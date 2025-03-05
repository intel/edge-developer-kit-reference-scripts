# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

import time
import cv2
from threading import Thread, Condition
from queue import Queue, Empty, Full
from utils.images_capture import VideoCapture


class Player:
	def __init__(self, player_id, device, model_adapter, input, precision="FP16", resolution=(1280, 720)):
		self.player_id = player_id
		self.model_adapter = model_adapter
		self.input = input
		self.device = device
		self.precision = precision
		self.running = False
		self.paused = False
		self.thread = None
		self.resolution = resolution  # Store resolution for resizing
		self.cap = VideoCapture(input, camera_resolution=self.resolution)  # Pass resolution to VideoCapture
		self.model = None
		self.queue = Queue(maxsize=100)
		self.cv = Condition()
		self.load_model()

	def load_model(self):
		model_path = f'/opt/models/{self.model_adapter["model"]}/{self.precision}/{self.model_adapter["model"]}.xml'
		adapter = self.model_adapter['adapter']
		try:
			self.model = adapter(model_path, self.device, self.precision, None)
		except Exception as e:
			print(f"Error loading model for player {self.player_id}: {e}")

	def start(self):
		with self.cv:
			if not self.running:
				self.running = True
				self.paused = False
				self.thread = Thread(target=self.run)
				self.thread.daemon = True
				self.thread.start()
				return True
		return False

	def stop(self):
		with self.cv:
			if self.running:
				self.running = False
				self.paused = False
				if self.thread and self.thread.is_alive():
					self.thread.join()
				self.queue.queue.clear()
				self.cv.notify_all()
				return True
		return False

	def pause(self):
		with self.cv:
			if self.running and not self.paused:
				self.paused = True
				self.cv.notify_all()
		return True

	def resume(self):
		with self.cv:
			if self.running and self.paused:
				self.paused = False
				self.cv.notify_all()
		return True

	def run(self):
		try:
			while self.running:
				frame = self.cap.read()  # Read frames from VideoCapture

				with self.cv:
					if not self.running:
						break

					while self.paused:
						self.cv.wait(timeout=0.1)

				if frame is None:
					# Log a warning and skip processing if the frame is empty
					print(f"Warning: Empty frame encountered in player {self.player_id}. Skipping frame.")
					time.sleep(0.001)  # Short sleep to avoid busy-waiting
					continue

				# Resize frame if it doesn't match the desired resolution
				if frame.shape[1] != self.resolution[0] or frame.shape[0] != self.resolution[1]:
					frame = cv2.resize(frame, self.resolution, interpolation=cv2.INTER_LINEAR)

				if self.model is not None:
					try:
						frame = self.model.predict(frame)
					except Exception as e:
						print(f"Error in model prediction for player {self.player_id}: {e}")
						continue

				# Encode the resized frame
				if frame is not None:
					ret, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 50])
					if ret:
						try:
							self.queue.put(buffer.tobytes(), timeout=0.01)
						except Full:
							continue
		finally:
			self.running = False


	def set_input(self, input):
		with self.cv:
			if input != self.input:
				self.input = input
				self.cap = VideoCapture(self.input, camera_resolution=self.resolution)  # Enforce resolution
				self.queue.queue.clear()

	def set_model(self, model_adapter):
		with self.cv:
			if model_adapter != self.model_adapter:
				self.model_adapter = model_adapter
				self.load_model()
				self.queue.queue.clear()

	def set_precision(self, precision):
		with self.cv:
			if precision != self.precision:
				self.precision = precision
				self.load_model()
				self.queue.queue.clear()

	def update(self, model_adapter=None, input=None, precision=None):
		with self.cv:
			self.set_model(model_adapter)
			self.set_input(input)
			self.set_precision(precision)

	def fps(self):
		return self.model.fps()

	def latency(self):
		return self.model.latency()

	def get_frame(self):
		try:
			return self.queue.get(timeout=0.5)
		except Empty:
			return None

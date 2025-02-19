# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

import os
import platform
import psutil
import math
import subprocess
import logging
import fire
import time
from statistics import mean
from flask import Flask, render_template, jsonify, request, Response
from flask_bootstrap import Bootstrap
from threading import Thread, Lock, Condition
from collections import deque
from threading import Lock
from datetime import datetime, timedelta
import distro  
from prometheus_client import Gauge, generate_latest, start_http_server
from utils.player import Player
from utils.yolov8_model import YoloV8Model
from utils.ssd_model import SSDModel
from utils.system_utils import get_power_consumption, get_cpu_model, get_gpu_model, list_devices, list_cameras

# Disable Flask's default request logging
log = logging.getLogger('werkzeug')
#log.setLevel(logging.ERROR)

# Global variables for connection management
connection_lock = Lock()
active_connections = {}  # Dictionary to track active connections: {IP: expiration_time}
connection_duration = timedelta(minutes=60)  # Limit duration to 5 minutes

# Model definitions
MODELS = {
	"yolov8n": {"model": "yolov8n", "adapter": YoloV8Model},
	"yolov8s": {"model": "yolov8s", "adapter": YoloV8Model},
	"yolov8m": {"model": "yolov8m", "adapter": YoloV8Model},
	"person-detection": {"model": "pedestrian-detection-adas-0002", "adapter": SSDModel},
}

class ObjectDetector:
	def __init__(self, port=80, host_address='localhost'):
		self.app = Flask(__name__)
		Bootstrap(self.app)
		self.port = port
		self.host_address = host_address  
		self.players = {}
		self.inputs = {}
		self.running = False
		self.cpu_loads = deque(maxlen=4)
		self.power_consumptions = deque(maxlen=4)
		self.lock = Lock()
		self.cv = Condition()  # Initialize the condition variable
		self.init_inputs()
		self.init_routes()
		self.metrics_thread = Thread(target=self.metrics_handler)
		self.metrics_thread.daemon = True
		self.animate = True 

		self.cpu_usage_metric = Gauge("cpu_usage_percent", "CPU Usage Percentage")
		self.power_consumption_metric = Gauge("power_consumption_watts", "Power Consumption in Watts")
		self.player_fps_metric = Gauge("fps", "Frames Per Second of Players", ['device'])
		self.player_latency_metric = Gauge("Latency", "Latency of Players in ms", ['device'])

	def init_inputs(self):

		input_folders = ['/opt/videos', '/workspace/videos']

		for folder in input_folders:
			for file in os.listdir(folder):
				file_path = os.path.join(folder, file)
				if os.path.isfile(file_path):
					self.inputs[file] = file_path  # Store the absolute path

		cameras = list_cameras()
		for cam in cameras:
			self.inputs[cam['name']] = cam['url']

	def start_player(self, player_id, device, model_name, source, precision="FP16"):
		with self.cv:
			if player_id in self.players and self.players[player_id].running:
				return False
			try:
				if player_id in self.players:
					self.stop_player(player_id)

				input = self.inputs[source] if source in self.inputs else source
				model_adapter = MODELS[model_name]
				player = Player(player_id, device, model_adapter, input, precision)
				player.ready_to_display = False
				player.start()
				self.players[player_id] = player
				self.cv.notify_all()
				return True
			except Exception as e:
				print(f"Error starting player {player_id}: {e}")
				return False

	def stop_player(self, player_id):
		with self.cv:
			if player_id in self.players:
				try:
					player = self.players.pop(player_id)
					player.stop()
					self.cv.notify_all()
					return True
				except Exception as e:
					print(f"Error stopping player {player_id}: {e}")
					return False
		return False

	def metrics_handler(self):
		"""Periodically collect system metrics."""
		while self.running:
			with self.cv:
				try:

					cpu_percent = psutil.cpu_percent(interval=None)
					power_consumption = get_power_consumption()

					self.cpu_loads.append(cpu_percent)
					self.power_consumptions.append(power_consumption)

					self.cpu_usage_metric.set(cpu_percent)
					self.power_consumption_metric.set(power_consumption)

					for player_id, player in self.players.items():
						if player.running and not player.paused:
							fps = player.fps()
							latency = player.latency()
						else:
							fps = latency = 0
							
						self.player_fps_metric.labels(device=player_id.upper()).set(fps)
						self.player_latency_metric.labels(device=player_id.upper()).set(latency)
					
				except Exception as e:
					logging.error(f"Metrics collection error: {e}")  

					self.cv.notify_all()

			time.sleep(1)

	def init_routes(self):
		"""Define routes for the web app."""
		self.app.add_url_rule('/metrics', 'prometheus_metrics', self.prometheus_metrics)
		app = self.app


		@app.route('/')
		def home():
			client_ip = request.remote_addr
			now = datetime.now()

			with connection_lock:
				# Check if the IP already has an active connection
				if client_ip in active_connections:

					expiration = active_connections[client_ip]
					if now < expiration:  # Connection is still active

						remaining_time = (expiration - now).total_seconds()
						return render_template(
							'access_denied.html',
							remaining_time=int(remaining_time)
						), 403
					else:
						# Remove expired connection and allow new one
						del active_connections[client_ip]

				# Register the new connection
				active_connections[client_ip] = now + connection_duration

			# Proceed with the normal logic if allowed
			platform_name = get_gpu_model().split("[")[0].replace("Intel Corporation", "").strip()
			devices = 	list_devices()
			default_device = "CPU"
			default_model = next(iter(MODELS.keys()), "No models available")
			default_source = next(iter(self.inputs.keys()), "No inputs available")
			default_precision = "FP16"

			return render_template(
				'index.html',
				devices=devices,
				default_device=default_device,
				default_precision=default_precision,
				default_model=default_model,
				default_source=default_source,
				platform_name=platform_name,
				model_names=list(MODELS.keys()),
				sources=list(self.inputs.keys()),
				animate=self.animate
			)

		@app.route('/video_feed')
		def video_feed():
			player_id = request.args.get('player_id')

			if not player_id:
				return "Error: player_id is required", 400

			with self.cv:
				while True:
					if player_id not in self.players or not self.players[player_id].running:
						self.cv.wait(timeout=0.1)
					else:
						break

			def generate():
				with self.cv:
					player = self.players[player_id]

				while player.running:
					frame = player.get_frame()
					if frame is not None:
						if not player.ready_to_display:
							player.ready_to_display = True 

						yield (b'--frame\r\n'
							   b'Content-Type: image/jpeg\r\n\r\n' + frame + b'\r\n')
					else:
						with self.cv:
							self.cv.wait(timeout=0.1)

			return Response(generate(), mimetype='multipart/x-mixed-replace; boundary=frame')

		@app.route('/get_metrics', methods=['GET'])
		def get_metrics():
			with self.cv:
				try:
					metrics = {
						'cpu_percent': int(mean(self.cpu_loads) if self.cpu_loads else 0),
						'power_data': int(mean(self.power_consumptions) if self.power_consumptions else 0),
						'players': {}
					}

					for player_id, player in self.players.items():
						if player.running and player.model:
							metrics['players'][player_id] = {
								'fps': player.fps(),
								'latency': player.latency()
							}
						else:
							metrics['players'][player_id] = {
								'fps': None,
								'latency': None,
								'status': 'stopped' if not player.running else 'model not loaded'
							}
					return jsonify(metrics)
				except Exception as e:
					return jsonify({'error': 'Failed to gather metrics'}), 500

		@app.route('/start_player', methods=['POST'])
		def start_player():
			data = request.get_json()
			player_id = data.get('player_id')
			device = data.get('device')
			model_name = data.get('model')
			source = data.get('source')
			precision = data.get('precision', "FP16")

			if self.start_player(player_id, device, model_name, source, precision):
				return jsonify({'message': f'Player {player_id} started successfully'})
			return jsonify({'error': f'Failed to start player {player_id}'}), 500

		@app.route('/stop_player', methods=['POST'])
		def stop_player():
			data = request.get_json()
			player_id = data.get('player_id')
			if self.stop_player(player_id):
				return jsonify({'message': f'Player {player_id} stopped successfully'})
			return jsonify({'error': f'Failed to stop player {player_id}'}), 500

		@app.route('/update_player', methods=['POST'])
		def update_player():
			data = request.get_json()
			player_id = data.get('player_id')
			with self.cv:
				if player_id in self.players:
					player = self.players[player_id]
					player.ready_to_display = False 
					source = data.get('source')
					input = self.inputs[source] if source in  self.inputs else source
					ret = player.update(
										model_adapter=MODELS.get(data.get('model')),
										input=input,
										precision=data.get('precision')
										)
					if ret:
						return jsonify({'message': f'Player {player_id} updated successfully'})
					else:
						return jsonify({'message': f'Player {player_id} cannot be updated'})

			return jsonify({'error': f'Player {player_id} not found'}), 404

		@app.route('/pause_player', methods=['POST'])
		def pause_player():
			data = request.get_json()
			player_id = data.get('player_id')
			with self.cv:
				if player_id in self.players:
					player = self.players[player_id]
					ret = player.pause()
					if ret:
						return jsonify({'message': f'Player {player_id} paused successfully'})
					else:
						return jsonify({'message': f'Player {player_id} cannot be paused'})

			return jsonify({'error': f'Player {player_id} not found'}), 404

		@app.route('/resume_player', methods=['POST'])
		def resume_player():
			data = request.get_json()
			player_id = data.get('player_id')
			with self.cv:
				if player_id in self.players:
					player = self.players[player_id]
					ret = player.resume()
					if ret:
						return jsonify({'message': f'Player {player_id} resumed successfully'})
					else:
						return jsonify({'message': f'Player {player_id} cannot be resumed'})

			return jsonify({'error': f'Player {player_id} not found'}), 404

		@app.route('/player_ready', methods=['GET'])
		def player_ready():
			"""Check if the player is ready to display."""
			player_id = request.args.get('player_id')
			if not player_id:
				return jsonify({'error': 'player_id is required'}), 400

			with self.cv:
				if player_id in self.players and self.players[player_id].running:
					player = self.players[player_id]
					return jsonify({'ready': player.ready_to_display})

			return jsonify({'ready': False})
				# File selection and upload routes

		@app.route('/upload', methods=['POST'])
		def upload_file():
			if 'file' not in request.files:
				return jsonify({"error": "No file part"}), 400
			file = request.files['file']
			if file.filename == '':
				return jsonify({"error": "No selected file"}), 400

			file_path = os.path.join(self.upload_folder, file.filename)
			file.save(file_path)
			self.inputs[file.filename] = file_path
			return jsonify({"message": "File uploaded successfully", "file_path": file_path}), 200

		@app.route('/get_sources', methods=['GET'])
		def get_sources():
			sources = list(self.inputs.keys())
			return jsonify(sources)

		@app.route('/disconnect')
		def disconnect():
			client_ip = request.remote_addr
			with connection_lock:
				if active_connection["ip"] == client_ip:
					active_connection["ip"] = None
					active_connection["expiration"] = None
			return jsonify({"message": "Disconnected successfully"})
	
		@app.route('/get_system_info', methods=['GET'])
		def get_system_info():
			"""Returns system information: CPU, GPU, OS, Kernel, and RAM."""
			system_info = {
				"CPU Model": get_cpu_model(),
				"GPU Model": get_gpu_model().replace("Intel Corporation", "").strip(),
				"OS Distribution": f"{distro.name()} {distro.version()}",
				"Kernel Version": platform.release(),
				"RAM Size": f"{math.floor(psutil.virtual_memory().total / (1000 ** 3))} GB"
			}
			return jsonify(system_info)

	def prometheus_metrics(self):
		return Response(generate_latest(), mimetype="text/plain")

	def run(self):
		self.running = True
		start_http_server(8082)
		self.metrics_thread.start()
		self.app.run(host=self.host_address, port=self.port, debug=False, threaded=True)


def main(port=80, host_address="127.0.0.1"):
	detector = ObjectDetector(port=port, host_address=host_address)
	detector.run()


if __name__ == "__main__":
	fire.Fire(main)

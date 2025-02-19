# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

import cv2
import numpy as np
from time import perf_counter

from utils.model import Model


class SSDModel(Model):
	def __init__(self, model_path, device, data_type, callback_function=None):
		super().__init__(model_path, device, data_type)
		self.user_callback = callback_function
		self.labels = [ "background", "person"]
		self.colors = [(0,0,0), (4, 42, 255)]

	def callback(self, outputs, image):
		image = self.postprocess(outputs, image)
		if self.user_callback is not None:
			self.user_callback(image)

	def postprocess(self, detections, image, threshold=0.5):
		for _, label_id, score, xmin, ymin, xmax, ymax in detections[0][0]:
			if score >= threshold:
				color = self.colors[int(label_id)]
				label = self.labels[int(label_id)]
				xmin *= image.shape[1]
				xmax *= image.shape[1]
				ymin *= image.shape[0]
				ymax *= image.shape[0]
				image = self.plot_one_box(image, xmin, ymin, xmax, ymax, score, label, color )

		return image


	

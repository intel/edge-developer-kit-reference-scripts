# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

import os, argparse
import math
import ctypes
from typing import Tuple, Dict
from collections import deque
from threading import Condition
import cython
import numpy as np
import torch 
cimport numpy as np
from libc.stdint cimport (uint8_t, uint16_t, uint32_t, uint64_t,
						  int8_t, int16_t, int32_t, int64_t)
from libcpp cimport bool
from pathlib import Path
import shutil
import cv2
from PIL import Image
from time import perf_counter
import pathlib
from ultralytics.utils.plotting import colors
import openvino.runtime as ov
from openvino.runtime import Core, AsyncInferQueue
import numpy as np
from utils.model import Model

#import dpctl
	
np.import_array()

labels = ['person', 'bicycle', 'car', 'motorcycle', 'airplane', 'bus', 'train', 'truck', 'boat', 'traffic light', 'fire hydrant', 
		  'stop sign', 'parking meter', 'bench', 'bird', 'cat', 'dog', 'horse', 'sheep', 'cow', 'elephant', 'bear', 'zebra', 'giraffe', 
		  'backpack', 'umbrella', 'handbag', 'tie', 'suitcase', 'frisbee', 'skis', 'snowboard', 'sports ball', 'kite', 'baseball bat', 
		  'baseball glove', 'skateboard', 'surfboard', 'tennis racket', 'bottle', 'wine glass', 'cup', 'fork', 'knife', 'spoon', 'bowl', 
		  'banana', 'apple', 'sandwich', 'orange', 'broccoli', 'carrot', 'hot dog', 'pizza', 'donut', 'cake', 'chair', 'couch', 'potted plant', 
		  'bed', 'dining table', 'toilet', 'tv', 'laptop', 'mouse', 'remote', 'keyboard', 'cell phone', 'microwave', 'oven', 'toaster', 'sink', 
		  'refrigerator', 'book', 'clock', 'vase', 'scissors', 'teddy bear', 'hair drier', 'toothbrush']



cdef class YoloV8ModelBase():
	def __init__(self, callback_function=None):

		self.user_callback = callback_function

		self.labels = labels
		self.num_masks = 32
		self.conf_threshold = 0.5
		self.iou_threshold = 0.2

	def callback(self, boxes, image):
		image = self.postprocess(boxes, image )
		if self.user_callback is not None:
			self.user_callback(image)

	def postprocess(self, pred_boxes, image):
		boxes, scores, class_ids = self.process_box_output(pred_boxes, image)
		image = self.draw_detections(image, boxes, scores, class_ids)
		return image

	cdef get_boxes(self, np.ndarray[float, ndim=2] box_predictions, np.ndarray[uint8_t, ndim=3] orig_img):
		cdef int img_height = orig_img.shape[0]
		cdef int img_width = orig_img.shape[1]

		cdef np.ndarray[float, ndim=2] boxes = box_predictions[:, :4]

		# Scale boxes to original image dimensions
		cdef np.ndarray[long, ndim=1] input_shape = np.array([self.input_width, self.input_height, self.input_width, self.input_height])
		boxes = np.divide(boxes, input_shape, dtype=np.float32)
		boxes *= np.array([img_width, img_height, img_width, img_height])

		# Convert bounding box (x, y, w, h) to bounding box (x1, y1, x2, y2)
		cdef np.ndarray[float, ndim=2] xy = boxes.copy(); 
		boxes[..., 0] = xy[..., 0] - xy[..., 2] / 2
		boxes[..., 1] = xy[..., 1] - xy[..., 3] / 2
		boxes[..., 2] = xy[..., 0] + xy[..., 2] / 2
		boxes[..., 3] = xy[..., 1] + xy[..., 3] / 2
		
		# Check the boxes are within the image
		boxes[:, 0] = np.clip(boxes[:, 0], 0, img_width)
		boxes[:, 1] = np.clip(boxes[:, 1], 0, img_height)
		boxes[:, 2] = np.clip(boxes[:, 2], 0, img_width)
		boxes[:, 3] = np.clip(boxes[:, 3], 0, img_height)

		return boxes

	cdef nms(self, np.ndarray[float, ndim=2] boxes, np.ndarray[float, ndim=1] scores, float iou_threshold):
		# Sort by score
		cdef np.ndarray[long, ndim=1] sorted_indices = np.argsort(scores)[::-1]

		cdef list  keep_boxes = []
		cdef int box_id
		cdef np.ndarray[float, ndim=1] ious
		cdef np.ndarray[long, ndim=1] keep_indices

		while sorted_indices.size > 0:
			# Pick the last box
			box_id = sorted_indices[0]
			keep_boxes.append(box_id)

			# Compute IoU of the picked box with the rest
			ious = self.compute_iou(boxes[box_id, :], boxes[sorted_indices[1:], :])

			# Remove boxes with IoU over the threshold
			keep_indices = np.where(ious < iou_threshold)[0]

			# print(keep_indices.shape, sorted_indices.shape)
			sorted_indices = sorted_indices[keep_indices + 1]

		return keep_boxes

	cdef process_box_output(self, np.ndarray[float, ndim=3] box_output, np.ndarray[uint8_t, ndim=3] orig_img):

		cdef np.ndarray[float, ndim=2]  predictions = np.squeeze(box_output).T

		cdef int num_classes = box_output.shape[1] - self.num_masks - 4
		# Filter out object confidence scores below threshold
		cdef np.ndarray[float, ndim=1]  scores = np.max(predictions[:, 4:4+num_classes], axis=1)
		predictions = predictions[scores > self.conf_threshold, :]
		scores = scores[scores > self.conf_threshold]

		if len(scores) == 0:
			return [], [], [], np.array([])

		cdef np.ndarray[float, ndim=2] box_predictions = predictions[..., :num_classes+4]

		# Get the class with the highest confidence
		cdef np.ndarray[long, ndim=1] class_ids = np.argmax(box_predictions[:, 4:], axis=1)

		# Get bounding boxes for each object
		cdef np.ndarray[float, ndim=2] boxes = self.get_boxes(box_predictions, orig_img)

		# Apply non-maxima suppression to suppress weak, overlapping bounding boxes
		cdef list indices = self.nms(boxes, scores, self.iou_threshold)

		return boxes[indices], scores[indices], class_ids[indices]


	cdef compute_iou(self, np.ndarray[float, ndim=1] box, np.ndarray[float, ndim=2] boxes):
		
		# Compute xmin, ymin, xmax, ymax for both boxes
		cdef np.ndarray[float, ndim=1] xmin = np.maximum(box[0], boxes[:, 0])
		cdef np.ndarray[float, ndim=1] ymin = np.maximum(box[1], boxes[:, 1])
		cdef np.ndarray[float, ndim=1] xmax = np.minimum(box[2], boxes[:, 2])
		cdef np.ndarray[float, ndim=1] ymax = np.minimum(box[3], boxes[:, 3])

		# Compute intersection area
		cdef np.ndarray[float, ndim=1] intersection_area = np.maximum(0, xmax - xmin) * np.maximum(0, ymax - ymin)
		# Compute union area
		cdef float box_area = (box[2] - box[0]) * (box[3] - box[1])
		cdef np.ndarray[float, ndim=1] boxes_area = (boxes[:, 2] - boxes[:, 0]) * (boxes[:, 3] - boxes[:, 1])
		cdef np.ndarray[float, ndim=1] union_area = box_area + boxes_area - intersection_area

		# Compute IoU
		cdef np.ndarray[float, ndim=1]  iou = intersection_area / union_area

		return iou

	def draw_detections(self, image, boxes, scores, class_ids):
		img_height, img_width = image.shape[:2]
		size = min([img_height, img_width]) * 0.0008
		text_thickness = int(min([img_height, img_width]) * 0.002)

		# Draw bounding boxes and labels of detections
		for box, score, class_id in zip(boxes, scores, class_ids):
			label = self.labels[class_id]				
			color = colors(class_id)
			x1, y1, x2, y2 = box.astype(int)

			image = self.plot_one_box(image, x1, y1, x2, y2, score, label, color)

		return image


class YoloV8Model(YoloV8ModelBase, Model):
	def __init__(self, model_path, device, data_type, callback_function):
		YoloV8ModelBase.__init__(self, callback_function)
		Model.__init__(self, model_path, device, data_type, 255.0, callback_function!=None)


	

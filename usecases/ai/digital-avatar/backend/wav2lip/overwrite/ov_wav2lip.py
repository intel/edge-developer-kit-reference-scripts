# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

import sys
import os

script_folder = os.path.join(os.path.dirname(__file__), 'wav2lip')
sys.path.append(script_folder)

import numpy as np
import cv2
from .audio import load_wav, melspectrogram
import subprocess
from tqdm import tqdm
from glob import glob
import torch
import platform
import openvino as ov
import torch
from torch.utils.model_zoo import load_url
from enum import Enum
import torch.nn.functional as F
import openvino.properties.hint as hints
import openvino.properties as props
# from face_parsing import init_parser, swap_regions
from concurrent.futures import ThreadPoolExecutor
from threading import Lock

import time
import logging
import uuid
from pathlib import Path

try:
    import urllib.request as request_file
except BaseException:
    import urllib as request_file


class LandmarksType(Enum):
    """Enum class defining the type of landmarks to detect.

    ``_2D`` - the detected points ``(x,y)`` are detected in a 2D space and follow the visible contour of the face
    ``_2halfD`` - this points represent the projection of the 3D points into 3D
    ``_3D`` - detect the points ``(x,y,z)``` in a 3D space

    """
    _2D = 1
    _2halfD = 2
    _3D = 3


class NetworkSize(Enum):
    # TINY = 1
    # SMALL = 2
    # MEDIUM = 3
    LARGE = 4

    def __new__(cls, value):
        member = object.__new__(cls)
        member._value_ = value
        return member

    def __int__(self):
        return self.value


class OVFaceDetector(object):
    def __init__(self, device, verbose):
        self.device = device
        self.verbose = verbose

    def detect_from_image(self, tensor_or_path):
        raise NotImplementedError

    def detect_from_directory(self, path, extensions=['.jpg', '.png'], recursive=False, show_progress_bar=True):
        if self.verbose:
            logger = logging.getLogger(__name__)

        if len(extensions) == 0:
            if self.verbose:
                logger.error(
                    "Expected at list one extension, but none was received.")
            raise ValueError

        if self.verbose:
            logger.info("Constructing the list of images.")
        additional_pattern = '/**/*' if recursive else '/*'
        files = []
        for extension in extensions:
            files.extend(glob.glob(path + additional_pattern +
                         extension, recursive=recursive))

        if self.verbose:
            logger.info(
                "Finished searching for images. %s images found", len(files))
            logger.info("Preparing to run the detection.")

        predictions = {}
        for image_path in tqdm(files, disable=not show_progress_bar):
            if self.verbose:
                logger.info(
                    "Running the face detector on image: %s", image_path)
            predictions[image_path] = self.detect_from_image(image_path)

        if self.verbose:
            logger.info(
                "The detector was successfully run on all %s images", len(files))

        return predictions

    @property
    def reference_scale(self):
        raise NotImplementedError

    @property
    def reference_x_shift(self):
        raise NotImplementedError

    @property
    def reference_y_shift(self):
        raise NotImplementedError

    @staticmethod
    def tensor_or_path_to_ndarray(tensor_or_path, rgb=True):
        """Convert path (represented as a string) or torch.tensor to a numpy.ndarray

        Arguments:
            tensor_or_path {numpy.ndarray, torch.tensor or string} -- path to the image, or the image itself
        """
        if isinstance(tensor_or_path, str):
            return cv2.imread(tensor_or_path) if not rgb else cv2.imread(tensor_or_path)[..., ::-1]
        elif torch.is_tensor(tensor_or_path):
            # Call cpu in case its coming from cuda
            return tensor_or_path.cpu().numpy()[..., ::-1].copy() if not rgb else tensor_or_path.cpu().numpy()
        elif isinstance(tensor_or_path, np.ndarray):
            return tensor_or_path[..., ::-1].copy() if not rgb else tensor_or_path
        else:
            raise TypeError


class OVSFDDetector(OVFaceDetector):
    def __init__(self, device, face_detector, verbose=False):
        super().__init__(device, verbose)
        self.face_detector = face_detector

    def detect_from_image(self, tensor_or_path):
        image = self.tensor_or_path_to_ndarray(tensor_or_path)

        bboxlist = self.detect(self.face_detector, image, device="cpu")
        keep = self.nms(bboxlist, 0.3)
        bboxlist = bboxlist[keep, :]
        bboxlist = [x for x in bboxlist if x[-1] > 0.5]

        return bboxlist

    def detect_from_batch(self, images):
        bboxlists = self.batch_detect(self.face_detector, images, device="cpu")
        keeps = [self.nms(bboxlists[:, i, :], 0.3)
                 for i in range(bboxlists.shape[1])]
        bboxlists = [bboxlists[keep, i, :] for i, keep in enumerate(keeps)]
        bboxlists = [[x for x in bboxlist if x[-1] > 0.5]
                     for bboxlist in bboxlists]

        return bboxlists

    def nms(self, dets, thresh):
        if 0 == len(dets):
            return []
        x1, y1, x2, y2, scores = dets[:, 0], dets[:,
                                                  1], dets[:, 2], dets[:, 3], dets[:, 4]
        areas = (x2 - x1 + 1) * (y2 - y1 + 1)
        order = scores.argsort()[::-1]

        keep = []
        while order.size > 0:
            i = order[0]
            keep.append(i)
            xx1, yy1 = np.maximum(x1[i], x1[order[1:]]), np.maximum(
                y1[i], y1[order[1:]])
            xx2, yy2 = np.minimum(x2[i], x2[order[1:]]), np.minimum(
                y2[i], y2[order[1:]])

            w, h = np.maximum(
                0.0, xx2 - xx1 + 1), np.maximum(0.0, yy2 - yy1 + 1)
            ovr = w * h / (areas[i] + areas[order[1:]] - w * h)

            inds = np.where(ovr <= thresh)[0]
            order = order[inds + 1]

        return keep

    def detect(self, net, img, device):
        img = img - np.array([104, 117, 123])
        img = img.transpose(2, 0, 1)
        img = img.reshape((1,) + img.shape)

        img = torch.from_numpy(img).float().to(device)
        BB, CC, HH, WW = img.size()

        results = net({"x": img.numpy()})
        olist = [torch.Tensor(results[i]) for i in range(12)]

        bboxlist = []
        for i in range(len(olist) // 2):
            olist[i * 2] = F.softmax(olist[i * 2], dim=1)
        olist = [oelem.data.cpu() for oelem in olist]
        for i in range(len(olist) // 2):
            ocls, oreg = olist[i * 2], olist[i * 2 + 1]
            FB, FC, FH, FW = ocls.size()  # feature map size
            stride = 2**(i + 2)    # 4,8,16,32,64,128
            anchor = stride * 4
            poss = zip(*np.where(ocls[:, 1, :, :] > 0.05))
            for Iindex, hindex, windex in poss:
                axc, ayc = stride / 2 + windex * stride, stride / 2 + hindex * stride
                score = ocls[0, 1, hindex, windex]
                loc = oreg[0, :, hindex, windex].contiguous().view(1, 4)
                priors = torch.Tensor(
                    [[axc / 1.0, ayc / 1.0, stride * 4 / 1.0, stride * 4 / 1.0]])
                variances = [0.1, 0.2]
                box = self.decode(loc, priors, variances)
                x1, y1, x2, y2 = box[0] * 1.0
                # cv2.rectangle(imgshow,(int(x1),int(y1)),(int(x2),int(y2)),(0,0,255),1)
                bboxlist.append([x1, y1, x2, y2, score])
        bboxlist = np.array(bboxlist)
        if 0 == len(bboxlist):
            bboxlist = np.zeros((1, 5))

        return bboxlist

    def decode(self, loc, priors, variances):
        """Decode locations from predictions using priors to undo
        the encoding we did for offset regression at train time.
        Args:
            loc (tensor): location predictions for loc layers,
                Shape: [num_priors,4]
            priors (tensor): Prior boxes in center-offset form.
                Shape: [num_priors,4].
            variances: (list[float]) Variances of priorboxes
        Return:
            decoded bounding box predictions
        """

        boxes = torch.cat((
            priors[:, :2] + loc[:, :2] * variances[0] * priors[:, 2:],
            priors[:, 2:] * torch.exp(loc[:, 2:] * variances[1])), 1)
        boxes[:, :2] -= boxes[:, 2:] / 2
        boxes[:, 2:] += boxes[:, :2]
        return boxes

    def batch_detect(self, net, imgs, device):
        imgs = imgs - np.array([104, 117, 123])
        imgs = imgs.transpose(0, 3, 1, 2)

        imgs = torch.from_numpy(imgs).float().to(device)
        BB, CC, HH, WW = imgs.size()

        results = net({"x": imgs.numpy()})
        olist = [torch.Tensor(results[i]) for i in range(12)]
        bboxlist = []
        for i in range(len(olist) // 2):
            olist[i * 2] = F.softmax(olist[i * 2], dim=1)
            # olist[i * 2] = (olist[i * 2], dim=1)
        olist = [oelem.data.cpu() for oelem in olist]
        # olist = [oelem for oelem in olist]
        for i in range(len(olist) // 2):
            ocls, oreg = olist[i * 2], olist[i * 2 + 1]
            FB, FC, FH, FW = ocls.size()  # feature map size
            stride = 2**(i + 2)    # 4,8,16,32,64,128
            anchor = stride * 4
            poss = zip(*np.where(ocls[:, 1, :, :] > 0.05))
            for Iindex, hindex, windex in poss:
                axc, ayc = stride / 2 + windex * stride, stride / 2 + hindex * stride
                score = ocls[:, 1, hindex, windex]
                loc = oreg[:, :, hindex, windex].contiguous().view(BB, 1, 4)
                priors = torch.Tensor(
                    [[axc / 1.0, ayc / 1.0, stride * 4 / 1.0, stride * 4 / 1.0]]).view(1, 1, 4)
                variances = [0.1, 0.2]
                box = self.batch_decode(loc, priors, variances)
                box = box[:, 0] * 1.0
                # cv2.rectangle(imgshow,(int(x1),int(y1)),(int(x2),int(y2)),(0,0,255),1)
                bboxlist.append(
                    torch.cat([box, score.unsqueeze(1)], 1).cpu().numpy())
        bboxlist = np.array(bboxlist)
        if 0 == len(bboxlist):
            bboxlist = np.zeros((1, BB, 5))

        return bboxlist

    def batch_decode(self, loc, priors, variances):
        """Decode locations from predictions using priors to undo
        the encoding we did for offset regression at train time.
        Args:
            loc (tensor): location predictions for loc layers,
                Shape: [num_priors,4]
            priors (tensor): Prior boxes in center-offset form.
                Shape: [num_priors,4].
            variances: (list[float]) Variances of priorboxes
        Return:
            decoded bounding box predictions
        """

        boxes = torch.cat((
            priors[:, :, :2] + loc[:, :, :2] * variances[0] * priors[:, :, 2:],
            priors[:, :, 2:] * torch.exp(loc[:, :, 2:] * variances[1])), 2)
        boxes[:, :, :2] -= boxes[:, :, 2:] / 2
        boxes[:, :, 2:] += boxes[:, :, :2]
        return boxes

    @property
    def reference_scale(self):
        return 195

    @property
    def reference_x_shift(self):
        return 0

    @property
    def reference_y_shift(self):
        return 0


class NetworkSize(Enum):
    # TINY = 1
    # SMALL = 2
    # MEDIUM = 3
    LARGE = 4

    def __new__(cls, value):
        member = object.__new__(cls)
        member._value_ = value
        return member

    def __int__(self):
        return self.value


class OVFaceAlignment:
    def __init__(self, landmarks_type, face_detector, network_size=NetworkSize.LARGE,
                 device='CPU', flip_input=False, verbose=False):
        self.device = device
        self.flip_input = flip_input
        self.landmarks_type = landmarks_type
        self.verbose = verbose

        network_size = int(network_size)

        self.face_detector = OVSFDDetector(
            device=device, face_detector=face_detector, verbose=verbose)

    def get_detections_for_batch(self, images):
        images = images[..., ::-1]
        detected_faces = self.face_detector.detect_from_batch(images.copy())
        results = []

        for i, d in enumerate(detected_faces):
            if len(d) == 0:
                results.append(None)
                continue
            d = d[0]
            d = np.clip(d, 0, None)

            x1, y1, x2, y2 = map(int, d[:-1])
            results.append((x1, y1, x2, y2))

        return results


class OVWav2Lip:
    def __init__(self, avatar_path="assets/xy.png", device="GPU", enhancer = None):
        # Paths to model checkpoints
        self.face_detection_path = "wav2lip/checkpoints/face_detection.xml"
        self.wav2lip_path = "wav2lip/checkpoints/wav2lip_gan.xml"
        self.segmentation_path = 'face_segmentation.pth'
        self.sr_path = 'esrgan_yunying.pth'
        self.face_landmarks_detector_path = 'wav2lip/checkpoints/face_landmarker_v2_with_blendshapes.task'

        self.enhancer = enhancer
        self.lock = Lock()
        # Device configuration
        self.inference_device = device

        # Input and output files
        self.face = avatar_path

        # Video processing settings
        self.static = False
        self.fps = 25.0
        self.pads = [0, 15, -10, -10]
        self.face_det_batch_size = 16
        self.wav2lip_batch_size = 128
        self.resize_factor = 1
        self.crop = [0, -1, 0, -1]
        self.box = [-1, -1, -1, -1]
        self.rotate = False
        self.nosmooth = True
        self.with_face_mask = False
        self.no_segmentation = False
        self.no_sr = False
        self.img_size = 96

        # Model URLs
        self.models_urls = {
            's3fd': 'https://www.adrianbulat.com/downloads/python-fan/s3fd-619a316812.pth',
        }

        # Run the initialization process
        self.run()

    def run(self):
        core = ov.Core()
        config = {hints.performance_mode: hints.PerformanceMode.LATENCY}

        # FIXME: A770 don't work for face detection
        self.face_detector = core.compile_model(
            self.face_detection_path, self.inference_device, config)

        # OV_WAV2LIP_MODEL_PATH = Path(args.wav2lip_path)
        core.set_property(
            {props.cache_dir: f'./cache/{self.inference_device}'})
        wav2_lip_model = core.read_model(model=self.wav2lip_path)
        self.compiled_wav2lip_model = core.compile_model(
            model=wav2_lip_model, device_name=self.inference_device, config=config)

        if os.path.isfile(self.face) and self.face.split('.')[1] in ['jpg', 'png', 'jpeg']:
            self.static = True
        # IOU cython speedup 10x

        def IOU(ax1, ay1, ax2, ay2, bx1, by1, bx2, by2):
            sa = abs((ax2 - ax1) * (ay2 - ay1))
            sb = abs((bx2 - bx1) * (by2 - by1))
            x1, y1 = max(ax1, bx1), max(ay1, by1)
            x2, y2 = min(ax2, bx2), min(ay2, by2)
            w = x2 - x1
            h = y2 - y1
            if w < 0 or h < 0:
                return 0.0
            else:
                return 1.0 * w * h / (sa + sb - w * h)

        self.full_frames = []
        os.makedirs("wav2lip/temp", exist_ok=True)
        if not os.path.isfile(self.face):
            raise ValueError(
                '--face argument must be a valid path to video/image file')

        elif self.face.split('.')[1] in ['jpg', 'png', 'jpeg']:
            self.full_frames = [cv2.imread(self.face)]
            self.fps = self.fps

        else:
            video_stream = cv2.VideoCapture(self.face)
            self.fps = video_stream.get(cv2.CAP_PROP_FPS)
            frame_count = video_stream.get(cv2.CAP_PROP_FRAME_COUNT)
            self.duration = round(frame_count / self.fps, 2)
            frames = []
            while 1:
                still_reading, frame = video_stream.read()
                if not still_reading:
                    video_stream.release()
                    break
                if self.resize_factor > 1:
                    frame = cv2.resize(
                        frame, (frame.shape[1]//self.resize_factor, frame.shape[0]//self.resize_factor))

                if self.rotate:
                    frame = cv2.rotate(frame, cv2.cv2.ROTATE_90_CLOCKWISE)

                y1, y2, x1, x2 = self.crop
                if x2 == -1:
                    x2 = frame.shape[1]
                if y2 == -1:
                    y2 = frame.shape[0]

                frame = frame[y1:y2, x1:x2]

                frames.append(frame)
            
            self.full_frames=frames.copy()

        self.mel_step_size = 16

        self.batch_size = self.wav2lip_batch_size

        self.face_det_results = None

        frames_temp = self.full_frames.copy()

        if self.box[0] == -1:
            if not self.static:
                self.face_det_results = self.face_detect_ov(
                    frames_temp, self.inference_device)
            else:
                self.face_det_results = self.face_detect_ov(
                    [frames_temp[0]], self.inference_device)
        else:
            print('Using the specified bounding box instead of face detection...')
            y1, y2, x1, x2 = self.box
            self.face_det_results = [
                [f[y1: y2, x1:x2], (y1, y2, x1, x2)] for f in frames_temp]

    def process_images_with_detector(self, images, detector, initial_batch_size):
        batch_size = initial_batch_size
        predictions = []

        for _ in range(int(np.log2(initial_batch_size)) + 1):  # Loop to halve the batch size
            try:
                for i in tqdm(range(0, len(images), batch_size)):
                    batch = np.array(images[i:i + batch_size])
                    predictions.extend(detector.get_detections_for_batch(batch))
                return predictions  # Return predictions if processing is successful
            except RuntimeError as e:
                import traceback
                traceback.print_exc()
                # if batch_size == 1:
                #     raise RuntimeError(
                #         'Image too big to run face detection on GPU. Please use the --resize_factor argument') from e
                # batch_size //= 2
                # print(f'Recovering from OOM error; New batch size: {batch_size}')

        # raise RuntimeError('Failed to process images even with the smallest batch size.')

    def face_detect_ov(self, images, device):
        detector = OVFaceAlignment(
            LandmarksType._2D, face_detector=self.face_detector, flip_input=False, device=device)

        predictions = self.process_images_with_detector(images, detector, self.face_det_batch_size)

        results = []
        pady1, pady2, padx1, padx2 = self.pads

        for rect, image in zip(predictions, images):
            if rect is None:
                # check this frame where the face was not detected.
                cv2.imwrite('temp/faulty_frame.jpg', image)
                raise ValueError(
                    'Face not detected! Ensure the video contains a face in all the frames.')

            y1 = max(0, rect[1] - pady1)
            y2 = min(image.shape[0], rect[3] + pady2)
            x1 = max(0, rect[0] - padx1)
            x2 = min(image.shape[1], rect[2] + padx2)

            results.append([x1, y1, x2, y2])

        boxes = np.array(results)
        if not self.nosmooth:
            boxes = self.get_smoothened_boxes(boxes, T=5)
        results = [[image[y1: y2, x1:x2], (y1, y2, x1, x2)]
                   for image, (x1, y1, x2, y2) in zip(images, boxes)]

        del detector
        return results

    def get_smoothened_boxes(boxes, T):
        for i in range(len(boxes)):
            if i + T > len(boxes):
                window = boxes[len(boxes) - T:]
            else:
                window = boxes[i: i + T]
            boxes[i] = np.mean(window, axis=0)
        return boxes

    def get_full_frames_and_face_det_results(self, reverse=False, double=False):
        if reverse:
            full_frames = self.full_frames.copy()[::-1]
            face_det_results = self.face_det_results.copy()[::-1]
        else:
            full_frames = self.full_frames.copy()
            face_det_results = self.face_det_results.copy()
        
        if double:
            full_frames = full_frames + full_frames[::-1]
            face_det_results = face_det_results + face_det_results[::-1]
        
        return full_frames, face_det_results

    def inference(self, audio_path, reversed=False, starting_frame=0, enhance=False):
        def process_frame(index, p, f, c, enhancer, enhance):
            y1, y2, x1, x2 = c
            p = p.astype(np.uint8)

            # Adjust coords to only focus on mouth
            crop_coords = [20, 80, 60, 90] # x1, x2, x3, x4
            
            width_c = x2 - x1
            height_c = y2 - y1
            scale_x = width_c / p.shape[1]
            scale_y = height_c / p.shape[0]
            
            p = p[crop_coords[2]: crop_coords[3], crop_coords[0]: crop_coords[1]]

            # Adjust the crop_coords relative to c
            adjusted_crop_coords = [
                int(crop_coords[0] * scale_x),
                int(crop_coords[1] * scale_x),
                int(crop_coords[2] * scale_y),
                int(crop_coords[3] * scale_y)
            ]
            x1 = x1 + adjusted_crop_coords[0]
            x2 = x1 + (adjusted_crop_coords[1] - adjusted_crop_coords[0])
            y1 = y1 + adjusted_crop_coords[2]
            y2 = y1 + (adjusted_crop_coords[3] - adjusted_crop_coords[2])

            if enhancer and enhance:
                with self.lock:
                    p, _ = enhancer.enhance(p)
            p = cv2.resize(p, (int((crop_coords[1] - crop_coords[0]) * scale_x), int((crop_coords[3] - crop_coords[2]) * scale_y)))
            
            # Create a mask for seamless cloning
            mask = 255 * np.ones(p.shape, p.dtype)
            
            # Calculate the center of the region where the image will be cloned
            center = (x1 + (x2 - x1) // 2, y1 + (y2 - y1) // 2)
            
            # Perform seamless cloning
            f = cv2.seamlessClone(p, f, mask, center, cv2.NORMAL_CLONE)
            
            return index, f

        file_id = str(uuid.uuid4())
        output_path = Path(f'wav2lip/results/{file_id}.mp4')
        output_path.parent.mkdir(parents=True, exist_ok=True)

        wav, wav_duration = load_wav(audio_path, 16000)
        mel = melspectrogram(wav)

        mel_chunks = []
        new_frames = []
        gen = None
        mel_idx_multiplier = 80./self.fps
        i = 0
        while 1:
            start_idx = int(i * mel_idx_multiplier)
            if start_idx + self.mel_step_size > len(mel[0]):
                mel_chunks.append(mel[:, len(mel[0]) - self.mel_step_size:])
                break
            mel_chunks.append(
                mel[:, start_idx: start_idx + self.mel_step_size])
            i += 1

        if not self.static:
            # if wav_duration > (self.duration):
            full_frames, face_det_results = self.get_full_frames_and_face_det_results(reverse=reversed, double=True)
            # else:
            #     full_frames, face_det_results = self.get_full_frames_and_face_det_results(reverse=reversed)
        else:
            full_frames, face_det_results = self.get_full_frames_and_face_det_results()

        gen = self.datagen(full_frames.copy(), mel_chunks, face_det_results, start_index=starting_frame)
        new_frames = full_frames.copy()[:len(mel_chunks)]
        device = 'cuda' if torch.cuda.is_available() else 'cpu'

        frames_generated = 0
        # count = 0
        # temp_path = f'wav2lip/temp/{file_id}'
        # temp_path2 = f'wav2lip/temp_2/{file_id}'
        # os.mkdir(temp_path)
        # os.mkdir(temp_path2)
        for i, (img_batch, mel_batch, frames, coords) in enumerate(tqdm(gen,
                                                                        total=int(np.ceil(float(len(mel_chunks))/self.batch_size)))):
            if i == 0:
                img_batch = torch.FloatTensor(
                    np.transpose(img_batch, (0, 3, 1, 2))).to(device)
                mel_batch = torch.FloatTensor(
                    np.transpose(mel_batch, (0, 3, 1, 2))).to(device)

                frame_h, frame_w = new_frames[0].shape[:-1]
                out = cv2.VideoWriter('wav2lip/temp/result.avi',
                                      cv2.VideoWriter_fourcc(*'DIVX'), self.fps, (frame_w, frame_h))
                pred_ov = self.compiled_wav2lip_model(
                    {"audio_sequences": mel_batch.numpy(), "face_sequences": img_batch.numpy()})[0]
            else:
                img_batch = np.transpose(img_batch, (0, 3, 1, 2))
                mel_batch = np.transpose(mel_batch, (0, 3, 1, 2))
                pred_ov = self.compiled_wav2lip_model(
                    {"audio_sequences": mel_batch, "face_sequences": img_batch})[0]
            # pred_ov = compiled_wav2lip_model({"audio_sequences": mel_batch, "face_sequences": img_batch})[0]
            pred_ov = pred_ov.transpose(0, 2, 3, 1) * 255.

            with ThreadPoolExecutor(max_workers=5) as executor:
                futures = [executor.submit(process_frame, i, p, f, c, self.enhancer, enhance) for i, (p, f, c) in enumerate(zip(pred_ov, frames, coords))]
                results = [None] * len(futures)
                for future in futures:
                    index, processed_frame = future.result()
                    results[index] = processed_frame

            for f in results:
                frames_generated += 1
                out.write(f)

        out.release()
        print(output_path)
        command = 'ffmpeg -y -i {} -i {} -strict -2 -q:v 1 -vf "hqdn3d,unsharp=5:5:0.5" {} > /dev/null 2>&1'.format(
        audio_path, 'wav2lip/temp/result.avi', output_path)

        subprocess.call(command, shell=platform.system() != 'Windows')

        return file_id

    def datagen(self, frames, mels, face_det_results, start_index=0):
        img_batch, mel_batch, frame_batch, coords_batch = [], [], [], []
        num_frames = len(frames)
        
        for i, m in enumerate(mels):
            # Start from the specified index, wrapping around the frame list if necessary
            idx = (start_index + i) % num_frames if not self.static else 0
            frame_to_save = frames[idx].copy()
            face, coords = face_det_results[idx].copy()
            face = cv2.resize(face, (self.img_size, self.img_size))

            img_batch.append(face)
            mel_batch.append(m)
            frame_batch.append(frame_to_save)
            coords_batch.append(coords)

            if len(img_batch) >= self.wav2lip_batch_size:
                img_batch, mel_batch = np.asarray(img_batch), np.asarray(mel_batch)

                img_masked = img_batch.copy()
                img_masked[:, self.img_size//2:] = 0

                img_batch = np.concatenate(
                    (img_masked, img_batch), axis=3) / 255.
                mel_batch = np.reshape(
                    mel_batch, [len(mel_batch), mel_batch.shape[1], mel_batch.shape[2], 1])

                yield img_batch, mel_batch, frame_batch, coords_batch
                img_batch, mel_batch, frame_batch, coords_batch = [], [], [], []

        if len(img_batch) > 0:
            img_batch, mel_batch = np.asarray(img_batch), np.asarray(mel_batch)

            img_masked = img_batch.copy()
            img_masked[:, self.img_size//2:] = 0

            img_batch = np.concatenate((img_masked, img_batch), axis=3) / 255.
            mel_batch = np.reshape(
                mel_batch, [len(mel_batch), mel_batch.shape[1], mel_batch.shape[2], 1])

            yield img_batch, mel_batch, frame_batch, coords_batch

if __name__ == "__main__":
    init_time = time.time()
    wav2lip = OVWav2Lip(device="CPU", avatar_path="assets/image.png")
    print("Init Time: ", time.time() - init_time)
    start_time = time.time()
    wav2lip.inference("assets/audio.wav")
    print("Time taken: ", time.time() - start_time)
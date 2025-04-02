# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

import os
import sys
import shutil
from time import  strftime

current_root_path = os.path.split(sys.argv[0])[0]
sadtalker_root = os.path.join(current_root_path, 'SadTalker')
sys.path.insert(0, sadtalker_root)

from src.utils.preprocess import CropAndExtract
from src.test_audio2coeff import Audio2Coeff  
from src.facerender.animate import AnimateFromCoeff
from src.facerender.pirender_animate import AnimateFromCoeff_PIRender
from src.generate_batch import get_data
from src.generate_facerender_batch import get_facerender_data
from src.utils.init_path import init_path

class SadTalkerInference:
    def __init__(self, source_image, device, enhancer = None, ref_video="assets/video.mp4"):
        self.source_image = source_image
        self.device = device
        self.batch_size=8

        self.input_yaw_list=None
        self.input_pitch_list=None
        self.input_roll_list=None

        self.size = 256
        self.preprocess  = 'extfull'
        self.pose_style=0
        self.ref_video=ref_video

        self.facerender="pirender"
        self.enhancer = enhancer
        self.background_enhancer=None

        self.result_dir="./results"
        self.checkpoint_dir="./checkpoints"

        self.preprocessed_dir = os.path.join(self.result_dir, "avatar-1")
        os.makedirs(self.preprocessed_dir, exist_ok=True)
        current_root_path = os.path.split(sys.argv[0])[0]
        self.sadtalker_paths = init_path(self.checkpoint_dir, os.path.join(current_root_path, 'SadTalker/src/config'), self.size, False, self.preprocess)
        
        self.ref_eyeblink_coeff_path=None
        self.ref_pose_coeff_path=None
        

        self.initialize_models()
        
    def reset_avatar(self):
        shutil.rmtree(self.preprocessed_dir)
        os.makedirs(self.preprocessed_dir, exist_ok=True)
        self.initialize_models()

    def initialize_models(self):
        self.preprocess_model = CropAndExtract(self.sadtalker_paths, self.device)
        self.audio_to_coeff = Audio2Coeff(self.sadtalker_paths,  self.device)
        if self.facerender == 'facevid2vid':
            self.animate_from_coeff= AnimateFromCoeff(self.sadtalker_paths, self.device)
        elif self.facerender == 'pirender':
            self.animate_from_coeff= AnimateFromCoeff_PIRender(self.sadtalker_paths, self.device)
        else:
            raise RuntimeError('Unknown model: {}'.format(self.facerender))
        
        first_frame_dir = os.path.join(self.preprocessed_dir, 'first_frame_dir')
        os.makedirs(first_frame_dir, exist_ok=True)
        print('3DMM Extraction for source image')
        first_coeff_path, crop_pic_path, crop_info, mouth_coords =  self.preprocess_model.generate(self.source_image, first_frame_dir, self.preprocess,\
                                                                                source_image_flag=True, pic_size=self.size)
        self.first_coeff_path = first_coeff_path
        self.crop_pic_path = crop_pic_path
        self.crop_info = crop_info
        self.mouth_coords = mouth_coords
        if self.first_coeff_path is None:
            print("Can't get the coeffs of the input")
            return
        
        if self.ref_video and os.path.exists(self.ref_video):
            ref_pose = self.source_image
            ref_pose_videoname = os.path.splitext(os.path.split(ref_pose)[-1])[0]
            ref_pose_frame_dir = os.path.join(self.preprocessed_dir, ref_pose_videoname)
            os.makedirs(ref_pose_frame_dir, exist_ok=True)
            print('3DMM Extraction for the reference video providing pose')
            _, _, _, self.mouth_coords = self.preprocess_model.generate(ref_pose, ref_pose_frame_dir, self.preprocess, source_image_flag=False)

    def inference(self, audio, expression_scale=0.9, still=True, enhance=False, mouth_only=True):
        #audio2ceoff
        batch = get_data(self.first_coeff_path, audio, self.device, self.ref_eyeblink_coeff_path, still=still)
        coeff_path = self.audio_to_coeff.generate(batch, self.preprocessed_dir, self.pose_style, self.ref_pose_coeff_path)

        data = get_facerender_data(coeff_path, self.crop_pic_path, self.first_coeff_path, audio, 
                                self.batch_size, self.input_yaw_list, self.input_pitch_list, self.input_roll_list,
                                expression_scale=expression_scale, still_mode=still, preprocess=self.preprocess, size=self.size, facemodel=self.facerender)
    
        result = self.animate_from_coeff.generate(data, self.preprocessed_dir, self.source_image, self.crop_info, \
                                    enhancer=self.enhancer, enhance=enhance, preprocess=self.preprocess, img_size=self.size, mouth_coords = self.mouth_coords, mouth_only=mouth_only)
        
        filename = result.split("/")[-1]
        shutil.move(result, os.path.join(self.result_dir, filename))
        print('The generated video is named:',  self.result_dir + filename)

        return filename
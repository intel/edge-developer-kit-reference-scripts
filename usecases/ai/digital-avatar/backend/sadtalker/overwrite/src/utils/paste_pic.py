# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

import cv2, os
import numpy as np
from tqdm import tqdm
import uuid
from concurrent.futures import ThreadPoolExecutor

from src.utils.videoio import save_video_with_watermark 

def process_frame(crop_frame, ox1, ox2, oy1, oy2, full_img):
    crop_frame = cv2.cvtColor(crop_frame, cv2.COLOR_RGB2BGR)
    p = cv2.resize(crop_frame.astype(np.uint8), (ox2-ox1, oy2 - oy1))
    mask = 255 * np.ones(p.shape, p.dtype)
    location = ((ox1 + ox2) // 2, (oy1 + oy2) // 2)
    gen_img = cv2.seamlessClone(p, full_img, mask, location, cv2.NORMAL_CLONE_WIDE)
    return gen_img

def process_mouth_frame(index, crop_frame, mouth_coord, initial_mouth_coords, crop_coords,full_frame, threshold):
        mouth_coord = mouth_coord
        clx, cly, crx, cry = crop_coords
        xmin, xmax, ymin, ymax = mouth_coord
            
        # resize image to crop size
        frame = cv2.resize(crop_frame, (crx-clx, cry - cly))
        frame = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)
        
        # crop mouth region and resize to fit video cropped frame
        frame = frame[initial_mouth_coords[2]:initial_mouth_coords[3], initial_mouth_coords[0]:initial_mouth_coords[1]]
        frame_resized = cv2.resize(frame, (xmax - xmin, ymax - ymin))

        # seamless clone
        mask = 255 * np.ones(frame_resized.shape, frame_resized.dtype)
        location = ((xmin + xmax) // 2, (ymin + ymax - threshold) // 2)
        gen_img = cv2.seamlessClone(frame_resized, full_frame, mask, location, cv2.NORMAL_CLONE_WIDE)
        return index, gen_img

def paste_pic(crop_frames, fps, pic_path, crop_info, new_audio_path, full_video_path, extended_crop=False, mouth_coords=None, mouth_only=False):

    if not os.path.isfile(pic_path):
        raise ValueError('pic_path must be a valid path to video/image file')
    elif pic_path.split('.')[-1] in ['jpg', 'png', 'jpeg']:
        # loader for first frame
        frames = [cv2.imread(pic_path)]
    else:
        # loader for videos
        video_stream = cv2.VideoCapture(pic_path)
        fps = video_stream.get(cv2.CAP_PROP_FPS)
        frames = []
        while 1:
            still_reading, frame = video_stream.read()
            if not still_reading:
                video_stream.release()
                break 
            frames.append(frame)
        frames.extend(frames[::-1])
        if isinstance(mouth_coords, list):
            mouth_coords.extend(mouth_coords[::-1])
    frame_h = frames[0].shape[0]
    frame_w = frames[0].shape[1]
    
    if len(crop_info) != 3:
        print("you didn't crop the image")
        return
    else:
        clx, cly, crx, cry = crop_info[1]
        lx, ly, rx, ry = crop_info[2]
        lx, ly, rx, ry = int(lx), int(ly), int(rx), int(ry)
        if extended_crop:
            oy1, oy2, ox1, ox2 = cly, cry, clx, crx
        else:
            oy1, oy2, ox1, ox2 = cly+ly, cly+ry, clx+lx, clx+rx

    tmp_path = str(uuid.uuid4())+'.mp4'
    if mouth_coords and mouth_only:
        threshold = 0
        
        initial_mouth_coords = 0,0,0,0
        if not isinstance(mouth_coords, list):
            mouth_coords = [mouth_coords]
        xmin, xmax, ymin, ymax = mouth_coords[0]
        
        mouth_x_min = xmin - clx
        mouth_x_max = xmax - clx
        mouth_y_min = ymin - cly
        mouth_y_max = ymax - cly
        initial_mouth_coords = mouth_x_min, mouth_x_max, mouth_y_min, mouth_y_max
            
        out_mouth = cv2.VideoWriter(tmp_path, cv2.VideoWriter_fourcc(*'mp4v'), fps, (frame_w, frame_h))
        with ThreadPoolExecutor() as executor:
            results = list(tqdm(executor.map(lambda i: process_mouth_frame(i, crop_frames[i], mouth_coords[i % len(mouth_coords)], initial_mouth_coords, (clx, cly, crx, cry), frames[i % len(frames)], threshold), range(len(crop_frames))), total=len(crop_frames), desc='Processing frames with mouth'))
        
        for index, gen_img in results:
            out_mouth.write(gen_img)
        
        out_mouth.release()
        save_video_with_watermark(tmp_path, new_audio_path, full_video_path, watermark=False)
        os.remove(tmp_path)
    else:
        out_tmp = cv2.VideoWriter(tmp_path, cv2.VideoWriter_fourcc(*'mp4v'), fps, (frame_w, frame_h))

        with ThreadPoolExecutor() as executor:
            results = list(tqdm(executor.map(lambda frame: process_frame(frame, ox1, ox2, oy1, oy2, frames[0]), crop_frames), total=len(crop_frames), desc='seamlessClone:'))

        for gen_img in results:
            out_tmp.write(gen_img)

        out_tmp.release()

        save_video_with_watermark(tmp_path, new_audio_path, full_video_path, watermark=False)
        os.remove(tmp_path)
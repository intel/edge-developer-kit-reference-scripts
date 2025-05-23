# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
import sys
import os
import torchvision.transforms.functional as functional
sys.modules['torchvision.transforms.functional_tensor'] = functional

parent_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.append(parent_dir)

from RealESRGan.inference import initialize

from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from fastapi import FastAPI, UploadFile, File, APIRouter
from starlette.background import BackgroundTasks
from fastapi.responses import JSONResponse, StreamingResponse
import uvicorn

from pydantic import BaseModel

from SadTalker.sadtalker import SadTalkerInference
import json
import logging
import wave

import time
import threading
import torch


from typing import Optional
import shutil

import numpy as np

logger = logging.getLogger('uvicorn.error')
SADTALKER=None

@asynccontextmanager
async def lifespan(app: FastAPI):
    global SADTALKER
    enhancer = initialize("realesr-animevideov3")
    source_image = "assets/image.png"
    SADTALKER = SadTalkerInference(source_image=source_image, device=os.environ.get('DEVICE', "cpu"), enhancer=enhancer)
    SADTALKER.reset_avatar()
    
    # warmup
    temp_filename = "empty.wav"
    with wave.open(temp_filename, "w") as wf:
        wf.setnchannels(1)  # mono
        wf.setsampwidth(2)  # 2 bytes per sample
        wf.setframerate(16000)  # 16 kHz
        wf.writeframes(np.zeros(16000 * 2, dtype=np.int16).tobytes())  # 1 second of silence
    start_time = time.time()
    result= SADTALKER.inference(audio=temp_filename, expression_scale=1.0, mouth_only=False)
    print(f"Time taken: {time.time()-start_time}")
    # shutil.copy(os.path.join("results", result), "assets/video.mp4")
    os.remove(temp_filename)
    yield

allowed_cors =  json.loads(os.getenv("ALLOWED_CORS", '["http://localhost"]'))
app = FastAPI(lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_cors,
    allow_credentials=True,
    allow_methods=['*'],
    allow_headers=['*'],
)

@app.get('/healthcheck', status_code=200)
def get_healthcheck():
    return 'OK'

router = APIRouter(prefix="/v1",
                   responses={404: {"description": "Unable to find route"}})

class InferenceFileRequest(BaseModel):
    filename: str
    expression_scale: Optional[float] = 0.5
    mouth_only: Optional[bool] = True

@router.get("/video/{id}")
async def get_video(id: str, bg_task: BackgroundTasks,):
    # TODO: remove lipsync file after streaming (refer to Wav2Lip main.py)
    async def remove_file(video_path):
        if os.path.exists(video_path):
            try:
                os.remove(video_path)
            except:
                logger.error(f"File: {video_path} not available")
    video_path = f"results/{id}"
    # return StreamingResponse(open(video_path, "rb"), media_type="video/mp4", background=bg_task.add_task(remove_file, video_path))
    return StreamingResponse(open(video_path, "rb"), media_type="video/mp4")


@router.post("/inference_from_filename")
async def inference_from_filename(data: InferenceFileRequest, starting_frame: int, reversed: str, enhance: bool  = False):
    # TODO: remove audio file after streaming (refer to Wav2Lip main.py)
    async def remove_file(file_name):
        if os.path.exists(file_name):
            try:
                os.remove(file_name)
            except:
                logger.error(f"File: {file_name} not available")

    global SADTALKER

    if not data.filename.endswith(".wav"):
        raise ValueError("Only .wav files are allowed")

    if not os.path.exists(f'data/{data.filename}'):
        raise ValueError(f"File: {data.filename} not found")
        
    start_time = time.time()
    result = SADTALKER.inference(f'data/{data.filename}', data.expression_scale, enhance=enhance, mouth_only=data.mouth_only)
    print(f"Time taken: {time.time()-start_time}")
    print(result)
    # await remove_file(f'data/{data.filename}')
    return JSONResponse(content={"url": result})


app.include_router(router)

def print_memory_stats():
    while True:
        memory_allocated_mb = torch.xpu.memory_allocated() / (1024 ** 2)
        print(f"Memory allocated: {memory_allocated_mb:.2f} MB")
        memory_reserved = torch.xpu.memory_reserved() / (1024 ** 2)
        print(f"Memory reserved: {memory_reserved:.2f} MB")
        time.sleep(5) 


if __name__ == "__main__":
    # memory_stats_thread = threading.Thread(target=print_memory_stats)
    # memory_stats_thread.daemon = True  
    # memory_stats_thread.start()

    uvicorn.run(
        "main:app",
        host=os.environ.get('SERVER_HOST', "0.0.0.0"),
        port=int(os.environ.get('SERVER_PORT', "8011")),
        reload=os.environ.get('SERVER_RELOAD', True)
    )
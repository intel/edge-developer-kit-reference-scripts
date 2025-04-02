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
from fastapi.encoders import jsonable_encoder
from fastapi.responses import FileResponse, StreamingResponse, JSONResponse
from fastapi import FastAPI, UploadFile, File, APIRouter
import tempfile
import uvicorn
import shutil
import logging
from starlette.background import BackgroundTasks
from wav2lip.ov_wav2lip import OVWav2Lip
import wave
import numpy as np
import json
import time
from setup.download_model import setup
import torch

logger = logging.getLogger('uvicorn.error')
WAV2LIP=None
DATA_DIRECTORY="data"

async def remove_file(file_name):
    if os.path.exists(file_name):
        try:
            os.remove(file_name)
        except:
            logger.error(f"File: {file_name} not available")


@asynccontextmanager
async def lifespan(app: FastAPI):
    setup()
    global WAV2LIP
    enhancer = initialize("realesr-animevideov3", device = os.environ.get('ENHANCER_DEVICE', "xpu" if torch.xpu.is_available() else "cpu" ))
    # enhancer = initialize("RealESRGAN_x4plus_anime_6B")
    # enhancer = initialize("realesr-general-x4v3")
    # enhancer = initialize("RealESRGAN_x4plus")
    # enhancer = initialize("RealESRGAN_x2plus")
    # enhancer = None
    WAV2LIP = OVWav2Lip(device="CPU", avatar_path="assets/video.mp4", enhancer=enhancer)

    print("warming up")
    temp_filename = "empty.wav"
    with wave.open(temp_filename, "w") as wf:
        wf.setnchannels(1)  # mono
        wf.setsampwidth(2)  # 2 bytes per sample
        wf.setframerate(16000)  # 16 kHz
        wf.writeframes(np.zeros(16000 * 2, dtype=np.int16).tobytes())  # 1 second of silence

    result= WAV2LIP.inference(temp_filename, enhance=True)
    result_path = os.path.join("wav2lip/results", result + ".mp4")
    # if os.path.exists(result_path):
    #     os.remove(result_path)
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

@router.post("/inference")
async def inference(bg_task: BackgroundTasks,starting_frame: int, reversed: str, file: UploadFile=File(...) ):
    global WAV2LIP
    if not file.filename.endswith(".wav"):
        return "Only .wav files are allowed"
    
    with tempfile.NamedTemporaryFile(suffix=".wav") as temp_audio:
        temp_audio_path = temp_audio.name
        with open(temp_audio_path, "wb") as f:
            shutil.copyfileobj(file.file, f)
            result = WAV2LIP.inference(temp_audio_path, reversed=True if reversed == "1" else False, starting_frame=starting_frame)
    print(result, flush=True)
    result = f"wav2lip/results/{result}.mp4"
    return FileResponse(result, media_type="video/mp4", background=bg_task.add_task(remove_file,result ))

@router.get("/test")
async def test(enhance: bool = False):
    global WAV2LIP

    start_time = time.time()
    result = WAV2LIP.inference("data/audio.wav", reversed=True if reversed == "1" else False, starting_frame=0, enhance=enhance)
    end_time = time.time()
    print(f"Inference took {end_time - start_time} seconds", flush=True)
    print(result, flush=True)
    return JSONResponse({"message": "hi"})

@router.post("/inference_from_filename")
async def inference( data: dict, starting_frame: int, reversed: str, enhance=False):
    global WAV2LIP
    if "filename" not in data:
        return "Filename is required"
    filename = data["filename"]
    if not filename.endswith(".wav"):
        return "Only .wav files are allowed"
    
    file_path=os.path.join(DATA_DIRECTORY, filename)
    if not os.path.exists(file_path):
        return JSONResponse(content=jsonable_encoder({"message": "file does not exist"}))

    start_time = time.time()
    with tempfile.NamedTemporaryFile(suffix=".wav") as temp_file:
        temp_file_path = temp_file.name
        shutil.copyfile(file_path, temp_file_path)
        result = WAV2LIP.inference(temp_file_path, reversed=True if reversed == "1" else False, starting_frame=starting_frame, enhance=enhance)
    end_time = time.time()

    print(result, flush=True)
    print(f"Inference took {end_time - start_time} seconds", flush=True)
    return JSONResponse(content=jsonable_encoder({"url": result}))

@router.get("/video/{id}")
async def get_video(id: str, bg_task: BackgroundTasks,):
    video_path = f"wav2lip/results/{id}.mp4"
    return StreamingResponse(open(video_path, "rb"), media_type="video/mp4")

app.include_router(router)

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host=os.environ.get('SERVER_HOST', "0.0.0.0"),
        port=int(os.environ.get('SERVER_PORT', "8011")),
        reload=True
    )
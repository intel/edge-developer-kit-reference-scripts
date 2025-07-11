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
from fastapi.responses import FileResponse, JSONResponse
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
from pydantic import BaseModel
from typing import Literal, Optional
import openvino as ov

logger = logging.getLogger('uvicorn.error')
WAV2LIP=None
DATA_DIRECTORY="data"

WAV2LIP_MODELS = ["wav2lip", "wav2lip_gan"]
ENHANCER_MODELS = [
        "RealESRGAN_x2plus", 
        "RealESRGAN_x4plus", 
        "realesr-animevideov3", 
        "realesr-general-x4v3", 
        "realesr-general-x4v3-dn", 
        "RealESRGAN_x4plus_anime_6B"
    ]
DEVICES = []
CONFIG = {
    "lipsync_model": os.environ.get('WAV2LIP_MODEL', WAV2LIP_MODELS[0]),
    "lipsync_device": os.environ.get('DEVICE', "CPU"),
    "use_enhancer": os.environ.get('USE_ENHANCER', False),
    "enhancer_device": os.environ.get('ENHANCER_DEVICE', "xpu:0" if torch.xpu.is_available() else "cpu"),
    "enhancer_model": os.environ.get('ENHANCER_MODEL', "RealESRGAN_x4plus_anime_6B"),
    "avatar_skin": os.environ.get('AVATAR_SKIN', "default")
}

class Configurations(BaseModel):
    lipsync_device: str
    lipsync_model: Literal[tuple(WAV2LIP_MODELS)]
    use_enhancer: Optional[bool] = False
    enhancer_device: Optional[str] = 'xpu:0'
    enhancer_model: Optional[Literal[tuple(ENHANCER_MODELS)]] = 'RealESRGAN_x4plus_anime_6B'
    avatar_skin: Optional[str] = 'default.mp4'
    
async def remove_file(file_name):
    if os.path.exists(file_name):
        try:
            os.remove(file_name)
        except:
            logger.error(f"File: {file_name} not available")

def initialize_wav2lip():
    global CONFIG
    enhancer=None
    if CONFIG["use_enhancer"] is not None:
        enhancer = initialize(CONFIG["enhancer_model"], device=CONFIG["enhancer_device"])

    wav2lip = OVWav2Lip(device=CONFIG["lipsync_device"], avatar_path=f"assets/avatar-skins/{CONFIG['avatar_skin']}.mp4", enhancer=enhancer, model=CONFIG["lipsync_model"])
    return wav2lip    

def warmup():
    # Warm up the model by running a dummy inference
    global WAV2LIP
    temp_filename = "empty.wav"
    with wave.open(temp_filename, "w") as wf:
        wf.setnchannels(1)  # mono
        wf.setsampwidth(2)  # 2 bytes per sample
        wf.setframerate(16000)  # 16 kHz
        wf.writeframes(np.zeros(16000 * 2, dtype=np.int16).tobytes())  # 1 second of silence

    result, _ = WAV2LIP.inference(temp_filename, enhance=CONFIG["use_enhancer"])
    result_path = os.path.join("wav2lip/results", result + ".mp4")
    os.remove(temp_filename)
    
def get_devices():
    devices = {
        "lipsync_device": [
        ],
        "enhancer_device": [
        ]
    }
    
    core = ov.Core()
    available_devices = core.get_available_devices()
    for device_name in available_devices:
        full_device_name = core.get_property(device_name, "FULL_DEVICE_NAME")
        devices["lipsync_device"].append({"name": full_device_name, "value": device_name})
    
    cpu_device_name = core.get_property("CPU", "FULL_DEVICE_NAME")
    devices["enhancer_device"].append({"name": cpu_device_name, "value": "cpu"})
        
    if torch.xpu.is_available():
        for i in range(torch.xpu.device_count()):
            devices["enhancer_device"].append({"name": f"GPU.{i}: {torch.xpu.get_device_name(i)}", "value": f"xpu:{i}"})

    return devices

def is_valid_device(device: str, device_type: str, devices: dict) -> bool:
    if device_type not in devices:
        return False
    return any(d["value"] == device for d in devices[device_type])


@asynccontextmanager
async def lifespan(_: FastAPI):
    setup()
    global WAV2LIP, DEVICES
    DEVICES = get_devices()
    WAV2LIP = initialize_wav2lip()

    warmup()
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
async def inference(bg_task: BackgroundTasks, starting_frame: int, reversed: str, file: UploadFile = File(...)):
    if not file.filename.endswith(".wav"):
        return "Only .wav files are allowed"
    
    with tempfile.NamedTemporaryFile(suffix=".wav") as temp_audio:
        temp_audio_path = temp_audio.name
        with open(temp_audio_path, "wb") as f:
            shutil.copyfileobj(file.file, f)
            result, _ = WAV2LIP.inference(temp_audio_path, reversed=True if reversed == "1" else False, starting_frame=starting_frame, enhance=CONFIG["use_enhancer"])
    print(result, flush=True)
    result = f"wav2lip/results/{result}.mp4"
    return FileResponse(result, media_type="video/mp4", background=bg_task.add_task(remove_file,result ))

@router.get("/test")
async def test(enhance: bool = False):
    start_time = time.time()
    result, _ = WAV2LIP.inference("data/audio.wav", reversed=True if reversed == "1" else False, starting_frame=0, enhance=enhance)
    end_time = time.time()
    print(f"Inference took {end_time - start_time} seconds", flush=True)
    print(result, flush=True)
    return JSONResponse({"message": "hi"})
 
@router.get("/config")
async def get_current_config():
    global CONFIG, DEVICES
    DEVICES = get_devices()
    config = {
        "lipsync_models": WAV2LIP_MODELS,
        "enhancer_models": ENHANCER_MODELS,
        "devices": DEVICES,
        "selected_config": CONFIG
    }
    
    return JSONResponse(content=jsonable_encoder(config))

@router.post("/inference_from_filename")
async def inference(data: dict, starting_frame: int, reversed: str, bg_task: BackgroundTasks):
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
        result, frames_generated = WAV2LIP.inference(temp_file_path, reversed=True if reversed == "1" else False, starting_frame=starting_frame, enhance=CONFIG["use_enhancer"])
    end_time = time.time()
    inference_latency = end_time - start_time
    
    # Remove audio file after response
    bg_task.add_task(remove_file, file_path)

    print(result, flush=True)
    print(f"Inference took {inference_latency} seconds", flush=True)
    return JSONResponse(
        content=jsonable_encoder({"url": result, "inference_latency": inference_latency, "frames_generated": frames_generated}),
        background=bg_task
    )

@router.post("/update_config")
async def update_config(data: Configurations):
    global WAV2LIP, CONFIG, DEVICES
    device = data.lipsync_device
    enhancer_device = data.enhancer_device

    # Validate lipsync_device
    if not is_valid_device(device, "lipsync_device", DEVICES):
        return JSONResponse(content=jsonable_encoder({"message": f"Invalid lipsync_device: {device}"}), status_code=400)

    # Validate enhancer_device if provided
    if enhancer_device and not is_valid_device(enhancer_device, "enhancer_device", DEVICES):
        return JSONResponse(content=jsonable_encoder({"message": f"Invalid enhancer_device: {enhancer_device}"}), status_code=400)

    # Initialize WAV2LIP with the validated values
    CONFIG = {
        "lipsync_model": data.lipsync_model,
        "lipsync_device": device,
        "use_enhancer": data.use_enhancer,
        "enhancer_device": enhancer_device,
        "enhancer_model": data.enhancer_model,
        "avatar_skin": data.avatar_skin
    }
    try:
        WAV2LIP = initialize_wav2lip()
        warmup()
    except Exception as error:
        logger.error(f"Error in updating device: {str(error)}")
        return JSONResponse(content=jsonable_encoder({"message": f"Failed to update device. Error: {error}"}), status_code=500)
    return JSONResponse(content=jsonable_encoder({"message": f"device updated to {device} and enhancer_device updated to {enhancer_device}"}), status_code=200)

@router.get("/video/{id}")
async def get_video(id: str, bg_task: BackgroundTasks):
    video_path = f"wav2lip/results/{id}.mp4"

    # Verify file exists
    if not os.path.exists(video_path):
        return JSONResponse(content=jsonable_encoder({"message": "file does not exist"}))
    
    return FileResponse(video_path)

app.include_router(router)

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host=os.environ.get('SERVER_HOST', "127.0.0.1"),
        port=int(os.environ.get('SERVER_PORT', "8011")),
        reload=True
    )
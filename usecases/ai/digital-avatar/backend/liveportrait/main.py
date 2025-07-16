# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from fastapi import FastAPI, UploadFile, File, APIRouter, Form
from fastapi.encoders import jsonable_encoder
from fastapi.responses import JSONResponse, FileResponse
import uvicorn
import os
import logging
import re
import shutil
import asyncio

import tyro
from liveportrait.src.config.argument_config import ArgumentConfig
from liveportrait.src.config.inference_config import InferenceConfig
from liveportrait.src.config.crop_config import CropConfig
from liveportrait.src.live_portrait_pipeline import LivePortraitPipeline
from pydantic import BaseModel

import torch
import json
import ffmpeg

logger = logging.getLogger('uvicorn.error')

TASK = None # Placeholder for task, can be set later if needed
def set_task(task):
    global TASK
    TASK = task

def partial_fields(target_class, kwargs):
    return target_class(**{k: v for k, v in kwargs.items() if hasattr(target_class, k)})

@asynccontextmanager
async def lifespan(app: FastAPI):
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

class InferenceRequest(BaseModel):
    skin_name: str
    source: str  # path to image or video

def sanitize_filename(name: str) -> str:
    # Remove invalid filename characters and spaces
    return re.sub(r'[^\w\-_.]', '_', name)

router = APIRouter(prefix="/v1",
                   responses={404: {"description": "Unable to find route"}})

def process_inference_task(sanitized_skin_name, ext, temp_path):
    set_task({
        "type": "inference",
        "skin_name": sanitized_skin_name,
        "url": f"_upload_{sanitized_skin_name}{ext}",
        "status": "IN_PROGRESS",
        "message": "File processed, creating skin...",
    })
    if ext in ['.png', '.jpg', '.jpeg', '.bmp', '.gif']:
        args = tyro.cli(ArgumentConfig)
        args.source = temp_path
        args.driving = "assets/idle.mp4"
        args.output_dir = "assets/avatar-skins"
        args.output_name = sanitized_skin_name
        inference_cfg = partial_fields(InferenceConfig, args.__dict__)
        try:
            if not torch.xpu.is_available():
                inference_cfg.flag_force_cpu = True
                inference_cfg.flag_use_half_precision = False
            else:
                from liveportrait.intel_xpu.xpu_override import xpu_override
                xpu_override()
                inference_cfg.flag_force_cpu = False
        except:
            inference_cfg.flag_force_cpu = True
            inference_cfg.flag_use_half_precision = False
        crop_cfg = partial_fields(CropConfig, args.__dict__)
        liveportrait = LivePortraitPipeline(
            inference_cfg=inference_cfg,
            crop_cfg=crop_cfg
        )
        liveportrait.execute(args)
        os.remove(temp_path)
        set_task({
            "type": "inference",
            "skin_name": sanitized_skin_name,
            "url": sanitized_skin_name + ".mp4",
            "status": "COMPLETED",
            "message": "Avatar skin created successfully.",
        })
    elif ext in ['.mp4', '.avi', '.mov', '.mkv']:
        dest_path = f"assets/avatar-skins/{sanitized_skin_name}.mp4"
        if temp_path != dest_path:
            shutil.move(temp_path, dest_path)
        else:
            dest_path = temp_path
        try:
            probe = ffmpeg.probe(dest_path)
            duration = float(probe['format']['duration'])
            if duration > 5:
                trimmed_path = dest_path + '.trimmed.mp4'
                (
                    ffmpeg
                    .input(dest_path)
                    .output(trimmed_path, t=5, codec='copy')
                    .run(overwrite_output=True)
                )
                os.replace(trimmed_path, dest_path)
        except Exception as e:
            logger.error(f"Video trimming with ffmpeg-python failed: {e}")
        set_task({
            "type": "inference",
            "skin_name": sanitized_skin_name,
            "url": sanitized_skin_name + ".mp4",
            "status": "COMPLETED",
            "message": "Avatar skin created successfully.",
        })
    else:
        os.remove(temp_path)
        set_task({
            "type": "inference",
            "skin_name": sanitized_skin_name,
            "url": None,
            "status": "FAILED",
            "message": "Unsupported file type for source.",
        })

@router.post("/inference")
async def inference(skin_name: str = Form(...), source: UploadFile = File(...)):
    try:
        set_task({
            "type": "inference",
            "skin_name": skin_name,
            "url": None,
            "status": "IN_PROGRESS",
            "message": "Processing skin upload...",
        })
        sanitized_skin_name = sanitize_filename(skin_name)
        ext = os.path.splitext(source.filename)[1].lower()
        temp_path = f"assets/avatar-skins/tmp/_upload_{sanitized_skin_name}{ext}"
        with open(temp_path, "wb") as f:
            f.write(await source.read())
        # Start the heavy task in a background thread so event loop is not blocked
        asyncio.create_task(asyncio.to_thread(process_inference_task, sanitized_skin_name, ext, temp_path))
        return JSONResponse(content=jsonable_encoder({"message": "Create avatar skin task started"}), status_code=200)
    
    except Exception as e:
        logger.error(f"Error during inference: {e}")
        set_task({
            "type": "inference",
            "skin_name": skin_name,
            "url": None,
            "status": "FAILED",
            "message": str(e),
        })
        return JSONResponse(content=jsonable_encoder({"message": f"Failed to create avatar skin. Error: {e}"}), status_code=500)        

@router.get("/get-task")
async def get_task():
    global TASK
    return JSONResponse(content=jsonable_encoder({"status": True, "data": TASK if TASK is not None else {"status": "IDLE"}}))

@router.get("/skin/{name}")
async def get_video(name: str):
    # if name starts with "_upload_", check in the tmp directory
    if name.startswith("_upload_"):
        video_path = f"assets/avatar-skins/tmp/{name}"
    else:
        video_path = f"assets/avatar-skins/{name}"

    # Verify file exists
    if not os.path.exists(video_path):
        return JSONResponse(content=jsonable_encoder({"message": "file does not exist"}))
    
    return FileResponse(video_path)

app.include_router(router)

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host=os.environ.get('SERVER_HOST', "127.0.0.1"),
        port=int(os.environ.get('SERVER_PORT', "8012")),
        reload=os.environ.get('SERVER_RELOAD', False)
    )
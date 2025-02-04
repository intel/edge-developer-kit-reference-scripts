# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from fastapi import FastAPI, UploadFile, File, APIRouter
import uvicorn
import os
import logging

import tyro
from liveportrait.src.config.argument_config import ArgumentConfig
from liveportrait.src.config.inference_config import InferenceConfig
from liveportrait.src.config.crop_config import CropConfig
from liveportrait.src.live_portrait_pipeline import LivePortraitPipeline
from pydantic import BaseModel
from typing import Optional

import torch
import json

logger = logging.getLogger('uvicorn.error')
LIVEPORTRAIT=None

def partial_fields(target_class, kwargs):
    return target_class(**{k: v for k, v in kwargs.items() if hasattr(target_class, k)})

@asynccontextmanager
async def lifespan(app: FastAPI):
    global LIVEPORTRAIT
    args = tyro.cli(ArgumentConfig)
    # specify configs for inference
    inference_cfg = partial_fields(InferenceConfig, args.__dict__)
    try:
        if not torch.xpu.is_available():
            inference_cfg.flag_force_cpu=True
            inference_cfg.flag_use_half_precision=False
        else:
            from liveportrait.intel_xpu.xpu_override import xpu_override
            xpu_override()
            inference_cfg.flag_force_cpu=False
    except:
        inference_cfg.flag_force_cpu=True
        inference_cfg.flag_use_half_precision=False

    print("Inference Device: " + ("CPU" if inference_cfg.flag_force_cpu else "XPU"))

    crop_cfg = partial_fields(CropConfig, args.__dict__)
    LIVEPORTRAIT = LivePortraitPipeline(
        inference_cfg=inference_cfg,
        crop_cfg=crop_cfg
    )
    args.source="assets/image.png"
    args.driving="assets/idle.mp4"
    args.output_dir="assets"
    
    LIVEPORTRAIT.execute(args)
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
    source: str = "assets/image.png"
    driving: str = "assets/idle.mp4"

router = APIRouter(prefix="/v1",
                   responses={404: {"description": "Unable to find route"}})

@router.post("/inference")
async def inference(data: Optional[InferenceRequest]= None):
    global LIVEPORTRAIT
    args = tyro.cli(ArgumentConfig)

    if data is not None:
        args.source=data.source
        args.driving=data.driving
    else:
        args.source="assets/image.png"
        args.driving="assets/idle.mp4"
    args.output_dir="assets"
    args.output_name="video"
    
    LIVEPORTRAIT.execute(args)
    
app.include_router(router)

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host=os.environ.get('SERVER_HOST', "0.0.0.0"),
        port=int(os.environ.get('SERVER_PORT', "8012")),
        reload=os.environ.get('SERVER_RELOAD', False)
    )
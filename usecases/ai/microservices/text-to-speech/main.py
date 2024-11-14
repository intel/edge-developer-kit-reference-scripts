# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

import sys
sys.path.append("/opt/thirdparty/MeloTTS")

import os
import uuid
# import torch
import time
# import intel_extension_for_pytorch as ipex
# import ipex_llm
from scipy.io.wavfile import write as write_wav

from contextlib import asynccontextmanager
from pydantic import BaseModel
from typing import Optional
from fastapi.responses import FileResponse
from fastapi import FastAPI, HTTPException
from starlette.background import BackgroundTasks

from melo.api import TTS

TTS_PROCESSOR = None
TTS_SPEAKER_IDS = None
TTS_DEVICE = None


def load_bark_model(language='EN', device="cpu"):
    model = TTS(language=language, device=device)
    speaker_ids = model.hps.data.spk2id
    return model, speaker_ids


def warmup(model, speaker_ids):
    print("Running model warmup ...")
    text = "How is your day today?"
    voice = "EN-US"
    output_path = "output.wav"
    model.tts_to_file(text, speaker_ids[voice], output_path, speed=1)
    os.remove(output_path)
    print("Model warmup completed ...")


def startup():
    global TTS_MODEL, TTS_SPEAKER_IDS, TTS_DEVICE
    if not os.path.exists("/tmp_audio"):
        os.makedirs("/tmp_audio")
    TTS_DEVICE = os.getenv('TTS_DEVICE').lower()
    print("Starting up model ...")
    TTS_MODEL, TTS_SPEAKER_IDS = load_bark_model(language='EN', device=TTS_DEVICE)
    warmup(TTS_MODEL, TTS_SPEAKER_IDS)


def clean_up():
    print("Cleaning up before closing.")


@asynccontextmanager
async def lifespan(app: FastAPI):
    startup()
    yield
    clean_up()

app = FastAPI(lifespan=lifespan)


class TTSData(BaseModel):
    input: str
    model: str = '-'
    voice: Optional[str] = 'EN-US'
    response_format: Optional[str] = 'wav'  # [mp3, opus, aac, flac, wav, pcm]
    speed: Optional[float] = 1.0  # [0.25 - 4.0]


class TTSModel(BaseModel):
    language: str = "EN"
    device: str = "cpu"


@app.post("/v1/audio/load_speech_model")
async def load_model(data: TTSModel):
    global TTS_MODEL, TTS_SPEAKER_IDS
    # device = "xpu" if torch.xpu.is_available() else "cpu"
    # device = "xpu"
    TTS_MODEL, TTS_SPEAKER_IDS = load_bark_model(
        language=data.language, device=data.device)


@app.post("/v1/audio/unload_speech_model")
async def unload_model():
    global TTS_MODEL, TTS_SPEAKER_IDS
    TTS_MODEL = None
    TTS_SPEAKER_IDS = None


@app.post("/v1/audio/speech")
async def speech_to_text(data: TTSData, bg_task: BackgroundTasks):
    global TTS_MODEL, TTS_SPEAKER_IDS
    async def remove_file(file_name):
        if os.path.exists(file_name):
            try:
                os.remove(file_name)
            except:
                print(f"File: {file_name} not available")

    if data.voice == "":
        data.voice = "EN-US"

    if TTS_MODEL == None or TTS_SPEAKER_IDS == None:
        raise HTTPException(
            status_code=403, detail="Model is not loaded. Please call the /v1/")

    output_path = f"/tmp_audio/{str(uuid.uuid4())}.wav"

    start_time = time.time()
    TTS_MODEL.tts_to_file(
        data.input, TTS_SPEAKER_IDS[data.voice], output_path, speed=data.speed)
    elapsed_time = time.time() - start_time
    print(f"Inference time: {elapsed_time:.2} secs")

    if os.path.isfile(output_path):
        return FileResponse(output_path, media_type="audio/wav", background=bg_task.add_task(remove_file, output_path))
    else:
        raise HTTPException(
            status_code=500, detail="Error in getting the generated output wav.")

@app.get('/healthcheck', status_code=200)
def get_healthcheck():
    return 'OK'

@app.get("/")
async def root():
    return {"message": "Hello World"}

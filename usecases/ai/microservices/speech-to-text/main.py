# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

import whisper
import os
import io
import uuid
import openvino as ov
import logging
from pathlib import Path
import soundfile as sf
import json
from typing import Optional
from fastapi import FastAPI, UploadFile, Form, File, HTTPException
from contextlib import asynccontextmanager
from utils import (
    load_stt_model,
    inference_transcribe,
    inference_translate
)
from pydub import AudioSegment
from fastapi.middleware.cors import CORSMiddleware

logger = logging.getLogger('uvicorn.error')
ASR_MODEL = None
MODEL_ID = None


def clean_up():
    print("Cleaning up before closing")


@asynccontextmanager
async def lifespan(app: FastAPI):
    global ASR_MODEL, MODEL_ID
    if not os.path.exists("/tmp_audio"):
        os.makedirs("/tmp_audio", exist_ok=True)
    MODEL_ID = os.getenv("STT_MODEL_ID")
    ASR_MODEL = load_stt_model(model_id=MODEL_ID, 
                        encoder_device=os.getenv("STT_ENCODED_DEVICE"),
                        decoder_device=os.getenv("STT_DECODED_DEVICE"))
    yield
    clean_up()


allowed_cors =  json.loads(os.getenv("ALLOWED_CORS", '["http://localhost"]'))
app = FastAPI(lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_cors,
    allow_credentials=True,
    allow_methods=['*'],
    allow_headers=['*'],
)

@app.post("/v1/audio/transcriptions")
async def stt_transcription(file: UploadFile = File(...), language: Optional[str] = Form(None)):
    global ASR_MODEL
    try:
        if file.filename:
            file_name, _ = os.path.splitext(file.filename)
            input_file_path = f"/tmp_audio/{file_name}.webm"
        else:
            unique_filename = str(uuid.uuid4())
            input_file_path = f"/tmp_audio/{unique_filename}.webm"
        with open(input_file_path, 'wb') as f:
            f.write(file.file.read())
        file_path = f"/tmp_audio/{file_name}.wav"
        audio = AudioSegment.from_file(input_file_path,format="webm")

        audio.export(file_path, format="wav")
        # _audio_byte = file_path.read()
        # audio_byte = io.BytesIO(_audio_byte)
        text = inference_transcribe(
            model=ASR_MODEL,
            audio=file_path,
            language=language
        )

    except Exception as error:
        logger.error(f"Error in STT transcriptions: {str(error)}")
        raise HTTPException(
            status_code=500, detail=f"Failed to transcribe the voice input. Error: {error}")

    return {"text": text, 'status': True}


@app.post("/v1/audio/translations")
async def stt_translation(file: UploadFile = File(...), language: Optional[str] = Form(None)):
    global ASR_MODEL
    try:
        _audio_byte = file.file.read()
        audio_byte = io.BytesIO(_audio_byte)
        text = inference_translate(
            model=ASR_MODEL,
            audio=audio_byte,
            language=language
        )

    except Exception as error:
        logger.error(f"Error in STT translations: {str(error)}")
        raise HTTPException(
            status_code=500, detail=f"Failed to translate the voice input. Error: {error}")

    return {"text": text, 'status': True}

@app.get('/healthcheck', status_code=200)
def get_healthcheck():
    return 'OK'

@app.get("/")
async def read_root():
    return {"Hello": "World"}

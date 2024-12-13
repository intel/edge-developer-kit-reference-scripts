# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

import os
import json
import uuid
import logging
from typing import Optional
from pydub import AudioSegment

from fastapi import FastAPI, UploadFile, Form, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from utils import (
    download_default_model,
    load_model_pipeline,
    transcribe,
    translate
)

logger = logging.getLogger('uvicorn.error')
ASR_PIPELINE = None
DEFAULT_MODEL_ID = os.getenv("DEFAULT_MODEL_ID", "openai/whisper-tiny")
DEVICE = os.getenv("STT_DEVICE", "CPU")
TEMP_AUDIO_DIR = "./tmp_audio"
MODEL_DIR = "./data/models/ov_asr"


def clean_up():
    logger.info("Shutting down server ...")


@asynccontextmanager
async def lifespan(app: FastAPI):
    global ASR_PIPELINE, DEFAULT_MODEL_ID
    logger.info("Starting server ...")
    if not os.path.exists(TEMP_AUDIO_DIR):
        os.makedirs(TEMP_AUDIO_DIR, exist_ok=True)

    if not os.path.exists(MODEL_DIR):
        logger.info("Model not found. Downloading default model ...")
        download_default_model(DEFAULT_MODEL_ID, MODEL_DIR)

    ASR_PIPELINE = load_model_pipeline(MODEL_DIR, device=DEVICE)
    yield
    clean_up()

allowed_cors = json.loads(os.getenv("ALLOWED_CORS", '["*"]'))
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


@app.post("/v1/audio/transcriptions")
async def stt_transcription(file: UploadFile = File(...), language: Optional[str] = Form(None)):
    global ASR_PIPELINE
    try:
        if file.filename:
            file_name, _ = os.path.splitext(file.filename)
            input_file_path = f"{TEMP_AUDIO_DIR}/{file_name}.webm"
        else:
            unique_filename = str(uuid.uuid4())
            input_file_path = f"{TEMP_AUDIO_DIR}/{unique_filename}.webm"

        with open(input_file_path, 'wb') as f:
            f.write(file.file.read())

        file_path = f"{TEMP_AUDIO_DIR}/{file_name}.wav"
        audio = AudioSegment.from_file(input_file_path, format="webm")
        audio.export(file_path, format="wav")

        if language == None:
            logger.warning("Language is not set. Default to english.")
            language = "english"

        text = transcribe(
            pipeline=ASR_PIPELINE,
            audio=file_path,
            language=language
        )

    except Exception as error:
        logger.error(f"Error in STT transcriptions: {str(error)}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to transcribe the voice input. Error: {error}"
        )

    return {"text": text, 'status': True}


@app.post("/v1/audio/translations")
async def stt_translation(file: UploadFile = File(...), language: Optional[str] = Form(None)):
    global ASR_MODEL
    try:
        if file.filename:
            file_name, _ = os.path.splitext(file.filename)
            input_file_path = f"{TEMP_AUDIO_DIR}/{file_name}.webm"
        else:
            unique_filename = str(uuid.uuid4())
            input_file_path = f"{TEMP_AUDIO_DIR}/{unique_filename}.webm"

        with open(input_file_path, 'wb') as f:
            f.write(file.file.read())

        file_path = f"{TEMP_AUDIO_DIR}/{file_name}.wav"
        audio = AudioSegment.from_file(input_file_path, format="webm")
        audio.export(file_path, format="wav")

        if language == None:
            logger.warning("Language is not set. Default to english.")
            language = "english"

        text = translate(
            pipeline=ASR_PIPELINE,
            audio=file_path,
            source_language=language
        )

    except Exception as error:
        logger.error(f"Error in STT translations: {str(error)}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to translate the voice input. Error: {error}"
        )

    return {"text": text, 'status': True}

# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

from fastapi import FastAPI, HTTPException
from piper.voice import PiperVoice
from urllib.request import urlretrieve
import wave
import io
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse, JSONResponse
from contextlib import asynccontextmanager
from typing import Optional
import json

import uvicorn
import os
from pydantic import BaseModel
from uuid import uuid4

PIPERTTS={
}
DOWNLOAD_URL=f"https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0"
MODEL_DIRECTORY="models"
DATA_DIRECTORY="data"

class ISynthesize(BaseModel):
    text: str
    length_scale: Optional[float] = 1
    speaker:Optional[str] = "female"
    keep_file: Optional[bool] = False

@asynccontextmanager
async def lifespan(app: FastAPI):
    global PIPERTTS
    model_paths = {
        "female": "en/en_US/hfc_female/medium/en_US-hfc_female-medium", 
        "male": "en/en_US/hfc_male/medium/en_US-hfc_male-medium"
        }

    if not os.path.exists(MODEL_DIRECTORY):
        os.makedirs(MODEL_DIRECTORY)

    if not os.path.exists(DATA_DIRECTORY):
        os.makedirs(DATA_DIRECTORY)
    
    for key, value in model_paths.items():
        model_name = value.split("/")[-1]
        
        # Download the model file if it doesn't exist
        model_file_path = os.path.join(MODEL_DIRECTORY, f"{model_name}.onnx")
        if not os.path.exists(model_file_path):
            model_download_path = f"{DOWNLOAD_URL}/{value}.onnx"
            urlretrieve(f"{model_download_path}", model_file_path)  # nosec --http file
        
        # Download the model config file if it doesn't exist
        model_config_file_path = os.path.join(MODEL_DIRECTORY, f"{model_name}.onnx.json")
        if not os.path.exists(model_config_file_path):
            model_config_path = f"{DOWNLOAD_URL}/{value}.onnx.json"
            urlretrieve(f"{model_config_path}", model_config_file_path)  # nosec --http file

        voice = PiperVoice.load(os.path.join(MODEL_DIRECTORY, f"{model_name}.onnx"))
        PIPERTTS[key] = voice
    yield

allowed_cors =  json.loads(os.getenv("ALLOWED_CORS", '["http://localhost:3000"]'))
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

@app.post("/v1/audio/speech")
async def synthesize(data: ISynthesize):
    global PIPERTTS
    if data.speaker not in PIPERTTS:
        raise HTTPException(status_code=404, detail=f"Speaker {data.speaker} not found")
    try:
        wav_io = io.BytesIO()
        with wave.open(wav_io, "wb") as wav_file:
            PIPERTTS[data.speaker].synthesize(data.text, wav_file, length_scale=data.length_scale)
        wav_io.seek(0)
        if data.keep_file:
            filename =f"{uuid4()}.wav"
            with open(f"{DATA_DIRECTORY}/{filename}", "wb") as f:
                f.write(wav_io.read())
            return JSONResponse(content={"filename": filename})
        else:
            return StreamingResponse(wav_io, media_type="audio/wav")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host=os.environ.get('SERVER_HOST', "0.0.0.0"),
        port=int(os.environ.get('SERVER_PORT', "8013")),
        reload=True
    )
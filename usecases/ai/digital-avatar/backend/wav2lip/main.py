from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from fastapi.responses import FileResponse
from fastapi import FastAPI, UploadFile, File, APIRouter
import tempfile
import uvicorn
import os
import shutil
import logging
from starlette.background import BackgroundTasks
from wav2lip.ov_wav2lip import OVWav2Lip
import wave
import numpy as np
import json

logger = logging.getLogger('uvicorn.error')
WAV2LIP=None
@asynccontextmanager
async def lifespan(app: FastAPI):
    global WAV2LIP
    WAV2LIP = OVWav2Lip(device="CPU", avatar_path="assets/video.mp4")

    print("warming up")
    temp_filename = "empty.wav"
    with wave.open(temp_filename, "w") as wf:
        wf.setnchannels(1)  # mono
        wf.setsampwidth(2)  # 2 bytes per sample
        wf.setframerate(16000)  # 16 kHz
        wf.writeframes(np.zeros(16000 * 2, dtype=np.int16).tobytes())  # 1 second of silence

    result= WAV2LIP.inference(temp_filename)
    if os.path.exists(result):
        os.remove(result)
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
async def inference(bg_task: BackgroundTasks, file: UploadFile=File(...) ):
    async def remove_file(file_name):
        if os.path.exists(file_name):
            try:
                os.remove(file_name)
            except:
                logger.error(f"File: {file_name} not available")

    global WAV2LIP
    if not file.filename.endswith(".wav"):
        return "Only .wav files are allowed"
    
    with tempfile.NamedTemporaryFile(suffix=".wav") as temp_audio:
        temp_audio_path = temp_audio.name
        with open(temp_audio_path, "wb") as f:
            shutil.copyfileobj(file.file, f)
            result = WAV2LIP.inference(temp_audio_path)
    print(result, flush=True)
    return FileResponse(result, media_type="video/mp4", background=bg_task.add_task(remove_file, result))

app.include_router(router)

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host=os.environ.get('SERVER_HOST', "0.0.0.0"),
        port=int(os.environ.get('SERVER_PORT', "8011")),
        reload=True
    )
# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

import os
os.environ['HF_HOME'] = "./data/huggingface"

import logging
import requests
import numpy as np
import multiprocessing
import asyncio
from contextlib import asynccontextmanager
from typing_extensions import TypedDict, Required
from typing import List, Union, Optional

from openai import OpenAI

import uvicorn
from pydantic import BaseModel
from fastapi.responses import JSONResponse, StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi import FastAPI, UploadFile, HTTPException, Request
from fastapi.encoders import jsonable_encoder
import magic

from utils.prompt import RAG_PROMPT, NO_CONTEXT_FOUND_PROMPT
from utils.chroma_client import ChromaClient
import openvino as ov

from urllib.parse import urlparse

logger = logging.getLogger('uvicorn.error')

OPENAI_BASE_URL = os.environ.get("OPENAI_BASE_URL", "http://localhost:8012/v1")
CHROMA_CLIENT = None
VECTORDB_DIR = "./data/embeddings"
DOCSTORE_DIR = "./data/embeddings/documents"

class ICreateChatCompletions(TypedDict, total=False):
    messages: Required[List]
    model: str
    tools: List
    endpoint: str
    suffix: str
    max_tokens: int = 16
    temperature: Union[int, float] = 1
    top_p: Union[int, float] = 1
    n: int = 1
    stream: bool = False
    logprobs: int
    echo: bool = False
    stop: Union[str, List[str]]
    presence_penalty: float = 0
    frequency_penalty: float = 0
    best_of: int
    logit_bias: dict[str, float]
    user: str
    top_k: int = -1
    ignore_eos: bool = False
    use_beam_search: bool = False
    stop_token_ids: List[int]
    skip_special_tokens: bool = True
    
class IModel(TypedDict):
    model: str
    
DEVICES = []
EMBEDDING_DEVICE = os.environ.get('EMBEDDING_DEVICE', "CPU")
RERANKER_DEVICE = os.environ.get('RERANKER_DEVICE', "CPU")
CONFIG = {
    "llm_model": os.environ.get('LLM_MODEL', "qwen2.5"),
    "system_prompt": os.environ.get('SYSTEM_PROMPT', "You are a helpful assistant. Always reply in English. Summarize content to be 100 words"),
    "temperature": 1,
    "max_tokens": 2048,
    "use_rag": os.environ.get('USE_RAG', True),
    "embedding_device": EMBEDDING_DEVICE,
    "reranker_device": RERANKER_DEVICE
}

class Configurations(BaseModel):
    llm_model: str
    system_prompt: str
    temperature: float
    max_tokens: int
    use_rag: Optional[bool] = False
    embedding_device: Optional[str] = EMBEDDING_DEVICE
    reranker_device: Optional[str] = RERANKER_DEVICE
    
def get_available_devices():
    devices = []
    core = ov.Core()
    available_devices = core.get_available_devices()
    for device_name in available_devices:
        full_device_name = core.get_property(device_name, "FULL_DEVICE_NAME")
        devices.append(
            {
                "name": full_device_name, 
                "value": device_name, 
            })
    return devices

def get_models():
    base_url = OPENAI_BASE_URL
    if "/v1" in base_url:
        base_url = base_url.replace("/v1", "")
    try:
        url = urlparse(f"{base_url}/api/tags")
        response = requests.get(url)
        response.raise_for_status()
        return response.json()
    except Exception as e:
        logger.error(f"Failed to fetch models: {e}")
        return {"models": []}

@asynccontextmanager
async def lifespan(app: FastAPI):
    global CHROMA_CLIENT, DEVICES
    logger.info("Initializing server services ...")
    DEVICES = get_available_devices()
    if (CONFIG['use_rag']):
        # Validate embedding_device and reranker_device
        device_values = [d['value'] for d in DEVICES]
        if CONFIG["embedding_device"] not in device_values:
            logger.error(f"Embedding device {CONFIG['embedding_device']} not found in available devices: {device_values}")
            raise HTTPException(status_code=400, detail=f"Embedding device {CONFIG['embedding_device']} not available.")
        if CONFIG["reranker_device"] not in device_values:
            logger.error(f"Reranker device {CONFIG['reranker_device']} not found in available devices: {device_values}")
            raise HTTPException(status_code=400, detail=f"Reranker device {CONFIG['reranker_device']} not available.")
        CHROMA_CLIENT = ChromaClient(VECTORDB_DIR, CONFIG["embedding_device"], CONFIG["reranker_device"])

    # Check if LLM model exist in list of models
    model_list = get_models().get("models", [])
    model_names = [m.get("name") for m in model_list]
    # If it doesn't exist, pull the model
    if CONFIG["llm_model"] not in model_names:
        logger.info(f"Model {CONFIG['llm_model']} not found. Pulling the model ...")
        response = await pull_model({"model": CONFIG["llm_model"]})
        if response.status_code != 200:
            logger.error(f"Failed to pull model {CONFIG['llm_model']}. Error: {response.text}")
            raise HTTPException(status_code=500, detail="Failed to pull model")
    yield
    logger.info("Stopping server services ...")


app = FastAPI(lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=['*'],
    allow_headers=['*']
)


@app.get('/healthcheck', status_code=200)
def get_healthcheck():
    return 'OK'

@app.get("/v1/config")
async def get_inference_devices():
    global DEVICES, CONFIG
    DEVICES = get_available_devices()
    config ={
        "devices": DEVICES,
        "selected_config": CONFIG
    }
    return JSONResponse(content=jsonable_encoder(config))

@app.get("/v1/models", status_code=200)
async def get_available_model():
    models = get_models()
    return JSONResponse(content=jsonable_encoder(models))

# RAG Routes
@app.get("/v1/rag/text_embeddings", status_code=200)
async def get_text_embeddings(page: Optional[int] = 1, pageSize: Optional[int] = 5, source: Optional[str] = ""):
    global CHROMA_CLIENT
    data = CHROMA_CLIENT.get_all_collection_data(page, pageSize, source)
    result = {"status": True, "data": data}
    return JSONResponse(content=jsonable_encoder(result))


@app.get("/v1/rag/text_embedding_sources", status_code=200)
async def get_text_embedding_sources():
    global CHROMA_CLIENT
    data = CHROMA_CLIENT.get_all_sources()
    result = {"status": True, "data": data}
    return JSONResponse(content=jsonable_encoder(result))

@app.post("/v1/update_config", status_code=200)
async def update_config(data: Configurations):
    global CONFIG, CHROMA_CLIENT
    
    # Check if LLM model exist in list of models
    model_list = get_models().get("models", [])
    model_names = [m.get("name") for m in model_list]
    # If it doesn't exist, pull the model
    if data.llm_model not in model_names:
        logger.info(f"Model {data.llm_model} not found. Pulling the model ...")
        response = await pull_model({"model": data.llm_model})
        if response.status_code != 200:
            logger.error(f"Failed to pull model {data.llm_model}. Error: {response.text}")
            raise HTTPException(status_code=500, detail="Failed to pull model")

    CONFIG = {
        "llm_model": data.llm_model,
        "system_prompt": data.system_prompt,
        "temperature": data.temperature,
        "max_tokens": data.max_tokens,
        "use_rag": data.use_rag,
        "embedding_device": data.embedding_device,
        "reranker_device": data.reranker_device
    }

    if (CONFIG['use_rag']):
        # Validate embedding_device and reranker_device
        device_values = [d['value'] for d in DEVICES]
        if data.embedding_device not in device_values:
            logger.error(f"Embedding device {data.embedding_device} not found in available devices: {device_values}")
            raise HTTPException(status_code=400, detail=f"Embedding device {data.embedding_device} not available.")
        if data.reranker_device not in device_values:
            logger.error(f"Reranker device {data.reranker_device} not found in available devices: {device_values}")
            raise HTTPException(status_code=400, detail=f"Reranker device {data.reranker_device} not available.")
        CHROMA_CLIENT = ChromaClient(VECTORDB_DIR, data.embedding_device, data.reranker_device)

    result = {"status": True, "data": None}
    return JSONResponse(content=jsonable_encoder(result))

@app.post("/v1/pull", status_code=200)
async def pull_model(data: IModel):
    model = data['model']
    base_url = os.environ.get("OPENAI_BASE_URL", "http://localhost:8012/v1")
    if "/v1" in base_url:
        base_url = base_url.replace("/v1", "")
        
    # response = requests.post(f"{base_url}/api/pull", json={"model": model}, stream=True)
    
    # def stream_response():
    #     for chunk in response.iter_content(chunk_size=8192):
    #         if chunk:
    #             yield chunk
    
    # return StreamingResponse(stream_response(), media_type="application/json")
    url = urlparse(f"{base_url}/api/pull")

    response = requests.post(url, json={"model": model, "stream": False})
    return JSONResponse(content=jsonable_encoder({"status": True, "data": response.json()}))

@app.delete("/v1/rag/text_embeddings/{uuid}", status_code=200)
async def delete_text_embeddings(uuid: str):
    global CHROMA_CLIENT
    data = CHROMA_CLIENT.delete_data(uuid)
    result = {"status": True, "data": data}
    return JSONResponse(content=jsonable_encoder(result))


@app.delete("/v1/rag/text_embeddings/source/{source}", status_code=200)
async def delete_text_embeddings(source: str):
    global CHROMA_CLIENT
    source_path = f"../data/embeddings/documents/{source}"
    try:
        if os.path.isfile(source_path):
            logger.info(f"Removing the source file: {source_path}")
            os.remove(source_path)
        data = CHROMA_CLIENT.delete_data_by_source(source)
        result = {"status": True, "data": data}
    except Exception as error:
        result = {"status": False, "data": None, "detail": error}
    return JSONResponse(content=jsonable_encoder(result))


TASK = None  # Placeholder for task, can be set later if needed
def set_task(task):
    global TASK
    TASK = task

@app.post("/v1/rag/text_embeddings", status_code=200)
async def upload_rag_doc(chunk_size: int, chunk_overlap: int, files: List[UploadFile] = [UploadFile(...)]):
    global CHROMA_CLIENT
    ALLOWED_MIME_TYPES = ['application/pdf', 'text/plain']
    file_list = []
    processed_list = []
    set_task({
        "type": "rag_embedding",
        "status": "IN_PROGRESS",
        "message": "Processing file upload...",
        "data": None
    })
    for file in files:
        # Read a small chunk to check the mime type
        sample = await file.read(2048)
        mime_type = magic.from_buffer(sample, mime=True)
        await file.seek(0)  # Reset file pointer
        if mime_type not in ALLOWED_MIME_TYPES:
            logger.warning(f"{file.filename} is not the supported type. Detected mime: {mime_type}")
            continue
        else:
            file_list.append(file)

    if len(file_list) == 0:
        logger.error("No file is able to use to create text embeddings.")
        set_task({
            "type": "rag_embedding",
            "status": "FAILED",
            "message": "No file is able to use to create text embeddings.",
            "data": None
        })
        raise HTTPException(
            status_code=400, detail="No file is able to use to create text embeddings.")

    if not os.path.isdir(DOCSTORE_DIR):
        os.makedirs(DOCSTORE_DIR, exist_ok=True)

    for file in file_list:
        with open(f"{DOCSTORE_DIR}/{file.filename}", "wb") as f:
            processed_list.append(file.filename)
            f.write(file.file.read())

    # Start the heavy task in a background thread so event loop is not blocked
    asyncio.create_task(asyncio.to_thread(process_rag_embedding_task, processed_list, chunk_size, chunk_overlap))
    return JSONResponse(content=jsonable_encoder({"message": "Create RAG embedding task started"}), status_code=200)

def process_rag_embedding_task(processed_list, chunk_size, chunk_overlap):
    global CHROMA_CLIENT
    try:
        # Create a TaskFile object for each file
        task_files = [
            {
                "filename": filename,
                "status": "PENDING",
                "message": "Waiting to process...",
            }
            for filename in processed_list
        ]
        def update_task():
            set_task({
                "type": "rag_embedding",
                "status": "IN_PROGRESS",
                "message": "Processing files...",
                "data": task_files
            })
        update_task()
        CHROMA_CLIENT.create_collection_data(
            processed_list, chunk_size, chunk_overlap, progress_callback=update_task, task_files=task_files
        )
        set_task({
            "type": "rag_embedding",
            "status": "COMPLETED",
            "message": "Text embeddings created successfully.",
            "data": task_files
        })
    except Exception as e:
        logger.error(f"Error during RAG embedding creation: {e}")
        set_task({
            "type": "rag_embedding",
            "status": "FAILED",
            "message": "Failed to create text embeddings.",
            "data": []
        })

@app.get("/v1/rag/text_embeddings/task", status_code=200)
async def get_rag_embedding_task():
    global TASK
    return JSONResponse(content=jsonable_encoder({"status": True, "data": TASK if TASK is not None else {"status": "IDLE"}}))


# Chat completions routes
@app.post("/v1/chat", status_code=200)
async def chat_completion(request: Request, data: ICreateChatCompletions):
    global CHROMA_CLIENT

    def _streamer():
        for chunk in llm.iter_content(chunk_size=1024):
            yield (chunk)

    def _verify_embeddings_available():
        num_embeddings = CHROMA_CLIENT.get_num_embeddings()
        logger.info(f"Number of embeddings available: {num_embeddings}")
        if num_embeddings == 0:
            return False
        return True

    def _get_high_score_context(data, threshold):
        return [elem for elem in data if elem['score'] > threshold]

    def _formatting_rag_fusion_result(retrieval_list, query):
        context = ""
        for i, item in enumerate(retrieval_list):
            document = item['document']
            score = np.array(item['score']) * 100
            context += f"Context {i+1}: {document}.\nScore: {score:.2}."
            if i < len(retrieval_list) - 1:
                context += "\n\n"

        formatted_prompt = RAG_PROMPT.format(
            context=context,
            question=query
        )
        return formatted_prompt

    isRAG = CONFIG['use_rag']

    if not any(message['role'] == 'system' for message in data['messages']):
        systemPrompt = CONFIG['system_prompt']
        if systemPrompt:
            data['messages'] = [{'role': 'system', 'content': systemPrompt}] + data['messages']

    if isRAG:
        logger.info("RAG settings is enabled. Verifying embedding is available")
        isEmbeddings = _verify_embeddings_available()
        if isEmbeddings:
            last_user_message = data['messages'][-1]['content']
            logger.info("Setting the temperature to 0.01 for RAG")
            data['temperature'] = 0.01

            reranker_results = CHROMA_CLIENT.query_data(last_user_message)
            if len(reranker_results) == 0:
                logger.error(
                    "Failed to retrieve contexts for RAG. Default to use normal message without RAG")
            else:
                filtered_results = _get_high_score_context(reranker_results, 0)
                if len(filtered_results) > 0:
                    logger.info("Successfully retrieve contexts for RAG")
                    user_prompt = _formatting_rag_fusion_result(
                        filtered_results, last_user_message)
                else:
                    logger.info("Failed to retrieve contexts for RAG")
                    user_prompt = NO_CONTEXT_FOUND_PROMPT.format(
                        question=last_user_message)
                data['messages'][-1]['content'] = user_prompt

    # Set the configurations for the LLM model
    data['model'] = CONFIG['llm_model']
    data['temperature'] = CONFIG['temperature']
    data['max_tokens'] = CONFIG['max_tokens']

    base_url = OPENAI_BASE_URL
    if "/v1" in base_url:
        base_url = base_url.replace("/v1", "")
    endpoint = data.get(
        'endpoint', f"{base_url}/api/chat")
    
    try:
        llm = requests.post(
            endpoint,
            json=data,
            stream=True
        )
    except Exception as error:
        logger.error(
            f"Error while proxying to serving services. Error: {error}")
        raise HTTPException(
            status_code=400, detail="Error while proxying to serving services")

    return StreamingResponse(_streamer(), media_type="text/event-stream")


if __name__ == "__main__":
    multiprocessing.freeze_support()
    uvicorn.run(
        app,
        host=os.environ.get('SERVER_HOST', "127.0.0.1"),
        port=int(os.environ.get('SERVER_PORT', "8012"))
    )

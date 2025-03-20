# Copyright (C) 2025 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

import time
import openvino as ov
import gc
import threading

from pathlib import Path
from functools import wraps
import os
from cmd_helper import optimum_cli
import base64
import io
from PIL import Image

from pydantic import BaseModel
from fastapi import FastAPI, HTTPException, Response, BackgroundTasks
from contextlib import asynccontextmanager
import uvicorn

from optimum.intel.openvino import OVModelForVisualCausalLM
from transformers import AutoProcessor


# -------------------------------------------------------------------------
# Utility Decorator
# -------------------------------------------------------------------------
def log_elapsed_time(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        start_time = time.time()
        print(f"Starting: {func.__name__}")
        result = func(*args, **kwargs)
        elapsed_time = time.time() - start_time
        print(f"Finished: {func.__name__} in {elapsed_time:.2f} seconds.")
        return result
    return wrapper


# -------------------------------------------------------------------------
# Main Class for Flux.1 Schnell
# -------------------------------------------------------------------------
class Pixtral_12B:
    def __init__(self, quantize=False):
        self.quantize = quantize
        self.model_name = "mistral-community/pixtral-12b"
        self.model_dir = Path("models")

        # Automatically convert models during initialization
        print("Converting models during initialization...")
        try:
            self.convert_models()
            print("Model conversion completed successfully.")
        except Exception as e:
            print(f"Model conversion failed: {e}")
            raise

        # Automatically prepare the pipeline during initialization
        self.ov_pipe = None
        self.processor = None
        try:
            self.prepare_pipeline()
        except Exception as e:
            print(f"Pipeline preparation failed: {e}")
            raise

    @log_elapsed_time
    def convert_models(self):
        """Convert PyTorch models to OpenVINO IR (if not already done)."""
        if not self.model_dir.exists():
            print(f"Downloading model: {self.model_name} to {self.model_dir}...")
            additional_args = {}
            additional_args.update({"weight-format": "int4"})
            optimum_cli(self.model_name, self.model_dir, additional_args=additional_args)
        print("Model conversion completed.")

    @staticmethod
    def get_device(user_device=None):
        try:
            ov_core = ov.Core()
            available_devices = [device.upper() for device in ov_core.available_devices]  # Normalize device names
            print(f"Available devices: {available_devices}")

            # Normalize user input and validate it
            if user_device:
                user_device = user_device.upper()
                if user_device in ["CPU", "GPU"]:
                    if user_device in available_devices:
                        print(f"User-specified device '{user_device}' is available. Using it.")
                        return "success", user_device
                    else:
                        error_message = f"User-specified device '{user_device}' is not available."
                        print(error_message)
                        return "error", error_message
                else:
                    error_message = f"Invalid device specified: '{user_device}'. Supported devices are 'CPU' and 'GPU'."
                    print(error_message)
                    return "error", error_message

            # Auto-select the best available device
            if "GPU" in available_devices:
                print("Automatically selecting GPU as the best available device.")
                return "success", "GPU"
            elif "CPU" in available_devices:
                print("Automatically selecting CPU as the fallback device.")
                return "success", "CPU"
            else:
                error_message = "Neither GPU nor CPU is available. Check your OpenVINO installation and device support."
                print(error_message)
                return "error", error_message
        except Exception as e:
            error_message = f"Unexpected error occurred: {str(e)}"
            print(error_message)
            return "error", error_message

    @log_elapsed_time
    def prepare_pipeline(self, device=None):
        # Determine the device to use
        status, selected_device_or_message = self.get_device(user_device=device)
        if status == "error":
            # Log and return the error response
            print(f"Error while selecting device: {selected_device_or_message}")
            return {"status": "error", "message": selected_device_or_message}


        # Clear previous pipeline and perform garbage collection
        if hasattr(self, 'ov_pipe') and self.ov_pipe is not None:
            print("Releasing resources from the previous pipeline...")
            del self.ov_pipe
            gc.collect()

        if hasattr(self, 'processor') and self.processor is not None:
            print("Releasing resources from the previous pipeline...")
            del self.processor
            gc.collect()

        print(f"Preparing OpenVINO pipeline on {selected_device_or_message}...")
        try:
            self.processor = AutoProcessor.from_pretrained(self.model_dir)
            self.ov_pipe = OVModelForVisualCausalLM.from_pretrained(
                self.model_dir, device=selected_device_or_message.lower()
            )
            success_message = f"Pipeline prepared successfully on {selected_device_or_message}."
            print(success_message)
            return {"status": "success", "message": success_message}
        except Exception as e:
            # Log initialization errors and return an error response
            error_message = f"Error while preparing the pipeline: {e}"
            print(error_message)
            return {"status": "error", "message": error_message}

    @staticmethod
    def _resize_with_aspect_ratio(image: Image, dst_height=512, dst_width=512):
        width, height = image.size
        if width > dst_width or height > dst_height:
            im_scale = min(dst_height / height, dst_width / width)
            resize_size = (int(width * im_scale), int(height * im_scale))
            return image.resize(resize_size)
        return image

    @log_elapsed_time
    def run_pipeline(self, image, question, max_tokens=50):
        print("Running inference...")

        messages = [
            {
                "role": "user",
                "content": [
                    {"type": "text", "content": question},
                    {"type": "image"},
                ],
            }
        ]

        text = self.processor.apply_chat_template(messages, add_generation_prompt=True, tokenize=False)
        resized_image = self._resize_with_aspect_ratio(image)

        try:
            inputs = self.processor(text=text, images=[resized_image], return_tensors="pt")
            generate_ids = self.ov_pipe.generate(
                **inputs, do_sample=False, max_new_tokens=max_tokens
            )
            output = self.processor.batch_decode(generate_ids, skip_special_tokens=True)[0]

            if output.startswith(question):
                output = output[len(question):].strip()

            print("Inference completed.")
            return {"status": "success", "message": "Inference completed successfully.", "output": output}
        except Exception as e:
            return {"status": "error", "message": f"Inference failed: {e}", "output": None}



# -------------------------------------------------------------------------
# FastAPI - REST API
# -------------------------------------------------------------------------


class DeviceRequest(BaseModel):
    device: str

class PromptRequest(BaseModel):
    image_path: str = None
    image_base64: str = None
    question: str = None
    max_tokens: int = 50

class API:
    def __init__(self):
        self.installer = Pixtral_12B(quantize=True)
        self._answer = ""  # Initialize with an underscore to indicate it's a protected attribute
        self.lock = threading.Lock()  # Initialize the lock

        # Define the application with lifespan context
        self.app = FastAPI(lifespan=self.lifespan)

        # Register routes explicitly
        self.app.add_api_route(
            "/pipeline/select-device", self.select_device_and_compile, methods=["POST"]
        )
        self.app.add_api_route("/pipeline/run", self.run_pipeline, methods=["POST"])
        self.app.add_api_route("/pipeline/status", self.check_pipeline_status, methods=["GET"])
        self.app.add_api_route("/pipeline/answer", self.get_answer, methods=["GET"])
        self.app.add_api_route("/health", self.health_check, methods=["GET"])

    def check_pipeline_status(self):
        return False if self.lock.locked() else True

    @asynccontextmanager
    async def lifespan(self, app: FastAPI):
        """Lifespan context manager for resource initialization and cleanup."""
        print("Starting application and initializing resources...")
        # Initialization logic (if needed) goes here
        yield
        print("Application is shutting down. Cleaning up resources...")
        if hasattr(self.installer, "ov_pipe") and self.installer.ov_pipe:
            del self.installer.ov_pipe
        gc.collect()
        print("Resources cleaned up successfully.")

    def prepare_pipeline(self, device: str):
        # Validate and select the device
        status, device_or_message = self.installer.get_device(user_device=device)

        if status == "error":
            # Return an error response with the message from _get_device
            return {"status": "error", "message": device_or_message}

        try:
            # Prepare the pipeline on the validated device
            self.installer.prepare_pipeline(device=device_or_message)
            return {"status": "success", "message": f"Pipeline prepared on {device_or_message}."}
        except Exception as e:
            # Return a structured error response in case of an exception
            return {"status": "error", "message": f"Pipeline preparation failed: {str(e)}"}

    def select_device_and_compile(self, request: DeviceRequest):
        return self.prepare_pipeline(device=request.device)

    @property
    def answer(self):
        return self._answer

    @answer.setter
    def answer(self, value):
        self._answer = value

    @staticmethod
    def pipeline_task(installer, image, question, max_tokens, api_instance):
        with api_instance.lock:
            try:
                response = installer.run_pipeline(image, question, max_tokens)
                if response["status"] == "success":
                    api_instance._answer = response["output"]  # Directly set the protected attribute
            except Exception as e:
                print(f"Pipeline execution failed: {e}")

    @staticmethod
    def _decode_image(image_base64: str):
        image_data = base64.b64decode(image_base64)
        return Image.open(io.BytesIO(image_data))

    def run_pipeline(self, request: PromptRequest, background_tasks: BackgroundTasks):
        if self.installer.ov_pipe is None:
            raise HTTPException(status_code=400, detail="Pipeline is not initialized.")

        # Extract parameters from the request
        image_path = request.image_path
        image_base64 = request.image_base64
        question = request.question or "Please describe the image in 3 sentences with less than 50 tokens"
        max_tokens = request.max_tokens

        # Handle image input
        if image_path:
            if not os.path.exists(image_path):
                raise HTTPException(status_code=400, detail=f"Image path '{image_path}' does not exist.")
            image = Image.open(image_path)
        elif image_base64:
            image = self._decode_image(image_base64)
        else:
            raise HTTPException(status_code=400, detail="Either image_path or image_base64 must be provided.")

        # Schedule the task in the background
        background_tasks.add_task(self.pipeline_task, self.installer, image, question, max_tokens, self)

        return {"status": "success", "message": "Pipeline execution started in background."}

    def get_answer(self):
        # Simply return the answer as a dictionary
        return {"answer": self._answer}  # Return as a dictionary with the answer field

    @staticmethod
    def health_check():
        return {"status": "healthy"}


if __name__ == "__main__":
    api = API()
    uvicorn.run(api.app, host="0.0.0.0", port=8100, reload=False)


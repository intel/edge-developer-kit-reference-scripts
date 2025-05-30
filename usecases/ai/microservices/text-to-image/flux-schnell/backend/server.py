# Copyright (C) 2025 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

import os
import gc
import time
import torch
import uvicorn
import openvino as ov
import openvino_genai as ov_genai

from pathlib import Path
from functools import wraps
from cmd_helper import optimum_cli
from PIL import Image

from pydantic import BaseModel
from fastapi import FastAPI, HTTPException, Response, BackgroundTasks
from contextlib import asynccontextmanager

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

def lock_api(func):
    @wraps(func)
    def wrapper(self, *args, **kwargs):
        if self.pipeline_status["running"] and (func.__name__ in ["run_pipeline", "select_device_and_compile"]):
            raise HTTPException(status_code=400, detail="Another pipeline execution is in progress. Please wait until it completes.")
        self.pipeline_status["running"] = True
        try:
            result = func(self, *args, **kwargs)
            self.pipeline_status["running"] = False  # Ensure it's set to False after successful execution
            return result
        except Exception as e:
            self.pipeline_status["running"] = False  # Ensure it's set to False even if an error occurs
            raise e
    return wrapper

# -------------------------------------------------------------------------
# Generator Class
# -------------------------------------------------------------------------
class Generator(ov_genai.Generator):
    def __init__(self, seed):
        super().__init__()
        self.generator = torch.Generator(device="cpu").manual_seed(seed)

    def next(self):
        return torch.randn(1, generator=self.generator, dtype=torch.float32).item()

    def randn_tensor(self, shape: ov.Shape):
        torch_tensor = torch.randn(list(shape), generator=self.generator, dtype=torch.float32)
        return ov.Tensor(torch_tensor.numpy())


# -------------------------------------------------------------------------
# Main Class for Flux.1 Schnell
# -------------------------------------------------------------------------
class FluxSchnell:
    def __init__(self, model_name_or_path, device="CPU", weight_format="int8", model_dir=None):
        self.model_name = model_name_or_path
        self.device = device
        self.weight_format = weight_format
        self.model_dir = model_dir
        self.random_generator = Generator(42)

        # Automatically convert models during initialization
        print("Converting models during initialization...")
        try:
            self.convert_models(self.weight_format)
            print("Model conversion completed successfully.")
        except Exception as e:
            print(f"Model conversion failed: {e}")
            raise

        # Automatically prepare the pipeline during initialization
        self.ov_pipe = None
        try:
            self.prepare_pipeline(self.device)
        except Exception as e:
            print(f"Pipeline preparation failed: {e}")
            raise

    @log_elapsed_time
    def convert_models(self, weight_format="int8"):
        """Convert PyTorch models to OpenVINO IR (if not already done)."""
        if not self.model_dir.exists():
            print(f"Downloading model: {self.model_name} ({weight_format}) to {self.model_dir}...")
            additional_args = {}
            additional_args.update({
                "weight-format": weight_format, 
                "group-size": "64", 
                "ratio": "1.0"
            })
            optimum_cli(self.model_name, self.model_dir, additional_args=additional_args)
        print("Model conversion completed.")

    @staticmethod
    def validate_device_available(user_device: str):
        """Check if the specified device is available."""
        ov_core = ov.Core()
        available_devices = [device.upper() for device in ov_core.available_devices]  # Normalize device names
        print(f"Available devices: {available_devices}")
        if user_device in available_devices:
            print(f"Device {user_device} is available.")
            return True, user_device
        else:
            print(f"Device {user_device} is not available.")
            return False, f"Device {user_device} is not available. Available devices: {available_devices}"
                
    @log_elapsed_time
    def prepare_pipeline(self, device: str):
        """Prepare the OpenVINO pipeline for inference."""
        # Validate the device
        if device is None:
            return {"status": "error", "message": "Device not specified."}
        
        # Clear previous pipeline and perform garbage collection
        if hasattr(self, 'ov_pipe') and self.ov_pipe is not None:
            print("Releasing resources from the previous pipeline...")
            del self.ov_pipe
            gc.collect()

        # Validate device availability
        status, selected_device_or_message = self.validate_device_available(user_device=device)
        if status == "error":
            print(f"Error while selecting device: {selected_device_or_message}")
            return {"status": "error", "message": selected_device_or_message}

        try:
            print(f"Preparing OpenVINO pipeline on {selected_device_or_message}...")
            self.ov_pipe = ov_genai.Text2ImagePipeline(self.model_dir, selected_device_or_message)
            success_message = f"Pipeline prepared successfully on {selected_device_or_message}."
            print(success_message)
            return {"status": "success", "message": success_message}
        except Exception as e:
            error_message = f"Error while preparing the pipeline: {e}"
            print(error_message)
            return {"status": "error", "message": error_message}

    @log_elapsed_time
    def run_pipeline(self, prompt, width, height, num_inference_steps):
        """Run inference on the pipeline with a specific prompt."""
        print(f"Generating image with prompt: '{prompt}'")
        ov_pipe = self.ov_pipe
        image_tensor = ov_pipe.generate(
            prompt,
            width=width,
            height=height,
            num_inference_steps=num_inference_steps,
            num_images_per_prompt=1,
            generator=self.random_generator
        )
        image = Image.fromarray(image_tensor.data[0])
        print("Inference completed.")
        return image


# -------------------------------------------------------------------------
# FastAPI - REST API
# -------------------------------------------------------------------------
class DeviceRequest(BaseModel):
    device: str

class PromptRequest(BaseModel):
    prompt: str
    width: int = 1024  # Default value of 512 for width
    height: int = 1024  # Default value of 512 for height
    num_inference_steps: int = 50  # Default value for number of inference steps

class Sdv3API:
    def __init__(self):
        self.installer = FluxSchnell(
            model_name_or_path=os.getenv("MODEL_NAME_OR_PATH", "black-forest-labs/FLUX.1-schnell"),
            device=os.getenv("DEVICE", "CPU"),
            weight_format = os.getenv("WEIGHT_FORMAT", "int8"),
            model_dir = Path(os.getenv("MODEL_DIR", "./data/openvino-flux-schnell"))
        )
        self.image_path = "tmp_output_image.png"
        self.pipeline_status = {"running": False, "completed": False}

        # Define the application with lifespan context
        self.app = FastAPI(lifespan=self.lifespan)

        # Register routes explicitly
        self.app.add_api_route(
            "/pipeline/select-device", self.select_device_and_compile, methods=["POST"]
        )
        self.app.add_api_route("/pipeline/run", self.run_pipeline, methods=["POST"])
        self.app.add_api_route("/pipeline/status", self.check_pipeline_status, methods=["GET"])
        self.app.add_api_route("/pipeline/image", self.get_pipeline_image, methods=["GET"])
        self.app.add_api_route("/health", self.health_check, methods=["GET"])

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

    @lock_api
    def select_device_and_compile(self, request: DeviceRequest):
        device = request.device
        try:
            # Prepare the pipeline on the validated device
            self.installer.prepare_pipeline(device)
            return {"status": "success", "message": f"Pipeline prepared on {device}."}
        except Exception as e:
            # Return a structured error response in case of an exception
            return {"status": "error", "message": f"Pipeline preparation failed: {str(e)}"}

    @staticmethod
    def pipeline_task(installer, prompt, image_path, pipeline_status, width, height, num_inference_steps):
        try:
            pipeline_status["running"] = True
            image = installer.run_pipeline(prompt, width, height, num_inference_steps)
            image.save(image_path)
            pipeline_status["completed"] = True
        except Exception as e:
            print(f"Pipeline execution failed: {e}")
        finally:
            pipeline_status["running"] = False

    @lock_api
    def run_pipeline(self, request: PromptRequest, background_tasks: BackgroundTasks):
        if self.installer.ov_pipe is None:
            raise HTTPException(status_code=400, detail="Pipeline is not initialized.")

        # Extract parameters from the request
        prompt = request.prompt
        width = request.width
        height = request.height
        num_inference_steps = request.num_inference_steps

        # Schedule the task in the background
        background_tasks.add_task(self.pipeline_task, self.installer, prompt, self.image_path, self.pipeline_status,
                                  width, height, num_inference_steps)

        return {"status": "success", "message": "Pipeline execution started in background."}

    @lock_api
    def check_pipeline_status(self):
        return {"running": self.pipeline_status["running"], "completed": self.pipeline_status["completed"]}

    @lock_api
    def get_pipeline_image(self):
        if not self.pipeline_status["completed"]:
            raise HTTPException(status_code=400, detail="Pipeline execution is not yet complete.")
        try:
            with open(self.image_path, "rb") as image_file:
                image_content = image_file.read()
            self.pipeline_status["completed"] = False
            os.remove(self.image_path)
            return Response(content=image_content, media_type="image/png")
        except FileNotFoundError:
            raise HTTPException(status_code=500, detail="Generated image not found.")

    @staticmethod
    def health_check():
        return {"status": "healthy"}


if __name__ == "__main__":
    api = Sdv3API()
    uvicorn.run(api.app, host="0.0.0.0", port=8100, reload=False)

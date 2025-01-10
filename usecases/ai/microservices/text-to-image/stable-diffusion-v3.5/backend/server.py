# Copyright (C) 2025 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

import time
import openvino.runtime as ov_runtime
import openvino_genai as ov_genai
import openvino as ov
import torch
import gc
import os

from pathlib import Path
from functools import wraps
from cmd_helper import optimum_cli
from PIL import Image

from pydantic import BaseModel
from fastapi import FastAPI, HTTPException, Response, BackgroundTasks
from contextlib import asynccontextmanager
import uvicorn

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
# Main Class for Stable Diffusion v3.5
# -------------------------------------------------------------------------
class StableDiffusionV3_5:
    def __init__(self, quantize=False):
        self.quantize = quantize
        self.model_name = "stabilityai/stable-diffusion-3.5-medium"
        self.model_dir = Path("stable-diffusion-3.5-medium")
        self.random_generator = Generator(42)

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
            optimum_cli(self.model_name, self.model_dir)
        print("Model conversion completed.")

    @staticmethod
    def get_device(user_device=None):
        try:
            ov_core = ov_runtime.Core()
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

        print(f"Preparing OpenVINO pipeline on {selected_device_or_message}...")
        try:
            self.ov_pipe = ov_genai.Text2ImagePipeline(self.model_dir, selected_device_or_message)
            success_message = f"Pipeline prepared successfully on {selected_device_or_message}."
            print(success_message)
            return {"status": "success", "message": success_message}
        except Exception as e:
            # Log initialization errors and return an error response
            error_message = f"Error while preparing the pipeline: {e}"
            print(error_message)
            return {"status": "error", "message": error_message}

    @log_elapsed_time
    def run_pipeline(self, prompt, width, height, num_inference_steps):
        # if not self.ov_pipe:
        #     raise RuntimeError("Pipeline is not initialized. Please call `prepare_pipeline` first.")

        """Run inference on the pipeline with a specific prompt."""
        print("Running inference...")
        print(f"Generating image with prompt: '{prompt}'")

        ov_pipe = self.ov_pipe

        # try:
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
        # except Exception as e:
        #     print(f"Image generation failed: {e}")
        #     raise


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
        self.installer = StableDiffusionV3_5(quantize=True)
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

    @lock_api
    def select_device_and_compile(self, request: DeviceRequest):
        return self.prepare_pipeline(device=request.device)

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


# Test to image generation

## Overview
Text-to-image generation microservice is a FastAPI-based API that interacts with the stable diffusion model to perform image generation tasks. 
It provides endpoints for managing the pipeline, checking the pipeline status, retrieving the generated image, and performing a health check.

### Supported Models
* Stable Diffusion XL
* Stable Diffusion v3.5 
* Stable Diffusion v3

### Supported Inference Device
* CPU
* GPU

---

## Quick Start

### 1. Install Operating System
Install the latest [Ubuntu 22.04 LTS Desktop](https://releases.ubuntu.com/jammy/). Refer to the [Ubuntu Desktop installation tutorial](https://ubuntu.com/tutorials/install-ubuntu-desktop#1-overview) if needed.

### 2. Install GPU Driver (Optional)
If you plan to use a GPU for inference, install the appropriate GPU driver:
- **Intel® Arc™ A-Series Graphics:** [Installation Guide](https://github.com/intel/edge-developer-kit-reference-scripts/tree/main/gpu/arc/dg2)
- **Intel® Data Center GPU Flex Series:** [Installation Guide](https://github.com/intel/edge-developer-kit-reference-scripts/tree/main/gpu/flex/ats)

### 3. Setup text-to-image generation server  

- Change the current directory to the selected model. For example:
  ```bash
  cd stable-diffusion-v3.5
  ```

- Execute the setup script.
  ```bash
  ./setup.sh
  ```

### 4. Verify the server by running the example (optional)
```bash
./run.sh
```


## Routes

### 1. **POST /pipeline/select-device**
   - **Description**: Selects and compiles the device for the pipeline.
   - **Request Body**: 
     ```
     {
       "device": "<device_name>"
     }
     ```
   - **Response**:
     - Success:
       ```
       {
         "status": "success",
         "message": "Pipeline prepared on <device_name>."
       }
       ```
     - Error:
       ```
       {
         "status": "error",
         "message": "<error_message>"
       }
       ```

### 2. **POST /pipeline/run**
   - **Description**: Starts the pipeline execution asynchronously in the background.
   - **Request Body**: 
     ```
     {
       "prompt": "<your_prompt>"
     }
     ```
   - **Response**:
     - Success:
       ```
       {
         "status": "success",
         "message": "Pipeline execution started in background."
       }
       ```
     - Error:
       ```
       {
         "status": "error",
         "message": "Pipeline execution is already running or pipeline is not initialized."
       }
       ```

### 3. **GET /pipeline/status**
   - **Description**: Checks the current status of the pipeline.
   - **Response**:
     ```
     {
       "running": <true or false>,
       "completed": <true or false>
     }
     ```

### 4. **GET /pipeline/image**
   - **Description**: Retrieves the generated image once the pipeline has completed execution. This endpoint is available only when the pipeline has finished processing.
   - **Response**:
     - Success (Image):
       The generated image will be returned as a `PNG` file:
       ```
       {
         "status": "success",
         "message": "Image returned"
       }
       ```
     - Error:
       ```
       {
         "status": "error",
         "message": "Pipeline execution is not yet complete."
       }
       ```

### 5. **GET /health**
   - **Description**: A simple health check endpoint to ensure that the API is up and running.
   - **Response**:
     ```
     {
       "status": "healthy"
     }
     ```
     
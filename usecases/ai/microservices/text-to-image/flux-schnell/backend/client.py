# Copyright (C) 2025 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

import time
import requests


class PipelineClient:
    def __init__(self, base_url="http://localhost:8100"):
        """
        Initialize the PipelineClient with the base URL.
        :param base_url: The base URL for the API.
        """
        self.base_url = base_url

    def make_request(self, method, endpoint, data=None, timeout=100):
        """
        Make a request to the API.
        :param method: HTTP method (GET, POST, etc.).
        :param endpoint: API endpoint.
        :param data: JSON payload for the request.
        :param timeout: Timeout in seconds.
        :return: Response object or None on failure.
        """
        url = f"{self.base_url}{endpoint}"
        try:
            response = requests.request(method, url, json=data, timeout=timeout)
            response.raise_for_status()
            return response
        except requests.RequestException as e:
            print(f"Error while accessing {url}: {e}")
            return None

    @staticmethod
    def save_image(content, filename):
        """
        Save the content as an image file.
        :param content: Binary content of the image.
        :param filename: Filename to save the image.
        """
        try:
            with open(filename, "wb") as file:
                file.write(content)
            print(f"Image saved as {filename}")
        except IOError as e:
            print(f"Failed to save image: {e}")

    def wait_for_completion(self, timeout=60, poll_interval=2):
        """
        Wait for the pipeline to complete.
        :param timeout: Maximum time to wait in seconds.
        :param poll_interval: Time between status checks.
        :return: True if completed, False otherwise.
        """
        start_time = time.time()
        while time.time() - start_time < timeout:
            response = self.make_request("GET", "/pipeline/status", timeout=10)
            if response:
                status = response.json()
                print(f"Pipeline status: Running={status['running']}, Completed={status['completed']}")
                if status["completed"]:
                    return True
            time.sleep(poll_interval)
        print("Timeout reached. Pipeline execution did not complete.")
        return False

    def check_health(self):
        """
        Check the health of the API.
        :return: True if the health check passes, False otherwise.
        """
        response = self.make_request("GET", "/health")
        if response:
            health_status = response.json()
            print(f"Health status: {health_status['status']}")
            return health_status['status'] == "healthy"
        else:
            print("Failed to perform health check.")
            return False


def main():
    client = PipelineClient()

    # Step 1: Health check
    if not client.check_health():
        print("Health check failed. Exiting.")
        return

    # Step 2: Select the device
    response = client.make_request("POST", "/pipeline/select-device", {"device": "GPU"})
    if response:
        print(response.json())

    # Step 3: Trigger the pipeline with additional parameters
    response = client.make_request(
        "POST",
        "/pipeline/run",
        {
            "prompt": "A raccoon trapped inside a glass jar full of colorful candies, the background is steamy with vivid colors",
            "width": 512,  # Additional parameter: width
            "height": 512,  # Additional parameter: height
            "num_inference_steps": 5  # Additional parameter: num_inference_steps
        },
    )
    if not response:
        print("Failed to trigger the pipeline.")
        return
    print(response.json())

    # Step 4: Wait for completion
    if not client.wait_for_completion():
        return

    # Step 5: Retrieve the generated image
    response = client.make_request("GET", "/pipeline/image")
    if response:
        client.save_image(response.content, "output_image.png")
    else:
        print("Failed to retrieve the generated image.")


if __name__ == "__main__":
    main()


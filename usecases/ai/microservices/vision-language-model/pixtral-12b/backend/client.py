# Copyright (C) 2025 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

import time
import base64
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
            if response and response.json() is True:
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

    def trigger_pipeline(self, data):
        """
        Trigger the pipeline with the given image data.
        :param image_data: The image data to send to the pipeline.
        :return: True if the pipeline was triggered successfully, False otherwise.
        """
        response = self.make_request("POST", "/pipeline/run", data)
        if not response:
            print("Failed to trigger the pipeline.")
            return False
        print(response.json())
        return True

    def retrieve_answer(self):
        """
        Retrieve the answer from the pipeline.
        """
        if self.wait_for_completion():
            response = self.make_request("GET", "/pipeline/answer")
            if response:
                print("Answer: ", response.json())
            else:
                print("Failed to retrieve the answer.")


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

    # Step 4: Trigger the pipeline with base64-encoded image
    with open("backend/sample.jpg", "rb") as image_file:
        image_base64 = base64.b64encode(image_file.read()).decode('utf-8')

    if not client.trigger_pipeline({
        "image_base64": image_base64,
        "question": "Is there a cat in the picture? Tell me the number of cats.",
        "max_tokens": 100
    }):
        return

    # Step 5: Retrieve the answer for base64-encoded image
    client.retrieve_answer()

    # Step 6: Trigger the pipeline with base64-encoded image, without question
    with open("backend/sample.jpg", "rb") as image_file:
        image_base64 = base64.b64encode(image_file.read()).decode('utf-8')

    if not client.trigger_pipeline({
        "image_base64": image_base64,
        "max_tokens": 100
    }):
        return

    # Step 7: Retrieve the answer for base64-encoded image
    client.retrieve_answer()


if __name__ == "__main__":
    main()

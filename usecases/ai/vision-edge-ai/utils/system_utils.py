# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

import os
import io
import platform
import subprocess
import csv
from openvino.runtime import Core


def get_power_consumption():
	total_energy = 0.0
	proc_energy = 0.0
	power_plane_0 = 0.0
	power_plane_1 = 0.0
	command = ['pcm', '/csv', '0.5', '-i=1']
	try:
		result = subprocess.run(command, capture_output=True, text=True, timeout=60)
		output = result.stdout
		csv_reader = csv.reader(io.StringIO(output))
		header_row = None
		for row in csv_reader:
			if "Proc Energy (Joules)" in row:
				header_row = row
				break
		if header_row:
			proc_energy_index = next((i for i, col in enumerate(header_row) if "Proc Energy" in col), None)
			power_plane_0_index = next((i for i, col in enumerate(header_row) if "Power Plane 0" in col), None)
			power_plane_1_index = next((i for i, col in enumerate(header_row) if "Power Plane 1" in col), None)
			data_row = None
			for row in csv_reader:
				if row and all(index is not None and row[index].replace('.', '', 1).isdigit() for index in [proc_energy_index, power_plane_0_index, power_plane_1_index]):
					data_row = row
					break
			if data_row:
				def safe_float(value):
					try:
						return float(value)
					except ValueError:
						return 0.0
				if proc_energy_index is not None:
					proc_energy = safe_float(data_row[proc_energy_index])
				if power_plane_0_index is not None:
					power_plane_0 = safe_float(data_row[power_plane_0_index])
				if power_plane_1_index is not None:
					power_plane_1 = safe_float(data_row[power_plane_1_index])
				total_energy = proc_energy + power_plane_0 + power_plane_1
	except Exception as e:
		print(f"An error occurred: {e}")
	return total_energy


def get_cpu_model():
    """Return the CPU model."""
    import platform
    try:
        cpu_model = platform.uname().processor or platform.processor()
        if not cpu_model or cpu_model == "x86_64" and platform.system() == "Linux":
            with open("/proc/cpuinfo", "r") as f:
                for line in f:
                    if "model name" in line:
                        cpu_model = line.split(":")[1].strip()
                        break
        return cpu_model or "CPU model not available"
    except Exception as e:
        print(f"Error fetching CPU model: {e}")
        return "CPU model not available"

def get_gpu_model():
    try:
        result = subprocess.run(["lspci"], capture_output=True, text=True)
        for line in result.stdout.splitlines():
            if ("VGA" in line or "3D controller" in line) and "Intel Corporation" in line:
                return line.split(": ")[-1].strip()
        return "Intel GPU not found"
    except Exception:
        return "Unknown GPU"

def list_devices():
	ie = Core()
	return ie.available_devices 
	

def list_cameras():
	video_devices = []
	try:
		# Use the v4l2-ctl command to list devices
		result = subprocess.run(["v4l2-ctl", "--list-devices"], capture_output=True, text=True)
		if result.returncode == 0:
			output = result.stdout
			devices = output.strip().split("\n\n")  # Split different device groups
			for idx, device in enumerate(devices):
				lines = device.splitlines()
				if lines:
					device_name = lines[0].strip()
					device_paths = [line.strip() for line in lines[1:] if line.strip().startswith('/dev/video')]
					valid_device_paths = [path for path in device_paths if os.path.exists(path)]  # Filter existing paths
					print(device_name)
					if valid_device_paths:
						if "RealSense" in device_name:
							camera_name = f"RS Camera {idx + 1}"
						else:
							camera_name = f"Web Camera {idx + 1}"
						
						video_devices.append({
							"name": camera_name,
							"url": str(idx) # Take the first valid path
						})
					else:
						print(f"Skipped device group: {device_name} (No valid video paths found)")

	except Exception as e:
		print(f"An error occurred while probing cameras: {e}")

	return video_devices

# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

import shlex
import logging
import subprocess  # nosec
import numpy as np
import soundfile as sf

import openvino as ov
import openvino_genai

logger = logging.getLogger('uvicorn.error')


class OptimumCLI:
    def run_export(model_name_or_path, output_dir):
        command = f"optimum-cli export openvino --trust-remote-code --model {model_name_or_path} {output_dir}"
        subprocess.run(shlex.split(command))  # nosec


def download_default_model(model_name_or_path, output_dir):
    logger.info(
        f"Downloading default model: {model_name_or_path} to {output_dir}")
    OptimumCLI.run_export(model_name_or_path, output_dir)


def verify_device_available(device):
    logger.info(f"Verifying device availability: {device.upper()}")
    core = ov.Core()
    available_devices = core.available_devices
    if device.upper() in available_devices:
        return device.upper()
    else:
        logger.error(
            f"Device not available: {device.upper()}. Default to CPU device.")
        return "CPU"


def load_model_pipeline(model_dir, device="CPU"):
    logger.info(f"Initializing pipeline on device: {device}")
    pipeline = openvino_genai.WhisperPipeline(model_dir, device)
    return pipeline


def resample(audio, src_sample_rate, dst_sample_rate):
    if src_sample_rate == dst_sample_rate:
        return audio
    duration = audio.shape[0] / src_sample_rate
    resampled_data = np.zeros(
        shape=(int(duration * dst_sample_rate)), dtype=np.float32)
    x_old = np.linspace(0, duration, audio.shape[0], dtype=np.float32)
    x_new = np.linspace(0, duration, resampled_data.shape[0], dtype=np.float32)
    resampled_audio = np.interp(x_new, x_old, audio)
    return resampled_audio.astype(np.float32)


def language_mapping(language):
    mapping = {
        "english": "<|en|>",
        "chinese": "<|zh|>",
    }
    return mapping.get(language, "<|en|>")


def transcribe(pipeline, audio, language="english"):
    config = pipeline.get_generation_config()
    if config.is_multilingual:
        config.language = language_mapping(language)
        config.task = "transcribe"

    data, fs = sf.read(audio)
    resampled_audio = resample(
        audio=data,
        src_sample_rate=fs,
        dst_sample_rate=16000
    ).astype(np.float32)

    results = pipeline.generate(resampled_audio, config)
    if results.texts and len(results.texts) > 0:
        return results.texts[0]
    else:
        logger.error("No transcription results.")
        return ""


def translate(pipeline, audio, source_language="english"):
    '''
    translate is taking the source language and output to english
    '''
    config = pipeline.get_generation_config()
    if config.is_multilingual:
        config.language = language_mapping(source_language)
        config.task = "translate"

    data, fs = sf.read(audio)
    resampled_audio = resample(
        audio=data,
        src_sample_rate=fs,
        dst_sample_rate=16000
    ).astype(np.float32)
    results = pipeline.generate(resampled_audio, config)
    if results.texts and len(results.texts) > 0:
        return results.texts[0]
    else:
        logger.error("No translation results.")
        return ""

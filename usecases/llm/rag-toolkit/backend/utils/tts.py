# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

import os
import sys
sys.path.append("../thirdparty/MeloTTS")

import logging
logger = logging.getLogger('uvicorn.error')

from melo.api import TTS

loggers = [logging.getLogger(name) for name in logging.root.manager.loggerDict]
for logger in loggers:
    print(logger)
    if "transformers" in logger.name.lower():
        logger.setLevel(logging.ERROR)

def download_nltk_data(download_dir='../data/nltk_data'):
    logger.info(f"NLTK data is not found in {download_dir}. Downloading NLTK data. Please ensure you have network access.")
    import nltk
    nltk.download('averaged_perceptron_tagger_eng', download_dir=download_dir)

def warmup(model, speaker_ids):
    logger.info("Warming up TTS model ...")
    text = "How is your day today?"
    voice = "EN-US"
    output_path = "../data/temp/tts/output.wav"
    
    model.tts_to_file(text, speaker_ids[voice], output_path, speed=1)
    
    if os.path.isfile(output_path):
        os.remove(output_path)

    logger.info("Warming up TTS model completed ...")

def load_tts_model(language, device):
    if not os.path.exists("../data/temp/tts"):
        os.makedirs("../data/temp/tts")

    nltk_cache_path = "../data/nltk_data"
    if not os.path.exists(nltk_cache_path):
        download_nltk_data(nltk_cache_path)

    logger.info(f"Initializing TTS model on device: {device}")
    model = TTS(language=language, device=device)
    speaker_ids = model.hps.data.spk2id
    warmup(model, speaker_ids)
    return model, speaker_ids
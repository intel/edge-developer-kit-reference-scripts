# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

import os
import time
import numpy as np
import soundfile as sf
from pathlib import Path
from functools import partial
from collections import namedtuple
from typing import List, Optional, Union, Tuple

import torch
import openvino as ov

import whisper
from whisper.decoding import DecodingTask, Inference, DecodingOptions, DecodingResult

import logging
logger = logging.getLogger('uvicorn.error')

class OpenVINOAudioEncoder(torch.nn.Module):
    """
    Helper for inference Whisper encoder model with OpenVINO
    """

    def __init__(self, core: ov.Core, model_path: Path, device="CPU"):
        super().__init__()
        self.model = core.read_model(model_path)
        logger.info(f"Compiling the encoder model to {device}")
        if device == "NPU":
            available_devices = core.available_devices
            logger.info(available_devices)
            if "NPU" in available_devices:
                logger.info("Reshape model input to static shape to support NPU device")
                self.model.reshape((1, 80, 3000))
            else:
                logger.warning("Unable to find NPU device on the platform. Fallback to use CPU device")
                device = "CPU"
        self.compiled_model = core.compile_model(self.model, device)
        self.output_blob = self.compiled_model.output(0)

    def forward(self, mel: torch.Tensor):
        """
        Inference OpenVINO whisper encoder model.

        Parameters:
          mel: input audio fragment mel spectrogram.
        Returns:
          audio_features: torch tensor with encoded audio features.
        """
        return torch.from_numpy(self.compiled_model(mel)[self.output_blob])


class OpenVINOTextDecoder(torch.nn.Module):
    """
    Helper for inference OpenVINO decoder model
    """

    def __init__(self, core: ov.Core, model_path: Path, device: str = "CPU"):
        super().__init__()
        self._core = core
        self.model = core.read_model(model_path)
        self._input_names = [inp.any_name for inp in self.model.inputs]
        self.compiled_model = core.compile_model(self.model, device)
        self.device = device
        self.blocks = []

    def init_past_inputs(self, feed_dict):
        """
        Initialize cache input for first step.

        Parameters:
          feed_dict: Dictonary with inputs for inference
        Returns:
          feed_dict: updated feed_dict
        """
        beam_size = feed_dict["x"].shape[0]
        audio_len = feed_dict["xa"].shape[2]
        previous_seq_len = 0
        for name in self._input_names:
            if name in ["x", "xa"]:
                continue
            feed_dict[name] = ov.Tensor(
                np.zeros((beam_size, previous_seq_len, audio_len), dtype=np.float32))
        return feed_dict

    def preprocess_kv_cache_inputs(self, feed_dict, kv_cache):
        """
        Transform kv_cache to inputs

        Parameters:
          feed_dict: dictionary with inputs for inference
          kv_cache: dictionary with cached attention hidden states from previous step
        Returns:
          feed_dict: updated feed dictionary with additional inputs
        """
        if not kv_cache:
            return self.init_past_inputs(feed_dict)
        for k, v in zip(self._input_names[2:], kv_cache):
            feed_dict[k] = ov.Tensor(v)
        return feed_dict

    def postprocess_outputs(self, outputs):
        """
        Transform model output to format expected by the pipeline

        Parameters:
          outputs: outputs: raw inference results.
        Returns:
          logits: decoder predicted token logits
          kv_cache: cached attention hidden states
        """
        logits = torch.from_numpy(outputs[0])
        kv_cache = list(outputs.values())[1:]
        return logits, kv_cache

    def forward(self, x: torch.Tensor, xa: torch.Tensor, kv_cache: Optional[dict] = None):
        """
        Inference decoder model.

        Parameters:
          x: torch.LongTensor, shape = (batch_size, <= n_ctx) the text tokens
          xa: torch.Tensor, shape = (batch_size, n_mels, n_audio_ctx)
             the encoded audio features to be attended on
          kv_cache: Dict[str, torch.Tensor], attention modules hidden states cache from previous steps
        Returns:
          logits: decoder predicted logits
          kv_cache: updated kv_cache with current step hidden states
        """
        feed_dict = {"x": ov.Tensor(x.numpy()), "xa": ov.Tensor(xa.numpy())}
        feed_dict = self.preprocess_kv_cache_inputs(feed_dict, kv_cache)
        res = self.compiled_model(feed_dict)
        return self.postprocess_outputs(res)


class OpenVINOInference(Inference):
    """
    Wrapper for inference interface
    """

    def __init__(self, model: "Whisper", initial_token_length: int):
        self.model: "Whisper" = model
        self.initial_token_length = initial_token_length
        self.kv_cache = {}

    def logits(self, tokens: torch.Tensor, audio_features: torch.Tensor) -> torch.Tensor:
        """
        getting logits for given tokens sequence and audio features and save kv_cache

        Parameters:
          tokens: input tokens
          audio_features: input audio features
        Returns:
          logits: predicted by decoder logits
        """
        if tokens.shape[-1] > self.initial_token_length:
            # only need to use the last token except in the first forward pass
            tokens = tokens[:, -1:]
        logits, self.kv_cache = self.model.decoder(
            tokens, audio_features, kv_cache=self.kv_cache)
        return logits

    def cleanup_caching(self):
        """
        Reset kv_cache to initial state
        """
        self.kv_cache = {}

    def rearrange_kv_cache(self, source_indices):
        """
        Update hidden states cache for selected sequences
        Parameters:
          source_indicies: sequences indicies
        Returns:
          None
        """
        for module, tensor in self.kv_cache.items():
            # update the key/value cache to contain the selected sequences
            self.kv_cache[module] = tensor[source_indices].detach()


class OpenVINODecodingTask(DecodingTask):
    """
    Class for decoding using OpenVINO
    """

    def __init__(self, model: "Whisper", options: DecodingOptions):
        super().__init__(model, options)
        self.inference = OpenVINOInference(model, len(self.initial_tokens))


def patch_whisper_for_ov_inference(model):
    @torch.no_grad()
    def decode(
        model: "Whisper",
        mel: torch.Tensor,
        options: DecodingOptions = DecodingOptions(),
    ) -> Union[DecodingResult, List[DecodingResult]]:
        """
        Performs decoding of 30-second audio segment(s), provided as Mel spectrogram(s).

        Parameters
        ----------
        model: Whisper
            the Whisper model instance

        mel: torch.Tensor, shape = (80, 3000) or (*, 80, 3000)
            A tensor containing the Mel spectrogram(s)

        options: DecodingOptions
            A dataclass that contains all necessary options for decoding 30-second segments

        Returns
        -------
        result: Union[DecodingResult, List[DecodingResult]]
            The result(s) of decoding contained in `DecodingResult` dataclass instance(s)
        """
        single = mel.ndim == 2
        if single:
            mel = mel.unsqueeze(0)

        result = OpenVINODecodingTask(model, options).run(mel)

        if single:
            result = result[0]

        return result

    Parameter = namedtuple("Parameter", ["device"])

    def parameters():
        return iter([Parameter(torch.device("cpu"))])

    def logits(model, tokens: torch.Tensor, audio_features: torch.Tensor):
        """
        Override for logits extraction method
        Parameters:
          tokens: input tokens
          audio_features: input audio features
        Returns:
          logits: decoder predicted logits
        """
        return model.decoder(tokens, audio_features, None)[0]

    model.parameters = parameters
    model.decode = partial(decode, model)
    model.logits = partial(logits, model)


def resample(audio, src_sample_rate, dst_sample_rate):
    """
    Resample audio to specific sample rate

    Parameters:
      audio: input audio signal
      src_sample_rate: source audio sample rate
      dst_sample_rate: destination audio sample rate
    Returns:
      resampled_audio: input audio signal resampled with dst_sample_rate
    """
    if src_sample_rate == dst_sample_rate:
        return audio
    duration = audio.shape[0] / src_sample_rate
    resampled_data = np.zeros(
        shape=(int(duration * dst_sample_rate)), dtype=np.float32)
    x_old = np.linspace(0, duration, audio.shape[0], dtype=np.float32)
    x_new = np.linspace(0, duration, resampled_data.shape[0], dtype=np.float32)
    resampled_audio = np.interp(x_new, x_old, audio)
    return resampled_audio.astype(np.float32)


def download_and_convert_encoder(model, model_id, save_dir="./data/model/stt"):
    mel = torch.zeros((1, 80 if "v3" not in model_id else 128, 3000))
    audio_features = model.encoder(mel)
    encoder_model = ov.convert_model(
        model.encoder, example_input=mel)
    ov.save_model(encoder_model,
                  f"{save_dir}/whisper_{model_id}_encoder.xml")


def download_and_convert_decoder(model, model_id, save_dir="./data/model/stt"):
    def attention_forward(
        attention_module,
        x: torch.Tensor,
        xa: Optional[torch.Tensor] = None,
        mask: Optional[torch.Tensor] = None,
        kv_cache: Optional[Tuple[torch.Tensor, torch.Tensor]] = None,
    ):
        """
        Override for forward method of decoder attention module with storing cache values explicitly.
        Parameters:
        attention_module: current attention module
        x: input token ids.
        xa: input audio features (Optional).
        mask: mask for applying attention (Optional).
        kv_cache: dictionary with cached key values for attention modules.
        idx: idx for search in kv_cache.
        Returns:
        attention module output tensor
        updated kv_cache
        """
        q = attention_module.query(x)

        if xa is None:
            # hooks, if installed (i.e. kv_cache is not None), will prepend the cached kv tensors;
            # otherwise, perform key/value projections for self- or cross-attention as usual.
            k = attention_module.key(x)
            v = attention_module.value(x)
            if kv_cache is not None:
                k = torch.cat((kv_cache[0], k), dim=1)
                v = torch.cat((kv_cache[1], v), dim=1)
            kv_cache_new = (k, v)
        else:
            # for cross-attention, calculate keys and values once and reuse in subsequent calls.
            k = attention_module.key(xa)
            v = attention_module.value(xa)
            kv_cache_new = (None, None)

        wv, qk = attention_module.qkv_attention(q, k, v, mask)
        return attention_module.out(wv), kv_cache_new

    def block_forward(
        residual_block,
        x: torch.Tensor,
        xa: Optional[torch.Tensor] = None,
        mask: Optional[torch.Tensor] = None,
        kv_cache: Optional[Tuple[torch.Tensor, torch.Tensor]] = None,
    ):
        """
        Override for residual block forward method for providing kv_cache to attention module.
        Parameters:
            residual_block: current residual block.
            x: input token_ids.
            xa: input audio features (Optional).
            mask: attention mask (Optional).
            kv_cache: cache for storing attention key values.
        Returns:
            x: residual block output
            kv_cache: updated kv_cache

        """
        x0, kv_cache = residual_block.attn(
            residual_block.attn_ln(x), mask=mask, kv_cache=kv_cache)
        x = x + x0
        if residual_block.cross_attn:
            x1, _ = residual_block.cross_attn(
                residual_block.cross_attn_ln(x), xa)
            x = x + x1
        x = x + residual_block.mlp(residual_block.mlp_ln(x))
        return x, kv_cache

    def decoder_forward(
        decoder,
        x: torch.Tensor,
        xa: torch.Tensor,
        kv_cache: Optional[Tuple[Tuple[torch.Tensor, torch.Tensor]]] = None,
    ):
        """
        Override for decoder forward method.
        Parameters:
        x: torch.LongTensor, shape = (batch_size, <= n_ctx) the text tokens
        xa: torch.Tensor, shape = (batch_size, n_mels, n_audio_ctx)
            the encoded audio features to be attended on
        kv_cache: Dict[str, torch.Tensor], attention modules hidden states cache from previous steps
        """
        if kv_cache is not None:
            offset = kv_cache[0][0].shape[1]
        else:
            offset = 0
            kv_cache = [None for _ in range(len(decoder.blocks))]
        x = decoder.token_embedding(
            x) + decoder.positional_embedding[offset: offset + x.shape[-1]]
        x = x.to(xa.dtype)
        kv_cache_upd = []

        for block, kv_block_cache in zip(decoder.blocks, kv_cache):
            x, kv_block_cache_upd = block(
                x, xa, mask=decoder.mask, kv_cache=kv_block_cache)
            kv_cache_upd.append(tuple(kv_block_cache_upd))

        x = decoder.ln(x)
        logits = (
            x @ torch.transpose(decoder.token_embedding.weight.to(x.dtype), 1, 0)).float()

        return logits, tuple(kv_cache_upd)

    mel = torch.zeros((1, 80 if "v3" not in model_id else 128, 3000))
    audio_features = model.encoder(mel)

    for idx, block in enumerate(model.decoder.blocks):
        block.forward = partial(block_forward, block)
        block.attn.forward = partial(attention_forward, block.attn)
        if block.cross_attn:
            block.cross_attn.forward = partial(
                attention_forward, block.cross_attn)
    model.decoder.forward = partial(decoder_forward, model.decoder)

    tokens = torch.ones((5, 3), dtype=torch.int64)
    logits, kv_cache = model.decoder(tokens, audio_features, kv_cache=None)
    tokens = torch.ones((5, 1), dtype=torch.int64)

    decoder_model = ov.convert_model(
        model.decoder,
        example_input=(tokens, audio_features, kv_cache))
    ov.save_model(decoder_model, f"{save_dir}/whisper_{model_id}_decoder.xml")


def load_stt_model(model_id='base', encoder_device='CPU', decoder_device='CPU'):
    logger.info(f"Initializing STT encoder on device: {encoder_device} and decoder on device: {decoder_device}")
    model = whisper.load_model(model_id, 'cpu')
    model.eval()

    if not os.path.exists("./data/temp/stt"):
        os.makedirs("./data/temp/stt", exist_ok=True)
    
    if not os.path.exists("./data/model/stt"):
        os.makedirs("./data/model/stt", exist_ok=True)

    whisper_encoder_ov = Path(
        f"./data/model/stt/whisper_{model_id}_encoder.xml")
    whisper_decoder_ov = Path(
        f"./data/model/stt/whisper_{model_id}_decoder.xml")

    if not os.path.isfile(whisper_encoder_ov):
        logger.info(f"Unable to find encoder model for whisper: {model_id}")
        download_and_convert_encoder(model, model_id)

    if not os.path.isfile(whisper_decoder_ov):
        logger.info(f"Unable to find decoder model for whisper: {model_id}")
        download_and_convert_decoder(model, model_id)

    core = ov.Core()
    patch_whisper_for_ov_inference(model)
    model.encoder = OpenVINOAudioEncoder(
        core, whisper_encoder_ov, device=encoder_device)
    model.decoder = OpenVINOTextDecoder(
        core, whisper_decoder_ov, device=decoder_device)

    return model


def inference_transcribe(model, audio, language='korean'):
    start_time = time.time()
    data, fs = sf.read(audio)
    resampled_audio = resample(
        audio=data, src_sample_rate=fs, dst_sample_rate=16000)
    transcription = model.transcribe(
        audio=resampled_audio, task="transcribe", language=language)
    logger.info(f"End-to-end STT transcription inference (secs): {(time.time()- start_time):.2}")
    return transcription['text']


def inference_translate(model, audio, language='english'):
    start_time = time.time()
    data, fs = sf.read(audio)
    resampled_audio = resample(
        audio=data, src_sample_rate=fs, dst_sample_rate=16000)
    translation = model.transcribe(
        audio=resampled_audio, task="translate", language=language)
    logger.info(f"End-to-end STT translation inference (secs): {(time.time()- start_time):.2}")
    return translation['text']

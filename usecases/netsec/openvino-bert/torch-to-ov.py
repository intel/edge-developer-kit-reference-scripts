# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

import os
import sys
import time
from pathlib import Path
from zipfile import ZipFile
from typing import Iterable
from typing import Any

import datasets
import numpy as np
import nncf
from nncf.parameters import ModelType
import openvino as ov
import torch
from transformers import BertForSequenceClassification, BertTokenizer


MODEL_DIR = "models"
os.makedirs(MODEL_DIR, exist_ok=True)

MAX_SEQ_LENGTH = 512


def load_model(inputs, input_info):
    try: 
        ir_model_xml = Path(MODEL_DIR) / "bert-base-cased.xml"
        core = ov.Core()

        torch_model = BertForSequenceClassification.from_pretrained('bert-base-cased')
        torch_model.eval

        # Convert the PyTorch model to OpenVINO IR FP32.
        if not ir_model_xml.exists():
            model = ov.convert_model(torch_model, example_input=inputs, input=input_info)
            ov.save_model(model, str(ir_model_xml))
        else:
            model = core.read_model(ir_model_xml)

        return model
    except Exception as e:
        print(f"Error in load_model: {e}")
        sys.exit(1)

def create_data_source():
    try: 
        raw_dataset = datasets.load_dataset('glue', 'mrpc', split='validation')
        tokenizer = BertTokenizer.from_pretrained('bert-base-cased')

        def _preprocess_fn(examples):
            texts = (examples['sentence1'], examples['sentence2'])
            result = tokenizer(*texts, padding='max_length', max_length=MAX_SEQ_LENGTH, truncation=True)
            result['labels'] = examples['label']
            return result
        processed_dataset = raw_dataset.map(_preprocess_fn, batched=True, batch_size=1)

        return processed_dataset
    except Exception as e:
        print(f"Error in create_data_source: {e}")
        sys.exit(1)

def nncf_quantize(model, inputs):
    try:
        INPUT_NAMES = [key for key in inputs.keys()]
        data_source = create_data_source()

        def transform_fn(data_item):
            """
            Extract the model's input from the data item.
            The data item here is the data item that is returned from the data source per iteration.
            This function should be passed when the data item cannot be used as model's input.
            """
            inputs = {
                name: np.asarray([data_item[name]], dtype=np.int64) for name in INPUT_NAMES
            }
            return inputs

        calibration_dataset = nncf.Dataset(data_source, transform_fn)
        # Quantize the model. By specifying model_type, we specify additional transformer patterns in the model.
        quantized_model = nncf.quantize(model, calibration_dataset,
                                        model_type=ModelType.TRANSFORMER)


        compressed_model_xml = Path(MODEL_DIR) / "quantized_bert_base_cased.xml"
        ov.save_model(quantized_model, compressed_model_xml)
    except Exception as e:
        print(f"Error in nncf_quantize: {e}")
        sys.exit(1)

if __name__ == '__main__':
    input_shape = ov.PartialShape([1, 512])
    input_info = [("input_ids", input_shape, np.int64),("attention_mask", input_shape, np.int64),("token_type_ids", input_shape, np.int64)]
    default_input = torch.ones(1, MAX_SEQ_LENGTH, dtype=torch.int64)
    inputs = {
        "input_ids": default_input,
        "attention_mask": default_input,
        "token_type_ids": default_input,
    }

    model = load_model(inputs, input_info)
    quantized_model = nncf_quantize(model, inputs)

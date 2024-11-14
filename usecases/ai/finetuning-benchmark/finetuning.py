# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

import os
import time
import fire
import json
import torch
import os.path as osp
from datetime import datetime
from typing import List, Union

from transformers import AutoTokenizer, TrainingArguments, TrainerCallback, Trainer, DataCollatorForLanguageModeling
from ipex_llm.transformers.qlora import get_peft_model, prepare_model_for_kbit_training, LoraConfig
from ipex_llm.transformers import AutoModelForCausalLM
from ipex_llm.utils.common import invalidInputError
from datasets import load_dataset


class TokenCountCallback(TrainerCallback):
    def __init__(self, cutoff_len=512, micro_batch_size=2, gradient_accumulation_steps=1):
        self.train_history = []
        self.eval_history = []
        self.train_runtime = []
        self.start_time = datetime.now()
        self.step_processed = 0
        self.max_steps = 0
        self.cutoff_len = cutoff_len
        self.train_remaining_time = 0
        self.step_time = 0
        self.micro_batch_size = micro_batch_size
        self.gradient_accumulation_steps = gradient_accumulation_steps

    def _calculate_remaining_time(self, step):
        elapsedTime = datetime.now() - self.start_time
        self.train_remaining_time = str(
            ((elapsedTime/self.step_processed)*(self.max_steps - step)))

    def _resume_from_checkpoint(self, state):
        for train_history in state.log_history:
            if 'loss' in train_history.keys():
                self.train_history.append(train_history)
            if 'eval_loss' in train_history.keys():
                self.eval_history.append(train_history)
            if 'train_runtime' in train_history.keys():
                self.train_runtime.append(train_history)
        self.resume_from_checkpoint = False

    def on_step_begin(self, args, state, control, **kwargs):
        self.step_time = time.time()

    def on_step_end(self, args, state, control, **kwargs):
        elapsed_step_time = time.time() - self.step_time
        if state.is_local_process_zero:
            num_tokens = self.cutoff_len * self.micro_batch_size * \
                self.gradient_accumulation_steps
            print(f"Epochs: {state.epoch} | Iterations: {state.global_step} | Token/sec: {num_tokens/elapsed_step_time} | GPU memory allocated: {torch.xpu.memory_allocated() / (1024 ** 3)} | GPU memory reserved: {torch.xpu.memory_reserved() / (1024 ** 3)} | Number of training tokens: {num_tokens} | Time take: {elapsed_step_time} secs")


class Prompter(object):
    __slots__ = ("template", "_verbose")

    def __init__(self, template_name: str = "", verbose: bool = False):
        self._verbose = verbose
        if not template_name:
            # Enforce the default here, so the constructor can be called with '' and will not break.
            template_name = "alpaca"
        file_name = osp.join("./templates", f"{template_name}.json")
        if not osp.exists(file_name):
            invalidInputError(False, f"Can't read {file_name}")
        with open(file_name) as fp:
            self.template = json.load(fp)
        if self._verbose:
            print(
                f"Using prompt template {template_name}: {self.template['description']}"
            )

    def generate_prompt(
        self,
        instruction: str,
        input: Union[None, str] = None,
        label: Union[None, str] = None,
    ) -> str:
        # returns the full prompt from instruction and optional input
        # if a label (=response, =output) is provided, it's also appended.
        if input:
            res = self.template["prompt_input"].format(
                instruction=instruction, input=input
            )
        else:
            res = self.template["prompt_no_input"].format(
                instruction=instruction
            )
        if label:
            res = f"{res}{label}"
        if self._verbose:
            print(res)
        return res

    def get_response(self, output: str) -> str:
        return output.split(self.template["response_split"])[1].strip()


def get_int_from_env(env_keys, default):
    """Returns the first positive env value found in the `env_keys` list or the default."""
    for e in env_keys:
        val = int(os.environ.get(e, -1))
        if val >= 0:
            return val
    return int(default)


def get_train_val_data(data, tokenizer, prompter, train_on_inputs,
                       add_eos_token, cutoff_len, val_set_size, seed=42):
    """Data processing to get train data and val data"""
    def tokenize(prompt, add_eos_token=True):
        result = tokenizer(
            prompt,
            padding="max_length",
            truncation=True,
            max_length=cutoff_len,
            return_tensors=None,
        )
        if (
            result["input_ids"][-1] != tokenizer.eos_token_id
            and len(result["input_ids"]) < cutoff_len
            and add_eos_token
        ):
            result["input_ids"].append(tokenizer.eos_token_id)
            result["attention_mask"].append(1)
        result["labels"] = result["input_ids"].copy()
        return result

    def generate_and_tokenize_prompt(data_point):
        full_prompt = prompter.generate_prompt(
            data_point["instruction"],
            data_point["input"],
            data_point["output"],
        )
        tokenized_full_prompt = tokenize(full_prompt)
        if not train_on_inputs:
            user_prompt = prompter.generate_prompt(
                data_point["instruction"], data_point["input"]
            )
            tokenized_user_prompt = tokenize(
                user_prompt, add_eos_token=add_eos_token
            )
            user_prompt_len = len(tokenized_user_prompt["input_ids"])
            if add_eos_token:
                user_prompt_len -= 1
            tokenized_full_prompt["labels"] = [
                -100
            ] * user_prompt_len + tokenized_full_prompt["labels"][
                user_prompt_len:
            ]  # could be sped up, probably
        return tokenized_full_prompt

    if val_set_size > 0:
        train_val = data["train"].train_test_split(
            test_size=val_set_size, shuffle=True, seed=seed
        )
        train_data = (
            train_val["train"].shuffle().map(generate_and_tokenize_prompt)
        )
        val_data = (
            train_val["test"].shuffle().map(generate_and_tokenize_prompt)
        )
    else:
        train_data = data["train"].shuffle().map(generate_and_tokenize_prompt)
        val_data = None
    return train_data, val_data


def train(
    # Model
    base_model: str = "mistralai/Mistral-7B-v0.3",
    base_model_revision: str = "main",
    training_mode: str = "qlora",
    lora_r: int = 8,
    lora_alpha: int = 16,
    lora_dropout: float = 0.05,
    lora_target_modules: List[str] = [
        "q_proj",
        "v_proj",
        "k_proj",
        "o_proj",
        "up_proj",
        "down_proj",
        "gate_proj"
    ],
    # Dataset
    data_path: str = "yahma/alpaca-cleaned",
    prompt_template_name: str = "alpaca",
    val_set_size: int = 2000,
    cutoff_len: int = 2048,
    dataset_seed=42,
    # Training
    output_dir: str = "./outputs",
    bf16: bool = True,
    per_device_train_batch_size: int = 2,
    batch_size: int = 128,
    warmup_steps=20,
    num_train_epochs: int = 3,
    learning_rate: float = 3e-5,
    gradient_checkpointing: bool = True,
    deepspeed_config: str = None
):
    print("Starting the benchmarking script")
    benchmark_start_time = time.time()
    gradient_accumulation_steps = batch_size // per_device_train_batch_size
    world_size = int(os.environ.get("WORLD_SIZE", 1))
    ddp = world_size != 1
    if ddp:
        gradient_accumulation_steps = gradient_accumulation_steps // world_size
        if gradient_accumulation_steps == 0:
            print(f"gradient_accumulation_steps should be set to the number of CPUs/GPUs used to run the benchmark. Defaulting to 1.")
            gradient_accumulation_steps = 1

    low_bit_dtype = "nf4" if training_mode == "qlora" else "bf16"

    print(
        f"Setting up model: {base_model} with {low_bit_dtype}, using model revision: {base_model_revision}")
    model = AutoModelForCausalLM.from_pretrained(
        base_model,
        revision=base_model_revision,
        load_in_low_bit=low_bit_dtype,
        optimize_model=False,
        torch_dtype=torch.bfloat16,
        modules_to_not_convert=[]
    )

    print(f'Model loaded on rank {os.environ.get("LOCAL_RANK", 0)}')
    model = model.to(f'xpu:{os.environ.get("LOCAL_RANK", 0)}')
    print(f'Model moved to rank {os.environ.get("LOCAL_RANK", 0)}')

    print(f"Setting up tokenizer: {base_model}")
    tokenizer = AutoTokenizer.from_pretrained(
        base_model,
        revision=base_model_revision,
        trust_remote_code=True
    )
    print(f'Tokenizer loaded on rank {os.environ.get("LOCAL_RANK", 0)}')

    if tokenizer.pad_token is None:
        print("Tokenizer pad_token not available. Setting pad_token to eos_token")
        tokenizer.pad_token = tokenizer.eos_token

    config = LoraConfig(
        r=lora_r,
        lora_alpha=lora_alpha,
        target_modules=lora_target_modules,
        lora_dropout=lora_dropout,
        bias="none",
        task_type="CAUSAL_LM",
        training_mode=training_mode
    )
    print(f"Lora Config: {config}")

    model = prepare_model_for_kbit_training(
        model, use_gradient_checkpointing=gradient_checkpointing)
    model = get_peft_model(model, config)
    model.config.use_cache = False
    model.print_trainable_parameters()

    print(f"Setting up dataset: {data_path}")
    if data_path.endswith(".json") or data_path.endswith(".jsonl"):
        data = load_dataset("json", data_files=data_path)
    else:
        data = load_dataset(data_path)

    print(f"Preprocessing dataset")
    prompter = Prompter(prompt_template_name)
    train_data, val_data = get_train_val_data(
        data,
        tokenizer,
        prompter,
        train_on_inputs=True,
        add_eos_token=False,
        cutoff_len=cutoff_len,
        val_set_size=val_set_size,
        seed=dataset_seed
    )

    print(f"Setting up Trainer")
    trainer = Trainer(
        model=model,
        train_dataset=train_data,
        eval_dataset=val_data,
        args=TrainingArguments(
            output_dir=output_dir + '/checkpoints',
            per_device_train_batch_size=per_device_train_batch_size,
            per_device_eval_batch_size=1,
            gradient_accumulation_steps=gradient_accumulation_steps,
            learning_rate=learning_rate,
            lr_scheduler_type="cosine",
            optim="adamw_hf",
            warmup_steps=warmup_steps,
            num_train_epochs=num_train_epochs,
            evaluation_strategy="epoch",
            bf16=bf16,
            logging_strategy="steps",
            logging_steps=1,
            save_strategy="epoch",
            save_total_limit=2,
            ddp_backend="ccl",
            ddp_find_unused_parameters=False,
            deepspeed=deepspeed_config,
            load_best_model_at_end=True,
            gradient_checkpointing=True,
        ),
        data_collator=DataCollatorForLanguageModeling(
            tokenizer, mlm=False
        ),
        callbacks=[TokenCountCallback(
            cutoff_len=cutoff_len,
            micro_batch_size=per_device_train_batch_size,
            gradient_accumulation_steps=gradient_accumulation_steps
        )]
    )

    print(f"Starting to train model")
    result = trainer.train()

    print(f"Result of the model: {result}")
    benchmark_end_time = time.time() - benchmark_start_time
    print(f"Total runtime for the benchmark: {benchmark_end_time} secs")

if __name__ == "__main__":
    local_rank = get_int_from_env(["LOCAL_RANK", "MPI_LOCALRANKID"], "0")
    world_size = get_int_from_env(["WORLD_SIZE", "PMI_SIZE"], "1")
    port = get_int_from_env(["MASTER_PORT"], 29500)
    os.environ["LOCAL_RANK"] = str(local_rank)
    os.environ["WORLD_SIZE"] = str(world_size)
    os.environ["RANK"] = str(local_rank)
    os.environ["MASTER_PORT"] = str(port)

    fire.Fire(train)

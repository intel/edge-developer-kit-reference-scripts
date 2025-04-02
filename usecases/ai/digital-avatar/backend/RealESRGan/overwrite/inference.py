# Copyright(C) 2024 Intel Corporation
# SPDX - License - Identifier: Apache - 2.0

import os

from basicsr.archs.rrdbnet_arch import RRDBNet
from basicsr.utils.download_util import load_file_from_url
from RealESRGan.realesrgan import RealESRGANer
from RealESRGan.realesrgan.archs.srvgg_arch import SRVGGNetCompact


def initialize(model_name="RealESRGAN_x2plus", device="cpu"):
    models = {
        "RealESRGAN_x2plus": {
            "url": ["https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.1/RealESRGAN_x2plus.pth"],
            "name": "RealESRGAN_x2plus",
            "model": RRDBNet(num_in_ch=3, num_out_ch=3, num_feat=64, num_block=23, num_grow_ch=32, scale=2),
            "netscale": 2
        },
        "RealESRGAN_x4plus": {
            "url": ['https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth'],
            "name": "RealESRGAN_x4plus",
            "model": RRDBNet(num_in_ch=3, num_out_ch=3, num_feat=64, num_block=23, num_grow_ch=32, scale=4),
            "netscale": 4
        },
        "realesr-animevideov3": {
            "url": ["https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesr-animevideov3.pth"],
            "name": "realesr-animevideov3",
            "model": SRVGGNetCompact(num_in_ch=3, num_out_ch=3, num_feat=64, num_conv=16, upscale=4, act_type='prelu'),
            "netscale": 4
        },
        "realesr-general-x4v3":{
            "url": [
                "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesr-general-x4v3.pth",
                "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesr-general-wdn-x4v3.pth"
                ],
            "name": "realesr-animevideov3",
            "model": SRVGGNetCompact(num_in_ch=3, num_out_ch=3, num_feat=64, num_conv=32, upscale=4, act_type='prelu'),
            "netscale": 4
        },
        "realesr-general-x4v3-dn":{
            "url": [
                "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesr-general-wdn-x4v3.pth"
                ],
            "name": "realesr-animevideov3",
            "model": SRVGGNetCompact(num_in_ch=3, num_out_ch=3, num_feat=64, num_conv=32, upscale=4, act_type='prelu'),
            "netscale": 4
        },
        "RealESRGAN_x4plus_anime_6B":{
             "url": [
                'https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.2.4/RealESRGAN_x4plus_anime_6B.pth'
                ],
            "name": "RealESRGAN_x4plus_anime_6B",
            "model": RRDBNet(num_in_ch=3, num_out_ch=3, num_feat=64, num_block=6, num_grow_ch=32, scale=4),
            "netscale": 4
        }
    }
    
    if model_name not in models:
        raise ValueError(f"Model name {model_name} not found")

    model = models[model_name]

    model_path = os.path.join('weights', model_name + '.pth')
    if not os.path.isfile(model_path):
        ROOT_DIR = os.path.dirname(os.path.abspath(__file__))
        # model_path will be updated
        model_path = load_file_from_url(
            url=model["url"][0], model_dir=os.path.join(ROOT_DIR, 'weights'), progress=True, file_name=None)

    # use dni to control the denoise strength
    dni_weight = None

    # restorer
    upsampler = RealESRGANer(
        scale=model["netscale"],
        model_path=model_path,
        dni_weight=dni_weight,
        model=model['model'],
        tile=0,
        tile_pad=10,
        pre_pad=0,
        half=False,
        device=device)

    return upsampler

if __name__=="__main__":
    initialize()
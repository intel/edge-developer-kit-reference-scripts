# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

import os.path
import sysconfig

import numpy as np
from setuptools import Extension, setup


setup (
    name="yolo processor",
	version="1.0.0",
    description="Cython extension ",
    license="Apache 2.0",
	ext_modules = 	[
		Extension(

			name = "yolo_model", 
			sources = [
					'yolo_model.pyx'
				], 
			include_dirs = [ 
					".", 
					np.get_include()
				],
			
            extra_compile_args = [
	                "-Wall",
	                "-Wextra",
	                "-O3",
	                "-Wno-cpp"
	            ],
			extra_link_args = [
					"-fPIC", "-Wno-unused-command-line-argument"
					],
			language="c++"

        )
	]
)




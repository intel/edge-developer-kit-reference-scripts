@echo off
title Clone_OpenVINO_Notebooks
echo Clone OpenVINO notebooks and install dependencies.
set "downloadDir=%HOMEDRIVE%%HOMEPATH%\Downloads"
cd /d "%downloadDir%"

::example of proxy setup
::set "HTTP_PROXY=http://proxy-xxx.com:123"
::set "HTTPS_PROXY=%HTTP_PROXY%"

git clone --depth=1 https://github.com/openvinotoolkit/openvino_notebooks.git
cd "%downloadDir%\openvino_notebooks"

python -m pip install --upgrade pip wheel setuptools
pip install -r requirements.txt

pause
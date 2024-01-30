@echo off
title Install OpenVINO archive version.
echo Installing.

set "IntelDir=C:\Program Files (x86)\Intel"

if exist "%IntelDir%" (
  echo File Exists
) else (
  echo Create new folder
  mkdir "%IntelDir%"
)

::example of proxy setup
::set "HTTP_PROXY=http://proxy-xxx.com:123"
::set "HTTPS_PROXY=%HTTP_PROXY%"

echo download OpenVINO.zip file ...
cd /d "%HOMEDRIVE%%HOMEPATH%\Downloads"
curl -L https://storage.openvinotoolkit.org/repositories/openvino/packages/2023.2/windows/w_openvino_toolkit_windows_2023.2.0.13089.cfd42bd2cb0_x86_64.zip --output openvino_2023.2.0.zip

tar -xf openvino_2023.2.0.zip
ren w_openvino_toolkit_windows_2023.2.0.13089.cfd42bd2cb0_x86_64 openvino_2023.2.0
move openvino_2023.2.0 "%IntelDir%"

cd "%IntelDir%\openvino_2023.2.0"
python -m pip install --upgrade pip
python -m pip install -r .\python\requirements.txt

cd "%IntelDir%"
mklink /D openvino_2023 openvino_2023.2.0



pause
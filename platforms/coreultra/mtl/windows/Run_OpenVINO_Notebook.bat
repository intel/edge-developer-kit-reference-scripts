@echo off
Title Run OpenVINO Notebooks
echo Bring up jupyter notebooks for OpenVINO.

set "IntelDir=C:\Program Files (x86)\Intel"
set "OpenVINODir=%IntelDir%\openvino_2023.2.0"
set "downloadDir=%HOMEDRIVE%%HOMEPATH%\Downloads"

cd /d "%downloadDir%"

::example of proxy setup
::set "HTTP_PROXY=http://proxy-xxx.com:123"
::set "HTTPS_PROXY=%HTTP_PROXY%"

if exist "%OpenVINODir%" (
  CALL "%OpenVINODir%\setupvars.bat"
  cd "%downloadDir%\openvino_notebooks"
  jupyter lab notebooks
) else (
  echo Unable to found OpenVINO directory, exit ...
)

pause
@ECHO off
REM Copyright (C) 2024 Intel Corporation
REM SPDX-License-Identifier: Apache-2.0

echo Installing Backend Service ...
python --version >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    echo Python is not installed. Please install Python 3.x and try again.
    exit /b 1
)

REM Create a virtual environment named 'backend-env'
if exist backend-env (
    echo Virtual environment already exists. Skipping creation ...
) ELSE (
    echo Creating virtual environment ...
    python -m venv backend-env
)

REM Activate the virtual environment
call backend-env\Scripts\activate

REM Install backend dependencies
python -m pip install -r backend\requirements.txt

pause

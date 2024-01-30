@echo off
title Install all Dependencies.
echo Installing.

::example of proxy setup
::set "HTTP_PROXY=http://proxy-xxx.com:123"
::set "HTTPS_PROXY=%HTTP_PROXY%"

::Install Python (required Administrator access)
::check python installed or not

echo install Python package
winget install -e --id Python.Python.3.10
echo install Git
winget install -e --id Git.Git

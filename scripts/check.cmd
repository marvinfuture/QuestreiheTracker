@echo off
setlocal
set "QRT_PYTHON=%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
if not exist "%QRT_PYTHON%" set "QRT_PYTHON=python"
"%QRT_PYTHON%" "%~dp0test.py"
if errorlevel 1 exit /b 1
"%QRT_PYTHON%" "%~dp0package.py"
exit /b %errorlevel%

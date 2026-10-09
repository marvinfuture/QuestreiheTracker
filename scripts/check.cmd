@echo off
setlocal
set "QST_PYTHON=%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
if not exist "%QST_PYTHON%" set "QST_PYTHON=python"
"%QST_PYTHON%" "%~dp0test.py"
if errorlevel 1 exit /b 1
"%QST_PYTHON%" "%~dp0package.py"
exit /b %errorlevel%

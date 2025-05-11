@echo off
setlocal
setlocal enabledelayedexpansion

if "%~1"=="" (
    echo Error: Drag ASM file onto script
    goto error
)

node disassembly.js %1

if errorlevel 1 (
  echo [ERROR] Processing failed
  pause
  exit /b 1
)


:error
echo.
echo [FAILED] No files changed.
timeout 5
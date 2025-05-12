@echo off
setlocal
setlocal enabledelayedexpansion

echo epicASM v1.0
echo Copyright (c) ColorProgrammy 2025


if "%~1"=="" (
    echo Error: Drag ASM file onto batch.
    goto error
)

node script.js %1

if errorlevel 1 (
  echo [ERROR] Processing failed
  echo No files changed.
  pause
  exit /b 1
)

timeout 5

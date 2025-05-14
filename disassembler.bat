@echo off
setlocal
setlocal enabledelayedexpansion

echo epicASM v1.0
echo Copyright (c) ColorProgrammy 2025
echo
echo Disassemble BIN/EXE to assembler
echo ---
echo

if "%~1"=="" (
    echo Error: Drag exe/bin file onto batch.
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

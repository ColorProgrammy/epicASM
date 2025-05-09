@echo off
setlocal enabledelayedexpansion

if "%~1"=="" (
    echo Error: Drag a file onto the script or specify its path.
    goto error
)

set "input_file=%~1"
set "output_file=%~n1.asm"

set "ext=%~x1"
if /i not "%ext%"==".exe" (
    if /i not "%ext%"==".dll" (
        if /i not "%ext%"==".bin" (
            echo Error: Only .exe, .dll, .bin files supported.
            goto error
        )
    )
)

if not exist "%input_file%" (
    echo Error: File "%input_file%" not found.
    goto error
)

if /i "%ext%"==".bin" (
    if not exist "nasm\ndisasm.exe" (
        echo Error: ndisasm.exe not found in .\nasm\
        goto error
    )
    echo Disassembling .bin file...
    "nasm\ndisasm.exe" -b 32 "%input_file%" > "%output_file%" 2>&1
) else (
    if not exist "mingw\objdump.exe" (
        echo Error: objdump.exe not found in .\mingw\
        goto error
    )
    echo Disassembling PE file...
    "mingw\objdump.exe" -d "%input_file%" > "%output_file%" 2>&1
)

if %ERRORLEVEL% neq 0 (
    echo Error: Disassembly failed.
    goto error
)

echo Success! Output: "%output_file%"
exit /b 0

:error
echo.
pause
exit /b 1
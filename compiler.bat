@echo off
setlocal enabledelayedexpansion

if "%~1"=="" (
    echo Usage: %~nx0 input.asm
    goto error
)

set "input=%~1"
set "name=%~n1"

if not exist "%input%" (
    echo File not found: %input%
    goto error
)

if /i not "%~x1"==".asm" (
    echo Only .asm files supported
    goto error
)

if not exist "nasm\nasm.exe" (
    echo NASM not found in .\nasm\
    goto error
)

:menu
echo Select output format:
echo 1) Flat binary (.bin)
echo 2) Windows EXE (.exe)
set /p choice="Your choice [1-2]: "

if "%choice%"=="1" (
    set "format=bin"
    set "output=%name%.bin"
    set "args=-f bin"
    goto compile
)
if "%choice%"=="2" (
    set "format=exe"
    set "output=%name%.exe"
    set "args=-f bin"
    goto check_pe_header
)
echo Invalid choice
goto menu

:check_pe_header
findstr /i /c:"db 'MZ'" "%input%" >nul
if %ERRORLEVEL% equ 0 (
    echo File already contains PE headers, using as-is
    goto compile
)

(
    echo [BITS 32]
    echo [ORG 0x400000]
    echo section .text
    echo start:
    type "%input%"
    echo     push 0
    echo     call [ExitProcess]
    echo align 4, db 0
    echo IMAGE_DOS_HEADER:
    echo     db 'MZ', 90, 0
    echo     times 60 - ($-IMAGE_DOS_HEADER) db 0
    echo     dd IMAGE_NT_HEADERS
    echo IMAGE_NT_HEADERS:
    echo     db 'PE',0,0
    echo IMAGE_FILE_HEADER:
    echo     dw 0x014C
    echo     dw 1
    echo     dd 0
    echo     dd 0
    echo     dd 0
    echo     dw 0xE0
    echo     dw 0x103
    echo IMAGE_OPTIONAL_HEADER32:
    echo     dw 0x10B
    echo     db 0,0
    echo     db 0,0
    echo     dd 0x1000
    echo     dd 0
    echo     dd 0
    echo     dd 0x1000
    echo     dd 0x1000
    echo     dd 0
    echo     dd 0x400000
    echo     dd 0x1000
    echo     dd 0x200
    echo     dw 4
    echo     dw 0
    echo     dw 0
    echo     dw 0
    echo     dw 4
    echo     dw 0
    echo     dd 0
    echo     dd 0x2000
    echo     dd 0x200
    echo     dd 0
    echo     dw 2
    echo     dw 0x400
    echo     dd 0x100000
    echo     dd 0x1000
    echo     dd 0x100000
    echo     dd 0x1000
    echo     dd 0
    echo     dd 16
    echo     dd 0,0
    echo     dd IMAGE_IMPORT_DESCRIPTOR, 0
    echo     times 14 dd 0,0
    echo IMAGE_SECTION_HEADER:
    echo     db '.text',0,0,0
    echo     dd 0x1000
    echo     dd 0x1000
    echo     dd _text_size
    echo     dd 0x200
    echo     dd 0
    echo     dd 0
    echo     dw 0
    echo     dw 0
    echo     dd 0x60000020
    echo IMAGE_IMPORT_DESCRIPTOR:
    echo     dd kernel32_iat - IMAGE_DOS_HEADER
    echo     dd 0
    echo     dd 0
    echo     dd kernel32_dll - IMAGE_DOS_HEADER
    echo     dd kernel32_iat - IMAGE_DOS_HEADER
    echo     dd 0,0,0,0,0
    echo kernel32_dll db 'kernel32.dll',0
    echo kernel32_iat:
    echo     dd ExitProcess - IMAGE_DOS_HEADER
    echo     dd 0
    echo ExitProcess db 0,0, 'ExitProcess',0
    echo _text_size equ $ - IMAGE_DOS_HEADER
) > temp.asm

set "input=temp.asm"
goto compile

:compile
nasm\nasm.exe %args% "%input%" -o "%output%"
if %ERRORLEVEL% neq 0 (
    echo Compilation failed
    goto cleanup
)

:cleanup
if exist "temp.asm" del "temp.asm"

if exist "%output%" (
    echo Success: %output%
) else (
    echo Output file not created
)

:error
pause

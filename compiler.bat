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
    goto build_pe
)
echo Invalid choice
goto menu

:build_pe
echo Generating full PE structure with Kernel32 import...
(
    echo BITS 32
    echo org 0x400000
    
    echo SECTION .text
    echo start:
    echo     call delta
    echo delta:
    echo     pop ebp
    echo     sub ebp, delta
    
    echo     ; Your code here
    type "%input%"
    
    echo     ; ExitProcess call
    echo     push 0
    echo     mov eax, [ebp+ExitProcess]
    echo     call eax
    
    echo ; PE headers
    echo IMAGE_DOS_HEADER:
    echo     db 'MZ',0,0
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
    echo     dw 0x010F
    
    echo IMAGE_OPTIONAL_HEADER32:
    echo     dd 0x10B
    echo     dd 0x1000
    echo     dd 0x1000
    echo     dd 0x1000
    echo     dd 0x2000
    echo     dd 0x400000
    echo     dd 0x1000
    echo     dd 0x200
    echo     dw 3
    echo     dw 0
    echo     dd 0
    echo     dd 0x10000
    echo     dd 0x1000
    echo     dd 0
    echo     dw 0
    echo     dw 0
    echo     dd 0x00000000
    
    echo IMAGE_SECTION_HEADER:
    echo     db '.text',0,0,0
    echo     dd 0x1000
    echo     dd 0x1000
    echo     dd _text_size
    echo     dd _text_start
    echo     dd 0
    echo     dd 0
    echo     dw 0
    echo     dw 0
    echo     dd 0x60000020
    
    echo ; Import table
    echo IMAGE_IMPORT_DESCRIPTOR:
    echo     dd kernel32_iat
    echo     dd 0
    echo     dd 0
    echo     dd kernel32_dll
    echo     dd kernel32_iat
    
    echo kernel32_dll db 'KERNEL32.dll',0
    echo kernel32_iat:
    echo ExitProcess dd _ExitProcess
    echo              dd 0
    
    echo _ExitProcess db 0,0,'ExitProcess',0
    
    echo _text_start:
) > temp.asm

set "input=temp.asm"
goto compile

:compile
echo Compiling to %format%...
nasm\nasm.exe %args% "%input%" -o "%output%"
if %ERRORLEVEL% neq 0 (
    echo Compilation failed
    goto cleanup
)

:cleanup
if exist "temp.asm" del "temp.asm"

if exist "%output%" (
    echo Success: %output%
    echo Note: Works for simple programs only
) else (
    echo Output file not created
)

:error
pause
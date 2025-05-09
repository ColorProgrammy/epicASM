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
    echo [BITS 32]
    echo [ORG 0x400000]
    
    echo section .text
    echo start:
    
    echo     ; Your code here
    type "%input%"
    
    echo     ; ExitProcess
    echo     push 0
    echo     call [ExitProcess]
    
    echo ; ===== PE HEADERS =====
    echo align 4, db 0
    
    echo IMAGE_DOS_HEADER:
    echo     db 'MZ', 90, 0
    echo     times 60 - ($-IMAGE_DOS_HEADER) db 0
    echo     dd IMAGE_NT_HEADERS
    
    echo IMAGE_NT_HEADERS:
    echo     db 'PE',0,0
    echo IMAGE_FILE_HEADER:
    echo     dw 0x014C      ; Machine (x86)
    echo     dw 1           ; NumberOfSections
    echo     dd 0           ; TimeDateStamp
    echo     dd 0           ; PointerToSymbolTable
    echo     dd 0           ; NumberOfSymbols
    echo     dw 0xE0        ; SizeOfOptionalHeader
    echo     dw 0x103       ; Characteristics
    
    echo IMAGE_OPTIONAL_HEADER32:
    echo     dw 0x10B       ; Magic (PE32)
    echo     db 0,0         ; MajorLinkerVersion
    echo     db 0,0         ; MinorLinkerVersion
    echo     dd 0x1000      ; SizeOfCode
    echo     dd 0           ; SizeOfInitializedData
    echo     dd 0           ; SizeOfUninitializedData
    echo     dd 0x1000      ; AddressOfEntryPoint
    echo     dd 0x1000      ; BaseOfCode
    echo     dd 0           ; BaseOfData
    echo     dd 0x400000    ; ImageBase
    echo     dd 0x1000      ; SectionAlignment
    echo     dd 0x200       ; FileAlignment
    echo     dw 4           ; MajorOSVersion
    echo     dw 0           ; MinorOSVersion
    echo     dw 0           ; MajorImageVersion
    echo     dw 0           ; MinorImageVersion
    echo     dw 4           ; MajorSubsystemVersion
    echo     dw 0           ; MinorSubsystemVersion
    echo     dd 0           ; Win32VersionValue
    echo     dd 0x2000      ; SizeOfImage
    echo     dd 0x200       ; SizeOfHeaders
    echo     dd 0           ; CheckSum
    echo     dw 2           ; Subsystem (Windows GUI)
    echo     dw 0x400       ; DllCharacteristics
    echo     dd 0x100000    ; SizeOfStackReserve
    echo     dd 0x1000      ; SizeOfStackCommit
    echo     dd 0x100000    ; SizeOfHeapReserve
    echo     dd 0x1000      ; SizeOfHeapCommit
    echo     dd 0           ; LoaderFlags
    echo     dd 16          ; NumberOfRvaAndSizes
    
    echo ; Data directories
    echo     dd 0,0         ; Export
    echo     dd IMAGE_IMPORT_DESCRIPTOR, 0 ; Import
    echo     times 14 dd 0,0
    
    echo IMAGE_SECTION_HEADER:
    echo     db '.text',0,0,0
    echo     dd 0x1000      ; VirtualSize
    echo     dd 0x1000      ; VirtualAddress
    echo     dd _text_size  ; SizeOfRawData
    echo     dd 0x200       ; PointerToRawData
    echo     dd 0           ; PointerToRelocations
    echo     dd 0           ; PointerToLinenumbers
    echo     dw 0           ; NumberOfRelocations
    echo     dw 0           ; NumberOfLinenumbers
    echo     dd 0x60000020  ; Characteristics
    
    echo ; ===== IMPORT TABLE =====
    echo IMAGE_IMPORT_DESCRIPTOR:
    echo     dd kernel32_iat - IMAGE_DOS_HEADER ; OriginalFirstThunk
    echo     dd 0           ; TimeDateStamp
    echo     dd 0           ; ForwarderChain
    echo     dd kernel32_dll - IMAGE_DOS_HEADER ; Name
    echo     dd kernel32_iat - IMAGE_DOS_HEADER ; FirstThunk
    
    echo     dd 0,0,0,0,0   ; Terminator
    
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
    echo Note: Run with administrative rights if needed
) else (
    echo Output file not created
)

:error
pause

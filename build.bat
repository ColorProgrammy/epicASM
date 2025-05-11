@echo off
setlocal enabledelayedexpansion

:: Проверка наличия файла
if "%~1"=="" (
    echo Error: Drag ASM file onto script
    goto error
)

set "input=%~1"
set "name=%~n1"

:: Пути к инструментам
set "NASM=nasm\nasm.exe"
set "GOLINK=golink\GoLink.exe"

:: Проверка инструментов
if not exist "%NASM%" (
    echo Error: NASM not found in .\nasm\
    goto error
)

:menu
echo Select output format:
echo 1) Flat binary (.bin)
echo 2) Windows EXE (.exe)
set /p choice="Your choice [1-2]: "

:: Генерация уникальных имен
set "counter=0"
:name_loop
set "suffix="
if !counter! GTR 0 set "suffix=_!counter!"
set "output_bin=!name!!suffix!.bin"
set "output_exe=!name!!suffix!.exe"
set "output_obj=!name!!suffix!.obj"
if exist "!output_bin!" (
    set /a "counter+=1"
    goto name_loop
)

:: Компиляция BIN
if "%choice%"=="1" (
    echo Compiling BIN...
    "%NASM%" -f bin "%input%" -o "!output_bin!" || (
        echo BIN Error: Remove all EXTERN calls
        del "!output_bin!" 2>nul
        goto error
    )
    goto success
)

:: Компиляция EXE
if "%choice%"=="2" (
    echo Compiling OBJ...
    "%NASM%" -f win32 "%input%" -o "!output_obj!" || (
        echo OBJ Error: Invalid sections/externs
        del "!output_obj!" 2>nul
        goto error
    )

    echo Linking EXE...
    if not exist "%GOLINK%" (
        echo Error: GoLink missing
        del "!output_obj!" 2>nul
        goto error
    )
    "%GOLINK%" /entry _start "!output_obj!" ^
        kernel32.dll user32.dll /fo "!output_exe!" || (
        echo LINK Error: Add required DLLs
        del "!output_exe!" 2>nul
        del "!output_obj!" 2>nul
        goto error
    )
    del "!output_obj!" 2>nul
    goto success
)

echo Invalid choice
goto menu

:success
echo.
echo Created: 
if "%choice%"=="1" echo - !output_bin!
if "%choice%"=="2" echo - !output_exe!
goto end

:error
echo.
echo [FAILED] No files changed.

:end
pause
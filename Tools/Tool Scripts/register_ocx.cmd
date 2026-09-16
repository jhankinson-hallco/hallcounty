@echo off
setlocal EnableExtensions EnableDelayedExpansion

if "%~1"=="" (
    echo Usage: %~nx0 "C:\Path\To\OCXRootFolder"
    exit /b 1
)

set "TARGETDIR=%~1"
set "REG64=%SystemRoot%\System32\regsvr32.exe"
set "REG32=%SystemRoot%\SysWOW64\regsvr32.exe"

if not exist "%TARGETDIR%" (
    echo ERROR: Folder not found: %TARGETDIR%
    exit /b 1
)

set /a FOUND=0
set /a SUCCESS=0
set /a FAILED=0

for /r "%TARGETDIR%" %%F in (*.ocx) do (
    set /a FOUND+=1
    call :RegisterOne "%%~fF"
)

if %FOUND% EQU 0 (
    echo No .ocx files found under: %TARGETDIR%
    exit /b 1
)

echo.
echo Finished.
echo Total found: %FOUND%
echo Registered: %SUCCESS%
echo Failed:     %FAILED%
exit /b 0

:RegisterOne
set "FILE=%~1"
echo Processing: %FILE%

if exist "%REG64%" (
    "%REG64%" /s "%FILE%" >nul 2>&1
    if not errorlevel 1 (
        echo   Registered with 64-bit regsvr32
        set /a SUCCESS+=1
        exit /b 0
    )
)

if exist "%REG32%" (
    "%REG32%" /s "%FILE%" >nul 2>&1
    if not errorlevel 1 (
        echo   Registered with 32-bit regsvr32
        set /a SUCCESS+=1
        exit /b 0
    )
)

echo   Failed to register, skipping
set /a FAILED+=1
exit /b 0
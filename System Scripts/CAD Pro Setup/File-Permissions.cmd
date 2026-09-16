@echo off
setlocal EnableExtensions

:: Require elevation
net session >nul 2>&1
if not "%errorlevel%"=="0" (
    echo ERROR: This script must be run as Administrator.
    exit /b 1
)

call :GrantAcl "C:\Program Files\TriTech Software Systems\"
call :GrantAcl "C:\Program Files (x86)\TriTech Software Systems\"
call :GrantAcl "C:\TriTech\"

echo.
echo Done.
exit /b 0

:GrantAcl
if not exist "%~1" (
    echo SKIP: Folder not found - %~1
    exit /b 0
)

echo Granting Everyone Full Control on: %~1
icacls "%~1" /grant:r *S-1-1-0:(OI)(CI)F /T /C /Q

if errorlevel 1 (
    echo FAILED: %~1
    exit /b 1
) else (
    echo SUCCESS: %~1
)

exit /b 0
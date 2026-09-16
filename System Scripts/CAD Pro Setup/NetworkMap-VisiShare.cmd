@echo off
setlocal EnableExtensions

:: Remove existing Q: mapping if present
net use Q: /delete /y >nul 2>&1

:: Map Q: to the share
net use Q: "\\911ProCAD\" /persistent:yes

if errorlevel 1 (
    echo FAILED to map Q: to \\911ProCAD\
    exit /b 1
)

echo SUCCESS: Q: mapped to \\911ProCAD\
exit /b 0
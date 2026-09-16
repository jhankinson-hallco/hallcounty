@echo off
setlocal

set "PowerShell64=%SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PowerShell64%" set "PowerShell64=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

if not exist "%PowerShell64%" exit /b 2

"%PowerShell64%" -ExecutionPolicy Bypass -NoProfile -NonInteractive -File "%~dp0Uninstall-Device_Branding.ps1"
exit /b %ERRORLEVEL%

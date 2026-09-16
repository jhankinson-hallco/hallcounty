@ECHO OFF

REM Log start
ECHO %DATE% %TIME%: Checking .NET 3.5 >> "%~dp0NetFx3.log"

"%SYSTEMROOT%\System32\DISM.exe" /online /Get-FeatureInfo /FeatureName:NetFx3 | findstr Enabled
IF %ERRORLEVEL% EQU 0 (
    ECHO .NET 3.5 is already enabled >> "%~dp0NetFx3.log"
    EXIT /B 0
) ELSE (
    ECHO %DATE% %TIME%: Enabling .NET 3.5 >> "%~dp0NetFx3.log"
    "%SYSTEMROOT%\system32\DISM.exe" /online /enable-feature /featurename:NetFx3 /All /Source:"%~dp0sxs" /LimitAccess
    IF %ERRORLEVEL% EQU 0 (
        ECHO %DATE% %TIME%: .NET 3.5 installed successfully >> "%~dp0NetFx3.log"
        EXIT /B 0
    ) ELSE (
        ECHO %DATE% %TIME%: ERROR - .NET 3.5 installation failed >> "%~dp0NetFx3.log"
        EXIT /B 1
    )
)
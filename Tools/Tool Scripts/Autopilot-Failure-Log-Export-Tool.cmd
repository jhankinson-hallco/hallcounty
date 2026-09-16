
date /t
time /t
tzutil /g
del D:\Logs\Autopilot.cab
mdmdiagnosticstool.exe -area Autopilot;TPM -cab C:\Autopilot.cab
move C:\Autopilot.cab D:\Logs\
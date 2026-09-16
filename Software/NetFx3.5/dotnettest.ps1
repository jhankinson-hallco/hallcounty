# Run as Administrator
# Saves log to C:\Temp\NetFx3_Install.log

$log = "C:\Temp\NetFx3_Install.log"
New-Item -Path $log -ItemType File -Force | Out-Null

Function Log {
    param([string]$Text)
    $time = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    "$time`t$Text" | Out-File -FilePath $log -Append -Encoding utf8
}

# Check elevation
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "Script must be run elevated as Administrator."
    exit 1
}

Log "Starting .NET Framework 3.5 (NetFx3) installation."

# Primary attempt: Enable Windows optional feature (online, allow Windows Update to download)
Try {
    Log "Attempting Enable-WindowsOptionalFeature -Online -FeatureName NetFx3 -All -NoRestart"
    $result = Enable-WindowsOptionalFeature -Online -FeatureName NetFx3 -All -NoRestart -ErrorAction Stop
    Log "Enable-WindowsOptionalFeature returned: $($result.State) ; RestartNeeded: $($result.RestartNeeded)"
} Catch {
    $err = $_.Exception.Message
    Log "Enable-WindowsOptionalFeature failed: $err"
    $result = $null
}

# If previous cmdlet didn't enable it, fall back to DISM enable-feature (lets Windows Update be used)
If ($null -eq $result -or $result.State -ne "Enabled") {
    Log "Falling back to DISM /Online /Enable-Feature for NetFx3 (allows Windows Update)."
    $dismArgs = "/Online /Enable-Feature /FeatureName:NetFx3 /All"
    $proc = Start-Process -FilePath dism.exe -ArgumentList $dismArgs -NoNewWindow -PassThru -Wait
    $exitCode = $proc.ExitCode
    Log "DISM exit code: $exitCode"
} Else {
    $exitCode = 0
}

# Check final state
Try {
    $feature = Get-WindowsOptionalFeature -Online -FeatureName NetFx3
    Log "Final feature state: $($feature.State)"
} Catch {
    Log "Failed to query feature state: $($_.Exception.Message)"
}

# If not enabled, detect common cause (WSUS / No Internet)
If ($exitCode -ne 0 -or $feature.State -ne "Enabled") {
    Log "NetFx3 not enabled. Performing quick diagnostics for likely causes."
    # Check internet connectivity
    $hasInternet = (Test-NetConnection -ComputerName download.windowsupdate.com -Port 443 -WarningAction SilentlyContinue).TcpTestSucceeded
    Log "Internet connectivity to Windows Update endpoint: $hasInternet"

    # Check for WSUS / Do not allow windows update source via registry (common cause)
    $wsusKeys = @(
        "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate",
        "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU"
    )
    $wsusFound = $false
    foreach ($k in $wsusKeys) {
        If (Test-Path $k) {
            $vals = Get-ItemProperty -Path $k -ErrorAction SilentlyContinue
            If ($vals) {
                $wsusFound = $true
                Log "Found WSUS/WindowsUpdate policy key: $k"
            }
        }
    }
    If ($wsusFound) {
        Log "Detected Windows Update policies that may prevent downloading files from Microsoft Update. Review WSUS/GPO or allow local machine to use Windows Update as source."
    } ElseIf (-not $hasInternet) {
        Log "No outbound internet connectivity to Windows Update endpoints detected. Ensure internet access or provide SxS source."
    } Else {
        Log "Unknown failure. Consult logs in $log and DISM / CBS logs for details."
    }

    Write-Error "Failed to enable NetFx3. See $log for diagnostic details."
    exit 2
}

Log "NetFx3 enabled successfully. If a restart is needed, please reboot the machine."
Write-Output "NET Framework 3.5 (NetFx3) enabled successfully. Log: $log"
exit 
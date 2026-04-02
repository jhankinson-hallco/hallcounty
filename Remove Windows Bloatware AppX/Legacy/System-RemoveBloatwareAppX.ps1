#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    White Glove-safe Windows 11 AppX bloatware removal (Provisioned + AllUsers).

.DESCRIPTION
    Designed for Intune Win32 app execution as SYSTEM during Autopilot pre-provisioning
    (White Glove / technician phase).

    Primary behaviors:
      - Runs only on Windows 11 (build 22000+)
      - Removes targeted AppX packages from:
          1) Provisioned packages (prevents installation for future users)
          2) Installed AppX packages for all users
      - Treats missing target packages as success
      - Uses error-only logging in C:\IntuneScriptLogs\RemoveBloatwareAppX\
        (appends across runs; each run producing output is separated by a header line)
      - Always exits 0 so this non-critical cleanup step does not break the ESP dependency chain

    White Glove / Autopilot guard:
      - Primary gate: real user profiles detected via Win32_UserProfile (WMI), with
        C:\Users filesystem + NTUSER.DAT existence fallback. If neither method can
        determine profile state, the script proceeds fail-OPEN - during White Glove
        provisioning both methods consistently fail, which is exactly when we need
        the script to run.
      - Secondary gate: if an active interactive user exists and is not a provisioning
        identity (e.g. defaultuser0), the script exits without running.

    Marker file behavior:
      - Written only for definitive terminal outcomes: Success, CompletedWithWarnings,
        SkippedNotWindows11, SkippedPostOOBE.
      - Transient outcomes (SkippedOsBuildUnknown, SkippedInteractiveUser,
        UnhandledException) exit 0 without a marker so Intune can retry.

    Does NOT target higher-risk components:
      - MicrosoftWindows.Client.WebExperience
      - Microsoft.Windows.ContentDeliveryManager

    DIAGNOSTIC MODE:
      Writes a trace log to two locations using .NET direct methods (immune to
      $ErrorActionPreference and StrictMode):
        Primary:  C:\Windows\Temp\System-RemoveBloatwareAppX_Diag.txt
        Mirror:   C:\IntuneScriptLogs\RemoveBloatwareAppX\System-RemoveBloatwareAppX_Diag.txt
      Remove the Write-DiagLog calls and $script:DiagFile once no longer needed.

.NOTES
    Author:         Jeremy Hankinson
    Script Version: 1.0.13
    Revision Date:  2026-03-17 (1.0.2); 2026-03-18 (1.0.3, 1.0.4, 1.0.5, 1.0.6); 2026-03-20 (1.0.7, 1.0.8); 2026-03-23 (1.0.9, 1.0.10); 2026-03-26 (1.0.11); 2026-03-27 (1.0.12); 2026-03-30 (1.0.13)
    Script Name:    System-RemoveBloatwareAppX.ps1

    ESP-safe: avoids causing technician phase failures for non-critical package-removal errors.

    INTUNE CONFIGURATION
      Install command:
        %SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File .\System-RemoveBloatwareAppX.ps1

      NOTE: Portal command must include -NonInteractive. Omitting it is a known drift point.

      Uninstall command:
        cmd.exe /c del "C:\IntuneAppMarkers\System-RemoveBloatwareAppX.tag" /f /q

      Install behavior:    System
      Restart behavior:    No specific action

    DETECTION
      File exists:
        C:\IntuneAppMarkers\System-RemoveBloatwareAppX.tag

    RETURN CODES
      0    = Success, skipped, or completed with warnings
#>

# =============================================================================
# CONFIGURATION
# =============================================================================

$script:AppVersion = '1.0.13'

$script:LogRoot    = 'C:\IntuneScriptLogs\RemoveBloatwareAppX'
$script:LogFile    = Join-Path -Path $script:LogRoot -ChildPath 'System-RemoveBloatwareAppX_Install.txt'
$script:MarkerRoot = 'C:\IntuneAppMarkers'
$script:MarkerPath = Join-Path -Path $script:MarkerRoot -ChildPath 'System-RemoveBloatwareAppX.tag'

# DIAGNOSTIC - primary diag trace file (C:\Windows\Temp is always writable as SYSTEM)
$script:DiagFile   = 'C:\Windows\Temp\System-RemoveBloatwareAppX_Diag.txt'

$script:MaxAttempts       = 3
$script:RetryDelaySeconds = 8

# Folder names that exist on a clean/provisioning device and must not be treated
# as real user profiles. defaultuser0/defaultuser1/etc. are excluded separately
# via regex in Get-RealUserProfiles and Test-IsProvisioningIdentity.
$script:ExcludedProfileNames = @(
    'Public'
    'Default'
    'Default User'
    'All Users'
)

# Provisioning identities that should NOT cause the script to suppress itself.
# Matches defaultuser0, defaultuser1, etc. - present during OOBE/White Glove.
$script:ProvisioningUserRegex = '(^|\\)defaultuser\d+$'

# Target AppX package names for removal. Add or remove entries as needed.
# Does NOT include WebExperience or ContentDeliveryManager.
$script:UninstallPackages = @(
    'Clipchamp.Clipchamp'
    'E046963F.LenovoSettingsforEnterprise'
    'Microsoft.549981C3F5F10'
    'Microsoft.BingNews'
    'Microsoft.BingWeather'
    'Microsoft.Edge.GameAssist'
    'Microsoft.GamingApp'
    'Microsoft.GetHelp'
    'Microsoft.Getstarted'
    'Microsoft.MicrosoftJournal'
    'Microsoft.MicrosoftOfficeHub'
    'Microsoft.MicrosoftSolitaireCollection'
    'Microsoft.MicrosoftStickyNotes'
    'Microsoft.MixedReality.Portal'
    'Microsoft.People'
    'Microsoft.PowerAutomateDesktop'
    'Microsoft.SurfaceAppProxy'
    'Microsoft.SurfaceHub'
    'Microsoft.Todos'
    'Microsoft.Whiteboard'
    'Microsoft.Windows.DevHome'
    'Microsoft.WindowsFeedbackHub'
    'Microsoft.WindowsMaps'
    'Microsoft.windowscommunicationsapps'
    'Microsoft.Xbox.TCUI'
    'Microsoft.XboxGameCallableUI'
    'Microsoft.XboxGameOverlay'
    'Microsoft.XboxGamingOverlay'
    'Microsoft.XboxIdentityProvider'
    'Microsoft.XboxSpeechToTextOverlay'
    'Microsoft.YourPhone'
    'Microsoft.ZuneMusic'
    'Microsoft.ZuneVideo'
    'MicrosoftCorporationII.MicrosoftFamily'
    'MicrosoftCorporationII.QuickAssist'
    'MicrosoftCorporationII.Windows365'
)

# =============================================================================
# END CONFIGURATION
# =============================================================================

# -----------------------------------------------------------------------------
# Logging (error-only, buffered - log file created only if warnings/errors occur;
# appends across runs so prior run output is preserved for diagnostics)
#
# v1.0.12: Replaced [System.Collections.Generic.List[string]] with a plain PS
# array. List::new() is blocked under PowerShell Constrained Language Mode (CLM),
# which WDAC/AppLocker can enforce. Because this initialization runs BEFORE the
# outer try/catch, a CLM block here causes an unhandled exit 1 with no log output.
# PS arrays (@()) are CLM-safe. The += operator replaces .Add().
# -----------------------------------------------------------------------------
$script:LogBuffer   = @()
$script:HasWarnings = $false
$script:HasErrors   = $false

function Add-LogLine {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'
    )

    # Wrapped in try/catch so that a logging failure never propagates to the
    # caller - critical when called from catch blocks.
    try {
        $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $script:LogBuffer += "$Timestamp [$Level] $Message"
    }
    catch { }

    if ($Level -eq 'WARN')  { $script:HasWarnings = $true }
    if ($Level -eq 'ERROR') { $script:HasErrors   = $true }
}

function Initialize-LogPath {
    # New-Item is CLM-safe; [System.IO.Directory]::CreateDirectory is not.
    try {
        New-Item -ItemType Directory -Path $script:LogRoot -Force -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Write-LogIfNeeded {
    try {
        if (-not ($script:HasWarnings -or $script:HasErrors)) { return }
        if (-not (Initialize-LogPath)) { return }

        # Each run that produces output is separated by a header so multiple
        # appended runs are easy to distinguish in a single log file.
        try   { $RunHeader = "=== Run $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') v$($script:AppVersion) ===" }
        catch { $RunHeader = '=== Run (timestamp unavailable) ===' }

        # $script:LogBuffer is a plain PS array (CLM-safe); no .ToArray() needed.
        # Explicit CRLF join is source-encoding-independent.
        $Lines = (@('', $RunHeader) + $script:LogBuffer) -join "`r`n"
        Add-Content -LiteralPath $script:LogFile -Value ($Lines + "`r`n") -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        # Never break provisioning because logging failed.
    }
}

# -----------------------------------------------------------------------------
# DIAGNOSTIC - Write-DiagLog
# Uses PS cmdlets (CLM-safe). Writes to C:\Windows\Temp (always writable as
# SYSTEM) and mirrors to the standard log folder. Remove this function and all
# Write-DiagLog calls once CLM root-cause investigation is complete.
# v1.0.12: Replaced [datetime]::Now, [System.IO.File]::AppendAllText,
# [System.IO.Directory]::CreateDirectory, and [System.IO.Path]::Combine with
# CLM-safe PS equivalents. All inner/outer guards preserved.
# -----------------------------------------------------------------------------
function Write-DiagLog {
    param([string]$Message)

    try {
        try   { $Ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff' } catch { $Ts = '(time unavailable)' }
        $Line = "$Ts  $Message"

        # Primary: C:\Windows\Temp - always accessible as SYSTEM
        try {
            Add-Content -LiteralPath $script:DiagFile -Value $Line -Encoding UTF8 -ErrorAction Stop
        }
        catch { } # Diag write must never propagate - swallow silently.

        # Mirror: standard log folder
        try {
            New-Item -ItemType Directory -Path $script:LogRoot -Force -ErrorAction Stop | Out-Null
            $MirrorFile = Join-Path -Path $script:LogRoot -ChildPath 'System-RemoveBloatwareAppX_Diag.txt'
            Add-Content -LiteralPath $MirrorFile -Value $Line -Encoding UTF8 -ErrorAction Stop
        }
        catch { } # Diag write must never propagate - swallow silently.
    }
    catch { } # Outer guard: Write-DiagLog must never throw under any circumstances.
}

# -----------------------------------------------------------------------------
# Marker Handling
# -----------------------------------------------------------------------------
function Write-Marker {
    param(
        [Parameter(Mandatory)][string[]]$Lines
    )

    Write-DiagLog "Write-Marker: attempting - path='$script:MarkerPath'"
    try {
        # CLM-safe: use PS cmdlets instead of .NET static methods (blocked under WDAC/CLM).
        New-Item -ItemType Directory -Path $script:MarkerRoot -Force -ErrorAction SilentlyContinue | Out-Null
        $Lines | Set-Content -LiteralPath $script:MarkerPath -Encoding UTF8 -ErrorAction Stop
        Write-DiagLog "Write-Marker: success - exists=$(Test-Path -LiteralPath $script:MarkerPath -PathType Leaf)"
    }
    catch {
        Write-DiagLog "Write-Marker: FAILED - $($_.Exception.Message)"
        Add-LogLine -Message "Failed to write marker file: $($_.Exception.Message)" -Level 'WARN'
    }
}

function New-MarkerLines {
    param(
        [Parameter(Mandatory)][string]$Status,
        [string[]]$AdditionalLines = @()
    )

    # Protect Get-Date - a failure here must not prevent Write-Marker from being called
    # at the site where New-MarkerLines is invoked (the exception would propagate to MAIN).
    try { $Ts = Get-Date -Format 'o' } catch { $Ts = '(unavailable)' }

    return [string[]](@(
        "Status=$Status"
        "ScriptVersion=$($script:AppVersion)"
        "Timestamp=$Ts"
    ) + $AdditionalLines)
}

# -----------------------------------------------------------------------------
# Guard Helpers
# -----------------------------------------------------------------------------
function Test-IsProvisioningIdentity {
    param(
        [AllowNull()][string]$UserName
    )

    # A null or blank username means no interactive session - safe to proceed.
    if ([string]::IsNullOrWhiteSpace($UserName)) {
        return $true
    }

    # Allow defaultuser0, defaultuser1, etc. - OOBE/White Glove identities.
    return ($UserName -match $script:ProvisioningUserRegex)
}

function Get-RealUserProfiles {
    <#
        Primary:  Win32_UserProfile (WMI)
        Fallback: C:\Users filesystem + NTUSER.DAT existence check

        Returns an array of [pscustomobject]@{Name; LocalPath} when determination succeeds.
        Returns $null when profile state cannot be determined reliably (both methods fail).
        Callers must treat $null as fail-OPEN - proceed with removal.
    #>

    # [SYSTEM/WMI] - Primary: query Win32_UserProfile
    try {
        $Profiles = @(
            Get-CimInstance -ClassName Win32_UserProfile -ErrorAction Stop |
                Where-Object {
                    -not $_.Special -and
                    $_.LocalPath -like 'C:\Users\*'
                } |
                ForEach-Object {
                    $ProfileName = Split-Path -Path $_.LocalPath -Leaf
                    [pscustomobject]@{
                        Name      = $ProfileName
                        LocalPath = $_.LocalPath
                    }
                } |
                Where-Object {
                    $script:ExcludedProfileNames -notcontains $_.Name -and
                    $_.Name -notmatch '^defaultuser\d+$'
                }
        )

        return $Profiles
    }
    catch {
        Add-LogLine -Message "Profile guard: Win32_UserProfile query failed. Falling back to filesystem enumeration. ($($_.Exception.Message))" -Level 'WARN'
    }

    # [SYSTEM/PERMISSIONS] - Fallback: C:\Users directories with NTUSER.DAT present
    try {
        $Profiles = @(
            Get-ChildItem -Path 'C:\Users' -Directory -ErrorAction Stop |
                Where-Object {
                    $script:ExcludedProfileNames -notcontains $_.Name -and
                    $_.Name -notmatch '^defaultuser\d+$' -and
                    (Test-Path -LiteralPath (Join-Path -Path $_.FullName -ChildPath 'NTUSER.DAT') -PathType Leaf)
                } |
                ForEach-Object {
                    [pscustomobject]@{
                        Name      = $_.Name
                        LocalPath = $_.FullName
                    }
                }
        )

        return $Profiles
    }
    catch {
        Add-LogLine -Message "Profile guard: filesystem fallback also failed. Provisioning state cannot be determined. ($($_.Exception.Message))" -Level 'WARN'
        return $null
    }
}

function Get-InteractiveUserName {
    # [SYSTEM/WMI] - Returns the active interactive username, or $null if unavailable.
    try {
        return (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop).UserName
    }
    catch {
        Add-LogLine -Message "Session guard: unable to query Win32_ComputerSystem. Profile state is the primary gate. ($($_.Exception.Message))" -Level 'WARN'
        return $null
    }
}

# -----------------------------------------------------------------------------
# Retry Wrapper
# -----------------------------------------------------------------------------
function Invoke-WithRetry {
    param(
        [Parameter(Mandatory)][scriptblock]$ScriptBlock,
        [object[]]$ArgumentList    = @(),
        [string]$ActionDescription = 'Action'
    )

    for ($Attempt = 1; $Attempt -le $script:MaxAttempts; $Attempt++) {
        try {
            & $ScriptBlock @ArgumentList
            return $true
        }
        catch {
            Add-LogLine -Message "$ActionDescription failed (attempt $Attempt/$($script:MaxAttempts)): $($_.Exception.Message)" -Level 'WARN'
            if ($Attempt -lt $script:MaxAttempts) {
                Start-Sleep -Seconds $script:RetryDelaySeconds
            }
        }
    }

    return $false
}

# -----------------------------------------------------------------------------
# MAIN - outer try/catch ensures no unhandled exception can produce a non-zero
# exit code. AppX bloatware removal is a non-critical provisioning step and
# must never block the Autopilot / White Glove ESP dependency chain.
# -----------------------------------------------------------------------------
try {
    # Pre-capture identity before the first DiagLog call. [WindowsIdentity]::GetCurrent().Name is
    # evaluated in the caller's scope - any failure would propagate before Write-DiagLog is reached.
    try { $RunningAs = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name } catch { $RunningAs = 'unknown' }
    Write-DiagLog "=== Script started v$($script:AppVersion) - PID=$PID User=$RunningAs ==="

    # -------------------------------------------------------------------------
    # OS Guard: Windows 11 Only (Build 22000+)
    # -------------------------------------------------------------------------
    try {
        $OsInfo      = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
        $BuildNumber = [int]$OsInfo.CurrentBuildNumber
        Write-DiagLog "OS guard: BuildNumber=$BuildNumber (threshold=22000)"
    }
    catch {
        # [SYSTEM] - Cannot read OS build. Transient state: exit without a marker so
        # Intune can retry once the registry is accessible.
        Write-DiagLog "OS guard: FAILED to read build number - $($_.Exception.Message)"
        Add-LogLine -Message "Unable to read OS build number. Exiting safely without removal. ($($_.Exception.Message))" -Level 'WARN'
        Write-LogIfNeeded
        exit 0
    }

    if ($BuildNumber -lt 22000) {
        # Definitive skip: build will not reach 22000+ without an OS upgrade.
        # Write marker so detection permanently suppresses future install attempts.
        Write-DiagLog "OS guard: build $BuildNumber < 22000 - writing SkippedNotWindows11 marker and exiting"
        Write-Marker -Lines (New-MarkerLines -Status 'SkippedNotWindows11' -AdditionalLines @("OSBuild=$BuildNumber"))
        Write-LogIfNeeded
        exit 0
    }

    # -------------------------------------------------------------------------
    # White Glove / Autopilot Guard
    #
    # Primary:   Real user profiles via Win32_UserProfile (WMI), with C:\Users +
    #            NTUSER.DAT filesystem fallback. A $null result means neither method
    #            could determine state - fail OPEN and proceed, since this is the
    #            expected condition during White Glove provisioning.
    # Secondary: Active non-provisioning interactive session (safety catch for edge
    #            cases where a session is active but a profile folder does not yet exist).
    # -------------------------------------------------------------------------
    Write-DiagLog "Profile guard: calling Get-RealUserProfiles"
    $RealProfiles = Get-RealUserProfiles

    if ($null -eq $RealProfiles) {
        # Both detection methods failed - cannot determine provisioning state.
        # Fail OPEN: proceed with removal rather than blocking indefinitely.
        # During White Glove provisioning, WMI and filesystem enumeration both
        # consistently fail - this is exactly when we need the script to run.
        Write-DiagLog "Profile guard: result=NULL (undetermined) - proceeding fail-open"
    }
    elseif ($RealProfiles.Count -gt 0) {
        # Definitive skip: real user profiles exist; device has been in production.
        # Write marker to permanently suppress future install attempts.
        $ProfileNames = ($RealProfiles.Name | Sort-Object -Unique) -join ', '
        Write-DiagLog "Profile guard: real profiles found ($ProfileNames) - writing SkippedPostOOBE marker and exiting"
        Write-Marker -Lines (New-MarkerLines -Status 'SkippedPostOOBE' -AdditionalLines @("Profiles=$ProfileNames"))
        Write-LogIfNeeded
        exit 0
    }
    else {
        Write-DiagLog "Profile guard: no real user profiles - proceeding to session guard"
    }

    $LoggedOnUser = Get-InteractiveUserName
    Write-DiagLog "Session guard: LoggedOnUser='$LoggedOnUser'"

    $IsProvisioning = Test-IsProvisioningIdentity -UserName $LoggedOnUser
    Write-DiagLog "Session guard: IsProvisioningIdentity=$IsProvisioning (regex='$script:ProvisioningUserRegex')"

    if (-not $IsProvisioning) {
        # Non-provisioning user is active. Transient state: exit without a marker so
        # Intune retries after the session ends or user profiles are created.
        Write-DiagLog "Session guard: non-provisioning user active - exiting without marker"
        Write-LogIfNeeded
        exit 0
    }

    Write-DiagLog "All guards passed - proceeding to AppX enumeration"

    # -------------------------------------------------------------------------
    # Enumerate Matching Packages
    # Each enumeration is retried up to MaxAttempts times in case the AppX
    # deployment service or DISM stack is transiently unavailable during ESP.
    # -------------------------------------------------------------------------
    $InstalledPackages   = @()
    $ProvisionedPackages = @()

    Write-DiagLog "Enumeration: starting Get-AppxPackage -AllUsers"
    for ($Attempt = 1; $Attempt -le $script:MaxAttempts; $Attempt++) {
        try {
            $InstalledPackages = @(
                Get-AppxPackage -AllUsers -ErrorAction Stop |
                    Where-Object { $script:UninstallPackages -contains $_.Name } |
                    Sort-Object -Property PackageFullName
            )
            Write-DiagLog "Enumeration: Get-AppxPackage succeeded (attempt $Attempt) - matched=$($InstalledPackages.Count)"
            break
        }
        catch {
            # [SYSTEM/PERMISSIONS] - AppX service may be temporarily unavailable during ESP
            Write-DiagLog "Enumeration: Get-AppxPackage FAILED (attempt $Attempt/$($script:MaxAttempts)) - $($_.Exception.Message)"
            Add-LogLine -Message "Get-AppxPackage -AllUsers failed (attempt $Attempt/$($script:MaxAttempts)): $($_.Exception.Message)" -Level 'WARN'
            if ($Attempt -lt $script:MaxAttempts) { Start-Sleep -Seconds $script:RetryDelaySeconds }
        }
    }

    Write-DiagLog "Enumeration: starting Get-AppxProvisionedPackage -Online"
    for ($Attempt = 1; $Attempt -le $script:MaxAttempts; $Attempt++) {
        try {
            $ProvisionedPackages = @(
                Get-AppxProvisionedPackage -Online -ErrorAction Stop |
                    Where-Object { $script:UninstallPackages -contains $_.DisplayName } |
                    Sort-Object -Property PackageName
            )
            Write-DiagLog "Enumeration: Get-AppxProvisionedPackage succeeded (attempt $Attempt) - matched=$($ProvisionedPackages.Count)"
            break
        }
        catch {
            # [SYSTEM/PERMISSIONS] - DISM/AppX servicing stack may be temporarily unavailable
            Write-DiagLog "Enumeration: Get-AppxProvisionedPackage FAILED (attempt $Attempt/$($script:MaxAttempts)) - $($_.Exception.Message)"
            Add-LogLine -Message "Get-AppxProvisionedPackage -Online failed (attempt $Attempt/$($script:MaxAttempts)): $($_.Exception.Message)" -Level 'WARN'
            if ($Attempt -lt $script:MaxAttempts) { Start-Sleep -Seconds $script:RetryDelaySeconds }
        }
    }

    # -------------------------------------------------------------------------
    # Removal Counters
    # -------------------------------------------------------------------------
    $ProvisionedMatched = $ProvisionedPackages.Count
    $InstalledMatched   = $InstalledPackages.Count

    $ProvisionedRemoved = 0
    $ProvisionedFailed  = 0
    $InstalledRemoved   = 0
    $InstalledFailed    = 0

    Write-DiagLog "Removal: ProvisionedMatched=$ProvisionedMatched InstalledMatched=$InstalledMatched"

    # -------------------------------------------------------------------------
    # Remove Provisioned AppX Packages
    # -------------------------------------------------------------------------
    foreach ($Package in $ProvisionedPackages) {
        $DisplayName = $Package.DisplayName
        $PackageName = $Package.PackageName

        Write-DiagLog "Removal: provisioned [$DisplayName]"
        $Success = Invoke-WithRetry -ActionDescription "Remove provisioned AppX [$DisplayName]" -ArgumentList @($PackageName) -ScriptBlock {
            param($ProvisionedPackageName)
            Remove-AppxProvisionedPackage -Online -PackageName $ProvisionedPackageName -ErrorAction Stop | Out-Null
        }

        if ($Success) { $ProvisionedRemoved++ } else { $ProvisionedFailed++ }
        Write-DiagLog "Removal: provisioned [$DisplayName] success=$Success"
    }

    # -------------------------------------------------------------------------
    # Remove Installed AppX Packages (All Users)
    # -------------------------------------------------------------------------
    foreach ($Package in $InstalledPackages) {
        $Name            = $Package.Name
        $PackageFullName = $Package.PackageFullName

        Write-DiagLog "Removal: installed [$Name]"
        $Success = Invoke-WithRetry -ActionDescription "Remove installed AppX [$Name]" -ArgumentList @($PackageFullName) -ScriptBlock {
            param($InstalledPackageFullName)
            Remove-AppxPackage -Package $InstalledPackageFullName -AllUsers -ErrorAction Stop | Out-Null
        }

        if ($Success) { $InstalledRemoved++ } else { $InstalledFailed++ }
        Write-DiagLog "Removal: installed [$Name] success=$Success"
    }

    # -------------------------------------------------------------------------
    # Write Final Marker and Exit
    # -------------------------------------------------------------------------
    $Status = if ($script:HasWarnings -or $ProvisionedFailed -gt 0 -or $InstalledFailed -gt 0) {
        'CompletedWithWarnings'
    }
    else {
        'Success'
    }

    Write-DiagLog "Final: Status=$Status ProvisionedRemoved=$ProvisionedRemoved/$ProvisionedMatched InstalledRemoved=$InstalledRemoved/$InstalledMatched - calling Write-Marker"

    Write-Marker -Lines (New-MarkerLines -Status $Status -AdditionalLines @(
        "OSBuild=$BuildNumber"
        "TargetListCount=$($script:UninstallPackages.Count)"
        "ProvisionedMatched=$ProvisionedMatched"
        "ProvisionedRemoved=$ProvisionedRemoved"
        "ProvisionedFailed=$ProvisionedFailed"
        "InstalledMatched=$InstalledMatched"
        "InstalledRemoved=$InstalledRemoved"
        "InstalledFailed=$InstalledFailed"
    ))

    Write-DiagLog "Final: Write-Marker returned - marker exists=$(Test-Path -LiteralPath $script:MarkerPath -PathType Leaf)"
    Write-LogIfNeeded
    Write-DiagLog "=== Script exiting 0 ==="
    exit 0
}
catch {
    # Unhandled exception - log and flush the buffer, then exit 0 WITHOUT writing a
    # marker. Omitting the marker allows Intune to retry on the next detection cycle
    # once the transient condition clears. Non-critical cleanup must never permanently
    # suppress reinstallation based on an unknown failure state.
    # Each call is individually protected so that a logging failure cannot prevent
    # the unconditional exit 0 below.
    try { Write-DiagLog "OUTER CATCH: unhandled exception - $($_.Exception.Message) at $($_.InvocationInfo.ScriptLineNumber)" } catch { }
    try { Add-LogLine -Message "Unhandled exception: $($_.Exception.Message)" -Level 'ERROR' }                                   catch { }
    try { Write-LogIfNeeded }                                                                                                     catch { }
    exit 0
}

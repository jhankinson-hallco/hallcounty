<#
.SYNOPSIS
    Deploys the SO.Classic.lnk shortcut to the Windows Startup folder.

.DESCRIPTION
    This Intune Platform Script checks if the SO.Classic.lnk shortcut exists in the 
    All Users Startup folder. If the shortcut does not exist, the script copies it 
    from a specified source location to the Startup folder.
    
    Error logging only occurs when an error happens, writing to C:\IntuneScriptLogs.
    
    Exit Codes:
        0 = Success (shortcut exists or was successfully copied)
        1 = Failure (an error occurred during execution)

.NOTES
    Author:         [Your Name]
    Date Created:   [Date]
    Last Modified:  [Date]
    Version:        1.0
    
    Intune Deployment Settings:
        - Run this script using the logged on credentials: No (runs as SYSTEM)
        - Enforce script signature check: No (unless signed)
        - Run script in 64-bit PowerShell: Yes (recommended)

.EXAMPLE
    Deploy via Intune Platform Scripts:
    Devices > Scripts and remediations > Platform scripts > Add > Windows 10 and later
#>

#==============================================================================
# CONFIGURATION SECTION - Modify these variables for your environment
#==============================================================================

# The name of the shortcut file to deploy
$ShortcutFileName = "SO.Classic.lnk"

# Source location where the shortcut file currently exists
# IMPORTANT: Update this path to where your SO.Classic.lnk file is located
# Common options:
#   - Network share: "\\server\share\shortcuts\SO.Classic.lnk"
#   - Local path (if pre-staged): "C:\Temp\SO.Classic.lnk"
#   - Azure Blob Storage (if using azcopy or similar)
$SourceFilePath = "C:\Temp\SO.Classic.lnk"

# Destination folder - All Users Startup folder (runs for all users at logon)
$DestinationFolder = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"

# Full destination path (constructed automatically)
$DestinationFilePath = Join-Path -Path $DestinationFolder -ChildPath $ShortcutFileName

# Log directory for error logging (per your specifications: C:\IntuneScriptLogs)
$LogDirectory = "C:\IntuneScriptLogs"

# Log file name schema: <application-name>_Install.txt
$LogFileName = "SO.Classic_Install.txt"

# Full log file path (constructed automatically)
$LogFilePath = Join-Path -Path $LogDirectory -ChildPath $LogFileName

#==============================================================================
# FUNCTION DEFINITIONS
#==============================================================================

function Write-ErrorLog {
    <#
    .SYNOPSIS
        Writes error information to the log file.
    
    .DESCRIPTION
        Creates the log directory and file if they don't exist, then appends
        the error message with a timestamp. Per requirements, the directory
        is created first, then the file is created, then content is written
        in separate operations.
    
    .PARAMETER ErrorMessage
        The error message to write to the log file.
    
    .PARAMETER ErrorCode
        Optional error code to include in the log entry.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ErrorMessage,
        
        [Parameter(Mandatory = $false)]
        [string]$ErrorCode = "N/A"
    )
    
    try {
        # Step 1: Check if log directory exists, create if not
        if (-not (Test-Path -Path $LogDirectory -PathType Container)) {
            # Create the log directory
            New-Item -Path $LogDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
        
        # Step 2: Check if log file exists, create if not (separate from writing)
        if (-not (Test-Path -Path $LogFilePath -PathType Leaf)) {
            # Create the log file (empty)
            New-Item -Path $LogFilePath -ItemType File -Force -ErrorAction Stop | Out-Null
        }
        
        # Step 3: Write to the log file (separate operation from creation)
        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $LogEntry = "[$Timestamp] ERROR CODE: $ErrorCode | $ErrorMessage"
        
        # Append the log entry to the file
        Add-Content -Path $LogFilePath -Value $LogEntry -ErrorAction Stop
    }
    catch {
        # If logging itself fails, write to stderr so Intune captures it
        # This is a last resort - logging should not prevent script completion
        Write-Error "CRITICAL: Failed to write to error log. Original error: $ErrorMessage. Logging error: $($_.Exception.Message)"
    }
}

#==============================================================================
# MAIN SCRIPT EXECUTION
#==============================================================================

try {
    #--------------------------------------------------------------------------
    # STEP 1: Check if the shortcut already exists at the destination
    #--------------------------------------------------------------------------
    # Using Test-Path to verify if the file already exists in the Startup folder
    # If it exists, no action is needed and we can exit successfully
    
    if (Test-Path -Path $DestinationFilePath -PathType Leaf) {
        # Shortcut already exists - no action needed
        # Exit with code 0 (success) - Intune will mark this as successful
        exit 0
    }
    
    #--------------------------------------------------------------------------
    # STEP 2: Verify the source file exists before attempting to copy
    #--------------------------------------------------------------------------
    # This prevents Copy-Item from failing with a cryptic error if the source
    # is missing. We provide a clear, actionable error message instead.
    
    if (-not (Test-Path -Path $SourceFilePath -PathType Leaf)) {
        # Source file not found - this is a configuration error
        $ErrorMsg = "SOURCE FILE NOT FOUND: The source shortcut file was not found at '$SourceFilePath'. Verify the source path is correct and the file exists."
        
        # Log the error (creates log directory and file only on error)
        Write-ErrorLog -ErrorMessage $ErrorMsg -ErrorCode "SRC_NOT_FOUND"
        
        # Write to stderr so Intune captures the failure reason
        Write-Error $ErrorMsg
        
        # Exit with code 1 (failure)
        exit 1
    }
    
    #--------------------------------------------------------------------------
    # STEP 3: Verify the destination folder exists
    #--------------------------------------------------------------------------
    # The Startup folder should always exist on Windows, but we verify anyway
    # for maximum reliability and to provide a clear error if something is wrong
    
    if (-not (Test-Path -Path $DestinationFolder -PathType Container)) {
        # Destination folder not found - this indicates a system issue
        $ErrorMsg = "DESTINATION FOLDER NOT FOUND: The Startup folder was not found at '$DestinationFolder'. This may indicate a corrupted Windows installation."
        
        # Log the error
        Write-ErrorLog -ErrorMessage $ErrorMsg -ErrorCode "DEST_NOT_FOUND"
        
        # Write to stderr
        Write-Error $ErrorMsg
        
        # Exit with code 1 (failure)
        exit 1
    }
    
    #--------------------------------------------------------------------------
    # STEP 4: Copy the shortcut file to the destination
    #--------------------------------------------------------------------------
    # Using Copy-Item with -Force to overwrite if a partial/corrupted file exists
    # Using -ErrorAction Stop to ensure errors are terminating and caught by try/catch
    
    Copy-Item -Path $SourceFilePath -Destination $DestinationFilePath -Force -ErrorAction Stop
    
    #--------------------------------------------------------------------------
    # STEP 5: Verify the copy was successful
    #--------------------------------------------------------------------------
    # After copying, we verify the file exists at the destination
    # This catches edge cases where Copy-Item might not throw an error but fail silently
    
    if (-not (Test-Path -Path $DestinationFilePath -PathType Leaf)) {
        # Copy appeared to succeed but file doesn't exist
        $ErrorMsg = "COPY VERIFICATION FAILED: Copy-Item completed without error, but the file was not found at the destination '$DestinationFilePath'. This may indicate a permissions issue or disk problem."
        
        # Log the error
        Write-ErrorLog -ErrorMessage $ErrorMsg -ErrorCode "VERIFY_FAILED"
        
        # Write to stderr
        Write-Error $ErrorMsg
        
        # Exit with code 1 (failure)
        exit 1
    }
    
    #--------------------------------------------------------------------------
    # STEP 6: Success - shortcut deployed successfully
    #--------------------------------------------------------------------------
    # No logging on success (per requirements: logging only occurs when an error happens)
    # Exit with code 0 (success)
    
    exit 0
}
catch {
    #--------------------------------------------------------------------------
    # CATCH BLOCK: Handle any unexpected errors
    #--------------------------------------------------------------------------
    # This catches any errors not explicitly handled above
    # Including Copy-Item failures, permission issues, etc.
    
    # Get detailed error information
    $ErrorMsg = "UNEXPECTED ERROR: $($_.Exception.Message)"
    
    # Get the error code if available (some operations provide specific codes)
    $ErrorCode = "UNKNOWN"
    if ($_.Exception.HResult) {
        $ErrorCode = "0x{0:X8}" -f $_.Exception.HResult
    }
    elseif ($_.Exception.ErrorCode) {
        $ErrorCode = $_.Exception.ErrorCode
    }
    
    # Log the error with full details
    Write-ErrorLog -ErrorMessage $ErrorMsg -ErrorCode $ErrorCode
    
    # Write to stderr so Intune captures the error
    Write-Error $ErrorMsg
    
    # Exit with code 1 (failure)
    exit 1
}

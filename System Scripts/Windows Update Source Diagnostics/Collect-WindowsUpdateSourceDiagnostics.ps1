#requires -version 5.1

<#
.SYNOPSIS
    Collects Windows Update, WSUS, Group Policy, Intune MDM, domain, and network
    evidence without changing update or policy state.

.DESCRIPTION
    Creates a timestamped evidence folder and ZIP archive. The collection is
    designed to determine why an Intune-enrolled domain device uses Microsoft
    Update, Windows Update, or WSUS.

    Run this script before gpupdate, an Intune sync, clicking Check for updates,
    changing OU placement, or changing any update policy. Those actions can
    replace the pre-test evidence that this script is intended to preserve.

    The script does not refresh Group Policy, initiate an update scan, install
    updates, change update service registration, or modify policy registry data.

.PARAMETER OutputRoot
    Parent directory for the timestamped evidence folder and ZIP archive.

.PARAMETER ExpectedComputerName
    Expected endpoint name. A mismatch is recorded prominently in the report.

.PARAMETER ExpectedDomainName
    AD DNS domain used for secure-channel and AD policy-scope checks.

.PARAMETER ExpectedWsusGpoName
    Display name of the expected domain WSUS GPO.

.PARAMETER ExpectedWsusExceptionGroup
    AD group that is denied Apply Group Policy on the expected WSUS GPO.

.PARAMETER EventLookbackDays
    Number of days of relevant events to export. Default is 14.

.PARAMETER SkipMdmDiagnostics
    Skips creation of the Microsoft MDM diagnostics CAB.

.PARAMETER SkipWindowsUpdateLog
    Skips conversion of Windows Update ETL files into WindowsUpdate.log.

.NOTES
    Version:        1.0.0
    Script Type:    Standalone Windows Update Diagnostic Collector
    Author:         Jeremy Hankinson
    Owner:          Hall County Georgia MIS
    WWW:            https://github.com/jhankinson-hallco/hallcounty
    Creation Date:  05/08/2026
    Purpose:        Diagnose Windows Update, Microsoft Update, and WSUS source selection

    CHANGE LOG
    Change: 05/08/2026 - Initial release -- ver. 1.0.0
#>

param(
    [string]$OutputRoot = 'C:\WindowsUpdateSourceDiagnostics',
    [string]$ExpectedComputerName = 'TA-PF47WVTR',
    [string]$ExpectedDomainName = 'hallcounty.org',
    [string]$ExpectedWsusGpoName = 'WSUS - Internal (TC18)',
    [string]$ExpectedWsusExceptionGroup = 'GPO Exception_WSUS - Internal',
    [int]$EventLookbackDays = 14,
    [switch]$SkipMdmDiagnostics,
    [switch]$SkipWindowsUpdateLog
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region CONFIGURATION
$script:ScriptVersion = '1.0.0'
$script:CollectionStatus = New-Object System.Collections.ArrayList
$script:CollectionErrorsPath = $null
$script:PolicySnapshot = $null
$script:UpdateServices = @()
$script:SourceRows = @()
$script:AdContext = $null
$script:GpResultText = ''
$script:SecureChannelText = ''
$script:Utf8Bom = New-Object System.Text.UTF8Encoding($true)
$script:StartTime = Get-Date
#endregion CONFIGURATION

function Get-SafePropertyValue {
    param(
        $InputObject,
        [string]$Name
    )

    if ($null -eq $InputObject) {
        return $null
    }

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function ConvertTo-DisplayValue {
    param(
        $Value
    )

    if ($null -eq $Value) {
        return '<not configured>'
    }

    if ($Value -is [System.Array]) {
        return (($Value | ForEach-Object { [string]$_ }) -join '; ')
    }

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return '<blank>'
    }

    return $text
}

function Write-Utf8File {
    param(
        [string]$LiteralPath,
        [string]$Content
    )

    [System.IO.File]::WriteAllText($LiteralPath, $Content, $script:Utf8Bom)
}

function Write-ObjectFile {
    param(
        [string]$LiteralPath,
        $InputObject
    )

    $text = $InputObject | Format-List * | Out-String -Width 4096
    Write-Utf8File -LiteralPath $LiteralPath -Content $text
}

function Write-CollectionError {
    param(
        [string]$Step,
        $ErrorRecord
    )

    try {
        $message = '[{0}] Step={1}; Type={2}; Message={3}; Position={4}{5}' -f `
            (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),
            $Step,
            $ErrorRecord.Exception.GetType().FullName,
            $ErrorRecord.Exception.Message,
            $ErrorRecord.InvocationInfo.PositionMessage,
            [Environment]::NewLine
        [System.IO.File]::AppendAllText($script:CollectionErrorsPath, $message, $script:Utf8Bom)
    }
    catch {
        [System.Diagnostics.Debug]::WriteLine('Unable to write the collector error log: ' + $_.Exception.Message)
    }
}

function Add-CollectionStatus {
    param(
        [string]$Step,
        [string]$Status,
        [datetime]$Started,
        [string]$Detail
    )

    $row = [pscustomobject]@{
        Step = $Step
        Status = $Status
        Started = $Started
        Finished = Get-Date
        DurationSeconds = [math]::Round(((Get-Date) - $Started).TotalSeconds, 2)
        Detail = $Detail
    }
    [void]$script:CollectionStatus.Add($row)
}

function Invoke-CollectionStep {
    param(
        [string]$Name,
        [scriptblock]$Action
    )

    $started = Get-Date
    try {
        $null = & $Action
        Add-CollectionStatus -Step $Name -Status 'Success' -Started $started -Detail ''
    }
    catch {
        Add-CollectionStatus -Step $Name -Status 'Failed' -Started $started -Detail $_.Exception.Message
        Write-CollectionError -Step $Name -ErrorRecord $_
    }
}

function Invoke-NativeCapture {
    param(
        [string]$FilePath,
        [string]$Arguments,
        [string]$OutputPath,
        [int]$TimeoutSeconds
    )

    $process = $null
    $timedOut = $false
    $exitCode = $null
    $stdout = ''
    $stderr = ''

    try {
        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = $FilePath
        $startInfo.Arguments = $Arguments
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $startInfo
        if (-not $process.Start()) {
            throw 'The process could not be started.'
        }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()

        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $timedOut = $true
            try {
                $process.Kill()
                [void]$process.WaitForExit(5000)
            }
            catch {
                [System.Diagnostics.Debug]::WriteLine('Unable to stop timed-out child process: ' + $_.Exception.Message)
            }
            $exitCode = 1460
        }
        else {
            $process.WaitForExit()
            $exitCode = $process.ExitCode
        }

        if ($process.HasExited) {
            $stdout = $stdoutTask.GetAwaiter().GetResult()
            $stderr = $stderrTask.GetAwaiter().GetResult()
        }
        else {
            $stdout = '<unavailable because the timed-out process did not exit>'
            $stderr = '<unavailable because the timed-out process did not exit>'
        }

        $content = @(
            'Command: ' + $FilePath + ' ' + $Arguments
            'ExitCode: ' + (ConvertTo-DisplayValue -Value $exitCode)
            'TimedOut: ' + $timedOut
            ''
            '--- STDOUT ---'
            $stdout
            ''
            '--- STDERR ---'
            $stderr
        ) -join [Environment]::NewLine
        Write-Utf8File -LiteralPath $OutputPath -Content $content

        return [pscustomobject]@{
            ExitCode = $exitCode
            TimedOut = $timedOut
            StandardOutput = $stdout
            StandardError = $stderr
        }
    }
    finally {
        if ($null -ne $process) {
            $process.Dispose()
        }
    }
}

function Export-RegistryQuery {
    param(
        [string]$NativeRegistryPath,
        [string]$OutputPath
    )

    $regExe = Join-Path $env:SystemRoot 'System32\reg.exe'
    $arguments = 'query "' + $NativeRegistryPath + '" /s'
    $null = Invoke-NativeCapture -FilePath $regExe -Arguments $arguments -OutputPath $OutputPath -TimeoutSeconds 60
}

function ConvertTo-LdapFilterValue {
    param(
        [string]$Value
    )

    if ($null -eq $Value) {
        return ''
    }

    return $Value.Replace('\', '\5c').Replace('*', '\2a').Replace('(', '\28').Replace(')', '\29').Replace([string][char]0, '\00')
}

function Resolve-GpoDisplayName {
    param(
        [string]$GpoDistinguishedName
    )

    try {
        $entry = New-Object System.DirectoryServices.DirectoryEntry('LDAP://' + $GpoDistinguishedName)
        $name = [string]$entry.Properties['displayName'].Value
        if ([string]::IsNullOrWhiteSpace($name)) {
            return '<unresolved>'
        }
        return $name
    }
    catch {
        return '<unresolved: ' + $_.Exception.Message + '>'
    }
}

function Get-GpoLinksForScope {
    param(
        [string]$ScopeDistinguishedName,
        [string]$ScopeName
    )

    $rows = @()
    $entry = New-Object System.DirectoryServices.DirectoryEntry('LDAP://' + $ScopeDistinguishedName)
    $linkText = [string]$entry.Properties['gPLink'].Value
    foreach ($match in [regex]::Matches($linkText, '\[LDAP://([^;]+);(\d+)\]', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
        $gpoDn = $match.Groups[1].Value
        $options = [int]$match.Groups[2].Value
        $rows += [pscustomobject]@{
            Scope = $ScopeName
            ScopeDistinguishedName = $ScopeDistinguishedName
            GpoDisplayName = Resolve-GpoDisplayName -GpoDistinguishedName $gpoDn
            GpoDistinguishedName = $gpoDn
            LinkEnabled = (($options -band 1) -eq 0)
            Enforced = (($options -band 2) -eq 2)
            LinkOptions = $options
        }
    }

    return ,$rows
}

function Get-AdPolicyContext {
    param(
        [string]$OutputDirectory,
        [string]$ComputerName,
        [string]$WsusGpoName,
        [string]$WsusExceptionGroup
    )

    $rootDse = New-Object System.DirectoryServices.DirectoryEntry('LDAP://RootDSE')
    $domainDn = [string]$rootDse.Properties['defaultNamingContext'].Value
    if ([string]::IsNullOrWhiteSpace($domainDn)) {
        throw 'The default AD naming context could not be read.'
    }

    $domainRoot = New-Object System.DirectoryServices.DirectoryEntry('LDAP://' + $domainDn)
    $computerSearcher = New-Object System.DirectoryServices.DirectorySearcher($domainRoot)
    $computerSearcher.Filter = '(&(objectCategory=computer)(sAMAccountName=' + (ConvertTo-LdapFilterValue -Value ($ComputerName + '$')) + '))'
    $computerSearcher.SearchScope = [System.DirectoryServices.SearchScope]::Subtree
    foreach ($propertyName in @('name', 'distinguishedName', 'memberOf', 'whenCreated', 'whenChanged', 'pwdLastSet', 'lastLogonTimestamp')) {
        [void]$computerSearcher.PropertiesToLoad.Add($propertyName)
    }
    $computerResult = $computerSearcher.FindOne()
    if ($null -eq $computerResult) {
        throw 'The local computer account was not found in Active Directory.'
    }

    $computerDn = [string]$computerResult.Properties['distinguishedname'][0]
    $computerRecord = [pscustomobject]@{
        ComputerName = $ComputerName
        DistinguishedName = $computerDn
        WhenCreated = if ($computerResult.Properties['whencreated'].Count -gt 0) { [datetime]$computerResult.Properties['whencreated'][0] } else { $null }
        WhenChanged = if ($computerResult.Properties['whenchanged'].Count -gt 0) { [datetime]$computerResult.Properties['whenchanged'][0] } else { $null }
        PasswordLastSetRaw = if ($computerResult.Properties['pwdlastset'].Count -gt 0) { [long]$computerResult.Properties['pwdlastset'][0] } else { $null }
        LastLogonTimestampRaw = if ($computerResult.Properties['lastlogontimestamp'].Count -gt 0) { [long]$computerResult.Properties['lastlogontimestamp'][0] } else { $null }
    }
    Write-ObjectFile -LiteralPath (Join-Path $OutputDirectory 'AD-Computer-Object.txt') -InputObject $computerRecord

    $directGroups = @()
    foreach ($groupDnValue in $computerResult.Properties['memberof']) {
        $directGroups += [pscustomobject]@{ DistinguishedName = [string]$groupDnValue }
    }
    $directGroups | Export-Csv -LiteralPath (Join-Path $OutputDirectory 'AD-Computer-Direct-Groups.csv') -NoTypeInformation -Encoding UTF8

    $ouRows = @()
    $parentDn = $computerDn.Substring($computerDn.IndexOf(',') + 1)
    while ($parentDn -like 'OU=*') {
        $ouEntry = New-Object System.DirectoryServices.DirectoryEntry('LDAP://' + $parentDn)
        $options = 0
        if ($ouEntry.Properties['gPOptions'].Count -gt 0) {
            $options = [int]$ouEntry.Properties['gPOptions'].Value
        }
        $ouRows += [pscustomobject]@{
            Name = [string]$ouEntry.Properties['name'].Value
            DistinguishedName = $parentDn
            GPOptions = $options
            BlockInheritance = (($options -band 1) -eq 1)
        }
        $parentDn = $parentDn.Substring($parentDn.IndexOf(',') + 1)
    }
    $ouRows | Export-Csv -LiteralPath (Join-Path $OutputDirectory 'AD-OU-Ancestry.csv') -NoTypeInformation -Encoding UTF8

    $gpoLinkRows = @()
    $gpoLinkRows += Get-GpoLinksForScope -ScopeDistinguishedName $domainDn -ScopeName ($domainDn + ' (domain)')
    $orderedOus = @($ouRows)
    [array]::Reverse($orderedOus)
    foreach ($ouRow in $orderedOus) {
        $gpoLinkRows += Get-GpoLinksForScope -ScopeDistinguishedName $ouRow.DistinguishedName -ScopeName $ouRow.Name
    }
    $gpoLinkRows | Export-Csv -LiteralPath (Join-Path $OutputDirectory 'AD-GPO-Links-In-Scope.csv') -NoTypeInformation -Encoding UTF8

    $policiesDn = 'CN=Policies,CN=System,' + $domainDn
    $policyRoot = New-Object System.DirectoryServices.DirectoryEntry('LDAP://' + $policiesDn)
    $gpoSearcher = New-Object System.DirectoryServices.DirectorySearcher($policyRoot)
    $gpoSearcher.Filter = '(&(objectClass=groupPolicyContainer)(displayName=' + (ConvertTo-LdapFilterValue -Value $WsusGpoName) + '))'
    $gpoSearcher.SearchScope = [System.DirectoryServices.SearchScope]::OneLevel
    $gpoSearcher.SecurityMasks = [System.DirectoryServices.SecurityMasks]::Dacl
    foreach ($propertyName in @('displayName', 'name', 'flags', 'gPCWQLFilter', 'gPCFileSysPath', 'versionNumber', 'distinguishedName')) {
        [void]$gpoSearcher.PropertiesToLoad.Add($propertyName)
    }
    $gpoResult = $gpoSearcher.FindOne()

    $gpoRecord = $null
    $aclRows = @()
    $expectedLink = $null
    $gpoSysvolAccessible = $false
    if ($null -ne $gpoResult) {
        $flags = 0
        if ($gpoResult.Properties['flags'].Count -gt 0) {
            $flags = [int]$gpoResult.Properties['flags'][0]
        }
        $wmiFilter = $null
        if ($gpoResult.Properties['gpcwqlfilter'].Count -gt 0) {
            $wmiFilter = [string]$gpoResult.Properties['gpcwqlfilter'][0]
        }
        $gpoDn = [string]$gpoResult.Properties['distinguishedname'][0]
        $expectedLink = $gpoLinkRows | Where-Object { $_.GpoDistinguishedName -ieq $gpoDn } | Select-Object -First 1
        $gpoFileSysPath = [string]$gpoResult.Properties['gpcfilesyspath'][0]
        $gpoRecord = [pscustomobject]@{
            DisplayName = [string]$gpoResult.Properties['displayname'][0]
            Guid = [string]$gpoResult.Properties['name'][0]
            DistinguishedName = $gpoDn
            ComputerConfigurationEnabled = (($flags -band 2) -eq 0)
            UserConfigurationEnabled = (($flags -band 1) -eq 0)
            WmiFilter = if ([string]::IsNullOrWhiteSpace($wmiFilter)) { '<none>' } else { $wmiFilter }
            FileSysPath = $gpoFileSysPath
            VersionNumber = [int]$gpoResult.Properties['versionnumber'][0]
            LinkScope = if ($null -eq $expectedLink) { '<not found in path>' } else { $expectedLink.Scope }
            LinkEnabled = if ($null -eq $expectedLink) { $false } else { $expectedLink.LinkEnabled }
            LinkEnforced = if ($null -eq $expectedLink) { $false } else { $expectedLink.Enforced }
        }
        Write-ObjectFile -LiteralPath (Join-Path $OutputDirectory 'AD-Expected-WSUS-GPO.txt') -InputObject $gpoRecord

        try {
            $gptIniPath = Join-Path $gpoFileSysPath 'GPT.INI'
            $machineRegistryPolPath = Join-Path $gpoFileSysPath 'Machine\Registry.pol'
            $gpoSysvolAccessible = Test-Path -LiteralPath $gpoFileSysPath
            $sysvolRecord = [pscustomobject]@{
                GpoFileSysPath = $gpoFileSysPath
                GpoPathAccessible = $gpoSysvolAccessible
                GptIniPresent = Test-Path -LiteralPath $gptIniPath
                MachineRegistryPolPresent = Test-Path -LiteralPath $machineRegistryPolPath
                GptIniLastWriteTimeUtc = if (Test-Path -LiteralPath $gptIniPath) { (Get-Item -LiteralPath $gptIniPath).LastWriteTimeUtc } else { $null }
                MachineRegistryPolLastWriteTimeUtc = if (Test-Path -LiteralPath $machineRegistryPolPath) { (Get-Item -LiteralPath $machineRegistryPolPath).LastWriteTimeUtc } else { $null }
                MachineRegistryPolSHA256 = if (Test-Path -LiteralPath $machineRegistryPolPath) { (Get-FileHash -LiteralPath $machineRegistryPolPath -Algorithm SHA256).Hash } else { $null }
            }
            Write-ObjectFile -LiteralPath (Join-Path $OutputDirectory 'AD-Expected-WSUS-GPO-SYSVOL.txt') -InputObject $sysvolRecord
            if (Test-Path -LiteralPath $gptIniPath) {
                Copy-Item -LiteralPath $gptIniPath -Destination (Join-Path $OutputDirectory 'Expected-WSUS-GPO-GPT.INI') -Force -ErrorAction Stop
            }
            if (Test-Path -LiteralPath $machineRegistryPolPath) {
                Copy-Item -LiteralPath $machineRegistryPolPath -Destination (Join-Path $OutputDirectory 'Expected-WSUS-GPO-Machine-Registry.pol') -Force -ErrorAction Stop
            }
        }
        catch {
            Write-Utf8File -LiteralPath (Join-Path $OutputDirectory 'AD-Expected-WSUS-GPO-SYSVOL-Error.txt') -Content $_.Exception.ToString()
        }

        $gpoEntry = $gpoResult.GetDirectoryEntry()
        $applyGuid = [Guid]'edacfd8f-ffb3-11d1-b41d-00a0c968f939'
        foreach ($rule in $gpoEntry.ObjectSecurity.GetAccessRules($true, $true, [System.Security.Principal.NTAccount])) {
            if ($rule.ObjectType -eq $applyGuid -or $rule.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Deny) {
                $aclRows += [pscustomobject]@{
                    Identity = $rule.IdentityReference.Value
                    AccessControlType = [string]$rule.AccessControlType
                    Rights = [string]$rule.ActiveDirectoryRights
                    ObjectType = [string]$rule.ObjectType
                    IsInherited = $rule.IsInherited
                }
            }
        }
        $aclRows | Export-Csv -LiteralPath (Join-Path $OutputDirectory 'AD-Expected-WSUS-GPO-ACL.csv') -NoTypeInformation -Encoding UTF8
    }
    else {
        Write-Utf8File -LiteralPath (Join-Path $OutputDirectory 'AD-Expected-WSUS-GPO.txt') -Content ('GPO not found: ' + $WsusGpoName)
    }

    $exceptionMembership = $false
    $exceptionGroupDn = $null
    $groupSearcher = New-Object System.DirectoryServices.DirectorySearcher($domainRoot)
    $groupSearcher.Filter = '(&(objectCategory=group)(sAMAccountName=' + (ConvertTo-LdapFilterValue -Value $WsusExceptionGroup) + '))'
    $groupSearcher.SearchScope = [System.DirectoryServices.SearchScope]::Subtree
    [void]$groupSearcher.PropertiesToLoad.Add('distinguishedName')
    $groupResult = $groupSearcher.FindOne()
    if ($null -ne $groupResult) {
        $exceptionGroupDn = [string]$groupResult.Properties['distinguishedname'][0]
        $membershipSearcher = New-Object System.DirectoryServices.DirectorySearcher($domainRoot)
        $membershipSearcher.Filter = '(&(objectCategory=computer)(sAMAccountName=' + (ConvertTo-LdapFilterValue -Value ($ComputerName + '$')) + ')(memberOf:1.2.840.113556.1.4.1941:=' + (ConvertTo-LdapFilterValue -Value $exceptionGroupDn) + '))'
        $membershipSearcher.SearchScope = [System.DirectoryServices.SearchScope]::Subtree
        $exceptionMembership = ($null -ne $membershipSearcher.FindOne())
    }

    $hasInheritanceBlock = (@($ouRows | Where-Object { $_.BlockInheritance }).Count -gt 0)
    $structurallyInScope = $false
    if ($null -ne $gpoRecord -and $null -ne $expectedLink) {
        $structurallyInScope = $gpoRecord.ComputerConfigurationEnabled -and
            $expectedLink.LinkEnabled -and
            ($expectedLink.Enforced -or -not $hasInheritanceBlock) -and
            -not $exceptionMembership
    }

    $context = [pscustomobject]@{
        DomainDistinguishedName = $domainDn
        ComputerDistinguishedName = $computerDn
        AnyOuBlocksInheritance = $hasInheritanceBlock
        BlockingOus = (($ouRows | Where-Object { $_.BlockInheritance } | ForEach-Object { $_.DistinguishedName }) -join '; ')
        ExpectedWsusGpoFound = ($null -ne $gpoRecord)
        ExpectedWsusGpoLinkFoundInPath = ($null -ne $expectedLink)
        ExpectedWsusGpoLinkEnabled = if ($null -eq $expectedLink) { $false } else { $expectedLink.LinkEnabled }
        ExpectedWsusGpoLinkEnforced = if ($null -eq $expectedLink) { $false } else { $expectedLink.Enforced }
        ExpectedWsusGpoSysvolAccessible = $gpoSysvolAccessible
        ExpectedWsusExceptionGroupDn = $exceptionGroupDn
        ComputerInExpectedWsusExceptionGroup = $exceptionMembership
        StructurallyInScopeForExpectedWsusGpo = $structurallyInScope
    }
    Write-ObjectFile -LiteralPath (Join-Path $OutputDirectory 'AD-Policy-Scope-Summary.txt') -InputObject $context
    return $context
}

function Get-UpdatePolicySnapshot {
    $wuPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
    $auPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
    $pmPath = 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Update'
    $wu = Get-ItemProperty -LiteralPath $wuPath -ErrorAction SilentlyContinue
    $au = Get-ItemProperty -LiteralPath $auPath -ErrorAction SilentlyContinue
    $pm = Get-ItemProperty -LiteralPath $pmPath -ErrorAction SilentlyContinue
    $currentVersion = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue

    return [pscustomobject]@{
        ProductName = Get-SafePropertyValue -InputObject $currentVersion -Name 'ProductName'
        DisplayVersion = Get-SafePropertyValue -InputObject $currentVersion -Name 'DisplayVersion'
        CurrentBuild = Get-SafePropertyValue -InputObject $currentVersion -Name 'CurrentBuild'
        WUServer = Get-SafePropertyValue -InputObject $wu -Name 'WUServer'
        WUStatusServer = Get-SafePropertyValue -InputObject $wu -Name 'WUStatusServer'
        UpdateServiceUrlAlternate = Get-SafePropertyValue -InputObject $wu -Name 'UpdateServiceUrlAlternate'
        UseWUServer = Get-SafePropertyValue -InputObject $au -Name 'UseWUServer'
        UseUpdateClassPolicySource = Get-SafePropertyValue -InputObject $au -Name 'UseUpdateClassPolicySource'
        AUOptions = Get-SafePropertyValue -InputObject $au -Name 'AUOptions'
        NoAutoUpdate = Get-SafePropertyValue -InputObject $au -Name 'NoAutoUpdate'
        DisableDualScan = Get-SafePropertyValue -InputObject $wu -Name 'DisableDualScan'
        DoNotConnectToWindowsUpdateInternetLocations = Get-SafePropertyValue -InputObject $wu -Name 'DoNotConnectToWindowsUpdateInternetLocations'
        DisableWindowsUpdateAccess = Get-SafePropertyValue -InputObject $wu -Name 'DisableWindowsUpdateAccess'
        SetDisableUXWUAccess = Get-SafePropertyValue -InputObject $wu -Name 'SetDisableUXWUAccess'
        SetProxyBehaviorForUpdateDetection = Get-SafePropertyValue -InputObject $wu -Name 'SetProxyBehaviorForUpdateDetection'
        TargetGroupEnabled = Get-SafePropertyValue -InputObject $wu -Name 'TargetGroupEnabled'
        TargetGroup = Get-SafePropertyValue -InputObject $wu -Name 'TargetGroup'
        FeatureSourceRegistry = Get-SafePropertyValue -InputObject $wu -Name 'SetPolicyDrivenUpdateSourceForFeatureUpdates'
        QualitySourceRegistry = Get-SafePropertyValue -InputObject $wu -Name 'SetPolicyDrivenUpdateSourceForQualityUpdates'
        DriverSourceRegistry = Get-SafePropertyValue -InputObject $wu -Name 'SetPolicyDrivenUpdateSourceForDriverUpdates'
        OtherSourceRegistry = Get-SafePropertyValue -InputObject $wu -Name 'SetPolicyDrivenUpdateSourceForOtherUpdates'
        FeatureSourcePolicyManager = Get-SafePropertyValue -InputObject $pm -Name 'SetPolicyDrivenUpdateSourceForFeatureUpdates'
        QualitySourcePolicyManager = Get-SafePropertyValue -InputObject $pm -Name 'SetPolicyDrivenUpdateSourceForQualityUpdates'
        DriverSourcePolicyManager = Get-SafePropertyValue -InputObject $pm -Name 'SetPolicyDrivenUpdateSourceForDriverUpdates'
        OtherSourcePolicyManager = Get-SafePropertyValue -InputObject $pm -Name 'SetPolicyDrivenUpdateSourceForOtherUpdates'
        AllowMUUpdateServicePolicyManager = Get-SafePropertyValue -InputObject $pm -Name 'AllowMUUpdateService'
        AllowMUUpdateServiceWinningProvider = Get-SafePropertyValue -InputObject $pm -Name 'AllowMUUpdateService_WinningProvider'
        DeferFeatureUpdatesPeriodInDays = Get-SafePropertyValue -InputObject $pm -Name 'DeferFeatureUpdatesPeriodInDays'
        DeferQualityUpdatesPeriodInDays = Get-SafePropertyValue -InputObject $pm -Name 'DeferQualityUpdatesPeriodInDays'
        BranchReadinessLevel = Get-SafePropertyValue -InputObject $pm -Name 'BranchReadinessLevel'
        ExcludeWUDriversInQualityUpdate = Get-SafePropertyValue -InputObject $pm -Name 'ExcludeWUDriversInQualityUpdate'
    }
}

function Select-ClassSourceValue {
    param(
        $RegistryValue,
        $PolicyManagerValue
    )

    if ($null -ne $RegistryValue) {
        return $RegistryValue
    }
    return $PolicyManagerValue
}

function Get-ClassSourceInterpretation {
    param(
        $UseWUServer,
        $UseClassPolicy,
        $ClassSourceValue
    )

    if ($UseClassPolicy -eq 1 -and $ClassSourceValue -eq 0) {
        return 'Windows Update / Microsoft Update - explicitly selected for this class'
    }
    if ($UseClassPolicy -eq 1 -and $ClassSourceValue -eq 1) {
        return 'WSUS - explicitly selected for this class'
    }
    if ($null -ne $ClassSourceValue -and $UseClassPolicy -ne 1) {
        return 'Class-source value exists, but UseUpdateClassPolicySource is not 1; verify policy activation'
    }
    if ($UseWUServer -eq 1) {
        return 'WSUS by managed-server/default behavior; check Windows 10 legacy dual-scan conditions'
    }
    return 'Windows Update / Microsoft Update because active WSUS selection is not present'
}

function Get-SourceDecisionRows {
    param(
        $Snapshot
    )

    $definitions = @(
        [pscustomobject]@{ Class = 'Feature updates'; Registry = $Snapshot.FeatureSourceRegistry; PolicyManager = $Snapshot.FeatureSourcePolicyManager },
        [pscustomobject]@{ Class = 'Quality updates'; Registry = $Snapshot.QualitySourceRegistry; PolicyManager = $Snapshot.QualitySourcePolicyManager },
        [pscustomobject]@{ Class = 'Driver updates'; Registry = $Snapshot.DriverSourceRegistry; PolicyManager = $Snapshot.DriverSourcePolicyManager },
        [pscustomobject]@{ Class = 'Other Microsoft product updates'; Registry = $Snapshot.OtherSourceRegistry; PolicyManager = $Snapshot.OtherSourcePolicyManager }
    )

    $rows = @()
    foreach ($definition in $definitions) {
        $selected = Select-ClassSourceValue -RegistryValue $definition.Registry -PolicyManagerValue $definition.PolicyManager
        $rows += [pscustomobject]@{
            UpdateClass = $definition.Class
            RegistryClassSource = ConvertTo-DisplayValue -Value $definition.Registry
            PolicyManagerClassSource = ConvertTo-DisplayValue -Value $definition.PolicyManager
            SelectedRawValue = ConvertTo-DisplayValue -Value $selected
            SourceConflict = ($null -ne $definition.Registry -and $null -ne $definition.PolicyManager -and [string]$definition.Registry -ne [string]$definition.PolicyManager)
            ValueMeaning = '0=Windows Update/Microsoft Update; 1=WSUS'
            Interpretation = Get-ClassSourceInterpretation -UseWUServer $Snapshot.UseWUServer -UseClassPolicy $Snapshot.UseUpdateClassPolicySource -ClassSourceValue $selected
        }
    }
    return ,$rows
}

function Get-PolicyManagerProviderRows {
    $rows = @()
    $providerRoot = 'HKLM:\SOFTWARE\Microsoft\PolicyManager\providers'
    if (-not (Test-Path -LiteralPath $providerRoot)) {
        return ,$rows
    }

    $updateKeys = @(Get-ChildItem -LiteralPath $providerRoot -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -eq 'Update' })
    foreach ($updateKey in $updateKeys) {
        $providerGuid = '<unknown>'
        if ($updateKey.Name -match '\\providers\\([^\\]+)\\') {
            $providerGuid = $matches[1]
        }

        $enrollment = Get-ItemProperty -LiteralPath ('HKLM:\SOFTWARE\Microsoft\Enrollments\' + $providerGuid) -ErrorAction SilentlyContinue
        $item = Get-ItemProperty -LiteralPath $updateKey.PSPath -ErrorAction SilentlyContinue
        if ($null -eq $item) {
            continue
        }

        foreach ($property in ($item.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' })) {
            $rows += [pscustomobject]@{
                ProviderGuid = $providerGuid
                EnrollmentProviderID = ConvertTo-DisplayValue -Value (Get-SafePropertyValue -InputObject $enrollment -Name 'ProviderID')
                EnrollmentType = ConvertTo-DisplayValue -Value (Get-SafePropertyValue -InputObject $enrollment -Name 'EnrollmentType')
                EnrollmentUPN = ConvertTo-DisplayValue -Value (Get-SafePropertyValue -InputObject $enrollment -Name 'UPN')
                RegistryKey = $updateKey.Name
                PolicyName = $property.Name
                Value = ConvertTo-DisplayValue -Value $property.Value
            }
        }
    }
    return ,$rows
}

function Get-ComPropertyValue {
    param(
        $ComObject,
        [string]$PropertyName
    )

    try {
        return $ComObject.$PropertyName
    }
    catch {
        return '<unavailable: ' + $_.Exception.Message + '>'
    }
}

function Get-UpdateServiceRows {
    $rows = @()
    $serviceManager = New-Object -ComObject 'Microsoft.Update.ServiceManager'
    foreach ($service in $serviceManager.Services) {
        $rows += [pscustomobject]@{
            Name = Get-ComPropertyValue -ComObject $service -PropertyName 'Name'
            ServiceID = Get-ComPropertyValue -ComObject $service -PropertyName 'ServiceID'
            IsDefaultAUService = Get-ComPropertyValue -ComObject $service -PropertyName 'IsDefaultAUService'
            IsManaged = Get-ComPropertyValue -ComObject $service -PropertyName 'IsManaged'
            IsRegisteredWithAU = Get-ComPropertyValue -ComObject $service -PropertyName 'IsRegisteredWithAU'
            OffersWindowsUpdates = Get-ComPropertyValue -ComObject $service -PropertyName 'OffersWindowsUpdates'
            CanRegisterWithAU = Get-ComPropertyValue -ComObject $service -PropertyName 'CanRegisterWithAU'
            ServiceUrl = Get-ComPropertyValue -ComObject $service -PropertyName 'ServiceUrl'
        }
    }
    return ,$rows
}

function Test-TcpEndpoint {
    param(
        [string]$ComputerName,
        [int]$Port,
        [int]$TimeoutMilliseconds
    )

    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $task = $client.ConnectAsync($ComputerName, $Port)
        $completed = $task.Wait($TimeoutMilliseconds)
        return [pscustomobject]@{
            ComputerName = $ComputerName
            Port = $Port
            Success = ($completed -and $client.Connected)
            Detail = if ($completed -and $client.Connected) { 'TCP connection succeeded' } else { 'TCP connection timed out or failed' }
        }
    }
    catch {
        return [pscustomobject]@{
            ComputerName = $ComputerName
            Port = $Port
            Success = $false
            Detail = $_.Exception.Message
        }
    }
    finally {
        $client.Close()
        $client.Dispose()
    }
}

function Export-EventChannel {
    param(
        [string]$LogName,
        [datetime]$StartTime,
        [string]$OutputDirectory
    )

    $safeName = [regex]::Replace($LogName, '[^A-Za-z0-9._-]', '_')
    $errorPath = Join-Path $OutputDirectory ($safeName + '.error.txt')
    try {
        $logInfo = Get-WinEvent -ListLog $LogName -ErrorAction Stop
        $events = @(Get-WinEvent -FilterHashtable @{ LogName = $LogName; StartTime = $StartTime } -ErrorAction SilentlyContinue)
        $eventRows = foreach ($event in $events) {
            [pscustomobject]@{
                TimeCreated = $event.TimeCreated
                Id = $event.Id
                LevelDisplayName = $event.LevelDisplayName
                ProviderName = $event.ProviderName
                MachineName = $event.MachineName
                RecordId = $event.RecordId
                Message = $event.Message
            }
        }
        $eventRows | Export-Csv -LiteralPath (Join-Path $OutputDirectory ($safeName + '.csv')) -NoTypeInformation -Encoding UTF8

        $milliseconds = [long]([math]::Ceiling(((Get-Date) - $StartTime).TotalMilliseconds))
        $wevtutil = Join-Path $env:SystemRoot 'System32\wevtutil.exe'
        $evtxPath = Join-Path $OutputDirectory ($safeName + '.evtx')
        $arguments = 'epl "' + $LogName + '" "' + $evtxPath + '" /q:"*[System[TimeCreated[timediff(@SystemTime) <= ' + $milliseconds + ']]]" /ow:true'
        $nativeResult = Invoke-NativeCapture -FilePath $wevtutil -Arguments $arguments -OutputPath (Join-Path $OutputDirectory ($safeName + '.wevtutil.txt')) -TimeoutSeconds 120

        return [pscustomobject]@{
            LogName = $LogName
            Enabled = $logInfo.IsEnabled
            RecordCount = $events.Count
            CsvPath = Join-Path $OutputDirectory ($safeName + '.csv')
            EvtxPath = if ($nativeResult.ExitCode -eq 0) { $evtxPath } else { '<EVTX export failed>' }
        }
    }
    catch {
        Write-Utf8File -LiteralPath $errorPath -Content $_.Exception.ToString()
        return [pscustomobject]@{
            LogName = $LogName
            Enabled = $null
            RecordCount = 0
            CsvPath = '<not exported>'
            EvtxPath = '<not exported>'
        }
    }
}

function Copy-EvidenceFile {
    param(
        [string]$Source,
        [string]$DestinationDirectory,
        [string]$DestinationName = ''
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        return
    }

    if ([string]::IsNullOrWhiteSpace($DestinationName)) {
        $DestinationName = [System.IO.Path]::GetFileName($Source)
    }
    $destination = Join-Path $DestinationDirectory $DestinationName
    Copy-Item -LiteralPath $Source -Destination $destination -Force -ErrorAction Stop
}

function Get-SourceDiagnosisText {
    param(
        $Snapshot,
        $SourceDecisionRows,
        $UpdateServiceRows,
        $AdPolicyContext,
        [string]$ComputerName,
        [string]$ExpectedName,
        [string]$WsusGpoName,
        [string]$GpText,
        [string]$SecureChannelOutput
    )

    $lines = New-Object System.Collections.ArrayList
    [void]$lines.Add('WINDOWS UPDATE SOURCE DIAGNOSIS')
    [void]$lines.Add('Generated: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz'))
    [void]$lines.Add('Computer: ' + $ComputerName)
    [void]$lines.Add('Expected computer: ' + $ExpectedName)
    [void]$lines.Add('')

    [void]$lines.Add('HIGH-VALUE FINDINGS')
    if ($ComputerName -ine $ExpectedName) {
        [void]$lines.Add('[WARNING] Computer name does not match the expected test device.')
    }
    else {
        [void]$lines.Add('[PASS] Computer name matches the expected test device.')
    }

    if ($Snapshot.UseWUServer -eq 1 -and -not [string]::IsNullOrWhiteSpace([string]$Snapshot.WUServer)) {
        [void]$lines.Add('[PASS] Active WSUS client policy is present: UseWUServer=1 and WUServer=' + [string]$Snapshot.WUServer)
    }
    else {
        [void]$lines.Add('[CAUSE CANDIDATE] Active WSUS client policy is absent or incomplete. WUServer=' + (ConvertTo-DisplayValue -Value $Snapshot.WUServer) + '; UseWUServer=' + (ConvertTo-DisplayValue -Value $Snapshot.UseWUServer))
    }

    if ($Snapshot.AllowMUUpdateServicePolicyManager -eq 1) {
        [void]$lines.Add('[CONFIRMED] Intune/MDM allows Microsoft Update registration: AllowMUUpdateService=1. Winning provider=' + (ConvertTo-DisplayValue -Value $Snapshot.AllowMUUpdateServiceWinningProvider))
    }
    elseif ($null -eq $Snapshot.AllowMUUpdateServicePolicyManager) {
        [void]$lines.Add('[INFO] AllowMUUpdateService is not configured in the current PolicyManager Update node.')
    }
    else {
        [void]$lines.Add('[INFO] AllowMUUpdateService=' + [string]$Snapshot.AllowMUUpdateServicePolicyManager + '.')
    }

    $muService = $UpdateServiceRows | Where-Object { $_.ServiceID -eq '7971f918-a847-4430-9279-4a52d1efe18d' -or $_.Name -eq 'Microsoft Update' } | Select-Object -First 1
    $wsusService = $UpdateServiceRows | Where-Object { $_.Name -eq 'Windows Server Update Service' -or $_.IsManaged -eq $true } | Select-Object -First 1
    if ($null -ne $muService) {
        [void]$lines.Add('[INFO] Microsoft Update is registered. IsDefaultAUService=' + (ConvertTo-DisplayValue -Value $muService.IsDefaultAUService) + '; IsRegisteredWithAU=' + (ConvertTo-DisplayValue -Value $muService.IsRegisteredWithAU))
    }
    else {
        [void]$lines.Add('[INFO] Microsoft Update is not registered in Update Service Manager.')
    }
    if ($null -ne $wsusService) {
        [void]$lines.Add('[INFO] A managed/WSUS update service is registered. Name=' + [string]$wsusService.Name + '; IsDefaultAUService=' + (ConvertTo-DisplayValue -Value $wsusService.IsDefaultAUService))
    }
    else {
        [void]$lines.Add('[CAUSE CANDIDATE] No managed/WSUS service is registered in Update Service Manager.')
    }

    if ($Snapshot.UseUpdateClassPolicySource -eq 1) {
        [void]$lines.Add('[CONFIRMED] Per-update-class source selection is enabled: UseUpdateClassPolicySource=1.')
    }
    else {
        [void]$lines.Add('[INFO] UseUpdateClassPolicySource=' + (ConvertTo-DisplayValue -Value $Snapshot.UseUpdateClassPolicySource) + '.')
    }

    foreach ($row in $SourceDecisionRows) {
        if ($row.SourceConflict -eq $true) {
            [void]$lines.Add('[CAUSE CANDIDATE] ' + $row.UpdateClass + ' have conflicting registry and PolicyManager source values.')
        }
        elseif ($row.SelectedRawValue -eq '0' -and $Snapshot.UseUpdateClassPolicySource -eq 1) {
            [void]$lines.Add('[CAUSE CONFIRMED] ' + $row.UpdateClass + ' are explicitly directed to Windows Update/Microsoft Update.')
        }
        elseif ($row.SelectedRawValue -eq '1' -and $Snapshot.UseUpdateClassPolicySource -eq 1) {
            [void]$lines.Add('[PASS] ' + $row.UpdateClass + ' are explicitly directed to WSUS.')
        }
        else {
            [void]$lines.Add('[SOURCE] ' + $row.UpdateClass + ': ' + $row.Interpretation)
        }
    }

    $buildNumber = 0
    [void][int]::TryParse([string]$Snapshot.CurrentBuild, [ref]$buildNumber)
    $deferralPolicyPresent = ($null -ne $Snapshot.DeferFeatureUpdatesPeriodInDays -or $null -ne $Snapshot.DeferQualityUpdatesPeriodInDays -or $null -ne $Snapshot.BranchReadinessLevel)
    if ($buildNumber -gt 0 -and $buildNumber -lt 22000 -and $Snapshot.UseWUServer -eq 1 -and $Snapshot.UseUpdateClassPolicySource -ne 1 -and $deferralPolicyPresent -and $Snapshot.DisableDualScan -ne 1) {
        [void]$lines.Add('[CAUSE CANDIDATE] Windows 10 has WSUS plus WUfB deferral policy without active class-source policy or DisableDualScan=1. Legacy dual-scan behavior can direct scans to Windows Update.')
    }

    if ($null -ne $AdPolicyContext) {
        if ($AdPolicyContext.StructurallyInScopeForExpectedWsusGpo) {
            [void]$lines.Add('[PASS] AD placement, inheritance, link state, and known exception membership place this computer in scope for the expected WSUS GPO.')
        }
        else {
            [void]$lines.Add('[CAUSE CANDIDATE] AD structure does not place the computer cleanly in scope for the expected WSUS GPO. See AD-Policy-Scope-Summary.txt.')
        }
        if ($AdPolicyContext.ExpectedWsusGpoSysvolAccessible) {
            [void]$lines.Add('[PASS] The expected WSUS GPO SYSVOL path was accessible during collection.')
        }
        else {
            [void]$lines.Add('[CAUSE CANDIDATE] The expected WSUS GPO SYSVOL path was not confirmed accessible.')
        }
    }
    else {
        [void]$lines.Add('[UNKNOWN] AD policy-scope validation could not be completed.')
    }

    if ($GpText -match [regex]::Escape($WsusGpoName)) {
        [void]$lines.Add('[PASS] gpresult contains the expected WSUS GPO name. Review GPResult-Computer-Z.txt to confirm whether it is applied or denied.')
    }
    else {
        [void]$lines.Add('[CAUSE CANDIDATE] gpresult does not contain the expected WSUS GPO name.')
    }

    if ($SecureChannelOutput -match '(?i)(trusted DC connection status Status = 0x0|NERR_Success|The secure channel between the local computer and the domain.*is in good condition)') {
        [void]$lines.Add('[PASS] Domain secure-channel evidence indicates success.')
    }
    else {
        [void]$lines.Add('[CAUSE CANDIDATE] Domain secure-channel success was not confirmed. Review NLTest-Secure-Channel.txt and Group Policy events.')
    }

    [void]$lines.Add('')
    [void]$lines.Add('SOURCE DECISION MATRIX')
    foreach ($row in $SourceDecisionRows) {
        [void]$lines.Add($row.UpdateClass + ': Raw=' + $row.SelectedRawValue + '; ' + $row.Interpretation)
    }

    [void]$lines.Add('')
    [void]$lines.Add('IMPORTANT INTERPRETATION RULES')
    [void]$lines.Add('- IsDefaultAUService by itself does not prove the source used for every update class.')
    [void]$lines.Add('- Class source 0 means Windows Update/Microsoft Update; class source 1 means WSUS.')
    [void]$lines.Add('- AllowMUUpdateService=1 registers Microsoft Update for other Microsoft products and may remain registered after the setting is removed.')
    [void]$lines.Add('- A registered WSUS service does not prove that current WUServer and UseWUServer policy values are active.')
    [void]$lines.Add('- Do not remediate until this ZIP has been reviewed.')

    [void]$lines.Add('')
    [void]$lines.Add('PRIMARY FILES FOR REVIEW')
    [void]$lines.Add('- 00-Source-Diagnosis.txt')
    [void]$lines.Add('- 00-Source-Decision-Matrix.csv')
    [void]$lines.Add('- 04-Update-Policy-Snapshot.txt')
    [void]$lines.Add('- 05-Update-Services.csv')
    [void]$lines.Add('- GroupPolicy/GPResult-Computer-Z.txt')
    [void]$lines.Add('- GroupPolicy/GPResult-Computer.html')
    [void]$lines.Add('- ActiveDirectory/AD-Policy-Scope-Summary.txt')
    [void]$lines.Add('- MDM/PolicyManager-Update-Current.txt')
    [void]$lines.Add('- MDM/PolicyManager-Provider-Provenance.csv')
    [void]$lines.Add('- Events/*WindowsUpdateClient*.csv')
    [void]$lines.Add('- Events/*GroupPolicy*.csv')
    [void]$lines.Add('- WindowsUpdate/WindowsUpdate.log')

    return ($lines -join [Environment]::NewLine)
}

# MAIN
try {
    if ($EventLookbackDays -lt 1 -or $EventLookbackDays -gt 90) {
        throw 'EventLookbackDays must be between 1 and 90.'
    }

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $isAdministrator = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdministrator) {
        throw 'Run this script from an elevated Windows PowerShell session.'
    }
    if (-not [Environment]::Is64BitProcess) {
        throw 'Run this script in 64-bit Windows PowerShell. Use C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe.'
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $collectionName = $env:COMPUTERNAME + '_WindowsUpdateSourceDiagnostics_' + $timestamp
    [void][System.IO.Directory]::CreateDirectory($OutputRoot)
    $outputDirectory = Join-Path $OutputRoot $collectionName
    [void][System.IO.Directory]::CreateDirectory($outputDirectory)
    $zipPath = Join-Path $OutputRoot ($collectionName + '.zip')
    $script:CollectionErrorsPath = Join-Path $outputDirectory '00-Collection-Errors.txt'
    Write-Utf8File -LiteralPath $script:CollectionErrorsPath -Content ''

    $systemDirectory = Join-Path $outputDirectory 'System'
    $networkDirectory = Join-Path $outputDirectory 'Network'
    $groupPolicyDirectory = Join-Path $outputDirectory 'GroupPolicy'
    $adDirectory = Join-Path $outputDirectory 'ActiveDirectory'
    $registryDirectory = Join-Path $outputDirectory 'Registry'
    $mdmDirectory = Join-Path $outputDirectory 'MDM'
    $eventsDirectory = Join-Path $outputDirectory 'Events'
    $windowsUpdateDirectory = Join-Path $outputDirectory 'WindowsUpdate'
    $logsDirectory = Join-Path $outputDirectory 'EndpointLogs'
    foreach ($directory in @($systemDirectory, $networkDirectory, $groupPolicyDirectory, $adDirectory, $registryDirectory, $mdmDirectory, $eventsDirectory, $windowsUpdateDirectory, $logsDirectory)) {
        [void][System.IO.Directory]::CreateDirectory($directory)
    }

    Write-Output ('Collecting evidence to: ' + $outputDirectory)
    Write-Output 'Do not run gpupdate, Intune sync, or Check for updates until collection completes.'

    Invoke-CollectionStep -Name 'System identity and OS' -Action {
        $operatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop
        $systemRecord = [pscustomobject]@{
            CollectionStartLocal = $script:StartTime
            CollectionStartUtc = $script:StartTime.ToUniversalTime()
            ComputerName = $env:COMPUTERNAME
            ExpectedComputerName = $ExpectedComputerName
            ComputerNameMatchesExpected = ($env:COMPUTERNAME -ieq $ExpectedComputerName)
            CurrentIdentity = $identity.Name
            IsAdministrator = $isAdministrator
            Is64BitProcess = [Environment]::Is64BitProcess
            PowerShellVersion = [string]$PSVersionTable.PSVersion
            PowerShellEdition = $PSVersionTable.PSEdition
            Manufacturer = $computerSystem.Manufacturer
            Model = $computerSystem.Model
            Domain = $computerSystem.Domain
            PartOfDomain = $computerSystem.PartOfDomain
            DomainRole = $computerSystem.DomainRole
            OSCaption = $operatingSystem.Caption
            OSVersion = $operatingSystem.Version
            OSBuildNumber = $operatingSystem.BuildNumber
            OSArchitecture = $operatingSystem.OSArchitecture
            InstallDate = $operatingSystem.InstallDate
            LastBootUpTime = $operatingSystem.LastBootUpTime
            BIOSSerialNumber = $bios.SerialNumber
            BIOSVersion = ($bios.BIOSVersion -join '; ')
            ScriptVersion = $script:ScriptVersion
        }
        Write-ObjectFile -LiteralPath (Join-Path $outputDirectory '01-System-Identity.txt') -InputObject $systemRecord
        $systemJson = $systemRecord | ConvertTo-Json -Depth 5
        Write-Utf8File -LiteralPath (Join-Path $systemDirectory 'System-Identity.json') -Content $systemJson
        Get-HotFix -ErrorAction SilentlyContinue | Sort-Object InstalledOn -Descending | Export-Csv -LiteralPath (Join-Path $systemDirectory 'Installed-Hotfixes.csv') -NoTypeInformation -Encoding UTF8
        Get-CimInstance -ClassName Win32_QuickFixEngineering -ErrorAction SilentlyContinue | Export-Csv -LiteralPath (Join-Path $systemDirectory 'QuickFixEngineering.csv') -NoTypeInformation -Encoding UTF8
    }

    Invoke-CollectionStep -Name 'Domain and Entra join state' -Action {
        $dsregcmd = Join-Path $env:SystemRoot 'System32\dsregcmd.exe'
        $null = Invoke-NativeCapture -FilePath $dsregcmd -Arguments '/status' -OutputPath (Join-Path $systemDirectory 'DSRegCmd-Status.txt') -TimeoutSeconds 60

        $nltest = Join-Path $env:SystemRoot 'System32\nltest.exe'
        $secureResult = Invoke-NativeCapture -FilePath $nltest -Arguments ('/sc_verify:' + $ExpectedDomainName) -OutputPath (Join-Path $networkDirectory 'NLTest-Secure-Channel.txt') -TimeoutSeconds 60
        $script:SecureChannelText = $secureResult.StandardOutput + [Environment]::NewLine + $secureResult.StandardError
        $null = Invoke-NativeCapture -FilePath $nltest -Arguments ('/dsgetdc:' + $ExpectedDomainName + ' /force') -OutputPath (Join-Path $networkDirectory 'NLTest-Domain-Controller.txt') -TimeoutSeconds 60
        $null = Invoke-NativeCapture -FilePath (Join-Path $env:SystemRoot 'System32\whoami.exe') -Arguments '/all' -OutputPath (Join-Path $systemDirectory 'WhoAmI-All.txt') -TimeoutSeconds 60
        $null = Invoke-NativeCapture -FilePath (Join-Path $env:SystemRoot 'System32\klist.exe') -Arguments '-li 0x3e7' -OutputPath (Join-Path $networkDirectory 'Machine-Kerberos-Tickets.txt') -TimeoutSeconds 60
    }

    Invoke-CollectionStep -Name 'Active Directory OU and GPO scope' -Action {
        $script:AdContext = Get-AdPolicyContext -OutputDirectory $adDirectory -ComputerName $env:COMPUTERNAME -WsusGpoName $ExpectedWsusGpoName -WsusExceptionGroup $ExpectedWsusExceptionGroup
    }

    Invoke-CollectionStep -Name 'Resultant Set of Policy' -Action {
        $gpresult = Join-Path $env:SystemRoot 'System32\gpresult.exe'
        $textResult = Invoke-NativeCapture -FilePath $gpresult -Arguments '/scope computer /z' -OutputPath (Join-Path $groupPolicyDirectory 'GPResult-Computer-Z.txt') -TimeoutSeconds 180
        $script:GpResultText = $textResult.StandardOutput + [Environment]::NewLine + $textResult.StandardError
        $htmlPath = Join-Path $groupPolicyDirectory 'GPResult-Computer.html'
        $htmlArguments = '/scope computer /h "' + $htmlPath + '" /f'
        $null = Invoke-NativeCapture -FilePath $gpresult -Arguments $htmlArguments -OutputPath (Join-Path $groupPolicyDirectory 'GPResult-Computer-HTML-Command.txt') -TimeoutSeconds 180

        $registryPol = Join-Path $env:SystemRoot 'System32\GroupPolicy\Machine\Registry.pol'
        if (Test-Path -LiteralPath $registryPol) {
            $registryPolMetadata = Get-Item -LiteralPath $registryPol | Select-Object FullName, Length, CreationTimeUtc, LastWriteTimeUtc | Format-List | Out-String -Width 4096
            Write-Utf8File -LiteralPath (Join-Path $groupPolicyDirectory 'Machine-RegistryPol-Metadata.txt') -Content $registryPolMetadata
            $registryPolHash = Get-FileHash -LiteralPath $registryPol -Algorithm SHA256 | Format-List | Out-String
            Write-Utf8File -LiteralPath (Join-Path $groupPolicyDirectory 'Machine-RegistryPol-SHA256.txt') -Content $registryPolHash
        }
        Export-RegistryQuery -NativeRegistryPath 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy' -OutputPath (Join-Path $groupPolicyDirectory 'Group-Policy-Registry-History.txt')
    }

    Invoke-CollectionStep -Name 'Effective Windows Update policy' -Action {
        $script:PolicySnapshot = Get-UpdatePolicySnapshot
        Write-ObjectFile -LiteralPath (Join-Path $outputDirectory '04-Update-Policy-Snapshot.txt') -InputObject $script:PolicySnapshot
        $policyJson = $script:PolicySnapshot | ConvertTo-Json -Depth 5
        Write-Utf8File -LiteralPath (Join-Path $registryDirectory 'Update-Policy-Snapshot.json') -Content $policyJson
        $script:SourceRows = Get-SourceDecisionRows -Snapshot $script:PolicySnapshot
        $script:SourceRows | Export-Csv -LiteralPath (Join-Path $outputDirectory '00-Source-Decision-Matrix.csv') -NoTypeInformation -Encoding UTF8
    }

    Invoke-CollectionStep -Name 'Raw update registry evidence' -Action {
        $registryQueries = @(
            [pscustomobject]@{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; File = 'Policies-WindowsUpdate.txt' },
            [pscustomobject]@{ Path = 'HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\Update'; File = 'PolicyManager-Current-Device-Update.txt' },
            [pscustomobject]@{ Path = 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate'; File = 'WindowsUpdate-CurrentVersion.txt' },
            [pscustomobject]@{ Path = 'HKLM\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy'; File = 'WindowsUpdate-UpdatePolicy.txt' },
            [pscustomobject]@{ Path = 'HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'; File = 'WindowsUpdate-UX-Settings.txt' },
            [pscustomobject]@{ Path = 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config'; File = 'DeliveryOptimization-Config.txt' },
            [pscustomobject]@{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'; File = 'DeliveryOptimization-Policies.txt' }
        )
        foreach ($query in $registryQueries) {
            Export-RegistryQuery -NativeRegistryPath $query.Path -OutputPath (Join-Path $registryDirectory $query.File)
        }
    }

    Invoke-CollectionStep -Name 'PolicyManager update provenance' -Action {
        $currentPolicy = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Update' -ErrorAction SilentlyContinue
        if ($null -ne $currentPolicy) {
            $currentPolicyText = $currentPolicy.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | Sort-Object Name | Select-Object Name, Value | Format-Table -AutoSize -Wrap | Out-String -Width 4096
            Write-Utf8File -LiteralPath (Join-Path $mdmDirectory 'PolicyManager-Update-Current.txt') -Content $currentPolicyText
        }
        else {
            Write-Utf8File -LiteralPath (Join-Path $mdmDirectory 'PolicyManager-Update-Current.txt') -Content '<PolicyManager current device Update key is absent>'
        }
        $providerRows = Get-PolicyManagerProviderRows
        $providerRows | Export-Csv -LiteralPath (Join-Path $mdmDirectory 'PolicyManager-Provider-Provenance.csv') -NoTypeInformation -Encoding UTF8
    }

    Invoke-CollectionStep -Name 'Windows Update service registration' -Action {
        $script:UpdateServices = Get-UpdateServiceRows
        $script:UpdateServices | Export-Csv -LiteralPath (Join-Path $outputDirectory '05-Update-Services.csv') -NoTypeInformation -Encoding UTF8
        $updateServicesText = $script:UpdateServices | Format-Table -AutoSize -Wrap | Out-String -Width 4096
        Write-Utf8File -LiteralPath (Join-Path $windowsUpdateDirectory 'Update-Services.txt') -Content $updateServicesText

        $autoUpdate = New-Object -ComObject 'Microsoft.Update.AutoUpdate'
        $autoResults = Get-ComPropertyValue -ComObject $autoUpdate -PropertyName 'Results'
        $autoSettings = Get-ComPropertyValue -ComObject $autoUpdate -PropertyName 'Settings'
        $autoRecord = [pscustomobject]@{
            ServiceEnabled = Get-ComPropertyValue -ComObject $autoUpdate -PropertyName 'ServiceEnabled'
            ResultsLastSearchSuccessDate = Get-ComPropertyValue -ComObject $autoResults -PropertyName 'LastSearchSuccessDate'
            ResultsLastInstallationSuccessDate = Get-ComPropertyValue -ComObject $autoResults -PropertyName 'LastInstallationSuccessDate'
            NotificationLevel = Get-ComPropertyValue -ComObject $autoSettings -PropertyName 'NotificationLevel'
            ReadOnly = Get-ComPropertyValue -ComObject $autoSettings -PropertyName 'ReadOnly'
            ScheduledInstallationDay = Get-ComPropertyValue -ComObject $autoSettings -PropertyName 'ScheduledInstallationDay'
            ScheduledInstallationTime = Get-ComPropertyValue -ComObject $autoSettings -PropertyName 'ScheduledInstallationTime'
        }
        Write-ObjectFile -LiteralPath (Join-Path $windowsUpdateDirectory 'Automatic-Updates-State.txt') -InputObject $autoRecord

        $session = New-Object -ComObject 'Microsoft.Update.Session'
        $searcher = $session.CreateUpdateSearcher()
        $searcherRecord = [pscustomobject]@{
            ServerSelectionRaw = Get-ComPropertyValue -ComObject $searcher -PropertyName 'ServerSelection'
            ServiceID = Get-ComPropertyValue -ComObject $searcher -PropertyName 'ServiceID'
            Online = Get-ComPropertyValue -ComObject $searcher -PropertyName 'Online'
            Note = 'No update search was initiated.'
        }
        Write-ObjectFile -LiteralPath (Join-Path $windowsUpdateDirectory 'Default-Update-Searcher-State.txt') -InputObject $searcherRecord
    }

    Invoke-CollectionStep -Name 'Windows Update services and scheduled tasks' -Action {
        $serviceNames = @('wuauserv', 'UsoSvc', 'BITS', 'WaaSMedicSvc', 'DoSvc', 'dmwappushservice', 'Winmgmt', 'gpsvc', 'Netlogon')
        Get-CimInstance -ClassName Win32_Service -ErrorAction Stop |
            Where-Object { $serviceNames -contains $_.Name } |
            Select-Object Name, DisplayName, State, StartMode, Status, ProcessId, PathName |
            Export-Csv -LiteralPath (Join-Path $systemDirectory 'Relevant-Services.csv') -NoTypeInformation -Encoding UTF8

        if (Get-Command -Name Get-ScheduledTask -ErrorAction SilentlyContinue) {
            $taskPaths = @(
                '\Microsoft\Windows\UpdateOrchestrator\',
                '\Microsoft\Windows\WindowsUpdate\',
                '\Microsoft\Windows\WaaSMedic\',
                '\Microsoft\Windows\EnterpriseMgmt\'
            )
            $tasks = @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $taskPaths -contains $_.TaskPath })
            $tasks | Select-Object TaskName, TaskPath, State, Author, Description | Export-Csv -LiteralPath (Join-Path $systemDirectory 'Relevant-Scheduled-Tasks.csv') -NoTypeInformation -Encoding UTF8
            $tasks | Export-Clixml -LiteralPath (Join-Path $systemDirectory 'Relevant-Scheduled-Tasks.clixml') -Depth 5
        }
    }

    Invoke-CollectionStep -Name 'Network, DNS, proxy, and WSUS reachability' -Action {
        $null = Invoke-NativeCapture -FilePath (Join-Path $env:SystemRoot 'System32\ipconfig.exe') -Arguments '/all' -OutputPath (Join-Path $networkDirectory 'IPConfig-All.txt') -TimeoutSeconds 60
        $null = Invoke-NativeCapture -FilePath (Join-Path $env:SystemRoot 'System32\netsh.exe') -Arguments 'winhttp show proxy' -OutputPath (Join-Path $networkDirectory 'WinHTTP-Proxy.txt') -TimeoutSeconds 60
        $null = Invoke-NativeCapture -FilePath (Join-Path $env:SystemRoot 'System32\w32tm.exe') -Arguments '/query /status /verbose' -OutputPath (Join-Path $networkDirectory 'Windows-Time-Status.txt') -TimeoutSeconds 60

        if (Get-Command -Name Get-NetIPConfiguration -ErrorAction SilentlyContinue) {
            $netIpText = Get-NetIPConfiguration -Detailed -ErrorAction SilentlyContinue | Format-List * | Out-String -Width 4096
            Write-Utf8File -LiteralPath (Join-Path $networkDirectory 'NetIPConfiguration.txt') -Content $netIpText
        }

        $connectivityRows = @()
        if ($null -ne $script:PolicySnapshot -and -not [string]::IsNullOrWhiteSpace([string]$script:PolicySnapshot.WUServer)) {
            try {
                $wsusUri = New-Object System.Uri([string]$script:PolicySnapshot.WUServer)
                $port = $wsusUri.Port
                $dnsAddresses = @([System.Net.Dns]::GetHostAddresses($wsusUri.DnsSafeHost) | ForEach-Object { $_.IPAddressToString })
                $dnsRecord = [pscustomobject]@{
                    Host = $wsusUri.DnsSafeHost
                    Addresses = $dnsAddresses -join '; '
                }
                $dnsText = $dnsRecord | Format-List | Out-String
                Write-Utf8File -LiteralPath (Join-Path $networkDirectory 'WSUS-DNS-Resolution.txt') -Content $dnsText
                $connectivityRows += Test-TcpEndpoint -ComputerName $wsusUri.DnsSafeHost -Port $port -TimeoutMilliseconds 10000

                $clientWebServiceUri = $script:PolicySnapshot.WUServer.TrimEnd('/') + '/ClientWebService/client.asmx'
                try {
                    $response = Invoke-WebRequest -Uri $clientWebServiceUri -UseBasicParsing -Method Get -TimeoutSec 20 -ErrorAction Stop
                    $httpRecord = [pscustomobject]@{
                        Uri = $clientWebServiceUri
                        StatusCode = [int]$response.StatusCode
                        StatusDescription = $response.StatusDescription
                        ContentLength = $response.RawContentLength
                    }
                    $httpText = $httpRecord | Format-List | Out-String
                    Write-Utf8File -LiteralPath (Join-Path $networkDirectory 'WSUS-HTTP-Test.txt') -Content $httpText
                }
                catch {
                    Write-Utf8File -LiteralPath (Join-Path $networkDirectory 'WSUS-HTTP-Test.txt') -Content $_.Exception.ToString()
                }
            }
            catch {
                Write-Utf8File -LiteralPath (Join-Path $networkDirectory 'WSUS-Endpoint-Parse-Error.txt') -Content $_.Exception.ToString()
            }
        }
        else {
            Write-Utf8File -LiteralPath (Join-Path $networkDirectory 'WSUS-Reachability-Not-Tested.txt') -Content 'WUServer is not configured, so no WSUS endpoint was available to test.'
        }
        $connectivityRows | Export-Csv -LiteralPath (Join-Path $networkDirectory 'WSUS-TCP-Reachability.csv') -NoTypeInformation -Encoding UTF8
    }

    Invoke-CollectionStep -Name 'Relevant Windows event logs' -Action {
        $eventStart = (Get-Date).AddDays(-1 * $EventLookbackDays)
        $eventLogs = @(
            'Microsoft-Windows-GroupPolicy/Operational',
            'Microsoft-Windows-WindowsUpdateClient/Operational',
            'Microsoft-Windows-UpdateOrchestrator/Operational',
            'Microsoft-Windows-Bits-Client/Operational',
            'Microsoft-Windows-DeliveryOptimization/Operational',
            'Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Admin',
            'Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Operational',
            'Microsoft-Windows-ModernDeployment-Diagnostics-Provider/Autopilot',
            'Microsoft-Windows-ModernDeployment-Diagnostics-Provider/ManagementService',
            'Microsoft-Windows-User Device Registration/Admin',
            'Microsoft-Windows-AAD/Operational'
        )
        $eventInventory = @()
        foreach ($eventLog in $eventLogs) {
            $eventInventory += Export-EventChannel -LogName $eventLog -StartTime $eventStart -OutputDirectory $eventsDirectory
        }
        $eventInventory | Export-Csv -LiteralPath (Join-Path $eventsDirectory 'Event-Export-Inventory.csv') -NoTypeInformation -Encoding UTF8

        $systemEvents = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; StartTime = $eventStart } -ErrorAction SilentlyContinue | Where-Object { $_.ProviderName -match 'GroupPolicy|WindowsUpdateClient|NETLOGON|DNS.Client|Time.Service' })
        $systemEventRows = foreach ($event in $systemEvents) {
            [pscustomobject]@{
                TimeCreated = $event.TimeCreated
                Id = $event.Id
                LevelDisplayName = $event.LevelDisplayName
                ProviderName = $event.ProviderName
                RecordId = $event.RecordId
                Message = $event.Message
            }
        }
        $systemEventRows | Export-Csv -LiteralPath (Join-Path $eventsDirectory 'System-Relevant-Events.csv') -NoTypeInformation -Encoding UTF8
    }

    Invoke-CollectionStep -Name 'Endpoint setup and Intune logs' -Action {
        $fileSources = @(
            [pscustomobject]@{ Source = (Join-Path $env:SystemRoot 'debug\NetSetup.log'); DestinationName = 'NetSetup.log' },
            [pscustomobject]@{ Source = (Join-Path $env:SystemRoot 'Logs\MoSetup\UpdateAgent.log'); DestinationName = 'MoSetup-UpdateAgent.log' },
            [pscustomobject]@{ Source = (Join-Path $env:SystemRoot 'Panther\setupact.log'); DestinationName = 'Panther-setupact.log' },
            [pscustomobject]@{ Source = (Join-Path $env:SystemRoot 'Panther\setuperr.log'); DestinationName = 'Panther-setuperr.log' },
            [pscustomobject]@{ Source = (Join-Path $env:SystemRoot 'Panther\UnattendGC\setupact.log'); DestinationName = 'UnattendGC-setupact.log' },
            [pscustomobject]@{ Source = (Join-Path $env:SystemRoot 'Panther\UnattendGC\setuperr.log'); DestinationName = 'UnattendGC-setuperr.log' }
        )
        foreach ($sourceRecord in $fileSources) {
            Copy-EvidenceFile -Source $sourceRecord.Source -DestinationDirectory $logsDirectory -DestinationName $sourceRecord.DestinationName
        }

        $imeSource = Join-Path $env:ProgramData 'Microsoft\IntuneManagementExtension\Logs'
        if (Test-Path -LiteralPath $imeSource) {
            $imeDestination = Join-Path $logsDirectory 'IntuneManagementExtension'
            [void][System.IO.Directory]::CreateDirectory($imeDestination)
            Get-ChildItem -LiteralPath $imeSource -File -Filter '*.log' -ErrorAction SilentlyContinue | ForEach-Object {
                Copy-Item -LiteralPath $_.FullName -Destination $imeDestination -Force -ErrorAction SilentlyContinue
            }
        }

        $autopilotSource = Join-Path $env:ProgramData 'Microsoft\Provisioning\Diagnostics\AutoPilot'
        if (Test-Path -LiteralPath $autopilotSource) {
            Copy-Item -LiteralPath $autopilotSource -Destination (Join-Path $logsDirectory 'AutoPilot') -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    if (-not $SkipMdmDiagnostics) {
        Invoke-CollectionStep -Name 'Microsoft MDM diagnostics CAB' -Action {
            $mdmTool = Join-Path $env:SystemRoot 'System32\mdmdiagnosticstool.exe'
            if (-not (Test-Path -LiteralPath $mdmTool)) {
                throw 'mdmdiagnosticstool.exe is not present.'
            }
            $cabPath = Join-Path $mdmDirectory 'MDMDiagnostics.cab'
            $arguments = '-area "Autopilot;DeviceEnrollment;DeviceProvisioning" -cab "' + $cabPath + '"'
            $result = Invoke-NativeCapture -FilePath $mdmTool -Arguments $arguments -OutputPath (Join-Path $mdmDirectory 'MDMDiagnosticsTool-Command.txt') -TimeoutSeconds 300
            if ($result.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $cabPath)) {
                throw 'MDM diagnostics CAB creation failed. Review MDMDiagnosticsTool-Command.txt.'
            }
        }
    }
    else {
        Add-CollectionStatus -Step 'Microsoft MDM diagnostics CAB' -Status 'Skipped' -Started (Get-Date) -Detail 'SkipMdmDiagnostics was specified.'
    }

    if (-not $SkipWindowsUpdateLog) {
        Invoke-CollectionStep -Name 'Generate WindowsUpdate.log' -Action {
            $command = Get-Command -Name Get-WindowsUpdateLog -ErrorAction SilentlyContinue
            if ($null -eq $command) {
                throw 'Get-WindowsUpdateLog is not available on this Windows build.'
            }
            Get-WindowsUpdateLog -LogPath (Join-Path $windowsUpdateDirectory 'WindowsUpdate.log') -ErrorAction Stop | Out-Null
        }
    }
    else {
        Add-CollectionStatus -Step 'Generate WindowsUpdate.log' -Status 'Skipped' -Started (Get-Date) -Detail 'SkipWindowsUpdateLog was specified.'
    }

    Invoke-CollectionStep -Name 'Generate source diagnosis' -Action {
        if ($null -eq $script:PolicySnapshot) {
            throw 'The policy snapshot was not collected.'
        }
        $diagnosis = Get-SourceDiagnosisText -Snapshot $script:PolicySnapshot -SourceDecisionRows $script:SourceRows -UpdateServiceRows $script:UpdateServices -AdPolicyContext $script:AdContext -ComputerName $env:COMPUTERNAME -ExpectedName $ExpectedComputerName -WsusGpoName $ExpectedWsusGpoName -GpText $script:GpResultText -SecureChannelOutput $script:SecureChannelText
        Write-Utf8File -LiteralPath (Join-Path $outputDirectory '00-Source-Diagnosis.txt') -Content $diagnosis

        $readme = @(
            'READ THIS FIRST'
            ''
            'This archive was collected before any diagnostic remediation.'
            'Start with 00-Source-Diagnosis.txt and 00-Source-Decision-Matrix.csv.'
            ''
            'The collection does not run gpupdate, initiate an update scan, install updates,'
            'change update service registration, or modify Group Policy/MDM registry values.'
            ''
            'Send the entire ZIP for analysis. Do not send only the Update Service Manager table.'
            ''
            'Sensitive content notice: the archive can contain device identifiers, domain and OU'
            'names, user UPNs, tenant identifiers, network configuration, and policy details.'
        ) -join [Environment]::NewLine
        Write-Utf8File -LiteralPath (Join-Path $outputDirectory '00-README-FIRST.txt') -Content $readme
    }

    $script:CollectionStatus | Export-Csv -LiteralPath (Join-Path $outputDirectory '00-Collection-Status.csv') -NoTypeInformation -Encoding UTF8
    $failedSteps = @($script:CollectionStatus | Where-Object { $_.Status -eq 'Failed' })
    $completionRecord = [pscustomobject]@{
        ComputerName = $env:COMPUTERNAME
        ScriptVersion = $script:ScriptVersion
        Started = $script:StartTime
        Finished = Get-Date
        DurationMinutes = [math]::Round(((Get-Date) - $script:StartTime).TotalMinutes, 2)
        TotalSteps = $script:CollectionStatus.Count
        FailedSteps = $failedSteps.Count
        OutputDirectory = $outputDirectory
        ZipPath = $zipPath
    }
    Write-ObjectFile -LiteralPath (Join-Path $outputDirectory '00-Collection-Summary.txt') -InputObject $completionRecord

    Get-ChildItem -LiteralPath $outputDirectory -File -Recurse -ErrorAction SilentlyContinue |
        Select-Object FullName, Length, CreationTimeUtc, LastWriteTimeUtc |
        Export-Csv -LiteralPath (Join-Path $outputDirectory '00-File-Inventory.csv') -NoTypeInformation -Encoding UTF8

    Compress-Archive -Path (Join-Path $outputDirectory '*') -DestinationPath $zipPath -CompressionLevel Optimal -Force

    Write-Output ''
    Write-Output 'Collection complete.'
    Write-Output ('Evidence folder: ' + $outputDirectory)
    Write-Output ('ZIP archive: ' + $zipPath)
    Write-Output ('Failed collection steps: ' + $failedSteps.Count)
    if ($failedSteps.Count -gt 0) {
        Write-Output 'Review 00-Collection-Status.csv and 00-Collection-Errors.txt inside the archive.'
    }
    exit 0
}
catch {
    $fatalMessage = 'Windows Update source diagnostic collection failed: ' + $_.Exception.Message
    Write-Error $fatalMessage
    if ($null -ne $script:CollectionErrorsPath) {
        Write-CollectionError -Step 'Fatal' -ErrorRecord $_
    }
    exit 1
}

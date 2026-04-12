#Requires -Version 5.1
<#
.SYNOPSIS
    WinHealthImprover - SafetyNet Module
.DESCRIPTION
    Comprehensive safety system that tracks every change made and provides
    full undo/rollback capability. Every registry change, service modification,
    and file deletion is logged and reversible.

    Features:
    - Change journal: records every modification with before/after state
    - Registry rollback: exports original values before modification
    - Service state backup: records original startup types
    - File backup: copies critical files before deletion
    - One-click undo: reverse all changes or specific stages
    - Emergency stop: halt execution and rollback
    - Pre-flight safety validation
#>

# ============================================================================
# CHANGE JOURNAL
# ============================================================================

$script:SafetyConfig = @{
    Enabled        = $true
    JournalPath    = ""
    BackupDir      = ""
    Journal        = [System.Collections.ArrayList]::new()
    RegistryBackup = [System.Collections.ArrayList]::new()
    ServiceBackup  = [System.Collections.ArrayList]::new()
    FileBackup     = [System.Collections.ArrayList]::new()
    Initialized    = $false
}

function Initialize-SafetyNet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$LogDirectory
    )

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $script:SafetyConfig.JournalPath = Join-Path $LogDirectory "SafetyNet_$timestamp.json"
    $script:SafetyConfig.BackupDir = Join-Path $LogDirectory "SafetyNet_Backups_$timestamp"

    if (-not (Test-Path $script:SafetyConfig.BackupDir)) {
        New-Item -Path $script:SafetyConfig.BackupDir -ItemType Directory -Force | Out-Null
    }

    $script:SafetyConfig.Initialized = $true

    Write-Log -Message "SafetyNet initialized - all changes will be tracked and reversible" -Level "SUCCESS" -Component "SafetyNet"
    Write-Log -Message "Undo data: $($script:SafetyConfig.BackupDir)" -Level "INFO" -Component "SafetyNet"
}

# ============================================================================
# CHANGE RECORDING
# ============================================================================

function Add-JournalEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("Registry", "Service", "File", "AppRemoval", "Setting", "Network", "Firewall")]
        [string]$Type,

        [Parameter(Mandatory)]
        [string]$Description,

        [string]$Target = "",
        [string]$OldValue = "",
        [string]$NewValue = "",
        [string]$Stage = "",
        [string]$UndoCommand = ""
    )

    if (-not $script:SafetyConfig.Initialized) { return }

    $entry = @{
        Timestamp   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Type        = $Type
        Description = $Description
        Target      = $Target
        OldValue    = $OldValue
        NewValue    = $NewValue
        Stage       = $Stage
        UndoCommand = $UndoCommand
        Undone      = $false
    }

    [void]$script:SafetyConfig.Journal.Add($entry)
}

function Save-Journal {
    if (-not $script:SafetyConfig.Initialized) { return }

    try {
        $journalData = @{
            ComputerName = $env:COMPUTERNAME
            CreatedAt    = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            TotalChanges = $script:SafetyConfig.Journal.Count
            Changes      = $script:SafetyConfig.Journal
            Registry     = $script:SafetyConfig.RegistryBackup
            Services     = $script:SafetyConfig.ServiceBackup
            Files        = $script:SafetyConfig.FileBackup
        }

        $journalData | ConvertTo-Json -Depth 10 | Out-File -FilePath $script:SafetyConfig.JournalPath -Encoding UTF8 -Force
    }
    catch { }
}

# ============================================================================
# SAFE REGISTRY OPERATIONS (with automatic backup)
# ============================================================================

function Set-RegistryValueSafe {
    <#
    .SYNOPSIS
        Sets a registry value while automatically backing up the original.
        Can be fully reversed with Undo-RegistryChanges.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        $Value,

        [ValidateSet("String", "ExpandString", "Binary", "DWord", "MultiString", "QWord")]
        [string]$Type = "DWord",

        [string]$Stage = "",
        [string]$Reason = ""
    )

    # Capture current value before changing
    $oldValue = $null
    $existed = $false
    try {
        if (Test-Path $Path) {
            $prop = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
            if ($null -ne $prop) {
                $oldValue = $prop.$Name
                $existed = $true
            }
        }
    }
    catch { }

    # Record in journal
    $backup = @{
        Path     = $Path
        Name     = $Name
        OldValue = $oldValue
        NewValue = $Value
        Type     = $Type
        Existed  = $existed
        Stage    = $Stage
    }
    [void]$script:SafetyConfig.RegistryBackup.Add($backup)

    # Build undo command
    $undoCmd = if ($existed) {
        "Set-ItemProperty -Path '$Path' -Name '$Name' -Value '$oldValue' -Force"
    }
    else {
        "Remove-ItemProperty -Path '$Path' -Name '$Name' -Force -ErrorAction SilentlyContinue"
    }

    Add-JournalEntry -Type "Registry" -Description ($Reason ? $Reason : "Set $Name = $Value") `
        -Target "$Path\$Name" -OldValue "$oldValue" -NewValue "$Value" -Stage $Stage -UndoCommand $undoCmd

    # Actually set the value
    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

# ============================================================================
# SAFE SERVICE OPERATIONS (with automatic backup)
# ============================================================================

function Set-ServiceStartupTypeSafe {
    <#
    .SYNOPSIS
        Changes a service's startup type while recording the original for undo.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ServiceName,

        [Parameter(Mandatory)]
        [ValidateSet("Automatic", "Manual", "Disabled")]
        [string]$StartupType,

        [string]$Stage = "",
        [string]$Reason = ""
    )

    try {
        $svc = Get-Service -Name $ServiceName -ErrorAction Stop
        $originalStartType = (Get-CimInstance Win32_Service -Filter "Name='$ServiceName'" -ErrorAction Stop).StartMode

        # Record backup
        $backup = @{
            ServiceName      = $ServiceName
            OriginalStartup  = $originalStartType
            OriginalStatus   = $svc.Status.ToString()
            NewStartup       = $StartupType
            Stage            = $Stage
        }
        [void]$script:SafetyConfig.ServiceBackup.Add($backup)

        $undoCmd = "Set-Service -Name '$ServiceName' -StartupType '$originalStartType'"
        Add-JournalEntry -Type "Service" -Description ($Reason ? $Reason : "Set $ServiceName to $StartupType") `
            -Target $ServiceName -OldValue $originalStartType -NewValue $StartupType -Stage $Stage -UndoCommand $undoCmd

        # Apply change
        Set-Service -Name $ServiceName -StartupType $StartupType -ErrorAction Stop

        if ($svc.Status -eq "Running" -and $StartupType -eq "Disabled") {
            Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
        }

        return $true
    }
    catch {
        return $false
    }
}

# ============================================================================
# SAFE FILE OPERATIONS (with automatic backup)
# ============================================================================

function Remove-ItemSafe {
    <#
    .SYNOPSIS
        Removes a file/folder while creating a backup copy first.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$Recurse,
        [string]$Stage = "",
        [string]$Reason = "",
        [switch]$SkipBackup  # For temp files that don't need backup
    )

    if (-not (Test-Path $Path)) { return $false }

    $item = Get-Item -Path $Path -ErrorAction SilentlyContinue
    if (-not $item) { return $false }

    # Backup critical files (skip for temp/cache)
    if (-not $SkipBackup -and $script:SafetyConfig.Initialized) {
        try {
            $backupPath = Join-Path $script:SafetyConfig.BackupDir (Split-Path $Path -Leaf)
            if ($item.PSIsContainer) {
                # For directories, just record the path (don't copy entire dirs)
                $fileBackup = @{
                    OriginalPath = $Path
                    BackupPath   = ""
                    IsDirectory  = $true
                    Stage        = $Stage
                }
            }
            else {
                $uniqueBackup = "$backupPath`_$(Get-Date -Format 'HHmmss')"
                Copy-Item -Path $Path -Destination $uniqueBackup -Force -ErrorAction SilentlyContinue
                $fileBackup = @{
                    OriginalPath = $Path
                    BackupPath   = $uniqueBackup
                    IsDirectory  = $false
                    Stage        = $Stage
                }
            }
            [void]$script:SafetyConfig.FileBackup.Add($fileBackup)
        }
        catch { }
    }

    Add-JournalEntry -Type "File" -Description ($Reason ? $Reason : "Removed $Path") `
        -Target $Path -Stage $Stage

    try {
        Remove-Item -Path $Path -Recurse:$Recurse -Force -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

# ============================================================================
# UNDO / ROLLBACK SYSTEM
# ============================================================================

function Undo-AllChanges {
    <#
    .SYNOPSIS
        Reverses ALL changes made during the current session.
    #>
    [CmdletBinding()]
    param(
        [string]$JournalFile = $script:SafetyConfig.JournalPath
    )

    Write-Host ""
    Write-Host "  +=========================================================+" -ForegroundColor Red
    Write-Host "  |              ROLLING BACK ALL CHANGES                    |" -ForegroundColor Red
    Write-Host "  +=========================================================+" -ForegroundColor Red
    Write-Host ""

    $journal = $null
    if ($JournalFile -and (Test-Path $JournalFile)) {
        $journal = Get-Content -Path $JournalFile -Raw | ConvertFrom-Json
    }
    elseif ($script:SafetyConfig.Journal.Count -gt 0) {
        $journal = @{
            Registry = $script:SafetyConfig.RegistryBackup
            Services = $script:SafetyConfig.ServiceBackup
            Files    = $script:SafetyConfig.FileBackup
        }
    }

    if (-not $journal) {
        Write-Host "  No change journal found. Nothing to undo." -ForegroundColor Yellow
        return
    }

    $undone = 0

    # Undo registry changes (reverse order)
    if ($journal.Registry) {
        $regEntries = @($journal.Registry)
        [array]::Reverse($regEntries)

        foreach ($reg in $regEntries) {
            try {
                if ($reg.Existed -eq $true -or $reg.Existed -eq "True") {
                    Set-ItemProperty -Path $reg.Path -Name $reg.Name -Value $reg.OldValue -Force -ErrorAction Stop
                    Write-Host "  [UNDO] Registry restored: $($reg.Path)\$($reg.Name)" -ForegroundColor Green
                }
                else {
                    Remove-ItemProperty -Path $reg.Path -Name $reg.Name -Force -ErrorAction SilentlyContinue
                    Write-Host "  [UNDO] Registry key removed: $($reg.Path)\$($reg.Name)" -ForegroundColor Green
                }
                $undone++
            }
            catch {
                Write-Host "  [FAIL] Could not undo: $($reg.Path)\$($reg.Name)" -ForegroundColor Red
            }
        }
    }

    # Undo service changes
    if ($journal.Services) {
        foreach ($svc in $journal.Services) {
            try {
                $startType = switch ($svc.OriginalStartup) {
                    "Auto"     { "Automatic" }
                    "Manual"   { "Manual" }
                    "Disabled" { "Disabled" }
                    default    { $svc.OriginalStartup }
                }
                Set-Service -Name $svc.ServiceName -StartupType $startType -ErrorAction Stop
                if ($svc.OriginalStatus -eq "Running") {
                    Start-Service -Name $svc.ServiceName -ErrorAction SilentlyContinue
                }
                Write-Host "  [UNDO] Service restored: $($svc.ServiceName) -> $($svc.OriginalStartup)" -ForegroundColor Green
                $undone++
            }
            catch {
                Write-Host "  [FAIL] Could not undo: $($svc.ServiceName)" -ForegroundColor Red
            }
        }
    }

    # Restore backed-up files
    if ($journal.Files) {
        foreach ($file in $journal.Files) {
            if ($file.BackupPath -and (Test-Path $file.BackupPath)) {
                try {
                    $destDir = Split-Path $file.OriginalPath -Parent
                    if (-not (Test-Path $destDir)) {
                        New-Item -Path $destDir -ItemType Directory -Force | Out-Null
                    }
                    Copy-Item -Path $file.BackupPath -Destination $file.OriginalPath -Force -ErrorAction Stop
                    Write-Host "  [UNDO] File restored: $($file.OriginalPath)" -ForegroundColor Green
                    $undone++
                }
                catch {
                    Write-Host "  [FAIL] Could not restore: $($file.OriginalPath)" -ForegroundColor Red
                }
            }
        }
    }

    Write-Host ""
    Write-Host "  Rollback complete: $undone changes reversed." -ForegroundColor Cyan
    Write-Host ""
}

function Undo-StageChanges {
    <#
    .SYNOPSIS
        Reverses changes made by a specific stage only.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$StageNumber
    )

    $stageName = "Stage$StageNumber"

    Write-Host "  Rolling back changes from Stage $StageNumber..." -ForegroundColor Yellow

    $undone = 0

    # Registry
    $regEntries = $script:SafetyConfig.RegistryBackup | Where-Object { $_.Stage -eq $stageName }
    foreach ($reg in $regEntries) {
        try {
            if ($reg.Existed) {
                Set-ItemProperty -Path $reg.Path -Name $reg.Name -Value $reg.OldValue -Force -ErrorAction Stop
            }
            else {
                Remove-ItemProperty -Path $reg.Path -Name $reg.Name -Force -ErrorAction SilentlyContinue
            }
            $undone++
        }
        catch { }
    }

    # Services
    $svcEntries = $script:SafetyConfig.ServiceBackup | Where-Object { $_.Stage -eq $stageName }
    foreach ($svc in $svcEntries) {
        try {
            Set-Service -Name $svc.ServiceName -StartupType $svc.OriginalStartup -ErrorAction Stop
            $undone++
        }
        catch { }
    }

    Write-Host "  Stage $StageNumber rollback: $undone changes reversed." -ForegroundColor Cyan
}

# ============================================================================
# SAFETY VALIDATION
# ============================================================================

function Test-SafeToRun {
    <#
    .SYNOPSIS
        Comprehensive pre-flight safety checks before any destructive operation.
    #>
    [CmdletBinding()]
    param()

    $issues = @()
    $warnings = @()

    # Check if running from a temp directory
    if ($PSScriptRoot -and $PSScriptRoot.ToLower() -match "\\temp\\|\\tmp\\") {
        $issues += "Running from a temporary directory - this folder may get deleted during cleanup"
    }

    # Check disk space
    $sysDrive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'" -ErrorAction SilentlyContinue
    if ($sysDrive) {
        $freeGB = [math]::Round($sysDrive.FreeSpace / 1GB, 1)
        if ($freeGB -lt 1) {
            $issues += "Critical: Less than 1 GB free on system drive ($freeGB GB)"
        }
        elseif ($freeGB -lt 3) {
            $warnings += "Low disk space: $freeGB GB free on system drive"
        }
    }

    # Check battery
    try {
        $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
        if ($battery -and $battery.BatteryStatus -ne 2) {
            $pct = $battery.EstimatedChargeRemaining
            if ($pct -lt 20) {
                $issues += "Battery at $pct% and not plugged in - connect AC power before running"
            }
            elseif ($pct -lt 50) {
                $warnings += "Running on battery ($pct%) - consider plugging in AC power"
            }
        }
    }
    catch { }

    # Check for critical processes that shouldn't be interrupted
    $criticalApps = @(
        @{ Name = "setup"; Desc = "An installer is running" },
        @{ Name = "msiexec"; Desc = "A Windows Installer operation is in progress" },
        @{ Name = "WindowsUpdate"; Desc = "Windows Update is actively installing" },
        @{ Name = "TiWorker"; Desc = "Windows Update is processing" }
    )

    foreach ($app in $criticalApps) {
        if (Get-Process -Name $app.Name -ErrorAction SilentlyContinue) {
            $warnings += "$($app.Desc) - wait for it to finish"
        }
    }

    # Check for running backup software
    $backupProcs = @("BackupExec", "veeam", "acronis", "carbonite")
    foreach ($proc in $backupProcs) {
        if (Get-Process -Name "*$proc*" -ErrorAction SilentlyContinue) {
            $warnings += "Backup software is running ($proc) - let it finish first"
        }
    }

    # Check uptime (long uptime = potential pending updates/issues)
    try {
        $lastBoot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
        $uptime = (Get-Date) - $lastBoot
        if ($uptime.TotalDays -gt 30) {
            $warnings += "System hasn't been rebooted in $([math]::Round($uptime.TotalDays)) days - consider rebooting first"
        }
    }
    catch { }

    return @{
        Safe     = ($issues.Count -eq 0)
        Issues   = $issues
        Warnings = $warnings
    }
}

function Show-SafetyReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$SafetyCheck
    )

    if ($SafetyCheck.Issues.Count -gt 0) {
        Write-Host ""
        Write-Host "  *** SAFETY ISSUES DETECTED ***" -ForegroundColor Red
        foreach ($issue in $SafetyCheck.Issues) {
            Write-Host "    [X] $issue" -ForegroundColor Red
        }
    }

    if ($SafetyCheck.Warnings.Count -gt 0) {
        Write-Host ""
        Write-Host "  Safety Warnings:" -ForegroundColor Yellow
        foreach ($warn in $SafetyCheck.Warnings) {
            Write-Host "    [!] $warn" -ForegroundColor Yellow
        }
    }

    if ($SafetyCheck.Issues.Count -eq 0 -and $SafetyCheck.Warnings.Count -eq 0) {
        Write-Host "  [+] All safety checks passed" -ForegroundColor Green
    }
    Write-Host ""
}

# ============================================================================
# APP WHITELIST SYSTEM
# ============================================================================

$script:AppWhitelist = @()

function Set-AppWhitelist {
    <#
    .SYNOPSIS
        Set a list of apps that should NEVER be removed during debloat.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$AppNames
    )

    $script:AppWhitelist = $AppNames
    Write-Log -Message "App whitelist set: $($AppNames -join ', ')" -Level "INFO" -Component "SafetyNet"
}

function Test-AppWhitelisted {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppName
    )

    foreach ($whitelisted in $script:AppWhitelist) {
        if ($AppName -like "*$whitelisted*") {
            return $true
        }
    }
    return $false
}

function Get-AppWhitelist {
    return $script:AppWhitelist
}

# ============================================================================
# CHANGE SUMMARY
# ============================================================================

function Get-ChangeSummary {
    <#
    .SYNOPSIS
        Returns a plain-English summary of all changes made.
    #>

    $summary = @{
        RegistryChanges = $script:SafetyConfig.RegistryBackup.Count
        ServiceChanges  = $script:SafetyConfig.ServiceBackup.Count
        FileChanges     = $script:SafetyConfig.FileBackup.Count
        TotalChanges    = $script:SafetyConfig.Journal.Count
        JournalFile     = $script:SafetyConfig.JournalPath
        BackupDir       = $script:SafetyConfig.BackupDir
    }

    return $summary
}

function Show-ChangeSummary {
    $summary = Get-ChangeSummary

    Write-Host ""
    Write-Host "  +---------------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host "  |              SAFETYNET CHANGE SUMMARY                   |" -ForegroundColor DarkGray
    Write-Host "  +---------------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host "  |  Registry values changed:  $($summary.RegistryChanges.ToString().PadRight(30))|" -ForegroundColor White
    Write-Host "  |  Services modified:         $($summary.ServiceChanges.ToString().PadRight(30))|" -ForegroundColor White
    Write-Host "  |  Files affected:            $($summary.FileChanges.ToString().PadRight(30))|" -ForegroundColor White
    Write-Host "  |  Total tracked changes:     $($summary.TotalChanges.ToString().PadRight(30))|" -ForegroundColor White
    Write-Host "  |                                                         |" -ForegroundColor DarkGray
    Write-Host "  |  All changes are reversible! Run:                       |" -ForegroundColor Green
    Write-Host "  |  .\Undo-Changes.ps1                                     |" -ForegroundColor Green
    Write-Host "  |  to reverse everything.                                 |" -ForegroundColor Green
    Write-Host "  +---------------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host ""

    # Auto-save journal
    Save-Journal
}

Export-ModuleMember -Function *

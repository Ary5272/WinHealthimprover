#Requires -Version 5.1
<#
.SYNOPSIS
    WinHealthImprover - Common Utility Functions
.DESCRIPTION
    Shared utility functions used across all stages.
#>

# ============================================================================
# SYSTEM DETECTION
# ============================================================================

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-IsSafeMode {
    try {
        $bootMode = (Get-CimInstance -ClassName Win32_ComputerSystem).BootupState
        return $bootMode -ne "Normal boot"
    }
    catch {
        return $false
    }
}

function Get-WindowsVersion {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $build = [System.Environment]::OSVersion.Version.Build

    $versionName = switch -Wildcard ($build) {
        { $_ -ge 26100 } { "Windows 11 24H2" }
        { $_ -ge 22631 } { "Windows 11 23H2" }
        { $_ -ge 22621 } { "Windows 11 22H2" }
        { $_ -ge 22000 } { "Windows 11 21H2" }
        { $_ -ge 19045 } { "Windows 10 22H2" }
        { $_ -ge 19044 } { "Windows 10 21H2" }
        { $_ -ge 19043 } { "Windows 10 21H1" }
        { $_ -ge 19042 } { "Windows 10 20H2" }
        { $_ -ge 19041 } { "Windows 10 2004" }
        default           { "Windows (Build $build)" }
    }

    return @{
        Caption     = $os.Caption
        Version     = $os.Version
        Build       = $build
        VersionName = $versionName
        Arch        = $os.OSArchitecture
        InstallDate = $os.InstallDate
        LastBoot    = $os.LastBootUpTime
    }
}

function Get-SystemInfo {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $cs = Get-CimInstance -ClassName Win32_ComputerSystem
    $cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
    $ram = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
    $freeRam = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $disks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3"

    $diskInfo = foreach ($disk in $disks) {
        @{
            Drive     = $disk.DeviceID
            Size      = [math]::Round($disk.Size / 1GB, 2)
            Free      = [math]::Round($disk.FreeSpace / 1GB, 2)
            UsedPct   = if ($disk.Size -gt 0) { [math]::Round((1 - $disk.FreeSpace / $disk.Size) * 100, 1) } else { 0 }
        }
    }

    return @{
        ComputerName = $cs.Name
        Domain       = $cs.Domain
        Manufacturer = $cs.Manufacturer
        Model        = $cs.Model
        CPU          = $cpu.Name.Trim()
        CPUCores     = $cpu.NumberOfCores
        CPUThreads   = $cpu.NumberOfLogicalProcessors
        TotalRAM     = $ram
        FreeRAM      = $freeRam
        OS           = Get-WindowsVersion
        Disks        = $diskInfo
        BootType     = (Get-CimInstance Win32_ComputerSystem).BootupState
    }
}

# ============================================================================
# DISK DETECTION
# ============================================================================

function Test-IsSSD {
    [CmdletBinding()]
    param(
        [string]$DriveLetter = "C"
    )

    try {
        $diskNumber = (Get-Partition -DriveLetter $DriveLetter -ErrorAction Stop).DiskNumber
        $mediaType = (Get-PhysicalDisk | Where-Object { $_.DeviceId -eq $diskNumber }).MediaType

        return ($mediaType -eq "SSD" -or $mediaType -eq "NVMe")
    }
    catch {
        # Fallback: check if TRIM is supported (indicates SSD)
        try {
            $defrag = Get-CimInstance -Namespace "root\Microsoft\Windows\Defrag" -ClassName "MSFT_Volume" -ErrorAction Stop |
                Where-Object { $_.DriveLetter -eq $DriveLetter }
            return ($defrag.MediaType -eq 0) # 0 = SSD
        }
        catch {
            return $false
        }
    }
}

# ============================================================================
# PROCESS & SERVICE UTILITIES
# ============================================================================

function Stop-ProcessSafely {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProcessName,

        [int]$TimeoutSeconds = 10
    )

    $procs = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    if (-not $procs) { return $false }

    foreach ($proc in $procs) {
        try {
            $proc.CloseMainWindow() | Out-Null
            if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
                $proc | Stop-Process -Force -ErrorAction Stop
            }
        }
        catch {
            try { $proc | Stop-Process -Force -ErrorAction Stop }
            catch { }
        }
    }
    return $true
}

function Set-ServiceStartupType {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ServiceName,

        [Parameter(Mandatory)]
        [ValidateSet("Automatic", "Manual", "Disabled")]
        [string]$StartupType
    )

    try {
        $svc = Get-Service -Name $ServiceName -ErrorAction Stop
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
# REGISTRY UTILITIES
# ============================================================================

function Set-RegistryValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        $Value,

        [ValidateSet("String", "ExpandString", "Binary", "DWord", "MultiString", "QWord")]
        [string]$Type = "DWord"
    )

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

function Get-RegistryValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Name,

        $Default = $null
    )

    try {
        $val = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
        return $val.$Name
    }
    catch {
        return $Default
    }
}

# ============================================================================
# FILE UTILITIES
# ============================================================================

function Get-FolderSize {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) { return 0 }

    try {
        $size = (Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        return [math]::Round(($size / 1MB), 2)
    }
    catch {
        return 0
    }
}

function Remove-FolderContents {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$Recurse,
        [string[]]$Exclude = @()
    )

    if (-not (Test-Path $Path)) { return 0 }

    $removedSize = 0
    try {
        $items = Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notin $Exclude }

        foreach ($item in $items) {
            try {
                $size = if ($item.PSIsContainer) {
                    (Get-ChildItem -Path $item.FullName -Recurse -Force -ErrorAction SilentlyContinue |
                        Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                }
                else {
                    $item.Length
                }

                Remove-Item -Path $item.FullName -Recurse:$Recurse -Force -ErrorAction Stop
                $removedSize += $size
            }
            catch { }
        }
    }
    catch { }

    return [math]::Round(($removedSize / 1MB), 2)
}

function Format-FileSize {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [double]$SizeInMB
    )

    if ($SizeInMB -ge 1024) {
        return "{0:N2} GB" -f ($SizeInMB / 1024)
    }
    return "{0:N2} MB" -f $SizeInMB
}

# ============================================================================
# NETWORK UTILITIES
# ============================================================================

function Test-InternetConnection {
    try {
        $result = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet -ErrorAction Stop
        return $result
    }
    catch {
        return $false
    }
}

# ============================================================================
# SCHEDULED TASK UTILITIES
# ============================================================================

function Disable-ScheduledTaskSafely {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TaskPath,

        [Parameter(Mandatory)]
        [string]$TaskName
    )

    try {
        $task = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction Stop
        if ($task.State -ne "Disabled") {
            Disable-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction Stop | Out-Null
            return $true
        }
        return $false  # Already disabled
    }
    catch {
        return $false
    }
}

# ============================================================================
# DRY-RUN SUPPORT
# ============================================================================

$script:DryRunMode = $false

function Set-DryRunMode {
    param([bool]$Enabled)
    $script:DryRunMode = $Enabled
}

function Test-DryRun {
    return $script:DryRunMode
}

# ============================================================================
# TIMING
# ============================================================================

function Measure-Stage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory)]
        [string]$StageName
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        & $ScriptBlock
    }
    finally {
        $sw.Stop()
        Write-Log -Message "$StageName completed in $($sw.Elapsed.ToString('hh\:mm\:ss'))" -Level "INFO" -Component $StageName
    }
    return $sw.Elapsed
}

Export-ModuleMember -Function *

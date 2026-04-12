#Requires -Version 5.1
<#
.SYNOPSIS
    WinHealthImprover - System Initialization & Pre-flight Checks
.DESCRIPTION
    Performs all pre-flight checks and system analysis before stages run.
#>

function Test-Prerequisites {
    [CmdletBinding()]
    param(
        [switch]$SkipAdminCheck
    )

    $results = @{
        IsAdmin       = $false
        IsSupported   = $false
        HasInternet   = $false
        IsSafeMode    = $false
        PowerSource   = "Unknown"
        FreeSpace     = 0
        Errors        = @()
    }

    # Check admin privileges
    $results.IsAdmin = Test-IsAdmin
    if (-not $results.IsAdmin -and -not $SkipAdminCheck) {
        $results.Errors += "WinHealthImprover must be run as Administrator."
    }

    # Check Windows version (minimum Windows 10)
    $build = [System.Environment]::OSVersion.Version.Build
    $results.IsSupported = ($build -ge 10240)
    if (-not $results.IsSupported) {
        $results.Errors += "Windows 10 or later is required (detected build: $build)."
    }

    # Check internet
    $results.HasInternet = Test-InternetConnection

    # Check safe mode
    $results.IsSafeMode = Test-IsSafeMode

    # Check free disk space on system drive
    $sysDrive = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'"
    $results.FreeSpace = [math]::Round($sysDrive.FreeSpace / 1GB, 2)
    if ($results.FreeSpace -lt 2) {
        $results.Errors += "Less than 2 GB free on system drive ($($results.FreeSpace) GB available)."
    }

    # Check power source
    try {
        $battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
        if ($battery) {
            $results.PowerSource = if ($battery.BatteryStatus -eq 2) { "AC Power" } else { "Battery" }
            if ($battery.BatteryStatus -ne 2) {
                Write-Log -Message "Running on battery power - consider connecting to AC power" -Level "WARN"
            }
        }
        else {
            $results.PowerSource = "AC Power (Desktop)"
        }
    }
    catch {
        $results.PowerSource = "Unknown"
    }

    return $results
}

function Show-SystemSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$SystemInfo,

        [Parameter(Mandatory)]
        [hashtable]$Prerequisites
    )

    Write-Host ""
    Write-Host "  +-----------------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host "  |              SYSTEM INFORMATION                         |" -ForegroundColor DarkGray
    Write-Host "  +-----------------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host "  |  Computer:  $($SystemInfo.ComputerName.PadRight(43))|" -ForegroundColor White
    Write-Host "  |  OS:        $($SystemInfo.OS.VersionName.PadRight(43))|" -ForegroundColor White
    Write-Host "  |  Build:     $("$($SystemInfo.OS.Build) ($($SystemInfo.OS.Arch))".PadRight(43))|" -ForegroundColor White
    Write-Host "  |  CPU:       $($SystemInfo.CPU.Substring(0, [Math]::Min(43, $SystemInfo.CPU.Length)).PadRight(43))|" -ForegroundColor White
    Write-Host "  |  RAM:       $("$($SystemInfo.TotalRAM) GB ($($SystemInfo.FreeRAM) GB free)".PadRight(43))|" -ForegroundColor White

    foreach ($disk in $SystemInfo.Disks) {
        $diskStr = "$($disk.Drive) $($disk.Free) GB free of $($disk.Size) GB ($($disk.UsedPct)% used)"
        Write-Host "  |  Disk:      $($diskStr.Substring(0, [Math]::Min(43, $diskStr.Length)).PadRight(43))|" -ForegroundColor White
    }

    Write-Host "  |  Power:     $($Prerequisites.PowerSource.PadRight(43))|" -ForegroundColor White
    Write-Host "  |  Internet:  $(if ($Prerequisites.HasInternet) { 'Connected'.PadRight(43) } else { 'Disconnected'.PadRight(43) })|" -ForegroundColor $(if ($Prerequisites.HasInternet) { 'Green' } else { 'Yellow' })
    Write-Host "  |  Safe Mode: $(if ($Prerequisites.IsSafeMode) { 'Yes'.PadRight(43) } else { 'No'.PadRight(43) })|" -ForegroundColor White
    Write-Host "  +-----------------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host ""
}

function Get-HealthScore {
    <#
    .SYNOPSIS
        Calculates an overall system health score (0-100).
    #>
    [CmdletBinding()]
    param()

    $score = 100
    $deductions = @()

    # Check disk space (up to -20)
    $sysDrive = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'"
    $freeSpacePct = [math]::Round(($sysDrive.FreeSpace / $sysDrive.Size) * 100, 1)
    if ($freeSpacePct -lt 10) { $score -= 20; $deductions += "Critical: Very low disk space ($freeSpacePct%)" }
    elseif ($freeSpacePct -lt 20) { $score -= 10; $deductions += "Low disk space ($freeSpacePct%)" }
    elseif ($freeSpacePct -lt 30) { $score -= 5; $deductions += "Moderate disk usage ($freeSpacePct% free)" }

    # Check temp files size (up to -10)
    $tempSize = (Get-FolderSize -Path $env:TEMP)
    $winTempSize = (Get-FolderSize -Path "$env:SystemRoot\Temp")
    $totalTemp = $tempSize + $winTempSize
    if ($totalTemp -gt 5000) { $score -= 10; $deductions += "Large temp files ($(Format-FileSize $totalTemp))" }
    elseif ($totalTemp -gt 1000) { $score -= 5; $deductions += "Moderate temp files ($(Format-FileSize $totalTemp))" }

    # Check Windows Update status (up to -15)
    try {
        $lastUpdate = (Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 1).InstalledOn
        $daysSinceUpdate = ((Get-Date) - $lastUpdate).Days
        if ($daysSinceUpdate -gt 90) { $score -= 15; $deductions += "No updates in $daysSinceUpdate days" }
        elseif ($daysSinceUpdate -gt 30) { $score -= 5; $deductions += "Updates may be pending ($daysSinceUpdate days)" }
    }
    catch { }

    # Check system file integrity (up to -15)
    try {
        $pendingReboot = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
        if ($pendingReboot) { $score -= 10; $deductions += "Pending reboot detected" }
    }
    catch { }

    # Check startup programs (up to -10)
    try {
        $startupCount = (Get-CimInstance Win32_StartupCommand | Measure-Object).Count
        if ($startupCount -gt 15) { $score -= 10; $deductions += "Too many startup programs ($startupCount)" }
        elseif ($startupCount -gt 8) { $score -= 5; $deductions += "Many startup programs ($startupCount)" }
    }
    catch { }

    # Check memory usage (up to -10)
    $os = Get-CimInstance Win32_OperatingSystem
    $memUsedPct = [math]::Round((1 - ($os.FreePhysicalMemory / $os.TotalVisibleMemorySize)) * 100, 1)
    if ($memUsedPct -gt 90) { $score -= 10; $deductions += "Very high memory usage ($memUsedPct%)" }
    elseif ($memUsedPct -gt 75) { $score -= 5; $deductions += "High memory usage ($memUsedPct%)" }

    # Check event log errors (up to -10)
    try {
        $recentErrors = (Get-WinEvent -FilterHashtable @{LogName = 'System'; Level = 1, 2; StartTime = (Get-Date).AddDays(-7) } -MaxEvents 50 -ErrorAction SilentlyContinue | Measure-Object).Count
        if ($recentErrors -gt 20) { $score -= 10; $deductions += "Many recent system errors ($recentErrors in 7 days)" }
        elseif ($recentErrors -gt 5) { $score -= 5; $deductions += "Some system errors ($recentErrors in 7 days)" }
    }
    catch { }

    # Check fragmentation on HDDs (up to -10)
    try {
        if (-not (Test-IsSSD)) {
            $defrag = Get-CimInstance -Namespace "root\Microsoft\Windows\Defrag" -ClassName "MSFT_Volume" -ErrorAction Stop |
                Where-Object { $_.DriveLetter -eq 'C' }
            # Not easily available via CIM, skip if not found
        }
    }
    catch { }

    $score = [math]::Max(0, $score)

    return @{
        Score      = $score
        Grade      = switch ($score) {
            { $_ -ge 90 } { "A" }
            { $_ -ge 80 } { "B" }
            { $_ -ge 70 } { "C" }
            { $_ -ge 60 } { "D" }
            default        { "F" }
        }
        Deductions = $deductions
    }
}

function Show-HealthScore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Health
    )

    $color = switch ($Health.Grade) {
        "A" { "Green" }
        "B" { "Green" }
        "C" { "Yellow" }
        "D" { "Red" }
        "F" { "DarkRed" }
    }

    Write-Host ""
    Write-Host "  +-----------------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host "  |              SYSTEM HEALTH SCORE                        |" -ForegroundColor DarkGray
    Write-Host "  +-----------------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host "  |                                                         |" -ForegroundColor DarkGray
    Write-Host "  |         Score: $($Health.Score.ToString().PadRight(5)) Grade: $($Health.Grade)                          |" -ForegroundColor $color
    Write-Host "  |                                                         |" -ForegroundColor DarkGray

    if ($Health.Deductions.Count -gt 0) {
        Write-Host "  |  Issues Found:                                          |" -ForegroundColor DarkGray
        foreach ($issue in $Health.Deductions) {
            $truncated = $issue.Substring(0, [Math]::Min(51, $issue.Length))
            Write-Host "  |    - $($truncated.PadRight(51))|" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "  |  No significant issues detected!                       |" -ForegroundColor Green
    }

    Write-Host "  |                                                         |" -ForegroundColor DarkGray
    Write-Host "  +-----------------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host ""
}

Export-ModuleMember -Function *

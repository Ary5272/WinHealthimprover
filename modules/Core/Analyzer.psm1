#Requires -Version 5.1
<#
.SYNOPSIS
    WinHealthImprover - System Analyzer Module
.DESCRIPTION
    Scans the system first and provides smart recommendations on what to run.
    Each recommendation comes with a risk rating, estimated time, and
    plain-English explanation of what it fixes.

    Features:
    - Quick system scan (30 seconds)
    - Issue detection with severity ratings
    - Smart stage recommendations
    - Estimated time for each stage
    - Risk assessment per recommendation
    - One-click "apply recommendations" option
#>

function Invoke-SystemAnalysis {
    <#
    .SYNOPSIS
        Perform a quick system scan and return prioritized recommendations.
    #>
    [CmdletBinding()]
    param()

    Write-Host ""
    Write-Host "  +==============================================================+" -ForegroundColor Cyan
    Write-Host "  |              System Analysis in Progress...                  |" -ForegroundColor Cyan
    Write-Host "  +==============================================================+" -ForegroundColor Cyan
    Write-Host ""

    $findings = [System.Collections.ArrayList]::new()

    # ---- Disk Space Analysis ----
    Write-Host "  Scanning disk space..." -ForegroundColor DarkGray
    try {
        $sysDrive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'" -ErrorAction SilentlyContinue
        if ($sysDrive) {
            $freeGB = [math]::Round($sysDrive.FreeSpace / 1GB, 1)
            $totalGB = [math]::Round($sysDrive.Size / 1GB, 1)
            $usedPct = [math]::Round((1 - $sysDrive.FreeSpace / $sysDrive.Size) * 100, 0)

            if ($usedPct -gt 90) {
                [void]$findings.Add(@{
                    Category    = "Disk Space"
                    Severity    = "Critical"
                    Issue       = "System drive is $usedPct% full ($freeGB GB free of $totalGB GB)"
                    Fix         = "Clean temporary files, caches, and old Windows Update files"
                    Stage       = 1
                    Risk        = "Safe"
                    TimeMinutes = 5
                })
            }
            elseif ($usedPct -gt 80) {
                [void]$findings.Add(@{
                    Category    = "Disk Space"
                    Severity    = "Warning"
                    Issue       = "System drive is $usedPct% full ($freeGB GB free)"
                    Fix         = "Clean up temporary files to free space"
                    Stage       = 1
                    Risk        = "Safe"
                    TimeMinutes = 5
                })
            }
        }
    }
    catch { }

    # ---- Temp File Analysis ----
    Write-Host "  Scanning temporary files..." -ForegroundColor DarkGray
    try {
        $tempPaths = @(
            $env:TEMP,
            "$env:SystemRoot\Temp",
            "$env:LOCALAPPDATA\Temp"
        )
        $tempSizeMB = 0
        foreach ($path in $tempPaths) {
            if (Test-Path $path) {
                $size = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                    Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                $tempSizeMB += [math]::Round($size / 1MB, 0)
            }
        }

        if ($tempSizeMB -gt 500) {
            [void]$findings.Add(@{
                Category    = "Junk Files"
                Severity    = "Warning"
                Issue       = "Found $tempSizeMB MB of temporary files"
                Fix         = "Remove cached files, temp data, and browser caches"
                Stage       = 1
                Risk        = "Safe"
                TimeMinutes = 3
            })
        }
    }
    catch { }

    # ---- Bloatware Detection ----
    Write-Host "  Scanning for bloatware..." -ForegroundColor DarkGray
    try {
        $bloatPatterns = @(
            "king.com.*", "GAMELOFT*", "Flipboard*", "Shazam*",
            "*DellInc*", "*HPConnected*", "*LenovoCompanion*",
            "*BingWeather*", "*BingNews*", "*BingFinance*",
            "*MicrosoftSolitaire*", "*Clipchamp*", "*ZuneMusic*"
        )
        $bloatCount = 0
        foreach ($pattern in $bloatPatterns) {
            $bloatCount += @(Get-AppxPackage -Name $pattern -AllUsers -ErrorAction SilentlyContinue).Count
        }

        if ($bloatCount -gt 0) {
            [void]$findings.Add(@{
                Category    = "Bloatware"
                Severity    = "Moderate"
                Issue       = "Found $bloatCount pre-installed bloatware apps"
                Fix         = "Remove unwanted apps (games, OEM tools, unused Microsoft apps)"
                Stage       = 2
                Risk        = "Moderate"
                TimeMinutes = 3
            })
        }
    }
    catch { }

    # ---- Startup Program Analysis ----
    Write-Host "  Scanning startup programs..." -ForegroundColor DarkGray
    try {
        $startupItems = Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue
        $startupCount = @($startupItems).Count

        if ($startupCount -gt 8) {
            [void]$findings.Add(@{
                Category    = "Startup"
                Severity    = "Warning"
                Issue       = "$startupCount programs run at startup (slowing boot time)"
                Fix         = "Disable unnecessary startup programs"
                Stage       = 6
                Risk        = "Safe"
                TimeMinutes = 2
            })
        }
    }
    catch { }

    # ---- Windows Defender Status ----
    Write-Host "  Checking security status..." -ForegroundColor DarkGray
    try {
        $defender = Get-MpComputerStatus -ErrorAction SilentlyContinue
        if ($defender) {
            if (-not $defender.RealTimeProtectionEnabled) {
                [void]$findings.Add(@{
                    Category    = "Security"
                    Severity    = "Critical"
                    Issue       = "Windows Defender real-time protection is OFF"
                    Fix         = "Re-enable Defender and harden security settings"
                    Stage       = 9
                    Risk        = "Safe"
                    TimeMinutes = 2
                })
            }

            $sigAge = $defender.AntivirusSignatureAge
            if ($sigAge -gt 7) {
                [void]$findings.Add(@{
                    Category    = "Security"
                    Severity    = "Warning"
                    Issue       = "Virus definitions are $sigAge days old"
                    Fix         = "Update virus definitions and run a scan"
                    Stage       = 3
                    Risk        = "Safe"
                    TimeMinutes = 10
                })
            }
        }
    }
    catch { }

    # ---- Windows Update Status ----
    Write-Host "  Checking Windows Updates..." -ForegroundColor DarkGray
    try {
        $lastUpdate = Get-HotFix -ErrorAction SilentlyContinue |
            Sort-Object InstalledOn -Descending -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($lastUpdate -and $lastUpdate.InstalledOn) {
            $daysSinceUpdate = ((Get-Date) - $lastUpdate.InstalledOn).Days
            if ($daysSinceUpdate -gt 30) {
                [void]$findings.Add(@{
                    Category    = "Updates"
                    Severity    = "Warning"
                    Issue       = "Last Windows Update was $daysSinceUpdate days ago"
                    Fix         = "Install pending Windows and driver updates"
                    Stage       = 5
                    Risk        = "Moderate"
                    TimeMinutes = 20
                })
            }
        }
    }
    catch { }

    # ---- Telemetry Check ----
    Write-Host "  Checking privacy settings..." -ForegroundColor DarkGray
    try {
        $telemetryLevel = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -ErrorAction SilentlyContinue
        if (-not $telemetryLevel -or $telemetryLevel.AllowTelemetry -gt 0) {
            [void]$findings.Add(@{
                Category    = "Privacy"
                Severity    = "Moderate"
                Issue       = "Windows telemetry is sending data to Microsoft"
                Fix         = "Disable telemetry, tracking, and advertising features"
                Stage       = 7
                Risk        = "Moderate"
                TimeMinutes = 3
            })
        }
    }
    catch { }

    # ---- SMBv1 Check ----
    Write-Host "  Checking network security..." -ForegroundColor DarkGray
    try {
        $smb1 = Get-WindowsOptionalFeature -Online -FeatureName "SMB1Protocol" -ErrorAction SilentlyContinue
        if ($smb1 -and $smb1.State -eq "Enabled") {
            [void]$findings.Add(@{
                Category    = "Network Security"
                Severity    = "Warning"
                Issue       = "SMBv1 is enabled (known ransomware attack vector)"
                Fix         = "Disable SMBv1 and optimize network settings"
                Stage       = 8
                Risk        = "Safe"
                TimeMinutes = 2
            })
        }
    }
    catch { }

    # ---- Service Bloat Check ----
    Write-Host "  Checking services..." -ForegroundColor DarkGray
    try {
        $unnecessaryServices = @("DiagTrack", "dmwappushservice", "RetailDemo", "wisvc", "MapsBroker")
        $runningUnnecessary = 0
        foreach ($svcName in $unnecessaryServices) {
            $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
            if ($svc -and $svc.Status -eq "Running") { $runningUnnecessary++ }
        }
        if ($runningUnnecessary -gt 0) {
            [void]$findings.Add(@{
                Category    = "Performance"
                Severity    = "Info"
                Issue       = "$runningUnnecessary unnecessary services running in background"
                Fix         = "Disable telemetry and demo services"
                Stage       = 6
                Risk        = "Safe"
                TimeMinutes = 1
            })
        }
    }
    catch { }

    # ---- Event Log Errors ----
    Write-Host "  Checking system health..." -ForegroundColor DarkGray
    try {
        $recentErrors = Get-WinEvent -FilterHashtable @{
            LogName   = "System"
            Level     = 2  # Error
            StartTime = (Get-Date).AddDays(-7)
        } -MaxEvents 50 -ErrorAction SilentlyContinue
        $errorCount = @($recentErrors).Count

        if ($errorCount -gt 20) {
            [void]$findings.Add(@{
                Category    = "System Health"
                Severity    = "Warning"
                Issue       = "$errorCount system errors in the last 7 days"
                Fix         = "Run system repair (SFC, DISM) to fix corrupted files"
                Stage       = 4
                Risk        = "Safe"
                TimeMinutes = 15
            })
        }
    }
    catch { }

    return $findings
}

function Show-AnalysisReport {
    <#
    .SYNOPSIS
        Display analysis findings in a user-friendly format.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.ArrayList]$Findings
    )

    Write-Host ""
    Write-Host "  +==============================================================+" -ForegroundColor Cyan
    Write-Host "  |              System Analysis Results                         |" -ForegroundColor Cyan
    Write-Host "  +==============================================================+" -ForegroundColor Cyan
    Write-Host ""

    if ($Findings.Count -eq 0) {
        Write-Host "  Your system looks great! No major issues found." -ForegroundColor Green
        Write-Host ""
        return
    }

    # Sort by severity
    $severityOrder = @{ "Critical" = 0; "Warning" = 1; "Moderate" = 2; "Info" = 3 }
    $sorted = $Findings | Sort-Object { $severityOrder[$_.Severity] }

    $totalTime = 0

    Write-Host "  Found $($Findings.Count) items to address:" -ForegroundColor White
    Write-Host "  ─────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""

    $index = 1
    foreach ($finding in $sorted) {
        $severityColor = switch ($finding.Severity) {
            "Critical" { "Red" }
            "Warning"  { "Yellow" }
            "Moderate" { "DarkYellow" }
            "Info"     { "DarkCyan" }
        }

        $riskColor = switch ($finding.Risk) {
            "Safe"     { "Green" }
            "Moderate" { "Yellow" }
            "Advanced" { "Red" }
        }

        $icon = switch ($finding.Severity) {
            "Critical" { "[!!!]" }
            "Warning"  { "[!!] " }
            "Moderate" { "[!]  " }
            "Info"     { "[i]  " }
        }

        Write-Host "  $icon $($finding.Category)" -ForegroundColor $severityColor
        Write-Host "       Problem:  $($finding.Issue)" -ForegroundColor White
        Write-Host "       Solution: $($finding.Fix)" -ForegroundColor DarkCyan
        Write-Host "       Risk: " -NoNewline -ForegroundColor DarkGray
        Write-Host "$($finding.Risk)" -NoNewline -ForegroundColor $riskColor
        Write-Host " | Est. time: ~$($finding.TimeMinutes) min | Stage $($finding.Stage)" -ForegroundColor DarkGray
        Write-Host ""

        $totalTime += $finding.TimeMinutes
        $index++
    }

    Write-Host "  ─────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  Total estimated time: ~$totalTime minutes" -ForegroundColor White
    Write-Host ""
}

function Get-RecommendedStages {
    <#
    .SYNOPSIS
        Convert analysis findings into a list of recommended stages.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.ArrayList]$Findings
    )

    $stages = @(0)  # Always include prep

    foreach ($finding in $Findings) {
        if ($finding.Stage -notin $stages) {
            $stages += $finding.Stage
        }
    }

    return ($stages | Sort-Object)
}

function Invoke-AnalyzerWizard {
    <#
    .SYNOPSIS
        Run the full analyzer wizard: scan, show results, ask user to apply.
    #>
    [CmdletBinding()]
    param()

    $findings = Invoke-SystemAnalysis

    Show-AnalysisReport -Findings $findings

    if ($findings.Count -eq 0) {
        return $null
    }

    $stages = Get-RecommendedStages -Findings $findings

    Write-Host "  Recommended stages to run: $($stages -join ', ')" -ForegroundColor Cyan
    Write-Host ""

    return @{
        Findings          = $findings
        RecommendedStages = $stages
    }
}

Export-ModuleMember -Function Invoke-SystemAnalysis, Show-AnalysisReport,
    Get-RecommendedStages, Invoke-AnalyzerWizard

#Requires -Version 5.1
<#
.SYNOPSIS
    Stage 10: Wrap-up & Reporting
.DESCRIPTION
    Final stage - generates reports and performs cleanup:
    - Recalculate health score (after)
    - Create final system restore point
    - Generate HTML report
    - Generate summary to console
    - Restore power settings (if changed)
    - Clean up temporary files we created
    - Show before/after comparison
#>

function Invoke-Stage10 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$HealthBefore,

        [Parameter(Mandatory)]
        [hashtable]$SystemInfo,

        [string]$LogDirectory,

        [switch]$DryRun,
        [switch]$SkipFinalRestorePoint
    )

    $stageTimer = [System.Diagnostics.Stopwatch]::StartNew()

    Write-StageHeader -StageNumber 10 -StageName "Wrap-up" -Description "Generating reports and performing final cleanup"

    # ---- Recalculate Health Score ----
    Write-SubStageHeader "Recalculating Health Score"
    $healthAfter = $null
    if (-not $DryRun) {
        try {
            $healthAfter = Get-HealthScore
            Write-Log -Message "Health score after: $($healthAfter.Score) (Grade: $($healthAfter.Grade))" -Level "INFO" -Component "Stage10"

            $improvement = $healthAfter.Score - $HealthBefore.Score
            if ($improvement -gt 0) {
                Write-Log -Message "Health improved by $improvement points!" -Level "SUCCESS" -Component "Stage10"
            }
            elseif ($improvement -eq 0) {
                Write-Log -Message "Health score unchanged" -Level "INFO" -Component "Stage10"
            }
        }
        catch {
            Write-Log -Message "Could not recalculate health score: $_" -Level "WARN" -Component "Stage10"
        }
    }

    # ---- Create Final Restore Point ----
    if (-not $SkipFinalRestorePoint -and -not $DryRun) {
        Write-SubStageHeader "Creating Final Restore Point"
        try {
            Checkpoint-Computer -Description "WinHealthImprover Post-Run Checkpoint" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
            Write-Log -Message "Final restore point created" -Level "SUCCESS" -Component "Stage10"
        }
        catch {
            Write-Log -Message "Could not create final restore point" -Level "WARN" -Component "Stage10"
        }
    }

    # ---- Capture Post-Run Inventory & Diff ----
    Write-SubStageHeader "Capturing Post-Run Inventory"
    if (-not $DryRun -and $LogDirectory) {
        try {
            # Capture after inventory
            $afterPrograms = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
                                               "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName } | Select-Object DisplayName, DisplayVersion
            $afterPrograms | Export-Csv -Path (Join-Path $LogDirectory "After_Programs.csv") -NoTypeInformation -ErrorAction SilentlyContinue

            # Try to find before inventory and generate diff
            $beforeFile = Get-ChildItem -Path $LogDirectory -Filter "*Before*Programs.csv" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($beforeFile) {
                $beforePrograms = Import-Csv -Path $beforeFile.FullName -ErrorAction SilentlyContinue
                $beforeNames = $beforePrograms | Select-Object -ExpandProperty DisplayName
                $afterNames = $afterPrograms | Select-Object -ExpandProperty DisplayName

                $removed = $beforeNames | Where-Object { $_ -notin $afterNames }
                $added = $afterNames | Where-Object { $_ -notin $beforeNames }

                if ($removed) {
                    $diffFile = Join-Path $LogDirectory "RemovedPrograms.txt"
                    $removed | Out-File -FilePath $diffFile -Encoding UTF8
                    Write-Log -Message "$($removed.Count) programs were removed during this session" -Level "SUCCESS" -Component "Stage10"
                    Set-Metric -Name "ProgramsRemoved" -Value $removed.Count -Category "Overall"
                }
                if ($added) {
                    Write-Log -Message "$($added.Count) programs were added during this session" -Level "INFO" -Component "Stage10"
                }
            }
        }
        catch {
            Write-Log -Message "Post-run inventory diff failed: $_" -Level "WARN" -Component "Stage10"
        }
    }

    # ---- Calculate Space Saved ----
    Write-SubStageHeader "Calculating Space Saved"
    if (-not $DryRun) {
        try {
            $sysDrive = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'"
            $freeSpaceAfter = [math]::Round($sysDrive.FreeSpace / 1GB, 2)
            $freeSpaceBefore = (Get-Metrics)["Overall"]["FreeSpaceBefore_GB"]

            if ($freeSpaceBefore -and $freeSpaceBefore -gt 0) {
                $spaceSaved = [math]::Round($freeSpaceAfter - $freeSpaceBefore, 2)
                if ($spaceSaved -gt 0) {
                    Write-Log -Message "Space recovered: $spaceSaved GB ($freeSpaceBefore GB -> $freeSpaceAfter GB free)" -Level "SUCCESS" -Component "Stage10"
                }
                else {
                    Write-Log -Message "Disk space: $freeSpaceBefore GB -> $freeSpaceAfter GB free" -Level "INFO" -Component "Stage10"
                }
                Set-Metric -Name "FreeSpaceAfter_GB" -Value $freeSpaceAfter -Category "Overall"
                Set-Metric -Name "SpaceSaved_GB" -Value ([math]::Max(0, $spaceSaved)) -Category "Overall"
            }
        }
        catch { }
    }

    # ---- Restore Power Settings ----
    Write-SubStageHeader "Restoring Power Settings"
    if (-not $DryRun) {
        try {
            # Restore balanced power plan
            & powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e 2>&1 | Out-Null
            Write-Log -Message "Power plan restored to Balanced" -Level "SUCCESS" -Component "Stage10"
        }
        catch { }
    }

    # ---- Generate HTML Report ----
    Write-SubStageHeader "Generating HTML Report"
    $reportPath = $null

    if ($LogDirectory) {
        try {
            $startTime = Get-LogStartTime
            $totalDuration = if ($startTime) { (Get-Date) - $startTime } else { [TimeSpan]::Zero }

            $reportPath = Join-Path $LogDirectory "WinHealthImprover_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"

            New-HTMLReport -OutputPath $reportPath `
                -SystemInfo $SystemInfo `
                -HealthBefore $HealthBefore `
                -HealthAfter $healthAfter `
                -StageResults (Get-StageResults) `
                -Metrics (Get-Metrics) `
                -TotalDuration $totalDuration

            Write-Log -Message "HTML report saved to: $reportPath" -Level "SUCCESS" -Component "Stage10"
        }
        catch {
            Write-Log -Message "Could not generate HTML report: $_" -Level "ERROR" -Component "Stage10"
        }
    }

    # ---- Console Summary ----
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor Cyan
    Write-Host "  FINAL SUMMARY" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Cyan
    Write-Host ""

    # Show before/after scores
    if ($healthAfter) {
        Show-BeforeAfterComparison -Before $HealthBefore -After $healthAfter
    }

    # Show stage results
    $stageResults = Get-StageResults
    if ($stageResults.Count -gt 0) {
        Write-Host ""
        Write-Host "  Stage Results:" -ForegroundColor White
        Write-Host "  ─────────────────────────────────────────────────────" -ForegroundColor DarkGray

        foreach ($result in $stageResults) {
            $icon = switch ($result.Status) {
                "Success" { "[+]" }
                "Warning" { "[!]" }
                "Error"   { "[X]" }
                "Skipped" { "[-]" }
            }
            $color = switch ($result.Status) {
                "Success" { "Green" }
                "Warning" { "Yellow" }
                "Error"   { "Red" }
                "Skipped" { "DarkGray" }
            }

            Write-Host "    $icon Stage $($result.StageNumber): $($result.StageName) - $($result.Summary) ($($result.Duration.ToString('mm\:ss')))" -ForegroundColor $color
        }
    }

    # Show key metrics
    $metrics = Get-Metrics
    Write-Host ""
    Write-Host "  Key Metrics:" -ForegroundColor White
    Write-Host "  ─────────────────────────────────────────────────────" -ForegroundColor DarkGray

    foreach ($category in $metrics.Keys) {
        foreach ($key in $metrics[$category].Keys) {
            Write-Host "    $category/$key : $($metrics[$category][$key])" -ForegroundColor DarkCyan
        }
    }

    # Report location
    if ($reportPath) {
        Write-Host ""
        Write-Host "  Full HTML report: $reportPath" -ForegroundColor Green
    }

    $logFile = Get-LogFilePath
    if ($logFile) {
        Write-Host "  Full log: $logFile" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "  A system reboot is recommended to apply all changes." -ForegroundColor Yellow
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor Cyan
    Write-Host ""

    $stageTimer.Stop()

    Register-StageResult -StageNumber 10 -StageName "Wrap-up" -Status "Success" `
        -Summary "Reports generated successfully" -Duration $stageTimer.Elapsed

    return @{
        HealthBefore = $HealthBefore
        HealthAfter  = $healthAfter
        ReportPath   = $reportPath
        LogPath      = $logFile
    }
}

function Show-BeforeAfterComparison {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Before,

        [Parameter(Mandatory)]
        [hashtable]$After
    )

    $change = $After.Score - $Before.Score
    $changeSymbol = if ($change -gt 0) { "+" } elseif ($change -lt 0) { "" } else { "" }
    $changeColor = if ($change -gt 0) { "Green" } elseif ($change -lt 0) { "Red" } else { "Yellow" }

    Write-Host "  ┌───────────────────────────────────────────────────────┐" -ForegroundColor DarkGray
    Write-Host "  │            HEALTH SCORE COMPARISON                    │" -ForegroundColor DarkGray
    Write-Host "  ├───────────────────────────────────────────────────────┤" -ForegroundColor DarkGray
    Write-Host "  │                                                       │" -ForegroundColor DarkGray
    Write-Host "  │   BEFORE:  $("$($Before.Score)/100 (Grade: $($Before.Grade))".PadRight(40))│" -ForegroundColor Yellow
    Write-Host "  │   AFTER:   $("$($After.Score)/100 (Grade: $($After.Grade))".PadRight(40))│" -ForegroundColor Green
    Write-Host "  │   CHANGE:  $("$changeSymbol$change points".PadRight(40))│" -ForegroundColor $changeColor
    Write-Host "  │                                                       │" -ForegroundColor DarkGray
    Write-Host "  └───────────────────────────────────────────────────────┘" -ForegroundColor DarkGray
}

Export-ModuleMember -Function Invoke-Stage10

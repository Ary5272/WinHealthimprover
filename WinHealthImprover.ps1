#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    WinHealthImprover - Windows System Repair, Optimization & Hardening Toolkit
.DESCRIPTION
    A comprehensive, modern PowerShell-based system repair and optimization tool.
    Successor to batch-based tools like Tron, with additional privacy, security,
    and network optimization stages.

    STAGES:
        0  - Prep:       System preparation, restore point, kill interfering processes
        1  - TempClean:  Clean temp files, caches, browser data, logs
        2  - Debloat:    Remove bloatware, UWP apps, OEM crapware
        3  - Disinfect:  Malware scanning, suspicious process/task detection
        4  - Repair:     SFC, DISM, WU reset, WMI, network stack repair
        5  - Patch:      Windows Updates, driver updates, software audit
        6  - Optimize:   Defrag/TRIM, power plans, services, visual effects
        7  - Privacy:    Telemetry, tracking, advertising, data collection
        8  - Network:    DNS, TCP/IP tuning, adapter optimization
        9  - Security:   Defender hardening, ASR rules, credential protection
        10 - Wrap-up:    Health score, HTML report, restore point

.PARAMETER DryRun
    Show what would be done without making changes.

.PARAMETER SkipStages
    Array of stage numbers to skip (e.g., -SkipStages 2,5,7)

.PARAMETER OnlyStages
    Run only these stage numbers (e.g., -OnlyStages 1,4,6)

.PARAMETER OptimizationLevel
    How aggressively to optimize: Balanced, Performance, MaxPerformance

.PARAMETER PrivacyLevel
    Privacy hardening level: Moderate, Aggressive

.PARAMETER SecurityLevel
    Security hardening level: Standard, Enhanced

.PARAMETER DNSProvider
    DNS provider for network optimization: Cloudflare, Google, Quad9

.PARAMETER QuickScan
    Use quick scan instead of full scan for malware detection.

.PARAMETER SkipWindowsUpdates
    Skip Windows Update installation (faster execution).

.PARAMETER KeepOneDrive
    Do not remove OneDrive during debloat stage.

.PARAMETER AggressiveDebloat
    Remove additional apps during debloat (may remove useful apps).

.PARAMETER LogDirectory
    Custom log directory path. Defaults to .\logs

.EXAMPLE
    .\WinHealthImprover.ps1
    Run all stages with default settings.

.EXAMPLE
    .\WinHealthImprover.ps1 -DryRun
    Preview all changes without modifying the system.

.EXAMPLE
    .\WinHealthImprover.ps1 -OnlyStages 1,4,6 -OptimizationLevel MaxPerformance
    Only run cleanup, repair, and optimization at maximum performance level.

.EXAMPLE
    .\WinHealthImprover.ps1 -SkipStages 3,5 -PrivacyLevel Aggressive
    Run all stages except disinfect and patch, with aggressive privacy hardening.
#>

[CmdletBinding()]
param(
    [switch]$DryRun,

    [int[]]$SkipStages = @(),

    [int[]]$OnlyStages = @(),

    [ValidateSet("Balanced", "Performance", "MaxPerformance")]
    [string]$OptimizationLevel = "Performance",

    [ValidateSet("Moderate", "Aggressive")]
    [string]$PrivacyLevel = "Moderate",

    [ValidateSet("Standard", "Enhanced")]
    [string]$SecurityLevel = "Standard",

    [ValidateSet("Cloudflare", "Google", "Quad9")]
    [string]$DNSProvider = "Cloudflare",

    [switch]$QuickScan,

    [switch]$SkipWindowsUpdates,

    [switch]$KeepOneDrive,

    [switch]$AggressiveDebloat,

    [string]$LogDirectory = (Join-Path $PSScriptRoot "logs"),

    [switch]$SkipChkdsk,

    [switch]$NoRestore,

    [switch]$Headless,

    # Auto-reboot after completion (delay in seconds, 0 = no reboot)
    [int]$AutoReboot = 0,

    # Auto-shutdown after completion
    [switch]$AutoShutdown,

    # Resume from a previous interrupted run
    [switch]$Resume,

    # Show configuration and exit without running
    [switch]$ConfigDump,

    # Verbose output (more detailed logging)
    [switch]$VerboseOutput,

    # Self-destruct: delete WinHealthImprover files after run
    [switch]$SelfDestruct,

    # Automatic mode - no prompts
    [switch]$Auto
)

# ============================================================================
# EXIT CODES
# ============================================================================
# 0 = Success
# 1 = Pre-flight check failure
# 2 = Warning (non-fatal errors occurred)
# 3 = Unsupported OS
# 4 = Not running as administrator
# 5 = Running from TEMP directory (dangerous - temp gets wiped)

# ============================================================================
# SAFETY CHECKS
# ============================================================================

# Block running from TEMP directory (it gets wiped in Stage 1)
if ($PSScriptRoot -and $PSScriptRoot.ToLower().Contains("\temp")) {
    Write-Host ""
    Write-Host "  ERROR: Do not run WinHealthImprover from a TEMP directory!" -ForegroundColor Red
    Write-Host "  The temp folder gets cleaned in Stage 1. Move to a permanent location." -ForegroundColor Red
    exit 5
}

# ============================================================================
# INITIALIZATION
# ============================================================================

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"  # Speed up web requests

$scriptRoot = $PSScriptRoot
$checkpointFile = Join-Path $LogDirectory "whi_checkpoint.json"
$exitCode = 0

# Import core modules
Import-Module (Join-Path $scriptRoot "modules\Core\Logging.psm1") -Force -DisableNameChecking
Import-Module (Join-Path $scriptRoot "modules\Core\Utils.psm1") -Force -DisableNameChecking
Import-Module (Join-Path $scriptRoot "modules\Core\Initialize.psm1") -Force -DisableNameChecking
Import-Module (Join-Path $scriptRoot "modules\Core\Reporting.psm1") -Force -DisableNameChecking

# Import stage modules
for ($i = 0; $i -le 10; $i++) {
    $stageName = switch ($i) {
        0  { "Stage0-Prep" }
        1  { "Stage1-TempClean" }
        2  { "Stage2-Debloat" }
        3  { "Stage3-Disinfect" }
        4  { "Stage4-Repair" }
        5  { "Stage5-Patch" }
        6  { "Stage6-Optimize" }
        7  { "Stage7-Privacy" }
        8  { "Stage8-Network" }
        9  { "Stage9-Security" }
        10 { "Stage10-Wrapup" }
    }
    $modulePath = Join-Path $scriptRoot "modules\$stageName.psm1"
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force -DisableNameChecking
    }
}

# ============================================================================
# CONFIG DUMP MODE
# ============================================================================

if ($ConfigDump) {
    Write-Host ""
    Write-Host "  WinHealthImprover Configuration:" -ForegroundColor Cyan
    Write-Host "  ─────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  DryRun:             $DryRun"
    Write-Host "  SkipStages:         $($SkipStages -join ', ')"
    Write-Host "  OnlyStages:         $($OnlyStages -join ', ')"
    Write-Host "  OptimizationLevel:  $OptimizationLevel"
    Write-Host "  PrivacyLevel:       $PrivacyLevel"
    Write-Host "  SecurityLevel:      $SecurityLevel"
    Write-Host "  DNSProvider:        $DNSProvider"
    Write-Host "  QuickScan:          $QuickScan"
    Write-Host "  SkipWindowsUpdates: $SkipWindowsUpdates"
    Write-Host "  KeepOneDrive:       $KeepOneDrive"
    Write-Host "  AggressiveDebloat:  $AggressiveDebloat"
    Write-Host "  SkipChkdsk:         $SkipChkdsk"
    Write-Host "  NoRestore:          $NoRestore"
    Write-Host "  AutoReboot:         $AutoReboot"
    Write-Host "  AutoShutdown:       $AutoShutdown"
    Write-Host "  LogDirectory:       $LogDirectory"
    Write-Host "  ─────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""
    exit 0
}

# ============================================================================
# CHECKPOINT / RESUME SYSTEM
# ============================================================================

$resumeFromStage = 0

if ($Resume -and (Test-Path $checkpointFile)) {
    try {
        $checkpoint = Get-Content -Path $checkpointFile -Raw | ConvertFrom-Json
        $resumeFromStage = $checkpoint.LastCompletedStage + 1
        Write-Host ""
        Write-Host "  Resuming from Stage $resumeFromStage (previously completed through Stage $($checkpoint.LastCompletedStage))" -ForegroundColor Yellow
        Write-Host ""
    }
    catch {
        Write-Host "  Could not read checkpoint file, starting fresh" -ForegroundColor Yellow
        $resumeFromStage = 0
    }
}

function Save-Checkpoint {
    param([int]$StageNumber)
    try {
        if (-not (Test-Path $LogDirectory)) {
            New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
        }
        @{
            LastCompletedStage = $StageNumber
            Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            Computer = $env:COMPUTERNAME
        } | ConvertTo-Json | Out-File -FilePath $checkpointFile -Encoding UTF8 -Force
    }
    catch { }
}

function Remove-Checkpoint {
    if (Test-Path $checkpointFile) {
        Remove-Item -Path $checkpointFile -Force -ErrorAction SilentlyContinue
    }
}

# ============================================================================
# BANNER & PRE-FLIGHT
# ============================================================================

Show-Banner

if ($DryRun) {
    Write-Host "  *** DRY RUN MODE - No changes will be made ***" -ForegroundColor Yellow
    Write-Host ""
    Set-DryRunMode -Enabled $true
}

# Initialize logging
$logFile = Initialize-Logging -LogDirectory $LogDirectory
Write-Log -Message "WinHealthImprover v1.0.0 started" -Level "INFO" -Component "Main"
Write-Log -Message "Log file: $logFile" -Level "INFO" -Component "Main"
Write-Log -Message "PowerShell version: $($PSVersionTable.PSVersion)" -Level "INFO" -Component "Main"

# Pre-flight checks
Write-Log -Message "Running pre-flight checks..." -Level "INFO" -Component "Main"
$prereqs = Test-Prerequisites
$sysInfo = Get-SystemInfo

if ($prereqs.Errors.Count -gt 0 -and -not $DryRun) {
    foreach ($err in $prereqs.Errors) {
        Write-Log -Message $err -Level "ERROR" -Component "Main"
    }
    Write-Host ""
    Write-Host "  Pre-flight checks failed. Fix the issues above and try again." -ForegroundColor Red
    Write-Host "  Use -DryRun to preview changes without admin privileges." -ForegroundColor Yellow
    exit 1
}

# Show system info
Show-SystemSummary -SystemInfo $sysInfo -Prerequisites $prereqs

# Calculate initial health score
Write-Log -Message "Calculating initial health score..." -Level "INFO" -Component "Main"
$healthBefore = Get-HealthScore
Show-HealthScore -Health $healthBefore
Set-Metric -Name "HealthScoreBefore" -Value $healthBefore.Score -Category "Overall"

# Log configuration
Write-Log -Message "Configuration: OptimizationLevel=$OptimizationLevel, PrivacyLevel=$PrivacyLevel, SecurityLevel=$SecurityLevel" -Level "INFO" -Component "Main"
Write-Log -Message "Configuration: DNSProvider=$DNSProvider, QuickScan=$QuickScan, DryRun=$DryRun" -Level "INFO" -Component "Main"

if ($SkipStages.Count -gt 0) {
    Write-Log -Message "Skipping stages: $($SkipStages -join ', ')" -Level "INFO" -Component "Main"
}
if ($OnlyStages.Count -gt 0) {
    Write-Log -Message "Running only stages: $($OnlyStages -join ', ')" -Level "INFO" -Component "Main"
}
if ($Resume) {
    Write-Log -Message "Resume mode: starting from stage $resumeFromStage" -Level "INFO" -Component "Main"
}

# ============================================================================
# STAGE EXECUTION
# ============================================================================

function Test-ShouldRunStage {
    param([int]$StageNumber)

    # Skip stages we've already completed in a resume
    if ($Resume -and $StageNumber -lt $resumeFromStage) {
        return $false
    }

    if ($OnlyStages.Count -gt 0) {
        return ($StageNumber -in $OnlyStages)
    }
    return ($StageNumber -notin $SkipStages)
}

$totalTimer = [System.Diagnostics.Stopwatch]::StartNew()

# Stage execution with checkpoint support
$stageDefinitions = @(
    @{ Num = 0;  Name = "Preparation"; Invoke = { Invoke-Stage0 -DryRun:$DryRun -LogDirectory $LogDirectory } },
    @{ Num = 1;  Name = "TempClean";   Invoke = { Invoke-Stage1 -DryRun:$DryRun } },
    @{ Num = 2;  Name = "Debloat";     Invoke = { Invoke-Stage2 -DryRun:$DryRun -KeepOneDrive:$KeepOneDrive -AggressiveDebloat:$AggressiveDebloat } },
    @{ Num = 3;  Name = "Disinfect";   Invoke = { Invoke-Stage3 -DryRun:$DryRun -QuickScan:$QuickScan } },
    @{ Num = 4;  Name = "Repair";      Invoke = { Invoke-Stage4 -DryRun:$DryRun -SkipChkdsk:$SkipChkdsk } },
    @{ Num = 5;  Name = "Patch";       Invoke = { Invoke-Stage5 -DryRun:$DryRun -SkipWindowsUpdates:$SkipWindowsUpdates } },
    @{ Num = 6;  Name = "Optimize";    Invoke = { Invoke-Stage6 -DryRun:$DryRun -OptimizationLevel $OptimizationLevel } },
    @{ Num = 7;  Name = "Privacy";     Invoke = { Invoke-Stage7 -DryRun:$DryRun -PrivacyLevel $PrivacyLevel } },
    @{ Num = 8;  Name = "Network";     Invoke = { Invoke-Stage8 -DryRun:$DryRun -DNSProvider $DNSProvider } },
    @{ Num = 9;  Name = "Security";    Invoke = { Invoke-Stage9 -DryRun:$DryRun -SecurityLevel $SecurityLevel } }
)

foreach ($stage in $stageDefinitions) {
    if (Test-ShouldRunStage $stage.Num) {
        try {
            & $stage.Invoke
            Save-Checkpoint -StageNumber $stage.Num
        }
        catch {
            Write-Log -Message "Stage $($stage.Num) ($($stage.Name)) failed: $_" -Level "ERROR" -Component "Main"
            Register-StageResult -StageNumber $stage.Num -StageName $stage.Name -Status "Error" -Summary "Failed: $_"
            $exitCode = 2
        }
    }
    else {
        if ($Resume -and $stage.Num -lt $resumeFromStage) {
            Write-Log -Message "Stage $($stage.Num) ($($stage.Name)) already completed (resume)" -Level "INFO" -Component "Main"
            Register-StageResult -StageNumber $stage.Num -StageName $stage.Name -Status "Skipped" -Summary "Already completed (resume)"
        }
        else {
            Write-Log -Message "Stage $($stage.Num) ($($stage.Name)) skipped" -Level "INFO" -Component "Main"
            Register-StageResult -StageNumber $stage.Num -StageName $stage.Name -Status "Skipped" -Summary "Skipped by user"
        }
    }
}

# ---- Stage 10: Wrap-up (always runs) ----
$wrapupResult = Invoke-Stage10 -HealthBefore $healthBefore -SystemInfo $sysInfo `
    -LogDirectory $LogDirectory -DryRun:$DryRun `
    -SkipFinalRestorePoint:$NoRestore

$totalTimer.Stop()

# Clean up checkpoint on successful completion
Remove-Checkpoint

Set-Metric -Name "TotalDuration" -Value $totalTimer.Elapsed.ToString('hh\:mm\:ss') -Category "Overall"
if ($wrapupResult.HealthAfter) {
    Set-Metric -Name "HealthScoreAfter" -Value $wrapupResult.HealthAfter.Score -Category "Overall"
}

Write-Log -Message "WinHealthImprover completed in $($totalTimer.Elapsed.ToString('hh\:mm\:ss'))" -Level "INFO" -Component "Main"
Write-Host "  WinHealthImprover finished in $($totalTimer.Elapsed.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# POST-RUN ACTIONS
# ============================================================================

# Self-destruct mode
if ($SelfDestruct -and -not $DryRun) {
    Write-Log -Message "Self-destruct mode: removing WinHealthImprover files..." -Level "WARN" -Component "Main"
    # Schedule deletion after script exits (can't delete yourself while running)
    $selfDestructCmd = "Start-Sleep -Seconds 5; Remove-Item -Path '$scriptRoot' -Recurse -Force -ErrorAction SilentlyContinue"
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"$selfDestructCmd`"" -WindowStyle Hidden
}

# Auto-shutdown
if ($AutoShutdown -and -not $DryRun) {
    Write-Host "  System will shut down in 30 seconds..." -ForegroundColor Yellow
    Write-Host "  Run 'shutdown /a' to cancel." -ForegroundColor Yellow
    Write-Log -Message "Auto-shutdown initiated (30 second delay)" -Level "WARN" -Component "Main"
    & shutdown /s /t 30 /c "WinHealthImprover completed. System shutting down." 2>&1 | Out-Null
}
# Auto-reboot
elseif ($AutoReboot -gt 0 -and -not $DryRun) {
    Write-Host "  System will reboot in $AutoReboot seconds..." -ForegroundColor Yellow
    Write-Host "  Run 'shutdown /a' to cancel." -ForegroundColor Yellow
    Write-Log -Message "Auto-reboot initiated ($AutoReboot second delay)" -Level "WARN" -Component "Main"
    & shutdown /r /t $AutoReboot /c "WinHealthImprover completed. System rebooting to apply changes." 2>&1 | Out-Null
}

exit $exitCode

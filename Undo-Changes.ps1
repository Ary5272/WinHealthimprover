#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    WinHealthImprover - Undo All Changes
.DESCRIPTION
    Standalone script to reverse ALL changes made by WinHealthImprover.
    Reads the SafetyNet journal and rolls back every registry change,
    service modification, and file deletion.

    Simply double-click or run this script to undo everything.

.EXAMPLE
    .\Undo-Changes.ps1
    Undo all changes from the most recent run.

.EXAMPLE
    .\Undo-Changes.ps1 -JournalFile ".\logs\SafetyNet_20240101_120000.json"
    Undo changes from a specific run.

.EXAMPLE
    .\Undo-Changes.ps1 -WhatIf
    Preview what would be undone without making changes.

.EXAMPLE
    .\Undo-Changes.ps1 -Stage 7
    Only undo changes from Stage 7 (Privacy).
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    # Path to a specific SafetyNet journal file. If not specified, finds the most recent one.
    [string]$JournalFile = "",

    # Only undo changes from a specific stage number
    [int]$Stage = -1,

    # Show what would be undone without making changes
    [switch]$WhatIf,

    # Log directory to search for journal files
    [string]$LogDirectory = (Join-Path $PSScriptRoot "logs")
)

# ============================================================================
# FIND JOURNAL FILE
# ============================================================================

function Find-LatestJournal {
    param([string]$SearchDir)

    if (-not (Test-Path $SearchDir)) {
        return $null
    }

    $journals = Get-ChildItem -Path $SearchDir -Filter "SafetyNet_*.json" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending

    if ($journals.Count -eq 0) { return $null }

    return $journals[0].FullName
}

# ============================================================================
# MAIN
# ============================================================================

Clear-Host

Write-Host ""
Write-Host "  +==============================================================+" -ForegroundColor Cyan
Write-Host "  |           WinHealthImprover - Undo Changes                  |" -ForegroundColor Cyan
Write-Host "  +==============================================================+" -ForegroundColor Cyan
Write-Host ""

# Find the journal file
if ([string]::IsNullOrWhiteSpace($JournalFile)) {
    $JournalFile = Find-LatestJournal -SearchDir $LogDirectory

    if (-not $JournalFile) {
        Write-Host "  No SafetyNet journal found in: $LogDirectory" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  This means either:" -ForegroundColor White
        Write-Host "    - WinHealthImprover hasn't been run yet" -ForegroundColor DarkGray
        Write-Host "    - The log directory was deleted" -ForegroundColor DarkGray
        Write-Host "    - Changes were already undone" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  To specify a journal file manually:" -ForegroundColor DarkCyan
        Write-Host "    .\Undo-Changes.ps1 -JournalFile 'path\to\SafetyNet_*.json'" -ForegroundColor DarkCyan
        Write-Host ""
        exit 0
    }
}

if (-not (Test-Path $JournalFile)) {
    Write-Host "  Journal file not found: $JournalFile" -ForegroundColor Red
    exit 1
}

Write-Host "  Journal file: $JournalFile" -ForegroundColor DarkCyan
Write-Host ""

# Load journal
try {
    $journal = Get-Content -Path $JournalFile -Raw | ConvertFrom-Json
}
catch {
    Write-Host "  ERROR: Could not read journal file: $_" -ForegroundColor Red
    exit 1
}

# Show summary
$regCount = @($journal.Registry).Count
$svcCount = @($journal.Services).Count
$fileCount = @($journal.Files).Count
$totalChanges = $journal.TotalChanges

Write-Host "  Changes recorded in this journal:" -ForegroundColor White
Write-Host "  ---------------------------------------------" -ForegroundColor DarkGray
Write-Host "    Registry values changed:  $regCount" -ForegroundColor DarkCyan
Write-Host "    Services modified:         $svcCount" -ForegroundColor DarkCyan
Write-Host "    Files affected:            $fileCount" -ForegroundColor DarkCyan
Write-Host "    Total tracked changes:     $totalChanges" -ForegroundColor DarkCyan
Write-Host "    Computer:                  $($journal.ComputerName)" -ForegroundColor DarkCyan
Write-Host "    Date:                      $($journal.CreatedAt)" -ForegroundColor DarkCyan
Write-Host ""

# If specific stage requested, filter
if ($Stage -ge 0) {
    Write-Host "  Filtering to Stage $Stage changes only..." -ForegroundColor Yellow
    Write-Host ""
}

# ============================================================================
# LIST AVAILABLE JOURNALS (if multiple exist)
# ============================================================================

$allJournals = Get-ChildItem -Path $LogDirectory -Filter "SafetyNet_*.json" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending

if ($allJournals.Count -gt 1) {
    Write-Host "  Other available journals:" -ForegroundColor DarkGray
    for ($i = 1; $i -lt [math]::Min($allJournals.Count, 6); $i++) {
        Write-Host "    - $($allJournals[$i].Name) ($($allJournals[$i].LastWriteTime.ToString('yyyy-MM-dd HH:mm')))" -ForegroundColor DarkGray
    }
    Write-Host ""
}

# ============================================================================
# CONFIRM
# ============================================================================

if ($WhatIf) {
    Write-Host "  === PREVIEW MODE (no changes will be made) ===" -ForegroundColor Yellow
    Write-Host ""
}

if (-not $WhatIf) {
    Write-Host "  ┌─────────────────────────────────────────────────────────┐" -ForegroundColor Yellow
    Write-Host "  │  WARNING: This will reverse all changes listed above.   │" -ForegroundColor Yellow
    Write-Host "  │  Your system will be restored to its pre-run state.     │" -ForegroundColor Yellow
    Write-Host "  └─────────────────────────────────────────────────────────┘" -ForegroundColor Yellow
    Write-Host ""

    do {
        $confirm = Read-Host "  Proceed with undo? (yes/no)"
        if ($confirm -eq "yes") { break }
        if ($confirm -eq "no") {
            Write-Host ""
            Write-Host "  Undo cancelled. No changes were made." -ForegroundColor Cyan
            exit 0
        }
        Write-Host "  Please type 'yes' or 'no'" -ForegroundColor Red
    } while ($true)
}

# ============================================================================
# PERFORM UNDO
# ============================================================================

Write-Host ""
Write-Host "  Rolling back changes..." -ForegroundColor Cyan
Write-Host "  ---------------------------------------------" -ForegroundColor DarkGray

$undone = 0
$failed = 0

# ---- Undo Registry Changes (reverse order) ----
if ($journal.Registry) {
    $regEntries = @($journal.Registry)
    [array]::Reverse($regEntries)

    # Filter by stage if requested
    if ($Stage -ge 0) {
        $regEntries = $regEntries | Where-Object { $_.Stage -eq "Stage$Stage" }
    }

    foreach ($reg in $regEntries) {
        $target = "$($reg.Path)\$($reg.Name)"

        if ($WhatIf) {
            if ($reg.Existed -eq $true -or $reg.Existed -eq "True") {
                Write-Host "    [PREVIEW] Would restore: $target = $($reg.OldValue)" -ForegroundColor DarkCyan
            }
            else {
                Write-Host "    [PREVIEW] Would remove:  $target" -ForegroundColor DarkCyan
            }
            $undone++
            continue
        }

        try {
            if ($reg.Existed -eq $true -or $reg.Existed -eq "True") {
                if (-not (Test-Path $reg.Path)) {
                    New-Item -Path $reg.Path -Force | Out-Null
                }
                Set-ItemProperty -Path $reg.Path -Name $reg.Name -Value $reg.OldValue -Force -ErrorAction Stop
                Write-Host "    [OK] Registry restored: $target" -ForegroundColor Green
            }
            else {
                Remove-ItemProperty -Path $reg.Path -Name $reg.Name -Force -ErrorAction SilentlyContinue
                Write-Host "    [OK] Registry removed:  $target" -ForegroundColor Green
            }
            $undone++
        }
        catch {
            Write-Host "    [FAIL] Could not undo: $target - $_" -ForegroundColor Red
            $failed++
        }
    }
}

# ---- Undo Service Changes ----
if ($journal.Services) {
    $svcEntries = @($journal.Services)

    if ($Stage -ge 0) {
        $svcEntries = $svcEntries | Where-Object { $_.Stage -eq "Stage$Stage" }
    }

    foreach ($svc in $svcEntries) {
        $startType = switch ($svc.OriginalStartup) {
            "Auto"     { "Automatic" }
            "Manual"   { "Manual" }
            "Disabled" { "Disabled" }
            default    { $svc.OriginalStartup }
        }

        if ($WhatIf) {
            Write-Host "    [PREVIEW] Would restore service: $($svc.ServiceName) -> $startType" -ForegroundColor DarkCyan
            $undone++
            continue
        }

        try {
            Set-Service -Name $svc.ServiceName -StartupType $startType -ErrorAction Stop

            if ($svc.OriginalStatus -eq "Running") {
                Start-Service -Name $svc.ServiceName -ErrorAction SilentlyContinue
            }

            Write-Host "    [OK] Service restored: $($svc.ServiceName) -> $startType" -ForegroundColor Green
            $undone++
        }
        catch {
            Write-Host "    [FAIL] Could not undo: $($svc.ServiceName) - $_" -ForegroundColor Red
            $failed++
        }
    }
}

# ---- Restore Backed-Up Files ----
if ($journal.Files) {
    $fileEntries = @($journal.Files)

    if ($Stage -ge 0) {
        $fileEntries = $fileEntries | Where-Object { $_.Stage -eq "Stage$Stage" }
    }

    foreach ($file in $fileEntries) {
        if ($file.BackupPath -and (Test-Path $file.BackupPath)) {
            if ($WhatIf) {
                Write-Host "    [PREVIEW] Would restore file: $($file.OriginalPath)" -ForegroundColor DarkCyan
                $undone++
                continue
            }

            try {
                $destDir = Split-Path $file.OriginalPath -Parent
                if (-not (Test-Path $destDir)) {
                    New-Item -Path $destDir -ItemType Directory -Force | Out-Null
                }
                Copy-Item -Path $file.BackupPath -Destination $file.OriginalPath -Force -ErrorAction Stop
                Write-Host "    [OK] File restored: $($file.OriginalPath)" -ForegroundColor Green
                $undone++
            }
            catch {
                Write-Host "    [FAIL] Could not restore: $($file.OriginalPath) - $_" -ForegroundColor Red
                $failed++
            }
        }
    }
}

# ============================================================================
# SUMMARY
# ============================================================================

Write-Host ""
Write-Host "  ---------------------------------------------" -ForegroundColor DarkGray

if ($WhatIf) {
    Write-Host "  PREVIEW: $undone changes would be reversed." -ForegroundColor Cyan
    Write-Host "  Run without -WhatIf to actually undo." -ForegroundColor DarkCyan
}
else {
    if ($failed -eq 0) {
        Write-Host "  SUCCESS: $undone changes reversed. Your system is restored!" -ForegroundColor Green
    }
    else {
        Write-Host "  PARTIAL: $undone changes reversed, $failed failed." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "  A system reboot is recommended to fully apply the rollback." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  Press any key to exit..." -ForegroundColor DarkGray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

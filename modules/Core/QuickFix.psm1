#Requires -Version 5.1
<#
.SYNOPSIS
    WinHealthImprover - Quick-Fix Presets Module
.DESCRIPTION
    One-click preset configurations for common tasks. Each preset bundles
    the right stages and settings for a specific goal.

    Presets:
    - Fix My PC:     Repair, clean, and optimize a troubled system
    - Speed Up:      Maximum performance optimization
    - Privacy Lock:  Full privacy hardening
    - Clean Sweep:   Deep clean of junk files and bloatware
    - Security Max:  Maximum security hardening
    - Fresh Start:   Full treatment for a near-new PC feel
    - Maintenance:   Quick routine maintenance run
#>

function Get-QuickFixPresets {
    <#
    .SYNOPSIS
        Returns all available Quick-Fix presets with their configurations.
    #>
    return @{
        "FixMyPC" = @{
            Name        = "Fix My PC"
            Icon        = "[+]"
            Description = "Repair a slow, broken, or misbehaving PC"
            Detail      = "Cleans junk, scans for malware, repairs Windows files, resets broken services, and optimizes performance."
            Stages      = @(0, 1, 3, 4, 5, 6)
            Settings    = @{
                OptimizationLevel  = "Performance"
                PrivacyLevel       = "Moderate"
                SecurityLevel      = "Standard"
                QuickScan          = $false
                SkipWindowsUpdates = $false
                KeepOneDrive       = $true
                AggressiveDebloat  = $false
                SkipChkdsk         = $false
            }
            EstMinutes  = 30
            Risk        = "Low"
        }

        "SpeedUp" = @{
            Name        = "Speed Up"
            Icon        = "[>]"
            Description = "Make your PC as fast as possible"
            Detail      = "Cleans temp files, removes bloatware, optimizes startup/services/power plan, tunes network, and disables background apps."
            Stages      = @(0, 1, 2, 6, 8)
            Settings    = @{
                OptimizationLevel  = "MaxPerformance"
                PrivacyLevel       = "Moderate"
                SecurityLevel      = "Standard"
                QuickScan          = $true
                SkipWindowsUpdates = $true
                KeepOneDrive       = $false
                AggressiveDebloat  = $false
                SkipChkdsk         = $true
            }
            EstMinutes  = 15
            Risk        = "Low"
        }

        "PrivacyLock" = @{
            Name        = "Privacy Lock"
            Icon        = "[#]"
            Description = "Stop Windows from tracking and spying on you"
            Detail      = "Disables all telemetry, tracking, advertising, location services, app permissions, and Edge/Office data collection."
            Stages      = @(0, 7)
            Settings    = @{
                OptimizationLevel  = "Balanced"
                PrivacyLevel       = "Aggressive"
                SecurityLevel      = "Standard"
                QuickScan          = $true
                SkipWindowsUpdates = $true
                KeepOneDrive       = $true
                AggressiveDebloat  = $false
                SkipChkdsk         = $true
            }
            EstMinutes  = 5
            Risk        = "Low"
        }

        "CleanSweep" = @{
            Name        = "Clean Sweep"
            Icon        = "[~]"
            Description = "Deep clean junk files and bloatware"
            Detail      = "Removes temp files, caches, browser data, Windows Update leftovers, bloatware, OEM crapware, and OneDrive."
            Stages      = @(0, 1, 2)
            Settings    = @{
                OptimizationLevel  = "Balanced"
                PrivacyLevel       = "Moderate"
                SecurityLevel      = "Standard"
                QuickScan          = $true
                SkipWindowsUpdates = $true
                KeepOneDrive       = $false
                AggressiveDebloat  = $true
                SkipChkdsk         = $true
            }
            EstMinutes  = 10
            Risk        = "Moderate"
        }

        "SecurityMax" = @{
            Name        = "Security Max"
            Icon        = "[!]"
            Description = "Maximum security hardening"
            Detail      = "Scans for malware, hardens Defender, enables ASR rules, configures audit policies, disables dangerous features, and locks down RDP/credentials."
            Stages      = @(0, 3, 8, 9)
            Settings    = @{
                OptimizationLevel  = "Balanced"
                PrivacyLevel       = "Aggressive"
                SecurityLevel      = "Enhanced"
                QuickScan          = $false
                SkipWindowsUpdates = $true
                KeepOneDrive       = $true
                AggressiveDebloat  = $false
                SkipChkdsk         = $true
            }
            EstMinutes  = 15
            Risk        = "Low"
        }

        "FreshStart" = @{
            Name        = "Fresh Start"
            Icon        = "[*]"
            Description = "The full treatment - like a brand new PC"
            Detail      = "Runs EVERY stage: clean, debloat, scan, repair, update, optimize, privacy, network, and security. The works!"
            Stages      = @(0, 1, 2, 3, 4, 5, 6, 7, 8, 9)
            Settings    = @{
                OptimizationLevel  = "Performance"
                PrivacyLevel       = "Moderate"
                SecurityLevel      = "Standard"
                QuickScan          = $false
                SkipWindowsUpdates = $false
                KeepOneDrive       = $false
                AggressiveDebloat  = $false
                SkipChkdsk         = $false
            }
            EstMinutes  = 60
            Risk        = "Moderate"
        }

        "Maintenance" = @{
            Name        = "Quick Maintenance"
            Icon        = "[=]"
            Description = "Routine maintenance (run monthly)"
            Detail      = "Quick temp cleanup, virus scan, disk optimization, and Windows Update check. Fast and safe for regular use."
            Stages      = @(0, 1, 3, 5, 6)
            Settings    = @{
                OptimizationLevel  = "Balanced"
                PrivacyLevel       = "Moderate"
                SecurityLevel      = "Standard"
                QuickScan          = $true
                SkipWindowsUpdates = $false
                KeepOneDrive       = $true
                AggressiveDebloat  = $false
                SkipChkdsk         = $true
            }
            EstMinutes  = 20
            Risk        = "Very Low"
        }
    }
}

function Show-QuickFixMenu {
    <#
    .SYNOPSIS
        Display the Quick-Fix preset selection menu.
    #>
    [CmdletBinding()]
    param()

    $presets = Get-QuickFixPresets
    $presetOrder = @("FixMyPC", "SpeedUp", "PrivacyLock", "CleanSweep", "SecurityMax", "FreshStart", "Maintenance")

    Write-Host ""
    Write-Host "  +==============================================================+" -ForegroundColor Cyan
    Write-Host "  |              Quick-Fix Presets                               |" -ForegroundColor Cyan
    Write-Host "  |   Pick a preset and we'll handle the rest!                  |" -ForegroundColor Cyan
    Write-Host "  +==============================================================+" -ForegroundColor Cyan
    Write-Host ""

    $index = 1
    foreach ($key in $presetOrder) {
        $preset = $presets[$key]
        $riskColor = switch ($preset.Risk) {
            "Very Low"  { "Green" }
            "Low"       { "Green" }
            "Moderate"  { "Yellow" }
            "High"      { "Red" }
        }

        Write-Host "    [$index] $($preset.Icon) $($preset.Name)" -ForegroundColor White
        Write-Host "        $($preset.Description)" -ForegroundColor DarkCyan
        Write-Host "        Risk: " -NoNewline -ForegroundColor DarkGray
        Write-Host "$($preset.Risk)" -NoNewline -ForegroundColor $riskColor
        Write-Host " | Time: ~$($preset.EstMinutes) min" -ForegroundColor DarkGray
        Write-Host ""
        $index++
    }

    Write-Host "    [8] Back to main menu" -ForegroundColor DarkGray
    Write-Host ""

    do {
        $choice = Read-Host "  Select a preset (1-7, 8 to go back)"
        $num = 0
        if ([int]::TryParse($choice, [ref]$num) -and $num -ge 1 -and $num -le 8) {
            break
        }
        Write-Host "  Please enter a number between 1 and 8" -ForegroundColor Red
    } while ($true)

    if ($num -eq 8) { return $null }

    $selectedKey = $presetOrder[$num - 1]
    $selected = $presets[$selectedKey]

    # Show detail and confirm
    Write-Host ""
    Write-Host "  Selected: $($selected.Name)" -ForegroundColor Green
    Write-Host "  $($selected.Detail)" -ForegroundColor White
    Write-Host ""
    Write-Host "  Stages: $($selected.Stages -join ', ')" -ForegroundColor DarkCyan
    Write-Host "  Estimated time: ~$($selected.EstMinutes) minutes" -ForegroundColor DarkCyan
    Write-Host ""

    Write-Host "  +---------------------------------------------------------+" -ForegroundColor Green
    Write-Host "  |  All changes are tracked and reversible!                |" -ForegroundColor Green
    Write-Host "  |  Run .\Undo-Changes.ps1 to reverse everything.          |" -ForegroundColor Green
    Write-Host "  +---------------------------------------------------------+" -ForegroundColor Green
    Write-Host ""

    do {
        $confirm = Read-Host "  Start this preset? (Y/n)"
        if ([string]::IsNullOrWhiteSpace($confirm) -or $confirm -match "^[Yy]") {
            return @{
                PresetKey = $selectedKey
                Preset    = $selected
            }
        }
        if ($confirm -match "^[Nn]") { return $null }
        Write-Host "  Please enter Y or N" -ForegroundColor Red
    } while ($true)
}

function ConvertTo-ScriptParams {
    <#
    .SYNOPSIS
        Convert a Quick-Fix preset selection into script parameters.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$PresetSelection
    )

    $preset = $PresetSelection.Preset

    return @{
        OnlyStages         = $preset.Stages
        DryRun             = $false
        OptimizationLevel  = $preset.Settings.OptimizationLevel
        PrivacyLevel       = $preset.Settings.PrivacyLevel
        SecurityLevel      = $preset.Settings.SecurityLevel
        DNSProvider        = "Cloudflare"
        QuickScan          = $preset.Settings.QuickScan
        SkipWindowsUpdates = $preset.Settings.SkipWindowsUpdates
        KeepOneDrive       = $preset.Settings.KeepOneDrive
        AggressiveDebloat  = $preset.Settings.AggressiveDebloat
        SkipChkdsk         = $preset.Settings.SkipChkdsk
        PresetName         = $preset.Name
    }
}

Export-ModuleMember -Function Get-QuickFixPresets, Show-QuickFixMenu, ConvertTo-ScriptParams

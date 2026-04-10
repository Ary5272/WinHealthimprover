#Requires -Version 5.1
<#
.SYNOPSIS
    Stage 2: Debloat
.DESCRIPTION
    Removes pre-installed bloatware, unnecessary UWP apps, and OEM crapware:
    - Microsoft UWP bloatware (configurable list)
    - OEM-installed bloatware
    - OneDrive removal (optional)
    - Cortana disabling
    - Suggested apps / tips removal
    - Start menu cleanup
    - Telemetry scheduled tasks
#>

function Invoke-Stage2 {
    [CmdletBinding()]
    param(
        [hashtable]$Config = @{},
        [switch]$DryRun,
        [switch]$KeepOneDrive,
        [switch]$AggressiveDebloat
    )

    $stageTimer = [System.Diagnostics.Stopwatch]::StartNew()
    $removedCount = 0

    Write-StageHeader -StageNumber 2 -StageName "Debloat" -Description "Removing bloatware, unnecessary apps, and pre-installed junk"

    # ---- Remove UWP Bloatware ----
    Write-SubStageHeader "Removing UWP Bloatware"
    $removed = Remove-UWPBloatware -DryRun:$DryRun -Aggressive:$AggressiveDebloat
    $removedCount += $removed

    # ---- Remove OEM Bloatware ----
    Write-SubStageHeader "Removing OEM Bloatware"
    $removed = Remove-OEMBloatware -DryRun:$DryRun
    $removedCount += $removed

    # ---- OneDrive ----
    if (-not $KeepOneDrive) {
        Write-SubStageHeader "Removing OneDrive (Consumer)"
        Remove-OneDriveConsumer -DryRun:$DryRun
    }
    else {
        Write-Log -Message "OneDrive removal skipped (KeepOneDrive flag set)" -Level "INFO" -Component "Stage2"
    }

    # ---- Disable Cortana ----
    Write-SubStageHeader "Disabling Cortana"
    Disable-Cortana -DryRun:$DryRun

    # ---- Disable Suggested Content ----
    Write-SubStageHeader "Disabling Suggested Content & Tips"
    Disable-SuggestedContent -DryRun:$DryRun

    # ---- Disable Consumer Features ----
    Write-SubStageHeader "Disabling Consumer Features"
    Disable-ConsumerFeatures -DryRun:$DryRun

    # ---- Clean Start Menu ----
    Write-SubStageHeader "Cleaning Start Menu Tiles"
    Clear-StartMenuTiles -DryRun:$DryRun

    Write-Host ""
    Write-Log -Message "Debloat complete: $removedCount apps removed" -Level "SUCCESS" -Component "Stage2"

    Set-Metric -Name "AppsRemoved" -Value $removedCount -Category "Stage2"

    $stageTimer.Stop()

    Register-StageResult -StageNumber 2 -StageName "Debloat" -Status "Success" `
        -Summary "Removed $removedCount bloatware apps" `
        -Details @{ RemovedCount = $removedCount } -Duration $stageTimer.Elapsed

    return $removedCount
}

# ============================================================================
# UWP BLOATWARE REMOVAL
# ============================================================================

function Remove-UWPBloatware {
    [CmdletBinding()]
    param(
        [switch]$DryRun,
        [switch]$Aggressive
    )

    # Conservative list - safe to remove for most users
    $bloatwareApps = @(
        # Games & Entertainment
        "Microsoft.BingWeather",
        "Microsoft.BingNews",
        "Microsoft.BingFinance",
        "Microsoft.BingSports",
        "Microsoft.GamingApp",
        "Microsoft.XboxGameOverlay",
        "Microsoft.XboxGamingOverlay",
        "Microsoft.XboxIdentityProvider",
        "Microsoft.XboxSpeechToTextOverlay",
        "Microsoft.Xbox.TCUI",
        "Microsoft.MicrosoftSolitaireCollection",
        "Microsoft.ZuneMusic",
        "Microsoft.ZuneVideo",
        "Microsoft.MixedReality.Portal",

        # Communication
        "Microsoft.People",
        "Microsoft.SkypeApp",
        "Microsoft.YourPhone",

        # Productivity junk
        "Microsoft.MicrosoftOfficeHub",
        "Microsoft.Office.OneNote",
        "Microsoft.Getstarted",
        "Microsoft.GetHelp",
        "Microsoft.Todos",

        # Maps & Travel
        "Microsoft.WindowsMaps",

        # 3D & Creative
        "Microsoft.Microsoft3DViewer",
        "Microsoft.3DBuilder",
        "Microsoft.MSPaint",   # Paint 3D, not classic Paint
        "Microsoft.Print3D",

        # Third-party pre-installed
        "king.com.CandyCrushSaga",
        "king.com.CandyCrushSodaSaga",
        "king.com.BubbleWitch3Saga",
        "GAMELOFTSA.Asphalt8Airborne",
        "Flipboard.Flipboard",
        "ShazamEntertainmentLtd.Shazam",
        "ClearChannelRadioDigital.iHeartRadio",
        "Fitbit.FitbitCoach",
        "Facebook.Facebook",
        "Facebook.Instagram",
        "SpotifyAB.SpotifyMusic",
        "Twitter.Twitter",
        "PandoraMediaInc.29680B314EFC2",
        "AdobeSystemsIncorporated.AdobePhotoshopExpress",
        "Duolingo-LearnLanguagesforFree",
        "EclipseManager",
        "ActiproSoftwareLLC",
        "46928booster.booster",
        "A278AB0D.MarchofEmpires",
        "D5EA27B7.Duolingo-LearnLanguagesforFree",

        # Clipchamp
        "Clipchamp.Clipchamp",

        # News
        "Microsoft.MicrosoftNews",

        # Widgets
        "MicrosoftWindows.Client.WebExperience",

        # Quick Assist (can be reinstalled)
        "MicrosoftCorporationII.QuickAssist",

        # Power Automate
        "Microsoft.PowerAutomateDesktop",

        # Feedback Hub
        "Microsoft.WindowsFeedbackHub"
    )

    # Aggressive additions - may break things for some users
    if ($Aggressive) {
        $bloatwareApps += @(
            "Microsoft.WindowsCamera",
            "Microsoft.WindowsAlarms",
            "Microsoft.WindowsSoundRecorder",
            "Microsoft.ScreenSketch",
            "Microsoft.WindowsCalculator",
            "Microsoft.Windows.Photos",
            "Microsoft.WindowsStore",
            "Microsoft.Wallet",
            "Microsoft.OneConnect"
        )
    }

    $removed = 0
    foreach ($app in $bloatwareApps) {
        $installed = Get-AppxPackage -Name $app -AllUsers -ErrorAction SilentlyContinue
        if ($installed) {
            if ($DryRun) {
                Write-Log -Message "[DRY RUN] Would remove: $app" -Level "INFO" -Component "Stage2"
                $removed++
            }
            else {
                try {
                    # Remove for all users
                    Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction Stop
                    # Prevent reinstallation
                    Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like "*$app*" } |
                        Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
                    Write-Log -Message "Removed: $app" -Level "SUCCESS" -Component "Stage2"
                    $removed++
                }
                catch {
                    Write-Log -Message "Could not remove $app : $_" -Level "WARN" -Component "Stage2"
                }
            }
        }
    }

    Write-Log -Message "Removed $removed UWP bloatware apps" -Level "SUCCESS" -Component "Stage2"
    return $removed
}

# ============================================================================
# OEM BLOATWARE
# ============================================================================

function Remove-OEMBloatware {
    [CmdletBinding()]
    param([switch]$DryRun)

    $oemBloatware = @(
        # Dell
        "*DellInc*", "*DellCustomer*", "*DellSupportAssist*", "*DellDigitalDelivery*",
        "*DellMobileConnect*", "*DellCommandPowerManager*",
        # HP
        "*HPConnected*", "*HPRegistration*", "*HPSupportAssistant*", "*HPJumpStart*",
        "*HPPrinterControl*", "*HPQuickDrop*", "*HPSystemInformation*",
        # Lenovo
        "*LenovoCompanion*", "*LenovoSettings*", "*LenovoUtility*", "*LenovoID*",
        # Acer
        "*AcerInc*", "*AcerExplorer*",
        # Asus
        "*ASUS*AppManager*", "*ASUS*Splendid*",
        # Samsung
        "*SamsungSettings*", "*SamsungNotes*",
        # Toshiba
        "*TOSHIBA*"
    )

    $removed = 0
    foreach ($pattern in $oemBloatware) {
        $installed = Get-AppxPackage -Name $pattern -AllUsers -ErrorAction SilentlyContinue
        foreach ($app in $installed) {
            if ($DryRun) {
                Write-Log -Message "[DRY RUN] Would remove OEM app: $($app.Name)" -Level "INFO" -Component "Stage2"
                $removed++
            }
            else {
                try {
                    $app | Remove-AppxPackage -AllUsers -ErrorAction Stop
                    Write-Log -Message "Removed OEM app: $($app.Name)" -Level "SUCCESS" -Component "Stage2"
                    $removed++
                }
                catch {
                    Write-Log -Message "Could not remove $($app.Name): $_" -Level "WARN" -Component "Stage2"
                }
            }
        }
    }

    Write-Log -Message "Removed $removed OEM bloatware apps" -Level "SUCCESS" -Component "Stage2"
    return $removed
}

# ============================================================================
# ONEDRIVE REMOVAL
# ============================================================================

function Remove-OneDriveConsumer {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would remove OneDrive consumer edition" -Level "INFO" -Component "Stage2"
        return
    }

    try {
        # Kill OneDrive process
        Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue

        # Uninstall
        $oneDrivePaths = @(
            "$env:SystemRoot\System32\OneDriveSetup.exe",
            "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
        )

        foreach ($path in $oneDrivePaths) {
            if (Test-Path $path) {
                & $path /uninstall 2>&1 | Out-Null
                Start-Sleep -Seconds 3
            }
        }

        # Clean up leftover folders
        $foldersToRemove = @(
            "$env:USERPROFILE\OneDrive",
            "$env:LOCALAPPDATA\Microsoft\OneDrive",
            "$env:ProgramData\Microsoft OneDrive"
        )

        foreach ($folder in $foldersToRemove) {
            if (Test-Path $folder) {
                Remove-Item -Path $folder -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        # Remove from Explorer sidebar
        Set-RegistryValue -Path "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" -Name "System.IsPinnedToNameSpaceTree" -Value 0
        Set-RegistryValue -Path "HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" -Name "System.IsPinnedToNameSpaceTree" -Value 0

        # Prevent reinstall
        Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" -Name "DisableFileSyncNGSC" -Value 1

        Write-Log -Message "OneDrive removed successfully" -Level "SUCCESS" -Component "Stage2"
    }
    catch {
        Write-Log -Message "Error removing OneDrive: $_" -Level "WARN" -Component "Stage2"
    }
}

# ============================================================================
# CORTANA / SUGGESTED CONTENT / CONSUMER FEATURES
# ============================================================================

function Disable-Cortana {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would disable Cortana" -Level "INFO" -Component "Stage2"
        return
    }

    $settings = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "AllowCortana"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "AllowCortanaAboveLock"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "AllowSearchToUseLocation"; Value = 0 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"; Name = "CortanaConsent"; Value = 0 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"; Name = "BingSearchEnabled"; Value = 0 }
    )

    foreach ($setting in $settings) {
        Set-RegistryValue -Path $setting.Path -Name $setting.Name -Value $setting.Value | Out-Null
    }

    Write-Log -Message "Cortana disabled" -Level "SUCCESS" -Component "Stage2"
}

function Disable-SuggestedContent {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would disable suggested content" -Level "INFO" -Component "Stage2"
        return
    }

    $settings = @(
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SilentInstalledAppsEnabled"; Value = 0 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SystemPaneSuggestionsEnabled"; Value = 0 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SoftLandingEnabled"; Value = 0 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "RotatingLockScreenEnabled"; Value = 0 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "RotatingLockScreenOverlayEnabled"; Value = 0 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-310093Enabled"; Value = 0 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-338388Enabled"; Value = 0 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-338389Enabled"; Value = 0 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-338393Enabled"; Value = 0 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-353694Enabled"; Value = 0 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-353696Enabled"; Value = 0 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "OemPreInstalledAppsEnabled"; Value = 0 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "PreInstalledAppsEnabled"; Value = 0 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "PreInstalledAppsEverEnabled"; Value = 0 }
    )

    foreach ($setting in $settings) {
        Set-RegistryValue -Path $setting.Path -Name $setting.Name -Value $setting.Value | Out-Null
    }

    Write-Log -Message "Suggested content and tips disabled" -Level "SUCCESS" -Component "Stage2"
}

function Disable-ConsumerFeatures {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would disable consumer features" -Level "INFO" -Component "Stage2"
        return
    }

    # Disable consumer features (prevents automatic app installs)
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -Value 1
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableSoftLanding" -Value 1
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableCloudOptimizedContent" -Value 1

    # Disable app suggestions
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableTailoredExperiencesWithDiagnosticData" -Value 1

    Write-Log -Message "Consumer features disabled" -Level "SUCCESS" -Component "Stage2"
}

function Clear-StartMenuTiles {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would clean Start Menu tiles" -Level "INFO" -Component "Stage2"
        return
    }

    try {
        # Remove promoted tiles / ads in Start
        Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338388Enabled" -Value 0
        Set-RegistryValue -Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "DisableNotificationCenter" -Value 0
        Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_TrackDocs" -Value 0

        Write-Log -Message "Start Menu tiles cleaned" -Level "SUCCESS" -Component "Stage2"
    }
    catch {
        Write-Log -Message "Error cleaning Start Menu: $_" -Level "WARN" -Component "Stage2"
    }
}

Export-ModuleMember -Function Invoke-Stage2

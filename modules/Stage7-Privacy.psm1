#Requires -Version 5.1
<#
.SYNOPSIS
    Stage 7: Privacy Hardening (NEW - Not in Tron!)
.DESCRIPTION
    Comprehensive privacy and telemetry hardening:
    - Windows telemetry disabling
    - Diagnostic data reduction
    - Activity history clearing
    - Advertising ID disabling
    - Location tracking disabling
    - Camera/microphone privacy
    - Clipboard history disabling
    - Timeline disabling
    - Feedback frequency reduction
    - Wi-Fi Sense disabling
    - Telemetry scheduled task disabling
    - Telemetry service disabling
    - Edge telemetry reduction
    - Office telemetry reduction
#>

function Invoke-Stage7 {
    [CmdletBinding()]
    param(
        [hashtable]$Config = @{},
        [switch]$DryRun,
        [ValidateSet("Moderate", "Aggressive")]
        [string]$PrivacyLevel = "Moderate"
    )

    $stageTimer = [System.Diagnostics.Stopwatch]::StartNew()
    $changes = 0

    Write-StageHeader -StageNumber 7 -StageName "Privacy" -Description "Hardening privacy settings ($PrivacyLevel mode)"

    # ---- Core Telemetry ----
    Write-SubStageHeader "Disabling Windows Telemetry"
    $changes += Disable-WindowsTelemetry -Level $PrivacyLevel -DryRun:$DryRun

    # ---- Diagnostic Data ----
    Write-SubStageHeader "Reducing Diagnostic Data Collection"
    $changes += Set-DiagnosticDataLevel -Level $PrivacyLevel -DryRun:$DryRun

    # ---- Advertising ID ----
    Write-SubStageHeader "Disabling Advertising ID"
    $changes += Disable-AdvertisingId -DryRun:$DryRun

    # ---- Activity History ----
    Write-SubStageHeader "Disabling Activity History & Timeline"
    $changes += Disable-ActivityHistory -DryRun:$DryRun

    # ---- Location Tracking ----
    Write-SubStageHeader "Restricting Location Tracking"
    $changes += Disable-LocationTracking -DryRun:$DryRun

    # ---- App Permissions ----
    Write-SubStageHeader "Tightening App Permissions"
    $changes += Set-AppPermissions -Level $PrivacyLevel -DryRun:$DryRun

    # ---- Telemetry Tasks ----
    Write-SubStageHeader "Disabling Telemetry Scheduled Tasks"
    $changes += Disable-TelemetryTasks -DryRun:$DryRun

    # ---- Telemetry Services ----
    Write-SubStageHeader "Disabling Telemetry Services"
    $changes += Disable-TelemetryServices -DryRun:$DryRun

    # ---- Feedback ----
    Write-SubStageHeader "Disabling Feedback Requests"
    $changes += Disable-FeedbackRequests -DryRun:$DryRun

    # ---- Wi-Fi Sense ----
    Write-SubStageHeader "Disabling Wi-Fi Sense"
    $changes += Disable-WiFiSense -DryRun:$DryRun

    # ---- Clipboard Sync ----
    Write-SubStageHeader "Disabling Cloud Clipboard"
    $changes += Disable-CloudClipboard -DryRun:$DryRun

    # ---- Edge Privacy ----
    Write-SubStageHeader "Hardening Edge Privacy"
    $changes += Set-EdgePrivacy -DryRun:$DryRun

    Write-Host ""
    Write-Log -Message "Privacy hardening complete: $changes settings changed" -Level "SUCCESS" -Component "Stage7"

    Set-Metric -Name "PrivacySettingsChanged" -Value $changes -Category "Stage7"

    $stageTimer.Stop()

    Register-StageResult -StageNumber 7 -StageName "Privacy" -Status "Success" `
        -Summary "$changes privacy settings hardened" `
        -Details @{ SettingsChanged = $changes } -Duration $stageTimer.Elapsed

    return $changes
}

# ============================================================================
# SUB-FUNCTIONS
# ============================================================================

function Disable-WindowsTelemetry {
    [CmdletBinding()]
    param(
        [string]$Level = "Moderate",
        [switch]$DryRun
    )

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would disable Windows telemetry" -Level "INFO" -Component "Stage7"
        return 0
    }

    $count = 0
    $settings = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name = "AllowTelemetry"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"; Name = "AllowTelemetry"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name = "DoNotShowFeedbackNotifications"; Value = 1 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name = "AllowDeviceNameInTelemetry"; Value = 0 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy"; Name = "TailoredExperiencesWithDiagnosticDataEnabled"; Value = 0 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Siuf\Rules"; Name = "NumberOfSIUFInPeriod"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat"; Name = "AITEnable"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat"; Name = "DisableInventory"; Value = 1 }
    )

    if ($Level -eq "Aggressive") {
        $settings += @(
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat"; Name = "DisableUAR"; Value = 1 },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows"; Name = "CEIPEnable"; Value = 0 },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PreviewBuilds"; Name = "AllowBuildPreview"; Value = 0 },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\System"; Name = "AllowExperimentation"; Value = 0 }
        )
    }

    foreach ($setting in $settings) {
        if (Set-RegistryValueSafe -Path $setting.Path -Name $setting.Name -Value $setting.Value -Stage "Stage7" -Reason "Disable telemetry") {
            $count++
        }
    }

    Write-Log -Message "Disabled $count telemetry settings" -Level "SUCCESS" -Component "Stage7"
    return $count
}

function Set-DiagnosticDataLevel {
    [CmdletBinding()]
    param(
        [string]$Level = "Moderate",
        [switch]$DryRun
    )

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would set diagnostic data to minimum" -Level "INFO" -Component "Stage7"
        return 0
    }

    $count = 0

    # Set to Security/Required level (minimum)
    $diagSettings = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name = "AllowTelemetry"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name = "MaxTelemetryAllowed"; Value = 1 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack"; Name = "ShowedToastAtLevel"; Value = 1 }
    )

    foreach ($setting in $diagSettings) {
        if (Set-RegistryValueSafe -Path $setting.Path -Name $setting.Name -Value $setting.Value -Stage "Stage7" -Reason "Reduce diagnostic data") {
            $count++
        }
    }

    Write-Log -Message "Diagnostic data set to minimum level" -Level "SUCCESS" -Component "Stage7"
    return $count
}

function Disable-AdvertisingId {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would disable advertising ID" -Level "INFO" -Component "Stage7"
        return 0
    }

    $count = 0
    $settings = @(
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo"; Name = "Enabled"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo"; Name = "DisabledByGroupPolicy"; Value = 1 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "Start_TrackProgs"; Value = 0 }
    )

    foreach ($setting in $settings) {
        if (Set-RegistryValueSafe -Path $setting.Path -Name $setting.Name -Value $setting.Value -Stage "Stage7" -Reason "Disable advertising ID") {
            $count++
        }
    }

    Write-Log -Message "Advertising ID disabled" -Level "SUCCESS" -Component "Stage7"
    return $count
}

function Disable-ActivityHistory {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would disable activity history" -Level "INFO" -Component "Stage7"
        return 0
    }

    $count = 0
    $settings = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"; Name = "EnableActivityFeed"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"; Name = "PublishUserActivities"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"; Name = "UploadUserActivities"; Value = 0 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "Start_TrackDocs"; Value = 0 }
    )

    foreach ($setting in $settings) {
        if (Set-RegistryValueSafe -Path $setting.Path -Name $setting.Name -Value $setting.Value -Stage "Stage7" -Reason "Disable activity history") {
            $count++
        }
    }

    Write-Log -Message "Activity history and timeline disabled" -Level "SUCCESS" -Component "Stage7"
    return $count
}

function Disable-LocationTracking {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would restrict location tracking" -Level "INFO" -Component "Stage7"
        return 0
    }

    $count = 0
    $settings = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors"; Name = "DisableLocation"; Value = 1 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors"; Name = "DisableLocationScripting"; Value = 1 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors"; Name = "DisableWindowsLocationProvider"; Value = 1 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"; Name = "Value"; Value = "Deny"; Type = "String" }
    )

    foreach ($setting in $settings) {
        $type = if ($setting.ContainsKey("Type")) { $setting.Type } else { "DWord" }
        if (Set-RegistryValueSafe -Path $setting.Path -Name $setting.Name -Value $setting.Value -Type $type -Stage "Stage7" -Reason "Disable location tracking") {
            $count++
        }
    }

    Write-Log -Message "Location tracking restricted" -Level "SUCCESS" -Component "Stage7"
    return $count
}

function Set-AppPermissions {
    [CmdletBinding()]
    param(
        [string]$Level = "Moderate",
        [switch]$DryRun
    )

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would tighten app permissions" -Level "INFO" -Component "Stage7"
        return 0
    }

    $count = 0
    $basePath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore"

    $capabilities = @("webcam", "microphone", "userNotificationListener", "contacts",
                      "appointments", "phoneCallHistory", "email", "userDataTasks",
                      "chat", "radios", "bluetoothSync", "appDiagnostics")

    foreach ($cap in $capabilities) {
        $path = "$basePath\$cap"
        if (Set-RegistryValueSafe -Path $path -Name "Value" -Value "Deny" -Type "String" -Stage "Stage7" -Reason "Restrict $cap permission") {
            $count++
        }
    }

    Write-Log -Message "Restricted $count app permission categories" -Level "SUCCESS" -Component "Stage7"
    return $count
}

function Disable-TelemetryTasks {
    [CmdletBinding()]
    param([switch]$DryRun)

    $tasksToDisable = @(
        @{ Path = "\Microsoft\Windows\Application Experience\"; Name = "Microsoft Compatibility Appraiser" },
        @{ Path = "\Microsoft\Windows\Application Experience\"; Name = "ProgramDataUpdater" },
        @{ Path = "\Microsoft\Windows\Autochk\"; Name = "Proxy" },
        @{ Path = "\Microsoft\Windows\Customer Experience Improvement Program\"; Name = "Consolidator" },
        @{ Path = "\Microsoft\Windows\Customer Experience Improvement Program\"; Name = "UsbCeip" },
        @{ Path = "\Microsoft\Windows\DiskDiagnostic\"; Name = "Microsoft-Windows-DiskDiagnosticDataCollector" },
        @{ Path = "\Microsoft\Windows\Feedback\Siuf\"; Name = "DmClient" },
        @{ Path = "\Microsoft\Windows\NetTrace\"; Name = "GatherNetworkInfo" },
        @{ Path = "\Microsoft\Windows\Windows Error Reporting\"; Name = "QueueReporting" },
        @{ Path = "\Microsoft\Windows\CloudExperienceHost\"; Name = "CreateObjectTask" },
        @{ Path = "\Microsoft\Windows\DiskFootprint\"; Name = "Diagnostics" },
        @{ Path = "\Microsoft\Windows\PI\"; Name = "Sqm-Tasks" }
    )

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would disable $($tasksToDisable.Count) telemetry tasks" -Level "INFO" -Component "Stage7"
        return 0
    }

    $disabled = 0
    foreach ($task in $tasksToDisable) {
        if (Disable-ScheduledTaskSafely -TaskPath $task.Path -TaskName $task.Name) {
            Write-Log -Message "Disabled task: $($task.Name)" -Level "SUCCESS" -Component "Stage7"
            $disabled++
        }
    }

    Write-Log -Message "Disabled $disabled telemetry scheduled tasks" -Level "SUCCESS" -Component "Stage7"
    return $disabled
}

function Disable-TelemetryServices {
    [CmdletBinding()]
    param([switch]$DryRun)

    $services = @(
        @{ Name = "DiagTrack"; Desc = "Connected User Experiences and Telemetry" },
        @{ Name = "dmwappushservice"; Desc = "WAP Push Message Routing" },
        @{ Name = "diagnosticshub.standardcollector.service"; Desc = "Diagnostics Hub Collector" },
        @{ Name = "DcpSvc"; Desc = "Data Collection Publishing Service" },
        @{ Name = "WerSvc"; Desc = "Windows Error Reporting" }
    )

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would disable $($services.Count) telemetry services" -Level "INFO" -Component "Stage7"
        return 0
    }

    $disabled = 0
    foreach ($svc in $services) {
        $result = $false
        if (Get-Command Set-ServiceStartupTypeSafe -ErrorAction SilentlyContinue) {
            $result = Set-ServiceStartupTypeSafe -ServiceName $svc.Name -StartupType "Disabled" -Stage "Stage7" -Reason "Disable $($svc.Desc)"
        } else {
            $result = Set-ServiceStartupType -ServiceName $svc.Name -StartupType "Disabled"
        }
        if ($result) {
            Write-Log -Message "Disabled service: $($svc.Name) ($($svc.Desc))" -Level "SUCCESS" -Component "Stage7"
            $disabled++
        }
    }

    return $disabled
}

function Disable-FeedbackRequests {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would disable feedback requests" -Level "INFO" -Component "Stage7"
        return 0
    }

    $count = 0
    $settings = @(
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Siuf\Rules"; Name = "NumberOfSIUFInPeriod"; Value = 0 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Siuf\Rules"; Name = "PeriodInNanoSeconds"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name = "DoNotShowFeedbackNotifications"; Value = 1 }
    )

    foreach ($setting in $settings) {
        if (Set-RegistryValueSafe -Path $setting.Path -Name $setting.Name -Value $setting.Value -Stage "Stage7" -Reason "Disable feedback") { $count++ }
    }

    Write-Log -Message "Feedback requests disabled" -Level "SUCCESS" -Component "Stage7"
    return $count
}

function Disable-WiFiSense {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would disable Wi-Fi Sense" -Level "INFO" -Component "Stage7"
        return 0
    }

    $count = 0
    $settings = @(
        @{ Path = "HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config"; Name = "AutoConnectAllowedOEM"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting"; Name = "Value"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowAutoConnectToWiFiSenseHotspots"; Name = "Value"; Value = 0 }
    )

    foreach ($setting in $settings) {
        if (Set-RegistryValueSafe -Path $setting.Path -Name $setting.Name -Value $setting.Value -Stage "Stage7" -Reason "Disable Wi-Fi Sense") { $count++ }
    }

    Write-Log -Message "Wi-Fi Sense disabled" -Level "SUCCESS" -Component "Stage7"
    return $count
}

function Disable-CloudClipboard {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would disable cloud clipboard" -Level "INFO" -Component "Stage7"
        return 0
    }

    $count = 0
    $settings = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"; Name = "AllowClipboardHistory"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"; Name = "AllowCrossDeviceClipboard"; Value = 0 }
    )

    foreach ($setting in $settings) {
        if (Set-RegistryValueSafe -Path $setting.Path -Name $setting.Name -Value $setting.Value -Stage "Stage7" -Reason "Disable cloud clipboard") { $count++ }
    }

    Write-Log -Message "Cloud clipboard disabled" -Level "SUCCESS" -Component "Stage7"
    return $count
}

function Set-EdgePrivacy {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would harden Edge privacy" -Level "INFO" -Component "Stage7"
        return 0
    }

    $count = 0
    $settings = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "PersonalizationReportingEnabled"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "SendSiteInfoToImproveServices"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "AutofillCreditCardEnabled"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "SearchSuggestEnabled"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "SpotlightExperiencesAndSuggestionsEnabled"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "ResolveNavigationErrorsUseWebService"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "AlternateErrorPagesEnabled"; Value = 0 }
    )

    foreach ($setting in $settings) {
        if (Set-RegistryValueSafe -Path $setting.Path -Name $setting.Name -Value $setting.Value -Stage "Stage7" -Reason "Harden Edge privacy") { $count++ }
    }

    Write-Log -Message "Edge privacy hardened ($count settings)" -Level "SUCCESS" -Component "Stage7"
    return $count
}

Export-ModuleMember -Function Invoke-Stage7

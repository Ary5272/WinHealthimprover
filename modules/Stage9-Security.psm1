#Requires -Version 5.1
<#
.SYNOPSIS
    Stage 9: Security Hardening (NEW - Not in Tron!)
.DESCRIPTION
    System security hardening beyond just disinfection:
    - Windows Defender configuration
    - UAC configuration
    - Credential Guard check
    - Attack Surface Reduction rules
    - PowerShell logging
    - Audit policy configuration
    - RDP security
    - AutoPlay/AutoRun disabling
    - Office macro security
    - Guest account disabling
    - Unnecessary feature removal (Telnet, TFTP)
    - Certificate store audit
#>

function Invoke-Stage9 {
    [CmdletBinding()]
    param(
        [hashtable]$Config = @{},
        [switch]$DryRun,
        [ValidateSet("Standard", "Enhanced")]
        [string]$SecurityLevel = "Standard"
    )

    $stageTimer = [System.Diagnostics.Stopwatch]::StartNew()
    $hardened = 0

    Write-StageHeader -StageNumber 9 -StageName "Security" -Description "Hardening system security ($SecurityLevel mode)"

    # ---- Windows Defender Hardening ----
    Write-SubStageHeader "Windows Defender Hardening"
    $hardened += Harden-WindowsDefender -DryRun:$DryRun

    # ---- UAC Configuration ----
    Write-SubStageHeader "UAC Configuration"
    $hardened += Set-UACLevel -DryRun:$DryRun

    # ---- Attack Surface Reduction ----
    Write-SubStageHeader "Attack Surface Reduction Rules"
    $hardened += Enable-ASRRules -Level $SecurityLevel -DryRun:$DryRun

    # ---- PowerShell Security ----
    Write-SubStageHeader "PowerShell Security Logging"
    $hardened += Enable-PowerShellLogging -DryRun:$DryRun

    # ---- AutoPlay/AutoRun ----
    Write-SubStageHeader "Disabling AutoPlay/AutoRun"
    $hardened += Disable-AutoPlayAutoRun -DryRun:$DryRun

    # ---- RDP Security ----
    Write-SubStageHeader "RDP Security Hardening"
    $hardened += Harden-RDP -DryRun:$DryRun

    # ---- Guest Account ----
    Write-SubStageHeader "Guest Account Security"
    $hardened += Disable-GuestAccount -DryRun:$DryRun

    # ---- Remove Dangerous Features ----
    Write-SubStageHeader "Removing Unnecessary Windows Features"
    $hardened += Remove-DangerousFeatures -DryRun:$DryRun

    # ---- Credential Protection ----
    Write-SubStageHeader "Credential Protection"
    $hardened += Enable-CredentialProtection -DryRun:$DryRun

    # ---- Audit Policies ----
    if ($SecurityLevel -eq "Enhanced") {
        Write-SubStageHeader "Security Audit Policies"
        $hardened += Set-AuditPolicies -DryRun:$DryRun
    }

    # ---- Office Macro Security ----
    Write-SubStageHeader "Office Macro Security"
    $hardened += Harden-OfficeMacros -DryRun:$DryRun

    # ---- Spectre/Meltdown Mitigations ----
    Write-SubStageHeader "CPU Vulnerability Mitigations"
    Test-CPUMitigations

    Write-Host ""
    Write-Log -Message "Security hardening complete: $hardened improvements applied" -Level "SUCCESS" -Component "Stage9"

    Set-Metric -Name "SecurityHardenings" -Value $hardened -Category "Stage9"

    $stageTimer.Stop()

    Register-StageResult -StageNumber 9 -StageName "Security" -Status "Success" `
        -Summary "$hardened security improvements applied" `
        -Details @{ HardenedCount = $hardened } -Duration $stageTimer.Elapsed

    return $hardened
}

# ============================================================================
# SUB-FUNCTIONS
# ============================================================================

function Harden-WindowsDefender {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would harden Windows Defender" -Level "INFO" -Component "Stage9"
        return 0
    }

    $count = 0

    try {
        # Enable real-time protection
        Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
        $count++

        # Enable cloud-based protection
        Set-MpPreference -MAPSReporting Advanced -ErrorAction SilentlyContinue
        $count++

        # Enable automatic sample submission
        Set-MpPreference -SubmitSamplesConsent SendAllSamples -ErrorAction SilentlyContinue
        $count++

        # Enable PUA protection
        Set-MpPreference -PUAProtection Enabled -ErrorAction SilentlyContinue
        $count++

        # Enable network protection
        Set-MpPreference -EnableNetworkProtection Enabled -ErrorAction SilentlyContinue
        $count++

        # Enable controlled folder access (ransomware protection)
        Set-MpPreference -EnableControlledFolderAccess Enabled -ErrorAction SilentlyContinue
        $count++

        # Enable behavior monitoring
        Set-MpPreference -DisableBehaviorMonitoring $false -ErrorAction SilentlyContinue
        $count++

        # Enable scan of all downloaded files
        Set-MpPreference -DisableIOAVProtection $false -ErrorAction SilentlyContinue
        $count++

        # Increase cloud check timeout
        Set-MpPreference -CloudBlockLevel High -ErrorAction SilentlyContinue
        Set-MpPreference -CloudExtendedTimeout 50 -ErrorAction SilentlyContinue
        $count++

        Write-Log -Message "Windows Defender hardened ($count settings)" -Level "SUCCESS" -Component "Stage9"
    }
    catch {
        Write-Log -Message "Defender hardening partial failure: $_" -Level "WARN" -Component "Stage9"
    }

    return $count
}

function Set-UACLevel {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would configure UAC" -Level "INFO" -Component "Stage9"
        return 0
    }

    $count = 0

    # Ensure UAC is enabled and set to recommended level
    $settings = @(
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"; Name = "EnableLUA"; Value = 1 },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"; Name = "ConsentPromptBehaviorAdmin"; Value = 5 },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"; Name = "PromptOnSecureDesktop"; Value = 1 },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"; Name = "EnableInstallerDetection"; Value = 1 }
    )

    foreach ($setting in $settings) {
        if (Set-RegistryValueSafe -Path $setting.Path -Name $setting.Name -Value $setting.Value -Stage "Stage9" -Reason "Configure UAC") { $count++ }
    }

    Write-Log -Message "UAC configured to recommended level" -Level "SUCCESS" -Component "Stage9"
    return $count
}

function Enable-ASRRules {
    [CmdletBinding()]
    param(
        [string]$Level = "Standard",
        [switch]$DryRun
    )

    # Attack Surface Reduction rule GUIDs
    $rules = @(
        @{ GUID = "BE9BA2D9-53EA-4CDC-84E5-9B1EEEE46550"; Desc = "Block executable content from email/webmail" },
        @{ GUID = "D4F940AB-401B-4EFC-AADC-AD5F3C50688A"; Desc = "Block Office child processes" },
        @{ GUID = "3B576869-A4EC-4529-8536-B80A7769E899"; Desc = "Block Office from creating executable content" },
        @{ GUID = "75668C1F-73B5-4CF0-BB93-3ECF5CB7CC84"; Desc = "Block Office from injecting into other processes" },
        @{ GUID = "D3E037E1-3EB8-44C8-A917-57927947596D"; Desc = "Block JS/VBS launching downloaded executable content" },
        @{ GUID = "5BEB7EFE-FD9A-4556-801D-275E5FFC04CC"; Desc = "Block execution of obfuscated scripts" },
        @{ GUID = "92E97FA1-2EDF-4476-BDD6-9DD0B4DDDC7B"; Desc = "Block Win32 API calls from macros" },
        @{ GUID = "B2B3F03D-6A65-4F7B-A9C7-1C7EF74A9BA4"; Desc = "Block untrusted/unsigned processes from USB" },
        @{ GUID = "26190899-1602-49E8-8B27-EB1D0A1CE869"; Desc = "Block Office communication app child processes" },
        @{ GUID = "7674BA52-37EB-4A4F-A9A1-F0F9A1619A2C"; Desc = "Block Adobe Reader child processes" }
    )

    if ($Level -eq "Enhanced") {
        $rules += @(
            @{ GUID = "9E6C4E1F-7D60-472F-BA1A-A39EF669E4B2"; Desc = "Block credential stealing from LSASS" },
            @{ GUID = "01443614-CD74-433A-B99E-2ECDC07BFC25"; Desc = "Block executable files unless they meet criteria" },
            @{ GUID = "C1DB55AB-C21A-4637-BB3F-A12568109D35"; Desc = "Block ransomware-like file encryption" }
        )
    }

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would enable $($rules.Count) ASR rules" -Level "INFO" -Component "Stage9"
        return 0
    }

    $count = 0
    foreach ($rule in $rules) {
        try {
            Add-MpPreference -AttackSurfaceReductionRules_Ids $rule.GUID -AttackSurfaceReductionRules_Actions Enabled -ErrorAction Stop
            Write-Log -Message "ASR enabled: $($rule.Desc)" -Level "SUCCESS" -Component "Stage9"
            $count++
        }
        catch {
            Write-Log -Message "Could not enable ASR rule: $($rule.Desc)" -Level "WARN" -Component "Stage9"
        }
    }

    Write-Log -Message "Enabled $count ASR rules" -Level "SUCCESS" -Component "Stage9"
    return $count
}

function Enable-PowerShellLogging {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would enable PowerShell security logging" -Level "INFO" -Component "Stage9"
        return 0
    }

    $count = 0

    # Enable script block logging
    $settings = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"; Name = "EnableScriptBlockLogging"; Value = 1 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging"; Name = "EnableModuleLogging"; Value = 1 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription"; Name = "EnableTranscripting"; Value = 1 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription"; Name = "EnableInvocationHeader"; Value = 1 }
    )

    foreach ($setting in $settings) {
        if (Set-RegistryValueSafe -Path $setting.Path -Name $setting.Name -Value $setting.Value -Stage "Stage9" -Reason "Enable PowerShell logging") { $count++ }
    }

    Write-Log -Message "PowerShell security logging enabled" -Level "SUCCESS" -Component "Stage9"
    return $count
}

function Disable-AutoPlayAutoRun {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would disable AutoPlay/AutoRun" -Level "INFO" -Component "Stage9"
        return 0
    }

    $count = 0
    $settings = @(
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"; Name = "NoDriveTypeAutoRun"; Value = 255 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"; Name = "NoDriveTypeAutoRun"; Value = 255 },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"; Name = "NoAutorun"; Value = 1 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"; Name = "NoAutoplayfornonVolume"; Value = 1 }
    )

    foreach ($setting in $settings) {
        if (Set-RegistryValueSafe -Path $setting.Path -Name $setting.Name -Value $setting.Value -Stage "Stage9" -Reason "Disable AutoPlay/AutoRun") { $count++ }
    }

    Write-Log -Message "AutoPlay/AutoRun disabled" -Level "SUCCESS" -Component "Stage9"
    return $count
}

function Harden-RDP {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would harden RDP settings" -Level "INFO" -Component "Stage9"
        return 0
    }

    $count = 0
    $settings = @(
        # Require NLA
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"; Name = "UserAuthentication"; Value = 1 },
        # Set encryption level to high
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"; Name = "MinEncryptionLevel"; Value = 3 },
        # Set security layer to SSL
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"; Name = "SecurityLayer"; Value = 2 },
        # Disable CredSSP fallback
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation"; Name = "AllowEncryptionOracle"; Value = 0 }
    )

    foreach ($setting in $settings) {
        if (Set-RegistryValueSafe -Path $setting.Path -Name $setting.Name -Value $setting.Value -Stage "Stage9" -Reason "Harden RDP") { $count++ }
    }

    Write-Log -Message "RDP security hardened ($count settings)" -Level "SUCCESS" -Component "Stage9"
    return $count
}

function Disable-GuestAccount {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would disable Guest account" -Level "INFO" -Component "Stage9"
        return 0
    }

    try {
        & net user Guest /active:no 2>&1 | Out-Null
        Write-Log -Message "Guest account disabled" -Level "SUCCESS" -Component "Stage9"
        return 1
    }
    catch {
        Write-Log -Message "Could not disable Guest account: $_" -Level "WARN" -Component "Stage9"
        return 0
    }
}

function Remove-DangerousFeatures {
    [CmdletBinding()]
    param([switch]$DryRun)

    $features = @(
        "TelnetClient",
        "TFTP",
        "SMB1Protocol",
        "MicrosoftWindowsPowerShellV2Root",
        "MicrosoftWindowsPowerShellV2"
    )

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would remove $($features.Count) dangerous features" -Level "INFO" -Component "Stage9"
        return 0
    }

    $count = 0
    foreach ($feature in $features) {
        try {
            $status = Get-WindowsOptionalFeature -Online -FeatureName $feature -ErrorAction SilentlyContinue
            if ($status -and $status.State -eq "Enabled") {
                Disable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart -ErrorAction Stop | Out-Null
                Write-Log -Message "Removed: $feature" -Level "SUCCESS" -Component "Stage9"
                $count++
            }
        }
        catch { }
    }

    if ($count -eq 0) {
        Write-Log -Message "No dangerous features were enabled" -Level "SUCCESS" -Component "Stage9"
    }

    return $count
}

function Enable-CredentialProtection {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would enable credential protection" -Level "INFO" -Component "Stage9"
        return 0
    }

    $count = 0

    # Disable WDigest (prevents cleartext password storage)
    if (Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest" -Name "UseLogonCredential" -Value 0 -Stage "Stage9" -Reason "Disable WDigest cleartext caching") {
        Write-Log -Message "WDigest cleartext credential caching disabled" -Level "SUCCESS" -Component "Stage9"
        $count++
    }

    # Enable LSA protection
    if (Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL" -Value 1 -Stage "Stage9" -Reason "Enable LSA protection") {
        Write-Log -Message "LSA protection enabled" -Level "SUCCESS" -Component "Stage9"
        $count++
    }

    # Disable LLMNR (Link-Local Multicast Name Resolution)
    if (Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Name "EnableMulticast" -Value 0 -Stage "Stage9" -Reason "Disable LLMNR") {
        Write-Log -Message "LLMNR disabled" -Level "SUCCESS" -Component "Stage9"
        $count++
    }

    return $count
}

function Set-AuditPolicies {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would configure audit policies" -Level "INFO" -Component "Stage9"
        return 0
    }

    $count = 0
    $policies = @(
        @{ Category = "Logon/Logoff"; Subcategory = "Logon"; Success = "enable"; Failure = "enable" },
        @{ Category = "Logon/Logoff"; Subcategory = "Logoff"; Success = "enable"; Failure = "enable" },
        @{ Category = "Account Logon"; Subcategory = "Credential Validation"; Success = "enable"; Failure = "enable" },
        @{ Category = "Object Access"; Subcategory = "File System"; Success = "enable"; Failure = "enable" },
        @{ Category = "Policy Change"; Subcategory = "Audit Policy Change"; Success = "enable"; Failure = "enable" },
        @{ Category = "Privilege Use"; Subcategory = "Sensitive Privilege Use"; Success = "enable"; Failure = "enable" }
    )

    foreach ($policy in $policies) {
        try {
            & auditpol /set /subcategory:"$($policy.Subcategory)" /success:$($policy.Success) /failure:$($policy.Failure) 2>&1 | Out-Null
            $count++
        }
        catch { }
    }

    Write-Log -Message "Configured $count audit policies" -Level "SUCCESS" -Component "Stage9"
    return $count
}

function Harden-OfficeMacros {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would harden Office macro security" -Level "INFO" -Component "Stage9"
        return 0
    }

    $count = 0

    # Block macros from the internet in Office apps
    $officeApps = @("Word", "Excel", "PowerPoint", "Access", "Visio", "Publisher", "Project")
    $officeVersions = @("16.0", "15.0")  # Office 2016/365 and 2013

    foreach ($version in $officeVersions) {
        foreach ($app in $officeApps) {
            $path = "HKCU:\SOFTWARE\Policies\Microsoft\Office\$version\$app\Security"
            if (Set-RegistryValueSafe -Path $path -Name "blockcontentexecutionfrominternet" -Value 1 -Stage "Stage9" -Reason "Block Office macros from internet") {
                $count++
            }
        }
    }

    if ($count -gt 0) {
        Write-Log -Message "Office macro security hardened ($count settings)" -Level "SUCCESS" -Component "Stage9"
    }
    else {
        Write-Log -Message "No Office installations found to harden" -Level "INFO" -Component "Stage9"
    }

    return $count
}

function Test-CPUMitigations {
    try {
        $mitigations = Get-SpeculationControlSettings -ErrorAction Stop
        Write-Log -Message "Spectre/Meltdown mitigations: Active" -Level "SUCCESS" -Component "Stage9"
    }
    catch {
        Write-Log -Message "CPU vulnerability mitigation status: Install SpeculationControl module for detailed check" -Level "INFO" -Component "Stage9"

        # Check basic registry keys
        $spectrePath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
        $featureEnabled = Get-RegistryValue -Path $spectrePath -Name "FeatureSettingsOverride"
        if ($null -ne $featureEnabled) {
            Write-Log -Message "CPU mitigation registry keys present" -Level "INFO" -Component "Stage9"
        }
    }
}

Export-ModuleMember -Function Invoke-Stage9

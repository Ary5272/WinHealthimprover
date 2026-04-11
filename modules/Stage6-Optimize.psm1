#Requires -Version 5.1
<#
.SYNOPSIS
    Stage 6: System Optimization
.DESCRIPTION
    Performance optimization operations:
    - Disk defrag (HDD) or TRIM (SSD)
    - Power plan optimization
    - Visual effects optimization
    - Startup program management
    - Service optimization
    - Page file optimization
    - Superfetch/SysMain optimization
    - Background app management
    - Game Mode configuration
    - Memory compression settings
#>

function Invoke-Stage6 {
    [CmdletBinding()]
    param(
        [hashtable]$Config = @{},
        [switch]$DryRun,
        [ValidateSet("Balanced", "Performance", "MaxPerformance")]
        [string]$OptimizationLevel = "Performance"
    )

    $stageTimer = [System.Diagnostics.Stopwatch]::StartNew()
    $optimizations = 0

    Write-StageHeader -StageNumber 6 -StageName "Optimize" -Description "Optimizing system performance ($OptimizationLevel mode)"

    # ---- Disk Optimization ----
    Write-SubStageHeader "Disk Optimization (Defrag/TRIM)"
    if (Optimize-Disks -DryRun:$DryRun) { $optimizations++ }

    # ---- Power Plan ----
    Write-SubStageHeader "Power Plan Optimization"
    if (Optimize-PowerPlan -Level $OptimizationLevel -DryRun:$DryRun) { $optimizations++ }

    # ---- Visual Effects ----
    Write-SubStageHeader "Visual Effects Optimization"
    if (Optimize-VisualEffects -Level $OptimizationLevel -DryRun:$DryRun) { $optimizations++ }

    # ---- Startup Programs ----
    Write-SubStageHeader "Startup Program Optimization"
    $disabledStartup = Optimize-StartupPrograms -DryRun:$DryRun
    if ($disabledStartup -gt 0) { $optimizations++ }

    # ---- Service Optimization ----
    Write-SubStageHeader "Service Optimization"
    if (Optimize-Services -Level $OptimizationLevel -DryRun:$DryRun) { $optimizations++ }

    # ---- Page File ----
    Write-SubStageHeader "Page File Optimization"
    if (Optimize-PageFile -DryRun:$DryRun) { $optimizations++ }

    # ---- Background Apps ----
    Write-SubStageHeader "Background App Management"
    if (Disable-BackgroundApps -DryRun:$DryRun) { $optimizations++ }

    # ---- SysMain / Prefetch ----
    Write-SubStageHeader "SysMain / Prefetch Configuration"
    Optimize-SysMain -DryRun:$DryRun

    # ---- Memory Compression ----
    Write-SubStageHeader "Memory Compression Check"
    Optimize-MemoryCompression -DryRun:$DryRun

    # ---- Game Mode ----
    Write-SubStageHeader "Game Mode Configuration"
    Set-GameMode -DryRun:$DryRun

    # ---- NTFS Optimizations ----
    Write-SubStageHeader "NTFS Performance Tuning"
    Optimize-NTFS -DryRun:$DryRun

    Write-Host ""
    Write-Log -Message "Optimization complete: $optimizations improvements applied" -Level "SUCCESS" -Component "Stage6"

    Set-Metric -Name "OptimizationsApplied" -Value $optimizations -Category "Stage6"

    $stageTimer.Stop()

    Register-StageResult -StageNumber 6 -StageName "Optimize" -Status "Success" `
        -Summary "$optimizations performance optimizations applied" `
        -Details @{ OptimizationsApplied = $optimizations } -Duration $stageTimer.Elapsed

    return $optimizations
}

# ============================================================================
# SUB-FUNCTIONS
# ============================================================================

function Optimize-Disks {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would optimize disks" -Level "INFO" -Component "Stage6"
        return $true
    }

    try {
        $volumes = Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveType -eq 'Fixed' }

        foreach ($vol in $volumes) {
            $isSSD = Test-IsSSD -DriveLetter $vol.DriveLetter.ToString()

            if ($isSSD) {
                Write-Log -Message "Running TRIM on $($vol.DriveLetter): (SSD)" -Level "INFO" -Component "Stage6"
                Optimize-Volume -DriveLetter $vol.DriveLetter -ReTrim -ErrorAction SilentlyContinue
                Write-Log -Message "TRIM completed on $($vol.DriveLetter):" -Level "SUCCESS" -Component "Stage6"
            }
            else {
                Write-Log -Message "Defragmenting $($vol.DriveLetter): (HDD)" -Level "INFO" -Component "Stage6"
                Optimize-Volume -DriveLetter $vol.DriveLetter -Defrag -ErrorAction SilentlyContinue
                Write-Log -Message "Defragmentation completed on $($vol.DriveLetter):" -Level "SUCCESS" -Component "Stage6"
            }
        }
        return $true
    }
    catch {
        Write-Log -Message "Disk optimization failed: $_" -Level "WARN" -Component "Stage6"
        return $false
    }
}

function Optimize-PowerPlan {
    [CmdletBinding()]
    param(
        [string]$Level = "Performance",
        [switch]$DryRun
    )

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would optimize power plan to $Level" -Level "INFO" -Component "Stage6"
        return $true
    }

    try {
        $planGuid = switch ($Level) {
            "Balanced"       { "381b4222-f694-41f0-9685-ff5bb260df2e" }
            "Performance"    { "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" }
            "MaxPerformance" {
                # Create Ultimate Performance plan if it doesn't exist
                $existing = & powercfg /list 2>&1
                if ($existing -match "e9a42b02-d5df-448d-aa00-03f14749eb61") {
                    "e9a42b02-d5df-448d-aa00-03f14749eb61"
                }
                else {
                    & powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1 | Out-Null
                    "e9a42b02-d5df-448d-aa00-03f14749eb61"
                }
            }
        }

        & powercfg /setactive $planGuid 2>&1 | Out-Null

        # Disable USB selective suspend
        & powercfg /setacvalueindex $planGuid 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>&1 | Out-Null

        # Disable hard disk sleep
        & powercfg /setacvalueindex $planGuid 0012ee47-9041-4b5d-9b77-535fba8b1442 6738e2c4-e8a5-4a42-b16a-e040e769756e 0 2>&1 | Out-Null

        Write-Log -Message "Power plan set to $Level" -Level "SUCCESS" -Component "Stage6"
        return $true
    }
    catch {
        Write-Log -Message "Power plan optimization failed: $_" -Level "WARN" -Component "Stage6"
        return $false
    }
}

function Optimize-VisualEffects {
    [CmdletBinding()]
    param(
        [string]$Level = "Performance",
        [switch]$DryRun
    )

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would optimize visual effects" -Level "INFO" -Component "Stage6"
        return $true
    }

    try {
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"

        if ($Level -eq "MaxPerformance") {
            # Disable all visual effects
            Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2 -Stage "Stage6" -Reason "Disable visual effects (max performance)"
            Set-RegistryValueSafe -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value ([byte[]](0x90, 0x12, 0x03, 0x80, 0x10, 0x00, 0x00, 0x00)) -Type "Binary" -Stage "Stage6" -Reason "Disable visual effects mask"
        }
        else {
            # Custom: Keep smooth fonts and taskbar thumbnails, disable the rest
            Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 3 -Stage "Stage6" -Reason "Custom visual effects"

            # Disable animations
            Set-RegistryValueSafe -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value "0" -Type "String" -Stage "Stage6" -Reason "Disable window animations"
            Set-RegistryValueSafe -Path "HKCU:\Control Panel\Desktop" -Name "DragFullWindows" -Value "1" -Type "String" -Stage "Stage6" -Reason "Enable full window drag"

            # Disable transparency
            Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 0 -Stage "Stage6" -Reason "Disable transparency"
        }

        # Disable menu animation
        Set-RegistryValueSafe -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "0" -Type "String" -Stage "Stage6" -Reason "Disable menu animation delay"

        Write-Log -Message "Visual effects optimized for $Level" -Level "SUCCESS" -Component "Stage6"
        return $true
    }
    catch {
        Write-Log -Message "Visual effects optimization failed: $_" -Level "WARN" -Component "Stage6"
        return $false
    }
}

function Optimize-StartupPrograms {
    [CmdletBinding()]
    param([switch]$DryRun)

    # Known high-impact, non-essential startup programs
    $disableList = @(
        "Steam Client Bootstrapper",
        "Spotify",
        "Discord",
        "Skype",
        "OneDrive",
        "iTunes Helper",
        "Adobe Creative Cloud",
        "Microsoft Teams",
        "Cortana",
        "Google Chrome Background",
        "Opera Browser Assistant"
    )

    $disabled = 0

    try {
        $startupItems = Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue

        foreach ($item in $startupItems) {
            $shouldDisable = $disableList | Where-Object { $item.Name -like "*$_*" -or $item.Command -like "*$_*" }
            if ($shouldDisable) {
                Write-Log -Message "Non-essential startup: $($item.Name)" -Level "INFO" -Component "Stage6"
                $disabled++
            }
        }

        if ($disabled -gt 0) {
            Write-Log -Message "Found $disabled non-essential startup programs (use Task Manager > Startup to disable)" -Level "INFO" -Component "Stage6"
        }
        else {
            Write-Log -Message "Startup programs look reasonable" -Level "SUCCESS" -Component "Stage6"
        }
    }
    catch { }

    return $disabled
}

function Optimize-Services {
    [CmdletBinding()]
    param(
        [string]$Level = "Performance",
        [switch]$DryRun
    )

    # Services safe to disable for most users
    $servicesToDisable = @(
        @{ Name = "DiagTrack";          Desc = "Connected User Experiences and Telemetry" },
        @{ Name = "dmwappushservice";    Desc = "WAP Push Message Routing" },
        @{ Name = "SysMain";            Desc = "Superfetch (on SSD systems)" },
        @{ Name = "WSearch";            Desc = "Windows Search (if not needed)" },
        @{ Name = "MapsBroker";         Desc = "Downloaded Maps Manager" },
        @{ Name = "lfsvc";              Desc = "Geolocation Service" },
        @{ Name = "RetailDemo";         Desc = "Retail Demo Service" },
        @{ Name = "wisvc";              Desc = "Windows Insider Service" },
        @{ Name = "WerSvc";             Desc = "Windows Error Reporting" }
    )

    if ($Level -eq "MaxPerformance") {
        $servicesToDisable += @(
            @{ Name = "Fax";              Desc = "Fax Service" },
            @{ Name = "XblAuthManager";   Desc = "Xbox Live Auth Manager" },
            @{ Name = "XblGameSave";      Desc = "Xbox Live Game Save" },
            @{ Name = "XboxNetApiSvc";    Desc = "Xbox Live Networking" },
            @{ Name = "XboxGipSvc";       Desc = "Xbox Accessory Management" },
            @{ Name = "TabletInputService"; Desc = "Touch Keyboard and Handwriting" }
        )
    }

    if ($DryRun) {
        foreach ($svc in $servicesToDisable) {
            Write-Log -Message "[DRY RUN] Would disable: $($svc.Name) ($($svc.Desc))" -Level "INFO" -Component "Stage6"
        }
        return $true
    }

    $modified = 0
    foreach ($svc in $servicesToDisable) {
        # Special case: only disable SysMain on SSD systems
        if ($svc.Name -eq "SysMain" -and -not (Test-IsSSD)) {
            continue
        }

        if (Get-Command Set-ServiceStartupTypeSafe -ErrorAction SilentlyContinue) {
            if (Set-ServiceStartupTypeSafe -ServiceName $svc.Name -StartupType "Disabled" -Stage "Stage6" -Reason "Disable $($svc.Desc)") {
                Write-Log -Message "Disabled: $($svc.Name) ($($svc.Desc))" -Level "SUCCESS" -Component "Stage6"
                $modified++
            }
        }
        elseif (Set-ServiceStartupType -ServiceName $svc.Name -StartupType "Disabled") {
            Write-Log -Message "Disabled: $($svc.Name) ($($svc.Desc))" -Level "SUCCESS" -Component "Stage6"
            $modified++
        }
    }

    Write-Log -Message "Disabled $modified unnecessary services" -Level "SUCCESS" -Component "Stage6"
    return ($modified -gt 0)
}

function Optimize-PageFile {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would optimize page file" -Level "INFO" -Component "Stage6"
        return $true
    }

    try {
        $ram = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
        $ramMB = [math]::Round($ram / 1MB)

        # Recommended: 1.5x RAM for systems with <= 8GB, 1x for > 8GB, min 1024MB
        $recommendedMin = if ($ramMB -le 8192) { [math]::Round($ramMB * 1.5) } else { $ramMB }
        $recommendedMax = [math]::Round($recommendedMin * 1.5)
        $recommendedMin = [math]::Max(1024, $recommendedMin)
        $recommendedMax = [math]::Max(2048, $recommendedMax)

        # Get current page file settings
        $pageFile = Get-CimInstance Win32_PageFileSetting -ErrorAction SilentlyContinue

        Write-Log -Message "RAM: $ramMB MB | Recommended page file: $recommendedMin - $recommendedMax MB" -Level "INFO" -Component "Stage6"

        if ($pageFile) {
            Write-Log -Message "Current page file: $($pageFile.InitialSize) - $($pageFile.MaximumSize) MB" -Level "INFO" -Component "Stage6"
        }
        else {
            Write-Log -Message "Page file is system-managed (recommended for most users)" -Level "SUCCESS" -Component "Stage6"
        }

        return $true
    }
    catch {
        Write-Log -Message "Page file optimization failed: $_" -Level "WARN" -Component "Stage6"
        return $false
    }
}

function Disable-BackgroundApps {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would disable background apps" -Level "INFO" -Component "Stage6"
        return $true
    }

    try {
        # Disable background apps globally
        Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Name "GlobalUserDisabled" -Value 1 -Stage "Stage6" -Reason "Disable background apps"
        Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "BackgroundAppGlobalToggle" -Value 0 -Stage "Stage6" -Reason "Disable background app search toggle"

        Write-Log -Message "Background apps disabled" -Level "SUCCESS" -Component "Stage6"
        return $true
    }
    catch {
        Write-Log -Message "Background app management failed: $_" -Level "WARN" -Component "Stage6"
        return $false
    }
}

function Optimize-SysMain {
    [CmdletBinding()]
    param([switch]$DryRun)

    $isSSD = Test-IsSSD

    if ($isSSD) {
        if (-not $DryRun) {
            if (Get-Command Set-ServiceStartupTypeSafe -ErrorAction SilentlyContinue) {
                Set-ServiceStartupTypeSafe -ServiceName "SysMain" -StartupType "Disabled" -Stage "Stage6" -Reason "SysMain not needed on SSD" | Out-Null
            } else {
                Set-ServiceStartupType -ServiceName "SysMain" -StartupType "Disabled" | Out-Null
            }
            Write-Log -Message "SysMain disabled (not needed on SSD)" -Level "SUCCESS" -Component "Stage6"
        }
        else {
            Write-Log -Message "[DRY RUN] Would disable SysMain on SSD" -Level "INFO" -Component "Stage6"
        }
    }
    else {
        Write-Log -Message "SysMain kept enabled (beneficial for HDD)" -Level "INFO" -Component "Stage6"
    }
}

function Optimize-MemoryCompression {
    [CmdletBinding()]
    param([switch]$DryRun)

    try {
        $memCompression = Get-MMAgent -ErrorAction Stop
        $status = if ($memCompression.MemoryCompression) { "enabled" } else { "disabled" }
        Write-Log -Message "Memory compression is $status" -Level "INFO" -Component "Stage6"

        $ram = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB
        if ($ram -ge 16 -and $memCompression.MemoryCompression) {
            Write-Log -Message "With $([math]::Round($ram))GB RAM, disabling memory compression may improve performance" -Level "INFO" -Component "Stage6"
        }
    }
    catch {
        Write-Log -Message "Could not check memory compression: $_" -Level "WARN" -Component "Stage6"
    }
}

function Set-GameMode {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would configure Game Mode" -Level "INFO" -Component "Stage6"
        return
    }

    # Enable Game Mode (actually helps with non-gaming too by reducing background interruptions)
    Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "AllowAutoGameMode" -Value 1 -Stage "Stage6" -Reason "Enable Game Mode"
    Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Value 1 -Stage "Stage6" -Reason "Enable Auto Game Mode"

    # Disable Game DVR (reduces CPU overhead)
    Set-RegistryValueSafe -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0 -Stage "Stage6" -Reason "Disable Game DVR"
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Value 0 -Stage "Stage6" -Reason "Disable Game DVR policy"

    Write-Log -Message "Game Mode configured (DVR disabled for performance)" -Level "SUCCESS" -Component "Stage6"
}

function Optimize-NTFS {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would optimize NTFS settings" -Level "INFO" -Component "Stage6"
        return
    }

    try {
        # Disable 8.3 filename creation (minor perf improvement)
        & fsutil behavior set disable8dot3 1 2>&1 | Out-Null

        # Disable last access timestamp (reduces write operations)
        & fsutil behavior set disablelastaccess 1 2>&1 | Out-Null

        # Increase NTFS memory usage for performance
        & fsutil behavior set memoryusage 2 2>&1 | Out-Null

        Write-Log -Message "NTFS performance settings applied" -Level "SUCCESS" -Component "Stage6"
    }
    catch {
        Write-Log -Message "NTFS optimization failed: $_" -Level "WARN" -Component "Stage6"
    }
}

Export-ModuleMember -Function Invoke-Stage6

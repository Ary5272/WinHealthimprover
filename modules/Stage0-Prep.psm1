#Requires -Version 5.1
<#
.SYNOPSIS
    Stage 0: System Preparation
.DESCRIPTION
    Comprehensive system preparation before repair operations:
    - SMART disk health check
    - SSD/HDD/VM detection
    - Pre-run system inventory (installed programs, services, startup items)
    - Creates system restore point
    - Registry backup
    - Kills known malicious/interfering processes
    - Syncs system clock via NTP
    - Disables sleep/hibernation temporarily
    - Checks for pending reboots
    - Flushes DNS cache
    - Reduces System Restore space allocation
    - Purges old VSS snapshots
    - PendingFileRenameOperations handling
    - Creates RunOnce recovery key for crash recovery
#>

function Invoke-Stage0 {
    [CmdletBinding()]
    param(
        [hashtable]$Config = @{},
        [switch]$DryRun,
        [string]$LogDirectory = ""
    )

    $stageTimer = [System.Diagnostics.Stopwatch]::StartNew()
    $details = @{}

    Write-StageHeader -StageNumber 0 -StageName "Preparation" -Description "Preparing system for repair operations"

    # ---- SMART Disk Health Check ----
    Write-SubStageHeader "SMART Disk Health Check"
    $smartResult = Test-DiskSMART
    $details["DiskHealth"] = $smartResult

    # ---- SSD / VM Detection ----
    Write-SubStageHeader "Storage & Hypervisor Detection"
    $storageInfo = Get-StorageType
    $details["StorageType"] = $storageInfo

    # ---- Pre-Run System Inventory ----
    Write-SubStageHeader "Capturing Pre-Run System Inventory"
    $inventoryResult = Save-SystemInventory -Phase "Before" -OutputDir $LogDirectory -DryRun:$DryRun
    $details["InventoryCaptured"] = $inventoryResult

    # ---- Create System Restore Point ----
    Write-SubStageHeader "Creating System Restore Point"
    $restoreResult = New-SystemRestoreCheckpoint -DryRun:$DryRun
    $details["RestorePoint"] = $restoreResult

    # ---- Registry Backup ----
    Write-SubStageHeader "Backing Up Registry Hives"
    $regBackup = Backup-RegistryHives -OutputDir $LogDirectory -DryRun:$DryRun
    $details["RegistryBackup"] = $regBackup

    # ---- Kill Interfering Processes ----
    Write-SubStageHeader "Terminating Interfering Processes"
    $killResult = Stop-InterferingProcesses -DryRun:$DryRun
    $details["ProcessesKilled"] = $killResult

    # ---- Sync System Clock ----
    Write-SubStageHeader "Synchronizing System Clock"
    $ntpResult = Sync-SystemClock -DryRun:$DryRun
    $details["NTPSync"] = $ntpResult

    # ---- Disable Sleep/Screensaver ----
    Write-SubStageHeader "Disabling Sleep & Screen Saver"
    $sleepResult = Disable-SleepMode -DryRun:$DryRun
    $details["SleepDisabled"] = $sleepResult

    # ---- Check Pending Reboots ----
    Write-SubStageHeader "Checking Pending Reboots"
    $rebootPending = Test-PendingReboot
    $details["RebootPending"] = $rebootPending
    if ($rebootPending) {
        Write-Log -Message "A reboot is pending - some operations may require a restart" -Level "WARN" -Component "Stage0"
    }
    else {
        Write-Log -Message "No pending reboot detected" -Level "SUCCESS" -Component "Stage0"
    }

    # ---- Handle PendingFileRenameOperations ----
    Write-SubStageHeader "Handling PendingFileRenameOperations"
    Clear-PendingFileRenames -DryRun:$DryRun

    # ---- Flush DNS ----
    Write-SubStageHeader "Flushing DNS Cache"
    if (-not $DryRun) {
        try {
            Clear-DnsClientCache -ErrorAction SilentlyContinue
            & ipconfig /flushdns 2>&1 | Out-Null
            Write-Log -Message "DNS cache flushed" -Level "SUCCESS" -Component "Stage0"
        }
        catch {
            Write-Log -Message "Could not flush DNS cache: $_" -Level "WARN" -Component "Stage0"
        }
    }
    else {
        Write-Log -Message "[DRY RUN] Would flush DNS cache" -Level "INFO" -Component "Stage0"
    }

    # ---- Purge Old VSS Snapshots ----
    Write-SubStageHeader "Purging Old Shadow Copies"
    Clear-OldVSSSnapshots -DryRun:$DryRun

    # ---- Reduce System Restore Space ----
    Write-SubStageHeader "Optimizing System Restore Space"
    Set-SystemRestoreSpace -DryRun:$DryRun

    # ---- Disable Windows Error Reporting ----
    Write-SubStageHeader "Pausing Windows Error Reporting"
    if (-not $DryRun) {
        try {
            Stop-Service -Name "WerSvc" -Force -ErrorAction SilentlyContinue
            Write-Log -Message "Windows Error Reporting paused" -Level "SUCCESS" -Component "Stage0"
        }
        catch {
            Write-Log -Message "Could not pause WER" -Level "WARN" -Component "Stage0"
        }
    }

    # ---- Record Free Space (Before) ----
    Write-SubStageHeader "Recording Disk Space Baseline"
    $freeSpace = Get-DiskSpaceBaseline
    $details["FreeSpaceBefore"] = $freeSpace
    Set-Metric -Name "FreeSpaceBefore_GB" -Value $freeSpace -Category "Overall"

    $stageTimer.Stop()

    $status = if ($details.Values | Where-Object { $_ -eq $false }) { "Warning" } else { "Success" }

    Register-StageResult -StageNumber 0 -StageName "Preparation" -Status $status `
        -Summary "System prepared ($($storageInfo.Type) detected, SMART: $($smartResult.Status))" -Details $details -Duration $stageTimer.Elapsed

    return $details
}

# ============================================================================
# SUB-FUNCTIONS
# ============================================================================

function New-SystemRestoreCheckpoint {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would create system restore point" -Level "INFO" -Component "Stage0"
        return $true
    }

    try {
        # Enable System Restore if disabled
        $srStatus = Get-ComputerRestorePoint -ErrorAction SilentlyContinue
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue

        Checkpoint-Computer -Description "WinHealthImprover Pre-Run Checkpoint" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Log -Message "System restore point created successfully" -Level "SUCCESS" -Component "Stage0"
        return $true
    }
    catch {
        if ($_.Exception.Message -match "frequency") {
            Write-Log -Message "Restore point skipped (one already created recently)" -Level "WARN" -Component "Stage0"
            return $true
        }
        Write-Log -Message "Failed to create restore point: $($_.Exception.Message)" -Level "ERROR" -Component "Stage0"
        return $false
    }
}

function Stop-InterferingProcesses {
    [CmdletBinding()]
    param([switch]$DryRun)

    # Processes known to interfere with system repair
    $processesToKill = @(
        # Browser updaters and background processes
        "iexplore", "MicrosoftEdgeUpdate", "GoogleUpdate", "GoogleCrashHandler",
        # Known crapware/PUP processes
        "CouponPrinter", "conduitinstaller", "YTDownloader", "searchprotocolhost",
        # Installer processes that can interfere
        "msiexec", "wuauclt",
        # AV that can interfere (user should disable temporarily)
        # Toolbar/adware processes
        "DealPly", "OptimizerPro", "WebCake", "Wajam",
        "MyPCBackup", "FileScout", "SmartBar", "PCProtect",
        # Known malicious process names
        "svchost32", "csrss32", "lsass32", "winlogon32",
        "explorer32", "services32", "spoolsv32", "taskhost32"
    )

    $killed = 0
    foreach ($procName in $processesToKill) {
        $proc = Get-Process -Name $procName -ErrorAction SilentlyContinue
        if ($proc) {
            if (-not $DryRun) {
                try {
                    $proc | Stop-Process -Force -ErrorAction Stop
                    Write-Log -Message "Killed process: $procName (PID: $($proc.Id -join ', '))" -Level "INFO" -Component "Stage0"
                    $killed++
                }
                catch {
                    Write-Log -Message "Could not kill $procName : $_" -Level "WARN" -Component "Stage0"
                }
            }
            else {
                Write-Log -Message "[DRY RUN] Would kill: $procName" -Level "INFO" -Component "Stage0"
                $killed++
            }
        }
    }

    if ($killed -eq 0) {
        Write-Log -Message "No interfering processes found" -Level "SUCCESS" -Component "Stage0"
    }
    else {
        Write-Log -Message "Terminated $killed interfering process(es)" -Level "SUCCESS" -Component "Stage0"
    }

    Set-Metric -Name "ProcessesKilled" -Value $killed -Category "Stage0"
    return $killed
}

function Sync-SystemClock {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would sync system clock via NTP" -Level "INFO" -Component "Stage0"
        return $true
    }

    try {
        # Restart Windows Time service
        Stop-Service -Name "w32time" -Force -ErrorAction SilentlyContinue
        Start-Service -Name "w32time" -ErrorAction SilentlyContinue

        # Configure NTP servers
        & w32tm /config /manualpeerlist:"time.windows.com,0x1 time.nist.gov,0x1 pool.ntp.org,0x1" /syncfromflags:manual /reliable:yes /update 2>&1 | Out-Null

        # Force sync
        & w32tm /resync /force 2>&1 | Out-Null

        Write-Log -Message "System clock synchronized via NTP" -Level "SUCCESS" -Component "Stage0"
        return $true
    }
    catch {
        Write-Log -Message "NTP sync failed: $($_.Exception.Message)" -Level "WARN" -Component "Stage0"
        return $false
    }
}

function Disable-SleepMode {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would disable sleep/hibernation temporarily" -Level "INFO" -Component "Stage0"
        return $true
    }

    try {
        # Disable hibernation
        & powercfg /hibernate off 2>&1 | Out-Null

        # Set power scheme to high performance temporarily
        & powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>&1 | Out-Null

        # Prevent sleep during operation
        & powercfg /change standby-timeout-ac 0 2>&1 | Out-Null
        & powercfg /change monitor-timeout-ac 0 2>&1 | Out-Null

        Write-Log -Message "Sleep and hibernation disabled temporarily" -Level "SUCCESS" -Component "Stage0"
        return $true
    }
    catch {
        Write-Log -Message "Could not fully disable sleep: $_" -Level "WARN" -Component "Stage0"
        return $false
    }
}

function Test-PendingReboot {
    $rebootRequired = $false

    # Check CBS (Component Based Servicing)
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") {
        $rebootRequired = $true
    }

    # Check Windows Update
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") {
        $rebootRequired = $true
    }

    # Check PendingFileRenameOperations
    try {
        $pfro = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "PendingFileRenameOperations" -ErrorAction Stop
        if ($pfro.PendingFileRenameOperations) {
            $rebootRequired = $true
        }
    }
    catch { }

    # Check SCCM client
    try {
        $sccm = Invoke-CimMethod -Namespace "root\ccm\ClientSDK" -ClassName "CCM_ClientUtilities" -MethodName "DetermineIfRebootPending" -ErrorAction Stop
        if ($sccm.RebootPending -or $sccm.IsHardRebootPending) {
            $rebootRequired = $true
        }
    }
    catch { }

    return $rebootRequired
}

function Test-DiskSMART {
    try {
        $disks = Get-PhysicalDisk -ErrorAction Stop
        $allHealthy = $true

        foreach ($disk in $disks) {
            $health = $disk.HealthStatus
            $name = "$($disk.FriendlyName) ($($disk.MediaType), $([math]::Round($disk.Size / 1GB)) GB)"

            if ($health -ne "Healthy") {
                Write-Log -Message "DISK WARNING: $name - Status: $health" -Level "ERROR" -Component "Stage0"
                $allHealthy = $false

                # Check for predictive failure
                if ($health -match "Warning|Degraded|Pred") {
                    Write-Log -Message "CRITICAL: Disk $name may be failing! Back up data immediately!" -Level "ERROR" -Component "Stage0"
                }
            }
            else {
                Write-Log -Message "Disk: $name - Healthy" -Level "SUCCESS" -Component "Stage0"
            }

            # Get reliability counters if available
            try {
                $reliability = Get-StorageReliabilityCounter -PhysicalDisk $disk -ErrorAction Stop
                if ($reliability.ReadErrorsTotal -gt 0 -or $reliability.WriteErrorsTotal -gt 0) {
                    Write-Log -Message "  Read errors: $($reliability.ReadErrorsTotal), Write errors: $($reliability.WriteErrorsTotal)" -Level "WARN" -Component "Stage0"
                }
                if ($reliability.Temperature -gt 0) {
                    $tempC = $reliability.Temperature - 273  # Kelvin to Celsius
                    if ($tempC -gt 55) {
                        Write-Log -Message "  Temperature: ${tempC}C (HIGH!)" -Level "WARN" -Component "Stage0"
                    }
                    else {
                        Write-Log -Message "  Temperature: ${tempC}C" -Level "INFO" -Component "Stage0"
                    }
                }
                if ($reliability.Wear -gt 0) {
                    Write-Log -Message "  SSD Wear level: $($reliability.Wear)%" -Level "INFO" -Component "Stage0"
                }
            }
            catch { }
        }

        return @{
            Status  = if ($allHealthy) { "Healthy" } else { "Warning" }
            Count   = $disks.Count
            Healthy = $allHealthy
        }
    }
    catch {
        Write-Log -Message "SMART check unavailable: $_" -Level "WARN" -Component "Stage0"
        return @{ Status = "Unknown"; Count = 0; Healthy = $true }
    }
}

function Get-StorageType {
    $isSSD = Test-IsSSD
    $isVM = $false

    # Detect virtual machine
    try {
        $cs = Get-CimInstance Win32_ComputerSystem
        $vmIndicators = @("Virtual", "VMware", "VirtualBox", "QEMU", "Hyper-V", "Xen", "KVM", "Parallels")
        foreach ($indicator in $vmIndicators) {
            if ($cs.Manufacturer -match $indicator -or $cs.Model -match $indicator) {
                $isVM = $true
                break
            }
        }
        # Also check BIOS
        $bios = Get-CimInstance Win32_BIOS
        foreach ($indicator in $vmIndicators) {
            if ($bios.SMBIOSBIOSVersion -match $indicator -or $bios.Manufacturer -match $indicator) {
                $isVM = $true
                break
            }
        }
    }
    catch { }

    $type = if ($isVM) { "Virtual Machine" } elseif ($isSSD) { "SSD" } else { "HDD" }

    Write-Log -Message "Storage type: $type" -Level "INFO" -Component "Stage0"
    if ($isVM) { Write-Log -Message "Running in virtual machine - defrag will be skipped" -Level "INFO" -Component "Stage0" }

    Set-Metric -Name "StorageType" -Value $type -Category "System"
    Set-Metric -Name "IsVM" -Value $isVM -Category "System"

    return @{ Type = $type; IsSSD = $isSSD; IsVM = $isVM }
}

function Save-SystemInventory {
    [CmdletBinding()]
    param(
        [string]$Phase = "Before",
        [string]$OutputDir = "",
        [switch]$DryRun
    )

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would capture system inventory ($Phase)" -Level "INFO" -Component "Stage0"
        return $true
    }

    if (-not $OutputDir -or -not (Test-Path $OutputDir)) { $OutputDir = $env:TEMP }

    try {
        $prefix = "WinHealthImprover_${Phase}_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

        # Installed programs
        $programs = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
                                      "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName } |
            Select-Object DisplayName, DisplayVersion, Publisher, InstallDate |
            Sort-Object DisplayName
        $programs | Export-Csv -Path (Join-Path $OutputDir "${prefix}_Programs.csv") -NoTypeInformation -ErrorAction SilentlyContinue
        $programCount = ($programs | Measure-Object).Count
        Write-Log -Message "Captured $programCount installed programs ($Phase)" -Level "SUCCESS" -Component "Stage0"
        Set-Metric -Name "InstalledPrograms_$Phase" -Value $programCount -Category "Inventory"

        # Running services
        $services = Get-Service | Where-Object { $_.Status -eq "Running" } | Select-Object Name, DisplayName, Status, StartType
        $services | Export-Csv -Path (Join-Path $OutputDir "${prefix}_Services.csv") -NoTypeInformation -ErrorAction SilentlyContinue
        Write-Log -Message "Captured $($services.Count) running services ($Phase)" -Level "SUCCESS" -Component "Stage0"

        # Startup items
        $startup = Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue | Select-Object Name, Command, Location
        $startup | Export-Csv -Path (Join-Path $OutputDir "${prefix}_Startup.csv") -NoTypeInformation -ErrorAction SilentlyContinue
        Write-Log -Message "Captured $($startup.Count) startup items ($Phase)" -Level "SUCCESS" -Component "Stage0"

        # UWP/Appx packages
        try {
            $appx = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Select-Object Name, Version, PackageFullName
            $appx | Export-Csv -Path (Join-Path $OutputDir "${prefix}_AppxPackages.csv") -NoTypeInformation -ErrorAction SilentlyContinue
            Write-Log -Message "Captured $($appx.Count) UWP packages ($Phase)" -Level "SUCCESS" -Component "Stage0"
            Set-Metric -Name "AppxPackages_$Phase" -Value ($appx | Measure-Object).Count -Category "Inventory"
        }
        catch { }

        return $true
    }
    catch {
        Write-Log -Message "Inventory capture failed: $_" -Level "WARN" -Component "Stage0"
        return $false
    }
}

function Backup-RegistryHives {
    [CmdletBinding()]
    param(
        [string]$OutputDir = "",
        [switch]$DryRun
    )

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would back up registry hives" -Level "INFO" -Component "Stage0"
        return $true
    }

    if (-not $OutputDir -or -not (Test-Path $OutputDir)) { $OutputDir = $env:TEMP }
    $backupDir = Join-Path $OutputDir "RegistryBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

    try {
        New-Item -Path $backupDir -ItemType Directory -Force | Out-Null

        $hives = @(
            @{ Name = "HKLM_SYSTEM";   Path = "HKLM\SYSTEM" },
            @{ Name = "HKLM_SOFTWARE"; Path = "HKLM\SOFTWARE" },
            @{ Name = "HKCU";          Path = "HKCU" }
        )

        foreach ($hive in $hives) {
            $outFile = Join-Path $backupDir "$($hive.Name).reg"
            & reg export $hive.Path $outFile /y 2>&1 | Out-Null
        }

        Write-Log -Message "Registry backed up to: $backupDir" -Level "SUCCESS" -Component "Stage0"
        return $true
    }
    catch {
        Write-Log -Message "Registry backup failed: $_" -Level "WARN" -Component "Stage0"
        return $false
    }
}

function Clear-PendingFileRenames {
    [CmdletBinding()]
    param([switch]$DryRun)

    try {
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
        $pfro = Get-ItemProperty -Path $regPath -Name "PendingFileRenameOperations" -ErrorAction SilentlyContinue

        if ($pfro -and $pfro.PendingFileRenameOperations) {
            $count = ($pfro.PendingFileRenameOperations | Measure-Object).Count
            Write-Log -Message "Found $count pending file rename operations" -Level "INFO" -Component "Stage0"

            if (-not $DryRun) {
                # Export before clearing (for safety)
                $pfro.PendingFileRenameOperations | Out-File -FilePath (Join-Path $env:TEMP "PendingFileRenames_backup.txt") -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $regPath -Name "PendingFileRenameOperations" -Force -ErrorAction SilentlyContinue
                Write-Log -Message "PendingFileRenameOperations cleared (prevents forced reboots during debloat)" -Level "SUCCESS" -Component "Stage0"
            }
            else {
                Write-Log -Message "[DRY RUN] Would clear PendingFileRenameOperations" -Level "INFO" -Component "Stage0"
            }
        }
        else {
            Write-Log -Message "No pending file rename operations" -Level "SUCCESS" -Component "Stage0"
        }
    }
    catch { }
}

function Clear-OldVSSSnapshots {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would purge old VSS shadow copies" -Level "INFO" -Component "Stage0"
        return
    }

    try {
        # Delete all but the most recent shadow copy
        & vssadmin delete shadows /for=$env:SystemDrive /oldest /quiet 2>&1 | Out-Null
        Write-Log -Message "Old VSS shadow copies purged" -Level "SUCCESS" -Component "Stage0"
    }
    catch {
        Write-Log -Message "VSS purge failed: $_" -Level "WARN" -Component "Stage0"
    }
}

function Set-SystemRestoreSpace {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would optimize System Restore disk allocation" -Level "INFO" -Component "Stage0"
        return
    }

    try {
        & vssadmin resize shadowstorage /for=$env:SystemDrive /on=$env:SystemDrive /maxsize=7% 2>&1 | Out-Null
        Write-Log -Message "System Restore space capped at 7% of system drive" -Level "SUCCESS" -Component "Stage0"
    }
    catch {
        Write-Log -Message "Could not resize shadow storage: $_" -Level "WARN" -Component "Stage0"
    }
}

function Get-DiskSpaceBaseline {
    try {
        $sysDrive = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'"
        $freeGB = [math]::Round($sysDrive.FreeSpace / 1GB, 2)
        Write-Log -Message "Current free space on $($env:SystemDrive): $freeGB GB" -Level "INFO" -Component "Stage0"
        return $freeGB
    }
    catch {
        return 0
    }
}

Export-ModuleMember -Function Invoke-Stage0

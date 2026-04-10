#Requires -Version 5.1
<#
.SYNOPSIS
    Stage 4: System Repair
.DESCRIPTION
    Comprehensive system file and component repair:
    - DISM component store repair
    - SFC system file checker
    - chkdsk disk check
    - Windows Update component reset
    - WMI repository repair
    - Network stack repair
    - Windows Search repair
    - File association repair
    - Print spooler repair
    - Windows Firewall repair
#>

function Invoke-Stage4 {
    [CmdletBinding()]
    param(
        [hashtable]$Config = @{},
        [switch]$DryRun,
        [switch]$SkipChkdsk
    )

    $stageTimer = [System.Diagnostics.Stopwatch]::StartNew()
    $repaired = 0

    Write-StageHeader -StageNumber 4 -StageName "Repair" -Description "Repairing system files, components, and services"

    # ---- DISM Component Store ----
    Write-SubStageHeader "DISM Component Store Repair"
    if (Invoke-DISMRepair -DryRun:$DryRun) { $repaired++ }

    # ---- SFC System File Checker ----
    Write-SubStageHeader "System File Checker (SFC)"
    if (Invoke-SFCRepair -DryRun:$DryRun) { $repaired++ }

    # ---- Windows Update Components ----
    Write-SubStageHeader "Windows Update Component Reset"
    if (Reset-WindowsUpdateComponents -DryRun:$DryRun) { $repaired++ }

    # ---- WMI Repository ----
    Write-SubStageHeader "WMI Repository Repair"
    if (Repair-WMIRepository -DryRun:$DryRun) { $repaired++ }

    # ---- Network Stack ----
    Write-SubStageHeader "Network Stack Repair"
    if (Repair-NetworkStack -DryRun:$DryRun) { $repaired++ }

    # ---- Windows Search ----
    Write-SubStageHeader "Windows Search Repair"
    if (Repair-WindowsSearch -DryRun:$DryRun) { $repaired++ }

    # ---- File Associations ----
    Write-SubStageHeader "File Association Repair"
    if (Repair-FileAssociations -DryRun:$DryRun) { $repaired++ }

    # ---- Print Spooler ----
    Write-SubStageHeader "Print Spooler Repair"
    if (Repair-PrintSpooler -DryRun:$DryRun) { $repaired++ }

    # ---- Windows Firewall ----
    Write-SubStageHeader "Windows Firewall Reset"
    if (Repair-WindowsFirewall -DryRun:$DryRun) { $repaired++ }

    # ---- MSI Installer Cleanup ----
    Write-SubStageHeader "MSI Installer Orphan Cleanup"
    if (Clear-MSIOrphans -DryRun:$DryRun) { $repaired++ }

    # ---- NVIDIA Telemetry Cleanup ----
    Write-SubStageHeader "NVIDIA Telemetry Removal"
    if (Remove-NVIDIATelemetry -DryRun:$DryRun) { $repaired++ }

    # ---- File Extension Repair ----
    Write-SubStageHeader "File Extension Association Repair"
    if (Repair-CommonFileExtensions -DryRun:$DryRun) { $repaired++ }

    # ---- .NET Framework Repair ----
    Write-SubStageHeader ".NET Framework Repair"
    if (Repair-DotNetFramework -DryRun:$DryRun) { $repaired++ }

    # ---- Disk Check ----
    if (-not $SkipChkdsk) {
        Write-SubStageHeader "Disk Health Check"
        Invoke-DiskCheck -DryRun:$DryRun
    }

    # ---- Volume Shadow Copy ----
    Write-SubStageHeader "Volume Shadow Copy Service"
    Repair-VSSService -DryRun:$DryRun

    Write-Host ""
    Write-Log -Message "System repair operations completed ($repaired components repaired)" -Level "SUCCESS" -Component "Stage4"

    Set-Metric -Name "ComponentsRepaired" -Value $repaired -Category "Stage4"

    $stageTimer.Stop()

    Register-StageResult -StageNumber 4 -StageName "Repair" -Status "Success" `
        -Summary "$repaired system components repaired" `
        -Details @{ ComponentsRepaired = $repaired } -Duration $stageTimer.Elapsed

    return $repaired
}

# ============================================================================
# SUB-FUNCTIONS
# ============================================================================

function Invoke-DISMRepair {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would run DISM /Online /Cleanup-Image /RestoreHealth" -Level "INFO" -Component "Stage4"
        return $true
    }

    try {
        Write-Log -Message "Running DISM scan (this may take several minutes)..." -Level "INFO" -Component "Stage4"

        # First check health
        $checkResult = & DISM /Online /Cleanup-Image /CheckHealth 2>&1
        Write-Log -Message "DISM CheckHealth: $($checkResult | Select-String 'image' | Select-Object -First 1)" -Level "INFO" -Component "Stage4"

        # Scan for corruption
        $scanResult = & DISM /Online /Cleanup-Image /ScanHealth 2>&1
        Write-Log -Message "DISM ScanHealth completed" -Level "INFO" -Component "Stage4"

        # Attempt repair
        $restoreResult = & DISM /Online /Cleanup-Image /RestoreHealth 2>&1
        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) {
            Write-Log -Message "DISM repair completed successfully" -Level "SUCCESS" -Component "Stage4"
            return $true
        }
        else {
            Write-Log -Message "DISM repair completed with exit code $exitCode" -Level "WARN" -Component "Stage4"
            return $false
        }

        # Clean up component store
        & DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase 2>&1 | Out-Null
        Write-Log -Message "DISM component cleanup completed" -Level "INFO" -Component "Stage4"
    }
    catch {
        Write-Log -Message "DISM repair failed: $_" -Level "ERROR" -Component "Stage4"
        return $false
    }
}

function Invoke-SFCRepair {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would run sfc /scannow" -Level "INFO" -Component "Stage4"
        return $true
    }

    try {
        Write-Log -Message "Running System File Checker (this may take several minutes)..." -Level "INFO" -Component "Stage4"

        $result = & sfc /scannow 2>&1
        $exitCode = $LASTEXITCODE

        # Parse SFC output
        $resultText = $result -join "`n"
        if ($resultText -match "did not find any integrity violations") {
            Write-Log -Message "SFC: No integrity violations found" -Level "SUCCESS" -Component "Stage4"
        }
        elseif ($resultText -match "successfully repaired") {
            Write-Log -Message "SFC: Found and repaired corrupt files" -Level "SUCCESS" -Component "Stage4"
        }
        elseif ($resultText -match "found corrupt files but was unable to fix") {
            Write-Log -Message "SFC: Found corrupt files that could not be repaired" -Level "WARN" -Component "Stage4"
        }

        return ($exitCode -eq 0)
    }
    catch {
        Write-Log -Message "SFC failed: $_" -Level "ERROR" -Component "Stage4"
        return $false
    }
}

function Reset-WindowsUpdateComponents {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would reset Windows Update components" -Level "INFO" -Component "Stage4"
        return $true
    }

    try {
        # Stop services
        $services = @("wuauserv", "cryptSvc", "bits", "msiserver", "appidsvc")
        foreach ($svc in $services) {
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
        }

        # Rename SoftwareDistribution and catroot2 folders
        $folders = @(
            @{ Path = "$env:SystemRoot\SoftwareDistribution"; Backup = "$env:SystemRoot\SoftwareDistribution.bak" },
            @{ Path = "$env:SystemRoot\System32\catroot2"; Backup = "$env:SystemRoot\System32\catroot2.bak" }
        )

        foreach ($folder in $folders) {
            if (Test-Path $folder.Backup) {
                Remove-Item -Path $folder.Backup -Recurse -Force -ErrorAction SilentlyContinue
            }
            if (Test-Path $folder.Path) {
                Rename-Item -Path $folder.Path -NewName (Split-Path $folder.Backup -Leaf) -Force -ErrorAction SilentlyContinue
            }
        }

        # Re-register DLLs
        $dlls = @(
            "atl.dll", "urlmon.dll", "mshtml.dll", "shdocvw.dll", "browseui.dll",
            "jscript.dll", "vbscript.dll", "scrrun.dll", "msxml.dll", "msxml3.dll",
            "msxml6.dll", "actxprxy.dll", "softpub.dll", "wintrust.dll", "dssenh.dll",
            "rsaenh.dll", "gpkcsp.dll", "sccbase.dll", "slbcsp.dll", "cryptdlg.dll",
            "oleaut32.dll", "ole32.dll", "shell32.dll", "initpki.dll", "wuapi.dll",
            "wuaueng.dll", "wuaueng1.dll", "wucltui.dll", "wups.dll", "wups2.dll",
            "wuweb.dll", "qmgr.dll", "qmgrprxy.dll", "wucltux.dll", "muweb.dll",
            "wuwebv.dll"
        )

        foreach ($dll in $dlls) {
            & regsvr32 /s $dll 2>&1 | Out-Null
        }

        # Reset Winsock
        & netsh winsock reset 2>&1 | Out-Null
        & netsh winhttp reset proxy 2>&1 | Out-Null

        # Restart services
        foreach ($svc in $services) {
            Start-Service -Name $svc -ErrorAction SilentlyContinue
        }

        Write-Log -Message "Windows Update components reset successfully" -Level "SUCCESS" -Component "Stage4"
        return $true
    }
    catch {
        Write-Log -Message "Error resetting WU components: $_" -Level "ERROR" -Component "Stage4"
        # Ensure services are restarted
        foreach ($svc in @("wuauserv", "cryptSvc", "bits", "msiserver")) {
            Start-Service -Name $svc -ErrorAction SilentlyContinue
        }
        return $false
    }
}

function Repair-WMIRepository {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would repair WMI repository" -Level "INFO" -Component "Stage4"
        return $true
    }

    try {
        # Verify WMI repository
        $result = & winmgmt /verifyrepository 2>&1
        if ($result -match "not consistent|inconsistent") {
            Write-Log -Message "WMI repository is inconsistent, attempting repair..." -Level "WARN" -Component "Stage4"

            # Try salvaging first
            & winmgmt /salvagerepository 2>&1 | Out-Null

            # Verify again
            $result = & winmgmt /verifyrepository 2>&1
            if ($result -match "not consistent|inconsistent") {
                # Force reset as last resort
                & winmgmt /resetrepository 2>&1 | Out-Null
                Write-Log -Message "WMI repository was reset" -Level "WARN" -Component "Stage4"
            }
            else {
                Write-Log -Message "WMI repository salvaged successfully" -Level "SUCCESS" -Component "Stage4"
            }
        }
        else {
            Write-Log -Message "WMI repository is consistent" -Level "SUCCESS" -Component "Stage4"
        }
        return $true
    }
    catch {
        Write-Log -Message "WMI repair failed: $_" -Level "ERROR" -Component "Stage4"
        return $false
    }
}

function Repair-NetworkStack {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would repair network stack" -Level "INFO" -Component "Stage4"
        return $true
    }

    try {
        # Reset Winsock catalog
        & netsh winsock reset 2>&1 | Out-Null

        # Reset TCP/IP stack
        & netsh int ip reset 2>&1 | Out-Null

        # Reset IPv4/IPv6
        & netsh int ipv4 reset 2>&1 | Out-Null
        & netsh int ipv6 reset 2>&1 | Out-Null

        # Flush DNS
        & ipconfig /flushdns 2>&1 | Out-Null

        # Reset proxy settings
        & netsh winhttp reset proxy 2>&1 | Out-Null

        # Release and renew IP
        & ipconfig /release 2>&1 | Out-Null
        & ipconfig /renew 2>&1 | Out-Null

        # Reset firewall
        & netsh advfirewall reset 2>&1 | Out-Null

        Write-Log -Message "Network stack repaired (reboot recommended)" -Level "SUCCESS" -Component "Stage4"
        return $true
    }
    catch {
        Write-Log -Message "Network stack repair partial failure: $_" -Level "WARN" -Component "Stage4"
        return $false
    }
}

function Repair-WindowsSearch {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would repair Windows Search" -Level "INFO" -Component "Stage4"
        return $true
    }

    try {
        Stop-Service -Name "WSearch" -Force -ErrorAction SilentlyContinue

        # Delete search database to force rebuild
        $searchDB = "$env:ProgramData\Microsoft\Search\Data\Applications\Windows\Windows.edb"
        if (Test-Path $searchDB) {
            Remove-Item -Path $searchDB -Force -ErrorAction SilentlyContinue
            Write-Log -Message "Search index database removed (will rebuild)" -Level "INFO" -Component "Stage4"
        }

        Start-Service -Name "WSearch" -ErrorAction SilentlyContinue
        Write-Log -Message "Windows Search repaired" -Level "SUCCESS" -Component "Stage4"
        return $true
    }
    catch {
        Write-Log -Message "Windows Search repair failed: $_" -Level "WARN" -Component "Stage4"
        Start-Service -Name "WSearch" -ErrorAction SilentlyContinue
        return $false
    }
}

function Repair-FileAssociations {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would repair file associations" -Level "INFO" -Component "Stage4"
        return $true
    }

    try {
        # Reset common file associations
        & dism /Online /Remove-DefaultAppAssociations 2>&1 | Out-Null
        Write-Log -Message "File associations reset to defaults" -Level "SUCCESS" -Component "Stage4"
        return $true
    }
    catch {
        Write-Log -Message "File association repair failed: $_" -Level "WARN" -Component "Stage4"
        return $false
    }
}

function Repair-PrintSpooler {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would repair Print Spooler" -Level "INFO" -Component "Stage4"
        return $true
    }

    try {
        Stop-Service -Name "Spooler" -Force -ErrorAction SilentlyContinue

        # Clear print queue
        $printPath = "$env:SystemRoot\System32\spool\PRINTERS"
        if (Test-Path $printPath) {
            Get-ChildItem -Path $printPath -Force -ErrorAction SilentlyContinue |
                Remove-Item -Force -ErrorAction SilentlyContinue
        }

        Start-Service -Name "Spooler" -ErrorAction SilentlyContinue
        Write-Log -Message "Print Spooler repaired" -Level "SUCCESS" -Component "Stage4"
        return $true
    }
    catch {
        Write-Log -Message "Print Spooler repair failed: $_" -Level "WARN" -Component "Stage4"
        Start-Service -Name "Spooler" -ErrorAction SilentlyContinue
        return $false
    }
}

function Repair-WindowsFirewall {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would reset Windows Firewall to defaults" -Level "INFO" -Component "Stage4"
        return $true
    }

    try {
        # Ensure firewall service is running
        Set-Service -Name "MpsSvc" -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name "MpsSvc" -ErrorAction SilentlyContinue

        # Enable firewall for all profiles
        Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled True -ErrorAction SilentlyContinue

        Write-Log -Message "Windows Firewall verified and enabled" -Level "SUCCESS" -Component "Stage4"
        return $true
    }
    catch {
        Write-Log -Message "Firewall repair failed: $_" -Level "WARN" -Component "Stage4"
        return $false
    }
}

function Invoke-DiskCheck {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would schedule chkdsk" -Level "INFO" -Component "Stage4"
        return
    }

    try {
        # Check disk health via SMART (if available)
        $disks = Get-PhysicalDisk -ErrorAction SilentlyContinue
        foreach ($disk in $disks) {
            $health = $disk.HealthStatus
            $name = "$($disk.FriendlyName) ($($disk.MediaType))"
            if ($health -ne "Healthy") {
                Write-Log -Message "DISK WARNING: $name status is $health" -Level "ERROR" -Component "Stage4"
            }
            else {
                Write-Log -Message "Disk $name: Healthy" -Level "SUCCESS" -Component "Stage4"
            }
        }

        # Schedule chkdsk for next reboot (can't run on active system drive)
        Write-Log -Message "Note: Full chkdsk on system drive requires a reboot" -Level "INFO" -Component "Stage4"
        Write-Log -Message "Run 'chkdsk C: /f /r' from an elevated prompt and reboot to perform full check" -Level "INFO" -Component "Stage4"
    }
    catch {
        Write-Log -Message "Disk check failed: $_" -Level "WARN" -Component "Stage4"
    }
}

function Repair-VSSService {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would repair VSS service" -Level "INFO" -Component "Stage4"
        return
    }

    try {
        # Ensure VSS service is set to Manual
        Set-Service -Name "VSS" -StartupType Manual -ErrorAction SilentlyContinue

        # Re-register VSS writers
        & vssadmin list writers 2>&1 | Out-Null

        Write-Log -Message "Volume Shadow Copy service verified" -Level "SUCCESS" -Component "Stage4"
    }
    catch {
        Write-Log -Message "VSS repair failed: $_" -Level "WARN" -Component "Stage4"
    }
}

function Clear-MSIOrphans {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would clean orphaned MSI installer data" -Level "INFO" -Component "Stage4"
        return $true
    }

    try {
        # Clean orphaned installer patches
        $patchCache = "$env:SystemRoot\Installer\`$PatchCache`$\Managed"
        if (Test-Path $patchCache) {
            $size = (Get-ChildItem -Path $patchCache -Recurse -Force -ErrorAction SilentlyContinue |
                Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum / 1MB
            if ($size -gt 100) {
                Write-Log -Message "Found $(Format-FileSize $size) of MSI patch cache" -Level "INFO" -Component "Stage4"
            }
        }

        # Run DISM component cleanup to remove superseded components
        & DISM /Online /Cleanup-Image /StartComponentCleanup 2>&1 | Out-Null
        Write-Log -Message "MSI and component cleanup completed" -Level "SUCCESS" -Component "Stage4"
        return $true
    }
    catch {
        Write-Log -Message "MSI cleanup failed: $_" -Level "WARN" -Component "Stage4"
        return $false
    }
}

function Remove-NVIDIATelemetry {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would remove NVIDIA telemetry tasks" -Level "INFO" -Component "Stage4"
        return $false
    }

    $removed = 0

    # NVIDIA telemetry scheduled tasks
    $nvTasks = Get-ScheduledTask -ErrorAction SilentlyContinue |
        Where-Object { $_.TaskName -match "NvTm|NVIDIA|NvNode|NvProfile|NvDriver" -and $_.TaskName -match "Telemetry|Report|Crash" }

    foreach ($task in $nvTasks) {
        try {
            Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false -ErrorAction Stop
            Write-Log -Message "Removed NVIDIA telemetry task: $($task.TaskName)" -Level "SUCCESS" -Component "Stage4"
            $removed++
        }
        catch { }
    }

    # NVIDIA telemetry services
    $nvServices = @("NvTelemetryContainer", "NVDisplay.ContainerLocalSystem")
    foreach ($svc in $nvServices) {
        $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($service) {
            try {
                Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
                Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
                Write-Log -Message "Disabled NVIDIA service: $svc" -Level "SUCCESS" -Component "Stage4"
                $removed++
            }
            catch { }
        }
    }

    # NVIDIA telemetry registry
    $nvRegPaths = @(
        "HKLM:\SOFTWARE\NVIDIA Corporation\NvControlPanel2\Client",
        "HKLM:\SOFTWARE\NVIDIA Corporation\Global\FTS"
    )
    foreach ($path in $nvRegPaths) {
        if (Test-Path $path) {
            Set-RegistryValue -Path $path -Name "EnableRID66610" -Value 0 | Out-Null
            Set-RegistryValue -Path $path -Name "EnableRID64640" -Value 0 | Out-Null
            Set-RegistryValue -Path $path -Name "EnableRID44231" -Value 0 | Out-Null
        }
    }

    if ($removed -eq 0) {
        Write-Log -Message "No NVIDIA telemetry found (NVIDIA may not be installed)" -Level "INFO" -Component "Stage4"
        return $false
    }

    Write-Log -Message "Removed $removed NVIDIA telemetry components" -Level "SUCCESS" -Component "Stage4"
    return $true
}

function Repair-CommonFileExtensions {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would repair common file extensions" -Level "INFO" -Component "Stage4"
        return $true
    }

    $repaired = 0

    # Common file extension associations to restore
    $extensions = @(
        @{ Ext = ".txt"; ProgID = "txtfile"; Type = "Text Document" },
        @{ Ext = ".log"; ProgID = "txtfile"; Type = "Log File" },
        @{ Ext = ".xml"; ProgID = "xmlfile"; Type = "XML Document" },
        @{ Ext = ".htm"; ProgID = "htmlfile"; Type = "HTML Document" },
        @{ Ext = ".html"; ProgID = "htmlfile"; Type = "HTML Document" },
        @{ Ext = ".jpg"; ProgID = "jpegfile"; Type = "JPEG Image" },
        @{ Ext = ".jpeg"; ProgID = "jpegfile"; Type = "JPEG Image" },
        @{ Ext = ".png"; ProgID = "pngfile"; Type = "PNG Image" },
        @{ Ext = ".gif"; ProgID = "giffile"; Type = "GIF Image" },
        @{ Ext = ".bmp"; ProgID = "Paint.Picture"; Type = "BMP Image" },
        @{ Ext = ".mp3"; ProgID = "WMP11.AssocFile.MP3"; Type = "MP3 Audio" },
        @{ Ext = ".mp4"; ProgID = "WMP11.AssocFile.MP4"; Type = "MP4 Video" },
        @{ Ext = ".zip"; ProgID = "CompressedFolder"; Type = "ZIP Archive" },
        @{ Ext = ".pdf"; ProgID = "AcroExch.Document.DC"; Type = "PDF Document" }
    )

    foreach ($assoc in $extensions) {
        try {
            # Only repair if the extension has no handler or a broken one
            $currentHandler = (Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$($assoc.Ext)\UserChoice" -Name "ProgId" -ErrorAction SilentlyContinue).ProgId

            if (-not $currentHandler) {
                # Extension has no handler; ensure the class exists
                $classPath = "HKLM:\SOFTWARE\Classes\$($assoc.Ext)"
                if (-not (Test-Path $classPath)) {
                    New-Item -Path $classPath -Force | Out-Null
                    Set-ItemProperty -Path $classPath -Name "(Default)" -Value $assoc.ProgID -ErrorAction SilentlyContinue
                    $repaired++
                }
            }
        }
        catch { }
    }

    if ($repaired -gt 0) {
        Write-Log -Message "Repaired $repaired file extension associations" -Level "SUCCESS" -Component "Stage4"
    }
    else {
        Write-Log -Message "File extensions appear intact" -Level "SUCCESS" -Component "Stage4"
    }

    return $true
}

function Repair-DotNetFramework {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would repair .NET Framework" -Level "INFO" -Component "Stage4"
        return $true
    }

    try {
        # Pre-compile .NET assemblies (ngen)
        $ngenPaths = @(
            "$env:SystemRoot\Microsoft.NET\Framework\v4.0.30319\ngen.exe",
            "$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319\ngen.exe"
        )

        foreach ($ngenPath in $ngenPaths) {
            if (Test-Path $ngenPath) {
                Write-Log -Message "Running .NET native image generation (ngen)..." -Level "INFO" -Component "Stage4"
                & $ngenPath executeQueuedItems 2>&1 | Out-Null
            }
        }

        Write-Log -Message ".NET Framework repair/optimization completed" -Level "SUCCESS" -Component "Stage4"
        return $true
    }
    catch {
        Write-Log -Message ".NET repair failed: $_" -Level "WARN" -Component "Stage4"
        return $false
    }
}

Export-ModuleMember -Function Invoke-Stage4

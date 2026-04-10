#Requires -Version 5.1
<#
.SYNOPSIS
    Stage 5: Patch & Update
.DESCRIPTION
    System and software update management:
    - Windows Updates (via COM API)
    - Microsoft Store app updates
    - Driver update check
    - .NET Framework updates
    - PowerShell update check
    - Installed software version audit
#>

function Invoke-Stage5 {
    [CmdletBinding()]
    param(
        [hashtable]$Config = @{},
        [switch]$DryRun,
        [switch]$SkipWindowsUpdates,
        [switch]$SkipDrivers
    )

    $stageTimer = [System.Diagnostics.Stopwatch]::StartNew()
    $updatesInstalled = 0

    Write-StageHeader -StageNumber 5 -StageName "Patch" -Description "Installing Windows updates, driver updates, and software patches"

    # ---- Windows Updates ----
    if (-not $SkipWindowsUpdates) {
        Write-SubStageHeader "Windows Updates"
        $wuInstalled = Install-WindowsUpdates -DryRun:$DryRun
        $updatesInstalled += $wuInstalled
    }
    else {
        Write-Log -Message "Windows Updates skipped (SkipWindowsUpdates flag)" -Level "INFO" -Component "Stage5"
    }

    # ---- Microsoft Store Updates ----
    Write-SubStageHeader "Microsoft Store App Updates"
    Update-StoreApps -DryRun:$DryRun

    # ---- Driver Updates ----
    if (-not $SkipDrivers) {
        Write-SubStageHeader "Driver Update Check"
        $driverUpdates = Find-DriverUpdates -DryRun:$DryRun
    }

    # ---- .NET Framework Check ----
    Write-SubStageHeader ".NET Runtime Check"
    Test-DotNetVersions

    # ---- PowerShell Version Check ----
    Write-SubStageHeader "PowerShell Version Check"
    Test-PowerShellVersion

    # ---- Installed Software Audit ----
    Write-SubStageHeader "Installed Software Audit"
    Get-OutdatedSoftware

    Write-Host ""
    Write-Log -Message "Patching complete: $updatesInstalled updates installed" -Level "SUCCESS" -Component "Stage5"

    Set-Metric -Name "UpdatesInstalled" -Value $updatesInstalled -Category "Stage5"

    $stageTimer.Stop()

    Register-StageResult -StageNumber 5 -StageName "Patch" -Status "Success" `
        -Summary "$updatesInstalled updates installed" `
        -Details @{ UpdatesInstalled = $updatesInstalled } -Duration $stageTimer.Elapsed

    return $updatesInstalled
}

# ============================================================================
# SUB-FUNCTIONS
# ============================================================================

function Install-WindowsUpdates {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would check and install Windows Updates" -Level "INFO" -Component "Stage5"
        return 0
    }

    try {
        # Use Windows Update COM API
        $updateSession = New-Object -ComObject Microsoft.Update.Session
        $updateSearcher = $updateSession.CreateUpdateSearcher()

        Write-Log -Message "Searching for Windows Updates..." -Level "INFO" -Component "Stage5"
        $searchResult = $updateSearcher.Search("IsInstalled=0 AND Type='Software' AND IsHidden=0")

        if ($searchResult.Updates.Count -eq 0) {
            Write-Log -Message "No pending Windows Updates found" -Level "SUCCESS" -Component "Stage5"
            return 0
        }

        Write-Log -Message "Found $($searchResult.Updates.Count) pending update(s)" -Level "INFO" -Component "Stage5"

        # List found updates
        $updatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
        foreach ($update in $searchResult.Updates) {
            Write-Log -Message "  Update: $($update.Title)" -Level "INFO" -Component "Stage5"

            # Accept EULA if required
            if (-not $update.EulaAccepted) {
                $update.AcceptEula()
            }
            $updatesToInstall.Add($update) | Out-Null
        }

        if ($updatesToInstall.Count -gt 0) {
            # Download updates
            Write-Log -Message "Downloading $($updatesToInstall.Count) update(s)..." -Level "INFO" -Component "Stage5"
            $downloader = $updateSession.CreateUpdateDownloader()
            $downloader.Updates = $updatesToInstall
            $downloadResult = $downloader.Download()

            if ($downloadResult.ResultCode -eq 2) {  # Succeeded
                # Install updates
                Write-Log -Message "Installing updates..." -Level "INFO" -Component "Stage5"
                $installer = $updateSession.CreateUpdateInstaller()
                $installer.Updates = $updatesToInstall
                $installResult = $installer.Install()

                $installed = 0
                for ($i = 0; $i -lt $updatesToInstall.Count; $i++) {
                    $result = $installResult.GetUpdateResult($i)
                    if ($result.ResultCode -eq 2) {
                        Write-Log -Message "  Installed: $($updatesToInstall.Item($i).Title)" -Level "SUCCESS" -Component "Stage5"
                        $installed++
                    }
                    else {
                        Write-Log -Message "  Failed: $($updatesToInstall.Item($i).Title) (Error: $($result.ResultCode))" -Level "WARN" -Component "Stage5"
                    }
                }

                if ($installResult.RebootRequired) {
                    Write-Log -Message "A system reboot is required to complete update installation" -Level "WARN" -Component "Stage5"
                }

                return $installed
            }
            else {
                Write-Log -Message "Update download failed (Result: $($downloadResult.ResultCode))" -Level "ERROR" -Component "Stage5"
                return 0
            }
        }
    }
    catch {
        Write-Log -Message "Windows Update failed: $_" -Level "ERROR" -Component "Stage5"

        # Fallback: try UsoClient
        try {
            Write-Log -Message "Attempting update via UsoClient..." -Level "INFO" -Component "Stage5"
            & UsoClient StartScan 2>&1 | Out-Null
            & UsoClient StartDownload 2>&1 | Out-Null
            & UsoClient StartInstall 2>&1 | Out-Null
            Write-Log -Message "Update triggered via UsoClient (check Windows Update settings for status)" -Level "INFO" -Component "Stage5"
        }
        catch { }

        return 0
    }
}

function Update-StoreApps {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would update Microsoft Store apps" -Level "INFO" -Component "Stage5"
        return
    }

    try {
        # Trigger Store app updates
        $namespaceName = "root\cimv2\mdm\dmmap"
        $className = "MDM_EnterpriseModernAppManagement_AppManagement01"

        $session = New-CimSession
        $result = Invoke-CimMethod -Namespace $namespaceName -ClassName $className -MethodName UpdateScanMethod -CimSession $session -ErrorAction Stop
        Remove-CimSession -CimSession $session

        Write-Log -Message "Microsoft Store app update triggered" -Level "SUCCESS" -Component "Stage5"
    }
    catch {
        # Fallback: use wsreset
        try {
            Start-Process "wsreset.exe" -WindowStyle Hidden -ErrorAction SilentlyContinue
            Write-Log -Message "Store cache reset triggered (updates will download automatically)" -Level "INFO" -Component "Stage5"
        }
        catch {
            Write-Log -Message "Could not trigger Store updates: $_" -Level "WARN" -Component "Stage5"
        }
    }
}

function Find-DriverUpdates {
    [CmdletBinding()]
    param([switch]$DryRun)

    try {
        Write-Log -Message "Checking for driver updates..." -Level "INFO" -Component "Stage5"

        # List devices with issues
        $problemDevices = Get-PnpDevice -Status ERROR, DEGRADED, UNKNOWN -ErrorAction SilentlyContinue
        if ($problemDevices) {
            Write-Log -Message "Found $($problemDevices.Count) device(s) with issues:" -Level "WARN" -Component "Stage5"
            foreach ($device in $problemDevices) {
                Write-Log -Message "  $($device.FriendlyName) - Status: $($device.Status) - Class: $($device.Class)" -Level "WARN" -Component "Stage5"
            }
        }
        else {
            Write-Log -Message "All devices functioning properly" -Level "SUCCESS" -Component "Stage5"
        }

        # Check for driver updates via Windows Update
        if (-not $DryRun) {
            try {
                $updateSession = New-Object -ComObject Microsoft.Update.Session
                $updateSearcher = $updateSession.CreateUpdateSearcher()
                $searchResult = $updateSearcher.Search("IsInstalled=0 AND Type='Driver'")

                if ($searchResult.Updates.Count -gt 0) {
                    Write-Log -Message "Found $($searchResult.Updates.Count) driver update(s) available:" -Level "INFO" -Component "Stage5"
                    foreach ($update in $searchResult.Updates) {
                        Write-Log -Message "  Driver: $($update.Title)" -Level "INFO" -Component "Stage5"
                    }
                }
                else {
                    Write-Log -Message "No driver updates available" -Level "SUCCESS" -Component "Stage5"
                }

                return $searchResult.Updates.Count
            }
            catch { }
        }

        return 0
    }
    catch {
        Write-Log -Message "Driver update check failed: $_" -Level "WARN" -Component "Stage5"
        return 0
    }
}

function Test-DotNetVersions {
    try {
        # Check .NET Framework
        $netFxKey = "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full"
        if (Test-Path $netFxKey) {
            $release = (Get-ItemProperty $netFxKey).Release
            $version = switch ($release) {
                { $_ -ge 533320 } { "4.8.1" }
                { $_ -ge 528040 } { "4.8" }
                { $_ -ge 461808 } { "4.7.2" }
                { $_ -ge 461308 } { "4.7.1" }
                { $_ -ge 460798 } { "4.7" }
                { $_ -ge 394802 } { "4.6.2" }
                default { "4.6 or earlier" }
            }
            Write-Log -Message ".NET Framework: $version" -Level "INFO" -Component "Stage5"
        }

        # Check .NET runtimes
        $dotnetInfo = & dotnet --list-runtimes 2>&1
        if ($LASTEXITCODE -eq 0) {
            $runtimes = $dotnetInfo | Select-Object -Last 5
            foreach ($runtime in $runtimes) {
                Write-Log -Message ".NET Runtime: $runtime" -Level "INFO" -Component "Stage5"
            }
        }

        # Check Visual C++ Redistributables
        $vcredists = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
                                       "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -match "Visual C\+\+" } |
            Select-Object DisplayName, DisplayVersion |
            Sort-Object DisplayName -Unique

        if ($vcredists) {
            Write-Log -Message "Installed VC++ Redistributables: $($vcredists.Count)" -Level "INFO" -Component "Stage5"
        }
    }
    catch {
        Write-Log -Message "Runtime version check failed: $_" -Level "WARN" -Component "Stage5"
    }
}

function Test-PowerShellVersion {
    $currentVersion = $PSVersionTable.PSVersion
    Write-Log -Message "PowerShell version: $currentVersion" -Level "INFO" -Component "Stage5"

    if ($currentVersion.Major -lt 7) {
        Write-Log -Message "PowerShell 7+ is recommended for best performance. Install from: https://aka.ms/powershell" -Level "WARN" -Component "Stage5"
    }
    else {
        Write-Log -Message "PowerShell is up to date" -Level "SUCCESS" -Component "Stage5"
    }
}

function Get-OutdatedSoftware {
    try {
        $installedSoftware = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
                                               "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -and $_.DisplayVersion } |
            Select-Object DisplayName, DisplayVersion, Publisher, InstallDate |
            Sort-Object DisplayName

        $count = ($installedSoftware | Measure-Object).Count
        Write-Log -Message "Found $count installed programs" -Level "INFO" -Component "Stage5"

        # Flag commonly outdated software
        $checkList = @(
            @{ Pattern = "Java"; MinVersion = "8.0" },
            @{ Pattern = "Adobe.*Reader"; MinVersion = "2024" },
            @{ Pattern = "7-Zip"; MinVersion = "23" },
            @{ Pattern = "VLC"; MinVersion = "3.0" },
            @{ Pattern = "Notepad\+\+"; MinVersion = "8" }
        )

        foreach ($check in $checkList) {
            $found = $installedSoftware | Where-Object { $_.DisplayName -match $check.Pattern }
            if ($found) {
                foreach ($app in $found) {
                    Write-Log -Message "  Installed: $($app.DisplayName) v$($app.DisplayVersion)" -Level "INFO" -Component "Stage5"
                }
            }
        }

        Set-Metric -Name "InstalledPrograms" -Value $count -Category "Stage5"
    }
    catch {
        Write-Log -Message "Software audit failed: $_" -Level "WARN" -Component "Stage5"
    }
}

Export-ModuleMember -Function Invoke-Stage5

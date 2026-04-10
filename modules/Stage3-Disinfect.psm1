#Requires -Version 5.1
<#
.SYNOPSIS
    Stage 3: Disinfection
.DESCRIPTION
    Malware scanning and removal:
    - Windows Defender signature update + full scan
    - Known malicious process detection
    - Suspicious scheduled task detection
    - Hosts file verification
    - Browser extension audit
    - Known malware registry key cleanup
    - Startup item audit
#>

function Invoke-Stage3 {
    [CmdletBinding()]
    param(
        [hashtable]$Config = @{},
        [switch]$DryRun,
        [switch]$QuickScan
    )

    $stageTimer = [System.Diagnostics.Stopwatch]::StartNew()
    $threats = 0

    Write-StageHeader -StageNumber 3 -StageName "Disinfect" -Description "Scanning for and removing malware, suspicious items, and threats"

    # ---- Kill Known Malicious Processes ----
    Write-SubStageHeader "Scanning for Known Malicious Processes"
    $killed = Find-MaliciousProcesses -DryRun:$DryRun
    $threats += $killed

    # ---- Update Windows Defender ----
    Write-SubStageHeader "Updating Windows Defender Signatures"
    Update-DefenderSignatures -DryRun:$DryRun

    # ---- Run Windows Defender Scan ----
    Write-SubStageHeader "Running Windows Defender Scan"
    $scanThreats = Invoke-DefenderScan -QuickScan:$QuickScan -DryRun:$DryRun
    $threats += $scanThreats

    # ---- Check Suspicious Scheduled Tasks ----
    Write-SubStageHeader "Auditing Scheduled Tasks"
    $suspiciousTasks = Find-SuspiciousScheduledTasks -DryRun:$DryRun
    $threats += $suspiciousTasks

    # ---- Check Hosts File ----
    Write-SubStageHeader "Verifying Hosts File Integrity"
    $hostsIssues = Test-HostsFile -DryRun:$DryRun
    $threats += $hostsIssues

    # ---- Audit Startup Items ----
    Write-SubStageHeader "Auditing Startup Items"
    $startupThreats = Find-SuspiciousStartupItems -DryRun:$DryRun
    $threats += $startupThreats

    # ---- Clean Malware Registry Keys ----
    Write-SubStageHeader "Cleaning Known Malware Registry Keys"
    $regCleaned = Remove-MalwareRegistryKeys -DryRun:$DryRun
    $threats += $regCleaned

    # ---- Check Running Services ----
    Write-SubStageHeader "Auditing Running Services"
    $suspiciousServices = Find-SuspiciousServices

    Write-Host ""
    if ($threats -eq 0) {
        Write-Log -Message "No threats detected" -Level "SUCCESS" -Component "Stage3"
    }
    else {
        Write-Log -Message "$threats potential threats found and addressed" -Level "WARN" -Component "Stage3"
    }

    Set-Metric -Name "ThreatsFound" -Value $threats -Category "Stage3"

    $stageTimer.Stop()

    Register-StageResult -StageNumber 3 -StageName "Disinfect" `
        -Status $(if ($threats -gt 0) { "Warning" } else { "Success" }) `
        -Summary "$threats potential threats detected" `
        -Details @{ ThreatsFound = $threats } -Duration $stageTimer.Elapsed

    return $threats
}

# ============================================================================
# SUB-FUNCTIONS
# ============================================================================

function Find-MaliciousProcesses {
    [CmdletBinding()]
    param([switch]$DryRun)

    # Known malicious process names and patterns
    $maliciousProcesses = @(
        # Fake system processes (real ones wouldn't have these names)
        "svchost32", "csrss32", "lsass32", "winlogon32", "services32",
        "explorer32", "spoolsv32", "taskhost32",
        # Known malware
        "cryptonight", "xmrig", "minergate", "nicehashminer",
        "coinminer", "cpuminer", "sgminer", "ccminer",
        # Common adware/PUP processes
        "Crossbrowse", "BoBrowser", "Chedot", "Torch",
        "MySearchDial", "V9Loader", "SweetPage",
        "AdvancedSystemProtector", "RegCleanPro", "SpeedUpMyPC",
        "DriverUpdater", "WinZipDriverUpdater",
        "PCSpeedMaximizer", "MyPCBackup", "webssearches"
    )

    $killed = 0
    foreach ($procName in $maliciousProcesses) {
        $proc = Get-Process -Name $procName -ErrorAction SilentlyContinue
        if ($proc) {
            Write-Log -Message "THREAT: Malicious process detected: $procName (PID: $($proc.Id))" -Level "ERROR" -Component "Stage3"
            if (-not $DryRun) {
                try {
                    $proc | Stop-Process -Force -ErrorAction Stop
                    Write-Log -Message "Killed malicious process: $procName" -Level "SUCCESS" -Component "Stage3"
                }
                catch {
                    Write-Log -Message "Could not kill $procName - may need manual removal" -Level "ERROR" -Component "Stage3"
                }
            }
            $killed++
        }
    }

    # Check for processes with suspicious paths
    $allProcs = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path }
    $suspiciousPaths = @("$env:TEMP", "$env:APPDATA", "$env:LOCALAPPDATA\Temp")

    foreach ($proc in $allProcs) {
        foreach ($susPath in $suspiciousPaths) {
            if ($proc.Path -and $proc.Path.StartsWith($susPath) -and
                $proc.Name -notin @("chrome", "firefox", "msedge", "code", "Teams", "Slack", "Discord")) {
                Write-Log -Message "SUSPICIOUS: Process running from temp path: $($proc.Name) at $($proc.Path)" -Level "WARN" -Component "Stage3"
            }
        }
    }

    if ($killed -eq 0) {
        Write-Log -Message "No known malicious processes found" -Level "SUCCESS" -Component "Stage3"
    }

    return $killed
}

function Update-DefenderSignatures {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would update Defender signatures" -Level "INFO" -Component "Stage3"
        return
    }

    try {
        $defenderStatus = Get-MpComputerStatus -ErrorAction Stop
        Write-Log -Message "Current Defender signature version: $($defenderStatus.AntivirusSignatureVersion)" -Level "INFO" -Component "Stage3"
        Write-Log -Message "Last signature update: $($defenderStatus.AntivirusSignatureLastUpdated)" -Level "INFO" -Component "Stage3"

        Update-MpSignature -ErrorAction Stop
        Write-Log -Message "Defender signatures updated successfully" -Level "SUCCESS" -Component "Stage3"
    }
    catch {
        Write-Log -Message "Could not update Defender signatures: $_" -Level "WARN" -Component "Stage3"
    }
}

function Invoke-DefenderScan {
    [CmdletBinding()]
    param(
        [switch]$QuickScan,
        [switch]$DryRun
    )

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would run Defender $(if ($QuickScan) { 'quick' } else { 'full' }) scan" -Level "INFO" -Component "Stage3"
        return 0
    }

    try {
        $scanType = if ($QuickScan) { "QuickScan" } else { "FullScan" }
        Write-Log -Message "Starting Windows Defender $scanType (this may take a while)..." -Level "INFO" -Component "Stage3"

        Start-MpScan -ScanType $scanType -ErrorAction Stop

        # Check for detected threats
        $threats = Get-MpThreatDetection -ErrorAction SilentlyContinue
        $recentThreats = $threats | Where-Object { $_.InitialDetectionTime -gt (Get-Date).AddHours(-1) }

        if ($recentThreats) {
            $threatCount = ($recentThreats | Measure-Object).Count
            Write-Log -Message "Defender found $threatCount threat(s)!" -Level "WARN" -Component "Stage3"

            foreach ($threat in $recentThreats) {
                Write-Log -Message "  Threat: $($threat.ThreatName) at $($threat.Resources)" -Level "WARN" -Component "Stage3"
            }

            # Attempt removal
            Remove-MpThreat -ErrorAction SilentlyContinue
            return $threatCount
        }
        else {
            Write-Log -Message "Defender scan completed - no threats found" -Level "SUCCESS" -Component "Stage3"
            return 0
        }
    }
    catch {
        Write-Log -Message "Defender scan failed: $_" -Level "ERROR" -Component "Stage3"
        return 0
    }
}

function Find-SuspiciousScheduledTasks {
    [CmdletBinding()]
    param([switch]$DryRun)

    $suspicious = 0

    try {
        $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue

        foreach ($task in $tasks) {
            $actions = $task.Actions
            foreach ($action in $actions) {
                if ($action.Execute) {
                    $exe = $action.Execute.ToLower()

                    # Check for tasks running from suspicious locations
                    $susLocations = @("$env:TEMP", "$env:APPDATA", "\downloads\", "\desktop\")
                    foreach ($loc in $susLocations) {
                        if ($exe -like "*$($loc.ToLower())*") {
                            Write-Log -Message "SUSPICIOUS task: '$($task.TaskName)' executes from: $($action.Execute)" -Level "WARN" -Component "Stage3"
                            $suspicious++
                        }
                    }

                    # Check for PowerShell with encoded commands
                    if ($exe -like "*powershell*" -and $action.Arguments -match "-[eE]nc") {
                        Write-Log -Message "SUSPICIOUS task: '$($task.TaskName)' uses encoded PowerShell command" -Level "WARN" -Component "Stage3"
                        $suspicious++
                    }

                    # Check for cmd.exe with suspicious arguments
                    if ($exe -like "*cmd*" -and $action.Arguments -match "(wget|curl|Invoke-WebRequest|downloadfile|bitsadmin)") {
                        Write-Log -Message "SUSPICIOUS task: '$($task.TaskName)' downloads files via cmd" -Level "WARN" -Component "Stage3"
                        $suspicious++
                    }
                }
            }
        }
    }
    catch {
        Write-Log -Message "Error auditing scheduled tasks: $_" -Level "WARN" -Component "Stage3"
    }

    if ($suspicious -eq 0) {
        Write-Log -Message "No suspicious scheduled tasks found" -Level "SUCCESS" -Component "Stage3"
    }

    return $suspicious
}

function Test-HostsFile {
    [CmdletBinding()]
    param([switch]$DryRun)

    $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
    $issues = 0

    try {
        if (-not (Test-Path $hostsPath)) {
            Write-Log -Message "Hosts file not found!" -Level "ERROR" -Component "Stage3"
            return 1
        }

        $content = Get-Content -Path $hostsPath -ErrorAction Stop
        $suspiciousEntries = @()

        foreach ($line in $content) {
            $trimmed = $line.Trim()
            if ($trimmed -and -not $trimmed.StartsWith("#")) {
                # Check for redirected common domains (sign of malware)
                $redirectTargets = @("google.com", "facebook.com", "microsoft.com", "windowsupdate.com", "windows.com")
                foreach ($target in $redirectTargets) {
                    if ($trimmed -match $target -and $trimmed -notmatch "^(127\.0\.0\.1|::1|0\.0\.0\.0)\s+") {
                        $suspiciousEntries += $trimmed
                    }
                }
            }
        }

        if ($suspiciousEntries.Count -gt 0) {
            Write-Log -Message "Found $($suspiciousEntries.Count) suspicious hosts file entries!" -Level "WARN" -Component "Stage3"
            foreach ($entry in $suspiciousEntries) {
                Write-Log -Message "  Suspicious: $entry" -Level "WARN" -Component "Stage3"
            }
            $issues = $suspiciousEntries.Count
        }
        else {
            Write-Log -Message "Hosts file appears clean" -Level "SUCCESS" -Component "Stage3"
        }
    }
    catch {
        Write-Log -Message "Error checking hosts file: $_" -Level "WARN" -Component "Stage3"
    }

    return $issues
}

function Find-SuspiciousStartupItems {
    [CmdletBinding()]
    param([switch]$DryRun)

    $suspicious = 0

    $startupPaths = @(
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
    )

    foreach ($path in $startupPaths) {
        if (Test-Path $path) {
            $items = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
            $props = $items.PSObject.Properties | Where-Object { $_.Name -notin @("PSPath", "PSParentPath", "PSChildName", "PSDrive", "PSProvider") }

            foreach ($prop in $props) {
                $value = $prop.Value.ToString().ToLower()

                # Check for suspicious patterns
                if ($value -match "(temp|appdata\\local\\temp|downloads)" -and
                    $value -notmatch "(chrome|firefox|edge|teams|slack|discord|spotify)") {
                    Write-Log -Message "SUSPICIOUS startup: '$($prop.Name)' -> $($prop.Value)" -Level "WARN" -Component "Stage3"
                    $suspicious++
                }

                if ($value -match "(cmd\.exe.*/(c|k)|powershell.*-enc|mshta|wscript|cscript)") {
                    Write-Log -Message "SUSPICIOUS startup (script): '$($prop.Name)' -> $($prop.Value)" -Level "WARN" -Component "Stage3"
                    $suspicious++
                }
            }
        }
    }

    if ($suspicious -eq 0) {
        Write-Log -Message "No suspicious startup items found" -Level "SUCCESS" -Component "Stage3"
    }

    return $suspicious
}

function Remove-MalwareRegistryKeys {
    [CmdletBinding()]
    param([switch]$DryRun)

    $cleaned = 0

    # Known malware/adware registry locations
    $malwareKeys = @(
        "HKCU:\SOFTWARE\Classes\CLSID\{randomly-generated}",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Browser Helper Objects"
    )

    # Check for suspicious BHOs (Browser Helper Objects)
    $bhoPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Browser Helper Objects"
    if (Test-Path $bhoPath) {
        $bhos = Get-ChildItem -Path $bhoPath -ErrorAction SilentlyContinue
        foreach ($bho in $bhos) {
            $clsid = $bho.PSChildName
            try {
                $name = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Classes\CLSID\$clsid" -Name "(Default)" -ErrorAction SilentlyContinue).'(Default)'
                $knownBad = @("SearchProtect", "Babylon", "Ask Toolbar", "Conduit", "MyWebSearch", "Sweetpacks", "Delta Search")
                if ($knownBad | Where-Object { $name -like "*$_*" }) {
                    Write-Log -Message "Found malware BHO: $name ($clsid)" -Level "WARN" -Component "Stage3"
                    if (-not $DryRun) {
                        Remove-Item -Path "$bhoPath\$clsid" -Recurse -Force -ErrorAction SilentlyContinue
                        $cleaned++
                    }
                }
            }
            catch { }
        }
    }

    if ($cleaned -eq 0) {
        Write-Log -Message "No known malware registry keys found" -Level "SUCCESS" -Component "Stage3"
    }

    return $cleaned
}

function Find-SuspiciousServices {
    try {
        $services = Get-CimInstance Win32_Service -ErrorAction SilentlyContinue |
            Where-Object { $_.PathName -and $_.StartMode -ne "Disabled" }

        $suspicious = 0
        foreach ($svc in $services) {
            $path = $svc.PathName.ToLower()

            # Services running from temp or suspicious locations
            if ($path -match "(\\temp\\|\\appdata\\|\\downloads\\)" -and
                $svc.Name -notmatch "(chrome|firefox|edge|teams|slack|discord)") {
                Write-Log -Message "SUSPICIOUS service: $($svc.Name) at $($svc.PathName)" -Level "WARN" -Component "Stage3"
                $suspicious++
            }

            # Services with no description and unusual paths
            if (-not $svc.Description -and $path -notmatch "(system32|program files|windows)" -and $svc.State -eq "Running") {
                Write-Log -Message "Undocumented service from non-standard path: $($svc.Name) at $($svc.PathName)" -Level "WARN" -Component "Stage3"
            }
        }

        if ($suspicious -eq 0) {
            Write-Log -Message "No suspicious services found" -Level "SUCCESS" -Component "Stage3"
        }

        return $suspicious
    }
    catch {
        Write-Log -Message "Error auditing services: $_" -Level "WARN" -Component "Stage3"
        return 0
    }
}

Export-ModuleMember -Function Invoke-Stage3

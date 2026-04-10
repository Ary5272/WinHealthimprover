#Requires -Version 5.1
<#
.SYNOPSIS
    Stage 1: Temporary File & Cache Cleanup
.DESCRIPTION
    Comprehensive cleanup of temporary files, caches, and unnecessary data:
    - User temp files
    - Windows temp files
    - Windows Update cache
    - Browser caches (Edge, Chrome, Firefox)
    - Recycle Bin
    - Thumbnail cache
    - Windows Installer cache
    - Font cache
    - Windows Error Reporting
    - Delivery Optimization cache
    - Event logs (backup then clear)
    - Memory dumps
#>

function Invoke-Stage1 {
    [CmdletBinding()]
    param(
        [hashtable]$Config = @{},
        [switch]$DryRun
    )

    $stageTimer = [System.Diagnostics.Stopwatch]::StartNew()
    $totalCleaned = 0

    Write-StageHeader -StageNumber 1 -StageName "TempClean" -Description "Cleaning temporary files, caches, and unnecessary data"

    # ---- User Temp Files ----
    Write-SubStageHeader "User Temp Files"
    $cleaned = Clear-UserTemp -DryRun:$DryRun
    $totalCleaned += $cleaned

    # ---- Windows Temp Files ----
    Write-SubStageHeader "Windows Temp Files"
    $cleaned = Clear-WindowsTemp -DryRun:$DryRun
    $totalCleaned += $cleaned

    # ---- Windows Update Cache ----
    Write-SubStageHeader "Windows Update Cache"
    $cleaned = Clear-WindowsUpdateCache -DryRun:$DryRun
    $totalCleaned += $cleaned

    # ---- Browser Caches ----
    Write-SubStageHeader "Browser Caches"
    $cleaned = Clear-BrowserCaches -DryRun:$DryRun
    $totalCleaned += $cleaned

    # ---- Recycle Bin ----
    Write-SubStageHeader "Recycle Bin"
    $cleaned = Clear-RecycleBinSafely -DryRun:$DryRun
    $totalCleaned += $cleaned

    # ---- Thumbnail Cache ----
    Write-SubStageHeader "Thumbnail Cache"
    $cleaned = Clear-ThumbnailCache -DryRun:$DryRun
    $totalCleaned += $cleaned

    # ---- Windows Error Reports ----
    Write-SubStageHeader "Windows Error Reports"
    $cleaned = Clear-ErrorReports -DryRun:$DryRun
    $totalCleaned += $cleaned

    # ---- Delivery Optimization Cache ----
    Write-SubStageHeader "Delivery Optimization Cache"
    $cleaned = Clear-DeliveryOptimization -DryRun:$DryRun
    $totalCleaned += $cleaned

    # ---- Memory Dumps ----
    Write-SubStageHeader "Memory Dumps"
    $cleaned = Clear-MemoryDumps -DryRun:$DryRun
    $totalCleaned += $cleaned

    # ---- Event Logs ----
    Write-SubStageHeader "Old Event Logs"
    $cleaned = Clear-OldEventLogs -DryRun:$DryRun
    $totalCleaned += $cleaned

    # ---- Prefetch ----
    Write-SubStageHeader "Prefetch Data"
    $cleaned = Clear-Prefetch -DryRun:$DryRun
    $totalCleaned += $cleaned

    # ---- Font Cache ----
    Write-SubStageHeader "Font Cache"
    $cleaned = Clear-FontCache -DryRun:$DryRun
    $totalCleaned += $cleaned

    # ---- Windows Installer Orphans ----
    Write-SubStageHeader "Windows Installer Orphaned Patches"
    $cleaned = Clear-InstallerOrphans -DryRun:$DryRun
    $totalCleaned += $cleaned

    # ---- CryptNet SSL Certificate Cache ----
    Write-SubStageHeader "CryptNet SSL Certificate Cache"
    $cleaned = Clear-CryptNetCache -DryRun:$DryRun
    $totalCleaned += $cleaned

    # ---- BranchCache ----
    Write-SubStageHeader "BranchCache"
    Clear-BranchCacheData -DryRun:$DryRun

    # ---- Windows Disk Cleanup (cleanmgr) ----
    Write-SubStageHeader "Windows Disk Cleanup (cleanmgr)"
    $cleaned = Invoke-DiskCleanup -DryRun:$DryRun
    $totalCleaned += $cleaned

    # ---- IIS Logs ----
    Write-SubStageHeader "IIS / Web Server Logs"
    $cleaned = Clear-IISLogs -DryRun:$DryRun
    $totalCleaned += $cleaned

    # ---- Stale User Profiles Temp Data ----
    Write-SubStageHeader "Other User Temp Folders"
    $cleaned = Clear-AllUserTemps -DryRun:$DryRun
    $totalCleaned += $cleaned

    # ---- Old Windows Installations ----
    Write-SubStageHeader "Old Windows Installations (Windows.old)"
    $cleaned = Clear-WindowsOld -DryRun:$DryRun
    $totalCleaned += $cleaned

    # ---- Summary ----
    Write-Host ""
    Write-Log -Message "Total space recovered: $(Format-FileSize $totalCleaned)" -Level "SUCCESS" -Component "Stage1"

    Set-Metric -Name "SpaceCleaned_MB" -Value $totalCleaned -Category "Stage1"

    $stageTimer.Stop()

    Register-StageResult -StageNumber 1 -StageName "TempClean" -Status "Success" `
        -Summary "Recovered $(Format-FileSize $totalCleaned) of disk space" `
        -Details @{ TotalCleanedMB = $totalCleaned } -Duration $stageTimer.Elapsed

    return $totalCleaned
}

# ============================================================================
# SUB-FUNCTIONS
# ============================================================================

function Clear-UserTemp {
    param([switch]$DryRun)

    $paths = @(
        $env:TEMP,
        "$env:LOCALAPPDATA\Temp",
        "$env:USERPROFILE\AppData\Local\Temp"
    )

    $totalCleaned = 0
    foreach ($path in ($paths | Select-Object -Unique)) {
        if (Test-Path $path) {
            $size = Get-FolderSize -Path $path
            if ($DryRun) {
                Write-Log -Message "[DRY RUN] Would clean $path ($(Format-FileSize $size))" -Level "INFO" -Component "Stage1"
            }
            else {
                $cleaned = Remove-FolderContents -Path $path -Recurse
                Write-Log -Message "Cleaned $path: $(Format-FileSize $cleaned)" -Level "SUCCESS" -Component "Stage1"
                $totalCleaned += $cleaned
            }
        }
    }
    return $totalCleaned
}

function Clear-WindowsTemp {
    param([switch]$DryRun)

    $paths = @(
        "$env:SystemRoot\Temp",
        "$env:SystemRoot\Logs\CBS",
        "$env:SystemRoot\Logs\DISM"
    )

    $totalCleaned = 0
    foreach ($path in $paths) {
        if (Test-Path $path) {
            $size = Get-FolderSize -Path $path
            if ($DryRun) {
                Write-Log -Message "[DRY RUN] Would clean $path ($(Format-FileSize $size))" -Level "INFO" -Component "Stage1"
            }
            else {
                $cleaned = Remove-FolderContents -Path $path -Recurse
                Write-Log -Message "Cleaned $path: $(Format-FileSize $cleaned)" -Level "SUCCESS" -Component "Stage1"
                $totalCleaned += $cleaned
            }
        }
    }
    return $totalCleaned
}

function Clear-WindowsUpdateCache {
    param([switch]$DryRun)

    $path = "$env:SystemRoot\SoftwareDistribution\Download"

    if (-not (Test-Path $path)) { return 0 }

    $size = Get-FolderSize -Path $path

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would clean Windows Update cache ($(Format-FileSize $size))" -Level "INFO" -Component "Stage1"
        return 0
    }

    try {
        Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
        Stop-Service -Name "bits" -Force -ErrorAction SilentlyContinue

        $cleaned = Remove-FolderContents -Path $path -Recurse

        Start-Service -Name "bits" -ErrorAction SilentlyContinue
        Start-Service -Name "wuauserv" -ErrorAction SilentlyContinue

        Write-Log -Message "Windows Update cache cleaned: $(Format-FileSize $cleaned)" -Level "SUCCESS" -Component "Stage1"
        return $cleaned
    }
    catch {
        Write-Log -Message "Error cleaning WU cache: $_" -Level "WARN" -Component "Stage1"
        Start-Service -Name "bits" -ErrorAction SilentlyContinue
        Start-Service -Name "wuauserv" -ErrorAction SilentlyContinue
        return 0
    }
}

function Clear-BrowserCaches {
    param([switch]$DryRun)

    $totalCleaned = 0

    # Chrome
    $chromePaths = @(
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache",
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\GPUCache",
        "$env:LOCALAPPDATA\Google\Chrome\User Data\ShaderCache"
    )

    # Edge
    $edgePaths = @(
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\GPUCache",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\ShaderCache"
    )

    # Firefox
    $firefoxProfilePath = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles"
    $firefoxPaths = @()
    if (Test-Path $firefoxProfilePath) {
        $profiles = Get-ChildItem -Path $firefoxProfilePath -Directory
        foreach ($profile in $profiles) {
            $firefoxPaths += "$($profile.FullName)\cache2"
            $firefoxPaths += "$($profile.FullName)\thumbnails"
        }
    }

    # Brave
    $bravePaths = @(
        "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Cache",
        "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Code Cache"
    )

    $allPaths = $chromePaths + $edgePaths + $firefoxPaths + $bravePaths

    foreach ($path in $allPaths) {
        if (Test-Path $path) {
            $size = Get-FolderSize -Path $path
            if ($DryRun) {
                Write-Log -Message "[DRY RUN] Would clean: $path ($(Format-FileSize $size))" -Level "INFO" -Component "Stage1"
            }
            else {
                $cleaned = Remove-FolderContents -Path $path -Recurse
                if ($cleaned -gt 0) {
                    Write-Log -Message "Cleaned browser cache: $(Format-FileSize $cleaned) from $(Split-Path $path -Leaf)" -Level "SUCCESS" -Component "Stage1"
                    $totalCleaned += $cleaned
                }
            }
        }
    }

    if ($totalCleaned -eq 0 -and -not $DryRun) {
        Write-Log -Message "No browser caches found to clean" -Level "INFO" -Component "Stage1"
    }

    return $totalCleaned
}

function Clear-RecycleBinSafely {
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would empty Recycle Bin" -Level "INFO" -Component "Stage1"
        return 0
    }

    try {
        $shell = New-Object -ComObject Shell.Application
        $recycleBin = $shell.Namespace(0xa)
        $itemCount = $recycleBin.Items().Count

        if ($itemCount -gt 0) {
            Clear-RecycleBin -Force -ErrorAction Stop
            Write-Log -Message "Recycle Bin emptied ($itemCount items)" -Level "SUCCESS" -Component "Stage1"
        }
        else {
            Write-Log -Message "Recycle Bin already empty" -Level "INFO" -Component "Stage1"
        }
    }
    catch {
        # Fallback method
        try {
            $recyclePath = "$env:SystemDrive\`$Recycle.Bin"
            if (Test-Path $recyclePath) {
                $cleaned = Remove-FolderContents -Path $recyclePath -Recurse
                Write-Log -Message "Recycle Bin cleaned: $(Format-FileSize $cleaned)" -Level "SUCCESS" -Component "Stage1"
                return $cleaned
            }
        }
        catch { }
    }

    return 0
}

function Clear-ThumbnailCache {
    param([switch]$DryRun)

    $path = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
    if (-not (Test-Path $path)) { return 0 }

    $thumbFiles = Get-ChildItem -Path $path -Filter "thumbcache_*.db" -ErrorAction SilentlyContinue
    $totalSize = ($thumbFiles | Measure-Object -Property Length -Sum).Sum / 1MB

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would clean thumbnail cache ($(Format-FileSize $totalSize))" -Level "INFO" -Component "Stage1"
        return 0
    }

    $cleaned = 0
    foreach ($file in $thumbFiles) {
        try {
            $size = $file.Length / 1MB
            Remove-Item -Path $file.FullName -Force -ErrorAction Stop
            $cleaned += $size
        }
        catch { }
    }

    Write-Log -Message "Thumbnail cache cleaned: $(Format-FileSize $cleaned)" -Level "SUCCESS" -Component "Stage1"
    return $cleaned
}

function Clear-ErrorReports {
    param([switch]$DryRun)

    $paths = @(
        "$env:LOCALAPPDATA\Microsoft\Windows\WER",
        "$env:ProgramData\Microsoft\Windows\WER",
        "$env:LOCALAPPDATA\CrashDumps"
    )

    $totalCleaned = 0
    foreach ($path in $paths) {
        if (Test-Path $path) {
            $size = Get-FolderSize -Path $path
            if ($DryRun) {
                Write-Log -Message "[DRY RUN] Would clean error reports at $path" -Level "INFO" -Component "Stage1"
            }
            else {
                $cleaned = Remove-FolderContents -Path $path -Recurse
                $totalCleaned += $cleaned
            }
        }
    }

    Write-Log -Message "Error reports cleaned: $(Format-FileSize $totalCleaned)" -Level "SUCCESS" -Component "Stage1"
    return $totalCleaned
}

function Clear-DeliveryOptimization {
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would clear Delivery Optimization cache" -Level "INFO" -Component "Stage1"
        return 0
    }

    try {
        Delete-DeliveryOptimizationCache -Force -ErrorAction SilentlyContinue
        Write-Log -Message "Delivery Optimization cache cleared" -Level "SUCCESS" -Component "Stage1"
    }
    catch {
        # Manual fallback
        $path = "$env:SystemRoot\SoftwareDistribution\DeliveryOptimization"
        if (Test-Path $path) {
            $cleaned = Remove-FolderContents -Path $path -Recurse
            Write-Log -Message "DO cache cleaned: $(Format-FileSize $cleaned)" -Level "SUCCESS" -Component "Stage1"
            return $cleaned
        }
    }

    return 0
}

function Clear-MemoryDumps {
    param([switch]$DryRun)

    $paths = @(
        "$env:SystemRoot\Minidump",
        "$env:SystemRoot\MEMORY.DMP",
        "$env:LOCALAPPDATA\CrashDumps"
    )

    $totalCleaned = 0
    foreach ($path in $paths) {
        if (Test-Path $path) {
            if ((Get-Item $path).PSIsContainer) {
                $size = Get-FolderSize -Path $path
                if ($DryRun) {
                    Write-Log -Message "[DRY RUN] Would clean dumps at $path ($(Format-FileSize $size))" -Level "INFO" -Component "Stage1"
                }
                else {
                    $cleaned = Remove-FolderContents -Path $path -Recurse
                    $totalCleaned += $cleaned
                }
            }
            else {
                $size = (Get-Item $path).Length / 1MB
                if ($DryRun) {
                    Write-Log -Message "[DRY RUN] Would remove $path ($(Format-FileSize $size))" -Level "INFO" -Component "Stage1"
                }
                else {
                    try {
                        Remove-Item -Path $path -Force -ErrorAction Stop
                        $totalCleaned += $size
                    }
                    catch { }
                }
            }
        }
    }

    Write-Log -Message "Memory dumps cleaned: $(Format-FileSize $totalCleaned)" -Level "SUCCESS" -Component "Stage1"
    return $totalCleaned
}

function Clear-OldEventLogs {
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would clear old event logs" -Level "INFO" -Component "Stage1"
        return 0
    }

    try {
        $logs = Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | Where-Object { $_.RecordCount -gt 0 }
        $cleared = 0
        foreach ($log in $logs) {
            try {
                [System.Diagnostics.Eventing.Reader.EventLogSession]::GlobalSession.ClearLog($log.LogName)
                $cleared++
            }
            catch { }
        }
        Write-Log -Message "Cleared $cleared event logs" -Level "SUCCESS" -Component "Stage1"
    }
    catch {
        Write-Log -Message "Error clearing event logs: $_" -Level "WARN" -Component "Stage1"
    }

    return 0
}

function Clear-Prefetch {
    param([switch]$DryRun)

    $path = "$env:SystemRoot\Prefetch"
    if (-not (Test-Path $path)) { return 0 }

    $size = Get-FolderSize -Path $path
    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would clean prefetch ($(Format-FileSize $size))" -Level "INFO" -Component "Stage1"
        return 0
    }

    $cleaned = Remove-FolderContents -Path $path -Recurse
    Write-Log -Message "Prefetch cleaned: $(Format-FileSize $cleaned)" -Level "SUCCESS" -Component "Stage1"
    return $cleaned
}

function Clear-FontCache {
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would rebuild font cache" -Level "INFO" -Component "Stage1"
        return 0
    }

    try {
        Stop-Service -Name "FontCache" -Force -ErrorAction SilentlyContinue
        $fontCachePath = "$env:SystemRoot\ServiceProfiles\LocalService\AppData\Local\FontCache"
        $cleaned = 0
        if (Test-Path $fontCachePath) {
            $cleaned = Remove-FolderContents -Path $fontCachePath -Recurse
        }
        Start-Service -Name "FontCache" -ErrorAction SilentlyContinue
        Write-Log -Message "Font cache rebuilt: $(Format-FileSize $cleaned)" -Level "SUCCESS" -Component "Stage1"
        return $cleaned
    }
    catch {
        Start-Service -Name "FontCache" -ErrorAction SilentlyContinue
        return 0
    }
}

function Clear-InstallerOrphans {
    param([switch]$DryRun)

    $path = "$env:SystemRoot\Installer\`$PatchCache`$"
    if (-not (Test-Path $path)) {
        Write-Log -Message "No installer orphans found" -Level "INFO" -Component "Stage1"
        return 0
    }

    $size = Get-FolderSize -Path $path
    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would clean installer orphans ($(Format-FileSize $size))" -Level "INFO" -Component "Stage1"
        return 0
    }

    $cleaned = Remove-FolderContents -Path $path -Recurse
    Write-Log -Message "Installer orphans cleaned: $(Format-FileSize $cleaned)" -Level "SUCCESS" -Component "Stage1"
    return $cleaned
}

function Clear-CryptNetCache {
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would clear CryptNet SSL cache" -Level "INFO" -Component "Stage1"
        return 0
    }

    try {
        $output = & certutil -URLcache * delete 2>&1
        Write-Log -Message "CryptNet SSL certificate cache cleared" -Level "SUCCESS" -Component "Stage1"
        return 0  # Size not easily measurable
    }
    catch {
        Write-Log -Message "CryptNet cache clear failed: $_" -Level "WARN" -Component "Stage1"
        return 0
    }
}

function Clear-BranchCacheData {
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would flush BranchCache" -Level "INFO" -Component "Stage1"
        return
    }

    try {
        & netsh branchcache flush 2>&1 | Out-Null
        Write-Log -Message "BranchCache flushed" -Level "SUCCESS" -Component "Stage1"
    }
    catch {
        Write-Log -Message "BranchCache flush not available (feature not installed)" -Level "INFO" -Component "Stage1"
    }
}

function Invoke-DiskCleanup {
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would run Windows Disk Cleanup" -Level "INFO" -Component "Stage1"
        return 0
    }

    try {
        # Configure cleanmgr categories via registry (sageset)
        $cleanupKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
        $categories = @(
            "Active Setup Temp Folders",
            "Delivery Optimization Files",
            "Device Driver Packages",
            "Downloaded Program Files",
            "Internet Cache Files",
            "Old ChkDsk Files",
            "Previous Installations",
            "Recycle Bin",
            "Setup Log Files",
            "System error memory dump files",
            "System error minidump files",
            "Temporary Files",
            "Temporary Setup Files",
            "Thumbnail Cache",
            "Update Cleanup",
            "Upgrade Discarded Files",
            "Windows Defender",
            "Windows Error Reporting Archive Files",
            "Windows Error Reporting Queue Files",
            "Windows Error Reporting System Archive Files",
            "Windows Error Reporting System Queue Files",
            "Windows ESD installation files",
            "Windows Upgrade Log Files"
        )

        foreach ($cat in $categories) {
            $catPath = Join-Path $cleanupKey $cat
            if (Test-Path $catPath) {
                Set-ItemProperty -Path $catPath -Name "StateFlags0100" -Value 2 -Type DWord -ErrorAction SilentlyContinue
            }
        }

        # Run cleanmgr with our configuration (non-interactive)
        Write-Log -Message "Running Windows Disk Cleanup (this may take a few minutes)..." -Level "INFO" -Component "Stage1"
        $proc = Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:100" -PassThru -WindowStyle Hidden
        $proc | Wait-Process -Timeout 300 -ErrorAction SilentlyContinue

        if (-not $proc.HasExited) {
            $proc | Stop-Process -Force -ErrorAction SilentlyContinue
            Write-Log -Message "Disk Cleanup timed out after 5 minutes" -Level "WARN" -Component "Stage1"
        }
        else {
            Write-Log -Message "Windows Disk Cleanup completed" -Level "SUCCESS" -Component "Stage1"
        }

        return 0  # cleanmgr doesn't report how much it cleaned
    }
    catch {
        Write-Log -Message "Disk Cleanup failed: $_" -Level "WARN" -Component "Stage1"
        return 0
    }
}

function Clear-IISLogs {
    param([switch]$DryRun)

    $iisLogPaths = @(
        "$env:SystemDrive\inetpub\logs\LogFiles",
        "$env:SystemRoot\System32\LogFiles\HTTPERR",
        "$env:SystemRoot\System32\LogFiles\W3SVC1"
    )

    $totalCleaned = 0
    foreach ($path in $iisLogPaths) {
        if (Test-Path $path) {
            $size = Get-FolderSize -Path $path
            if ($size -gt 0) {
                if ($DryRun) {
                    Write-Log -Message "[DRY RUN] Would clean IIS logs: $path ($(Format-FileSize $size))" -Level "INFO" -Component "Stage1"
                }
                else {
                    # Only delete logs older than 30 days
                    $oldFiles = Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                        Where-Object { -not $_.PSIsContainer -and $_.LastWriteTime -lt (Get-Date).AddDays(-30) }
                    $cleaned = 0
                    foreach ($file in $oldFiles) {
                        try {
                            $cleaned += $file.Length / 1MB
                            Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                        }
                        catch { }
                    }
                    if ($cleaned -gt 0) {
                        Write-Log -Message "Cleaned IIS logs (>30 days): $(Format-FileSize $cleaned)" -Level "SUCCESS" -Component "Stage1"
                    }
                    $totalCleaned += $cleaned
                }
            }
        }
    }

    if ($totalCleaned -eq 0 -and -not $DryRun) {
        Write-Log -Message "No old IIS/HTTP logs found" -Level "INFO" -Component "Stage1"
    }

    return $totalCleaned
}

function Clear-AllUserTemps {
    param([switch]$DryRun)

    $totalCleaned = 0
    $usersPath = Split-Path $env:USERPROFILE -Parent

    try {
        $userFolders = Get-ChildItem -Path $usersPath -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notin @("Default", "Default User", "Public", "All Users") }

        foreach ($user in $userFolders) {
            $tempPath = Join-Path $user.FullName "AppData\Local\Temp"
            if ((Test-Path $tempPath) -and ($user.Name -ne $env:USERNAME)) {
                $size = Get-FolderSize -Path $tempPath
                if ($size -gt 10) {  # Only bother if > 10 MB
                    if ($DryRun) {
                        Write-Log -Message "[DRY RUN] Would clean temp for user $($user.Name) ($(Format-FileSize $size))" -Level "INFO" -Component "Stage1"
                    }
                    else {
                        $cleaned = Remove-FolderContents -Path $tempPath -Recurse
                        if ($cleaned -gt 0) {
                            Write-Log -Message "Cleaned temp for $($user.Name): $(Format-FileSize $cleaned)" -Level "SUCCESS" -Component "Stage1"
                            $totalCleaned += $cleaned
                        }
                    }
                }
            }
        }
    }
    catch { }

    return $totalCleaned
}

function Clear-WindowsOld {
    param([switch]$DryRun)

    $path = "$env:SystemDrive\Windows.old"
    if (-not (Test-Path $path)) {
        Write-Log -Message "No Windows.old folder found" -Level "INFO" -Component "Stage1"
        return 0
    }

    $size = Get-FolderSize -Path $path

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would remove Windows.old ($(Format-FileSize $size))" -Level "INFO" -Component "Stage1"
        return 0
    }

    try {
        # Take ownership and remove
        & takeown /F $path /R /A /D Y 2>&1 | Out-Null
        & icacls $path /grant Administrators:F /T /C /Q 2>&1 | Out-Null
        Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
        Write-Log -Message "Removed Windows.old: $(Format-FileSize $size)" -Level "SUCCESS" -Component "Stage1"
        return $size
    }
    catch {
        Write-Log -Message "Could not fully remove Windows.old: $_" -Level "WARN" -Component "Stage1"
        return 0
    }
}

Export-ModuleMember -Function Invoke-Stage1

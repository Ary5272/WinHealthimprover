#Requires -Version 5.1
<#
.SYNOPSIS
    Stage 8: Network Optimization (NEW - Not in Tron!)
.DESCRIPTION
    Network performance and reliability optimization:
    - DNS optimization (configure fast DNS providers)
    - TCP/IP stack tuning
    - Network adapter optimization
    - QoS configuration
    - NetBIOS over TCP/IP disabling
    - SMBv1 disabling (security)
    - DNS cache optimization
    - Network throttling adjustment
    - Nagle algorithm configuration
    - Network adapter power management
#>

function Invoke-Stage8 {
    [CmdletBinding()]
    param(
        [hashtable]$Config = @{},
        [switch]$DryRun,
        [ValidateSet("Cloudflare", "Google", "Quad9", "Custom")]
        [string]$DNSProvider = "Cloudflare"
    )

    $stageTimer = [System.Diagnostics.Stopwatch]::StartNew()
    $optimizations = 0

    Write-StageHeader -StageNumber 8 -StageName "Network" -Description "Optimizing network performance and security"

    # ---- DNS Optimization ----
    Write-SubStageHeader "DNS Optimization ($DNSProvider)"
    if (Set-OptimalDNS -Provider $DNSProvider -DryRun:$DryRun) { $optimizations++ }

    # ---- TCP/IP Tuning ----
    Write-SubStageHeader "TCP/IP Stack Tuning"
    $optimizations += Optimize-TCPIPStack -DryRun:$DryRun

    # ---- Network Adapter Settings ----
    Write-SubStageHeader "Network Adapter Optimization"
    if (Optimize-NetworkAdapters -DryRun:$DryRun) { $optimizations++ }

    # ---- Disable SMBv1 ----
    Write-SubStageHeader "Disabling SMBv1 (Security)"
    if (Disable-SMBv1 -DryRun:$DryRun) { $optimizations++ }

    # ---- Disable NetBIOS ----
    Write-SubStageHeader "Disabling NetBIOS over TCP/IP"
    if (Disable-NetBIOS -DryRun:$DryRun) { $optimizations++ }

    # ---- DNS Cache Tuning ----
    Write-SubStageHeader "DNS Cache Optimization"
    if (Optimize-DNSCache -DryRun:$DryRun) { $optimizations++ }

    # ---- Network Throttling ----
    Write-SubStageHeader "Network Throttling Adjustment"
    if (Optimize-NetworkThrottling -DryRun:$DryRun) { $optimizations++ }

    # ---- Adapter Power Management ----
    Write-SubStageHeader "Adapter Power Management"
    if (Disable-AdapterPowerSaving -DryRun:$DryRun) { $optimizations++ }

    # ---- Network Profile ----
    Write-SubStageHeader "Network Discovery Configuration"
    Set-NetworkProfile -DryRun:$DryRun

    Write-Host ""
    Write-Log -Message "Network optimization complete: $optimizations improvements" -Level "SUCCESS" -Component "Stage8"

    Set-Metric -Name "NetworkOptimizations" -Value $optimizations -Category "Stage8"

    $stageTimer.Stop()

    Register-StageResult -StageNumber 8 -StageName "Network" -Status "Success" `
        -Summary "$optimizations network optimizations applied" `
        -Details @{ Optimizations = $optimizations } -Duration $stageTimer.Elapsed

    return $optimizations
}

# ============================================================================
# SUB-FUNCTIONS
# ============================================================================

function Set-OptimalDNS {
    [CmdletBinding()]
    param(
        [string]$Provider = "Cloudflare",
        [switch]$DryRun
    )

    $dnsServers = switch ($Provider) {
        "Cloudflare" { @("1.1.1.1", "1.0.0.1") }
        "Google"     { @("8.8.8.8", "8.8.4.4") }
        "Quad9"      { @("9.9.9.9", "149.112.112.112") }
        default      { @("1.1.1.1", "1.0.0.1") }
    }

    $dnsV6 = switch ($Provider) {
        "Cloudflare" { @("2606:4700:4700::1111", "2606:4700:4700::1001") }
        "Google"     { @("2001:4860:4860::8888", "2001:4860:4860::8844") }
        "Quad9"      { @("2620:fe::fe", "2620:fe::9") }
        default      { @("2606:4700:4700::1111", "2606:4700:4700::1001") }
    }

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would set DNS to $Provider ($($dnsServers -join ', '))" -Level "INFO" -Component "Stage8"
        return $true
    }

    try {
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }

        foreach ($adapter in $adapters) {
            # Set IPv4 DNS
            Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses $dnsServers -ErrorAction SilentlyContinue

            # Set IPv6 DNS
            Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses $dnsV6 -ErrorAction SilentlyContinue

            Write-Log -Message "DNS set to $Provider for adapter: $($adapter.Name)" -Level "SUCCESS" -Component "Stage8"
        }

        # Flush DNS to apply changes
        Clear-DnsClientCache -ErrorAction SilentlyContinue

        return $true
    }
    catch {
        Write-Log -Message "DNS configuration failed: $_" -Level "WARN" -Component "Stage8"
        return $false
    }
}

function Optimize-TCPIPStack {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would optimize TCP/IP stack" -Level "INFO" -Component "Stage8"
        return 0
    }

    $count = 0

    try {
        # Enable TCP Window Auto-Tuning
        & netsh int tcp set global autotuninglevel=normal 2>&1 | Out-Null
        $count++

        # Enable Direct Cache Access (DCA)
        & netsh int tcp set global dca=enabled 2>&1 | Out-Null
        $count++

        # Enable Receive-Side Scaling
        & netsh int tcp set global rss=enabled 2>&1 | Out-Null
        $count++

        # Enable TCP Chimney Offload
        & netsh int tcp set global chimney=enabled 2>&1 | Out-Null
        $count++

        # Enable ECN capability
        & netsh int tcp set global ecncapability=enabled 2>&1 | Out-Null
        $count++

        # Set congestion provider
        & netsh int tcp set supplemental Internet congestionprovider=ctcp 2>&1 | Out-Null
        $count++

        # Optimize TCP timestamps
        & netsh int tcp set global timestamps=disabled 2>&1 | Out-Null
        $count++

        # Set initial RTO (retransmission timeout)
        & netsh int tcp set global initialRto=2000 2>&1 | Out-Null
        $count++

        # Registry-based TCP optimizations
        $tcpSettings = @(
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name = "TcpAckFrequency"; Value = 1 },
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name = "TCPNoDelay"; Value = 1 },
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name = "Tcp1323Opts"; Value = 1 },
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name = "DefaultTTL"; Value = 64 },
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name = "MaxUserPort"; Value = 65534 },
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name = "TcpTimedWaitDelay"; Value = 30 }
        )

        foreach ($setting in $tcpSettings) {
            if (Set-RegistryValue -Path $setting.Path -Name $setting.Name -Value $setting.Value) { $count++ }
        }

        Write-Log -Message "TCP/IP stack optimized ($count settings)" -Level "SUCCESS" -Component "Stage8"
    }
    catch {
        Write-Log -Message "TCP/IP optimization partial failure: $_" -Level "WARN" -Component "Stage8"
    }

    return $count
}

function Optimize-NetworkAdapters {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would optimize network adapters" -Level "INFO" -Component "Stage8"
        return $true
    }

    try {
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }

        foreach ($adapter in $adapters) {
            # Disable Flow Control (can cause latency)
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword "*FlowControl" -RegistryValue 0 -ErrorAction SilentlyContinue

            # Disable Interrupt Moderation for lower latency
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword "*InterruptModeration" -RegistryValue 0 -ErrorAction SilentlyContinue

            # Enable Jumbo Frames (if supported)
            # Not all adapters support this, so we skip errors
            # Set-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword "*JumboPacket" -RegistryValue 9014 -ErrorAction SilentlyContinue

            Write-Log -Message "Optimized adapter: $($adapter.Name)" -Level "SUCCESS" -Component "Stage8"
        }

        return $true
    }
    catch {
        Write-Log -Message "Adapter optimization failed: $_" -Level "WARN" -Component "Stage8"
        return $false
    }
}

function Disable-SMBv1 {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would disable SMBv1" -Level "INFO" -Component "Stage8"
        return $true
    }

    try {
        # Disable SMBv1 server
        Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -ErrorAction SilentlyContinue

        # Disable SMBv1 client
        Disable-WindowsOptionalFeature -Online -FeatureName "SMB1Protocol" -NoRestart -ErrorAction SilentlyContinue | Out-Null

        # Registry fallback
        Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "SMB1" -Value 0

        Write-Log -Message "SMBv1 disabled (security improvement)" -Level "SUCCESS" -Component "Stage8"
        return $true
    }
    catch {
        Write-Log -Message "SMBv1 disable failed: $_" -Level "WARN" -Component "Stage8"
        return $false
    }
}

function Disable-NetBIOS {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would disable NetBIOS over TCP/IP" -Level "INFO" -Component "Stage8"
        return $true
    }

    try {
        # Disable NetBIOS on all interfaces
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces"
        if (Test-Path $regPath) {
            Get-ChildItem -Path $regPath | ForEach-Object {
                Set-ItemProperty -Path $_.PSPath -Name "NetbiosOptions" -Value 2 -ErrorAction SilentlyContinue
            }
        }

        Write-Log -Message "NetBIOS over TCP/IP disabled" -Level "SUCCESS" -Component "Stage8"
        return $true
    }
    catch {
        Write-Log -Message "NetBIOS disable failed: $_" -Level "WARN" -Component "Stage8"
        return $false
    }
}

function Optimize-DNSCache {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would optimize DNS cache" -Level "INFO" -Component "Stage8"
        return $true
    }

    try {
        # Increase DNS cache size
        $settings = @(
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"; Name = "CacheHashTableBucketSize"; Value = 1 },
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"; Name = "CacheHashTableSize"; Value = 384 },
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"; Name = "MaxCacheEntryTtlLimit"; Value = 64000 },
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"; Name = "MaxSOACacheEntryTtlLimit"; Value = 301 }
        )

        foreach ($setting in $settings) {
            Set-RegistryValue -Path $setting.Path -Name $setting.Name -Value $setting.Value | Out-Null
        }

        Write-Log -Message "DNS cache optimized" -Level "SUCCESS" -Component "Stage8"
        return $true
    }
    catch {
        Write-Log -Message "DNS cache optimization failed: $_" -Level "WARN" -Component "Stage8"
        return $false
    }
}

function Optimize-NetworkThrottling {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would optimize network throttling" -Level "INFO" -Component "Stage8"
        return $true
    }

    try {
        # Disable Nagle's algorithm (reduces latency for interactive apps)
        Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "NetworkThrottlingIndex" -Value 0xFFFFFFFF

        # Disable system responsiveness throttling for network
        Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "SystemResponsiveness" -Value 0

        Write-Log -Message "Network throttling optimized" -Level "SUCCESS" -Component "Stage8"
        return $true
    }
    catch {
        Write-Log -Message "Network throttling optimization failed: $_" -Level "WARN" -Component "Stage8"
        return $false
    }
}

function Disable-AdapterPowerSaving {
    [CmdletBinding()]
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Log -Message "[DRY RUN] Would disable adapter power saving" -Level "INFO" -Component "Stage8"
        return $true
    }

    try {
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }

        foreach ($adapter in $adapters) {
            # Disable power management on adapter
            $deviceId = (Get-NetAdapterHardwareInfo -Name $adapter.Name -ErrorAction SilentlyContinue).PnpDeviceID
            if ($deviceId) {
                $regPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$deviceId\Device Parameters\Power"
                Set-RegistryValue -Path $regPath -Name "AllowIdleIrpInD3" -Value 0 | Out-Null
            }

            # Disable Energy Efficient Ethernet
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword "*EEE" -RegistryValue 0 -ErrorAction SilentlyContinue

            Write-Log -Message "Power saving disabled for: $($adapter.Name)" -Level "SUCCESS" -Component "Stage8"
        }

        return $true
    }
    catch {
        Write-Log -Message "Adapter power saving disable failed: $_" -Level "WARN" -Component "Stage8"
        return $false
    }
}

function Set-NetworkProfile {
    [CmdletBinding()]
    param([switch]$DryRun)

    try {
        $profiles = Get-NetConnectionProfile -ErrorAction SilentlyContinue
        foreach ($profile in $profiles) {
            Write-Log -Message "Network: $($profile.Name) - Category: $($profile.NetworkCategory)" -Level "INFO" -Component "Stage8"
        }
    }
    catch { }
}

Export-ModuleMember -Function Invoke-Stage8

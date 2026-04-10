#Requires -Version 5.1
<#
.SYNOPSIS
    WinHealthImprover - Structured Logging Framework
.DESCRIPTION
    Provides comprehensive logging with console output, file logging,
    and structured data collection for HTML report generation.
#>

# ============================================================================
# LOGGING CONFIGURATION
# ============================================================================

$script:LogConfig = @{
    LogDir       = ""
    LogFile      = ""
    ErrorLogFile = ""
    ConsoleWidth = 100
    Initialized  = $false
    StartTime    = $null
    Entries      = [System.Collections.ArrayList]::new()
    StageResults = [System.Collections.ArrayList]::new()
    Metrics      = @{}
}

# ============================================================================
# INITIALIZATION
# ============================================================================

function Initialize-Logging {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$LogDirectory,

        [string]$RunId = (Get-Date -Format "yyyyMMdd_HHmmss")
    )

    $script:LogConfig.LogDir = $LogDirectory
    $script:LogConfig.LogFile = Join-Path $LogDirectory "WinHealthImprover_$RunId.log"
    $script:LogConfig.ErrorLogFile = Join-Path $LogDirectory "WinHealthImprover_${RunId}_errors.log"
    $script:LogConfig.StartTime = Get-Date
    $script:LogConfig.Initialized = $true

    if (-not (Test-Path $LogDirectory)) {
        New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
    }

    $header = @"
================================================================================
  WinHealthImprover Log
  Started: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
  Computer: $env:COMPUTERNAME
  User: $env:USERNAME
  OS: $((Get-CimInstance Win32_OperatingSystem).Caption)
================================================================================
"@
    $header | Out-File -FilePath $script:LogConfig.LogFile -Encoding UTF8
    return $script:LogConfig.LogFile
}

# ============================================================================
# CORE LOGGING FUNCTIONS
# ============================================================================

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Message,

        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS", "DEBUG", "STAGE", "SUBSTAGE")]
        [string]$Level = "INFO",

        [string]$Component = "General",

        [switch]$NoConsole,
        [switch]$NoFile
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] [$Component] $Message"

    # Store structured entry
    $entry = @{
        Timestamp = $timestamp
        Level     = $Level
        Component = $Component
        Message   = $Message
    }
    [void]$script:LogConfig.Entries.Add($entry)

    # File logging
    if (-not $NoFile -and $script:LogConfig.Initialized) {
        $logLine | Out-File -FilePath $script:LogConfig.LogFile -Append -Encoding UTF8

        if ($Level -eq "ERROR") {
            $logLine | Out-File -FilePath $script:LogConfig.ErrorLogFile -Append -Encoding UTF8
        }
    }

    # Console output with colors
    if (-not $NoConsole) {
        $color = switch ($Level) {
            "INFO"     { "White" }
            "WARN"     { "Yellow" }
            "ERROR"    { "Red" }
            "SUCCESS"  { "Green" }
            "DEBUG"    { "DarkGray" }
            "STAGE"    { "Cyan" }
            "SUBSTAGE" { "DarkCyan" }
            default    { "White" }
        }

        $prefix = switch ($Level) {
            "INFO"     { "  [*]" }
            "WARN"     { "  [!]" }
            "ERROR"    { "  [X]" }
            "SUCCESS"  { "  [+]" }
            "DEBUG"    { "  [.]" }
            "STAGE"    { "" }
            "SUBSTAGE" { "    >>>" }
            default    { "  [-]" }
        }

        Write-Host "$prefix $Message" -ForegroundColor $color
    }
}

function Write-StageHeader {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$StageNumber,

        [Parameter(Mandatory)]
        [string]$StageName,

        [string]$Description = ""
    )

    $header = @"

================================================================================
  STAGE $StageNumber : $($StageName.ToUpper())
  $Description
================================================================================
"@

    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor Cyan
    Write-Host "  STAGE $StageNumber : $($StageName.ToUpper())" -ForegroundColor Cyan
    if ($Description) {
        Write-Host "  $Description" -ForegroundColor DarkCyan
    }
    Write-Host ("=" * 80) -ForegroundColor Cyan
    Write-Host ""

    if ($script:LogConfig.Initialized) {
        $header | Out-File -FilePath $script:LogConfig.LogFile -Append -Encoding UTF8
    }
}

function Write-SubStageHeader {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    Write-Host ""
    Write-Host "    --- $Name ---" -ForegroundColor DarkCyan
    Write-Log -Message $Name -Level "SUBSTAGE"
}

function Write-ProgressBar {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$PercentComplete,

        [string]$Activity = "Processing",
        [string]$Status = ""
    )

    $barLength = 40
    $filled = [math]::Floor($barLength * $PercentComplete / 100)
    $empty = $barLength - $filled
    $bar = ("[" + ("█" * $filled) + ("░" * $empty) + "]")

    Write-Host "`r  $bar $PercentComplete% - $Activity $Status" -NoNewline -ForegroundColor White

    if ($PercentComplete -ge 100) {
        Write-Host ""
    }
}

# ============================================================================
# STAGE RESULT TRACKING
# ============================================================================

function Register-StageResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$StageNumber,

        [Parameter(Mandatory)]
        [string]$StageName,

        [Parameter(Mandatory)]
        [ValidateSet("Success", "Warning", "Error", "Skipped")]
        [string]$Status,

        [string]$Summary = "",

        [hashtable]$Details = @{},

        [TimeSpan]$Duration = [TimeSpan]::Zero
    )

    $result = @{
        StageNumber = $StageNumber
        StageName   = $StageName
        Status      = $Status
        Summary     = $Summary
        Details     = $Details
        Duration    = $Duration
        Timestamp   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }

    [void]$script:LogConfig.StageResults.Add($result)
}

function Get-StageResults {
    return $script:LogConfig.StageResults
}

function Get-LogEntries {
    return $script:LogConfig.Entries
}

# ============================================================================
# METRIC TRACKING
# ============================================================================

function Set-Metric {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        $Value,

        [string]$Category = "General"
    )

    if (-not $script:LogConfig.Metrics.ContainsKey($Category)) {
        $script:LogConfig.Metrics[$Category] = @{}
    }
    $script:LogConfig.Metrics[$Category][$Name] = $Value
}

function Get-Metrics {
    return $script:LogConfig.Metrics
}

function Get-LogFilePath {
    return $script:LogConfig.LogFile
}

function Get-LogStartTime {
    return $script:LogConfig.StartTime
}

# ============================================================================
# BANNER
# ============================================================================

function Show-Banner {
    $banner = @"

    ██╗    ██╗██╗███╗   ██╗    ██╗  ██╗███████╗ █████╗ ██╗  ████████╗██╗  ██╗
    ██║    ██║██║████╗  ██║    ██║  ██║██╔════╝██╔══██╗██║  ╚══██╔══╝██║  ██║
    ██║ █╗ ██║██║██╔██╗ ██║    ███████║█████╗  ███████║██║     ██║   ███████║
    ██║███╗██║██║██║╚██╗██║    ██╔══██║██╔══╝  ██╔══██║██║     ██║   ██╔══██║
    ╚███╔███╔╝██║██║ ╚████║    ██║  ██║███████╗██║  ██║███████╗██║   ██║  ██║
     ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝    ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝╚═╝   ╚═╝  ╚═╝
                        ██╗███╗   ███╗██████╗ ██████╗  ██████╗ ██╗   ██╗███████╗██████╗
                        ██║████╗ ████║██╔══██╗██╔══██╗██╔═══██╗██║   ██║██╔════╝██╔══██╗
                        ██║██╔████╔██║██████╔╝██████╔╝██║   ██║██║   ██║█████╗  ██████╔╝
                        ██║██║╚██╔╝██║██╔═══╝ ██╔══██╗██║   ██║╚██╗ ██╔╝██╔══╝  ██╔══██╗
                        ██║██║ ╚═╝ ██║██║     ██║  ██║╚██████╔╝ ╚████╔╝ ███████╗██║  ██║
                        ╚═╝╚═╝     ╚═╝╚═╝     ╚═╝  ╚═╝ ╚═════╝   ╚═══╝  ╚══════╝╚═╝  ╚═╝

                    Windows System Repair, Optimization & Hardening Toolkit
                                    v1.0.0 | PowerShell Edition

"@

    Write-Host $banner -ForegroundColor Cyan
}

Export-ModuleMember -Function *

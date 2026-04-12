#Requires -Version 5.1
<#
.SYNOPSIS
    WinHealthImprover - Interactive Wizard Module
.DESCRIPTION
    Guided step-by-step mode for non-technical users. Walks through each
    decision with plain-English explanations and safe defaults.

    Features:
    - Plain-English explanations for every option
    - Risk ratings (Safe/Moderate/Advanced) for each stage
    - Smart defaults based on system scan
    - Confirmation before any destructive action
    - "Explain More" option for curious users
    - Progress tracking with friendly messages
#>

function Start-Wizard {
    <#
    .SYNOPSIS
        Launch the interactive wizard that guides users through WinHealthImprover.
    #>
    [CmdletBinding()]
    param(
        [string]$LogDirectory = ".\logs"
    )

    Clear-Host
    Show-WizardBanner

    # Step 1: Welcome & Safety Check
    $safetyResult = Show-WizardStep-Safety
    if (-not $safetyResult.Continue) { return $null }

    # Step 2: What do you want to fix?
    $goal = Show-WizardStep-Goal

    # Step 3: How aggressive?
    $aggressiveness = Show-WizardStep-Aggressiveness

    # Step 4: Build configuration from choices
    $config = Build-WizardConfig -Goal $goal -Aggressiveness $aggressiveness

    # Step 5: Show plan & confirm
    $confirmed = Show-WizardStep-Confirm -Config $config
    if (-not $confirmed) {
        Write-Host ""
        Write-Host "  No worries! Nothing was changed. You can run the wizard again anytime." -ForegroundColor Cyan
        Write-Host ""
        return $null
    }

    return $config
}

# ============================================================================
# WIZARD UI HELPERS
# ============================================================================

function Show-WizardBanner {
    Write-Host ""
    Write-Host "  +==============================================================+" -ForegroundColor Cyan
    Write-Host "  |                                                              |" -ForegroundColor Cyan
    Write-Host "  |          Welcome to WinHealthImprover!                       |" -ForegroundColor Cyan
    Write-Host "  |                                                              |" -ForegroundColor Cyan
    Write-Host "  |   This wizard will guide you step-by-step through fixing     |" -ForegroundColor Cyan
    Write-Host "  |   and optimizing your PC. No technical knowledge needed!     |" -ForegroundColor Cyan
    Write-Host "  |                                                              |" -ForegroundColor Cyan
    Write-Host "  |   Every change can be undone with one click.                 |" -ForegroundColor Green
    Write-Host "  |                                                              |" -ForegroundColor Cyan
    Write-Host "  +==============================================================+" -ForegroundColor Cyan
    Write-Host ""
}

function Read-WizardChoice {
    <#
    .SYNOPSIS
        Prompt user with a numbered menu and return their selection.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [Parameter(Mandatory)]
        [string[]]$Options,

        [int]$Default = 1
    )

    Write-Host ""
    Write-Host "  $Prompt" -ForegroundColor White
    Write-Host "  -------------------------------------------------" -ForegroundColor DarkGray
    for ($i = 0; $i -lt $Options.Count; $i++) {
        $marker = if ($i + 1 -eq $Default) { " (recommended)" } else { "" }
        Write-Host "    [$($i + 1)] $($Options[$i])$marker" -ForegroundColor Yellow
    }
    Write-Host ""

    do {
        $input = Read-Host "  Your choice (1-$($Options.Count), Enter for default)"
        if ([string]::IsNullOrWhiteSpace($input)) { return $Default }
        $num = 0
        if ([int]::TryParse($input, [ref]$num) -and $num -ge 1 -and $num -le $Options.Count) {
            return $num
        }
        Write-Host "  Please enter a number between 1 and $($Options.Count)" -ForegroundColor Red
    } while ($true)
}

function Read-WizardYesNo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [bool]$Default = $true
    )

    $hint = if ($Default) { "(Y/n)" } else { "(y/N)" }

    do {
        $input = Read-Host "  $Prompt $hint"
        if ([string]::IsNullOrWhiteSpace($input)) { return $Default }
        if ($input -match "^[Yy]") { return $true }
        if ($input -match "^[Nn]") { return $false }
        Write-Host "  Please enter Y or N" -ForegroundColor Red
    } while ($true)
}

# ============================================================================
# WIZARD STEPS
# ============================================================================

function Show-WizardStep-Safety {
    Write-Host "  STEP 1 of 5: Safety Check" -ForegroundColor Cyan
    Write-Host "  ===========================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Before we start, let's make sure your PC is ready..." -ForegroundColor White
    Write-Host ""

    # Run safety checks
    $issues = @()
    $warnings = @()

    # Check disk space
    try {
        $sysDrive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'" -ErrorAction SilentlyContinue
        if ($sysDrive) {
            $freeGB = [math]::Round($sysDrive.FreeSpace / 1GB, 1)
            if ($freeGB -lt 1) {
                $issues += "Your system drive has less than 1 GB free ($freeGB GB). Free up space first."
            }
            elseif ($freeGB -lt 3) {
                $warnings += "Your system drive has only $freeGB GB free. We'll be careful with disk space."
            }
            else {
                Write-Host "    [OK] Disk space: $freeGB GB free" -ForegroundColor Green
            }
        }
    }
    catch { }

    # Check battery
    try {
        $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
        if ($battery -and $battery.BatteryStatus -ne 2) {
            $pct = $battery.EstimatedChargeRemaining
            if ($pct -lt 20) {
                $issues += "Battery is at $pct% and not plugged in. Please connect your charger."
            }
            elseif ($pct -lt 50) {
                $warnings += "Running on battery ($pct%). We recommend plugging in."
            }
        }
        else {
            if ($battery) {
                Write-Host "    [OK] Power: Plugged in" -ForegroundColor Green
            }
            else {
                Write-Host "    [OK] Power: Desktop (no battery)" -ForegroundColor Green
            }
        }
    }
    catch { }

    # Check for installers
    $installerRunning = $false
    @("msiexec", "setup", "TiWorker") | ForEach-Object {
        if (Get-Process -Name $_ -ErrorAction SilentlyContinue) {
            $warnings += "An installer or Windows Update appears to be running. Wait for it to finish."
            $installerRunning = $true
        }
    }
    if (-not $installerRunning) {
        Write-Host "    [OK] No installers running" -ForegroundColor Green
    }

    # Check admin
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isAdmin) {
        Write-Host "    [OK] Running as Administrator" -ForegroundColor Green
    }
    else {
        $issues += "Not running as Administrator. Please right-click and 'Run as Administrator'."
    }

    # Show issues
    if ($issues.Count -gt 0) {
        Write-Host ""
        Write-Host "  Problems found:" -ForegroundColor Red
        foreach ($issue in $issues) {
            Write-Host "    [X] $issue" -ForegroundColor Red
        }
        Write-Host ""
        Write-Host "  Please fix these issues before continuing." -ForegroundColor Red
        return @{ Continue = $false }
    }

    if ($warnings.Count -gt 0) {
        Write-Host ""
        Write-Host "  Warnings:" -ForegroundColor Yellow
        foreach ($warn in $warnings) {
            Write-Host "    [!] $warn" -ForegroundColor Yellow
        }
    }

    Write-Host ""
    Write-Host "  Everything looks good! Let's continue." -ForegroundColor Green
    Write-Host ""

    $continue = Read-WizardYesNo -Prompt "Ready to proceed?" -Default $true
    return @{ Continue = $continue }
}

function Show-WizardStep-Goal {
    Write-Host ""
    Write-Host "  STEP 2 of 5: What would you like to do?" -ForegroundColor Cyan
    Write-Host "  ════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""

    $choice = Read-WizardChoice -Prompt "Pick the option that best describes what you need:" -Options @(
        "Fix My PC          - My computer is slow, broken, or acting weird",
        "Speed It Up         - Everything works but I want it faster",
        "Clean Up Junk       - Remove bloatware, temp files, and garbage",
        "Lock Down Privacy   - Stop Windows from spying on me",
        "Harden Security     - Protect me from hackers and malware",
        "The Full Treatment  - Do EVERYTHING (recommended for first run)",
        "Just Scan           - Show me what's wrong but don't change anything"
    ) -Default 6

    $goalMap = @{
        1 = "FixMyPC"
        2 = "SpeedUp"
        3 = "CleanUp"
        4 = "Privacy"
        5 = "Security"
        6 = "FullTreatment"
        7 = "ScanOnly"
    }

    $goal = $goalMap[$choice]

    # Show what this means in plain English
    $explanations = @{
        "FixMyPC"        = "We'll repair Windows files, fix broken services, clean junk, remove malware, and optimize your system."
        "SpeedUp"        = "We'll optimize startup programs, services, power settings, and network for maximum speed."
        "CleanUp"        = "We'll remove temporary files, bloatware, pre-installed junk, and free up disk space."
        "Privacy"        = "We'll disable telemetry, tracking, advertising, and tighten app permissions."
        "Security"       = "We'll harden Windows Defender, enable attack protection, and lock down your system."
        "FullTreatment"  = "We'll run every stage: clean, debloat, scan for malware, repair, update, optimize, and harden."
        "ScanOnly"       = "We'll analyze your system and show you what we'd recommend, without making any changes."
    }

    Write-Host ""
    Write-Host "  What we'll do: $($explanations[$goal])" -ForegroundColor White
    Write-Host ""

    return $goal
}

function Show-WizardStep-Aggressiveness {
    Write-Host ""
    Write-Host "  STEP 3 of 5: How cautious should we be?" -ForegroundColor Cyan
    Write-Host "  ════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""

    $choice = Read-WizardChoice -Prompt "Choose your comfort level:" -Options @(
        "Gentle    - Only make safe, easily reversible changes (best for beginners)",
        "Balanced  - Standard optimizations that work for most people",
        "Aggressive - Maximum optimization (may change some features you use)"
    ) -Default 2

    $levelMap = @{ 1 = "Gentle"; 2 = "Balanced"; 3 = "Aggressive" }
    $level = $levelMap[$choice]

    $riskInfo = @{
        "Gentle"     = "We'll only make changes that are 100% safe and easily reversible. Nothing that could break your workflow."
        "Balanced"   = "Standard optimizations that improve most PCs. Some features you rarely use may be disabled."
        "Aggressive" = "Maximum performance and privacy. Some Windows features will be removed. All changes are still reversible!"
    }

    Write-Host ""
    Write-Host "  $($riskInfo[$level])" -ForegroundColor White
    Write-Host ""

    return $level
}

function Build-WizardConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Goal,

        [Parameter(Mandatory)]
        [string]$Aggressiveness
    )

    # Map aggressiveness to optimization/privacy/security levels
    $optLevel = switch ($Aggressiveness) {
        "Gentle"     { "Balanced" }
        "Balanced"   { "Performance" }
        "Aggressive" { "MaxPerformance" }
    }

    $privLevel = switch ($Aggressiveness) {
        "Gentle"     { "Moderate" }
        "Balanced"   { "Moderate" }
        "Aggressive" { "Aggressive" }
    }

    $secLevel = switch ($Aggressiveness) {
        "Gentle"     { "Standard" }
        "Balanced"   { "Standard" }
        "Aggressive" { "Enhanced" }
    }

    # Map goal to stages
    $stages = switch ($Goal) {
        "FixMyPC"       { @(0, 1, 3, 4, 5, 6) }
        "SpeedUp"       { @(0, 1, 6, 8) }
        "CleanUp"       { @(0, 1, 2) }
        "Privacy"       { @(0, 7) }
        "Security"      { @(0, 3, 9) }
        "FullTreatment" { @(0, 1, 2, 3, 4, 5, 6, 7, 8, 9) }
        "ScanOnly"      { @() }
    }

    $dryRun = ($Goal -eq "ScanOnly")

    $config = @{
        OnlyStages         = $stages
        DryRun             = $dryRun
        OptimizationLevel  = $optLevel
        PrivacyLevel       = $privLevel
        SecurityLevel      = $secLevel
        DNSProvider        = "Cloudflare"
        QuickScan          = ($Aggressiveness -eq "Gentle")
        SkipWindowsUpdates = ($Goal -notin @("FixMyPC", "FullTreatment"))
        KeepOneDrive       = ($Aggressiveness -eq "Gentle")
        AggressiveDebloat  = ($Aggressiveness -eq "Aggressive")
        SkipChkdsk         = ($Aggressiveness -eq "Gentle")
        Goal               = $Goal
        Aggressiveness     = $Aggressiveness
        WizardMode         = $true
    }

    return $config
}

function Show-WizardStep-Confirm {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    Write-Host ""
    Write-Host "  STEP 4 of 5: Review Your Plan" -ForegroundColor Cyan
    Write-Host "  ══════════════════════════════" -ForegroundColor Cyan
    Write-Host ""

    $stageNames = @{
        0  = "Preparation       - Create restore point, backup settings"
        1  = "Temp Cleanup      - Remove junk files and caches"
        2  = "Debloat           - Remove bloatware and pre-installed junk"
        3  = "Disinfect         - Scan for malware and suspicious activity"
        4  = "Repair            - Fix Windows files and broken services"
        5  = "Patch             - Install Windows and driver updates"
        6  = "Optimize          - Speed up startup, services, and disk"
        7  = "Privacy           - Disable tracking and telemetry"
        8  = "Network           - Optimize internet speed and DNS"
        9  = "Security          - Harden system against attacks"
    }

    $riskColors = @{
        0 = "Green"; 1 = "Green"; 2 = "Yellow"; 3 = "Green";
        4 = "Yellow"; 5 = "Yellow"; 6 = "Yellow"; 7 = "Yellow";
        8 = "Yellow"; 9 = "Yellow"
    }

    $riskLabels = @{
        0 = "[SAFE]    "; 1 = "[SAFE]    "; 2 = "[MODERATE]"; 3 = "[SAFE]    ";
        4 = "[MODERATE]"; 5 = "[MODERATE]"; 6 = "[MODERATE]"; 7 = "[MODERATE]";
        8 = "[MODERATE]"; 9 = "[MODERATE]"
    }

    if ($Config.DryRun) {
        Write-Host "  Mode: PREVIEW ONLY (no changes will be made)" -ForegroundColor Cyan
    }
    else {
        Write-Host "  Mode: $($Config.Goal) ($($Config.Aggressiveness) aggressiveness)" -ForegroundColor White
    }

    Write-Host ""
    Write-Host "  Stages that will run:" -ForegroundColor White
    Write-Host "  ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray

    if ($Config.OnlyStages.Count -eq 0 -and $Config.DryRun) {
        Write-Host "    All stages (preview mode - nothing will change)" -ForegroundColor Cyan
    }
    else {
        foreach ($stageNum in ($Config.OnlyStages | Sort-Object)) {
            $name = $stageNames[$stageNum]
            $risk = $riskLabels[$stageNum]
            $color = $riskColors[$stageNum]
            Write-Host "    $risk Stage $stageNum : $name" -ForegroundColor $color
        }
    }

    Write-Host ""
    Write-Host "  Settings:" -ForegroundColor White
    Write-Host "    Optimization: $($Config.OptimizationLevel)" -ForegroundColor DarkCyan
    Write-Host "    Privacy:      $($Config.PrivacyLevel)" -ForegroundColor DarkCyan
    Write-Host "    Security:     $($Config.SecurityLevel)" -ForegroundColor DarkCyan
    Write-Host "    DNS:          $($Config.DNSProvider)" -ForegroundColor DarkCyan
    Write-Host ""

    Write-Host "  ┌─────────────────────────────────────────────────────────┐" -ForegroundColor Green
    Write-Host "  │  ALL changes are tracked and can be reversed at any     │" -ForegroundColor Green
    Write-Host "  │  time by running: .\Undo-Changes.ps1                    │" -ForegroundColor Green
    Write-Host "  └─────────────────────────────────────────────────────────┘" -ForegroundColor Green
    Write-Host ""

    return (Read-WizardYesNo -Prompt "Start the process?" -Default $true)
}

function Show-WizardProgress {
    <#
    .SYNOPSIS
        Show a friendly progress message during stage execution.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$StageNumber,

        [Parameter(Mandatory)]
        [int]$TotalStages,

        [Parameter(Mandatory)]
        [string]$Description
    )

    $pct = [math]::Round(($StageNumber / $TotalStages) * 100)
    $bar = "[" + ("=" * [math]::Floor($pct / 5)) + (" " * (20 - [math]::Floor($pct / 5))) + "]"

    $friendlyMessages = @{
        0  = "Getting everything ready..."
        1  = "Taking out the trash..."
        2  = "Removing junk apps..."
        3  = "Checking for bad guys..."
        4  = "Fixing broken things..."
        5  = "Installing updates..."
        6  = "Making things faster..."
        7  = "Locking down your privacy..."
        8  = "Tuning your internet..."
        9  = "Building your defenses..."
        10 = "Wrapping up..."
    }

    $friendly = if ($friendlyMessages.ContainsKey($StageNumber)) {
        $friendlyMessages[$StageNumber]
    } else { $Description }

    Write-Host ""
    Write-Host "  $bar $pct% - $friendly" -ForegroundColor Cyan
    Write-Host ""
}

function Show-WizardComplete {
    <#
    .SYNOPSIS
        Show a friendly completion message after all stages finish.
    #>
    [CmdletBinding()]
    param(
        [hashtable]$HealthBefore,
        [hashtable]$HealthAfter,
        [string]$ReportPath,
        [string]$JournalPath
    )

    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "  ║                                                              ║" -ForegroundColor Green
    Write-Host "  ║                    All Done!                                 ║" -ForegroundColor Green
    Write-Host "  ║                                                              ║" -ForegroundColor Green
    Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""

    if ($HealthBefore -and $HealthAfter) {
        $improvement = $HealthAfter.Score - $HealthBefore.Score
        Write-Host "  Your PC health score:" -ForegroundColor White
        Write-Host "    Before: $($HealthBefore.Score)/100 (Grade: $($HealthBefore.Grade))" -ForegroundColor Yellow
        Write-Host "    After:  $($HealthAfter.Score)/100 (Grade: $($HealthAfter.Grade))" -ForegroundColor Green

        if ($improvement -gt 0) {
            Write-Host "    Improved by $improvement points!" -ForegroundColor Green
        }
        Write-Host ""
    }

    Write-Host "  What's next:" -ForegroundColor White
    Write-Host "    1. Restart your computer to apply all changes" -ForegroundColor DarkCyan
    Write-Host "    2. If anything seems wrong, run: .\Undo-Changes.ps1" -ForegroundColor DarkCyan

    if ($ReportPath) {
        Write-Host "    3. View detailed report: $ReportPath" -ForegroundColor DarkCyan
    }

    Write-Host ""
    Write-Host "  Thanks for using WinHealthImprover!" -ForegroundColor Cyan
    Write-Host ""
}

Export-ModuleMember -Function Start-Wizard, Show-WizardProgress, Show-WizardComplete,
    Read-WizardChoice, Read-WizardYesNo, Build-WizardConfig

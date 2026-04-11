# WinHealthImprover

**Windows System Repair, Optimization & Hardening Toolkit**

A modern, comprehensive PowerShell-based system repair and optimization tool for Windows 10/11. Inspired by [Tron](https://github.com/bmrf/tron) but rebuilt from the ground up with PowerShell, additional stages, a GUI, and smarter detection.

## Why WinHealthImprover?

| Feature | Tron | WinHealthImprover |
|---------|------|-------------------|
| Language | Batch (.bat) | PowerShell 5.1+ |
| GUI | None | WPF GUI with real-time progress |
| Stages | 9 | 11 (added Privacy, Network, Security) |
| Health Scoring | No | Before/after health scores (0-100) |
| HTML Reports | No | Full HTML reports with metrics |
| Dry Run Mode | No | Preview all changes safely |
| Granular Control | Limited flags | Per-stage, per-task toggles |
| Privacy Hardening | Basic | Comprehensive telemetry/tracking removal |
| Network Optimization | None | DNS, TCP/IP tuning, adapter optimization |
| Security Hardening | None | ASR rules, credential protection, audit policies |
| Smart Detection | No | Auto-detects SSD/HDD, adjusts behavior |
| Structured Logging | Basic | Multi-level structured logging with metrics |
| Configuration | None | JSON configuration file |
| Modular Architecture | Monolithic | Importable PowerShell modules |
| Undo/Rollback | None | Full SafetyNet undo system |
| Interactive Wizard | None | Guided step-by-step wizard |
| Quick-Fix Presets | None | One-click Fix My PC, Speed Up, Privacy Lock, etc. |
| System Analyzer | None | Smart scan with prioritized recommendations |
| App Whitelist | None | Protect specific apps from removal |
| Confirmation Prompts | None | Ask before removing each app (non-auto mode) |

## Stages

| Stage | Name | Description |
|-------|------|-------------|
| 0 | **Prep** | System restore point, kill interfering processes, NTP sync, disable sleep |
| 1 | **TempClean** | Clean temp files, browser caches, Windows Update cache, event logs, memory dumps |
| 2 | **Debloat** | Remove UWP bloatware, OEM crapware, OneDrive, Cortana, suggested content |
| 3 | **Disinfect** | Windows Defender update + scan, malicious process detection, startup audit |
| 4 | **Repair** | DISM, SFC, Windows Update reset, WMI repair, network stack, print spooler |
| 5 | **Patch** | Windows Updates, Store app updates, driver checks, software audit |
| 6 | **Optimize** | Defrag/TRIM, power plans, visual effects, services, NTFS tuning |
| 7 | **Privacy** | Telemetry, advertising ID, activity history, location, app permissions |
| 8 | **Network** | DNS optimization, TCP/IP tuning, SMBv1 removal, adapter power management |
| 9 | **Security** | Defender hardening, ASR rules, UAC, RDP security, credential protection |
| 10 | **Wrap-up** | Health score recalculation, HTML report generation, restore power settings |

## Quick Start

### Easy Mode (Recommended for Beginners)

```powershell
# Double-click Launch.bat for a menu, or:

# Interactive Wizard - guided step-by-step, no knowledge needed
.\WinHealthImprover.ps1 -Wizard

# Quick-Fix Presets - one-click solutions
.\WinHealthImprover.ps1 -QuickFix

# System Analyzer - scan first, then recommend what to run
.\WinHealthImprover.ps1 -Analyze
```

### CLI (Power Users)

```powershell
# Run as Administrator
# Full run with defaults
.\WinHealthImprover.ps1

# Preview changes without modifying anything
.\WinHealthImprover.ps1 -DryRun

# Only run cleanup, repair, and optimization
.\WinHealthImprover.ps1 -OnlyStages 1,4,6

# Skip malware scan and updates (faster)
.\WinHealthImprover.ps1 -SkipStages 3,5

# Maximum performance optimization with aggressive privacy
.\WinHealthImprover.ps1 -OptimizationLevel MaxPerformance -PrivacyLevel Aggressive

# Use Google DNS instead of Cloudflare
.\WinHealthImprover.ps1 -DNSProvider Google
```

### GUI

```powershell
# Launch the graphical interface (includes Quick-Fix preset buttons)
.\WinHealthImprover-GUI.ps1
```

### Undo Changes

```powershell
# Reverse ALL changes from the most recent run
.\Undo-Changes.ps1

# Preview what would be undone
.\Undo-Changes.ps1 -WhatIf

# Only undo changes from a specific stage
.\Undo-Changes.ps1 -Stage 7

# Undo from a specific journal file
.\Undo-Changes.ps1 -JournalFile ".\logs\SafetyNet_20240101_120000.json"
```

## Parameters

| Parameter | Values | Default | Description |
|-----------|--------|---------|-------------|
| `-DryRun` | switch | off | Preview changes without modifying system |
| `-SkipStages` | int[] | none | Stage numbers to skip (e.g., `2,5,7`) |
| `-OnlyStages` | int[] | none | Run only these stages (e.g., `1,4,6`) |
| `-OptimizationLevel` | Balanced, Performance, MaxPerformance | Performance | How aggressively to optimize |
| `-PrivacyLevel` | Moderate, Aggressive | Moderate | Privacy hardening intensity |
| `-SecurityLevel` | Standard, Enhanced | Standard | Security hardening intensity |
| `-DNSProvider` | Cloudflare, Google, Quad9 | Cloudflare | DNS provider for network optimization |
| `-QuickScan` | switch | off | Use quick scan for malware detection |
| `-SkipWindowsUpdates` | switch | off | Skip Windows Update installation |
| `-KeepOneDrive` | switch | off | Don't remove OneDrive |
| `-AggressiveDebloat` | switch | off | Remove additional apps (may remove useful ones) |
| `-SkipChkdsk` | switch | off | Skip disk health check |
| `-NoRestore` | switch | off | Skip creating restore points |
| `-LogDirectory` | path | `.\logs` | Custom log directory |
| `-Auto` | switch | off | Automatic mode - no confirmation prompts |
| `-Wizard` | switch | off | Launch interactive wizard (guided mode) |
| `-QuickFix` | switch | off | Launch Quick-Fix preset menu |
| `-Analyze` | switch | off | Run system analyzer with recommendations |
| `-Resume` | switch | off | Resume from a previous interrupted run |
| `-ConfigDump` | switch | off | Show configuration and exit |
| `-SelfDestruct` | switch | off | Delete WinHealthImprover files after run |
| `-AutoReboot` | int | 0 | Auto-reboot after N seconds (0 = disabled) |
| `-AutoShutdown` | switch | off | Auto-shutdown after completion |

## Requirements

- **Windows 10 or 11** (build 10240+)
- **PowerShell 5.1+** (included with Windows 10/11)
- **Administrator privileges** (required for most operations)
- **2 GB+ free disk space** on system drive

## Project Structure

```
WinHealthImprover/
├── WinHealthImprover.ps1          # Main CLI launcher
├── WinHealthImprover-GUI.ps1      # GUI launcher (WPF)
├── Launch.bat                     # Easy double-click menu launcher
├── Undo-Changes.ps1               # Standalone rollback script
├── config/
│   └── defaults.json              # Default configuration
├── modules/
│   ├── Core/
│   │   ├── Analyzer.psm1         # System analyzer & recommendations
│   │   ├── Initialize.psm1       # Pre-flight checks & health scoring
│   │   ├── Logging.psm1          # Structured logging framework
│   │   ├── QuickFix.psm1         # Quick-Fix preset configurations
│   │   ├── Reporting.psm1        # HTML report generation
│   │   ├── SafetyNet.psm1        # Change tracking & undo system
│   │   ├── Utils.psm1            # Common utility functions
│   │   └── Wizard.psm1           # Interactive wizard for beginners
│   ├── Stage0-Prep.psm1          # System preparation
│   ├── Stage1-TempClean.psm1     # Temp file cleanup
│   ├── Stage2-Debloat.psm1       # Bloatware removal
│   ├── Stage3-Disinfect.psm1     # Malware scanning
│   ├── Stage4-Repair.psm1        # System repair
│   ├── Stage5-Patch.psm1         # Updates & patching
│   ├── Stage6-Optimize.psm1      # Performance optimization
│   ├── Stage7-Privacy.psm1       # Privacy hardening
│   ├── Stage8-Network.psm1       # Network optimization
│   ├── Stage9-Security.psm1      # Security hardening
│   └── Stage10-Wrapup.psm1       # Reporting & cleanup
├── resources/                     # Resource files
├── tools/                         # Portable tool storage
├── logs/                          # Log output directory
└── .gitignore
```

## Output

After each run, WinHealthImprover generates:

1. **Console summary** with before/after health scores and stage results
2. **Detailed log file** (`.log`) with timestamped, structured entries
3. **Error log file** (`_errors.log`) with only errors/warnings
4. **HTML report** with system info, health scores, stage results, and metrics

## Safety Features

- **SafetyNet Undo System** - Every change (registry, services, files) is tracked in a journal and fully reversible with `.\Undo-Changes.ps1`
- **System Restore Points** - Created before and after modifications
- **Dry Run mode** - Preview every change before committing
- **Pre-flight Safety Checks** - Validates disk space, battery, running installers before starting
- **App Whitelist** - Protect specific apps from being removed during debloat
- **Confirmation Prompts** - Asks before each app removal (unless `-Auto` mode)
- **Per-Stage Rollback** - Undo changes from a specific stage only (`.\Undo-Changes.ps1 -Stage 7`)
- **Checkpoint/Resume** - If the process crashes, resume from where it left off with `-Resume`
- **Structured Logging** - Every action recorded with timestamps and before/after values
- **Error Isolation** - Stage failures don't stop the entire process
- **Smart Detection** - Auto-detects SSD/HDD, RAM, battery, and adjusts behavior

## Quick-Fix Presets

| Preset | Description | Stages | Est. Time | Risk |
|--------|-------------|--------|-----------|------|
| Fix My PC | Repair a slow/broken PC | 0,1,3,4,5,6 | ~30 min | Low |
| Speed Up | Maximum performance | 0,1,2,6,8 | ~15 min | Low |
| Privacy Lock | Stop tracking/spying | 0,7 | ~5 min | Low |
| Clean Sweep | Deep junk removal | 0,1,2 | ~10 min | Moderate |
| Security Max | Full hardening | 0,3,8,9 | ~15 min | Low |
| Fresh Start | The full treatment | 0-9 | ~60 min | Moderate |
| Maintenance | Monthly routine | 0,1,3,5,6 | ~20 min | Very Low |

## Extending

Each stage is a standalone PowerShell module. To add custom functionality:

1. Create a new `.psm1` file in the `modules/` directory
2. Export a single `Invoke-StageX` function
3. Import it in `WinHealthImprover.ps1`
4. Add it to the stage execution block

## License

MIT License - See [LICENSE](LICENSE) for details.

## Acknowledgments

Inspired by [Tron](https://github.com/bmrf/tron) by vocatus/bmrf. Rebuilt from scratch in PowerShell with modern architecture and additional capabilities.

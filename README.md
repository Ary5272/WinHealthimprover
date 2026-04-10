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

### CLI (Recommended)

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
# Launch the graphical interface
.\WinHealthImprover-GUI.ps1
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
├── config/
│   └── defaults.json              # Default configuration
├── modules/
│   ├── Core/
│   │   ├── Initialize.psm1       # Pre-flight checks & health scoring
│   │   ├── Logging.psm1          # Structured logging framework
│   │   ├── Reporting.psm1        # HTML report generation
│   │   └── Utils.psm1            # Common utility functions
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

- **System Restore Points** are created before and after modifications
- **Dry Run mode** lets you preview every change before committing
- **Structured logging** records every action taken
- **Non-destructive defaults** - aggressive options must be explicitly enabled
- **Error isolation** - stage failures don't stop the entire process
- **Smart detection** - auto-detects SSD/HDD, RAM amount, and adjusts behavior

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

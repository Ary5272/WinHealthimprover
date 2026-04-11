@echo off
:: ============================================================================
:: WinHealthImprover - Easy Launch Script
:: ============================================================================
:: Double-click this file to launch WinHealthImprover with default settings.
:: It will automatically request Administrator privileges.
:: ============================================================================

title WinHealthImprover Launcher
color 0B

:: Check for admin rights
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║           WinHealthImprover - Launch Menu                   ║
echo  ╠══════════════════════════════════════════════════════════════╣
echo  ║                                                              ║
echo  ║   EASY MODE (recommended for most users):                   ║
echo  ║   [1]  Interactive Wizard (guided step-by-step)             ║
echo  ║   [2]  Quick-Fix Presets (one-click solutions)              ║
echo  ║   [3]  System Scan (analyze and recommend)                  ║
echo  ║                                                              ║
echo  ║   STANDARD MODE:                                            ║
echo  ║   [4]  Full Run (all stages)                                ║
echo  ║   [5]  Dry Run (preview only, no changes)                   ║
echo  ║   [6]  Quick Run (skip updates + quick scan)                ║
echo  ║                                                              ║
echo  ║   TARGETED MODE:                                            ║
echo  ║   [7]  Cleanup Only (temp files + bloatware)                ║
echo  ║   [8]  Repair Only (fix broken Windows)                     ║
echo  ║   [9]  Optimize Only (speed up PC)                          ║
echo  ║   [A]  Privacy Harden (stop tracking)                       ║
echo  ║   [B]  Security Harden (protect from attacks)               ║
echo  ║                                                              ║
echo  ║   OTHER:                                                    ║
echo  ║   [C]  Launch GUI                                           ║
echo  ║   [D]  Undo All Changes (rollback)                         ║
echo  ║   [E]  Custom (enter parameters manually)                   ║
echo  ║   [0]  Exit                                                  ║
echo  ║                                                              ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.
echo   All changes are tracked and can be reversed with option [D]!
echo.

set /p choice="  Select an option: "

if "%choice%"=="1" goto wizard
if "%choice%"=="2" goto quickfix
if "%choice%"=="3" goto analyze
if "%choice%"=="4" goto full
if "%choice%"=="5" goto dryrun
if "%choice%"=="6" goto quick
if "%choice%"=="7" goto cleanup
if "%choice%"=="8" goto repair
if "%choice%"=="9" goto optimize
if /i "%choice%"=="A" goto privacy
if /i "%choice%"=="B" goto security
if /i "%choice%"=="C" goto gui
if /i "%choice%"=="D" goto undo
if /i "%choice%"=="E" goto custom
if "%choice%"=="0" goto end

echo Invalid choice. & goto end

:wizard
echo Starting Interactive Wizard...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0WinHealthImprover.ps1" -Wizard
goto done

:quickfix
echo Starting Quick-Fix Presets...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0WinHealthImprover.ps1" -QuickFix
goto done

:analyze
echo Starting System Analysis...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0WinHealthImprover.ps1" -Analyze
goto done

:full
echo Running Full Scan...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0WinHealthImprover.ps1"
goto done

:dryrun
echo Running Dry Run (no changes)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0WinHealthImprover.ps1" -DryRun
goto done

:quick
echo Running Quick Mode (skip updates + quick scan)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0WinHealthImprover.ps1" -SkipWindowsUpdates -QuickScan -SkipChkdsk
goto done

:cleanup
echo Running Cleanup Only...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0WinHealthImprover.ps1" -OnlyStages 0,1,2
goto done

:repair
echo Running Repair Only...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0WinHealthImprover.ps1" -OnlyStages 0,4
goto done

:optimize
echo Running Optimization...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0WinHealthImprover.ps1" -OnlyStages 0,6,8
goto done

:privacy
echo Running Privacy Hardening...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0WinHealthImprover.ps1" -OnlyStages 0,7 -PrivacyLevel Aggressive
goto done

:security
echo Running Security Hardening...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0WinHealthImprover.ps1" -OnlyStages 0,9 -SecurityLevel Enhanced
goto done

:gui
echo Launching GUI...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0WinHealthImprover-GUI.ps1"
goto done

:undo
echo Launching Undo Tool...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Undo-Changes.ps1"
goto done

:custom
echo.
set /p params="  Enter parameters: "
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0WinHealthImprover.ps1" %params%
goto done

:done
echo.
echo  ════════════════════════════════════════════════════════════════
echo   WinHealthImprover has finished. A reboot is recommended.
echo   Run option [D] to undo any changes if needed.
echo  ════════════════════════════════════════════════════════════════
echo.
pause

:end
exit /b

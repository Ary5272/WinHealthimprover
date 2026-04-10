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
echo  ║   [1]  Full Run (all stages, recommended)                   ║
echo  ║   [2]  Dry Run (preview only, no changes)                   ║
echo  ║   [3]  Quick Run (skip updates + full scan)                 ║
echo  ║   [4]  Cleanup Only (stages 0,1,2)                         ║
echo  ║   [5]  Repair Only (stages 0,4)                            ║
echo  ║   [6]  Optimize Only (stages 0,6,7,8)                      ║
echo  ║   [7]  Security Harden (stages 0,7,9)                      ║
echo  ║   [8]  Launch GUI                                           ║
echo  ║   [9]  Custom (enter parameters manually)                   ║
echo  ║   [0]  Exit                                                  ║
echo  ║                                                              ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.

set /p choice="  Select an option [1-9, 0 to exit]: "

if "%choice%"=="1" goto full
if "%choice%"=="2" goto dryrun
if "%choice%"=="3" goto quick
if "%choice%"=="4" goto cleanup
if "%choice%"=="5" goto repair
if "%choice%"=="6" goto optimize
if "%choice%"=="7" goto security
if "%choice%"=="8" goto gui
if "%choice%"=="9" goto custom
if "%choice%"=="0" goto end

echo Invalid choice. & goto end

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
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0WinHealthImprover.ps1" -OnlyStages 0,6,7,8
goto done

:security
echo Running Security Hardening...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0WinHealthImprover.ps1" -OnlyStages 0,7,9
goto done

:gui
echo Launching GUI...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0WinHealthImprover-GUI.ps1"
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
echo  ════════════════════════════════════════════════════════════════
echo.
pause

:end
exit /b

#Requires -Version 5.1
<#
.SYNOPSIS
    WinHealthImprover - GUI Launcher
.DESCRIPTION
    Modern WPF-based graphical interface for WinHealthImprover.
    Provides stage selection, real-time progress, and configuration options.
#>

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# ============================================================================
# XAML GUI DEFINITION
# ============================================================================

[xml]$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="WinHealthImprover v1.0.0"
    Width="900" Height="720"
    WindowStartupLocation="CenterScreen"
    Background="#0a0a1a"
    ResizeMode="CanMinimize">

    <Window.Resources>
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="#e0e0e0"/>
            <Setter Property="Margin" Value="5,4"/>
            <Setter Property="FontSize" Value="13"/>
        </Style>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#1a3a5c"/>
            <Setter Property="Foreground" Value="#00d4ff"/>
            <Setter Property="BorderBrush" Value="#2a5a8c"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="20,10"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
        </Style>
        <Style TargetType="ComboBox">
            <Setter Property="Background" Value="#12122a"/>
            <Setter Property="Foreground" Value="#e0e0e0"/>
            <Setter Property="BorderBrush" Value="#1e1e3f"/>
            <Setter Property="Padding" Value="8,5"/>
            <Setter Property="FontSize" Value="13"/>
        </Style>
        <Style TargetType="Label">
            <Setter Property="Foreground" Value="#7f8c9b"/>
            <Setter Property="FontSize" Value="13"/>
        </Style>
        <Style TargetType="GroupBox">
            <Setter Property="Foreground" Value="#00d4ff"/>
            <Setter Property="BorderBrush" Value="#1e1e3f"/>
            <Setter Property="Margin" Value="5"/>
            <Setter Property="Padding" Value="10"/>
            <Setter Property="FontSize" Value="13"/>
        </Style>
    </Window.Resources>

    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header -->
        <StackPanel Grid.Row="0" Margin="0,0,0,10">
            <TextBlock Text="WinHealthImprover" FontSize="28" FontWeight="Bold"
                       Foreground="#00d4ff" HorizontalAlignment="Center"/>
            <TextBlock Text="Windows System Repair, Optimization &amp; Hardening Toolkit"
                       FontSize="12" Foreground="#7f8c9b" HorizontalAlignment="Center" Margin="0,5,0,0"/>
            <TextBlock Text="All changes are tracked and reversible via SafetyNet"
                       FontSize="11" Foreground="#00cc66" HorizontalAlignment="Center" Margin="0,3,0,5"/>
            <!-- Quick-Fix Preset Buttons -->
            <WrapPanel HorizontalAlignment="Center" Margin="0,5,0,0">
                <Button x:Name="btnFixMyPC" Content=" Fix My PC " Margin="4,2" FontSize="11" Padding="12,6"
                        Background="#1a4a2a" Foreground="#00ff88" BorderBrush="#2a6a4a"/>
                <Button x:Name="btnSpeedUp" Content=" Speed Up " Margin="4,2" FontSize="11" Padding="12,6"
                        Background="#1a3a5c" Foreground="#00d4ff" BorderBrush="#2a5a8c"/>
                <Button x:Name="btnCleanUp" Content=" Clean Up " Margin="4,2" FontSize="11" Padding="12,6"
                        Background="#3a3a1a" Foreground="#ffcc00" BorderBrush="#5a5a2a"/>
                <Button x:Name="btnPrivacy" Content=" Privacy Lock " Margin="4,2" FontSize="11" Padding="12,6"
                        Background="#3a1a3a" Foreground="#ff88ff" BorderBrush="#5a2a5a"/>
                <Button x:Name="btnSecurity" Content=" Security Max " Margin="4,2" FontSize="11" Padding="12,6"
                        Background="#3a1a1a" Foreground="#ff6666" BorderBrush="#5a2a2a"/>
                <Button x:Name="btnUndo" Content=" Undo Changes " Margin="4,2" FontSize="11" Padding="12,6"
                        Background="#2a1a1a" Foreground="#ff4444" BorderBrush="#4a2a2a"/>
            </WrapPanel>
        </StackPanel>

        <!-- Main Content Grid -->
        <Grid Grid.Row="1">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <!-- Stage Selection -->
            <GroupBox Header="  Stages  " Grid.Column="0">
                <StackPanel>
                    <CheckBox x:Name="chkStage0" Content="Stage 0: Preparation" IsChecked="True"/>
                    <CheckBox x:Name="chkStage1" Content="Stage 1: Temp Cleanup" IsChecked="True"/>
                    <CheckBox x:Name="chkStage2" Content="Stage 2: Debloat" IsChecked="True"/>
                    <CheckBox x:Name="chkStage3" Content="Stage 3: Disinfect" IsChecked="True"/>
                    <CheckBox x:Name="chkStage4" Content="Stage 4: System Repair" IsChecked="True"/>
                    <CheckBox x:Name="chkStage5" Content="Stage 5: Patch &amp; Update" IsChecked="True"/>
                    <CheckBox x:Name="chkStage6" Content="Stage 6: Optimize" IsChecked="True"/>
                    <CheckBox x:Name="chkStage7" Content="Stage 7: Privacy Hardening" IsChecked="True"/>
                    <CheckBox x:Name="chkStage8" Content="Stage 8: Network Optimization" IsChecked="True"/>
                    <CheckBox x:Name="chkStage9" Content="Stage 9: Security Hardening" IsChecked="True"/>
                    <CheckBox x:Name="chkStage10" Content="Stage 10: Wrap-up &amp; Report" IsChecked="True" IsEnabled="False"/>
                </StackPanel>
            </GroupBox>

            <!-- Options -->
            <StackPanel Grid.Column="1">
                <GroupBox Header="  Options  ">
                    <StackPanel>
                        <CheckBox x:Name="chkDryRun" Content="Dry Run (preview only)"/>
                        <CheckBox x:Name="chkQuickScan" Content="Quick Scan (faster malware check)"/>
                        <CheckBox x:Name="chkSkipUpdates" Content="Skip Windows Updates"/>
                        <CheckBox x:Name="chkKeepOneDrive" Content="Keep OneDrive"/>
                        <CheckBox x:Name="chkAggressive" Content="Aggressive Debloat"/>
                        <CheckBox x:Name="chkSkipChkdsk" Content="Skip Disk Check" IsChecked="True"/>
                    </StackPanel>
                </GroupBox>

                <GroupBox Header="  Configuration  ">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <Grid.RowDefinitions>
                            <RowDefinition/>
                            <RowDefinition/>
                            <RowDefinition/>
                            <RowDefinition/>
                        </Grid.RowDefinitions>

                        <Label Content="Optimization:" Grid.Row="0" Grid.Column="0"/>
                        <ComboBox x:Name="cmbOptimization" Grid.Row="0" Grid.Column="1" Margin="5,3"
                                  SelectedIndex="1">
                            <ComboBoxItem Content="Balanced"/>
                            <ComboBoxItem Content="Performance"/>
                            <ComboBoxItem Content="MaxPerformance"/>
                        </ComboBox>

                        <Label Content="Privacy:" Grid.Row="1" Grid.Column="0"/>
                        <ComboBox x:Name="cmbPrivacy" Grid.Row="1" Grid.Column="1" Margin="5,3"
                                  SelectedIndex="0">
                            <ComboBoxItem Content="Moderate"/>
                            <ComboBoxItem Content="Aggressive"/>
                        </ComboBox>

                        <Label Content="Security:" Grid.Row="2" Grid.Column="0"/>
                        <ComboBox x:Name="cmbSecurity" Grid.Row="2" Grid.Column="1" Margin="5,3"
                                  SelectedIndex="0">
                            <ComboBoxItem Content="Standard"/>
                            <ComboBoxItem Content="Enhanced"/>
                        </ComboBox>

                        <Label Content="DNS Provider:" Grid.Row="3" Grid.Column="0"/>
                        <ComboBox x:Name="cmbDNS" Grid.Row="3" Grid.Column="1" Margin="5,3"
                                  SelectedIndex="0">
                            <ComboBoxItem Content="Cloudflare"/>
                            <ComboBoxItem Content="Google"/>
                            <ComboBoxItem Content="Quad9"/>
                        </ComboBox>
                    </Grid>
                </GroupBox>
            </StackPanel>
        </Grid>

        <!-- Progress / Log Output -->
        <GroupBox Header="  Output  " Grid.Row="2" Margin="5,10,5,5">
            <ScrollViewer x:Name="scrollOutput" VerticalScrollBarVisibility="Auto">
                <TextBlock x:Name="txtOutput" Foreground="#e0e0e0" FontFamily="Consolas"
                           FontSize="11" TextWrapping="Wrap" Padding="10"/>
            </ScrollViewer>
        </GroupBox>

        <!-- Progress Bar -->
        <Grid Grid.Row="3" Margin="5,5">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <ProgressBar x:Name="progressBar" Grid.Column="0" Height="25"
                         Background="#12122a" Foreground="#00d4ff" BorderBrush="#1e1e3f"
                         Minimum="0" Maximum="100" Value="0"/>
            <TextBlock x:Name="txtProgress" Grid.Column="1" Foreground="#7f8c9b"
                       VerticalAlignment="Center" Margin="10,0,0,0" FontSize="13"
                       Text="Ready"/>
        </Grid>

        <!-- Action Buttons -->
        <StackPanel Grid.Row="4" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,10">
            <Button x:Name="btnStart" Content="  Start  " Margin="10,0"/>
            <Button x:Name="btnSelectAll" Content="  Select All  " Margin="10,0"/>
            <Button x:Name="btnDeselectAll" Content="  Deselect All  " Margin="10,0"/>
            <Button x:Name="btnOpenLog" Content="  Open Log  " Margin="10,0" IsEnabled="False"/>
            <Button x:Name="btnOpenReport" Content="  Open Report  " Margin="10,0" IsEnabled="False"/>
        </StackPanel>
    </Grid>
</Window>
"@

# ============================================================================
# WINDOW CREATION
# ============================================================================

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get controls
$controls = @{}
$xaml.SelectNodes("//*[@*[contains(translate(name(),'x','X'),'Name')]]") | ForEach-Object {
    $name = $_.Name
    $controls[$name] = $window.FindName($name)
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Add-OutputText {
    param([string]$Text, [string]$Color = "#e0e0e0")

    $controls['txtOutput'].Dispatcher.Invoke([Action]{
        $run = New-Object System.Windows.Documents.Run($Text + "`n")
        # TextBlock doesn't support Runs directly in simple mode, append to text
        $controls['txtOutput'].Text += $Text + "`n"
        $controls['scrollOutput'].ScrollToEnd()
    })
}

function Set-Progress {
    param([int]$Value, [string]$Status)

    $controls['progressBar'].Dispatcher.Invoke([Action]{
        $controls['progressBar'].Value = $Value
        $controls['txtProgress'].Text = $Status
    })
}

# ============================================================================
# EVENT HANDLERS
# ============================================================================

$controls['btnSelectAll'].Add_Click({
    for ($i = 0; $i -le 9; $i++) {
        $controls["chkStage$i"].IsChecked = $true
    }
})

$controls['btnDeselectAll'].Add_Click({
    for ($i = 0; $i -le 9; $i++) {
        $controls["chkStage$i"].IsChecked = $false
    }
})

# Quick-Fix Preset Handlers
function Set-PresetStages {
    param([int[]]$Stages)
    for ($i = 0; $i -le 9; $i++) {
        $controls["chkStage$i"].IsChecked = ($i -in $Stages)
    }
}

$controls['btnFixMyPC'].Add_Click({
    Set-PresetStages -Stages @(0,1,3,4,5,6)
    $controls['cmbOptimization'].SelectedIndex = 1  # Performance
    $controls['chkDryRun'].IsChecked = $false
    Add-OutputText "[Preset] Fix My PC selected: Clean, scan, repair, update, optimize"
})

$controls['btnSpeedUp'].Add_Click({
    Set-PresetStages -Stages @(0,1,2,6,8)
    $controls['cmbOptimization'].SelectedIndex = 2  # MaxPerformance
    $controls['chkSkipUpdates'].IsChecked = $true
    $controls['chkDryRun'].IsChecked = $false
    Add-OutputText "[Preset] Speed Up selected: Clean, debloat, optimize, network"
})

$controls['btnCleanUp'].Add_Click({
    Set-PresetStages -Stages @(0,1,2)
    $controls['chkAggressive'].IsChecked = $true
    $controls['chkDryRun'].IsChecked = $false
    Add-OutputText "[Preset] Clean Up selected: Temp files, bloatware, junk removal"
})

$controls['btnPrivacy'].Add_Click({
    Set-PresetStages -Stages @(0,7)
    $controls['cmbPrivacy'].SelectedIndex = 1  # Aggressive
    $controls['chkDryRun'].IsChecked = $false
    Add-OutputText "[Preset] Privacy Lock selected: Full telemetry and tracking disable"
})

$controls['btnSecurity'].Add_Click({
    Set-PresetStages -Stages @(0,3,8,9)
    $controls['cmbSecurity'].SelectedIndex = 1  # Enhanced
    $controls['chkDryRun'].IsChecked = $false
    Add-OutputText "[Preset] Security Max selected: Scan, network security, full hardening"
})

$controls['btnUndo'].Add_Click({
    $undoScript = Join-Path $PSScriptRoot "Undo-Changes.ps1"
    if (Test-Path $undoScript) {
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$undoScript`"" -Verb RunAs
    }
    else {
        Add-OutputText "ERROR: Undo-Changes.ps1 not found"
    }
})

$controls['btnStart'].Add_Click({
    $controls['btnStart'].IsEnabled = $false
    $controls['txtOutput'].Text = ""

    # Build skip list
    $skipStages = @()
    for ($i = 0; $i -le 9; $i++) {
        if (-not $controls["chkStage$i"].IsChecked) {
            $skipStages += $i
        }
    }

    # Build parameters
    $params = @()
    if ($controls['chkDryRun'].IsChecked) { $params += "-DryRun" }
    if ($controls['chkQuickScan'].IsChecked) { $params += "-QuickScan" }
    if ($controls['chkSkipUpdates'].IsChecked) { $params += "-SkipWindowsUpdates" }
    if ($controls['chkKeepOneDrive'].IsChecked) { $params += "-KeepOneDrive" }
    if ($controls['chkAggressive'].IsChecked) { $params += "-AggressiveDebloat" }
    if ($controls['chkSkipChkdsk'].IsChecked) { $params += "-SkipChkdsk" }

    $optLevel = $controls['cmbOptimization'].SelectedItem.Content
    $privLevel = $controls['cmbPrivacy'].SelectedItem.Content
    $secLevel = $controls['cmbSecurity'].SelectedItem.Content
    $dnsProvider = $controls['cmbDNS'].SelectedItem.Content

    $params += "-OptimizationLevel $optLevel"
    $params += "-PrivacyLevel $privLevel"
    $params += "-SecurityLevel $secLevel"
    $params += "-DNSProvider $dnsProvider"

    if ($skipStages.Count -gt 0) {
        $params += "-SkipStages $($skipStages -join ',')"
    }

    $params += "-Headless"

    $scriptPath = Join-Path $PSScriptRoot "WinHealthImprover.ps1"
    $cmdLine = "& '$scriptPath' $($params -join ' ')"

    Add-OutputText "Starting WinHealthImprover..."
    Add-OutputText "Command: $cmdLine"
    Add-OutputText ""

    Set-Progress -Value 5 -Status "Starting..."

    # Run in background job
    $job = Start-Job -ScriptBlock {
        param($scriptPath, $paramString)
        Set-Location (Split-Path $scriptPath -Parent)
        $output = Invoke-Expression "& '$scriptPath' $paramString 2>&1"
        return $output
    } -ArgumentList $scriptPath, ($params -join ' ')

    # Monitor job in timer
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(500)

    $timer.Add_Tick({
        $state = $job.State

        # Read any new output
        $output = Receive-Job -Job $job -ErrorAction SilentlyContinue
        if ($output) {
            foreach ($line in $output) {
                $controls['txtOutput'].Text += "$line`n"
            }
            $controls['scrollOutput'].ScrollToEnd()
        }

        if ($state -eq "Completed" -or $state -eq "Failed" -or $state -eq "Stopped") {
            $timer.Stop()
            $controls['btnStart'].IsEnabled = $true
            $controls['btnOpenLog'].IsEnabled = $true
            $controls['btnOpenReport'].IsEnabled = $true

            Set-Progress -Value 100 -Status $(if ($state -eq "Completed") { "Complete!" } else { "Failed" })

            Add-OutputText ""
            Add-OutputText "=== Process $state ==="

            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        }
        else {
            # Estimate progress based on output content
            $text = $controls['txtOutput'].Text
            $currentStage = 0
            for ($s = 10; $s -ge 0; $s--) {
                if ($text -match "STAGE $s") {
                    $currentStage = $s
                    break
                }
            }
            $pct = [math]::Min(95, 5 + ($currentStage * 9))
            Set-Progress -Value $pct -Status "Running Stage $currentStage..."
        }
    }.GetNewClosure())

    $timer.Start()
})

$controls['btnOpenLog'].Add_Click({
    $logDir = Join-Path $PSScriptRoot "logs"
    if (Test-Path $logDir) {
        $latestLog = Get-ChildItem -Path $logDir -Filter "*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($latestLog) {
            Start-Process notepad.exe -ArgumentList $latestLog.FullName
        }
    }
})

$controls['btnOpenReport'].Add_Click({
    $logDir = Join-Path $PSScriptRoot "logs"
    if (Test-Path $logDir) {
        $latestReport = Get-ChildItem -Path $logDir -Filter "*.html" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($latestReport) {
            Start-Process $latestReport.FullName
        }
    }
})

# ============================================================================
# SHOW WINDOW
# ============================================================================

# Check for admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $controls['txtOutput'].Text = "WARNING: Not running as Administrator.`nSome features will not work. Please restart as Administrator.`n`nYou can still use Dry Run mode to preview changes."
    $controls['chkDryRun'].IsChecked = $true
}

$window.ShowDialog() | Out-Null

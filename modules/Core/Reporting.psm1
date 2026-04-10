#Requires -Version 5.1
<#
.SYNOPSIS
    WinHealthImprover - HTML Report Generator
.DESCRIPTION
    Generates comprehensive HTML reports with system health analysis,
    stage results, and before/after comparisons.
#>

function New-HTMLReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter(Mandatory)]
        [hashtable]$SystemInfo,

        [Parameter(Mandatory)]
        [hashtable]$HealthBefore,

        [hashtable]$HealthAfter = $null,

        [Parameter(Mandatory)]
        [System.Collections.ArrayList]$StageResults,

        [hashtable]$Metrics = @{},

        [TimeSpan]$TotalDuration = [TimeSpan]::Zero
    )

    $reportDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $stageRows = ""

    foreach ($stage in $StageResults) {
        $statusIcon = switch ($stage.Status) {
            "Success" { "&#10004;" }
            "Warning" { "&#9888;" }
            "Error"   { "&#10008;" }
            "Skipped" { "&#8722;" }
        }
        $statusColor = switch ($stage.Status) {
            "Success" { "#27ae60" }
            "Warning" { "#f39c12" }
            "Error"   { "#e74c3c" }
            "Skipped" { "#95a5a6" }
        }

        $stageRows += @"
        <tr>
            <td>Stage $($stage.StageNumber)</td>
            <td>$($stage.StageName)</td>
            <td style="color: $statusColor; font-weight: bold;">$statusIcon $($stage.Status)</td>
            <td>$($stage.Summary)</td>
            <td>$($stage.Duration.ToString('mm\:ss'))</td>
        </tr>
"@
    }

    # Build metrics section
    $metricsHtml = ""
    foreach ($category in $Metrics.Keys) {
        $metricsHtml += "<h3>$category</h3><table><thead><tr><th>Metric</th><th>Value</th></tr></thead><tbody>"
        foreach ($key in $Metrics[$category].Keys) {
            $metricsHtml += "<tr><td>$key</td><td>$($Metrics[$category][$key])</td></tr>"
        }
        $metricsHtml += "</tbody></table>"
    }

    $afterScoreHtml = ""
    if ($HealthAfter) {
        $changeIcon = if ($HealthAfter.Score -gt $HealthBefore.Score) { "&#9650;" }
                      elseif ($HealthAfter.Score -lt $HealthBefore.Score) { "&#9660;" }
                      else { "&#9644;" }

        $afterScoreHtml = @"
        <div class="score-card after">
            <h3>After</h3>
            <div class="score">$($HealthAfter.Score)</div>
            <div class="grade">Grade: $($HealthAfter.Grade)</div>
            <div class="change">$changeIcon Change: $($HealthAfter.Score - $HealthBefore.Score) points</div>
        </div>
"@
    }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>WinHealthImprover Report - $($SystemInfo.ComputerName)</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: #0a0a1a;
            color: #e0e0e0;
            line-height: 1.6;
        }
        .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
        header {
            background: linear-gradient(135deg, #0f3460, #16213e);
            padding: 30px;
            border-radius: 12px;
            margin-bottom: 24px;
            border: 1px solid #1a3a5c;
        }
        header h1 {
            font-size: 2em;
            color: #00d4ff;
            margin-bottom: 8px;
        }
        header .subtitle { color: #7f8c9b; font-size: 0.95em; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin-bottom: 24px; }
        .card {
            background: #12122a;
            border-radius: 10px;
            padding: 24px;
            border: 1px solid #1e1e3f;
        }
        .card h2 {
            color: #00d4ff;
            font-size: 1.2em;
            margin-bottom: 16px;
            padding-bottom: 8px;
            border-bottom: 1px solid #1e1e3f;
        }
        .card h3 { color: #4fc3f7; margin: 16px 0 8px; }
        .info-row { display: flex; justify-content: space-between; padding: 6px 0; border-bottom: 1px solid #1a1a35; }
        .info-label { color: #7f8c9b; }
        .info-value { color: #ffffff; font-weight: 500; }
        .score-container { display: flex; gap: 24px; justify-content: center; flex-wrap: wrap; }
        .score-card {
            text-align: center;
            padding: 24px 40px;
            background: #1a1a35;
            border-radius: 12px;
            min-width: 200px;
        }
        .score-card h3 { color: #7f8c9b; margin-bottom: 12px; }
        .score {
            font-size: 3.5em;
            font-weight: bold;
            background: linear-gradient(135deg, #00d4ff, #7c4dff);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        .grade { font-size: 1.3em; color: #4fc3f7; margin-top: 8px; }
        .change { margin-top: 8px; color: #27ae60; font-weight: bold; }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 12px;
        }
        thead { background: #1a1a35; }
        th { color: #00d4ff; text-align: left; padding: 12px; font-weight: 600; }
        td { padding: 10px 12px; border-bottom: 1px solid #1a1a35; }
        tr:hover { background: #16163a; }
        .status-success { color: #27ae60; }
        .status-warning { color: #f39c12; }
        .status-error { color: #e74c3c; }
        .status-skipped { color: #95a5a6; }
        .issues-list { list-style: none; }
        .issues-list li {
            padding: 8px 12px;
            margin: 4px 0;
            background: #1a1a35;
            border-radius: 6px;
            border-left: 3px solid #f39c12;
        }
        footer {
            text-align: center;
            padding: 20px;
            color: #555;
            font-size: 0.85em;
        }
        @media print {
            body { background: white; color: #333; }
            .card { border: 1px solid #ddd; }
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>WinHealthImprover Report</h1>
            <div class="subtitle">Generated: $reportDate | Duration: $($TotalDuration.ToString('hh\:mm\:ss')) | Computer: $($SystemInfo.ComputerName)</div>
        </header>

        <div class="card">
            <h2>Health Score</h2>
            <div class="score-container">
                <div class="score-card before">
                    <h3>Before</h3>
                    <div class="score">$($HealthBefore.Score)</div>
                    <div class="grade">Grade: $($HealthBefore.Grade)</div>
                </div>
                $afterScoreHtml
            </div>
            $(if ($HealthBefore.Deductions.Count -gt 0) {
                "<h3 style='color:#4fc3f7;margin:20px 0 10px;'>Issues Detected</h3><ul class='issues-list'>" +
                ($HealthBefore.Deductions | ForEach-Object { "<li>$_</li>" }) -join "" +
                "</ul>"
            })
        </div>

        <div class="grid">
            <div class="card">
                <h2>System Information</h2>
                <div class="info-row"><span class="info-label">Computer</span><span class="info-value">$($SystemInfo.ComputerName)</span></div>
                <div class="info-row"><span class="info-label">OS</span><span class="info-value">$($SystemInfo.OS.VersionName)</span></div>
                <div class="info-row"><span class="info-label">Build</span><span class="info-value">$($SystemInfo.OS.Build)</span></div>
                <div class="info-row"><span class="info-label">Architecture</span><span class="info-value">$($SystemInfo.OS.Arch)</span></div>
                <div class="info-row"><span class="info-label">CPU</span><span class="info-value">$($SystemInfo.CPU)</span></div>
                <div class="info-row"><span class="info-label">RAM</span><span class="info-value">$($SystemInfo.TotalRAM) GB</span></div>
                <div class="info-row"><span class="info-label">Manufacturer</span><span class="info-value">$($SystemInfo.Manufacturer)</span></div>
                <div class="info-row"><span class="info-label">Model</span><span class="info-value">$($SystemInfo.Model)</span></div>
            </div>

            <div class="card">
                <h2>Disk Information</h2>
                $(foreach ($disk in $SystemInfo.Disks) {
                    "<div class='info-row'><span class='info-label'>$($disk.Drive)</span><span class='info-value'>$($disk.Free) GB free / $($disk.Size) GB ($($disk.UsedPct)%)</span></div>"
                })
            </div>
        </div>

        <div class="card">
            <h2>Stage Results</h2>
            <table>
                <thead>
                    <tr>
                        <th>Stage</th>
                        <th>Name</th>
                        <th>Status</th>
                        <th>Summary</th>
                        <th>Duration</th>
                    </tr>
                </thead>
                <tbody>
                    $stageRows
                </tbody>
            </table>
        </div>

        $(if ($metricsHtml) {
            "<div class='card'><h2>Detailed Metrics</h2>$metricsHtml</div>"
        })

        <footer>
            <p>WinHealthImprover v1.0.0 | PowerShell Edition | Report generated $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        </footer>
    </div>
</body>
</html>
"@

    $html | Out-File -FilePath $OutputPath -Encoding UTF8 -Force
    return $OutputPath
}

Export-ModuleMember -Function *

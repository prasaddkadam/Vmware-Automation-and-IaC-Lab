
# VMware Automation & Infrastructure-as-Code Lab
# Stage 3 - Checkpoint 14
# Script: 05-Get-LabReport.ps1
# Purpose: Consolidate existing infrastructure health reports
# Operation: Read-only; processes CSV reports

param(
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'

if (-not $OutputDirectory) {
    $RepoRoot = Split-Path $PSScriptRoot -Parent
    $WorkspaceRoot = Split-Path $RepoRoot -Parent
    $OutputDirectory = Join-Path $WorkspaceRoot 'output'
}

if (-not (Test-Path -LiteralPath $OutputDirectory)) {
    throw "Output directory not found: $OutputDirectory"
}

$Results = [System.Collections.Generic.List[object]]::new()

function Get-LatestReport {
    param([string]$Pattern)

    Get-ChildItem -LiteralPath $OutputDirectory -Filter $Pattern -File |
        Sort-Object Name -Descending |
        Select-Object -First 1
}

function Add-Result {
    param(
        [string]$Component,
        [string]$Metric,
        [string]$Value,
        [string]$Status,
        [string]$SourceTimestamp
    )

    $script:Results.Add([PSCustomObject]@{
        Component = $Component
        Metric = $Metric
        Value = $Value
        Status = $Status
        SourceTimestamp = $SourceTimestamp
    })
}

# Identify newest reports
$HostFile = Get-LatestReport 'ESXi-HostHealth-*.csv'
$StorageFile = Get-LatestReport 'ESXi-DatastoreHealth-*.csv'
$NICFile = Get-LatestReport 'ESXi-NICHealth-*.csv'
$ComparisonFile = Get-LatestReport 'ESXi-NICComparison-*.csv'
$BaselineFile = Get-LatestReport 'ESXi-Baseline-*.csv'

# 1. Host health
if ($HostFile) {
    $HostHealth = Import-Csv $HostFile.FullName |
        Select-Object -First 1

    if (-not $HostHealth) {
        throw "Host report is empty: $($HostFile.Name)"
    }

    $ConnectionStatus = if (
        $HostHealth.ConnectionState -eq 'Connected'
    ) { 'PASS' } else { 'FAIL' }

    Add-Result 'Host' 'Connection' `
        $HostHealth.ConnectionState $ConnectionStatus `
        $HostHealth.Timestamp

    foreach ($Metric in @('CpuUsedPct', 'MemoryUsedPct')) {
        $Value = [double]$HostHealth.$Metric
        $Status = if ($Value -ge 85) { 'WARNING' } else { 'PASS' }

        Add-Result 'Host' $Metric "$Value%" $Status `
            $HostHealth.Timestamp
    }
}
else {
    Add-Result 'Host' 'Health report' 'Missing' 'UNKNOWN' ''
}

# 2. Datastore health
if ($StorageFile) {
    $Datastores = @(Import-Csv $StorageFile.FullName)

    foreach ($Datastore in $Datastores) {
        $UsedPct = [double]$Datastore.UsedPct
        $Status = if ($UsedPct -ge 80) { 'WARNING' } else { 'PASS' }

        Add-Result 'Storage' $Datastore.Name `
            "$UsedPct% used; $($Datastore.FreeGB) GB free" `
            $Status $Datastore.Timestamp
    }
}
else {
    Add-Result 'Storage' 'Datastore report' 'Missing' 'UNKNOWN' ''
}

# 3. NIC health comparison
if ($ComparisonFile) {
    $NICComparisons = @(Import-Csv $ComparisonFile.FullName)

    foreach ($NIC in $NICComparisons) {
        $Status = switch ($NIC.Status) {
            'NO_NEW_ERRORS' { 'PASS' }
            'WARNING' { 'WARNING' }
            'RESET_OR_WRAP' { 'WARNING' }
            default { 'UNKNOWN' }
        }

        # Ensure comparison corresponds to latest NIC snapshot
        if ($NICFile) {
            $LatestNIC = @(
                Import-Csv $NICFile.FullName |
                    Where-Object NIC -eq $NIC.NIC
            )

            if (
                $LatestNIC.Count -ne 1 -or
                $LatestNIC[0].Timestamp -ne $NIC.CurrentTimestamp
            ) {
                $Status = 'UNKNOWN'
            }
        }
        else {
            $Status = 'UNKNOWN'
        }

        Add-Result 'Network' "$($NIC.NIC) error delta" `
            "$($NIC.Status); CRC=$($NIC.CRCDelta); Length=$($NIC.LengthErrorDelta); Missed=$($NIC.MissedErrorDelta)" `
            $Status $NIC.CurrentTimestamp
    }
}
else {
    Add-Result 'Network' 'NIC comparison' 'Missing' 'UNKNOWN' ''
}

# 4. Configuration baseline
if ($BaselineFile) {
    $Baseline = @(Import-Csv $BaselineFile.FullName)

    $Failures = @($Baseline | Where-Object Status -eq 'FAIL')
    $Passes = @($Baseline | Where-Object Status -eq 'PASS')
    $Unexpected = @(
        $Baseline | Where-Object Status -notin @('PASS', 'FAIL')
    )

    $Status = if ($Failures.Count -gt 0) {
        'FAIL'
    }
    elseif ($Baseline.Count -eq 0 -or $Unexpected.Count -gt 0) {
        'UNKNOWN'
    }
    else {
        'PASS'
    }

    Add-Result 'Configuration' 'Baseline checks' `
        "$($Passes.Count) passed; $($Failures.Count) failed" `
        $Status $BaselineFile.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')

    foreach ($Failure in $Failures) {
        Add-Result 'Configuration' $Failure.Component `
            "Expected=$($Failure.Expected); Actual=$($Failure.Actual)" `
            'FAIL' $BaselineFile.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
    }
}
else {
    Add-Result 'Configuration' 'Baseline report' 'Missing' 'UNKNOWN' ''
}

# 5. Overall assessment
$Statuses = @($Results | Select-Object -ExpandProperty Status)

$OverallStatus = if ('FAIL' -in $Statuses) {
    'FAIL'
}
elseif ('UNKNOWN' -in $Statuses) {
    'UNKNOWN'
}
elseif ('WARNING' -in $Statuses) {
    'WARNING'
}
else {
    'PASS'
}

Write-Host "`n=== CONSOLIDATED LAB REPORT ===" -ForegroundColor Cyan
$Results | Format-Table Component,Metric,Value,Status -AutoSize -Wrap

Write-Host "`nOverall Status: $OverallStatus"

# 6. Export
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$ReportPath = Join-Path $OutputDirectory "ESXi-LabReport-$Timestamp.csv"

$Results | Export-Csv -Path $ReportPath -NoTypeInformation

Write-Host "Report exported to: $ReportPath" -ForegroundColor Green
Write-Host "Note: Results reflect their source timestamps, not live telemetry."

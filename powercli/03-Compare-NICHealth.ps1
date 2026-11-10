
# VMware Automation & Infrastructure-as-Code Lab
# Stage 3 - PowerCLI
# Script: 03-Compare-NICHealth.ps1
# Purpose: Compare two ESXi NIC health snapshots
# Operation: Read-only; processes existing CSV files

param(
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'

if (-not $OutputDirectory) {
    $RepoRoot = Split-Path $PSScriptRoot -Parent
    $WorkspaceRoot = Split-Path $RepoRoot -Parent
    $OutputDirectory = Join-Path $WorkspaceRoot 'output'
}

# Find the two latest timestamped NIC snapshots.
$Files = @(
    Get-ChildItem -Path $OutputDirectory `
        -Filter 'ESXi-NICHealth-*.csv' -File |
        Sort-Object Name |
        Select-Object -Last 2
)

if ($Files.Count -lt 2) {
    throw "At least two timestamped NIC reports are required."
}

$Previous = @(Import-Csv $Files[0].FullName)
$Current  = @(Import-Csv $Files[1].FullName)

if (-not $Previous.Count -or -not $Current.Count) {
    throw "One or both NIC reports contain no data."
}

$Counters = @(
    'PacketsReceived'
    'CRCerrors'
    'LengthErrors'
    'MissedErrors'
    'ReceiveDropped'
)

# Match NICs by name rather than relying on CSV row order.
$Results = foreach ($NIC in $Current) {

    $OldNIC = @($Previous | Where-Object NIC -eq $NIC.NIC)

    if ($OldNIC.Count -ne 1) {
        Write-Warning "No unique previous record for $($NIC.NIC)"
        continue
    }

    $Delta = @{}
    $CounterReset = $false

    foreach ($Counter in $Counters) {

        $OldValue = [long]$OldNIC[0].$Counter
        $NewValue = [long]$NIC.$Counter

        $Difference = $NewValue - $OldValue

        if ($Difference -lt 0) {
            $CounterReset = $true
        }

        $Delta[$Counter] = $Difference
    }

    # Negative deltas invalidate ordinary error comparisons.
    if ($CounterReset) {
        $Status = 'RESET_OR_WRAP'
    }
    elseif (
        $Delta.CRCerrors -gt 0 -or
        $Delta.LengthErrors -gt 0 -or
        $Delta.MissedErrors -gt 0 -or
        $Delta.ReceiveDropped -gt 0
    ) {
        $Status = 'WARNING'
    }
    else {
        $Status = 'NO_NEW_ERRORS'
    }

    [PSCustomObject]@{
        NIC               = $NIC.NIC
        PreviousTimestamp = $OldNIC[0].Timestamp
        CurrentTimestamp  = $NIC.Timestamp
        PacketDelta       = if ($CounterReset) { $null } else { $Delta.PacketsReceived }
        CRCDelta          = if ($CounterReset) { $null } else { $Delta.CRCerrors }
        LengthErrorDelta  = if ($CounterReset) { $null } else { $Delta.LengthErrors }
        MissedErrorDelta  = if ($CounterReset) { $null } else { $Delta.MissedErrors }
        DroppedDelta      = if ($CounterReset) { $null } else { $Delta.ReceiveDropped }
        Status            = $Status
    }
}

if (-not $Results) {
    throw "No matching NICs were found in the two reports."
}

Write-Host "`n=== NIC HEALTH COMPARISON ===" -ForegroundColor Cyan
$Results | Format-List

$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$ReportPath = Join-Path $OutputDirectory "ESXi-NICComparison-$Timestamp.csv"

$Results | Export-Csv -Path $ReportPath -NoTypeInformation

Write-Host "Comparison exported to: $ReportPath" -ForegroundColor Green

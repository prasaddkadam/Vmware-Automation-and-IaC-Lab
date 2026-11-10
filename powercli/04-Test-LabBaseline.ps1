
# VMware Automation & Infrastructure-as-Code Lab
# Stage 3 - Checkpoint 12
# Script: 04-Test-LabBaseline.ps1
# Purpose: Validate ESXi and VM configuration
# Operation: Read-only

param(
    [string]$ESXiServer = '192.168.0.41',
    [string]$VMName = 'LINUX01'
)

$ErrorActionPreference = 'Stop'

# Save reports outside the Git repository
$RepoRoot = Split-Path $PSScriptRoot -Parent
$WorkspaceRoot = Split-Path $RepoRoot -Parent
$OutputDirectory = Join-Path $WorkspaceRoot 'output'

New-Item -ItemType Directory -Path $OutputDirectory -Force |
    Out-Null

# Reuse an existing connection
$Connection = $global:DefaultVIServers |
    Where-Object {
        $_.Name -eq $ESXiServer -and $_.IsConnected
    } |
    Select-Object -First 1

if (-not $Connection) {
    $Connection = Connect-VIServer -Server $ESXiServer
}

$Results = [System.Collections.Generic.List[object]]::new()

function Add-BaselineCheck {
    param(
        [string]$Component,
        [string]$Expected,
        [string]$Actual
    )

    $Status = if ($Expected -eq $Actual) {
        'PASS'
    }
    else {
        'FAIL'
    }

    $script:Results.Add([PSCustomObject]@{
        Component = $Component
        Expected  = $Expected
        Actual    = $Actual
        Status    = $Status
    })
}

# 1. ESXi host
$ESXiHost = Get-VMHost -Server $Connection |
    Select-Object -First 1

if (-not $ESXiHost) {
    throw 'ESXi host could not be retrieved.'
}

Add-BaselineCheck 'ESXi Version' '8.0.3' $ESXiHost.Version
Add-BaselineCheck 'Host Connection' 'Connected' ([string]$ESXiHost.ConnectionState)

# 2. Storage
$Datastore = Get-Datastore -Server $Connection |
    Where-Object Name -eq 'datastore1' |
    Select-Object -First 1

Add-BaselineCheck 'Datastore Exists' 'True' ([string][bool]$Datastore)

if ($Datastore) {
    Add-BaselineCheck 'Datastore Type' 'VMFS' ([string]$Datastore.Type)
}

# 3. Virtual networking
$VSwitch = Get-VirtualSwitch -Server $Connection |
    Where-Object Name -eq 'vSwitch0' |
    Select-Object -First 1

Add-BaselineCheck 'Virtual Switch' 'True' ([string][bool]$VSwitch)

$PortGroups = @(Get-VirtualPortGroup -Server $Connection)

foreach ($PGName in @('VM Network', 'Management Network')) {

    $PG = $PortGroups |
        Where-Object Name -eq $PGName |
        Select-Object -First 1

    Add-BaselineCheck "$PGName Exists" 'True' ([string][bool]$PG)

    if ($PG) {
        Add-BaselineCheck "$PGName VLAN" '0' ([string]$PG.VLanId)
        Add-BaselineCheck "$PGName Switch" 'vSwitch0' ([string]$PG.VirtualSwitch.Name)
    }
}

# 4. Virtual machine
$VM = Get-VM -Name $VMName -Server $Connection -ErrorAction SilentlyContinue

Add-BaselineCheck 'LINUX01 Exists' 'True' ([string][bool]$VM)

if ($VM) {

    Add-BaselineCheck 'LINUX01 vCPU' '2' ([string]$VM.NumCpu)
    Add-BaselineCheck 'LINUX01 RAM (GB)' '2' ([string]$VM.MemoryGB)

    # Validate virtual disk
    $Disks = @($VM | Get-HardDisk)

    Add-BaselineCheck 'LINUX01 Disk Count' '1' ([string]$Disks.Count)

    if ($Disks.Count -eq 1) {
        Add-BaselineCheck 'LINUX01 Disk (GB)' '25' ([string]$Disks[0].CapacityGB)
        Add-BaselineCheck 'LINUX01 Disk Format' 'Thin' ([string]$Disks[0].StorageFormat)
    }

    # Validate virtual NIC
    $Adapters = @($VM | Get-NetworkAdapter)

    Add-BaselineCheck 'LINUX01 NIC Count' '1' ([string]$Adapters.Count)

    if ($Adapters.Count -eq 1) {
        Add-BaselineCheck 'LINUX01 NIC Type' 'Vmxnet3' ([string]$Adapters[0].Type)
        Add-BaselineCheck 'LINUX01 Network' 'VM Network' ([string]$Adapters[0].NetworkName)
    }
}

# 5. Display summary
Write-Host "`n=== LAB BASELINE VALIDATION ===" -ForegroundColor Cyan

$Results | Format-Table -AutoSize

$Passed = @($Results | Where-Object Status -eq 'PASS').Count
$Failed = @($Results | Where-Object Status -eq 'FAIL').Count

$OverallStatus = if ($Failed -eq 0) { 'PASS' } else { 'FAIL' }

Write-Host "`nPassed: $Passed"
Write-Host "Failed: $Failed"
Write-Host "Overall Result: $OverallStatus"

# 6. Export CSV report
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$ReportPath = Join-Path $OutputDirectory "ESXi-Baseline-$Timestamp.csv"

$Results | Export-Csv -Path $ReportPath -NoTypeInformation

Write-Host "`nReport exported to: $ReportPath" -ForegroundColor Green

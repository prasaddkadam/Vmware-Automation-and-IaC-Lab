
# VMware Automation & Infrastructure-as-Code Lab
# Stage 3 - PowerCLI
# Script: 02-Get-ESXiHostHealth.ps1
# Purpose: Export read-only ESXi host-health information

param(
    [string]$ESXiServer = '192.168.0.41',
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'

# Default output folder is outside the cloned repository.
if (-not $OutputDirectory) {
    $RepoRoot = Split-Path $PSScriptRoot -Parent
    $WorkspaceRoot = Split-Path $RepoRoot -Parent
    $OutputDirectory = Join-Path $WorkspaceRoot 'output'
}

New-Item -ItemType Directory -Path $OutputDirectory -Force |
    Out-Null

# Reuse an existing API connection where possible.
$Connection = $global:DefaultVIServers |
    Where-Object {
        $_.Name -eq $ESXiServer -and $_.IsConnected
    } |
    Select-Object -First 1

if (-not $Connection) {
    $Connection = Connect-VIServer -Server $ESXiServer
}

$HostVM = Get-VMHost -Server $Connection |
    Select-Object -First 1

if (-not $HostVM) {
    throw 'No ESXi host was returned.'
}

$Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$FileTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

# 1. CPU and memory
$HostHealth = [PSCustomObject]@{
    Timestamp       = $Timestamp
    HostName        = $HostVM.Name
    Version         = $HostVM.Version
    ConnectionState = $HostVM.ConnectionState
    CpuTotalMHz     = $HostVM.CpuTotalMhz
    CpuUsedMHz      = $HostVM.CpuUsageMhz
    CpuUsedPct      = [math]::Round(
        ($HostVM.CpuUsageMhz / $HostVM.CpuTotalMhz) * 100, 2
    )
    MemoryTotalGB   = [math]::Round($HostVM.MemoryTotalGB, 2)
    MemoryUsedGB    = [math]::Round($HostVM.MemoryUsageGB, 2)
    MemoryUsedPct   = [math]::Round(
        ($HostVM.MemoryUsageGB / $HostVM.MemoryTotalGB) * 100, 2
    )
}

# 2. Datastore utilisation
$DatastoreHealth = @(
    Get-Datastore -RelatedObject $HostVM -Server $Connection |
        ForEach-Object {
            [PSCustomObject]@{
                Timestamp  = $Timestamp
                Name       = $_.Name
                Type       = $_.Type
                CapacityGB = [math]::Round($_.CapacityGB, 2)
                FreeGB     = [math]::Round($_.FreeSpaceGB, 2)
                UsedPct    = if ($_.CapacityGB -gt 0) {
                    [math]::Round(
                        (1 - $_.FreeSpaceGB / $_.CapacityGB) * 100, 2
                    )
                }
                else { $null }
            }
        }
)

# 3. Physical NIC error counters through ESXCLI V2
$EsxCli = Get-EsxCli -VMHost $HostVM -V2

$NICHealth = @(
    Get-VMHostNetworkAdapter -VMHost $HostVM -Physical |
        ForEach-Object {
            $NICName = $_.Name

            $NICArgs = $EsxCli.network.nic.stats.get.CreateArgs()
            $NICArgs.nicname = $NICName

            $Stats = $EsxCli.network.nic.stats.get.Invoke($NICArgs)

            [PSCustomObject]@{
                Timestamp           = $Timestamp
                NIC                 = $NICName
                PacketsReceived     = $Stats.Packetsreceived
                CRCerrors           = $Stats.ReceiveCRCerrors
                LengthErrors        = $Stats.Receivelengtherrors
                MissedErrors        = $Stats.Receivemissederrors
                ReceiveDropped      = $Stats.Receivepacketsdropped
                TotalReceiveErrors  = $Stats.Totalreceiveerrors
                TotalTransmitErrors = $Stats.Totaltransmiterrors
            }
        }
)

# 4. Display results
Write-Host "`n=== ESXi HOST HEALTH ===" -ForegroundColor Cyan
$HostHealth | Format-List

Write-Host "`n=== DATASTORE HEALTH ===" -ForegroundColor Cyan
$DatastoreHealth | Format-Table -AutoSize

Write-Host "`n=== PHYSICAL NIC HEALTH ===" -ForegroundColor Cyan
$NICHealth | Format-Table -AutoSize

# Export timestamped health reports
$HostHealth | Export-Csv (
    Join-Path $OutputDirectory "ESXi-HostHealth-$FileTimestamp.csv"
) -NoTypeInformation

$DatastoreHealth | Export-Csv (
    Join-Path $OutputDirectory "ESXi-DatastoreHealth-$FileTimestamp.csv"
) -NoTypeInformation

$NICHealth | Export-Csv (
    Join-Path $OutputDirectory "ESXi-NICHealth-$FileTimestamp.csv"
) -NoTypeInformation

Write-Host "`nReports exported to: $OutputDirectory" -ForegroundColor Green

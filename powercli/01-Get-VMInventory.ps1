
# VMware Automation & IaC Lab
# Stage 3 - PowerCLI
# Script: 01-Get-VMInventory.ps1
# Purpose: Export ESXi virtual machine inventory to CSV
# Operation: Read-only

$ErrorActionPreference = 'Stop'

$ESXiServer = '192.168.0.41'

# Establish connection if not already connected
$Connection = $global:DefaultVIServers |
    Where-Object { $_.Name -eq $ESXiServer -and $_.IsConnected } |
    Select-Object -First 1

if (-not $Connection) {
    $Connection = Connect-VIServer -Server $ESXiServer
}

# Retrieve virtual machines
$VMs = Get-VM -Server $Connection

# Build an inventory using PowerShell objects
$Inventory = foreach ($VM in $VMs) {

    $Disk = $VM | Get-HardDisk | Select-Object -First 1
    $NIC  = $VM | Get-NetworkAdapter | Select-Object -First 1

    [PSCustomObject]@{
        VMName        = $VM.Name
        PowerState    = $VM.PowerState
        vCPU          = $VM.NumCpu
        MemoryGB      = $VM.MemoryGB
        DiskGB        = $Disk.CapacityGB
        StorageFormat = $Disk.StorageFormat
        Network       = $NIC.NetworkName
        NICType       = $NIC.Type
        ESXiHost      = $VM.VMHost.Name
    }
}

# Display results
$Inventory | Format-Table -AutoSize

# Calculate the workspace directory above the repository
$RepoRoot = Split-Path $PSScriptRoot -Parent
$WorkspaceRoot = Split-Path $RepoRoot -Parent

$OutputDir = Join-Path $WorkspaceRoot 'output'
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$OutputPath = Join-Path $OutputDir 'VM-Inventory.csv'

$Inventory | Export-Csv -Path $OutputPath -NoTypeInformation

Write-Host "Inventory exported to: $OutputPath"

# Project Log

## 2026-11-01 — VMware Platform Foundation

### Objective

Establish the physical VMware host and create a stable baseline before deploying virtual machines or introducing automation.

### Platform

- Intel Core i5-13500T
- 32 GB RAM
- 256 GB NVMe SSD
- Intel I219-LM 1 GbE
- VMware ESXi 8

### Implemented

- Enabled Intel VT-x and VT-d
- Installed VMware ESXi directly on the physical host
- Configured the ESXi hostname and FQDN
- Configured management networking
- Created a DHCP reservation for the management interface
- Verified gateway and external network connectivity
- Configured DNS
- Configured and verified NTP synchronisation
- Validated the VMFS datastore
- Examined the ESXi virtual networking architecture
- Enabled SSH for administrative testing

### Troubleshooting

The ESXi installer initially encountered two boot-related problems:

1. UEFI Secure Boot prevented the installation media from starting.
2. ESXi generated a CPU uniformity PSOD because of the Intel hybrid P-core/E-core architecture.

The CPU compatibility issue was resolved using:

`cpuUniformityHardCheckPanic=FALSE`

The setting was subsequently configured persistently.

### Verification

Validated:

- ESXi Host Client access
- SSH access
- Physical NIC status
- 1 GbE network link
- VMkernel management interface
- Default route
- Internet connectivity
- DNS resolution
- NTP synchronisation
- VMFS datastore availability

### Next Milestone

Deploy the first virtual machine manually and record the configuration decisions that will later become automation candidates.

---

## 2026-11-08 — ESXi Network Remediation

### Objective

Restore reliable ESXi management connectivity to enable
deployment of the first Linux virtual machine.

### Investigation

- Diagnosed failed SCP and datastore ISO uploads.
- Identified receive CRC errors and physical NIC link drops.
- Isolated cables, switch, router ports and workstation interfaces.
- Compared ESXi `ne1000` against Ubuntu Live `e1000e`.
- Validated approximately 749 Mbit/s throughput under Ubuntu.

### Remediation

Upgraded HP Pro Mini 400 G9 U23 BIOS from 02.15.12 to 02.23.00.

Saved ESXi TPM encryption recovery material and generated
a host configuration backup before performing firmware maintenance.

### Verification

- ESXi booted successfully.
- 100 MB SCP transfer completed.
- Ubuntu Server ISO uploaded successfully.

### Outcome

The immediate networking blocker was resolved,
allowing Stage 2 VM deployment to proceed.

### Incident Report

[INC-001 — ESXi Network Instability](incidents/INC-001-esxi-network-instability.md)

### Next Milestone

Deploy and configure LINUX01.

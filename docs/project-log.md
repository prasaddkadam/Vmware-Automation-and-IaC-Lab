# Project Log

## 2026-11-01 — VMware Platform Foundation

### Objective

Establish the physical VMware host and create a stable baseline before deploying virtual machines or introducing automation.

### Platform

- HP Pro Mini 400 G9
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

# Troubleshooting

This document records significant technical issues encountered while building the lab, including evidence, root cause, resolution and verification.

---

## ESXi Installation Media Rejected by UEFI Secure Boot

### Symptom

The HP firmware displayed:

> Selected boot image did not authenticate.

before the ESXi installer could start.

### Layer

Firmware / UEFI boot validation.

### Cause

The firmware Secure Boot configuration rejected the ESXi USB bootloader.

### Resolution

Secure Boot was disabled for the initial ESXi installation.

### Verification

The USB installer subsequently booted successfully.

---

## ESXi CPU Uniformity PSOD

### Symptom

During ESXi startup the host generated a PSOD containing:

`Fatal CPU mismatch on feature "Cores per package"`

### Hardware

Intel Core i5-13500T.

### Cause

The processor uses Intel's hybrid architecture with Performance and Efficiency cores. ESXi detected non-uniform CPU characteristics and triggered its CPU uniformity hard check.

### Resolution

The installer was booted using:

`cpuUniformityHardCheckPanic=FALSE`

After successful installation the configuration was made persistent.

### Verification

ESXi subsequently booted successfully and the kernel setting was verified as disabled.

### Lesson Learned

Enterprise hypervisors may expose hardware-compatibility assumptions that are not normally visible when running consumer operating systems, particularly on newer heterogeneous CPU architectures.

---

## ESXi Management Network Instability — INC-001

**Status:** Monitoring — recurring network instability observed

During preparation for the first VM deployment, the ESXi management
connection experienced repeated failures under sustained inbound traffic.

Investigation included physical network isolation, NIC statistics,
kernel log analysis and Ubuntu Live cross-platform testing.

Updating the HP U23 BIOS from 02.15.12 to 02.23.00 was followed by
successful 100 MB SCP and Ubuntu Server ISO transfers.

During the first Ubuntu VM installation, ESXi management interruptions recurred and cumulative NIC statistics showed 415 CRC errors and repeated physical link flaps. The HP BIOS **PCI Express Power Management** setting was then disabled for testing. The rebuilt VM subsequently installed successfully, but a durable NIC fix has not yet been demonstrated. The precise underlying defect remains unconfirmed.

**Full report:** [INC-001 — ESXi Network Instability](incidents/INC-001-esxi-network-instability.md)

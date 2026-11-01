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

# INC-001 — ESXi Management Network Instability

**Date:** 8 November 2026  
**Status:** Monitoring — recurrence observed following initial BIOS remediation  
**Affected component:** ESXi management networking (`vmnic0`)  
**Related stage:** Stage 1 — Platform Foundation / Stage 2 preparation

## 1. Incident Summary

During preparation of the first Linux virtual machine, attempts to upload the Ubuntu Server installation ISO to the ESXi datastore repeatedly failed.

Both browser-based uploads and SCP transfers experienced interruptions. Further investigation identified increasing NIC receive errors and intermittent physical link drops under network load.

A firmware update was applied to the physical host. Following the update, a 100 MB SCP test and the complete Ubuntu Server ISO transfer succeeded.

## 2. Environment

| Component | Configuration |
|---|---|
| Physical host | HP Pro Mini 400 G9 |
| Processor | Intel Core i5-13500T |
| Memory | 32 GB |
| Hypervisor | VMware ESXi 8.0.3, build 24677879 |
| Physical NIC | Intel I219-LM, 1 GbE |
| ESXi NIC driver | `ne1000` 0.9.2 |
| NIC firmware reported by ESXi | `2.5-4` |
| VMkernel management interface | `vmk0` |
| Physical uplink | `vmnic0` |
| Datastore | `datastore1`, VMFS-6 |

## 3. Symptoms

- Datastore ISO uploads stalled or failed.
- SCP connections terminated with `Connection reset` or `Broken pipe`.
- Small and large transfers both experienced failures.
- ICMP connectivity to the ESXi management interface became intermittent during transfers.
- NIC receive CRC and length error counters increased.
- ESXi kernel logs recorded physical NIC link-down and link-up events.

## 4. Investigation

### Network isolation

The physical network path was progressively simplified to eliminate possible causes.

Tests included:

- Bypassing the unmanaged Ethernet switch
- Connecting the host directly to the router
- Testing different router Ethernet ports
- Replacing the Ethernet cable with a short known-good cable
- Testing transfers from both wired and wireless management-workstation connections
- Reducing SCP transfer speed

These changes did not reliably eliminate the failures under ESXi.

### ESXi NIC diagnostics

The physical NIC was inspected using:

```bash
esxcli network nic get -n vmnic0
esxcli network nic stats get -n vmnic0
```

Kernel events were examined using:

```bash
grep -iE 'ne1000|rx hang|link is down|link is up' /var/log/vmkernel.log
```

The investigation identified receive-side errors and physical link interruptions associated with unsuccessful transfers.

### Cross-operating-system comparison

To distinguish a hardware problem from an ESXi-specific issue, the Mini PC was booted from an Ubuntu Live USB without modifying the ESXi installation.

Ubuntu detected the same Intel I219-LM NIC using the Linux `e1000e` driver.

NIC counters were examined with:

```bash
sudo ethtool -S eno1
```

Network throughput was tested using `iperf3`:

```bash
iperf3 -c <test-server-ip> -p 5201 -t 30
```

The Ubuntu test successfully transferred approximately 2.62 GB over 30 seconds at an average throughput of approximately 749 Mbit/s using a wired management workstation connection.

The test also passed over Wi-Fi, without increases in the monitored NIC error counters.

This substantially reduced the likelihood of a persistent physical NIC, cable, switch or router fault.

## 5. Root Cause Assessment

The evidence indicated an ESXi-specific network compatibility or firmware interaction involving the onboard Intel I219-LM adapter.

ESXi used the `ne1000` driver, whereas Ubuntu used `e1000e`.

However, the exact low-level defect was not conclusively identified. The investigation did not establish that `ne1000` alone was responsible.

**Assessment:** Probable ESXi-specific NIC/firmware compatibility issue; precise mechanism unconfirmed.

## 6. Remediation

The HP system BIOS was upgraded:

| Property | Before | After |
|---|---|---|
| BIOS family | U23 | U23 |
| BIOS version | 02.15.12 | 02.23.00 |
| BIOS date | 3 September 2024 | 27 July 2026 |

Prior to the update:

- ESXi host configuration backup was generated.
- TPM-backed ESXi configuration encryption was identified.
- The ESXi encryption recovery key was securely saved outside the host.
- Existing ESXi and firmware settings were considered for post-update verification.

The update was performed using HP's built-in BIOS update utility.

ESXi subsequently booted successfully without reported startup problems.

## 7. Post-Change Verification

The following tests succeeded after the firmware update:

| Test | Result |
|---|---|
| ESXi boot | Passed |
| SSH management connectivity | Passed |
| 100 MB SCP transfer | Passed |
| Complete Ubuntu Server ISO upload | Passed |

The successful transfers demonstrated that the previously reproducible upload failures were no longer occurring in these tests.

These transfers established only an initial improvement. Subsequent VM installation activity exposed renewed ESXi management outages and physical link-down events. A later NIC sample showed cumulative receive CRC errors of 415, with 348 receive length and 348 receive missed errors. The exact cause remains unresolved.

### Subsequent diagnostic change — PCI Express Power Management

During a further BIOS investigation, the physical host's **PCI Express Power Management** option was disabled as a controlled troubleshooting experiment. The rebuilt `LINUX01` guest then installed and booted successfully, and an ESXi NIC sample showed zero CRC errors and 38 receive length/missed errors since NIC initialisation. One `vmnic0` link-down entry was also present near the maintenance period; its cause was not established. No post-change long-duration stability test has yet confirmed a permanent fix.

**Assessment:** Retain as a provisional mitigation only. Continue to measure CRC/error deltas and new link-down events under load. Do not attribute causality solely to PCIe power management.

## 8. Lessons Learned

1. Successful link negotiation and ICMP connectivity do not guarantee stable connectivity under sustained network load.
2. NIC receive error counters and kernel logs provide stronger diagnostic evidence than basic connectivity tests alone.
3. Simplifying the physical network path helps isolate cables, switches and router ports.
4. Booting an alternative operating system on the same hardware provides a useful A/B comparison.
5. Firmware versions should be included in infrastructure compatibility baselines.
6. TPM recovery material and configuration backups are essential considerations before host firmware maintenance.
7. A successful remediation does not necessarily prove the precise underlying root cause.

## 9. Operational Outcome

The ESXi management connection successfully supported the transfers needed for VM deployment.

The Ubuntu Server ISO was uploaded to the datastore, and the rebuilt `LINUX01` subsequently passed guest login, SSH, package-update and VMware Tools verification. The initial deployment milestone is complete, but host network stability remains an open operational risk.

## 10. Follow-up

- Monitor `vmnic0` receive CRC, length and missed-error counters.
- Monitor ESXi kernel logs for any recurrence of physical link drops.
- Reassess NIC-driver compatibility if the issue returns.
- Introduce automated host health checks in the future PowerCLI stage.

---

**Related documentation:**

- [Platform Foundation](../stages/01-platform-foundation.md)
- [Project Log](../project-log.md)
- [Troubleshooting Index](../troubleshooting.md)

# Stage 2 — Manual Infrastructure Baseline

## Objective

Deploy and verify the first virtual machine manually on the existing standalone ESXi host. Record the infrastructure objects and guest configuration so later PowerCLI and Infrastructure-as-Code work can target a known-good baseline rather than rebuilding a second lab.

**Milestone date:** 9 November 2026  
**VM:** `LINUX01`  
**Milestone:** First Linux VM installed and verified; physical ESXi NIC stability remains under observation (see [INC-001](../incidents/INC-001-esxi-network-instability.md)).

## 1. ESXi VM configuration

| Component | Configured value |
|---|---|
| Hypervisor | VMware ESXi 8.0.3, build 24677879 |
| VM name | `LINUX01` |
| Virtual hardware compatibility | ESXi 8.0 U2 virtual machine |
| Guest OS selection | Ubuntu Linux (64-bit) |
| Installed OS | Ubuntu Server 24.04.5 LTS |
| vCPU | 2 |
| Memory | 2048 MB |
| Datastore | `datastore1` (VMFS-6) |
| Disk | 25 GB VMDK |
| Provisioning | Thin |
| Disk mode | Dependent |
| SCSI controller | VMware Paravirtual (PVSCSI) |
| Virtual NIC | VMXNET3 |
| Port group | `VM Network` |
| Virtual firmware | EFI |
| VM UEFI Secure Boot | Disabled for initial lab build |
| Installation source | `[datastore1] ISOs/ubuntu-24.04.5-live-server-amd64.iso` |
| CD/DVD after installation | Installation ISO disconnected |

The management interface `vmk0` and VM port group share `vSwitch0` and physical uplink `vmnic0`. Each VM has its own virtual NIC/MAC address, even though the ESXi host uses one physical Ethernet port.

## 2. Guest installation decisions

- Standard Ubuntu Server installation, not minimised.
- Guest network configured via DHCP; no HTTP proxy.
- Default Ubuntu archive mirror; repository connectivity test passed.
- Guided storage using the full virtual disk with LVM; LUKS encryption not enabled.
- Hostname: `linux01`; administration account: `labadmin` (sudo).
- OpenSSH Server installed; password login initially enabled for lab onboarding.
- No featured server snaps selected.
- The installation ISO was disconnected before the first successful boot from VMDK.

**Security:** Passwords, SSH secrets and recovery keys are not stored in this repository. SSH is for the trusted lab LAN; no public router port-forwarding is required. Key-based SSH authentication is a later improvement.

## 3. Virtual disk and Linux storage layout

The 25 GB VMDK is exposed to Ubuntu as `/dev/sda`.

| Guest device / mount | Approximate size | Purpose |
|---|---:|---|
| `/dev/sda1` → `/boot/efi` | 1 GB | EFI System Partition |
| `/dev/sda2` → `/boot` | 2 GB | Boot filesystem |
| `/dev/sda3` | 21.9 GB | LVM physical volume |
| `ubuntu-vg/ubuntu-lv` → `/` | 11 GB | ext4 root filesystem |
| Unallocated volume-group capacity | ~10.9 GB | Future LVM expansion exercise |

At initial validation, `df -h` showed approximately 4.7 GB used and 5.5 GB available on `/` (46% utilised). Free space within the LVM volume group is different from free space within the mounted root filesystem.

## 4. Guest network and administration

The guest virtual NIC was recognised as `ens34`, configured via DHCP. At verification it held `192.168.0.83/24`; this is a **temporary observed lease**, not a guaranteed static address.

The management workstation successfully connected using:

```powershell
ssh labadmin@<LINUX01-IP>
```

Ubuntu 24.04 OpenSSH is configured with systemd socket activation: `ssh.socket` can listen and start `ssh.service` when a connection arrives. `ssh.service` was observed active after a successful remote login. Its `disabled` unit state alone was not a failure.

## 5. VMware guest integration

Ubuntu's `open-vm-tools` package was updated through APT and verified:

```bash
vmware-toolbox-cmd -v
systemctl status open-vm-tools --no-pager
systemctl list-units --type=service | grep -i vm
```

Observed version: **13.0.10.0 (build-25056151)**. `open-vm-tools.service` and `vgauth.service` were active. VMware Tools is guest-managed through Ubuntu packages; an ESXi Host Client message such as *VMware Tools is not managed by vSphere* does not mean the guest service is absent.

## 6. Verification evidence

| Test | Observed result |
|---|---|
| VM boots from virtual disk | Passed |
| Ubuntu login with `labadmin` | Passed |
| `whoami` | `labadmin` |
| `hostnamectl` | `linux01`; Ubuntu 24.04.5 LTS |
| `ip -br addr` | `ens34` up, DHCP IPv4 address |
| SSH from Windows management laptop | Passed |
| `sudo apt update` | Passed; repository metadata fetched |
| Ubuntu package update | Completed; no reboot required |
| `open-vm-tools.service` | Active (running) |
| `vmware-toolbox-cmd -v` | 13.0.10.0 |
| `lsblk` / `df -h` | Expected 25 GB disk, EFI/boot/LVM layout |

The initial installation attempt failed while configuring APT (`apt-get update`, exit status 100), alongside recurring host connectivity interruptions. The VM was removed and rebuilt; the subsequent installation and verification succeeded. The causal relationship between the guest APT failure and the ESXi NIC issue was **not conclusively proven**.

## 7. Host networking caveat — INC-001

After upgrading the physical host BIOS from U23 02.15.12 to 02.23.00, a 100 MB SCP transfer and full Ubuntu ISO upload succeeded. However, later guest installation activity coincided with renewed ESXi management interruptions, physical `vmnic0` link events, and increased error counters (including 415 cumulative CRC errors on one earlier sample).

The HP BIOS setting **PCI Express Power Management** was subsequently disabled as a controlled experiment. The rebuilt Ubuntu VM installed successfully; in a later ESXi sample, CRC errors were zero, while receive length/missed errors were 38 each. This **does not yet establish a durable fix**. Continue monitoring and do not mark the NIC issue permanently resolved based only on the successful VM build.

See [INC-001 — ESXi Management Network Instability](../incidents/INC-001-esxi-network-instability.md).

## 8. Automation candidate list

These manual tasks are candidates for later repeatable PowerCLI / API / IaC workflows:

| Manual action | Potential automation |
|---|---|
| Select datastore and create VM | PowerCLI VM provisioning |
| Assign vCPU, RAM and guest OS | Parameterised VM specification |
| Attach 25 GB thin VMDK | Declarative disk configuration |
| Select VMXNET3 and port group | Standardised VM network configuration |
| Set EFI firmware / secure-boot policy | VM configuration baseline |
| Attach installation ISO | PowerCLI media management |
| Install guest OS and initial account | Unattended install / cloud-init (future) |
| Enable SSH and guest tools | Configuration management (Ansible) |
| Validate IP, SSH, Tools and disk | Automated health checks |
| Record results | Generate machine-readable deployment evidence |

**Design boundary:** PowerCLI/Terraform provision or manage VM infrastructure; Ansible/cloud-init configure the guest. Terraform provider support for a standalone ESXi host must be validated before selecting a provisioning implementation.

## 9. Stage outcome and next steps

**First VM manual deployment: complete.** The initial working Linux guest now exists on the same platform that will later be automated.

Next steps:
1. Continue observing host NIC link events and receive error deltas.
2. Introduce SSH keys and clarify guest IP reservation/naming.
3. Capture repeatable VM inventory/configuration through PowerCLI.
4. Evaluate provider/API capabilities before Terraform implementation.

# Stage 1 — Platform Foundation

## Objective

Establish a stable VMware ESXi platform on dedicated physical hardware before deploying virtual machines or introducing infrastructure automation.

The stage focused on:

- Hardware assessment
- BIOS and virtualisation configuration
- ESXi installation
- Management networking
- VMware virtual networking fundamentals
- Storage validation
- DNS and NTP configuration
- Remote administration
- Hardware compatibility troubleshooting
- Establishing a baseline for later PowerCLI and Terraform automation

The objective was deliberately limited to the infrastructure foundation. No production-style VM environment was created during this stage.

---

## Hardware

### Physical Host

| Component | Specification |
|---|---|
| Platform | HP PC |
| CPU | Intel Core i5-13500T |
| CPU Topology | 14 cores / 20 threads |
| Architecture | Intel hybrid P-core / E-core |
| Memory | 32 GB DDR4-3200 |
| Memory Configuration | 2 × 16 GB |
| Storage | 256 GB Samsung NVMe SSD |
| Network Adapter | Intel I219-LM 1 GbE |
| Hypervisor | VMware ESXi 8 |

The host is dedicated to the VMware lab.

A separate personal laptop is used as the management and automation workstation.

---

## Architecture

### Initial Architecture

```text
                Management Workstation
                        │
              Browser / SSH / API
                        │
                  Home Network
                        │
                        ▼
                      HP PC
                        │
                   VMware ESXi
                        │
               ┌────────┴────────┐
               │                 │
         Management          VM Network
               │
              vmk0
```

The management workstation will later host:

- PowerShell
- VMware PowerCLI
- Terraform
- Git
- VS Code
- Docker
- Ansible
- Packer
- SSH tooling

This keeps automation tooling separate from the ESXi host.

---

# BIOS Configuration

Before installing ESXi, the host firmware configuration was reviewed.

The following virtualisation features were confirmed as enabled:

- Intel Virtualization Technology — VT-x
- Intel Virtualization Technology for Directed I/O — VT-d
- Hyper-Threading
- Intel Turbo Boost

These settings allow ESXi to use the CPU's hardware virtualisation capabilities and provide a foundation for future virtual machines and device virtualisation features.

### Firmware Maintenance

During subsequent network troubleshooting, the HP Pro Mini 400 G9
BIOS was upgraded from U23 02.15.12 to U23 02.23.00.

The update followed successful cross-OS network testing and
was performed after securing ESXi configuration recovery material.

Following the update, ESXi booted successfully and the previously
failing datastore transfer operations completed.

See [INC-001](../incidents/INC-001-esxi-network-instability.md).
---

# ESXi Installation

VMware ESXi 8 was installed directly onto the HP Mini PC as a bare-metal Type-1 hypervisor.

The installation path was:

```text
Bootable USB
     ↓
ESXi Installer
     ↓
Internal NVMe SSD
     ↓
VMware ESXi
```

The internal Samsung NVMe device was selected as the installation target.

ESXi subsequently created its system storage and VMFS datastore structure on the device.

---

## Secure Boot Issue

The first attempt to start the ESXi installer failed before ESXi itself loaded.

The HP firmware displayed:

```text
Selected boot image did not authenticate
```

This indicated a UEFI/Secure Boot validation issue rather than an ESXi runtime problem.

Secure Boot was disabled for the initial installation.

After the change, the ESXi USB installer successfully booted.

A detailed record is maintained in:

[`../troubleshooting.md`](../troubleshooting.md)

---

# Intel Hybrid CPU Compatibility

After the Secure Boot issue was resolved, ESXi encountered a Purple Screen of Death during startup.

The error included:

```text
Fatal CPU mismatch on feature "Cores per package"
```

The Intel Core i5-13500T uses a hybrid CPU architecture containing both Performance cores and Efficiency cores.

ESXi detected differences between the CPU core types during its CPU uniformity check.

The installer was successfully booted using:

```text
cpuUniformityHardCheckPanic=FALSE
```

After ESXi installation, the setting was made persistent.

Verification was performed using:

```bash
esxcli system settings kernel list | grep -i cpuUniformity
```

The configuration confirmed that:

```text
cpuUniformityHardCheckPanic = FALSE
```

The host subsequently booted successfully.

This was the first major hardware compatibility issue documented in the project.

---

# Host Identity

The default ESXi hostname was replaced with a dedicated lab identity.

Configured values:

```text
Hostname: esxi01
Domain:   home.arpa
FQDN:     esxi01.home.arpa
```

The configuration was verified using:

```bash
esxcli system hostname get
```

This established a predictable naming standard before additional infrastructure is deployed.

---

# Management Networking

The host currently uses the onboard Intel Ethernet controller.

ESXi identified the physical network adapter as:

```text
vmnic0
```

The adapter was validated as:

```text
Intel I219-LM
Driver: ne1000
Link: 1 Gbps
Duplex: Full
```

The NIC status was verified using:

```bash
esxcli network nic list
```

and:

```bash
esxcli network nic get -n vmnic0
```

---

## Management Addressing

The ESXi management interface uses DHCP with a router-side reservation.

This design was selected instead of configuring a manually assigned address directly on the host.

The resulting model is:

```text
ESXi vmk0
    │
DHCP Request
    │
Home Router
    │
Reserved Lease
    │
Predictable Management Address
```

The decision keeps home-network address management centralised while still providing a stable ESXi management address.

The exact management IP is intentionally not required for the public documentation.

---

# VMware Virtual Networking

The default ESXi networking configuration was examined before any VMs were created.

Current layout:

```text
Physical Network
       │
     vmnic0
       │
     vSwitch0
       │
 ┌─────┴──────────────┐
 │                    │
Management         VM Network
Network
 │
vmk0
```

---

## Physical NIC — `vmnic0`

`vmnic0` represents the physical Intel Ethernet adapter from the perspective of ESXi.

It provides the physical uplink between the VMware virtual networking stack and the home network.

---

## VMware Standard Switch — `vSwitch0`

`vSwitch0` is the default VMware Standard Virtual Switch.

It provides software-based Layer 2 switching inside the ESXi host.

Current uplink:

```text
vSwitch0
   │
 vmnic0
```

---

## Management Network

The `Management Network` port group is used by the ESXi management VMkernel interface.

Current path:

```text
ESXi Management Traffic
          │
         vmk0
          │
 Management Network
          │
       vSwitch0
          │
        vmnic0
          │
    Physical Network
```

---

## VM Network

The `VM Network` port group will be used for future virtual-machine network adapters.

A future VM will follow a path similar to:

```text
Guest OS
   │
Virtual NIC
   │
VM Network
   │
vSwitch0
   │
vmnic0
   │
Physical Network
```

This distinction between VMkernel traffic and guest VM traffic is an important part of the VMware architecture baseline.

---

# VMkernel Networking

The host management interface is:

```text
vmk0
```

The VMkernel interface provides network connectivity for ESXi itself.

The interface was inspected using:

```bash
esxcli network ip interface list
```

and:

```bash
esxcli network ip interface ipv4 get
```

At this stage `vmk0` is used for management traffic.

Future VMware environments may use additional VMkernel interfaces for services such as:

- vMotion
- NFS
- iSCSI
- vSAN
- Provisioning
- Fault Tolerance

These are not required in the initial single-host lab.

---

# Connectivity Verification

The host network configuration was verified at several layers.

### Local Gateway

```bash
vmkping <gateway>
```

Result:

```text
Successful
0% packet loss
```

### External Network Connectivity

```bash
vmkping 8.8.8.8
```

Result:

```text
Successful
0% packet loss
```

### DNS Resolution

DNS was tested using:

```bash
nslookup pool.ntp.org
```

and:

```bash
nslookup google.com
```

Both returned valid DNS responses.

This confirmed:

```text
Physical Link
     ↓
Local Routing
     ↓
Default Gateway
     ↓
Internet Connectivity
     ↓
DNS Resolution
```

---

# DNS Configuration

The ESXi host is configured to use the DNS services available through the home network.

The configured DNS servers were verified using:

```bash
esxcli network ip dns server list
```

The DNS search domain is:

```text
home.arpa
```

verified using:

```bash
esxcli network ip dns search list
```

The `home.arpa` domain provides a suitable namespace for the internal lab environment.

A dedicated internal DNS service may be introduced later when the Windows infrastructure lab is created.

---

# Time Synchronisation

Correct infrastructure time is important for:

- Authentication
- Certificates
- Logs
- Troubleshooting
- Domain services
- Automation
- Event correlation

NTP was configured using:

```bash
esxcli system ntp set --server=0.uk.pool.ntp.org --server=1.uk.pool.ntp.org
```

The service was enabled with:

```bash
esxcli system ntp set --enabled=true
```

and restarted using:

```bash
/etc/init.d/ntpd restart
```

Configuration was verified with:

```bash
esxcli system ntp get
```

The final status confirmed:

```text
Enabled: true
Time Service Enabled: true
Time Synchronized: true
```

Peer status was checked using:

```bash
ntpq -p
```

A valid upstream NTP source was selected successfully.

---

# Storage

The physical storage device is a Samsung 256 GB NVMe SSD.

The device was inspected using:

```bash
esxcli storage core device list
```

ESXi identified the device as:

```text
Local NVMe Disk
Samsung MZVL4256HBJD
SSD: true
```

---

## VMFS Datastore

The ESXi installer created:

```text
datastore1
```

using:

```text
VMFS-6
```

The filesystem was verified using:

```bash
esxcli storage filesystem list
```

The physical disk currently contains approximately:

```text
256 GB NVMe
│
├── ESXi system storage
├── ESX-OSData
└── datastore1
      ~118 GB VMFS
```

The relatively limited datastore capacity influenced the decision to use:

- Thin provisioning
- Small VM disks
- Temporary virtual machines
- Minimal snapshots
- Resource-conscious VM sizing

---

# Remote Administration

SSH was enabled temporarily for lab administration and CLI validation.

SSH access allows commands such as:

```bash
esxcli system hostname get
esxcli network nic list
esxcli network ip interface ipv4 get
esxcli storage filesystem list
esxcli system ntp get
```

The ESXi Host Client remains the primary GUI management interface at this stage.

SSH will be enabled only when required rather than treated as a permanently exposed administrative service.

---

# VMware Fundamentals Established

Before creating the first VM, the following VMware components were identified and understood:

| Component | Role |
|---|---|
| ESXi | Bare-metal hypervisor |
| VMkernel | Core ESXi operating layer |
| `vmnic0` | Physical NIC |
| `vSwitch0` | VMware Standard Virtual Switch |
| Management Network | Management port group |
| VM Network | Virtual-machine port group |
| `vmk0` | Management VMkernel adapter |
| VMFS-6 | VMware filesystem |
| `datastore1` | VM storage location |
| VMDK | VMware virtual disk format |
| vCPU | Virtual processor |
| Virtual RAM | VM memory allocation |
| VMXNET3 | VMware optimised virtual NIC |
| VMware Tools | Guest integration software |
| Snapshot | Temporary VM state/rollback mechanism |

These concepts form the objects that later PowerCLI and Terraform automation will manage.

---

# Troubleshooting Summary

Two significant boot-related issues were encountered during the initial
platform installation. A third incident involving ESXi management
network instability was investigated and resolved during preparation
for Stage 2.

See [INC-001 — ESXi Network Instability](../incidents/INC-001-esxi-network-instability.md).

## Secure Boot Authentication Failure

```text
Selected boot image did not authenticate
```

Layer:

```text
UEFI / Secure Boot
```

Resolution:

```text
Secure Boot disabled for installation
```

## Hybrid CPU Uniformity PSOD

```text
Fatal CPU mismatch on feature "Cores per package"
```

Layer:

```text
ESXi kernel / CPU compatibility
```

Resolution:

```text
cpuUniformityHardCheckPanic=FALSE
```

Both incidents are documented in more detail in:

[`../troubleshooting.md`](../troubleshooting.md)

---

# Verification

Stage 1 was considered complete after verifying:

- ESXi boots successfully from internal storage
- Host Client is accessible
- SSH administrative access works
- Hostname and FQDN are correct
- CPU compatibility workaround is persistent
- Physical NIC is operational
- Ethernet link is 1 Gbps full duplex
- VMkernel management interface is active
- Default route is present
- Home gateway is reachable
- External IP connectivity works
- DNS resolution works
- NTP is synchronized
- VMFS datastore is mounted
- Standard virtual switch is operational
- Management and VM port groups are present

---

# What I Learned

This stage established the distinction between the major VMware infrastructure layers:

```text
Physical Hardware
       ↓
ESXi / VMkernel
       ↓
Physical NIC / Storage
       ↓
Virtual Switch / VMFS
       ↓
Port Groups / Datastores
       ↓
Virtual Machines
```

Key learning points included:

- The difference between a physical NIC, VMkernel NIC and VM virtual NIC
- How VMware Standard Switches connect virtual infrastructure to physical networking
- How port groups separate different classes of virtual network connectivity
- How VMkernel adapters provide connectivity for ESXi host services
- How VMFS abstracts physical storage into datastores
- How enterprise hypervisors can expose CPU compatibility issues not normally visible with desktop operating systems
- Why infrastructure services such as DNS and NTP should be validated before workloads are deployed
- Why architecture decisions should be documented before automation begins

---

# Automation Candidates

Stage 1 was largely infrastructure discovery and initial host setup, but several operations are candidates for later automation.

Potential PowerCLI/API automation includes:

- Query ESXi hostname
- Query host CPU and memory
- Query physical NICs
- Query virtual switches
- Query port groups
- Query VMkernel interfaces
- Query datastores
- Query datastore capacity
- Query host NTP configuration
- Query DNS configuration
- Validate host connectivity
- Produce an automated host baseline report

These will be revisited during the PowerCLI stage.

The objective will not be to automatically rebuild the host immediately.

Instead, PowerCLI will first be used to **discover and validate the infrastructure that already exists**.

---

# Stage Outcome

The VMware platform foundation is complete.

The environment now provides:

```text
Physical Host
      ↓
VMware ESXi
      ↓
Management Networking
      ↓
VMFS Storage
      ↓
Remote Administration
      ↓
Validated Platform
```

No virtual machines have yet been deployed.

This is intentional.

The next stage establishes the manual VM deployment baseline so that the exact operations involved in virtual-machine provisioning can later be automated.

---

# Next Stage

## Stage 2 — Manual Infrastructure Baseline

The next milestone is to create the first virtual machine manually.

The deployment will record:

- VM name
- Guest OS type
- vCPU
- Memory
- Firmware
- Datastore
- Virtual disk
- Thin provisioning
- Virtual network adapter
- Port group
- ISO attachment
- Guest installation
- VMware Tools

Each manual action will then be added to an **Automation Candidate List**.

That list will become the starting point for the later PowerCLI automation stage.

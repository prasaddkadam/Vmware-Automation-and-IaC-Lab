# VMware Automation & Infrastructure-as-Code Lab

A practical VMware infrastructure automation project progressing from manual ESXi administration to PowerCLI, Terraform, configuration management, and repeatable Infrastructure-as-Code deployment.

The project is intentionally built in stages: infrastructure components are first understood and configured manually, then progressively automated rather than building separate manual and automated labs.

---

## Project Goal

Build a small but realistic VMware environment and evolve it through:

```text
Manual Infrastructure
        ↓
PowerCLI / PowerShell
        ↓
VMware API Automation
        ↓
Terraform / Infrastructure as Code
        ↓
Standardised VM Deployment
        ↓
Configuration Management
        ↓
Containerised Automation Tooling
        ↓
End-to-End Deployment
```

The objective is not simply to install multiple tools. Each automation technology is introduced only after understanding the infrastructure component it will manage.

---

## Lab Architecture

### Current Architecture

```text
              Management Workstation
                        │
          ┌─────────────┼──────────────┐
          │             │              │
      PowerShell     PowerCLI      Terraform
          │             │              │
          └─────────────┼──────────────┘
                        │
                 VMware API / SSH
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
          VM Network       Management
                                  │
                                 vmk0
```

### Target Automation Architecture

```text
Git Repository
      │
      ▼
Automation Environment
      │
      ├── Terraform
      ├── PowerCLI
      ├── Ansible
      └── Supporting Scripts
              │
              ▼
          VMware API
              │
              ▼
        ESXi / vCenter
              │
              ▼
       Standardised VM
              │
              ▼
      Guest Configuration
              │
              ▼
      Service Deployment
              │
              ▼
         Verification
```

---

## Hardware

### VMware Host

| Component | Specification |
|---|---|
| Platform | HP PC |
| CPU | Intel Core i5-13500T |
| CPU Architecture | 14 cores / 20 threads, hybrid P-core/E-core |
| Memory | 32 GB DDR4 |
| Storage | 256 GB Samsung NVMe SSD |
| Network Adapter | Intel I219-LM 1 GbE |
| Hypervisor | VMware ESXi 8 |

### Management Workstation

A separate personal workstation is used for:

- PowerShell
- VMware PowerCLI
- Terraform
- Git
- VS Code
- SSH
- Docker
- Ansible
- Packer

This keeps automation tooling separate from the ESXi host and preserves host resources for virtual machines.

---

## Project Stages

The detailed learning roadmap is condensed into seven implementation stages for this repository.

| Stage | Focus | Status |
|---|---|---|
| **1. Platform Foundation** | Hardware, ESXi, networking, storage and VMware fundamentals | ✅ Complete |
| **2. Manual Infrastructure Baseline** | First VM and manual deployment workflow | 🔜 Next |
| **3. PowerCLI & API Automation** | VMware automation using PowerShell and PowerCLI | Planned |
| **4. Infrastructure as Code** | Terraform and declarative infrastructure provisioning | Planned |
| **5. Standardised Deployment** | Templates, unattended installation and Packer | Planned |
| **6. Configuration Management** | PowerShell, Ansible and guest configuration | Planned |
| **7. End-to-End Automation** | Containerised tooling and repeatable infrastructure deployment | Planned |

---

## Stage 1 — Platform Foundation

The initial VMware platform has been established and validated.

Completed work includes:

- Assessed physical hardware for ESXi suitability
- Enabled Intel VT-x
- Enabled Intel VT-d
- Installed VMware ESXi directly on the physical Mini PC
- Configured ESXi hostname and FQDN
- Configured management networking
- Created a DHCP reservation for predictable ESXi management addressing
- Verified gateway and external network connectivity
- Configured DNS
- Configured and verified NTP synchronisation
- Validated VMFS storage
- Examined VMware Standard Switch networking
- Identified the management VMkernel interface
- Enabled SSH for administrative testing

Detailed implementation notes are maintained under [`docs/`](docs/).

---

## Current VMware Network

```text
Physical Network
       │
     vmnic0
       │
     vSwitch0
       │
 ┌─────┴─────────────┐
 │                   │
Management        VM Network
Network
 │
vmk0
 │
ESXi Management
```

### Current Components

| Component | Purpose |
|---|---|
| `vmnic0` | Physical Intel Ethernet adapter |
| `vSwitch0` | VMware Standard Virtual Switch |
| `Management Network` | Port group carrying ESXi management traffic |
| `VM Network` | Port group for virtual-machine network connectivity |
| `vmk0` | ESXi management VMkernel adapter |
| `datastore1` | VMFS datastore for VM files |

---

## Storage Architecture

The host currently uses a single NVMe SSD.

```text
NVMe SSD
   │
   ├── ESXi System Storage
   │
   └── VMFS-6
          │
          └── datastore1
```

The lab therefore follows resource-conscious storage practices:

- Thin-provisioned virtual disks
- Small guest OS disks
- Minimal unnecessary snapshots
- Temporary VMs where appropriate
- Powered-off VMs when not required
- Reusable templates later in the project

---

## Hardware Compatibility Finding

The Intel Core i5-13500T uses Intel's hybrid Performance-core and Efficiency-core architecture.

During ESXi installation, the host encountered a CPU uniformity PSOD containing:

```text
Fatal CPU mismatch on feature "Cores per package"
```

The issue was investigated and resolved using the ESXi kernel configuration:

```text
cpuUniformityHardCheckPanic=FALSE
```

The setting was subsequently made persistent and verified.

This became the project's first documented infrastructure troubleshooting case.

See:

[`docs/troubleshooting.md`](docs/troubleshooting.md)

---

## Design Principles

### Understand Before Automating

Infrastructure components are first understood manually before being automated.

```text
Understand
   ↓
Configure Manually
   ↓
Identify Repetitive Operations
   ↓
Automate
```

### Avoid Rebuilding the Lab

The project does not create one large manual environment and then destroy it simply to reproduce the same infrastructure through automation.

The same infrastructure is progressively transitioned from:

```text
Manual Administration
        ↓
Scripting
        ↓
API Automation
        ↓
Infrastructure as Code
```

### Separate Provisioning from Configuration

Infrastructure provisioning and guest operating-system configuration are treated as separate concerns.

```text
Infrastructure Provisioning
        │
        ├── PowerCLI
        └── Terraform
```

```text
Guest Configuration
        │
        ├── PowerShell
        ├── cloud-init
        └── Ansible
```

### Resource-Conscious Design

The project deliberately uses modest hardware rather than simulating an unnecessarily large enterprise environment.

Resource allocation, storage consumption and VM lifecycle are therefore treated as architectural considerations rather than afterthoughts.

---

## Repository Structure

The repository grows progressively as technologies are introduced.

Current structure:

```text
.
├── README.md
├── .gitignore
│
└── docs/
    ├── design-decisions.md
    ├── project-log.md
    ├── troubleshooting.md
    │
    └── stages/
        └── 01-platform-foundation.md
```

Future directories will be added as their corresponding technologies are introduced:

```text
powercli/
terraform/
ansible/
packer/
docker/
scripts/
diagrams/
```

This avoids adding placeholder automation that has not actually been implemented.

---

## Documentation

The project maintains several types of engineering documentation.

### Project Log

[`docs/project-log.md`](docs/project-log.md)

Chronological record of significant implementation milestones.

### Design Decisions

[`docs/design-decisions.md`](docs/design-decisions.md)

Records architectural choices and the reasoning behind them.

### Troubleshooting

[`docs/troubleshooting.md`](docs/troubleshooting.md)

Records significant technical failures using:

```text
Symptom
   ↓
Evidence
   ↓
Root Cause
   ↓
Resolution
   ↓
Verification
   ↓
Lesson Learned
```

### Stage Documentation

[`docs/stages/`](docs/stages/)

Detailed technical documentation for each major implementation stage.

---

## Security

Sensitive information is intentionally excluded from the repository.

The repository does not contain:

- Passwords
- ESXi root credentials
- API credentials
- SSH private keys
- Terraform secrets
- `.tfvars` containing credentials
- Private certificates
- Employer infrastructure
- Production configuration
- Company scripts

The repository represents an independent personal infrastructure automation project.

---

## Technologies

Technologies introduced throughout the project will include:

- VMware ESXi
- VMware PowerCLI
- PowerShell
- VMware APIs
- Terraform
- Git
- Windows Server
- Linux
- Ansible
- Packer
- Docker
- Infrastructure as Code
- Configuration Management

---

## Current Status

### ✅ Stage 1 — Platform Foundation

Complete.

The ESXi host is installed, networked, time-synchronised, remotely manageable and validated.

### 🔜 Stage 2 — Manual Infrastructure Baseline

The next milestone is to create the first VM manually and document:

- VM name
- Guest OS
- vCPU
- Memory
- Datastore
- VMDK configuration
- Thin provisioning
- Virtual NIC
- Port group
- Firmware
- ISO attachment
- VMware Tools

Every manual step will then be added to an **Automation Candidate List** for the later PowerCLI stage.

---

## Long-Term Target

The final workflow will aim to demonstrate:

```text
Git
 ↓
Automation Tooling
 ↓
Terraform / PowerCLI
 ↓
VMware API
 ↓
VM Provisioned
 ↓
Guest Configuration
 ↓
Service Deployment
 ↓
Automated Verification
```

The goal is a repeatable, documented infrastructure deployment process rather than a collection of unrelated automation exercises.

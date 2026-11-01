# Design Decisions

## DD-001 — Bare-Metal ESXi

**Decision:** Install ESXi directly on the Mini PC rather than using nested virtualisation.

**Reason:** The Mini PC is dedicated to the project, allowing hardware resources to be used directly by the hypervisor and providing a more realistic VMware environment.

---

## DD-002 — Separate Automation Workstation

**Decision:** Use a separate personal laptop for automation tooling.

**Reason:** PowerShell, PowerCLI, Terraform, Git, Docker, Ansible and development tooling do not need to consume resources on the ESXi host.

---

## DD-003 — No vCenter Initially

**Decision:** Begin with standalone ESXi.

**Reason:** The initial learning objectives and PowerCLI discovery tasks do not justify the additional resource consumption and complexity of vCenter.

vCenter will be reconsidered when its API, template, Terraform or enterprise-management capabilities provide a concrete project benefit.

---

## DD-004 — DHCP Reservation for ESXi Management

**Decision:** Allow ESXi to use DHCP while reserving its address at the router.

**Reason:** Provides a predictable management address while keeping home-network address allocation centrally managed.

---

## DD-005 — Resource-Conscious VM Design

**Decision:** Prefer thin provisioning, small guest disks and temporary VMs.

**Reason:** The current VMFS datastore is capacity constrained and the project should demonstrate efficient infrastructure design rather than unnecessary resource allocation.

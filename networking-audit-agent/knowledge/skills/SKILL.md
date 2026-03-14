# Networking Audit Skill

## Purpose

Perform comprehensive network security and architecture audits on Azure environments. Identifies misconfigurations, security gaps, and deviations from Azure Landing Zone (ALZ) and Well-Architected Framework (WAF) networking best practices.

## When to Activate

Load this skill when the user asks to:
- Audit or review network security (NSGs, firewalls, public exposure)
- Validate hub-spoke or VNet topology against ALZ standards
- Check load balancing configuration (Azure LB, App Gateway, Front Door, Traffic Manager)
- Review DNS, private endpoints, or service exposure
- Audit PaaS networking configuration (Private Link, Service Endpoints, PaaS firewall rules)
- Troubleshoot or design DNS resolution strategy (Private DNS Resolver, hybrid DNS, conditional forwarding)
- Perform a networking architecture assessment (the networking pillar of a landing zone review)
- Investigate connectivity, routing, or traffic flow issues from an architecture perspective
- Run a WAF reliability or security assessment scoped to networking
- Validate Virtual WAN topology, secured hubs, and routing intent
- Review Virtual Network Gateway (ExpressRoute/VPN) configuration and redundancy
- Audit DDoS Protection coverage, Azure Bastion deployment, or NAT Gateway configuration
- Review Azure Firewall policies, Firewall Manager, or centralized firewall management
- Check AVNM (Azure Virtual Network Manager) configurations or security admin rules
- Validate Network Watcher enablement, NSG/VNet flow logs, or traffic analytics
- Review Route Server BGP peering and NVA dynamic routing setup

Do NOT load for:
- Application-layer debugging (HTTP errors, app crashes) — defer to app-specific skills
- Live incident triage on a single resource — defer to diagnostic skills
- Cost optimization not related to networking

## Audit Domains

This skill covers eight audit domains, each with a dedicated reference file:

| Domain | Reference File | What It Covers |
|--------|---------------|----------------|
| NSG & Firewall | [nsg-audit.md](nsg-audit.md) | Overly permissive rules, open mgmt ports, any-any, missing deny-all, flow logs |
| VNet & Topology | [vnet-topology.md](vnet-topology.md) | Hub-spoke validation, Virtual WAN, peering, address space, UDRs, VNet Gateways (ER/VPN), route tables, NVA/firewall routing |
| Load Balancing | [load-balancing.md](load-balancing.md) | LB SKU, health probes, App GW WAF, Front Door, Traffic Manager, redundancy |
| DNS & Private Endpoints | [dns-private-endpoints.md](dns-private-endpoints.md) | Private DNS zones, PE connectivity, public exposure, DNS resolution chain |
| PaaS Networking | [paas-networking.md](paas-networking.md) | Private Link Service, Private Endpoint deep dive, Service Endpoints, PaaS firewall rules, network isolation patterns |
| DNS Strategy | [dns-strategy.md](dns-strategy.md) | DNS architecture patterns, Azure DNS Private Resolver, hybrid DNS, conditional forwarding, multi-region DNS, on-prem resolution |
| Perimeter Security | [perimeter-security.md](perimeter-security.md) | DDoS Protection, Azure Bastion, NAT Gateway — perimeter defense, secure management access, outbound control |
| Network Management | [network-management.md](network-management.md) | Firewall Manager/Policy, AVNM, Network Watcher, Route Server — centralized policy management, network governance, observability, dynamic routing |

## Tools Used

This skill primarily uses these existing tools:
- `RunAzCliReadCommands` — az network, az resource, az graph queries for resource discovery and config inspection
- `SearchResource` — find resources by name or type
- `ExecutePythonCode` — generate summary reports, parse complex outputs, build compliance matrices

### Key Resource Graph Queries

**Discover all networking resources in a subscription:**
```
az graph query -q "Resources | where type startswith 'microsoft.network' | summarize count() by type | order by count_ desc" --first 50 --subscription <subId>
```

**Find all NSGs with rules:**
```
az graph query -q "Resources | where type =~ 'microsoft.network/networksecuritygroups' | project name, resourceGroup, location, properties.securityRules" --first 100 --subscription <subId>
```

**Find all VNets and their peerings:**
```
az graph query -q "Resources | where type =~ 'microsoft.network/virtualnetworks' | project name, resourceGroup, location, properties.addressSpace.addressPrefixes, properties.virtualNetworkPeerings" --first 100 --subscription <subId>
```

**Find all public IPs:**
```
az graph query -q "Resources | where type =~ 'microsoft.network/publicipaddresses' | project name, resourceGroup, properties.ipAddress, properties.publicIPAllocationMethod, properties.ipConfiguration.id" --first 100 --subscription <subId>
```

## Workflow

### Quick Audit (default)
A fast pass across all domains. Use when the user says "audit my network" or "check my networking setup."

1. **Discover** — Run Resource Graph queries to inventory all networking resources
2. **Assess** — For each domain, run the priority checks (marked 🔴 Critical and 🟡 High in reference files)
3. **Report** — Produce a summary table:
   | Check | Status | Severity | Finding | Recommendation |
   |-------|--------|----------|---------|----------------|
4. **Prioritize** — Group findings by severity, call out the top 3 risks clearly

### Deep Audit (per domain)
A thorough review of one domain. Use when the user says "deep dive on NSGs" or "check my hub-spoke topology."

1. **Discover** — Inventory resources in that domain
2. **Assess** — Run ALL checks from the relevant reference file (🔴🟡🟢)
3. **Correlate** — Cross-reference with other domains (e.g., NSG rules + UDRs + peering)
4. **Report** — Detailed findings with specific resource names, rule IDs, and remediation commands
5. **Remediate** — For each finding, provide the exact `az cli` command to fix (as a write command requiring approval)

### Networking Architecture Assessment
Validates networking against Azure Landing Zone (ALZ) networking design principles. Use when the user mentions "landing zone networking", "ALZ networking", or asks for a networking architecture review.

> **Scope note**: This is the networking-focused portion of a landing zone assessment. A full landing zone assessment spans identity, governance, management, security, and platform automation — which are beyond this skill's scope. This workflow covers the networking pillar only.

1. **Topology** — Validate hub-spoke or Virtual WAN topology (including vWAN secured hubs and routing intent)
2. **Segmentation** — Check network segmentation (VNets, subnets, NSGs per subnet)
3. **Egress** — Validate centralized egress through firewall/NVA
4. **Ingress** — Check ingress paths (App Gateway, Front Door, etc.)
5. **Hybrid** — Check ExpressRoute/VPN gateway configuration, SKUs, redundancy, BGP
6. **DNS** — Validate private DNS zone strategy and hybrid DNS resolution
7. **Private Endpoints** — Validate PaaS private connectivity and public access lockdown
8. **Compliance** — Score against ALZ networking checklist
9. **Report** — Produce ALZ networking compliance matrix with pass/fail/not-applicable per control

## Output Format

### Summary Table (always include)
```
## Networking Audit Summary
| # | Domain | Check | Severity | Status | Resource | Finding |
|---|--------|-------|----------|--------|----------|---------|
| 1 | NSG | Open SSH (22) to Internet | 🔴 Critical | FAIL | nsg-web-01 | Inbound Allow from Any on port 22 |
| 2 | Topology | Hub-spoke peering | 🟢 Info | PASS | hub-vnet | All spokes peered correctly |
```

### Severity Levels
- 🔴 **Critical** — Immediate security risk or major architectural violation
- 🟡 **High** — Significant gap, should remediate soon
- 🔵 **Medium** — Best practice deviation, plan to fix
- 🟢 **Low/Info** — Minor or informational

### Remediation Format
For each finding that needs a fix, provide:
```
**Finding**: [description]
**Resource**: [resource name and ID]
**Current State**: [what's wrong]
**Recommended Action**: [what to do]
**Command**:
az network nsg rule update --resource-group <rg> --nsg-name <nsg> --name <rule> --access Deny --subscription <subId>
```

## Behavioral Rules

### Citation Requirement
- **Every recommendation MUST include a citation** to the official Microsoft documentation URL that supports it.
- Use MS Learn (`learn.microsoft.com`) as the authoritative source. ALZ, WAF, and networking best practices are well-documented there.
- Format: Include the doc link in the "Ref" field of each finding, or inline as `[Link text](URL)`.
- If you cannot find a supporting MS doc for a recommendation, explicitly note it as "No official reference found" and ask the user if they have a preferred source.

### PaaS-Specific Documentation First
- **Each PaaS service has its own networking model, firewall behavior, and limitations.** Before auditing or recommending ANY PaaS networking config, you MUST consult the service-specific MS doc listed in [paas-networking.md](paas-networking.md) — not generic Private Link guidance.
- What works for Storage does NOT work for Key Vault, SQL, Cosmos DB, etc.
- Always cite the **service-specific doc** in findings, not the generic PE doc.

### Ask, Don't Guess
- **When information is missing or you cannot evaluate a check, ASK the user** — never assume, guess, or make a judgment call.
- Examples of when to ask:
  - Can't determine if a VNet is a hub or spoke (ask the user their topology)
  - Unknown if a public IP is intentional (ask before flagging)
  - Unclear if custom DNS is by design (ask about hybrid DNS strategy)
  - Missing on-premises IP ranges for overlap check (ask user to provide)
- Say: *"I need more info to evaluate this — [specific question]"* rather than making assumptions.

### Reference Documents

#### Azure Landing Zone (ALZ) — Networking Pillar
These are the authoritative ALZ docs for the networking design area. **Always cite the specific sub-page, not just the top-level ALZ URL.**

| Doc | URL | Maps to Audit Domain |
|-----|-----|---------------------|
| **Landing Zone Overview** | https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/ | All — 8 design areas, platform vs application LZ, Connectivity/Corp/Online mgmt groups |
| **Network Topology & Connectivity Design Area** | https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/design-area/network-topology-and-connectivity | All — Corp vs Online separation, Connectivity subscription role |
| **Define an Azure Network Topology** | https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/define-an-azure-network-topology | VNet & Topology — hub-spoke vs vWAN decision criteria |
| **Hub-Spoke Network Topology** | https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/hub-spoke-network-topology | VNet & Topology — hub VNet, peering, gateway transit, NVA, Bastion, Firewall, DNS, routing |
| **Virtual WAN Network Topology** | https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/virtual-wan-network-topology | VNet & Topology — vWAN hubs, secured hubs, routing intent, ER/VPN, DDoS, NVA in hub |
| **Inbound & Outbound Internet Connectivity** | https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/plan-for-inbound-and-outbound-internet-connectivity | Perimeter Security — NAT Gateway (recommended default), Azure Firewall, WAF, Bastion, DDoS, no default outbound |
| **Plan for Traffic Inspection** | https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/plan-for-traffic-inspection | Network Management — VNet flow logs (migrate from NSG flow logs), Traffic Analytics, packet capture |
| **Connectivity to Azure PaaS Services** | https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/connectivity-to-azure-paas-services | PaaS Networking — PE vs SE vs VNet injection decision, hybrid access patterns |
| **Private Link & DNS Integration at Scale** | https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/private-link-and-dns-integration-at-scale | DNS Strategy, DNS & PE — central DNS zones in Connectivity sub, Azure Policy for PE DNS automation, Private Resolver architecture |

#### Key ALZ Networking Design Recommendations (cross-referenced to audit checks)
These are direct ALZ recommendations from the docs above. Each maps to specific audit checks:

- **Use NAT Gateway for outbound** (not default SNAT) → `NAT-C1`, `NAT-H1` — [Inbound & Outbound doc]
- **Use Azure Bastion, don't expose VM management ports** → `BAST-C1`, `BAST-H1` — [Inbound & Outbound doc]
- **Use DDoS Protection on VNets with public IPs** → `DDOS-C1` — [vWAN topology doc]
- **Use Azure Firewall Premium for IDPS/TLS** → `FW-H3` — [Inbound & Outbound doc]
- **Use Firewall Manager + IP Groups** → `FW-H2`, `FW-M1` — [Inbound & Outbound doc]
- **Use Private Link for PaaS, not public endpoints** → `PE-C1`, `PE-C2` — [PaaS Connectivity doc]
- **Migrate NSG flow logs to VNet flow logs** (NSG flow logs retired Sept 2027) → `NW-H3` — [Traffic Inspection doc]
- **Enable Traffic Analytics on flow logs** → `NW-M1` — [Traffic Inspection doc]
- **Central Private DNS zones in Connectivity subscription** → `DNS-H3`, `DNS-C1` — [Private Link & DNS doc]
- **Use Azure DNS Private Resolver (not VM forwarders)** → `DNS-H1`, `DNS-H2` — [Private Link & DNS doc]
- **Corp mgmt group = private/intranet, Online = public/internet** → Architecture Assessment workflow
- **Connectivity subscription hosts all shared networking** → Architecture Assessment workflow

#### Well-Architected Framework (WAF)
- **WAF — Reliability Pillar**: https://learn.microsoft.com/azure/well-architected/reliability/
- **WAF — Security Pillar**: https://learn.microsoft.com/azure/well-architected/security/

#### ALZ Deployment Baseline (VBD)
- **VBD ALZ Deployment Checklist**: [alz-deployment-baseline.md](alz-deployment-baseline.md) — Networking-relevant design decisions extracted from the official VBD ALZ Deployment Checklist (60+ items, 10 sections). Use during Networking Architecture Assessments to validate environment state against ALZ deployment decisions.

## Conversation Style

- Lead with the most critical findings
- Be specific — name resources, rule names, port numbers
- Don't just flag problems — explain WHY it's a risk, provide the fix, AND cite the MS doc
- For Networking Architecture Assessments, reference the specific ALZ design principle being violated
- Use tables for scanability
- Ask clarifying questions when scope is ambiguous OR when data needed for evaluation is missing

## Completion

An audit is complete when:
- All in-scope domains have been checked
- Findings are presented in a summary table
- Top 3 risks are called out explicitly
- Remediation commands are provided for critical/high findings
- User has been asked if they want to deep dive on any specific domain

# ALZ Deployment Baseline — Networking Checklist

Reference file extracted from the official **VBD ALZ Deployment Checklist** (Microsoft internal consulting tool). This captures the networking-relevant design decisions made during an ALZ deployment. During a **Networking Architecture Assessment**, validate actual environment state against these baseline decisions.

> **Source**: `ALZ Deployment - Checklist.xlsx` (Portal sheet, 204 rows) — provided by user.
> **Scope**: Only networking-relevant items extracted. Full checklist also covers identity, governance, management, security, compliance.

---

## How to Use This File

During a **Networking Architecture Assessment** (or Quick/Deep Audit), use this baseline to:
1. **Ask the customer**: "Do you have your ALZ deployment checklist with the design decisions?" — if yes, compare actual state against their recorded decisions
2. **If no checklist**: Use this as the reference for what ALZ deploys by default and validate the environment matches
3. **Map findings**: Each VBD item below maps to specific audit checks in our reference files

---

## VBD Section 1: Network Topology Choice

| VBD Item | Design Decision Options | Default/Recommended | Maps to Audit Check |
|----------|------------------------|--------------------|--------------------| 
| Deploy networking topology | Hub-spoke (Azure FW) / Hub-spoke (NVA) / Virtual WAN / No | Depends on requirements | `vnet-topology.md` — All topology checks |
| Deploy AVNM | Yes/No | Optional (preview in VBD) | `network-management.md` — AVNM-H1 |
| Address space for hub VNet | CIDR notation (e.g. 10.100.0.0/16) | Customer-defined | `vnet-topology.md` — C1 (overlap) |
| Region for first networking hub | Azure region | Customer-defined | `vnet-topology.md` — V4 (hub regional coverage) |
| Deploy in secondary region | Yes (recommended) / No | Yes | `vnet-topology.md` — multi-region topology |

### What to Validate
- Confirm the **chosen topology** (hub-spoke or vWAN) matches what's actually deployed
- Check that hub VNet/vWAN hub address space matches the recorded design decision (no drift)
- If secondary region was selected, verify secondary hub/vhub exists with mirrored services

---

## VBD Section 2: DDoS Protection

| VBD Item | Design Decision Options | Default/Recommended | Maps to Audit Check |
|----------|------------------------|--------------------|--------------------| 
| Enable DDoS Network Protection (platform) | Yes (recommended) / No | Yes | `perimeter-security.md` — DDOS-C1 |
| Enable DDoS Network Protection (landing zones) | Yes (recommended) / Audit only / No | Yes | `perimeter-security.md` — DDOS-H1 |

### What to Validate
- DDoS Protection plan exists and is associated with ALL VNets containing public IPs
- Landing zone policy enforces DDoS (not just platform-level)
- **ALZ Policy**: `Enable DDoS Network Protection` assigned at Landing Zones management group

---

## VBD Section 3: Private DNS Zones & Private Endpoints

| VBD Item | Design Decision Options | Default/Recommended | Maps to Audit Check |
|----------|------------------------|--------------------|--------------------| 
| Create Private DNS Zones for Azure PaaS services | Yes (recommended) / No | Yes | `dns-strategy.md` — DNS-L4, `dns-private-endpoints.md` — H1 |
| Select Private DNS Zones to create | 68 zones available | 68 selected (all) | `dns-strategy.md` — DNS-L2 |
| Ensure PE integrated with Private DNS Zones (corp LZ) | Yes (recommended) / Audit only / No | Yes | `dns-private-endpoints.md` — H2, `paas-networking.md` — PE-C1 |
| Audit Private DNS Zone creation in Corp MG | Yes (recommended) / Audit only / No | Yes | `dns-strategy.md` — DNS-H3, DNS-C2 |

### What to Validate
- Private DNS Zones exist in the **Connectivity subscription** (centralized, not scattered per spoke)
- All 68 privatelink.* zones are created (or the subset selected during deployment)
- Each Private DNS Zone is linked to the hub VNet (and spoke VNets needing resolution)
- Azure Policy enforces PE DNS integration for corp landing zones
- No duplicate privatelink.* zones in spoke subscriptions (split-brain risk)
- **ALZ Policy**: `Deploy-Private-DNS-Zones` initiative assigned at Corp management group

---

## VBD Section 4: VPN Gateway

| VBD Item | Design Decision Options | Default/Recommended | Maps to Audit Check |
|----------|------------------------|--------------------|--------------------| 
| Deploy VPN Gateway | Yes / No | Based on hybrid needs | `vnet-topology.md` — GW1 |
| Zone redundant or regional | Zone redundant (recommended) / Regional | Zone redundant | `vnet-topology.md` — GW1 (AZ-redundant SKUs) |
| Active/Active mode | Yes / No | Depends on HA needs | `vnet-topology.md` — H4 |
| VPN Gateway SKU | VpnGw2/3/4/5 or VpnGw2AZ/3AZ/4AZ/5AZ | VpnGw2AZ+ | `vnet-topology.md` — GW1 |
| Gateway subnet | CIDR (e.g. 10.100.1.0/24) | /27 minimum, /24 recommended | `vnet-topology.md` — GW6 |
| Deploy VPN in secondary region | Yes / No | Match primary decision | `vnet-topology.md` — multi-region |

### What to Validate
- VPN Gateway SKU matches the AZ-redundant variant if zone redundancy was selected
- Active-active is enabled if specified in design decision
- GatewaySubnet is >= /27 (VBD example shows /24 which is good)
- Secondary region has matching VPN Gateway if multi-region was selected
- **Cross-check**: VPN connections use BGP (`vnet-topology.md` — GW3)

---

## VBD Section 5: ExpressRoute Gateway

| VBD Item | Design Decision Options | Default/Recommended | Maps to Audit Check |
|----------|------------------------|--------------------|--------------------| 
| Deploy ExpressRoute Gateway | Yes / No | Based on hybrid needs | `vnet-topology.md` — GW1 |
| Zone redundant or regional | Zone redundant (recommended) / Regional | Zone redundant | `vnet-topology.md` — GW1 (ErGwXAZ SKUs) |
| ExpressRoute Gateway SKU | Standard/HighPerformance/UltraPerformance or ErGw1AZ/2AZ/3AZ | ErGw1AZ+ | `vnet-topology.md` — GW1 |
| Deploy ER in secondary region | Yes / No | Match primary decision | `vnet-topology.md` — GW2 (dual circuits) |

### What to Validate
- ER Gateway uses AZ-redundant SKU (ErGwXAZ) if zone redundancy was selected
- ER circuit redundancy: at least 2 circuits in different peering locations (`vnet-topology.md` — GW2)
- FastPath enabled for high-throughput workloads (`vnet-topology.md` — GW5)
- Gateway diagnostics enabled (`vnet-topology.md` — GW4)

---

## VBD Section 6: Azure Firewall

| VBD Item | Design Decision Options | Default/Recommended | Maps to Audit Check |
|----------|------------------------|--------------------|--------------------| 
| Deploy Azure Firewall | Yes (recommended) / No | Yes | `nsg-audit.md` — M4, `vnet-topology.md` — C2 |
| Azure Firewall tier | Premium (recommended) / Standard / Basic | Premium | `network-management.md` — FW-H3 |
| Availability Zones | Zone 1, 2, 3 | All 3 zones | `network-management.md` — (implicit in FW checks) |
| Firewall subnet | CIDR /26 minimum | e.g. 10.100.0.0/24 | `nsg-audit.md` — firewall subnet sizing |
| Azure Firewall as DNS proxy | Yes / No | Depends on DNS strategy | `dns-strategy.md` — DNS-C3 |
| Deploy Firewall in secondary region | Yes / No | Match primary | `network-management.md` — FW-H2 (multi-FW) |
| Firewall tier in secondary region | Premium/Standard/Basic | Match primary | `network-management.md` — FW-H2 |

### What to Validate
- Firewall uses **Firewall Policy** (not classic rules) → `network-management.md` — FW-C1
- Firewall tier matches VBD decision (Premium recommended for IDPS/TLS)
- Deployed across all 3 availability zones for 99.99% SLA
- DNS proxy enabled if selected (critical for FQDN-based network rules)
- Threat intelligence mode set to **Deny** → `network-management.md` — FW-H4
- Diagnostic logs enabled → `network-management.md` — FW-H5
- If multi-region: Firewall Manager + policy inheritance → `network-management.md` — FW-H2, FW-M2
- **ALZ Policy**: Azure Firewall is the default egress path for Corp landing zones

---

## VBD Section 7: Virtual WAN (if selected)

| VBD Item | Design Decision Options | Default/Recommended | Maps to Audit Check |
|----------|------------------------|--------------------|--------------------| 
| vWAN hub address space | CIDR (e.g. 10.100.0.0/23) | Customer-defined | `vnet-topology.md` — V7 |
| VPN Gateway scale unit | 1+ | 1 | `vnet-topology.md` — V1 (SKU check) |
| ExpressRoute scale unit | 1+ | 1 | `vnet-topology.md` — V1 |
| Enable Routing Intent | Yes / No | Yes (recommended) | `vnet-topology.md` — V3 |
| Hub Routing Preference | ExpressRoute (default) / VPN / AS Path | ExpressRoute | `vnet-topology.md` — routing checks |
| Virtual Hub Capacity (routing infrastructure units) | 2+ | 2 | `vnet-topology.md` — V1 |
| Deploy firewall in vWAN hub | Yes (recommended) / No | Yes | `vnet-topology.md` — V2 (secured hub) |
| Firewall tier in vWAN | Premium/Standard/Basic | Premium | `network-management.md` — FW-H3 |
| Firewall as DNS proxy in vWAN | Yes / No | Depends | `dns-strategy.md` — DNS-C3 |
| Secondary vWAN hub | Yes / No | Match primary | `vnet-topology.md` — V4 |

### What to Validate
- vWAN is **Standard SKU** (not Basic) → `vnet-topology.md` — V1
- Each hub is a **secured hub** (Azure Firewall deployed) → `vnet-topology.md` — V2
- **Routing Intent** is enabled → `vnet-topology.md` — V3
- Hub exists in each required region → `vnet-topology.md` — V4
- All spoke VNets are connected to the appropriate hub → `vnet-topology.md` — V5
- BGP used for branch connectivity (not static routes) → `vnet-topology.md` — V6
- Hub address spaces don't overlap → `vnet-topology.md` — V7

---

## VBD Section 8: Landing Zone Network Policies

These are Azure Policy assignments made during ALZ deployment at the Landing Zones or Corp management groups. During audit, verify these policies are active and compliant.

| VBD Policy Item | Scope | Default | Maps to Audit Check |
|----------------|-------|---------|---------------------|
| Prevent inbound mgmt ports from internet | Identity MG + Landing Zones MG | Yes (recommended) | `nsg-audit.md` — C1 (SSH/RDP), `perimeter-security.md` — BAST-C1 |
| Ensure subnets are associated with NSG | Identity MG + Landing Zones MG | Yes (recommended) | `nsg-audit.md` — H2, `vnet-topology.md` — H5 |
| Prevent IP forwarding | Landing Zones MG | Yes (recommended) | Non-NVA VMs should not have IP forwarding |
| Ensure HTTPS ingress in K8s clusters | Landing Zones MG | Yes (recommended) | AKS network policy check |
| Prevent public endpoints for PaaS (corp) | Corp MG | Yes (recommended) | `paas-networking.md` — PE-C1, PE-C2 |
| Prevent NICs with public IPs (corp) | Corp MG | Yes (recommended) | `perimeter-security.md` — BAST-C1, `nsg-audit.md` — C1 |
| Deny vWAN/VPN/ER in Corp MG | Corp MG | Yes (recommended) | Gateways only in Connectivity sub |
| Audit Private DNS Zone creation in Corp MG | Corp MG | Yes (recommended) | `dns-strategy.md` — DNS-H3 (centralized DNS) |
| Ensure secure connections (HTTPS) to storage | Landing Zones MG | Yes (recommended) | `paas-networking.md` — encryption in transit |
| WAF enabled on Application Gateways | Landing Zones MG | Yes (recommended) | `load-balancing.md` — C3, H5 |
| Enable DDoS Network Protection | Landing Zones MG | Yes (recommended) | `perimeter-security.md` — DDOS-C1 |
| Ensure PE + Private DNS integration (corp) | Corp MG | Yes (recommended) | `dns-private-endpoints.md` — H1, H2 |
| AMBA for Load Balancing Services | Landing Zones MG | Yes (recommended) | `load-balancing.md` — monitoring |
| AMBA for Network Routing/Security alterations | Landing Zones MG | Yes (recommended) | `network-management.md` — change detection |
| Network & Networking services guardrails | Landing Zones MG | Yes (recommended) | `network-management.md` — comprehensive |

### What to Validate
- Each policy is **assigned** (not just defined) at the correct management group scope
- Policy effect is **Deny** (not just Audit) for critical items like public endpoint prevention
- Compliance percentage — flag any non-compliant resources
- **Key pattern**: Corp MG = private-only (no public endpoints, no public IPs, no gateways). Online MG = can have public endpoints with controls.

---

## VBD Section 9: Identity VNet (Networking Relevance)

| VBD Item | Design Decision Options | Default/Recommended | Maps to Audit Check |
|----------|------------------------|--------------------|--------------------| 
| VNet address space for Identity subscription | CIDR (e.g. 10.110.0.0/24) | Customer-defined | `vnet-topology.md` — C1 (no overlap) |
| Connect to connectivity hub in secondary region | Yes (recommended) / No | Yes | `vnet-topology.md` — peering checks |
| Prevent inbound mgmt ports (Identity MG) | Yes (recommended) / No | Yes | `nsg-audit.md` — C1 |
| Ensure subnets with NSG (Identity MG) | Yes (recommended) / No | Yes | `nsg-audit.md` — H2 |
| Prevent public IP usage (Identity MG) | Yes (recommended) / No | Yes | `perimeter-security.md` — BAST-C1 |

### What to Validate
- Identity VNet is peered to the hub VNet in each region
- Domain controller VMs have NO public IPs
- All Identity subnets have NSGs with deny-internet-inbound rules
- Address space doesn't overlap with hub, connectivity, or spoke VNets

---

## VBD Section 10: Sovereign Landing Zone Additions (If Applicable)

The Sovereign Landing Zone (SLZ) Bicep variant adds these networking parameters:

| Parameter | Purpose | Maps to Audit Check |
|-----------|---------|---------------------|
| `parDeployDdosProtection` | DDoS plan toggle | `perimeter-security.md` — DDOS-C1 |
| `parDeployHubNetwork` | Hub VNet toggle | `vnet-topology.md` — all |
| `parEnableFirewall` | Azure Firewall toggle | `network-management.md` — FW checks |
| `parUsePremiumFirewall` | Premium SKU toggle | `network-management.md` — FW-H3 |
| `parHubNetworkAddressPrefix` | Hub CIDR | `vnet-topology.md` — C1 |
| `parAzureBastionSubnet` | Bastion subnet CIDR | `perimeter-security.md` — BAST-H3 |
| `parGatewaySubnet` | Gateway subnet CIDR | `vnet-topology.md` — GW6 |
| `parAzureFirewallSubnet` | Firewall subnet CIDR | Subnet sizing check |
| `parDeployBastion` | Bastion toggle | `perimeter-security.md` — BAST-H1 |
| `parExpressRouteGatewayConfig` | ER GW settings (SKU, BGP, active-active) | `vnet-topology.md` — GW1, GW2 |
| `parVpnGatewayConfig` | VPN GW settings (SKU, BGP, active-active) | `vnet-topology.md` — GW1, GW3 |
| `parPrivateDnsResourceGroupId` | Central DNS zone RG | `dns-strategy.md` — DNS-H3 |

---

## Audit Workflow: Using This Baseline

When running a **Networking Architecture Assessment**, follow this sequence:

1. **Ask**: "Do you have the ALZ deployment checklist with design decisions filled in?"
2. **If yes**: Compare each section above against recorded decisions → flag drift
3. **If no**: Use the "Recommended" column as the expected baseline → validate environment
4. **For each section**:
   - Run the mapped audit checks from the reference files
   - Compare actual resource state against VBD design decisions
   - Flag: ✅ Matches decision | ⚠️ Drift from decision | ❌ Missing/not deployed
5. **Policy compliance**: Verify all Landing Zone network policies are assigned and enforced (Section 8)
6. **Report**: Include a "Design Decision Compliance" section in the audit summary

### Sample Output Format
```
## ALZ Design Decision Compliance
| VBD Decision | Expected | Actual | Status |
|-------------|----------|--------|--------|
| Topology: Hub-spoke with Azure Firewall | Hub-spoke | Hub-spoke | ✅ Match |
| DDoS Protection enabled | Yes | No DDoS plan found | ❌ Gap |
| VPN Gateway SKU: VpnGw2AZ | VpnGw2AZ | VpnGw1 (non-AZ) | ⚠️ Drift |
| Private DNS Zones: 68 | 68 zones | 42 zones | ⚠️ Partial |
| Azure Firewall tier: Premium | Premium | Standard | ⚠️ Drift |
```

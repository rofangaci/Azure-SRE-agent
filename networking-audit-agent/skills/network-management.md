# Network Management & Observability

Audit checks for Azure Firewall Manager/Policy, Azure Virtual Network Manager (AVNM), Network Watcher, and Route Server — services that provide centralized policy management, network governance at scale, observability, and dynamic routing.

## Discovery Queries

**Azure Firewall Policies:**
```
az graph query -q "Resources | where type =~ 'microsoft.network/firewallpolicies' | project name, id, resourceGroup, location, sku.tier, properties.basePolicy, properties.childPolicies, properties.firewalls, properties.threatIntelMode" --first 50 --subscription <subId>
```

**Azure Firewalls and their associated policies:**
```
az graph query -q "Resources | where type =~ 'microsoft.network/azurefirewalls' | project name, id, resourceGroup, location, properties.sku.tier, properties.firewallPolicy.id, properties.hubIPAddresses" --first 50 --subscription <subId>
```

**Azure Virtual Network Manager instances:**
```
az graph query -q "Resources | where type =~ 'microsoft.network/networkmanagers' | project name, id, resourceGroup, location, properties.networkManagerScopes" --first 50 --subscription <subId>
```

**AVNM configurations (connectivity + security):**
```
az graph query -q "Resources | where type startswith 'microsoft.network/networkmanagers/' | project name, type, id, resourceGroup" --first 100 --subscription <subId>
```

**Network Watcher instances:**
```
az graph query -q "Resources | where type =~ 'microsoft.network/networkwatchers' | project name, id, resourceGroup, location" --first 50 --subscription <subId>
```

**NSG Flow Logs:**
```
az graph query -q "Resources | where type =~ 'microsoft.network/networkwatchers/flowlogs' | project name, id, properties.targetResourceId, properties.enabled, properties.retentionPolicy, properties.flowAnalyticsConfiguration" --first 100 --subscription <subId>
```

**VNet Flow Logs:**
```
az graph query -q "Resources | where type =~ 'microsoft.network/networkwatchers/flowlogs' | where properties.targetResourceId contains 'virtualNetworks' | project name, id, properties.targetResourceId, properties.enabled" --first 100 --subscription <subId>
```

**Route Servers:**
```
az graph query -q "Resources | where type =~ 'microsoft.network/virtualhubs' and kind =~ 'routeserver' | project name, id, resourceGroup, location, properties.allowBranchToBranchTraffic, properties.virtualRouterAsn, properties.virtualRouterIps" --first 50 --subscription <subId>
```

---

## Azure Firewall Manager & Firewall Policy

### Why It Matters

Azure Firewall Manager provides centralized security policy management across multiple Azure Firewall instances (hub VNets and secured virtual hubs). Firewall Policy replaces classic inline rules with a structured, inheritable policy model — enabling rule collection groups, IDPS, TLS inspection, URL filtering, and multi-hub consistency. For any environment with more than one firewall, centralized management is critical to prevent security drift.

**Ref**: [Azure Firewall Manager overview](https://learn.microsoft.com/azure/firewall-manager/overview)
**Ref**: [Azure Firewall Policy overview](https://learn.microsoft.com/azure/firewall/policy-overview)

### Checks

#### 🔴 Critical

**FW-C1: Azure Firewall using classic rules instead of Firewall Policy**
- **What**: Azure Firewall configured with classic inline rule collections rather than a Firewall Policy resource.
- **Why**: Classic rules are legacy and cannot be managed centrally via Firewall Manager. They don't support: rule collection groups, policy inheritance, IDPS, TLS inspection, web categories, or explicit proxy. Migration to Firewall Policy is a prerequisite for all modern features.
- **Check**: Query Azure Firewalls → check if `firewallPolicy.id` is null (classic) vs populated (policy-based).
- **Ref**: [Azure Firewall rule processing — Policy vs Classic](https://learn.microsoft.com/azure/firewall/rule-processing)
- **Ref**: [Migrate classic rules to Firewall Policy](https://learn.microsoft.com/azure/firewall/rule-processing#migrate-to-firewall-policy)

#### 🟡 High

**FW-H1: Firewall Policy not organized with rule collection groups**
- **What**: Firewall Policy has all rules in a flat structure without rule collection groups.
- **Why**: Rule collection groups provide priority-based processing and logical segmentation (e.g., platform-infra rules at priority 100, app-team rules at 500, deny-all at 65000). Without them, rule management becomes unscalable and conflicts increase.
- **Check**: Query Firewall Policy → inspect `ruleCollectionGroups[]` → flag if only one group or no logical separation.
- **Ref**: [Firewall Policy rule processing](https://learn.microsoft.com/azure/firewall/rule-processing)

**FW-H2: Multi-firewall environment without centralized Firewall Manager**
- **What**: Multiple Azure Firewalls deployed across hubs or regions with independently managed policies.
- **Why**: Independent policy management leads to inconsistencies, security drift, and higher operational overhead. Firewall Manager + policy inheritance ensures a base security posture across all firewalls.
- **Check**: Count Azure Firewalls → if >1, check if policies share a common parent policy (inheritance hierarchy).
- **Ref**: [Firewall Manager — centralized management](https://learn.microsoft.com/azure/firewall-manager/policy-overview)

**FW-H3: Firewall Premium features not evaluated for sensitive workloads**
- **What**: Azure Firewall deployed with Standard SKU in environments handling regulated or sensitive workloads.
- **Why**: Premium SKU provides: IDPS (signature-based detection with 67,000+ signatures), TLS inspection (decrypt and inspect encrypted traffic), URL filtering with web categories, and enhanced performance. For PCI-DSS, HIPAA, or financial workloads, IDPS and TLS inspection are typically required.
- **Check**: Query Firewall Policy → check `sku.tier`. If Standard, flag for review based on workload sensitivity.
- **Ref**: [Azure Firewall Premium features](https://learn.microsoft.com/azure/firewall/premium-features)

**FW-H4: Threat intelligence set to Alert-only or Off**
- **What**: Firewall Policy `threatIntelMode` is `Off` or `Alert` instead of `Deny`.
- **Why**: Threat intelligence blocks known malicious IPs and FQDNs from Microsoft's threat intelligence feed. `Alert` only logs — threats are observed but not blocked. `Deny` actively blocks connections.
- **Check**: Query Firewall Policy → check `properties.threatIntelMode`.
- **Ref**: [Azure Firewall threat intelligence-based filtering](https://learn.microsoft.com/azure/firewall/threat-intel)

**FW-H5: Azure Firewall diagnostic logs not enabled**
- **What**: Azure Firewall structured logs (AZFWApplicationRule, AZFWNetworkRule, AZFWNatRule, AZFWThreatIntel, AZFWIdpsSignature) not sent to Log Analytics.
- **Why**: Without logs, you have no visibility into allowed/denied traffic, threat intel hits, or IDPS alerts. Logs are essential for security monitoring and incident response.
- **Check**: `az monitor diagnostic-settings list --resource <firewallId>` — look for structured log categories.
- **Ref**: [Azure Firewall structured logs](https://learn.microsoft.com/azure/firewall/firewall-structured-logs)

#### 🔵 Medium

**FW-M1: Firewall Policy not using IP Groups**
- **What**: Firewall rules reference inline IP addresses/ranges instead of IP Groups.
- **Why**: IP Groups provide reusable address sets referenced across multiple rules and policies — reducing duplication, simplifying updates, and enabling consistency across environments.
- **Check**: Query Firewall Policy rules → check for inline IPs vs IP Group references.
- **Ref**: [IP Groups in Azure Firewall](https://learn.microsoft.com/azure/firewall/ip-groups)

**FW-M2: No parent-child policy inheritance**
- **What**: Multiple Firewall Policies exist without a parent-child hierarchy.
- **Why**: Inheritance enables a base (parent) policy with org-wide rules, with child policies adding environment-specific rules. Without it, common rules (e.g., block known-bad, allow Azure management) are duplicated and diverge over time.
- **Check**: Query Firewall Policies → check `basePolicy` and `childPolicies` properties.
- **Ref**: [Firewall Policy hierarchy](https://learn.microsoft.com/azure/firewall-manager/policy-overview#hierarchical-policies)

**FW-M3: Firewall forced tunneling not evaluated**
- **What**: Azure Firewall in environments requiring all traffic (including management plane) to pass through an on-premises device, but forced tunneling is not configured.
- **Why**: Some compliance requirements mandate that even Azure Firewall's management traffic routes through on-prem. Forced tunneling uses a dedicated AzureFirewallManagementSubnet for Azure management while tunneling data-plane traffic.
- **Check**: Check if AzureFirewallManagementSubnet exists and if the firewall has management IP config.
- **Ref**: [Azure Firewall forced tunneling](https://learn.microsoft.com/azure/firewall/forced-tunneling)

#### 🟢 Info

**FW-L1: Firewall Manager and Policy inventory**
- List all Firewall Policies: SKU tier, associated firewalls, rule collection group count, parent/child relationships, threat intel mode, IDPS mode.
- Cross-reference with Firewall Manager for centralized management status.
- Note rule collection group limits: 50 per policy (Standard), 100 per policy (Premium).

---

## Azure Virtual Network Manager (AVNM)

### Why It Matters

AVNM provides centralized network governance at scale — topology enforcement (hub-spoke and mesh), security admin rules (org-level deny rules that override NSGs), and dynamic VNet group membership. For environments with many VNets across subscriptions, AVNM replaces manual peering management and fragile NSG configurations with policy-driven automation.

**Ref**: [Azure Virtual Network Manager overview](https://learn.microsoft.com/azure/virtual-network-manager/overview)

### Checks

#### 🟡 High

**AVNM-H1: Large VNet estate without AVNM**
- **What**: Subscription or management group has >10 VNets managed individually (manual peering, individual NSGs) without AVNM.
- **Why**: Manual VNet management doesn't scale. AVNM automates peering topology, enforces connectivity patterns, and deploys security admin rules centrally. Misconfigurations and inconsistencies increase with manual management.
- **Check**: Count VNets → if >10 and no AVNM resource exists, flag for evaluation.
- **Ref**: [AVNM use cases](https://learn.microsoft.com/azure/virtual-network-manager/overview#use-cases)

**AVNM-H2: AVNM deployed without security admin rules**
- **What**: AVNM exists with connectivity configurations but no security admin rules deployed.
- **Why**: Security admin rules are the key differentiator from NSGs — they enforce org-level network policies (e.g., always deny inbound SSH from internet) that **CANNOT be overridden by NSG rules lower in the stack**. This provides a guaranteed security baseline.
- **Check**: Query AVNM → check for security admin configurations and deployed rule collections.
- **Ref**: [Security admin rules overview](https://learn.microsoft.com/azure/virtual-network-manager/concept-security-admins)

**AVNM-H3: AVNM configurations created but not deployed**
- **What**: AVNM connectivity or security configurations exist in `Created` state — not deployed to target regions.
- **Why**: Configurations only take effect after explicit deployment to regions. Created-but-undeployed configs provide zero network effect.
- **Check**: Check AVNM deployment status for each configuration per region.
- **Ref**: [AVNM configuration deployment](https://learn.microsoft.com/azure/virtual-network-manager/concept-deployments)

#### 🔵 Medium

**AVNM-M1: Network groups using only static membership**
- **What**: AVNM network groups use static (manual) VNet membership instead of dynamic (Azure Policy-based) membership.
- **Why**: Dynamic membership automatically includes VNets matching defined criteria (tags, properties, subscriptions). New VNets are managed immediately without manual intervention — critical for landing zone scale-out.
- **Check**: Query AVNM network groups → check membership type (static vs conditional/policy-based).
- **Ref**: [AVNM network groups](https://learn.microsoft.com/azure/virtual-network-manager/concept-network-groups)

**AVNM-M2: AVNM scope too narrow**
- **What**: AVNM instance scope doesn't include all subscriptions or management groups where VNets reside.
- **Why**: VNets outside AVNM scope cannot be managed. The scope must cover the full network estate to prevent unmanaged shadow VNets.
- **Check**: Query AVNM → check `networkManagerScopes` against subscription/management group structure.
- **Ref**: [AVNM scope and access](https://learn.microsoft.com/azure/virtual-network-manager/concept-network-manager-scope)

**AVNM-M3: AVNM connectivity config not using direct connectivity for spoke-to-spoke**
- **What**: AVNM hub-spoke connectivity configuration has `isGlobal` and `directConnectivity` disabled, forcing all spoke-to-spoke traffic through the hub.
- **Why**: Direct connectivity between spokes (when appropriate) reduces latency and hub bottleneck. However, for security-enforced environments, hub transit is intentional. **ASK** the user about their spoke-to-spoke traffic policy before flagging.
- **Check**: Query AVNM connectivity configuration → check `connectivityTopology` and connectivity group settings.
- **Ref**: [AVNM connectivity configurations](https://learn.microsoft.com/azure/virtual-network-manager/concept-connectivity-configuration)

#### 🟢 Info

**AVNM-L1: AVNM inventory**
- List AVNM instances: scope (subscriptions/management groups), network groups (static/dynamic count), connectivity configs (hub-spoke/mesh), security admin configs, deployment status per region.
- Cross-reference with manual peering count to quantify automation gap.

---

## Network Watcher

### Why It Matters

Network Watcher provides the diagnostic, monitoring, and logging toolkit for Azure networking. NSG/VNet flow logs, connection monitoring, packet capture, IP flow verify, next hop, and VPN diagnostics are all Network Watcher features. If Network Watcher isn't enabled in a region, **none of these tools work there**. It is the foundational observability layer for Azure networking.

**Ref**: [Network Watcher overview](https://learn.microsoft.com/azure/network-watcher/network-watcher-overview)

### Checks

#### 🔴 Critical

**NW-C1: Network Watcher not enabled in regions with networking resources**
- **What**: Network Watcher is not provisioned in one or more regions where VNets, NSGs, or other networking resources exist.
- **Why**: Without Network Watcher in a region, you cannot use: NSG flow logs, VNet flow logs, connection monitor, packet capture, IP flow verify, next hop, or VPN diagnostics in that region. Complete networking blind spot.
- **Check**: Query Network Watcher resources → compare enabled regions against all regions where VNets exist.
- **Ref**: [Enable Network Watcher](https://learn.microsoft.com/azure/network-watcher/network-watcher-create)

#### 🟡 High

**NW-H1: NSG Flow Logs not enabled**
- **What**: NSGs exist without flow logs configured.
- **Why**: NSG flow logs record all IP traffic passing through NSGs — essential for security monitoring, traffic analysis, anomaly detection, and compliance. Without them, zero visibility into allowed/denied network flows.
- **Check**: Cross-reference NSG list with flow log resources → flag NSGs without flow logs.
- **Cross-ref**: NSG audit check H4 (nsg-audit.md). This check adds the Network Watcher perspective and VNet flow log alternative.
- **Ref**: [NSG flow logs overview](https://learn.microsoft.com/azure/network-watcher/nsg-flow-logs-overview)

**NW-H2: No Connection Monitor for critical connectivity paths**
- **What**: No Connection Monitor tests configured for critical connectivity paths (e.g., app → database, hub → spoke, Azure → on-prem, app → PaaS endpoints).
- **Why**: Connection Monitor provides continuous reachability and latency monitoring with alerting. Without it, connectivity failures are detected only reactively when users/apps report impact.
- **Check**: `az network watcher connection-monitor list` — check if any exist and their source/destination coverage.
- **Ref**: [Connection Monitor overview](https://learn.microsoft.com/azure/network-watcher/connection-monitor-overview)

**NW-H3: Using legacy NSG flow logs instead of VNet flow logs**
- **What**: Environment uses NSG flow logs but has not migrated to VNet flow logs.
- **Why**: VNet flow logs provide: coverage for all workloads including those bypassing NSGs, simplified management at VNet/subnet level instead of per-NSG, support for encrypted virtual networks, and VNet encryption status visibility. **NSG flow logs are being retired September 30, 2027** (no new NSG flow logs after June 30, 2025). Migration is mandatory.
- **Check**: Query flow log resources → identify NSG flow logs vs VNet flow logs → recommend migration.
- **ALZ Ref**: [Plan for Traffic Inspection — ALZ](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/plan-for-traffic-inspection) — *"Use virtual network flow logs and migrate from existing NSG flow logs configuration."*
- **Ref**: [VNet flow logs overview](https://learn.microsoft.com/azure/network-watcher/vnet-flow-logs-overview)

#### 🔵 Medium

**NW-M1: Traffic Analytics not enabled on flow logs**
- **What**: Flow logs exist but Traffic Analytics is not enabled.
- **Why**: Traffic Analytics processes raw flow logs into actionable insights — traffic patterns, top talkers, security threats, bandwidth utilization, geo distribution. Raw flow logs alone require significant manual analysis effort.
- **Check**: Query flow log resources → check `flowAnalyticsConfiguration.networkWatcherFlowAnalyticsConfiguration.enabled`.
- **Ref**: [Traffic Analytics overview](https://learn.microsoft.com/azure/network-watcher/traffic-analytics)

**NW-M2: Flow log retention too short**
- **What**: Flow log retention set to less than 90 days.
- **Why**: Many compliance frameworks (SOC 2, ISO 27001, PCI-DSS) require 90+ days of network traffic logs. Short retention means lost forensic data during incident investigation.
- **Check**: Query flow logs → check `retentionPolicy.days`.
- **Ref**: [NSG flow log format and retention](https://learn.microsoft.com/azure/network-watcher/nsg-flow-logs-overview#log-format)

**NW-M3: No packet capture configured for troubleshooting readiness**
- **What**: No packet capture configurations exist for critical VMs/VMSSes.
- **Why**: Packet capture enables on-demand traffic capture for troubleshooting — essential for diagnosing intermittent connectivity issues, protocol problems, or application-layer failures. Having pre-configured capture targets speeds up incident response.
- **Check**: `az network watcher packet-capture list` — check for existing captures or saved configurations.
- **Ref**: [Packet capture overview](https://learn.microsoft.com/azure/network-watcher/packet-capture-overview)

#### 🟢 Info

**NW-L1: Network Watcher feature inventory per region**
- List all Network Watcher instances by region.
- For each region: flow log coverage (% of NSGs/VNets with flow logs), Connection Monitor test count, Traffic Analytics status, packet capture usage.
- Flag regions with networking resources but missing Network Watcher features.

---

## Route Server

### Why It Matters

Azure Route Server enables dynamic route exchange between network virtual appliances (NVAs — third-party firewalls, SD-WAN appliances) and Azure's network fabric via BGP. Without Route Server, NVA routes must be manually maintained in UDRs — fragile, error-prone, and operationally expensive at scale. Route Server automates route propagation, supports failover, and enables multi-path routing.

> **Note**: Azure Firewall does NOT need Route Server — it has its own routing integration. Route Server is for **third-party NVAs** (Palo Alto, Cisco, Fortinet, SD-WAN, etc.).

**Ref**: [Azure Route Server overview](https://learn.microsoft.com/azure/route-server/overview)

### Checks

#### 🟡 High

**RS-H1: Third-party NVAs in hub VNet without Route Server**
- **What**: Network virtual appliances (third-party firewalls, SD-WAN) deployed in hub VNet without Route Server for dynamic route exchange.
- **Why**: Without Route Server, all routes to/from NVAs must be maintained in static UDRs. Route Server automates this via BGP, supporting automatic failover between NVA instances and dynamic route updates.
- **Check**: Identify third-party NVA deployments in hub VNets (non-Azure Firewall) → verify Route Server exists in the same VNet.
- **Ref**: [Route Server with NVA](https://learn.microsoft.com/azure/route-server/overview#how-does-it-work)

**RS-H2: Route Server branch-to-branch not enabled when needed**
- **What**: Route Server `allowBranchToBranchTraffic` is `false` in environments where transit between VPN/ER gateway and NVA is required.
- **Why**: Branch-to-branch enables route exchange between the VPN/ER gateway and NVA BGP peers. Required when NVAs must inspect or route traffic between on-premises branches and Azure resources. Without it, on-prem traffic cannot route through the NVA.
- **Check**: Query Route Server → check `allowBranchToBranchTraffic` → cross-reference with whether VPN/ER gateway and NVAs coexist in the hub.
- **Ref**: [Route Server routing considerations](https://learn.microsoft.com/azure/route-server/overview#critical-things-to-consider-about-routing)

**RS-H3: Route Server approaching BGP peer or route limits**
- **What**: Route Server nearing the limit of 8 BGP peers or receiving close to 1,000 routes per peer (10,000 total with certain configurations).
- **Why**: Exceeding limits causes route drops — routing failures are silent until traffic is affected. Monitor peer count and learned route count proactively.
- **Check**: `az network routeserver peering list` → count peers. `az network routeserver peering list-learned-routes` → count routes per peer.
- **Ref**: [Route Server limits and FAQ](https://learn.microsoft.com/azure/route-server/route-server-faq)

#### 🔵 Medium

**RS-M1: Single NVA instance peering with Route Server**
- **What**: Only one NVA instance is configured as a BGP peer with Route Server.
- **Why**: Route Server itself runs on redundant instances, but if the single NVA peer fails, dynamic routing is lost. At least two NVA instances should peer with Route Server for high availability.
- **Check**: Count Route Server BGP peers → flag if only 1 NVA peer (excluding gateway peers).
- **Ref**: [Route Server high availability](https://learn.microsoft.com/azure/route-server/route-server-faq#high-availability)

**RS-M2: Route Server and VPN/ER gateway route conflict risk**
- **What**: Route Server, VPN gateway, and ExpressRoute gateway coexist in the same VNet hub without understanding route preference.
- **Why**: When all three exist, route preference follows: ER BGP > VPN BGP > Route Server BGP > static UDR. Misunderstanding this hierarchy leads to unexpected routing behavior.
- **Check**: Verify if Route Server, VPN GW, and ER GW coexist → document route preference awareness.
- **Ref**: [Route Server route preference](https://learn.microsoft.com/azure/route-server/overview#critical-things-to-consider-about-routing)

#### 🟢 Info

**RS-L1: Route Server inventory**
- List all Route Servers: ASN, virtual router IPs, BGP peers (name, IP, ASN), branch-to-branch status, learned route count per peer.
- Cross-reference with VPN/ER gateways and NVAs in the same VNet.
- Note: Route Server pricing is hourly. No data processing charge.
- **Ref**: [Route Server pricing](https://azure.microsoft.com/pricing/details/route-server/)

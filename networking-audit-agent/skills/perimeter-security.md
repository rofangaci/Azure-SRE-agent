# Perimeter Security & Outbound Control

Audit checks for Azure DDoS Protection, Azure Bastion, and NAT Gateway — services that protect the network perimeter, control management access, and manage outbound connectivity.

## Discovery Queries

**DDoS Protection Plans:**
```
az graph query -q "Resources | where type =~ 'microsoft.network/ddosprotectionplans' | project name, id, resourceGroup, location, properties.virtualNetworks" --first 50 --subscription <subId>
```

**VNets with DDoS Protection status:**
```
az graph query -q "Resources | where type =~ 'microsoft.network/virtualnetworks' | project name, id, resourceGroup, properties.enableDdosProtection, properties.ddosProtectionPlan.id" --first 100 --subscription <subId>
```

**Public IPs (to cross-reference with DDoS coverage):**
```
az graph query -q "Resources | where type =~ 'microsoft.network/publicipaddresses' | project name, id, resourceGroup, sku.name, properties.ipAddress, properties.publicIPAllocationMethod, properties.ipConfiguration.id" --first 200 --subscription <subId>
```

**Azure Bastion hosts:**
```
az graph query -q "Resources | where type =~ 'microsoft.network/bastionhosts' | project name, id, resourceGroup, location, sku.name, properties.ipConfigurations" --first 50 --subscription <subId>
```

**AzureBastionSubnet sizing:**
```
az graph query -q "Resources | where type =~ 'microsoft.network/virtualnetworks' | mv-expand subnet = properties.subnets | where subnet.name =~ 'AzureBastionSubnet' | project vnetName=name, subnetName=tostring(subnet.name), addressPrefix=tostring(subnet.properties.addressPrefix)" --first 50 --subscription <subId>
```

**NAT Gateways:**
```
az graph query -q "Resources | where type =~ 'microsoft.network/natgateways' | project name, id, resourceGroup, location, sku.name, properties.idleTimeoutInMinutes, properties.publicIpAddresses, properties.publicIpPrefixes, properties.subnets" --first 50 --subscription <subId>
```

**VMs with public IPs (Bastion relevance):**
```
az graph query -q "Resources | where type =~ 'microsoft.network/networkinterfaces' | mv-expand ipconfig = properties.ipConfigurations | where isnotempty(ipconfig.properties.publicIPAddress.id) | project nicName=name, vmId=tostring(properties.virtualMachine.id), publicIpId=tostring(ipconfig.properties.publicIPAddress.id)" --first 200 --subscription <subId>
```

---

## DDoS Protection

### Why It Matters

Azure DDoS Protection provides enhanced mitigation for volumetric, protocol, and application-layer attacks targeting resources with public IPs. Without it, you rely only on Azure's infrastructure-level (Basic) DDoS protection, which does not provide telemetry, alerting, custom mitigation policies, or cost protection.

**Ref**: [Azure DDoS Protection overview](https://learn.microsoft.com/azure/ddos-protection/ddos-protection-overview)

### Checks

#### 🔴 Critical

**DDOS-C1: VNets with public IPs lack DDoS Protection Plan**
- **What**: Any VNet containing resources with public IP addresses has `enableDdosProtection == false`.
- **Why**: Without DDoS Protection, public-facing resources get only infrastructure-level protection — no telemetry, no alerting, no custom policies, no cost protection guarantee.
- **Check**: Query all VNets → filter those with `enableDdosProtection == false` → cross-reference with VNets containing public IP resources.
- **Ref**: [Fundamental best practices — Enable DDoS Protection](https://learn.microsoft.com/azure/ddos-protection/fundamental-best-practices)

#### 🟡 High

**DDOS-H1: DDoS Protection Plan exists but not associated with all VNets**
- **What**: A DDoS Plan is provisioned but some VNets with public IPs are not associated.
- **Why**: Partial coverage leaves unprotected VNets exposed. The plan covers up to 100 VNets (across subscriptions in same tenant) at no additional per-VNet cost.
- **Check**: Compare `ddosProtectionPlan.virtualNetworks[]` against all VNets with public IPs.
- **Ref**: [DDoS Protection Plan — VNet association](https://learn.microsoft.com/azure/ddos-protection/manage-ddos-protection#enable-for-an-existing-virtual-network)

**DDOS-H2: DDoS Protection diagnostic logs not enabled**
- **What**: DDoS Protection diagnostic settings (DDoSProtectionNotifications, DDoSMitigationFlowLogs, DDoSMitigationReports) not sent to Log Analytics.
- **Why**: Without logs, you have no visibility into active attacks or mitigation actions. Cannot perform post-attack forensics.
- **Check**: `az monitor diagnostic-settings list --resource <publicIpId>` — look for DDoS-specific log categories.
- **Ref**: [Configure DDoS diagnostic logs](https://learn.microsoft.com/azure/ddos-protection/diagnostic-logging)

**DDOS-H3: Public IPs using Basic SKU (incompatible with DDoS Protection)**
- **What**: Basic SKU public IPs exist in the environment.
- **Why**: Basic SKU public IPs cannot be protected by DDoS Protection plans. They also lack zone redundancy and have limited features. Basic SKU public IPs are being retired.
- **Check**: Query public IPs where `sku.name == 'Basic'`.
- **Ref**: [Public IP SKU comparison](https://learn.microsoft.com/azure/virtual-network/ip-services/public-ip-addresses#sku)

#### 🔵 Medium

**DDOS-M1: DDoS Protection alerts not configured**
- **What**: No Azure Monitor alerts for DDoS attack detection (metric: `IfUnderDDoSAttack`).
- **Why**: Without alerts, attacks go unnoticed until users report impact. Alert on attack start and end for rapid response.
- **Check**: `az monitor metrics alert list` — look for alerts on DDoS metrics.
- **Ref**: [Configure DDoS alerts](https://learn.microsoft.com/azure/ddos-protection/alerts)

**DDOS-M2: DDoS Protection rapid response not configured**
- **What**: DDoS Network Protection plan exists but DDoS Rapid Response (DRR) engagement is not pre-configured.
- **Why**: DRR provides direct access to Microsoft's DDoS experts during an active attack. Pre-configuration ensures faster response when under attack.
- **Check**: Review whether DDoS Rapid Response is part of the support plan and engagement process is documented.
- **Ref**: [DDoS Rapid Response](https://learn.microsoft.com/azure/ddos-protection/ddos-rapid-response)

#### 🟢 Info

**DDOS-L1: DDoS Protection inventory and cost note**
- List all DDoS Protection Plans, associated VNets, and public IP count per VNet.
- **Cost note**: DDoS Network Protection is ~$2,944/month per plan + overage per 100 Gbps. Covers up to 100 VNets. DDoS IP Protection is ~$199/month per public IP — better for small deployments (<15 public IPs).
- **Ref**: [DDoS Protection pricing](https://azure.microsoft.com/pricing/details/ddos-protection/)

---

## Azure Bastion

### Why It Matters

Azure Bastion provides secure RDP/SSH access to VMs directly through the Azure portal (or native client) without exposing VMs via public IPs. It eliminates the attack surface of open management ports (RDP 3389, SSH 22) on the internet — the #1 attack vector for VMs.

**Ref**: [Azure Bastion overview](https://learn.microsoft.com/azure/bastion/bastion-overview)

### Checks

#### 🔴 Critical

**BAST-C1: VMs with public IPs used for RDP/SSH access**
- **What**: VMs have public IPs AND NSG rules allowing inbound RDP (3389) or SSH (22).
- **Why**: Exposes management ports to the internet. Bastion eliminates this entirely by providing browser-based or native-client access over TLS without any public IP on the VM.
- **Check**: Cross-reference VMs with public IPs → check NSG rules for port 22/3389 inbound from `*` or `Internet`.
- **Cross-ref**: NSG audit check C1 (open management ports). This check adds the Bastion remediation path.
- **Ref**: [Why use Azure Bastion](https://learn.microsoft.com/azure/bastion/bastion-overview#why-use-azure-bastion)

#### 🟡 High

**BAST-H1: No Bastion deployed in hub VNet**
- **What**: Hub VNet (or shared services VNet) has no Bastion host, meaning VM management relies on VPN/ER + jump boxes or public IPs.
- **Why**: Bastion in the hub can service all peered spoke VNets (Standard SKU required), providing centralized, auditable management access. One Bastion instance covers the entire hub-spoke topology.
- **Check**: Look for Bastion host resources → verify at least one exists in a hub VNet → verify VNet peering allows Bastion access to spokes.
- **Ref**: [Bastion VNet peering — connect to VMs in peered VNets](https://learn.microsoft.com/azure/bastion/vnet-peering)

**BAST-H2: Bastion using Basic SKU**
- **What**: Bastion deployed with Basic SKU.
- **Why**: Basic SKU lacks: native client support, shareable links, IP-based connections, Kerberos auth, custom port, file upload/download via native client. Standard or Premium SKU unlocks these for enterprise use.
- **Check**: Query Bastion resources → check `sku.name`.
- **Ref**: [Bastion SKU feature comparison](https://learn.microsoft.com/azure/bastion/configuration-settings#skus)

**BAST-H3: AzureBastionSubnet smaller than /26**
- **What**: The `AzureBastionSubnet` has an address prefix smaller than /26.
- **Why**: /26 is the **minimum** required subnet size for Bastion. Smaller subnets fail deployment. /26 supports up to 60 concurrent sessions; scale up to /24 for higher concurrency.
- **Check**: Query subnets named `AzureBastionSubnet` → validate prefix length >= /26.
- **Ref**: [Bastion subnet requirements](https://learn.microsoft.com/azure/bastion/configuration-settings#subnet)

**BAST-H4: Bastion not deployed in regions with VMs**
- **What**: VMs exist in regions where no Bastion host is deployed, and there is no hub Bastion with peering access.
- **Why**: Bastion is regional. VMs in regions without Bastion (or reachable via peered hub Bastion) have no secure management access path.
- **Check**: Compare regions with VM deployments vs regions with Bastion hosts → flag gaps.
- **Ref**: [Bastion region availability](https://learn.microsoft.com/azure/bastion/bastion-overview#regions)

#### 🔵 Medium

**BAST-M1: Bastion diagnostic logs not enabled**
- **What**: `BastionAuditLogs` not sent to Log Analytics.
- **Why**: Without audit logs, no record of who connected to which VM, when, and from where — critical for security compliance and forensics.
- **Check**: `az monitor diagnostic-settings list --resource <bastionId>` — look for `BastionAuditLogs` category.
- **Ref**: [Bastion diagnostic logs](https://learn.microsoft.com/azure/bastion/diagnostic-logs)

**BAST-M2: Bastion not zone-redundant**
- **What**: Bastion Standard/Premium SKU deployed without availability zone configuration.
- **Why**: Zone failure could cause loss of management access to all VMs in that VNet. Zone-redundant Bastion survives single-zone outages.
- **Check**: Check Bastion properties for zone configuration.
- **Ref**: [Bastion availability zones](https://learn.microsoft.com/azure/bastion/configuration-settings#zones)

#### 🟢 Info

**BAST-L1: Bastion inventory**
- List all Bastion hosts: SKU, VNet, subnet size, scale units, features enabled, zone configuration.
- Note: Bastion pricing is hourly per scale unit. Standard SKU starts at 2 scale units.
- **Ref**: [Bastion pricing](https://azure.microsoft.com/pricing/details/azure-bastion/)

---

## NAT Gateway

### Why It Matters

NAT Gateway provides dedicated, predictable outbound internet connectivity for subnets using static public IPs. Without it, VMs rely on Azure's default outbound access (deprecated Sept 2025), load balancer SNAT (prone to port exhaustion), or instance-level public IPs — none of which provide the control, scalability, or reliability of NAT Gateway.

**Ref**: [Azure NAT Gateway overview](https://learn.microsoft.com/azure/nat-gateway/nat-overview)

### Checks

#### 🔴 Critical

**NAT-C1: Subnets relying on deprecated default outbound access**
- **What**: Subnets with VMs needing outbound internet access have no NAT Gateway, no LB with outbound rules, and no instance-level public IPs — relying on Azure's default outbound access.
- **Why**: Default outbound access was deprecated September 2025. It provides no static IP, no SNAT port guarantees, and no user control. New VMs in these subnets will NOT get outbound connectivity.
- **Check**: Query subnets → filter those without `natGateway` property and without LB association → cross-reference with VMs/resources requiring outbound.
- **Ref**: [Default outbound access retirement](https://learn.microsoft.com/azure/virtual-network/ip-services/default-outbound-access)

#### 🟡 High

**NAT-H1: NAT Gateway with single public IP**
- **What**: NAT Gateway configured with only one public IP address.
- **Why**: Each public IP provides ~64,512 SNAT ports. For workloads with high outbound connection rates (APIs, crawlers, microservices), a single IP risks SNAT port exhaustion. NAT Gateway supports up to 16 public IPs (~1M ports).
- **Check**: Query NAT Gateway → count `publicIpAddresses[]`.
- **Ref**: [NAT Gateway scaling and performance](https://learn.microsoft.com/azure/nat-gateway/nat-gateway-resource#scaling)

**NAT-H2: NAT Gateway not associated with all subnets needing outbound**
- **What**: NAT Gateway exists but is not associated with all subnets requiring outbound internet access.
- **Why**: Only subnets explicitly associated with the NAT Gateway use it. Unassociated subnets fall back to default outbound (deprecated) or have no outbound path.
- **Check**: Compare NAT Gateway `subnets[]` against all subnets with VMs/resources needing outbound.
- **Ref**: [NAT Gateway subnet association](https://learn.microsoft.com/azure/nat-gateway/nat-gateway-resource#subnets)

**NAT-H3: Subnets with both NAT Gateway and instance-level public IPs**
- **What**: VMs in NAT Gateway-associated subnets also have instance-level public IPs.
- **Why**: Instance-level public IPs take precedence over NAT Gateway for outbound traffic from that VM, creating inconsistent outbound IP behavior. This is often unintentional.
- **Check**: Cross-reference NAT Gateway subnets with VMs that have public IPs.
- **Ref**: [NAT Gateway and public IP precedence](https://learn.microsoft.com/azure/nat-gateway/nat-gateway-resource#public-ip-addresses)

#### 🔵 Medium

**NAT-M1: NAT Gateway idle timeout not tuned**
- **What**: NAT Gateway using default 4-minute idle timeout without evaluation.
- **Why**: For long-lived connections (database queries, file transfers, WebSocket), 4 minutes may be too short, causing unexpected connection drops. Can be set 4–120 minutes.
- **Check**: Query NAT Gateway → check `idleTimeoutInMinutes`.
- **Ref**: [NAT Gateway idle timeout](https://learn.microsoft.com/azure/nat-gateway/nat-gateway-resource#idle-timeout)

**NAT-M2: Public IP prefix not used for NAT Gateway**
- **What**: Using individual public IPs instead of a public IP prefix for NAT Gateway.
- **Why**: Public IP prefixes provide a contiguous IP range, simplifying firewall allowlisting at destination services (e.g., partner APIs that filter by IP range).
- **Check**: Query NAT Gateway → check if using `publicIpPrefixes` vs individual `publicIpAddresses`.
- **Ref**: [Public IP prefix for NAT Gateway](https://learn.microsoft.com/azure/nat-gateway/nat-gateway-resource#public-ip-prefixes)

#### 🟢 Info

**NAT-L1: NAT Gateway inventory**
- List all NAT Gateways: associated subnets, public IPs/prefixes, idle timeout, zones.
- Note: NAT Gateway is zone-resilient by default (spans all zones in a region). Pricing: per hour + per GB processed.
- **Ref**: [NAT Gateway pricing](https://azure.microsoft.com/pricing/details/azure-nat-gateway/)

**NAT-L2: Outbound connectivity method inventory**
- For each subnet, document the outbound connectivity method: NAT Gateway, LB outbound rules, instance-level public IP, or none (default/broken).
- This inventory is critical for validating outbound compliance post-default-outbound-access retirement.

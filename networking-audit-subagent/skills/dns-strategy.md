# DNS Architecture & Strategy Audit Checks

## Purpose

Audits DNS architecture patterns in Azure — focusing on Private DNS Zones, Azure DNS Private Resolver, hybrid DNS resolution (on-premises ↔ Azure), conditional forwarding, and multi-region DNS. This is one of the **most common pain points** for customers because DNS failures are silent, hard to diagnose, and affect everything.

> This file focuses on DNS **architecture and strategy**. For private endpoint-specific DNS record validation, see [dns-private-endpoints.md](dns-private-endpoints.md). For PaaS networking config, see [paas-networking.md](paas-networking.md).

## Why DNS Is the #1 Pain Point

1. **Private Endpoints require correct DNS** — If DNS resolves to the public IP instead of the private IP, traffic goes out to the internet and back, or is blocked entirely. The PE exists but is bypassed silently.
2. **Hybrid is hard** — On-premises DNS must forward `privatelink.*` zones to Azure. Azure DNS must forward corporate zones to on-prem. Getting both directions right is error-prone.
3. **Debugging is invisible** — DNS failures show up as "connection timeout" or "host not found" — not as "DNS misconfigured". Teams spend hours looking at NSGs and firewalls when the problem is DNS.
4. **Scale complexity** — As PE count grows (50, 100, 200+), managing DNS zones, VNet links, and A records becomes operationally heavy without automation.

**Ref**: https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/private-link-and-dns-integration-at-scale

## Key Architecture Patterns

### Pattern 1: Azure-Only (No Hybrid)

```
VNets → Azure DNS (168.63.129.16) → Private DNS Zones → Private IP
```

- Simplest pattern. Works out of the box if Private DNS Zones are linked to the VNets.
- **Risk**: Forgetting to link a zone to a VNet.
- **Ref**: https://learn.microsoft.com/azure/dns/private-dns-overview

### Pattern 2: Hybrid with Azure DNS Private Resolver (Recommended)

```
On-premises DNS → Conditional Forwarder → Azure DNS Private Resolver (Inbound Endpoint)
                                          ↓
                                   Private DNS Zones → Private IP

Azure VNets → Azure DNS Private Resolver (Outbound Endpoint) → On-premises DNS
```

- **Inbound endpoint**: On-prem forwards `privatelink.*` queries to the resolver's inbound IP (in your VNet).
- **Outbound endpoint**: Azure VNets forward corporate domain queries (e.g., `corp.contoso.com`) to on-prem DNS via the resolver's outbound endpoint + DNS forwarding ruleset.
- **Ref**: https://learn.microsoft.com/azure/dns/dns-private-resolver-overview

### Pattern 3: Hybrid with DNS Forwarder VM (Legacy)

```
On-premises DNS → Conditional Forwarder → DNS Forwarder VM (in hub VNet) → 168.63.129.16
                                          ↓
                                   Private DNS Zones → Private IP
```

- Pre-dates Azure DNS Private Resolver. Uses a Windows/Linux VM running DNS (BIND, Windows DNS, CoreDNS, etc.).
- **Downsides**: VM maintenance, no SLA, single point of failure (unless paired), no autoscaling.
- **Ref**: https://learn.microsoft.com/azure/private-link/private-endpoint-dns#on-premises-workloads-using-a-dns-forwarder
- **Migration path**: Replace with Azure DNS Private Resolver.

### Pattern 4: Multi-Region DNS

```
Region A: Hub VNet A → Private DNS Zones (linked to Region A VNets)
Region B: Hub VNet B → Private DNS Zones (linked to Region B VNets)
                        ↑
                  SAME Private DNS Zones (global resource, linked to VNets in BOTH regions)
```

- Private DNS Zones are **global** — a single zone can be linked to VNets in any region.
- **Risk**: Some customers create per-region DNS zones (e.g., `privatelink.blob.core.windows.net` in both East US and West US resource groups) → causes split-brain.
- **Correct approach**: One zone per `privatelink.*` domain, linked to all VNets that need resolution.
- **Ref**: https://learn.microsoft.com/azure/private-link/private-endpoint-dns#azure-services-dns-zone-configuration

## Discovery

```bash
# List all Private DNS Zones
az graph query -q "Resources | where type =~ 'microsoft.network/privatednszones' | project name, resourceGroup, recordCount=properties.numberOfRecordSets, vnetLinkCount=properties.numberOfVirtualNetworkLinks" --first 100 --subscription <subId>

# List all VNet links to Private DNS Zones
az graph query -q "Resources | where type =~ 'microsoft.network/privatednszones/virtualnetworklinks' | project zone=split(id, '/')[8], name, vnetId=properties.virtualNetwork.id, registrationEnabled=properties.registrationEnabled, provisioningState=properties.provisioningState" --first 500 --subscription <subId>

# Find Azure DNS Private Resolvers
az graph query -q "Resources | where type =~ 'microsoft.network/dnsresolvers' | project name, resourceGroup, location, state=properties.dnsResolverState, vnetId=properties.virtualNetwork.id" --first 10 --subscription <subId>

# Find DNS Private Resolver Inbound Endpoints
az graph query -q "Resources | where type =~ 'microsoft.network/dnsresolvers/inboundendpoints' | project resolverName=split(id, '/')[8], name, ip=properties.ipConfigurations[0].privateIpAddress, subnetId=properties.ipConfigurations[0].subnet.id" --first 20 --subscription <subId>

# Find DNS Private Resolver Outbound Endpoints
az graph query -q "Resources | where type =~ 'microsoft.network/dnsresolvers/outboundendpoints' | project resolverName=split(id, '/')[8], name, subnetId=properties.subnet.id" --first 20 --subscription <subId>

# Find DNS Forwarding Rulesets
az graph query -q "Resources | where type =~ 'microsoft.network/dnsforwardingrulesets' | project name, resourceGroup, id" --first 20 --subscription <subId>

# Get DNS forwarding rules (for outbound forwarding)
az dns-resolver forwarding-rule list --ruleset-name <ruleset-name> -g <rg> --subscription <subId>

# Check VNet DNS server configuration (custom vs Azure default)
az graph query -q "Resources | where type =~ 'microsoft.network/virtualnetworks' | project name, rg=resourceGroup, dnsServers=properties.dhcpOptions.dnsServers" --first 200 --subscription <subId>
```

## Audit Checks

### 🔴 Critical

#### DNS-C1: No DNS Resolution Path for Private Endpoints
**What**: Private endpoints exist but there is no functioning DNS resolution path — no Private DNS Zone linked to the consuming VNet, or VNet uses custom DNS servers that don't forward to Azure DNS.
**Why**: The PE exists but DNS resolves to the **public IP**. Traffic bypasses the PE silently. This is the #1 misconfiguration in PE deployments.
**Ref**: https://learn.microsoft.com/azure/private-link/private-endpoint-dns
**Check** (multi-step):
1. For each PE, identify which VNets need to resolve it
2. Check if the corresponding `privatelink.*` DNS zone exists
3. Check if that zone is linked to those VNets
4. If VNet uses custom DNS servers, check if they forward to `168.63.129.16` (or to a DNS Private Resolver inbound endpoint)
**Diagnostic test**:
```bash
# From a VM in the VNet, resolve the PaaS FQDN
nslookup <service>.blob.core.windows.net
# Should return: <service>.privatelink.blob.core.windows.net → 10.x.x.x (private IP)
# If it returns a public IP → DNS is NOT resolving through PE
```
**Remediation**: Depends on pattern (see architecture patterns above). Most common fix: link Private DNS Zone to the VNet.

#### DNS-C2: Duplicate Private DNS Zones (Split-Brain)
**What**: Multiple Private DNS Zones with the same name (e.g., two `privatelink.blob.core.windows.net` zones in different resource groups or subscriptions).
**Why**: Each zone may have different A records. Which one a VNet uses depends on which zone it's linked to. This causes inconsistent resolution — some VNets resolve PE correctly, others don't. Extremely hard to debug.
**Ref**: https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/private-link-and-dns-integration-at-scale#private-dns-zones
**Check**: Group all Private DNS Zones by name. Flag any name that appears more than once across all resource groups/subscriptions in scope.
```python
# Use ExecutePythonCode to group zones by name and flag duplicates
```
**Remediation**: Consolidate to a single zone (typically in the connectivity/hub subscription). Merge A records, update VNet links, then delete the duplicate.

#### DNS-C3: VNet Custom DNS Not Forwarding to Azure DNS
**What**: VNet has custom DNS servers configured (e.g., on-prem AD DNS), and those servers do NOT have a conditional forwarder to `168.63.129.16` (or to a DNS Private Resolver) for `privatelink.*` zones.
**Why**: All DNS queries from VMs in this VNet go to the custom DNS server first. If that server can't resolve `privatelink.*`, it falls back to root hints → resolves to the PUBLIC IP of the PaaS service. PE is completely bypassed.
**Ref**: https://learn.microsoft.com/azure/private-link/private-endpoint-dns#on-premises-workloads-using-a-dns-forwarder
**Check**:
1. Identify VNets with `properties.dhcpOptions.dnsServers` set (not empty)
2. These VNets use custom DNS → verify the custom DNS server forwards `privatelink.*` to Azure
3. **Cannot fully validate from Azure config alone** — the forwarding config lives on the DNS server itself
**Action**: Flag VNets with custom DNS. Ask the user: *"VNet X uses custom DNS servers [IPs]. Do those servers have conditional forwarders configured for privatelink.* zones pointing to Azure DNS (168.63.129.16) or to an Azure DNS Private Resolver?"*

### 🟡 High

#### DNS-H1: No Azure DNS Private Resolver in Hybrid Environment
**What**: Customer has hybrid connectivity (ER/VPN) but no Azure DNS Private Resolver or DNS forwarder VM in the hub.
**Why**: On-premises clients cannot resolve Azure Private DNS Zones (they don't have access to 168.63.129.16). PE names resolve to public IPs from on-prem.
**Ref**: https://learn.microsoft.com/azure/dns/dns-private-resolver-overview
**Check**:
1. Hybrid connectivity exists (VPN/ER gateway found)
2. No `microsoft.network/dnsresolvers` resource found
3. No DNS forwarder VM identified in the hub VNet
**Action**: Ask the user: *"You have hybrid connectivity but I don't see a DNS Private Resolver or forwarder VM. How do on-premises clients resolve Azure private endpoint names?"*
**Remediation**: Deploy Azure DNS Private Resolver in the hub VNet. Configure inbound endpoint. Configure on-prem DNS to forward `privatelink.*` to the inbound endpoint IP.

#### DNS-H2: DNS Forwarder VM Instead of DNS Private Resolver
**What**: Customer uses a VM-based DNS forwarder (Windows DNS, BIND, etc.) instead of the managed Azure DNS Private Resolver.
**Why**: VM-based forwarders require maintenance, patching, HA configuration, and monitoring. Azure DNS Private Resolver is a fully managed, highly available service.
**Ref**: https://learn.microsoft.com/azure/dns/dns-private-resolver-overview#benefits
**Check**: Look for VMs in the hub VNet running on port 53, or VNets pointing their custom DNS to IPs within Azure VNets.
**Action**: This is a migration recommendation, not a critical finding. Flag as improvement opportunity.
**Remediation**: Deploy DNS Private Resolver, migrate forwarding rules, update VNet DNS server settings, then decommission forwarder VMs.

#### DNS-H3: Private DNS Zone Not Linked to All Required VNets
**What**: A Private DNS Zone exists but is only linked to some VNets — VNets that need resolution are missing.
**Why**: VMs in unlinked VNets cannot resolve PEs via that zone. Common when new spokes are added but DNS links are forgotten.
**Check**: For each Private DNS Zone, compare its VNet links against:
- All spoke VNets that have workloads consuming the PaaS services with PEs
- The hub VNet (for DNS Private Resolver to work)
**Remediation**:
```bash
az network private-dns link vnet create -g <rg> --zone-name <zone> -n <link-name> --virtual-network <vnet-id> --registration-enabled false --subscription <subId>
```

#### DNS-H4: Outbound DNS Forwarding Not Configured (Azure → On-Prem)
**What**: Hybrid environment but no DNS forwarding ruleset for corporate domains (e.g., `corp.contoso.com`, `ad.internal`).
**Why**: Azure workloads can't resolve on-premises hostnames — needed for hybrid applications, AD-joined services, and cross-environment calls.
**Check**: If DNS Private Resolver exists, check for outbound endpoint + forwarding ruleset. If not, check if VNet custom DNS servers handle this.
```bash
az dns-resolver forwarding-rule list --ruleset-name <name> -g <rg> --subscription <subId>
```
**Action**: Ask user: *"Which on-premises DNS domains do Azure workloads need to resolve? (e.g., corp.contoso.com)"*
**Remediation**: Create outbound endpoint + forwarding ruleset rules for each on-prem domain.

#### DNS-H5: DNS Private Resolver Not Zone-Redundant
**What**: DNS Private Resolver inbound/outbound endpoints deployed in a single subnet without zone redundancy.
**Why**: If the subnet's availability zone goes down, DNS resolution fails for all linked VNets — cascading outage.
**Ref**: https://learn.microsoft.com/azure/dns/dns-private-resolver-overview#regional-availability
**Check**: DNS Private Resolver is inherently HA within a region, but the subnet it's deployed in matters. Verify the resolver exists in a region with AZ support and has endpoints in appropriately sized subnets.
**Note**: DNS Private Resolver supports availability zones natively as of GA. Confirm region support.

### 🔵 Medium

#### DNS-M1: Private DNS Zone Auto-Registration Enabled on privatelink Zones
**What**: VNet links to `privatelink.*` zones have `registrationEnabled: true`.
**Why**: Auto-registration creates A records for all VMs in the VNet inside the `privatelink.*` zone. This pollutes the zone with VM records that don't belong there, potentially causing name collisions.
**Check**: VNet links where `registrationEnabled == true` on any `privatelink.*` zone.
**Ref**: https://learn.microsoft.com/azure/dns/private-dns-autoregistration
**Remediation**: Disable auto-registration on `privatelink.*` zones. Only enable it on zones intended for VM name resolution (e.g., `contoso.internal`).

#### DNS-M2: Missing DNS Forwarding Ruleset VNet Links
**What**: DNS forwarding ruleset exists but is not linked to all VNets that need outbound forwarding.
**Why**: Only VNets linked to the ruleset will use its forwarding rules. Unlinked VNets fall through to default Azure DNS, which can't resolve on-prem names.
**Check**:
```bash
az dns-resolver forwarding-ruleset list -g <rg> --subscription <subId>
# Then check VNet links for each ruleset
az dns-resolver vnet-link list --ruleset-name <name> -g <rg> --subscription <subId>
```
**Remediation**: Link the ruleset to all spoke VNets that need on-prem resolution.

#### DNS-M3: Stale DNS A Records in Private DNS Zones
**What**: A records exist in Private DNS Zones that point to IPs no longer in use (orphaned PE was deleted but record remains).
**Why**: DNS resolves to a dead IP → connection timeout. Especially problematic when IPs are recycled and a new resource gets the old IP.
**Check**: For each A record in `privatelink.*` zones, verify the IP maps to an active Private Endpoint NIC.
```python
# Use ExecutePythonCode to cross-reference DNS records with PE NIC IPs
```
**Remediation**: Delete stale A records. Use PE DNS Zone Groups for automatic lifecycle management.

#### DNS-M4: No Custom Domain for Private DNS
**What**: Customer doesn't have a custom private DNS zone for internal name resolution (only using `privatelink.*` zones).
**Why**: Without a custom zone (e.g., `internal.contoso.com`), there's no friendly name resolution for VMs and services within Azure. Teams resort to using IP addresses or relying on OS-level hosts files.
**Action**: Ask user: *"Do you have a custom private DNS zone for internal Azure resources (e.g., internal.contoso.com)? This enables friendly name resolution."*

### 🟢 Low / Info

#### DNS-L1: DNS Architecture Summary
Produce a summary of the current DNS architecture:
```
## DNS Architecture Overview
- **DNS Pattern**: [Azure-only / Hybrid with Private Resolver / Hybrid with Forwarder VM / Unknown]
- **Private DNS Zones**: [count] zones, [count] total VNet links
- **DNS Private Resolver**: [Yes/No] — Location: [region] — Inbound IP: [ip]
- **DNS Forwarding Rulesets**: [count] rulesets, [count] rules
- **VNets with Custom DNS**: [count] out of [total] VNets
- **Forwarder VMs**: [count] identified
```

#### DNS-L2: Private DNS Zone Inventory
| Zone Name | Resource Group | Record Count | VNet Links | Registration Enabled? |
|-----------|---------------|-------------|------------|----------------------|

#### DNS-L3: DNS Resolution Test Matrix
For critical PaaS services with PEs, document the expected resolution:
| Service FQDN | Expected Private IP | DNS Zone | Zone Linked to Consuming VNet? | Verified? |
|--------------|--------------------|-----------|-----------------------------|-----------| 

#### DNS-L4: ALZ DNS Recommended Zone List
Cross-reference deployed zones against the full ALZ recommended list:
**Ref**: https://learn.microsoft.com/azure/private-link/private-endpoint-dns#azure-services-dns-zone-configuration

Common zones that should exist if the corresponding PaaS service is in use:
| Service | Required Zone |
|---------|--------------|
| Storage Blob | `privatelink.blob.core.windows.net` |
| Storage File | `privatelink.file.core.windows.net` |
| Storage DFS | `privatelink.dfs.core.windows.net` |
| Key Vault | `privatelink.vaultcore.azure.net` |
| SQL | `privatelink.database.windows.net` |
| Cosmos DB (SQL API) | `privatelink.documents.azure.com` |
| ACR | `privatelink.azurecr.io` |
| Event Hub | `privatelink.servicebus.windows.net` |
| Service Bus | `privatelink.servicebus.windows.net` |
| Web App | `privatelink.azurewebsites.net` |
| Azure Monitor | `privatelink.monitor.azure.com` |
| Azure OpenAI | `privatelink.openai.azure.com` |

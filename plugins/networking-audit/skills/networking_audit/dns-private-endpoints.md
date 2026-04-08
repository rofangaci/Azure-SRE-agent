# DNS & Private Endpoints Audit Checks

## Discovery

```bash
# List all Private Endpoints
az graph query -q "Resources | where type =~ 'microsoft.network/privateendpoints' | project name, resourceGroup, location, targetResource=properties.privateLinkServiceConnections[0].properties.privateLinkServiceId, groupIds=properties.privateLinkServiceConnections[0].properties.groupIds, connectionState=properties.privateLinkServiceConnections[0].properties.privateLinkServiceConnectionState.status" --first 200 --subscription <subId>

# List all Private DNS Zones
az graph query -q "Resources | where type =~ 'microsoft.network/privatednszones' | project name, resourceGroup, recordCount=properties.numberOfRecordSets, vnetLinkCount=properties.numberOfVirtualNetworkLinks" --first 100 --subscription <subId>

# List Private DNS Zone VNet Links
az graph query -q "Resources | where type =~ 'microsoft.network/privatednszones/virtualnetworklinks' | project zone=split(id, '/')[8], name, vnetId=properties.virtualNetwork.id, registrationEnabled=properties.registrationEnabled" --first 200 --subscription <subId>

# List Public IPs and their associations
az graph query -q "Resources | where type =~ 'microsoft.network/publicipaddresses' | project name, resourceGroup, ip=properties.ipAddress, allocation=properties.publicIPAllocationMethod, associatedTo=properties.ipConfiguration.id" --first 200 --subscription <subId>

# Find PaaS resources that support Private Link (common ones)
az graph query -q "Resources | where type in~ ('microsoft.storage/storageaccounts', 'microsoft.keyvault/vaults', 'microsoft.sql/servers', 'microsoft.documentdb/databaseaccounts', 'microsoft.servicebus/namespaces', 'microsoft.eventhub/namespaces', 'microsoft.cognitiveservices/accounts') | project name, type, resourceGroup, id" --first 200 --subscription <subId>
```

## Audit Checks

### 🔴 Critical

#### C1: PaaS Services Without Private Endpoints
**What**: Key PaaS services (Storage, Key Vault, SQL, Cosmos DB) accessible only via public endpoints with no private endpoint configured.
**Why**: Data traverses public internet. Violates ALZ principle of private-by-default. Exposes to network-based attacks.
**Ref**: https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/private-link-and-dns-integration-at-scale
**Check**: For each PaaS resource, check if a corresponding private endpoint exists.
```bash
# Check if a storage account has private endpoints
az network private-endpoint-connection list --id <resource-id> --subscription <subId>
```
**Priority PaaS services to check**: Storage Accounts, Key Vaults, SQL Servers, Cosmos DB, Service Bus, Event Hub, Cognitive Services, ACR.
**Remediation**: Create private endpoints for each PaaS service and disable public access.

#### C2: Public Network Access Enabled on Sensitive PaaS
**What**: PaaS resources have `publicNetworkAccess: Enabled` despite having private endpoints.
**Why**: Private endpoint is bypassed — traffic can still come in via public internet.
**Ref**: https://learn.microsoft.com/azure/private-link/disable-public-access
**Check**:
```bash
# Example for Storage Account
az storage account show -g <rg> -n <name> --query "publicNetworkAccess" --subscription <subId>
# Example for Key Vault
az keyvault show -g <rg> -n <name> --query "properties.publicNetworkAccess" --subscription <subId>
```
**Remediation**: Disable public network access after confirming private endpoint connectivity.
```bash
az storage account update -g <rg> -n <name> --public-network-access Disabled --subscription <subId>
```

#### C3: Private Endpoint in Disconnected State
**What**: Private endpoint exists but connection state is `Disconnected` or `Rejected`.
**Why**: Private endpoint is non-functional. DNS may still resolve to private IP, causing silent failures.
**Ref**: https://learn.microsoft.com/azure/private-link/manage-private-endpoint#manage-private-endpoint-connections
**Check**: `connectionState.status != 'Approved'`.
**Remediation**: Approve the connection on the PaaS resource side, or recreate the private endpoint.

### 🟡 High

#### H1: Private DNS Zone Not Linked to VNet
**What**: Private DNS zone exists but is not linked to the VNet that needs to resolve the private endpoint.
**Why**: DNS queries from that VNet won't resolve the private endpoint — traffic goes to public IP instead.
**Ref**: https://learn.microsoft.com/azure/private-link/private-endpoint-dns#azure-services-dns-zone-configuration
**Check**: For each private DNS zone, verify VNet links exist for all VNets that need resolution.
**Common zones to check**:
| Service | DNS Zone |
|---------|----------|
| Storage Blob | `privatelink.blob.core.windows.net` |
| Storage File | `privatelink.file.core.windows.net` |
| Key Vault | `privatelink.vaultcore.azure.net` |
| SQL | `privatelink.database.windows.net` |
| Cosmos DB | `privatelink.documents.azure.com` |
| ACR | `privatelink.azurecr.io` |

**Remediation**:
```bash
az network private-dns link vnet create -g <rg> --zone-name <zone> -n <link-name> --virtual-network <vnet-id> --registration-enabled false --subscription <subId>
```

#### H2: Missing DNS A Record for Private Endpoint
**What**: Private endpoint exists but no corresponding A record in the private DNS zone.
**Why**: DNS resolution will fall through to public IP — private endpoint is unused.
**Check**: For each private endpoint, verify an A record exists in the correct private DNS zone.
```bash
az network private-dns record-set a list -g <rg> -z <zone-name> --subscription <subId>
```
**Remediation**: Usually automatic if DNS zone integration was configured during PE creation. If missing, add manually or recreate PE with DNS zone group.

#### H3: Private DNS Zone in Wrong Resource Group / Subscription
**What**: Private DNS zones scattered across multiple resource groups instead of centralized.
**Why**: ALZ recommends centralizing private DNS zones in the connectivity subscription/hub. Scattered zones are hard to manage and can conflict.
**Ref**: https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/private-link-and-dns-integration-at-scale#private-dns-zones
**Check**: Report where each private DNS zone lives. Flag if not in a central connectivity resource group.
**Remediation**: Plan migration to central DNS zone management (usually in hub/connectivity subscription).

#### H4: Orphaned Public IPs
**What**: Public IP addresses not associated with any resource.
**Why**: Unused public IPs cost money and expand the attack surface.
**Check**: Public IPs where `properties.ipConfiguration.id` is null/empty.
**Remediation**: Delete unused public IPs.
```bash
az network public-ip delete -g <rg> -n <pip-name> --subscription <subId>
```

#### H5: Unnecessary Public IPs on Internal Workloads
**What**: VMs or internal load balancers with public IPs when they should be accessed only via private network.
**Why**: Exposes internal workloads to internet. Use Azure Bastion for management access.
**Check**: Cross-reference public IPs with their associated resources; flag any that are backend workloads (not gateways/firewalls/bastion).

### 🔵 Medium

#### M1: DNS Forwarder / Resolver Not Configured
**What**: Hub VNet has no Azure DNS Private Resolver or DNS forwarder VM.
**Why**: On-premises clients can't resolve Azure private DNS zones. Hybrid DNS resolution breaks.
**Ref**: https://learn.microsoft.com/azure/dns/dns-private-resolver-overview
**Check**: Look for DNS Private Resolver resource or DNS forwarder VMs in hub VNet.
```bash
az graph query -q "Resources | where type =~ 'microsoft.network/dnsresolvers' | project name, resourceGroup, location" --first 10 --subscription <subId>
```
**Remediation**: Deploy Azure DNS Private Resolver in hub VNet.

#### M2: Custom DNS Servers on VNet
**What**: VNet configured with custom DNS servers instead of Azure-provided DNS.
**Why**: Not inherently bad (common in hybrid), but must be correctly configured to forward to Azure DNS (168.63.129.16) for private endpoint resolution.
**Ref**: https://learn.microsoft.com/azure/private-link/private-endpoint-dns#on-premises-workloads-using-a-dns-forwarder
**Check**: `properties.dhcpOptions.dnsServers` on VNet.
**Action**: If custom DNS is set, verify the custom DNS server forwards to 168.63.129.16 for `privatelink.*` zones.

#### M3: Private Endpoint NIC Not in Same VNet as Workload
**What**: Private endpoint deployed in a different VNet than the workload consuming it.
**Why**: Requires peering/routing to reach the PE. Adds complexity and latency. DNS resolution must work cross-VNet.
**Check**: Compare PE VNet with the VNet of the primary consumer.
**Note**: This is valid in hub-spoke designs where PEs are centralized in the hub. Flag for review, not necessarily a problem.

#### M4: Private DNS Zone Auto-Registration
**What**: Auto-registration enabled on a private DNS zone linked to the VNet.
**Why**: Auto-registration creates A records for all VMs in the VNet — may pollute DNS and create conflicts.
**Check**: VNet links with `registrationEnabled: true`.
**Recommendation**: Only enable auto-registration on zones intended for VM name resolution, not for privatelink zones.

### 🟢 Low / Info

#### L1: Private Endpoint Inventory
Report a complete inventory of all private endpoints, their target services, connection state, and DNS configuration.

#### L2: DNS Zone Inventory
Report all private DNS zones, their record counts, and VNet link status.

#### L3: Public IP Inventory
Report all public IPs, their SKU, allocation method, and association.

#### L4: DNS Resolution Validation
For critical private endpoints, perform a DNS resolution test to confirm the private IP is returned:
```bash
az network private-endpoint dns-zone-group list --endpoint-name <pe-name> -g <rg> --subscription <subId>
```

# PaaS Networking & Service Exposure Audit Checks

## Purpose

Audits how PaaS services are connected to the network — covering Private Endpoints, Private Link Service, Service Endpoints, and PaaS-level firewall rules. Ensures services follow the ALZ principle of **private-by-default** and validates that network isolation is correctly implemented end-to-end.

> This file focuses on the PaaS networking **configuration** side. For DNS resolution of private endpoints, see [dns-strategy.md](dns-strategy.md). For topology-level placement, see [vnet-topology.md](vnet-topology.md).

## Key Concepts

### Private Endpoint vs Service Endpoint vs Public Access

| Aspect | Private Endpoint | Service Endpoint | Public Access |
|--------|-----------------|------------------|---------------|
| Traffic path | Via private IP in your VNet | Via Azure backbone (still public IP on PaaS side) | Public internet |
| DNS resolution | Resolves to private IP (via Private DNS Zone) | Resolves to public IP | Resolves to public IP |
| Network isolation | Full — PaaS gets a NIC in your VNet | Partial — source subnet is allowed, PaaS keeps its public IP | None |
| Cross-region | Yes | No (same region only) | Yes |
| On-prem access | Yes (if VNet is reachable from on-prem) | No (on-prem traffic still hits public endpoint) | Yes |
| Cost | PE resource + data processing charges | Free | Free |
| ALZ recommendation | **Preferred** | Acceptable for specific scenarios | Avoid for sensitive data |

**Ref**: https://learn.microsoft.com/azure/private-link/private-link-service-overview
**Ref**: https://learn.microsoft.com/azure/virtual-network/virtual-network-service-endpoints-overview

### Private Link Service (Provider Side)

Private Link Service is the **provider-side** construct. It allows you to expose your own service (behind a Standard Load Balancer) to consumers via Private Endpoints — even across tenants/subscriptions.

| Use Case | Example |
|----------|---------|
| ISV exposing SaaS to customers | Your API behind ILB → consumers create PE in their VNet |
| Internal shared services | Central team's API exposed to spoke subscriptions via PE |
| Cross-tenant connectivity | Partner access without VNet peering or VPN |

**Ref**: https://learn.microsoft.com/azure/private-link/private-link-service-overview

## ⚠️ MANDATORY: PaaS-Specific Documentation Rule

> **Before auditing or recommending networking configuration for ANY PaaS service, you MUST consult the service-specific Microsoft documentation listed below.**
> Each PaaS service has its own networking model, firewall behavior, trusted-service bypass logic, and limitations.
> **DO NOT generalize** — what works for Storage does not work for Key Vault, SQL, or Cosmos DB.
> If a PaaS service is encountered that is not listed below, search the MS docs for `"<service> networking"` or `"<service> private endpoint"` before making any recommendation.

### PaaS Service Networking Reference Index

| PaaS Service | Networking Doc (MUST READ before auditing) | Key Differences |
|-------------|-------------------------------------------|-----------------| 
| **Storage Account** | https://learn.microsoft.com/azure/storage/common/storage-network-security | `networkRuleSet` with `defaultAction`, `bypass` (AzureServices, Logging, Metrics), per-service PE (`blob`, `file`, `table`, `queue`, `dfs`, `web`). `allowSharedKeyAccess` controls auth. HNS (Data Lake) has additional considerations. |
| **Key Vault** | https://learn.microsoft.com/azure/key-vault/general/network-security | `publicNetworkAccess` + IP/VNet rules. Trusted services bypass is separate from network rules. Soft-delete and purge protection interact with PE behavior. |
| **Azure SQL** | https://learn.microsoft.com/azure/azure-sql/database/network-access-controls-overview | Server-level firewall rules, VNet rules, `publicNetworkAccess`, `deny public network access` differs from `Disabled`. Outbound networking restrictions. Managed Instance has its own VNet-injected model. |
| **Cosmos DB** | https://learn.microsoft.com/azure/cosmos-db/how-to-configure-firewall | Per-account IP rules, VNet rules, `publicNetworkAccess`. Different APIs (SQL, MongoDB, Cassandra, Gremlin, Table) may need different PE group IDs. Analytical store has separate networking. |
| **Azure Container Registry** | https://learn.microsoft.com/azure/container-registry/container-registry-access-selected-networks | `publicNetworkAccess`, IP rules, dedicated data endpoint (`*.data.azurecr.io` — needs its own PE for image pull isolation). Geo-replicated registries need PE per replica. |
| **Service Bus** | https://learn.microsoft.com/azure/service-bus-messaging/service-bus-service-endpoints | IP filter rules, VNet rules, trusted services, `publicNetworkAccess`. Premium SKU required for PE. |
| **Event Hub** | https://learn.microsoft.com/azure/event-hubs/event-hubs-service-endpoints | Similar to Service Bus — IP filter, VNet rules, trusted services. Dedicated/Premium SKU for PE. Kafka endpoint needs consideration. |
| **Azure OpenAI / Cognitive Services** | https://learn.microsoft.com/azure/ai-services/cognitive-services-virtual-networks | `publicNetworkAccess`, `networkAcls`, custom subdomain required for PE. Content filtering adds networking nuance. |
| **App Service / Function App** | https://learn.microsoft.com/azure/app-service/networking-features | Inbound: Access restrictions, PE (for inbound private access). Outbound: VNet Integration, hybrid connections. IP-based restrictions differ from PE. Regional VNet integration subnet delegation required. |
| **Azure Database for PostgreSQL (Flexible)** | https://learn.microsoft.com/azure/postgresql/flexible-server/concepts-networking | Two models: **Public access** (firewall rules) vs **Private access** (VNet injection, not PE). VNet-injected servers have delegated subnet. Different from PE-based approach. |
| **Azure Database for MySQL (Flexible)** | https://learn.microsoft.com/azure/mysql/flexible-server/concepts-networking | Same two models as PostgreSQL Flexible: public access or VNet injection (delegated subnet). |
| **Azure Cache for Redis** | https://learn.microsoft.com/azure/azure-cache-for-redis/cache-network-isolation | PE support, VNet injection (Premium SKU), firewall rules, `publicNetworkAccess`. VNet injection and PE are mutually exclusive patterns. |
| **Azure Kubernetes Service (AKS)** | https://learn.microsoft.com/azure/aks/concepts-network | API server: public, private (PE), or VNet integration. Node networking: kubenet vs Azure CNI vs CNI Overlay. Ingress/egress via LB + UDR. Very different from standard PaaS PE model. |
| **Azure Monitor / Log Analytics** | https://learn.microsoft.com/azure/azure-monitor/logs/private-link-security | Azure Monitor Private Link Scope (AMPLS) — not a standard PE. Links multiple Monitor resources behind one PE. Global vs per-resource mode. Complex scoping rules. |

### How to Use This Index

When the skill encounters a PaaS resource during audit:
1. **Look up the service** in the table above
2. **Read the linked doc** (or search MS docs if not listed) to understand that service's specific networking model
3. **Only then** evaluate whether the current config is correct or needs remediation
4. **Cite the service-specific doc** (not generic PE docs) in your finding

Example — **WRONG approach**:
> "Storage account has public access enabled → disable it" (generic, ignores `bypass` and `networkRuleSet` nuance)

Example — **CORRECT approach**:
> "Storage account `mystorageacct` has `defaultAction: Allow` in its network rule set. Per [Storage network security docs](https://learn.microsoft.com/azure/storage/common/storage-network-security), set `defaultAction: Deny` and configure allowed VNet/IP rules. Note: `bypass: AzureServices` is currently set, which allows trusted Azure services (e.g., Azure Backup, Azure Monitor) to access the account regardless of network rules — confirm with the user if this bypass is intentional."

## Discovery

```bash
# List all Private Endpoints
az graph query -q "Resources | where type =~ 'microsoft.network/privateendpoints' | project name, resourceGroup, location, targetResource=properties.privateLinkServiceConnections[0].properties.privateLinkServiceId, groupIds=properties.privateLinkServiceConnections[0].properties.groupIds, connectionState=properties.privateLinkServiceConnections[0].properties.privateLinkServiceConnectionState.status" --first 200 --subscription <subId>

# List all Private Link Services (provider-side)
az graph query -q "Resources | where type =~ 'microsoft.network/privatelinkservices' | project name, resourceGroup, location, lbFrontendIp=properties.loadBalancerFrontendIpConfigurations[0].id, visibility=properties.visibility.subscriptions, autoApproval=properties.autoApproval.subscriptions" --first 50 --subscription <subId>

# List all Service Endpoints on subnets
az graph query -q "Resources | where type =~ 'microsoft.network/virtualnetworks' | mv-expand subnet = properties.subnets | mv-expand se = subnet.properties.serviceEndpoints | project vnet=name, rg=resourceGroup, subnet=subnet.name, service=se.service, locations=se.locations" --first 500 --subscription <subId>

# PaaS resources and their public network access status
az graph query -q "Resources | where type in~ ('microsoft.storage/storageaccounts', 'microsoft.keyvault/vaults', 'microsoft.sql/servers', 'microsoft.documentdb/databaseaccounts', 'microsoft.servicebus/namespaces', 'microsoft.eventhub/namespaces', 'microsoft.cognitiveservices/accounts', 'microsoft.containerregistry/registries', 'microsoft.web/sites') | project name, type, resourceGroup, id" --first 500 --subscription <subId>

# Check PE connections on a specific resource
az network private-endpoint-connection list --id <resource-id> --subscription <subId>

# Storage account network rules (example for PaaS firewall)
az storage account show -g <rg> -n <name> --query "{publicAccess:publicNetworkAccess, defaultAction:networkRuleSet.defaultAction, virtualNetworkRules:networkRuleSet.virtualNetworkRules, ipRules:networkRuleSet.ipRules, bypass:networkRuleSet.bypass}" --subscription <subId>
```

## Audit Checks

### 🔴 Critical

#### PE-C1: Sensitive PaaS Without Private Endpoint
**What**: Key PaaS services have no private endpoint configured — accessible only via public endpoint.
**Why**: Data traverses public internet. ALZ mandates private-by-default for data services. Violates WAF Security pillar.
**Ref**: https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/private-link-and-dns-integration-at-scale
**Check**: For each PaaS resource, verify at least one private endpoint connection exists with state `Approved`.
```bash
az network private-endpoint-connection list --id <resource-id> --subscription <subId>
```
**Priority services** (check these first):
| Service | Type | Private Link Group ID |
|---------|------|----------------------|
| Storage Account | `microsoft.storage/storageaccounts` | `blob`, `file`, `table`, `queue`, `dfs`, `web` |
| Key Vault | `microsoft.keyvault/vaults` | `vault` |
| SQL Server | `microsoft.sql/servers` | `sqlServer` |
| Cosmos DB | `microsoft.documentdb/databaseaccounts` | `Sql`, `MongoDB`, `Cassandra`, `Gremlin`, `Table` |
| Service Bus | `microsoft.servicebus/namespaces` | `namespace` |
| Event Hub | `microsoft.eventhub/namespaces` | `namespace` |
| ACR | `microsoft.containerregistry/registries` | `registry` |
| Cognitive Services / OpenAI | `microsoft.cognitiveservices/accounts` | `account` |
| App Service | `microsoft.web/sites` | `sites` |

**Ref — Supported resources**: https://learn.microsoft.com/azure/private-link/private-link-service-overview#availability
**Remediation**: Create private endpoint for each PaaS service, then disable public access.

#### PE-C2: Public Network Access Still Enabled After PE Creation
**What**: PaaS resource has a private endpoint BUT `publicNetworkAccess` is still `Enabled` (or `networkRuleSet.defaultAction` is `Allow`).
**Why**: The private endpoint provides a private path, but the public door is still open. An attacker can bypass the PE entirely.
**Ref**: https://learn.microsoft.com/azure/private-link/disable-public-access
**Check per service**:
```bash
# Storage
az storage account show -g <rg> -n <name> --query "publicNetworkAccess" --subscription <subId>
# Key Vault
az keyvault show -g <rg> -n <name> --query "properties.publicNetworkAccess" --subscription <subId>
# SQL
az sql server show -g <rg> -n <name> --query "publicNetworkAccess" --subscription <subId>
# Cosmos DB
az cosmosdb show -g <rg> -n <name> --query "publicNetworkAccess" --subscription <subId>
# ACR
az acr show -g <rg> -n <name> --query "publicNetworkAccess" --subscription <subId>
```
**Remediation**: Disable public network access after confirming PE connectivity works end-to-end.
> ⚠️ **Ask before disabling**: Confirm with the user that all consumers can reach the PE. Disabling public access can break CI/CD pipelines, portal access, and external integrations that haven't been migrated.

#### PE-C3: Private Endpoint Connection Not Approved
**What**: Private endpoint exists but connection state is `Pending`, `Rejected`, or `Disconnected`.
**Why**: PE is non-functional. DNS may resolve to private IP, causing silent failures — the worst kind of outage.
**Ref**: https://learn.microsoft.com/azure/private-link/manage-private-endpoint#manage-private-endpoint-connections
**Check**: `connectionState.status != 'Approved'` on PE connections.
**Remediation**: Approve the connection on the PaaS resource, or re-create the PE if stuck.

### 🟡 High

#### PE-H1: Service Endpoint Used Where Private Endpoint Should Be
**What**: Subnets have service endpoints configured to PaaS services, but no corresponding private endpoints.
**Why**: Service endpoints provide partial isolation (Azure backbone routing, subnet-level ACL) but the PaaS resource still has a public IP. On-premises clients cannot use service endpoints. ALZ recommends PE over SE for new deployments.
**Ref**: https://learn.microsoft.com/azure/virtual-network/virtual-network-service-endpoints-overview#key-benefits
**Check**: For subnets with service endpoints, check if the target PaaS resource also has a PE.
**When SE is acceptable**:
- Legacy workloads where PE migration is not yet planned
- Specific services where PE is not yet supported
- Cost-sensitive scenarios (SE is free, PE has data processing charges)
**Action**: Flag for review. Ask the user if migration to PE is planned.

#### PE-H2: PaaS Firewall Rules Too Broad
**What**: PaaS resource network rules allow broad IP ranges (e.g., /8, /16) or allow all Azure services (`bypass: AzureServices`).
**Why**: Broad IP rules undermine network isolation. `AzureServices` bypass allows ANY Azure service in ANY tenant to access the resource.
**Ref**: https://learn.microsoft.com/azure/storage/common/storage-network-security#trusted-microsoft-services
**Check**:
```bash
# Storage example
az storage account show -g <rg> -n <name> --query "networkRuleSet" --subscription <subId>
```
Flag:
- `ipRules` with CIDRs larger than /28
- `bypass` set to `AzureServices` without understanding the implications
- `defaultAction: Allow`
**Remediation**: Narrow IP rules to specific ranges. Evaluate if `AzureServices` bypass is truly needed. Use PE + managed identity instead.

#### PE-H3: Missing Private Endpoint for Sub-Resources
**What**: PaaS service has PE for one sub-resource but not others being used.
**Why**: Example: Storage account has PE for `blob` but the app also uses `table` or `queue` — those calls go over public endpoint.
**Check**: Cross-reference PE group IDs with actual PaaS sub-resources in use.
**Common misses**:
| Service | Often forgotten sub-resource |
|---------|------------------------------|
| Storage | `table`, `queue`, `dfs` (only `blob` has PE) |
| Cosmos DB | Secondary API endpoints |
| SQL Server | `sqlServer` PE doesn't cover `sqlOnDemand` (Synapse) |
**Action**: Ask user which sub-resources are actively used. Don't assume — validate.

#### PE-H4: Private Link Service Without Connection Limits
**What**: Private Link Service (provider-side) has no connection limits or visibility/auto-approval restrictions.
**Why**: Without limits, any subscription could create a PE to your service (if visibility is `*`). This is a security and capacity risk.
**Ref**: https://learn.microsoft.com/azure/private-link/private-link-service-overview#properties
**Check**:
```bash
az network private-link-service show -g <rg> -n <pls-name> --subscription <subId> --query "{visibility:visibility, autoApproval:autoApproval, maxConnections:natGateway}"
```
Flag:
- `visibility.subscriptions` set to `*` (all subscriptions can see it)
- `autoApproval.subscriptions` set to `*` (all connections auto-approved)
**Remediation**: Restrict visibility and auto-approval to specific subscription IDs.

#### PE-H5: Private Endpoint in Wrong VNet / Subnet
**What**: PE deployed in a VNet/subnet that is not where the consuming workload lives, without proper routing.
**Why**: If the PE NIC is in VNet A but the app is in VNet B, VNet peering (or vWAN connection) is required AND DNS must resolve from VNet B. This is valid in hub-spoke (centralized PE), but must be confirmed.
**Check**: Compare PE VNet with consuming workload VNet.
**Action**: Ask user about their PE placement strategy — centralized (hub) or distributed (spoke). Don't flag as a problem without context.

### 🔵 Medium

#### PE-M1: Service Endpoint Policy Not Applied
**What**: Service endpoints are configured but no Service Endpoint Policy restricts which specific PaaS resources can be accessed.
**Why**: Without a policy, the service endpoint allows the subnet to access ANY instance of that PaaS type (e.g., any Storage account in Azure). A compromised VM could exfiltrate data to an attacker's storage account.
**Ref**: https://learn.microsoft.com/azure/virtual-network/virtual-network-service-endpoint-policies-overview
**Check**: Subnets with service endpoints but no `serviceEndpointPolicies` associated.
**Remediation**: Create and apply service endpoint policies that restrict access to specific resource IDs.
```bash
az network service-endpoint policy create -g <rg> -n <policy-name> --subscription <subId>
az network service-endpoint policy-definition create -g <rg> --policy-name <policy> -n <def-name> --service Microsoft.Storage --service-resources <storage-account-id> --subscription <subId>
```

#### PE-M2: PaaS Diagnostic Settings Not Capturing Network Events
**What**: PaaS resource has no diagnostic settings logging network-related events (e.g., StorageRead/Write, AuditEvent for Key Vault).
**Why**: Can't audit who accessed the resource or detect unauthorized access patterns.
**Check**:
```bash
az monitor diagnostic-settings list --resource <resource-id> --subscription <subId>
```
**Remediation**: Enable diagnostic logs to Log Analytics workspace.

#### PE-M3: Managed Identity Not Used for PaaS Access
**What**: Applications authenticate to PaaS services using connection strings with keys/passwords instead of managed identity.
**Why**: Keys can be leaked, shared, and don't expire automatically. Managed identity provides keyless, auditable authentication.
**Ref**: https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview
**Check**: This is hard to audit purely from network config. Look for:
- Storage accounts with `allowSharedKeyAccess: true`
- Key Vault access policies using `objectId` of service principals with client secrets
- Connection strings in App Settings containing passwords
**Action**: Flag for review and recommend migration to managed identity.

#### PE-M4: Cross-Region Private Endpoint Without Justification
**What**: Private endpoint is in a different region than the PaaS resource.
**Why**: Cross-region PE adds latency and cross-region data transfer costs. Valid for DR or global services, but should be intentional.
**Check**: Compare PE `location` with target PaaS resource `location`.
**Action**: Ask user if cross-region PE is intentional (DR, multi-region app).

### 🟢 Low / Info

#### PE-L1: PaaS Network Isolation Inventory
Produce a summary table for all PaaS resources:
| Resource | Type | Has PE? | PE State | Public Access | SE? | Firewall Rules | Status |
|----------|------|---------|----------|---------------|-----|---------------|--------|
| mystorage01 | Storage | Yes | Approved | Disabled | No | N/A | ✅ Secure |
| mykv01 | Key Vault | Yes | Approved | Enabled | No | 2 IP rules | ⚠️ Public still open |
| mysql01 | SQL | No | N/A | Enabled | Yes | Default Allow | ❌ Not isolated |

#### PE-L2: Private Link Service Inventory
If any Private Link Services exist, report:
| PLS Name | Load Balancer | Visibility | Auto-Approval | Connection Count |
|----------|---------------|------------|---------------|-----------------|

#### PE-L3: Service Endpoint Coverage
Report which subnets have which service endpoints enabled:
| VNet | Subnet | Service Endpoints |
|------|--------|-------------------|

#### PE-L4: Cost Estimation Note
Private endpoints incur:
- PE resource cost: ~$7.30/month per PE (as of 2024)
- Data processing: $0.01/GB inbound + outbound
Flag total PE count and estimated monthly cost for planning.
**Ref**: https://azure.microsoft.com/pricing/details/private-link/

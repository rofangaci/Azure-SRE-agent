# NSG & Firewall Audit Checks

## Discovery

```bash
# List all NSGs
az graph query -q "Resources | where type =~ 'microsoft.network/networksecuritygroups' | project name, resourceGroup, location, id" --first 200 --subscription <subId>

# Get NSG with full rules
az network nsg show -g <rg> -n <nsg> --subscription <subId>

# List all NSGs with their associated subnets and NICs
az graph query -q "Resources | where type =~ 'microsoft.network/networksecuritygroups' | project name, resourceGroup, subnetCount=array_length(properties.subnets), nicCount=array_length(properties.networkInterfaces)" --first 200 --subscription <subId>

# Find Azure Firewalls
az graph query -q "Resources | where type =~ 'microsoft.network/azurefirewalls' | project name, resourceGroup, location, properties.sku.tier" --first 50 --subscription <subId>

# Check NSG flow logs
az graph query -q "Resources | where type =~ 'microsoft.network/networkwatchers/flowlogs' | project name, resourceGroup, properties.targetResourceId, properties.enabled" --first 100 --subscription <subId>
```

## Audit Checks

### 🔴 Critical

#### C1: Open Management Ports to Internet
**What**: NSG rules allowing inbound SSH (22), RDP (3389), or WinRM (5985/5986) from `*`, `Internet`, or `0.0.0.0/0`.
**Why**: Direct attack vector. #1 cause of VM compromise.
**Ref**: https://learn.microsoft.com/azure/security/fundamentals/network-best-practices#disable-rdpssh-access-to-virtual-machines
**Check**:
```bash
az network nsg list --subscription <subId> --query "[].{nsg:name, rg:resourceGroup, rules:securityRules[?direction=='Inbound' && access=='Allow' && (destinationPortRange=='22' || destinationPortRange=='3389' || destinationPortRange=='5985' || destinationPortRange=='5986') && (sourceAddressPrefix=='*' || sourceAddressPrefix=='Internet' || sourceAddressPrefix=='0.0.0.0/0')]}" -o json
```
**Remediation**: Restrict source to specific IP ranges, use Azure Bastion, or use JIT VM access.
```bash
az network nsg rule update -g <rg> --nsg-name <nsg> -n <rule> --source-address-prefixes <specific-ip-range> --subscription <subId>
```

#### C2: Any-Any Inbound Allow
**What**: NSG rules with source `*`, destination `*`, port `*`, protocol `*`, action `Allow` on inbound.
**Why**: Effectively disables the NSG — no network segmentation.
**Ref**: https://learn.microsoft.com/azure/virtual-network/network-security-groups-overview#security-rules
**Check**: Inspect all inbound Allow rules where sourceAddressPrefix is `*` AND destinationPortRange is `*`.
**Remediation**: Replace with specific allow rules for required traffic, then add explicit deny-all.

#### C3: High-Risk Ports Open to Internet
**What**: Inbound Allow from Internet on database ports (1433, 3306, 5432, 27017), SMB (445), or other sensitive ports.
**Why**: Database and file share ports should never be directly internet-facing.
**Ref**: https://learn.microsoft.com/azure/security/fundamentals/network-best-practices#logically-segment-subnets
**Ports to check**: 1433 (SQL), 3306 (MySQL), 5432 (PostgreSQL), 27017 (MongoDB), 445 (SMB), 1521 (Oracle), 6379 (Redis), 9200 (Elasticsearch), 11211 (Memcached).
**Remediation**: Remove internet-facing rules; use private endpoints for PaaS databases.

#### C4: Outbound Allow All to Internet
**What**: Custom outbound rules allowing all traffic to `Internet` or `*` on all ports.
**Why**: Enables data exfiltration. ALZ requires centralized egress through firewall.
**Ref**: https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/plan-for-internet-inbound-outbound
**Check**: Look for custom outbound Allow rules (not the default Azure rules) with destination `*` or `Internet` and port `*`.
**Remediation**: Route egress through Azure Firewall or NVA; use UDR 0.0.0.0/0 → firewall.

### 🟡 High

#### H1: NSG Not Associated with Any Subnet or NIC
**What**: NSG exists but is not attached to any subnet or NIC.
**Why**: Orphaned resource — either misconfiguration (intended protection not applied) or cleanup needed.
**Check**: NSGs where `properties.subnets` is empty AND `properties.networkInterfaces` is empty.
**Remediation**: Associate with intended subnet/NIC, or delete if orphaned.

#### H2: Subnet Without NSG
**What**: A subnet has no NSG associated.
**Why**: No network-level filtering — all traffic allowed. ALZ requires NSG on every subnet.
**Ref**: https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/plan-for-traffic-inspection#nsgs
**Check**:
```bash
az graph query -q "Resources | where type =~ 'microsoft.network/virtualnetworks' | mv-expand subnet = properties.subnets | project vnet=name, subnet=subnet.name, nsg=subnet.properties.networkSecurityGroup.id | where isnull(nsg) or isempty(nsg)" --first 200 --subscription <subId>
```
**Exceptions**: AzureFirewallSubnet, AzureFirewallManagementSubnet, GatewaySubnet, AzureBastionSubnet, RouteServerSubnet — these subnets must NOT have an NSG.
**Remediation**: Create and associate an NSG with appropriate rules.

#### H3: Overly Broad Source/Destination
**What**: Allow rules using `*` as source or destination address prefix where a more specific CIDR or service tag could be used.
**Why**: Violates least-privilege networking. Expands blast radius.
**Check**: Rules where sourceAddressPrefix or destinationAddressPrefix is `*` but action is `Allow`.
**Remediation**: Replace `*` with specific CIDRs, service tags (e.g., `VirtualNetwork`, `AzureLoadBalancer`), or ASGs.

#### H4: NSG Flow Logs Not Enabled
**What**: NSG does not have flow logs enabled, or flow logs are disabled.
**Why**: No visibility into traffic patterns. Required for security monitoring and forensics.
**Ref**: https://learn.microsoft.com/azure/network-watcher/nsg-flow-logs-overview
**Check**: Cross-reference NSG list with flow log list; flag NSGs without flow logs.
**Remediation**:
```bash
az network watcher flow-log create -g <rg> --nsg <nsg-id> --storage-account <storage-id> --enabled true --retention 90 --subscription <subId>
```

#### H5: Missing Deny-All Catchall
**What**: No explicit low-priority deny-all rule at the end of the NSG rule set.
**Why**: While Azure has implicit deny, explicit deny-all with logging provides auditability.
**Check**: Look for a rule with priority >= 4000, action Deny, source `*`, destination `*`, port `*`.
**Note**: This is a best-practice recommendation, not a security gap (implicit deny exists).

### 🔵 Medium

#### M1: Large Port Ranges
**What**: Allow rules with port ranges spanning 100+ ports (e.g., `1000-9999`).
**Why**: Over-provisioned access. Likely includes unintended ports.
**Check**: Parse destinationPortRange for ranges; flag if span > 100.
**Remediation**: Narrow to specific required ports.

#### M2: Priority Gaps / Ordering Issues
**What**: Rules with non-sequential priorities or allow rules with lower priority than deny rules for the same traffic.
**Why**: Can indicate config drift or rules that will never be evaluated.
**Check**: Sort rules by priority; flag gaps > 100 between consecutive rules and allow-after-deny patterns.

#### M3: Deprecated or Unused Rules
**What**: Rules that reference IP ranges no longer in use, or that duplicate default rules.
**Why**: Config clutter makes auditing harder and increases risk of mistakes.
**Check**: Cross-reference rule source/destination CIDRs with actual VNet address spaces.

#### M4: Azure Firewall Not Using Premium SKU Features
**What**: Azure Firewall deployed but not using TLS inspection, IDPS, or URL filtering.
**Why**: Missing advanced threat protection capabilities.
**Ref**: https://learn.microsoft.com/azure/firewall/premium-features
**Check**: `az network firewall show` — inspect `sku.tier` and policy features.

### 🟢 Low / Info

#### L1: NSG Rule Count
**What**: Report total rule count per NSG.
**Why**: NSGs with many rules (50+) are harder to audit and maintain. Consider ASGs for simplification.

#### L2: Service Tag Usage
**What**: Report whether rules use service tags vs raw IP ranges.
**Why**: Service tags auto-update with Azure IP ranges — more maintainable.

#### L3: NSG Naming Convention
**What**: Check if NSG names follow a consistent naming pattern.
**Why**: ALZ recommends `nsg-<workload>-<env>-<region>` or similar.

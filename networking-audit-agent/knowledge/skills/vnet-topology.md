# VNet & Topology Audit Checks

## Discovery

```bash
# List all VNets with address spaces
az graph query -q "Resources | where type =~ 'microsoft.network/virtualnetworks' | project name, resourceGroup, location, addressSpace=properties.addressSpace.addressPrefixes, subnetCount=array_length(properties.subnets)" --first 200 --subscription <subId>

# List all peerings
az graph query -q "Resources | where type =~ 'microsoft.network/virtualnetworks' | mv-expand peering = properties.virtualNetworkPeerings | project vnet=name, rg=resourceGroup, peerName=peering.name, peerState=peering.properties.peeringState, remoteVnet=peering.properties.remoteVirtualNetwork.id, allowForwardedTraffic=peering.properties.allowForwardedTraffic, allowGatewayTransit=peering.properties.allowGatewayTransit, useRemoteGateways=peering.properties.useRemoteGateways" --first 200 --subscription <subId>

# List all route tables
az graph query -q "Resources | where type =~ 'microsoft.network/routetables' | project name, resourceGroup, routes=properties.routes, disableBgpRoutePropagation=properties.disableBgpRoutePropagation" --first 200 --subscription <subId>

# List all subnets with their associations
az graph query -q "Resources | where type =~ 'microsoft.network/virtualnetworks' | mv-expand subnet = properties.subnets | project vnet=name, rg=resourceGroup, subnet=subnet.name, addressPrefix=subnet.properties.addressPrefix, nsg=subnet.properties.networkSecurityGroup.id, routeTable=subnet.properties.routeTable.id, delegations=subnet.properties.delegations" --first 500 --subscription <subId>

# Find VPN and ExpressRoute gateways
az graph query -q "Resources | where type =~ 'microsoft.network/virtualnetworkgateways' | project name, resourceGroup, gatewayType=properties.gatewayType, vpnType=properties.vpnType, sku=properties.sku.name, activeActive=properties.activeActive" --first 50 --subscription <subId>

# Find Virtual WAN hubs
az graph query -q "Resources | where type =~ 'microsoft.network/virtualhubs' | project name, resourceGroup, addressPrefix=properties.addressPrefix, virtualWan=properties.virtualWan.id, routingState=properties.routingState" --first 50 --subscription <subId>

# Find Virtual WANs (parent resource)
az graph query -q "Resources | where type =~ 'microsoft.network/virtualwans' | project name, resourceGroup, sku=properties.type, allowBranchToBranchTraffic=properties.allowBranchToBranchTraffic" --first 10 --subscription <subId>

# Find ExpressRoute circuits
az graph query -q "Resources | where type =~ 'microsoft.network/expressroutecircuits' | project name, resourceGroup, sku=properties.sku, peeringLocation=properties.peeringLocation, serviceProviderName=properties.serviceProviderProperties.serviceProviderName, bandwidthInMbps=properties.serviceProviderProperties.bandwidthInMbps" --first 50 --subscription <subId>

# Find VPN connections
az graph query -q "Resources | where type =~ 'microsoft.network/connections' | project name, resourceGroup, connectionType=properties.connectionType, enableBgp=properties.enableBgp, connectionStatus=properties.connectionStatus" --first 100 --subscription <subId>
```

## Audit Checks

### 🔴 Critical

#### C1: Address Space Overlap
**What**: Two or more VNets (or VNet + on-premises) have overlapping CIDR ranges.
**Why**: Causes routing ambiguity. Breaks peering, VPN, and ExpressRoute. Cannot be fixed without re-IPing.
**Ref**: https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/plan-for-ip-addressing
**Check**: Parse all VNet address spaces; detect any CIDR overlap between peered VNets or VNets connected via gateway.
```python
# Use ExecutePythonCode to compare CIDR ranges
import ipaddress
# For each pair of VNets, check if any address prefixes overlap
```
**Remediation**: Re-IP the overlapping VNet (major effort) or use NAT gateway for specific scenarios.

#### C2: Missing Default Route to Firewall (Spoke VNets)
**What**: Spoke VNets without a UDR sending 0.0.0.0/0 to the hub firewall/NVA.
**Why**: Traffic from spokes bypasses centralized security inspection — ALZ critical requirement.
**Ref**: https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/plan-for-traffic-inspection
**Check**: For each spoke VNet's subnets, verify route table exists AND has a route for `0.0.0.0/0` with next hop type `VirtualAppliance` pointing to firewall IP.
**Exceptions**: GatewaySubnet — should NOT have 0.0.0.0/0 to firewall.
**Remediation**:
```bash
# Create route table
az network route-table create -g <rg> -n <rt-name> --subscription <subId>
# Add default route
az network route-table route create -g <rg> --route-table-name <rt> -n default-to-firewall --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address <firewall-private-ip> --subscription <subId>
# Associate with subnet
az network vnet subnet update -g <rg> --vnet-name <vnet> -n <subnet> --route-table <rt-id> --subscription <subId>
```

#### C3: Peering State Not Connected
**What**: VNet peering exists but state is not `Connected` (e.g., `Disconnected`, `Initiated`).
**Why**: Broken connectivity between VNets. Traffic will fail.
**Ref**: https://learn.microsoft.com/azure/virtual-network/virtual-network-peering-overview#connectivity
**Check**: Filter peerings where `peeringState != 'Connected'`.
**Remediation**: Ensure peering is created on both sides. Re-create if stuck in bad state.

### 🟡 High

#### H1: Hub VNet Not Identified / No Hub-Spoke Pattern
**What**: Multiple VNets exist but no clear hub-spoke topology (no central VNet with gateway + firewall).
**Why**: ALZ strongly recommends hub-spoke or Virtual WAN. Flat topology lacks centralized control.
**Ref**: https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/define-an-azure-network-topology
**Check**: Look for a VNet with: (a) VPN/ER gateway, (b) Azure Firewall or NVA, (c) peered to multiple spokes.
**Remediation**: Designate or create a hub VNet; migrate to hub-spoke topology.

#### H2: Peering Without Forwarded Traffic
**What**: Hub-to-spoke peering has `allowForwardedTraffic: false`.
**Why**: Traffic from on-premises (via gateway) or other spokes (via firewall) won't reach this spoke.
**Ref**: https://learn.microsoft.com/azure/virtual-network/virtual-network-peering-overview#gateways-and-on-premises-connectivity
**Check**: On spoke-side peering, `allowForwardedTraffic` should be `true`. On hub-side peering, `allowGatewayTransit` should be `true`.
**Remediation**:
```bash
az network vnet peering update -g <rg> --vnet-name <spoke-vnet> -n <peering-name> --set allowForwardedTraffic=true --subscription <subId>
```

#### H3: Gateway Transit Not Configured
**What**: Hub VNet has a gateway but `allowGatewayTransit` is not enabled on hub-side peering.
**Why**: Spoke VNets can't use the hub's VPN/ER gateway for on-premises connectivity.
**Ref**: https://learn.microsoft.com/azure/virtual-network/virtual-network-peering-overview#gateways-and-on-premises-connectivity
**Check**: Hub-side peering should have `allowGatewayTransit: true`. Spoke-side should have `useRemoteGateways: true`.
**Remediation**: Update peering on both sides.

#### H4: VPN/ER Gateway Not Active-Active
**What**: VPN or ExpressRoute gateway deployed in single-instance mode.
**Why**: Single point of failure. No redundancy during maintenance or failure.
**Check**: `properties.activeActive == false` on the gateway resource.
**Ref**: https://learn.microsoft.com/azure/vpn-gateway/vpn-gateway-highlyavailable
**Remediation**:
```bash
az network vnet-gateway update -g <rg> -n <gw-name> --active-active true --subscription <subId>
```

### 🟠 Virtual Network Gateway — Detailed Checks (ExpressRoute & VPN)

> Ref: https://learn.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpngateways
> Ref: https://learn.microsoft.com/azure/expressroute/expressroute-about-virtual-network-gateways

#### GW1: Gateway SKU Appropriateness (🟡 High)
**What**: VPN or ExpressRoute gateway using a deprecated, undersized, or non-AZ-redundant SKU.
**Why**: Deprecated SKUs (Basic, Standard for VPN) lack features and are on retirement path. Non-AZ SKUs (VpnGw1, VpnGw2, VpnGw3) don't survive availability zone failures. Production workloads should use AZ-redundant SKUs.
**Check**:
```bash
az graph query -q "Resources | where type =~ 'microsoft.network/virtualnetworkgateways' | project name, rg=resourceGroup, gatewayType=properties.gatewayType, sku=properties.sku.name, tier=properties.sku.tier, activeActive=properties.activeActive, generation=properties.vpnGatewayGeneration" --first 50 --subscription <subId>
```
**VPN — Preferred production SKUs**: VpnGw2AZ, VpnGw3AZ, VpnGw4AZ, VpnGw5AZ (Gen2 preferred).
**ExpressRoute — Preferred SKUs**: ErGw1AZ, ErGw2AZ, ErGw3AZ, ErGwScale.
**Ref — VPN SKUs**: https://learn.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpn-gateway-settings#gwsku
**Ref — ER SKUs**: https://learn.microsoft.com/azure/expressroute/expressroute-about-virtual-network-gateways#gwsku
**Remediation**: Resize the gateway to an AZ-redundant SKU:
```bash
az network vnet-gateway update -g <rg> -n <gw-name> --sku VpnGw2AZ --subscription <subId>
```

#### GW2: ExpressRoute Circuit Redundancy (🔴 Critical)
**What**: ExpressRoute gateway connected to a single circuit or single peering location.
**Why**: Single circuit = single point of failure. Microsoft recommends two circuits across two peering locations for maximum resiliency.
**Check**:
```bash
az network vnet-gateway list-bgp-peer-status -g <rg> -n <gw-name> --subscription <subId>
az network express-route list --subscription <subId> --query "[].{name:name, peeringLocation:peeringLocation, serviceProviderName:serviceProviderProvisioningState, circuitState:circuitProvisioningState}"
```
Count circuits per gateway. Flag if only one circuit or same peering location for both.
**Ref**: https://learn.microsoft.com/azure/expressroute/designing-for-high-availability-with-expressroute
**Remediation**: Deploy a second ExpressRoute circuit in a different peering location and connect to the gateway.

#### GW3: VPN Gateway Connections Without BGP (🟡 High)
**What**: Site-to-site VPN connections using static routing instead of BGP.
**Why**: Static routes don't auto-adapt to network changes. BGP enables automatic failover and route propagation in active-active and multi-site scenarios.
**Check**:
```bash
az network vpn-connection list -g <rg> --subscription <subId> --query "[].{name:name, enableBgp:enableBgp, routingWeight:routingWeight}"
```
Flag connections where `enableBgp == false`.
**Ref**: https://learn.microsoft.com/azure/vpn-gateway/vpn-gateway-bgp-overview
**Remediation**: Enable BGP on the VPN connection and configure BGP peering parameters.

#### GW4: Gateway Diagnostics Not Enabled (🔵 Medium)
**What**: Virtual Network Gateway has no diagnostic settings sending logs to Log Analytics.
**Why**: No visibility into tunnel status, BGP peer changes, IKE negotiations, or route updates. Critical for troubleshooting hybrid connectivity.
**Check**:
```bash
az monitor diagnostic-settings list --resource <gateway-resource-id> --subscription <subId>
```
**Key log categories**: GatewayDiagnosticLog, TunnelDiagnosticLog, RouteDiagnosticLog, IKEDiagnosticLog, P2SDiagnosticLog.
**Ref**: https://learn.microsoft.com/azure/vpn-gateway/monitor-vpn-gateway
**Remediation**: Enable diagnostic settings.

#### GW5: ExpressRoute Circuit Not Using FastPath (🔵 Medium)
**What**: ExpressRoute connection not configured with FastPath enabled (when using Ultra Performance or ErGw3AZ/ErGwScale gateway).
**Why**: FastPath bypasses the gateway for data-plane traffic, reducing latency for high-throughput scenarios.
**Check**: `az network vpn-connection show -g <rg> -n <conn-name> --subscription <subId>` — check `expressRouteGatewayBypass` property.
**Ref**: https://learn.microsoft.com/azure/expressroute/about-fastpath
**Remediation**: Enable FastPath on the ExpressRoute connection (requires ErGw3AZ or Ultra Performance SKU).

#### GW6: GatewaySubnet Sizing (🟡 High)
**What**: GatewaySubnet is too small (< /27).
**Why**: Azure recommends /27 for GatewaySubnet. Smaller subnets may not have enough IPs for active-active, coexistence (VPN + ER), or future features.
**Check**: Inspect the GatewaySubnet address prefix in the VNet.
**Ref**: https://learn.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpn-gateway-settings#gwsub
**Remediation**: Resize the GatewaySubnet (requires deleting and recreating the gateway — disruptive).

---

#### H5: Subnets Without Route Table
**What**: Subnets (other than exempted ones) don't have a route table associated.
**Why**: No custom routing — traffic follows default Azure routing, bypassing firewall.
**Check**: Subnets where `routeTable` is null/empty.
**Exceptions**: GatewaySubnet (may or may not need UDR depending on design), AzureFirewallSubnet, AzureBastionSubnet.
**Remediation**: Create and associate a route table with appropriate routes.

#### H6: BGP Route Propagation Enabled on Spoke Subnets
**What**: Route tables on spoke subnets have `disableBgpRoutePropagation: false`.
**Why**: On-premises routes propagated via BGP can override the 0.0.0.0/0 → firewall UDR, causing traffic to bypass the firewall.
**Ref**: https://learn.microsoft.com/azure/virtual-network/virtual-networks-udr-overview#border-gateway-protocol
**Check**: Spoke subnet route tables should have `disableBgpRoutePropagation: true`.
**Exceptions**: Depends on design — some scenarios require BGP propagation.
**Remediation**:
```bash
az network route-table update -g <rg> -n <rt> --disable-bgp-route-propagation true --subscription <subId>
```

### 🟠 Virtual WAN Topology

> These checks apply when the environment uses Azure Virtual WAN instead of (or alongside) traditional hub-spoke.
> Ref: https://learn.microsoft.com/azure/virtual-wan/virtual-wan-about

#### V1: Virtual WAN SKU (🔴 Critical)
**What**: Virtual WAN deployed with Basic SKU instead of Standard.
**Why**: Basic SKU does not support VPN site-to-site transit, ExpressRoute, User VPN (P2S), VHub-to-VHub, or Azure Firewall integration. Most production scenarios require Standard.
**Check**: `az graph query -q "Resources | where type =~ 'microsoft.network/virtualwans' | project name, resourceGroup, sku=properties.type" --first 10 --subscription <subId>`
**Ref**: https://learn.microsoft.com/azure/virtual-wan/virtual-wan-about#basicstandard
**Remediation**: Upgrade Virtual WAN to Standard SKU.

#### V2: Virtual Hub Without Azure Firewall / Secured Hub (🔴 Critical)
**What**: Virtual WAN hub exists but has no Azure Firewall or third-party NVA deployed (not a "secured virtual hub").
**Why**: Without a firewall in the hub, there is no centralized traffic inspection. All traffic flows unfiltered between spokes, branches, and internet.
**Check**: `az graph query -q "Resources | where type =~ 'microsoft.network/azurefirewalls' | where properties.virtualHub.id != '' | project name, hubId=properties.virtualHub.id" --first 50 --subscription <subId>` — cross-reference with virtual hub list.
**Ref**: https://learn.microsoft.com/azure/firewall-manager/secured-virtual-hub
**Remediation**: Deploy Azure Firewall in the Virtual WAN hub to create a secured virtual hub via Azure Firewall Manager.

#### V3: Routing Intent Not Configured (🟡 High)
**What**: Secured virtual hub has Azure Firewall but Routing Intent is not enabled.
**Why**: Without Routing Intent, you must manually manage route tables and static routes in the hub. Routing Intent automates inter-hub and branch-to-internet routing through the firewall with less operational overhead and fewer misconfigurations.
**Check**: `az network vhub routing-intent show --resource-group <rg> --vhub-name <hub-name> --subscription <subId>` — if not found, Routing Intent is not configured.
**Ref**: https://learn.microsoft.com/azure/virtual-wan/how-to-routing-policies
**Remediation**: Configure Routing Intent with Internet and/or Private traffic policies pointing to Azure Firewall.

#### V4: vWAN Hub Not Deployed in Expected Regions (🟡 High)
**What**: Virtual WAN exists but hubs are not deployed in all regions where workloads or branches reside.
**Why**: Spokes in regions without a hub must route through a remote hub, adding latency and cross-region data transfer costs.
**Check**: Compare virtual hub locations with VNet/branch locations.
**Ref**: https://learn.microsoft.com/azure/virtual-wan/virtual-wan-global-transit-network-architecture
**Remediation**: Deploy additional virtual hubs in regions with workloads or branches.

#### V5: VNet Connections Missing from Virtual Hub (🟡 High)
**What**: VNets exist in the same region as a virtual hub but are not connected to it.
**Why**: Unconnected VNets don't benefit from virtual WAN routing, firewall inspection, or branch connectivity.
**Check**: `az network vhub connection list --resource-group <rg> --vhub-name <hub-name> --subscription <subId>` — compare with VNets in the same region.
**Ref**: https://learn.microsoft.com/azure/virtual-wan/virtual-wan-site-to-site-portal#vnet
**Remediation**: Create VNet connections from the virtual hub.

#### V6: Static Routes Instead of BGP for Branches (🔵 Medium)
**What**: VPN site connections use only static routes rather than BGP.
**Why**: Static routes don't adapt to topology changes. BGP provides automatic route propagation and failover.
**Check**: `az network vpn-site show -g <rg> -n <site-name> --subscription <subId>` — check `bgpProperties`.
**Ref**: https://learn.microsoft.com/azure/virtual-wan/virtual-wan-site-to-site-portal#site
**Remediation**: Enable BGP on VPN sites and configure BGP peering addresses and ASN.

#### V7: Virtual Hub Address Space Conflict (🔴 Critical)
**What**: Virtual hub address prefix overlaps with connected VNet address spaces or on-premises ranges.
**Why**: Causes routing failures and connectivity issues across the virtual WAN.
**Check**: Compare `properties.addressPrefix` of each virtual hub against all connected VNet address spaces and known on-premises ranges.
**Remediation**: Redeploy the virtual hub with a non-overlapping address prefix (requires recreation).

---

### 🔵 Medium

#### M1: Overly Large Subnet Sizing
**What**: Subnets with /16 or /8 address space when the workload needs far fewer IPs.
**Why**: Wastes address space, reduces segmentation granularity, makes future growth harder.
**Check**: Flag subnets larger than /22 and check if the allocated space is proportional to the workload.
**Remediation**: Plan subnets based on workload needs. Use /24 to /27 for most workloads.

#### M2: Unused or Empty VNets
**What**: VNets with no subnets containing resources, no peering, and no gateways.
**Why**: Consumes address space; potential config drift artifact.
**Check**: VNets where all subnets have no connected NICs, service endpoints, or delegations.
**Remediation**: Delete if unused, or document if reserved for future use.

#### M3: Missing Service Endpoints or Private Endpoints on Subnets
**What**: Subnets accessing PaaS services (Storage, SQL, Key Vault) without service endpoints or private endpoints.
**Why**: Traffic goes over public internet instead of Azure backbone.
**Check**: Cross-reference subnet configurations with PaaS resources in the same subscription.
**Remediation**: Add service endpoints or (preferred) use private endpoints.

#### M4: Asymmetric Routing Risk
**What**: Route tables with routes that could cause return traffic to take a different path.
**Why**: Firewalls and NVAs drop asymmetric flows. Causes intermittent connectivity.
**Check**: Verify that forward and return paths are symmetric (both go through the same firewall/NVA).
**Tip**: Common in multi-NVA or multi-region designs. Check for routes that send traffic to different NVAs for different prefixes.

### 🟢 Low / Info

#### L1: VNet Naming Convention
**What**: Check VNet names against ALZ naming convention (`vnet-<workload>-<env>-<region>`).
**Why**: Consistency aids operations and automation.

#### L2: Subnet Naming Convention
**What**: Check subnet names follow pattern (`snet-<purpose>-<env>`).
**Why**: Consistent naming reduces confusion during incident response.

#### L3: Peering Naming Convention
**What**: Peering names should indicate both sides (e.g., `peer-hub-to-spoke-web`).

#### L4: Address Space Documentation
**What**: Is there an IPAM or address space plan documented?
**Why**: Without a plan, address space allocation becomes chaotic as the environment grows.
**Action**: Ask the user if they maintain an IPAM tool or spreadsheet.

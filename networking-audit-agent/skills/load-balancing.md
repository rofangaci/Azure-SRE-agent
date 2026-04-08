# Load Balancing Audit Checks

## Discovery

```bash
# List all load balancers
az graph query -q "Resources | where type =~ 'microsoft.network/loadbalancers' | project name, resourceGroup, location, sku=properties.sku.name, frontendCount=array_length(properties.frontendIPConfigurations), backendPoolCount=array_length(properties.backendAddressPools)" --first 100 --subscription <subId>

# List all application gateways
az graph query -q "Resources | where type =~ 'microsoft.network/applicationgateways' | project name, resourceGroup, location, sku=properties.sku, wafEnabled=properties.webApplicationFirewallConfiguration.enabled" --first 50 --subscription <subId>

# List all Front Door profiles
az graph query -q "Resources | where type =~ 'microsoft.cdn/profiles' or type =~ 'microsoft.network/frontdoors' | project name, resourceGroup, type, sku=properties.sku" --first 50 --subscription <subId>

# List all Traffic Manager profiles
az graph query -q "Resources | where type =~ 'microsoft.network/trafficmanagerprofiles' | project name, resourceGroup, routingMethod=properties.trafficRoutingMethod, monitorStatus=properties.monitorConfig.profileMonitorStatus" --first 50 --subscription <subId>
```

## Audit Checks

### 🔴 Critical

#### C1: Basic SKU Load Balancer in Production
**What**: Azure Load Balancer using Basic SKU.
**Why**: Basic LB has no SLA, no availability zone support, no NSG requirement on backend pool, and is being retired. Critical for reliability and security.
**Ref**: https://learn.microsoft.com/azure/load-balancer/skus
**Check**: `sku.name == 'Basic'`.
**Remediation**: Migrate to Standard SKU.
```bash
# Note: Basic to Standard migration requires recreation
# Use the Azure LB migration tool or manual recreation
az network lb create -g <rg> -n <lb-name> --sku Standard --subscription <subId>
```

#### C2: No Health Probe Configured
**What**: Load balancer backend pool has no health probe, or probe is misconfigured.
**Why**: Without health probes, traffic is sent to unhealthy backends — causes failures.
**Ref**: https://learn.microsoft.com/azure/load-balancer/load-balancer-custom-probe-overview
**Check**: Verify each LB rule references a health probe. Check probe protocol/port/path match the application.
```bash
az network lb probe list -g <rg> --lb-name <lb> --subscription <subId>
az network lb rule list -g <rg> --lb-name <lb> --subscription <subId> --query "[].{rule:name, probe:probe.id}"
```
**Remediation**: Create appropriate health probes.

#### C3: Application Gateway Without WAF
**What**: App Gateway deployed without WAF enabled, or WAF in detection-only mode on internet-facing workloads.
**Why**: No web application firewall protection against OWASP top 10 attacks.
**Ref**: https://learn.microsoft.com/azure/web-application-firewall/ag/ag-overview
**Check**: `properties.webApplicationFirewallConfiguration.enabled == false` or `firewallMode == 'Detection'`.
**Remediation**:
```bash
az network application-gateway waf-config set -g <rg> --gateway-name <appgw> --enabled true --firewall-mode Prevention --rule-set-version 3.2 --subscription <subId>
```

### 🟡 High

#### H1: Health Probe Using TCP Instead of HTTP(S)
**What**: Health probe checks TCP connectivity instead of an application health endpoint.
**Why**: TCP probe only verifies the port is open — the app could be in an error state but still accepting connections.
**Check**: Probe protocol is `Tcp` for HTTP/HTTPS workloads.
**Remediation**: Switch to HTTP(S) probe with a dedicated health endpoint (e.g., `/health`).

#### H2: Load Balancer Without Zone Redundancy
**What**: Standard LB frontend IP not configured as zone-redundant.
**Why**: Single zone failure takes down the load balancer.
**Ref**: https://learn.microsoft.com/azure/load-balancer/load-balancer-standard-availability-zones
**Check**: Frontend IP configuration `zones` property — should be `["1","2","3"]` or empty (zone-redundant by default for Standard).
**Remediation**: Recreate frontend IP as zone-redundant.

#### H3: Application Gateway Single Instance
**What**: App Gateway with `capacity: 1` or `minCapacity: 0` without autoscaling.
**Why**: Single point of failure and no capacity for traffic spikes.
**Check**: `sku.capacity == 1` and no autoscale configuration.
**Remediation**: Set minimum 2 instances, or enable autoscaling with min >= 2.
```bash
az network application-gateway update -g <rg> -n <appgw> --capacity 2 --subscription <subId>
```

#### H4: App Gateway V1 SKU
**What**: Application Gateway using v1 SKU (Standard or WAF, not Standard_v2 or WAF_v2).
**Why**: V1 lacks autoscaling, zone redundancy, performance improvements, and is on deprecation path.
**Ref**: https://learn.microsoft.com/azure/application-gateway/migrate-v1-v2
**Check**: `sku.tier` is `Standard` or `WAF` (not `Standard_v2` or `WAF_v2`).
**Remediation**: Migrate to v2 SKU.

#### H5: Front Door Without WAF Policy
**What**: Azure Front Door deployed without a WAF policy attached.
**Why**: Internet-facing entry point without web application firewall protection.
**Ref**: https://learn.microsoft.com/azure/web-application-firewall/afds/afds-overview
**Check**: Front Door security policies — verify WAF policy is associated.
**Remediation**: Create and attach a WAF policy with managed rule sets.

#### H6: Traffic Manager with Single Endpoint
**What**: Traffic Manager profile with only one enabled endpoint.
**Why**: No failover capability — defeats the purpose of Traffic Manager.
**Check**: Count of enabled endpoints < 2.
**Remediation**: Add a secondary endpoint for failover.

### 🔵 Medium

#### M1: Session Persistence on Stateless Workloads
**What**: Session affinity (source IP or cookie) enabled on workloads that should be stateless.
**Why**: Causes uneven load distribution. Backend failures affect specific users.
**Check**: LB rules with `loadDistribution != 'Default'` or App GW with cookie affinity.
**Recommendation**: Ask user if the workload is stateful. If not, disable affinity.

#### M2: Idle Timeout Configuration
**What**: Load balancer idle timeout set to default 4 minutes for long-running connections.
**Why**: Can cause connection drops for applications with long-lived connections.
**Check**: `idleTimeoutInMinutes` on LB rules.
**Remediation**: Increase for long-lived connections (up to 30 min), or use TCP keepalive.

#### M3: Missing Diagnostic Logs
**What**: Load balancer, App Gateway, or Front Door without diagnostic settings.
**Why**: No visibility into traffic, errors, or performance.
**Check**:
```bash
az monitor diagnostic-settings list --resource <resource-id> --subscription <subId>
```
**Remediation**: Enable diagnostic logs to Log Analytics workspace.

#### M4: Non-Standard Health Probe Intervals
**What**: Health probe interval too high (> 15s) or too low (< 5s).
**Why**: High interval = slow failover. Low interval = unnecessary load on backends.
**Check**: Default is usually 15s with 2 unhealthy threshold = 30s to detect failure.
**Recommendation**: 5-10s interval, 2 unhealthy threshold for production workloads.

### 🟢 Low / Info

#### L1: Load Balancing Decision Matrix
Report which load balancing services are in use and validate against the Azure decision tree.
**Ref**: https://learn.microsoft.com/azure/architecture/guide/technology-choices/load-balancing-overview
| Traffic Type | Recommended Service | Global? |
|-------------|-------------------|---------| 
| HTTP(S) external | Front Door + App GW | Yes + Regional |
| HTTP(S) internal | App GW or Internal LB | Regional |
| Non-HTTP external | LB Standard + Traffic Manager | Regional + Global |
| Non-HTTP internal | LB Standard Internal | Regional |

#### L2: Naming Conventions
Check names follow patterns: `lb-<workload>-<env>`, `agw-<workload>-<env>`, `fd-<workload>`.

#### L3: Tag Compliance
Verify required tags (environment, owner, cost-center) on all load balancing resources.

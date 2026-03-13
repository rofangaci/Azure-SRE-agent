# Audit Domain Reference

## Domain 1: NSG & Firewall

### Checks
- NSG associated with all subnets (except exempted: AzureFirewallSubnet, GatewaySubnet)
- No allow-all inbound rules (0.0.0.0/0 on any port)
- No orphaned NSGs (not attached to any subnet or NIC)
- Deny-all-inbound as last rule
- No overly broad port ranges (e.g., 1-65535)
- Azure Firewall rules reviewed for least privilege
- Firewall diagnostic logging enabled

### Key References
- https://learn.microsoft.com/azure/virtual-network/network-security-groups-overview
- https://learn.microsoft.com/azure/firewall/overview

---

## Domain 2: VNet & Topology

### Checks
- No overlapping address spaces across peered VNets
- Hub-spoke topology validated (hub VNet identified)
- VNet peering status is "Connected"
- Subnet address space utilization (warn if >80%)
- Route tables associated with subnets
- No default 0.0.0.0/0 route to Internet on sensitive subnets

### Key References
- https://learn.microsoft.com/azure/virtual-network/virtual-networks-overview
- https://learn.microsoft.com/azure/architecture/networking/architecture/hub-spoke

---

## Domain 3: Load Balancing

### Checks
- Standard SKU (not Basic) for production workloads
- Health probes configured and responsive
- Backend pool has healthy instances
- Cross-zone load balancing enabled where applicable
- Application Gateway WAF policy attached (if AGW present)

### Key References
- https://learn.microsoft.com/azure/load-balancer/load-balancer-overview
- https://learn.microsoft.com/azure/application-gateway/overview

---

## Domain 4: DNS & Private Endpoints

### Checks
- Private endpoints in approved state
- Private DNS zones linked to appropriate VNets
- DNS resolution returns private IP for PE-enabled resources
- No public FQDN exposure for PE-only resources

### Key References
- https://learn.microsoft.com/azure/private-link/private-endpoint-overview
- https://learn.microsoft.com/azure/private-link/private-endpoint-dns

---

## Domain 5: PaaS Networking

### Checks
- Storage accounts: public network access disabled or restricted
- SQL Server: public network access denied, PE configured
- Key Vault: network ACLs configured, PE preferred
- App Service: VNet integration, access restrictions
- Cosmos DB: public access disabled, PE configured

### Key References
- https://learn.microsoft.com/azure/storage/common/storage-network-security
- https://learn.microsoft.com/azure/azure-sql/database/connectivity-architecture

---

## Domain 6: DNS Strategy

### Checks
- Custom DNS servers configured on VNets (if hybrid)
- Conditional forwarders for on-premises domains
- Azure DNS Private Resolver deployed (if required)
- DNS forwarding rules validated

### Key References
- https://learn.microsoft.com/azure/dns/private-dns-overview
- https://learn.microsoft.com/azure/dns/dns-private-resolver-overview

---

## Domain 7: Perimeter Security

### Checks
- DDoS Protection Plan associated with VNets containing public IPs
- Azure Bastion deployed for management access (no public IPs on VMs)
- NAT Gateway for outbound connectivity (instead of public IPs on VMs)
- No direct RDP/SSH from Internet allowed

### Key References
- https://learn.microsoft.com/azure/ddos-protection/ddos-protection-overview
- https://learn.microsoft.com/azure/bastion/bastion-overview

---

## Domain 8: Network Management

### Checks
- Network Watcher enabled in all active regions
- Firewall Manager configured (if multi-hub)
- Azure Virtual Network Manager for topology enforcement
- NSG flow logs enabled and flowing to Log Analytics
- Route Server configured (if required for NVA routing)

### Key References
- https://learn.microsoft.com/azure/network-watcher/network-watcher-monitoring-overview
- https://learn.microsoft.com/azure/firewall-manager/overview

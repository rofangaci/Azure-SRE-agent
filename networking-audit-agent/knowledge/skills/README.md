# Networking Audit Skill Files

These files define the agent's audit capabilities across 8 networking domains + the main skill orchestration + ALZ deployment baseline.

## How to Use

Upload all files in this directory to the agent's **Knowledge** section at [sre.azure.com](https://sre.azure.com). The agent will use these as its operational playbooks during audits.

## Files

| File | Domain | Description |
|------|--------|-------------|
| `SKILL.md` | All | Main skill orchestration — workflows, output formats, behavioral rules |
| `nsg-audit.md` | NSG & Firewall | Overly permissive rules, open mgmt ports, any-any, flow logs |
| `vnet-topology.md` | VNet & Topology | Hub-spoke, vWAN, peering, UDRs, VPN/ER gateways |
| `load-balancing.md` | Load Balancing | LB SKU, health probes, App GW WAF, Front Door, Traffic Manager |
| `dns-private-endpoints.md` | DNS & Private Endpoints | PE connectivity, DNS zone linkage, public exposure |
| `paas-networking.md` | PaaS Networking | Private Link, Service Endpoints, PaaS firewall rules |
| `dns-strategy.md` | DNS Strategy | Private Resolver, hybrid DNS, conditional forwarding |
| `perimeter-security.md` | Perimeter Security | DDoS Protection, Azure Bastion, NAT Gateway |
| `network-management.md` | Network Management | Firewall Manager, AVNM, Network Watcher, Route Server |
| `alz-deployment-baseline.md` | ALZ Baseline | VBD deployment checklist for architecture assessments |

## For Customers

When deploying this agent to a new tenant:
1. Upload all `.md` files in this directory to the agent's knowledge base
2. The agent persona (`knowledge/agent-persona.md`) references these skills
3. The agent will automatically load the relevant skill file based on the audit request

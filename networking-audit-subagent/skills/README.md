# Networking Audit Skill Files

These files define the agent's audit capabilities across 8 networking domains + the main skill orchestration + ALZ deployment baseline.

## How to Use

### Option A: Load via Plugin Marketplace (Recommended)
The skills are now packaged as a marketplace plugin at `plugins/networking-audit/`. Load them via the SRE Agent UI:
1. Navigate to **Plugins**
2. Add the `networking-audit-skill` plugin from the marketplace
3. All 8 audit domains + orchestration logic are automatically available

### Option B: Upload Directly to Agent (Legacy)
Upload all files in this directory directly to the agent's **Skills** section at [sre.azure.com](https://sre.azure.com). The agent will use these as its operational playbooks during audits.

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
1. **Do NOT upload skills through Knowledge/Memory** — use Plugin Marketplace or Skill Builder only (see Options A & B above)
2. The agent persona (`../prompts/agent-system-prompt.md`) contains the networking specialist instructions
3. The agent will automatically load the relevant skill file based on the audit request

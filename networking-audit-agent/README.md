# Networking Audit Agent

Azure network architecture and service audit specialist powered by [Azure SRE Agent](https://sre.azure.com). Performs comprehensive network security audits and architecture assessments across Azure environments.

## Features

- **130+ automated checks** across 8 networking audit domains
- **3 workflow modes**: Quick Audit, Deep Audit, Architecture Assessment
- Azure Landing Zone (ALZ) networking pillar compliance
- Well-Architected Framework (WAF) reliability and security assessments
- Ready-to-run remediation commands for every finding

## Repository Structure

```
networking-audit-agent/
├── infra/                          # Infrastructure as Code (Bicep)
│   ├── main.bicep                  # Agent managed identity
│   ├── rbac.bicep                  # RBAC role assignments
│   └── parameters/
│       ├── dev.bicepparam          # Dev environment parameters
│       └── prod.bicepparam         # Prod environment parameters
├── knowledge/                      # Agent knowledge documents
│   ├── agent-persona.md            # Agent system prompt / persona
│   ├── agent-overview.md           # Agent capabilities and behavior
│   ├── audit-domains.md            # Audit domain reference (130+ checks)
│   └── skills/                     # Audit skill playbooks (10 files)
│       ├── SKILL.md                # Main skill orchestration & workflows
│       ├── nsg-audit.md            # NSG & Firewall checks
│       ├── vnet-topology.md        # VNet, hub-spoke, vWAN, gateways
│       ├── load-balancing.md       # LB, App GW, Front Door, Traffic Mgr
│       ├── dns-private-endpoints.md # Private endpoints & DNS records
│       ├── paas-networking.md      # PaaS network isolation & exposure
│       ├── dns-strategy.md         # DNS architecture & hybrid resolution
│       ├── perimeter-security.md   # DDoS, Bastion, NAT Gateway
│       ├── network-management.md   # Firewall Mgr, AVNM, Network Watcher
│       └── alz-deployment-baseline.md # ALZ VBD checklist reference
├── scripts/                        # Helper scripts (Bash + PowerShell)
│   ├── deploy.sh / deploy.ps1     # Deploy infrastructure
│   ├── setup-rbac.sh / .ps1       # Configure RBAC for target subscriptions
│   └── upload-knowledge.sh / .ps1 # Upload knowledge docs to the agent
├── docs/
│   ├── CICD-SETUP.md              # GitHub Actions secrets & OIDC setup
│   └── SECURITY.md                # RBAC roles, permissions & security model
├── .github/workflows/
│   └── deploy.yml                  # CI/CD pipeline
├── CHANGELOG.md
└── LICENSE                         # MIT
```

## Quick Start

### Prerequisites

- Azure subscription in the target tenant
- [Azure CLI](https://aka.ms/installazurecli) installed and authenticated
- [jq](https://jqlang.github.io/jq/) installed (Bash scripts only)
- Contributor role on the target resource group
- Access to [sre.azure.com](https://sre.azure.com)

### Step 1: Deploy Infrastructure

Deploys the user-assigned managed identity that the agent will use.

> **Supported Regions:** Azure SRE Agent is currently available in **3 regions only**. You **must** deploy to one of these:
>
> | Region | Location code |
> |--------|---------------|
> | East US 2 | `eastus2` |
> | Sweden Central | `swedencentral` |
> | Australia East | `australiaeast` |
>
> Deploying to an unsupported region will fail. The deploy scripts validate this automatically.

**Bash:**
```bash
./scripts/deploy.sh prod <subscription-id> <resource-group> [location]
# location defaults to eastus2 if omitted
```

**PowerShell:**
```powershell
./scripts/deploy.ps1 -Environment prod -SubscriptionId "<sub-id>" -ResourceGroup "<rg>" -Location "eastus2"
```

### Step 2: Create the Agent

1. Go to [sre.azure.com](https://sre.azure.com)
2. Select your subscription in the target tenant
3. Create a new agent named `networking-audit-agent`
4. Assign the user-assigned managed identity created in Step 1
5. Upload `knowledge/agent-persona.md` as the agent's persona/system prompt

### Step 3: Configure RBAC

Grants the agent Reader + Network Contributor access to subscriptions it will audit. See [docs/SECURITY.md](docs/SECURITY.md) for role justification and least-privilege alternatives.

**Bash:**
```bash
./scripts/setup-rbac.sh <principal-id> <subscription-id-1> [subscription-id-2 ...]
```

**PowerShell:**
```powershell
./scripts/setup-rbac.ps1 -PrincipalId "<principal-id>" -SubscriptionIds "<sub-1>", "<sub-2>"
```

### Step 4: Load Skills from Marketplace Plugin

The networking audit skills are now available as a **marketplace plugin** packaged under `plugins/networking-audit/`. 

**Option A: Load via Plugin Marketplace (Recommended)**
1. In the SRE Agent UI, navigate to **Plugins**
2. Add the `networking-audit-skill` plugin from the marketplace
3. The plugin automatically loads all 8 audit domain skills + orchestration logic

**Option B: Upload Knowledge & Skills Manually (Legacy)**
For environments where plugin marketplace is not available, use the upload scripts to inject skills directly into the knowledge base:

**Bash:**
```bash
./scripts/upload-knowledge.sh <agent-resource-id>
```

**PowerShell:**
```powershell
./scripts/upload-knowledge.ps1 -AgentResourceId "<agent-resource-id>"
```

Or upload manually: **sre.azure.com → Agent → Knowledge → Upload** (upload all `.md` files from both `knowledge/` and `knowledge/skills/`)

> **Difference:** The plugin marketplace approach (Option A) provides versioning, dependency management, and cleaner separation of concerns. The manual script approach (Option B) directly injects skills into the knowledge base and works in all environments. Both achieve the same end result: the agent gains access to all 8 audit domain skills.

### Step 5: Connect Repository

In the SRE Agent UI, connect this GitHub repository so the agent can reference IaC, scripts, and documentation during investigations.

## CI/CD Pipeline

The included GitHub Actions workflow validates and deploys Bicep templates automatically. See [docs/CICD-SETUP.md](docs/CICD-SETUP.md) for setup instructions including:

- Required GitHub secrets (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `AZURE_RESOURCE_GROUP`)
- OIDC federated credential setup (no stored secrets)
- GitHub Environments configuration for dev/prod

## Audit Domains

| # | Domain | Examples |
|---|--------|----------|
| 1 | NSG & Firewall | Rule hygiene, deny-all defaults, orphaned NSGs |
| 2 | VNet & Topology | Address space overlaps, peering, hub-spoke |
| 3 | Load Balancing | Health probes, SKU alignment, cross-zone |
| 4 | DNS & Private Endpoints | PE approval state, DNS zone linkage |
| 5 | PaaS Networking | Public access controls, service restrictions |
| 6 | DNS Strategy | Custom DNS, conditional forwarders, Private Resolver |
| 7 | Perimeter Security | DDoS Protection, Bastion, NAT Gateway |
| 8 | Network Management | Firewall Manager, AVNM, Network Watcher |

## Security

See [docs/SECURITY.md](docs/SECURITY.md) for:
- Required RBAC roles and justification
- Least-privilege alternatives (Reader-only mode)
- Scope recommendations (subscription vs resource group vs management group)
- Data access boundaries (control plane only, no data plane)
- Audit trail and monitoring guidance

## Contributing

1. Fork this repository
2. Create a feature branch
3. Submit a pull request

## License

[MIT](LICENSE)

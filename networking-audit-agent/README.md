# Networking Audit Agent

Azure network architecture and service audit specialist powered by [Azure SRE Agent](https://sre.azure.com). Performs comprehensive network security audits and architecture assessments across Azure environments.

## Scope

This document is for **standalone mode** only (dedicated networking audit agent).

For mode selection (standalone vs subagent), use the master guide at [../README.md](../README.md).

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
│   ├── agent-overview.md           # Agent capabilities and behavior
│   └── audit-domains.md            # Audit domain reference (130+ checks)
├── prompts/                        # System prompt source files
│   └── agent-system-prompt.md      # Agent persona/system prompt text
├── skills/                         # Audit skill playbooks (10 files)
│   ├── SKILL.md                    # Main skill orchestration & workflows
│   ├── nsg-audit.md                # NSG & Firewall checks
│   ├── vnet-topology.md            # VNet, hub-spoke, vWAN, gateways
│   ├── load-balancing.md           # LB, App GW, Front Door, Traffic Mgr
│   ├── dns-private-endpoints.md    # Private endpoints & DNS records
│   ├── paas-networking.md          # PaaS network isolation & exposure
│   ├── dns-strategy.md             # DNS architecture & hybrid resolution
│   ├── perimeter-security.md       # DDoS, Bastion, NAT Gateway
│   ├── network-management.md       # Firewall Mgr, AVNM, Network Watcher
│   └── alz-deployment-baseline.md  # ALZ VBD checklist reference
├── scripts/                        # Helper scripts (Bash + PowerShell)
│   ├── deploy.sh / deploy.ps1     # Deploy infrastructure
│   ├── setup-rbac.sh / .ps1       # Configure RBAC for target subscriptions
│   └── archive/                    # Archived scripts (not part of active flow)
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
5. Copy `prompts/agent-system-prompt.md` into the agent's persona/system prompt field

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

### Step 4: Load Skills

Skills are not loaded through Knowledge Sources. Use one of these options:

**Option A: Plugin Marketplace (Recommended)**
1. Open **Plugins** in the SRE Agent UI
2. Add `networking-audit-skill`
3. Confirm the skill is available to the agent

**Option B: Skill Builder Upload**
1. Go to **Builder -> Skills -> Create Skill -> Upload**
2. Upload all `.md` files from `skills/` (except `skills/README.md`)
3. Attach required tools from `skills/metadata.yaml`

> **Note:** `prompts/agent-system-prompt.md` is the system prompt source used in Step 2. Skills in `skills/` are operational playbooks and should be loaded through Plugin Marketplace or Skill Builder, not Knowledge Sources.

### Step 5: Optional Static Knowledge

Knowledge Sources are optional for standalone mode and should contain only static references:

- `knowledge/agent-overview.md`
- `knowledge/audit-domains.md`
- Optional ALZ architecture/reference docs

Do **not** upload `prompts/agent-system-prompt.md` as Knowledge.

The previous knowledge-upload scripts are archived under `scripts/archive/` and not part of the active setup flow.

### Step 6: Connect Repository

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

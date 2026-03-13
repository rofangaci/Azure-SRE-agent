# Networking Audit Agent

Azure network security and architecture specialist powered by [Azure SRE Agent](https://sre.azure.com). Performs comprehensive network security audits and architecture assessments across Azure environments.

## Features

- **130+ automated checks** across 8 networking audit domains
- **3 workflow modes**: Quick Audit, Deep Audit, Architecture Assessment
- Azure Landing Zone (ALZ) networking pillar compliance
- Well-Architected Framework (WAF) reliability and security assessments

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
│   └── audit-domains.md            # Audit domain reference
├── scripts/                        # Helper scripts
│   ├── deploy.sh                   # Deploy infrastructure
│   ├── setup-rbac.sh               # Configure RBAC for target subscriptions
│   └── upload-knowledge.sh         # List knowledge docs for upload
└── .github/
    └── workflows/
        └── deploy.yml              # CI/CD pipeline
```

## Deploying to a New Tenant

### Prerequisites

- Azure subscription in the target tenant
- Azure CLI installed and authenticated (`az login --tenant <tenant-id>`)
- Contributor role on the target resource group
- Access to [sre.azure.com](https://sre.azure.com)

### Step 1: Deploy Infrastructure

```bash
# Deploy managed identity and supporting resources
./scripts/deploy.sh prod <subscription-id> <resource-group>
```

### Step 2: Create the Agent

1. Go to [sre.azure.com](https://sre.azure.com)
2. Select your subscription in the target tenant
3. Create a new agent named `networking-audit-agent`
4. Assign the user-assigned managed identity created in Step 1

### Step 3: Configure RBAC

```bash
# Grant the agent access to subscriptions it needs to audit
./scripts/setup-rbac.sh <principal-id> <subscription-id-1> <subscription-id-2>
```

### Step 4: Upload Knowledge

Upload the documents in `knowledge/` to the agent via the SRE Agent UI or connect this repository for code context.

### Step 5: Connect Repository

In the SRE Agent UI, connect this GitHub repository so the agent can reference code, IaC, and documentation during investigations.

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

## Contributing

1. Fork this repository
2. Create a feature branch
3. Submit a pull request

## License

MIT

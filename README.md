# Azure SRE Networking Audit Packages

This workspace contains two separate delivery modes for networking audit capabilities.

## Choose Your Mode

| If you want to... | Use this folder |
|---|---|
| Run a dedicated networking-only agent end-to-end | `networking-audit-agent/` |
| Add networking expertise to an existing broad SRE agent using custom-agent/subagent handoff | `networking-audit-subagent/` |

## What Is Different

| Area | Standalone mode | Subagent mode |
|---|---|---|
| Main agent persona | Networking-focused persona on the main agent | Keep main agent generic; networking persona only on custom agent/subagent |
| Skills | Optional but recommended | Required for networking specialization |
| Knowledge upload | Optional static docs for the standalone agent | Optional static docs for reference; do not upload persona as knowledge |
| Managed identity and RBAC | Agent instance MI for standalone agent | Same instance MI used by main + subagents; RBAC must cover delegated actions |

## Prerequisites

| Standalone mode | Subagent mode |
|---|---|
| Azure subscription in target tenant | Existing SRE agent instance (already deployed on sre.azure.com) |
| Azure CLI installed and authenticated | Access to sre.azure.com Builder |
| Contributor role on target resource group | Same Azure subscription/tenant |
| Access to sre.azure.com | Same managed identity RBAC scope |
| jq installed (Bash scripts only) | |

**Note:** Standalone mode deploys the agent and infrastructure from scratch. Subagent mode adds networking expertise to an existing SRE agent and requires no infrastructure deployment.

## Start Here

1. For standalone deployment: open `networking-audit-agent/README.md`
2. For subagent deployment: open `networking-audit-subagent/README.md`


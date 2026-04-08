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

## Start Here

1. For standalone deployment: open `networking-audit-agent/README.md`
2. For subagent deployment: open `networking-audit-subagent/README.md`


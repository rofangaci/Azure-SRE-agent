# Security & RBAC Guide

This document explains the permissions the Networking Audit Agent requires and the security model.

## Managed Identity

The agent uses a **User-Assigned Managed Identity** (`<agent-name>-mi`) for authentication. This is preferred over service principals because:

- No credentials to rotate or manage
- Lifecycle is tied to the Azure resource
- Supports Azure RBAC natively
- Auditable via Azure AD sign-in logs

## Required RBAC Roles

The agent needs two roles on each subscription it audits:

| Role | Role Definition ID | Purpose | Scope |
|---|---|---|---|
| **Reader** | `acdd72a7-3385-48ef-bd42-f606fba81ae7` | Read all resource configurations for audit checks | Subscription |
| **Network Contributor** | `4d97b98b-1d4f-4787-a291-c67834d212e7` | Read network-specific properties; optionally apply remediation (with approval) | Subscription |

### Why Reader?

The agent inspects resource configurations across all resource types (Storage, SQL, Key Vault, etc.) to validate their network security posture. Reader provides read-only access to all resources.

### Why Network Contributor?

- **Read access** to detailed network resources (NSGs, route tables, VNets, peerings, private endpoints, DNS zones) that may not be fully visible with Reader alone
- **Write access** for agent-recommended remediations (e.g., adding NSG rules, modifying route tables) — **always requires explicit user approval**

### Least Privilege Alternative

If the customer's security policy prohibits Network Contributor, a **read-only** configuration is possible:

```bash
# Reader only — agent can audit but cannot remediate
az role assignment create \
  --assignee-object-id <principal-id> \
  --assignee-principal-type ServicePrincipal \
  --role "Reader" \
  --scope "/subscriptions/<subscription-id>"
```

In this mode, the agent will still produce remediation commands but cannot execute them directly. The customer must run them manually.

## Scope Recommendations

| Scenario | Recommended Scope |
|---|---|
| Single subscription audit | Subscription-level RBAC |
| Multi-subscription audit | Each target subscription |
| Specific resource group only | Resource group-level RBAC (limits visibility) |
| Management group wide | Management group-level RBAC (broadest) |

### Scoping to a Resource Group

```bash
az role assignment create \
  --assignee-object-id <principal-id> \
  --assignee-principal-type ServicePrincipal \
  --role "Reader" \
  --scope "/subscriptions/<sub-id>/resourceGroups/<rg-name>"
```

> **Note:** Resource-group scoping limits the agent's visibility. Cross-resource-group checks (e.g., VNet peering between RGs, Private DNS zone links) may produce incomplete results.

## Data Access

The agent does **NOT** have access to:
- Data plane (blob contents, database records, key vault secrets)
- Azure AD directory (user/group management)
- Billing or cost data

The agent only reads **control plane** (ARM) resource configurations.

## Audit Trail

All agent actions are logged:
- **Azure Activity Log** — ARM read operations from the managed identity
- **Azure AD Sign-in Logs** — Authentication events for the managed identity
- **SRE Agent UI** — Full conversation history and tool invocations at sre.azure.com

## Security Best Practices

1. **Scope minimally** — Only grant access to subscriptions that need auditing
2. **Review periodically** — Audit the managed identity's role assignments quarterly
3. **Use Reader-only** if remediation via the agent is not needed
4. **Monitor sign-ins** — Set up alerts for unexpected managed identity activity
5. **Tag the identity** — Apply ownership and project tags for governance

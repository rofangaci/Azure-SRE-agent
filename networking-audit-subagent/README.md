# Networking Audit Subagent Mode

Use this package when you already have a broader SRE main agent and want to add focused networking audit expertise.

## Architecture

- Main agent stays generic for broad operations.
- Networking custom agent/subagent handles networking-only investigations.
- Networking skills are attached to the networking custom agent.
- Main agent hands off networking requests to the networking custom agent.

## Folder Contents

- `skills/`: Networking skill files (SKILL.md + domain files + metadata)
- `prompts/agent-system-prompt.md`: Persona text for the networking custom agent system prompt
- `knowledge/agent-overview.md`, `knowledge/audit-domains.md`: Optional static reference docs

## Setup

### Step 1: Create or Use Main Agent

Create or select your existing main SRE agent in sre.azure.com.

### Step 2: Grant RBAC on Agent Instance Managed Identity

Custom agents/subagents use the same managed identity as the main agent instance.

Grant roles based on intended actions:
- Audit-only: Reader
- Remediation/write actions: Network Contributor (or narrower write roles)

### Step 3: Create Networking Custom Agent

In Builder -> Agent Canvas:
1. Create custom agent (for example: `network_audit_specialist`)
2. Set system prompt using `prompts/agent-system-prompt.md`
3. Add handoff description covering VNet, NSG, Firewall, DNS, Private Endpoints, ALZ networking checks
4. Restrict this custom agent to networking skills only

### Step 4: Load Skills

Option A (recommended): Plugin Marketplace
1. Add `networking-audit-skill` plugin
2. Allow that skill for the networking custom agent

Option B: Manual Skill Builder upload
1. In Builder -> Skills -> Create Skill -> Upload
2. Upload files from `skills/`
3. Attach tools listed in `skills/metadata.yaml`

### Step 5: Optional Static Knowledge

If needed, upload only static references to Memory & Knowledge:
- `knowledge/agent-overview.md`
- `knowledge/audit-domains.md`

Do not upload `prompts/agent-system-prompt.md` as a knowledge file; use it as the custom agent system prompt.

### Step 6: Configure Main-Agent Handoff

Add main-agent routing instructions such as:
- Delegate networking audits, ALZ networking, DNS/private endpoint, and perimeter security requests to `network_audit_specialist`
- Keep non-networking investigations on main agent
- Ask one clarifying question when scope is ambiguous, then hand off

## Notes

- This mode is designed for specialization through delegation.
- If you need strict permission isolation by domain, use separate agent instances (each with its own managed identity and RBAC scope).

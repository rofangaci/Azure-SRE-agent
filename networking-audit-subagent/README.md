# Networking Audit Subagent Mode

Use this package when you already have a broader SRE main agent and want to add focused networking audit expertise.

## Architecture

- Main agent stays generic for broad operations.
- Networking custom agent/subagent handles networking-only investigations.
- Networking skills are attached to the networking custom agent.
- Main agent hands off networking requests to the networking custom agent.

## Folder Contents

- `HANDOFF-SETUP.md`: Complete configuration examples (system prompts, YAML templates, testing guide)
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

The main agent (orchestrator) needs routing intelligence to know when to delegate to your networking custom agent. Configure this in the main agent's **Instructions** field (system prompt).

#### In the main SRE Agent UI:

1. Go to **Builder → Agent Canvas** (your main agent, not the networking custom agent)
2. Open the main agent configuration
3. Go to the **Instructions** tab
4. Add networking handoff routing to the instructions. Use this template:

```
[Existing main agent instructions...]

## Agent Delegation Rules

When users ask about any of the following, delegate to the networking specialist:
- Network architecture, VNet topology, hub-spoke, vWAN, or gateway design
- NSG rules, Azure Firewall, Application Gateway, or load balancing
- Private endpoints, DNS resolution, or hybrid DNS connectivity
- Perimeter security, DDoS protection, Bastion, NAT Gateway
- Azure Landing Zone (ALZ) networking pillar compliance
- Network security audit or architecture assessment
- Any Azure networking service: VNet, ExpressRoute, Azure Bastion, APIM, Front Door, Traffic Manager

Route these requests to: @network_audit_specialist (created in Step 3)

For ambiguous requests (e.g., "I have a connectivity issue"): Ask one clarifying question to determine if it's networking-related before delegating.

Keep other operational requests (VM, database, storage, security, cost) on the main agent.
```

5. Save/Apply the configuration
6. Test in the Agent Canvas **Test playground** with networking-related questions to verify handoff triggers

#### How handoff works (context sharing):

- When main agent hands off to networking custom agent, the full conversation history is preserved
- Networking custom agent sees the user's original question + all previous context
- After the custom agent completes its investigation, it can hand back to main agent or hand off to another specialist
- Single conversation thread throughout — no context loss

#### Manual invocation (optional):

Users can also bypass automatic handoff and invoke directly:
1. Type `/agent` in chat
2. Select `network_audit_specialist`
3. Ask networking question

This is useful when users know they need networking expertise immediately.

## Notes

- This mode is designed for specialization through delegation.
- If you need strict permission isolation by domain, use separate agent instances (each with its own managed identity and RBAC scope).
- For complex handoff chains (e.g., incident triage → networking specialist → approval router), see [SRE Agent incident response documentation](https://learn.microsoft.com/azure/sre-agent/incident-response).

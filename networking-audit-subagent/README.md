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

For this step, open `HANDOFF-SETUP.md` and copy/paste the exact values from:
- **Networking Custom Agent Configuration**
- **Instructions Field (Networking Custom Agent)**

In Builder -> Agent Canvas:
1. Select **Create -> Custom Agent** and set name to `network_audit_specialist`
2. Set **Instructions** using the text in `prompts/agent-system-prompt.md` (or use the expanded version in `HANDOFF-SETUP.md`)
3. Set **Handoff Description** using the exact text in `HANDOFF-SETUP.md` -> **Networking Custom Agent Configuration**
4. Set tools/skills scope to networking only (do not attach unrelated domain skills)
5. Save/Apply

### Step 4: Load Skills

For details and examples, see `skills/README.md`.

Option A (recommended): Plugin Marketplace
1. Add `networking-audit-skill` plugin
2. Allow that skill for the networking custom agent

Option B: Manual Skill Builder upload
1. In Builder -> Skills -> Create Skill -> Upload
2. Upload files from `skills/`
3. Attach tools listed in `skills/metadata.yaml`

### Step 5: Optional Static Knowledge

For upload boundaries and examples, see `knowledge/README.md` and `prompts/README.md`.

If needed, upload only static references to Memory & Knowledge:
- `knowledge/agent-overview.md`
- `knowledge/audit-domains.md`

Do not upload `prompts/agent-system-prompt.md` as a knowledge file; use it as the custom agent system prompt.

### Step 6: Configure Main-Agent Handoff

The main agent (orchestrator) needs routing intelligence to know when to delegate to your networking custom agent.

For this step, open `HANDOFF-SETUP.md` and copy/paste from:
- **Main Agent System Prompt (Orchestrator)**
- **Testing the Handoff**

In the main SRE Agent UI:
1. Go to **Builder -> Agent Canvas** (main agent)
2. Open **Instructions**
3. Paste the routing template from `HANDOFF-SETUP.md` -> **Main Agent System Prompt (Orchestrator)**
4. Save/Apply
5. Run validation in `HANDOFF-SETUP.md` -> **Testing the Handoff**

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

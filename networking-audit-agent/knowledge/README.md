# Knowledge Base

This folder contains optional static reference documentation for the networking audit agent.

## What's Here

- `agent-overview.md`: High-level description of networking audit agent capabilities and scope
- `audit-domains.md`: Reference documentation for the 130+ networking audit checks (checksum by domain)

## How to Use

Upload these files to the SRE agent's **Knowledge Sources** / **Memory & Knowledge** section:

1. Go to **sre.azure.com → [Your Agent] → Knowledge**
2. Upload the `.md` files from this folder
3. These become searchable reference material during agent operations

**Optional**: Upload additional static reference docs (network architecture diagrams, compliance frameworks, ALZ deployment guides, etc.) to enrich the knowledge base.

## What NOT to Put Here

- ❌ **System prompts** — stored in `../prompts/` instead
- ❌ **Skill playbooks** — loaded via Plugin Marketplace or Skill Builder UI, not Knowledge Sources
- ❌ **Agent persona files** — use `../prompts/agent-system-prompt.md` as the system prompt source

## References

For more details on knowledge management, see [SRE Agent Custom Agents - Knowledge base management](https://learn.microsoft.com/azure/sre-agent/sub-agents#knowledge-base-management)

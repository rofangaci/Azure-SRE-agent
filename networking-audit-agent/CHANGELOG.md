# Changelog

All notable changes to the Networking Audit Agent repository are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.2.0] - 2026-03-14

### Added
- 10 Networking Audit Skill playbooks under `knowledge/skills/` (2,300+ lines)
- Skills README with upload instructions (`knowledge/skills/README.md`)
- Supported regions table in README Quick Start (Step 1)
- Skills mention in README Step 4 with importance callout

### Fixed
- `upload-knowledge.sh` now scans both `knowledge/*.md` and `knowledge/skills/*.md`
- `upload-knowledge.ps1` now uses `-Recurse` to include skill files
- Deploy scripts now pass user-provided location to Bicep (overrides `.bicepparam` default)

## [1.0.0] - 2026-03-13

### Added
- Initial repository scaffold
- Bicep IaC for managed identity deployment (`infra/main.bicep`)
- RBAC role assignment template (`infra/rbac.bicep`)
- Environment parameter files for dev and prod
- Agent persona/system prompt (`knowledge/agent-persona.md`)
- Agent overview and 8 audit domain reference docs
- Bash deployment scripts with prerequisite validation
- PowerShell deployment scripts for Windows users
- GitHub Actions CI/CD workflow with OIDC authentication
- CI/CD setup guide (`docs/CICD-SETUP.md`)
- Security and RBAC documentation (`docs/SECURITY.md`)
- MIT License

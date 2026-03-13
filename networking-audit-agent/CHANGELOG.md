# Changelog

All notable changes to the Networking Audit Agent repository are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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

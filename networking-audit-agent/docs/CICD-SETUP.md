# CI/CD Setup Guide

This guide explains how to configure the GitHub Actions workflow for automated infrastructure deployment.

## Required GitHub Secrets

Go to your GitHub repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret** and add:

| Secret Name | Description | Example |
|---|---|---|
| `AZURE_CLIENT_ID` | App registration (service principal) client ID for OIDC login | `12345678-abcd-1234-abcd-123456789012` |
| `AZURE_TENANT_ID` | Azure AD tenant ID | `87654321-dcba-4321-dcba-210987654321` |
| `AZURE_SUBSCRIPTION_ID` | Target subscription ID | `aaaabbbb-cccc-dddd-eeee-ffffgggghhhh` |
| `AZURE_RESOURCE_GROUP` | Target resource group name | `rg-networking-audit` |

## Setting Up OIDC Authentication (Federated Credentials)

The workflow uses OpenID Connect (OIDC) — no secrets/passwords stored in GitHub.

### Step 1: Create an App Registration

```bash
az ad app create --display-name "networking-audit-agent-cicd"
```

Note the `appId` from the output.

### Step 2: Create a Service Principal

```bash
az ad sp create --id <app-id>
```

### Step 3: Add Federated Credential for GitHub Actions

```bash
az ad app federated-credential create --id <app-id> --parameters '{
  "name": "github-main-branch",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:rofangaci/Azure-SRE-agent:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'
```

For environment-based deployments (recommended), also add:

```bash
# For dev environment
az ad app federated-credential create --id <app-id> --parameters '{
  "name": "github-env-dev",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:rofangaci/Azure-SRE-agent:environment:dev",
  "audiences": ["api://AzureADTokenExchange"]
}'

# For prod environment
az ad app federated-credential create --id <app-id> --parameters '{
  "name": "github-env-prod",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:rofangaci/Azure-SRE-agent:environment:prod",
  "audiences": ["api://AzureADTokenExchange"]
}'
```

### Step 4: Grant RBAC to the Service Principal

```bash
# Contributor on the resource group (to deploy Bicep)
az role assignment create \
  --assignee <app-id> \
  --role "Contributor" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/<resource-group>"
```

### Step 5: Create GitHub Environments (Optional but Recommended)

In your repo → **Settings** → **Environments**:

1. Create `dev` environment (no protection rules)
2. Create `prod` environment with:
   - Required reviewers (add yourself)
   - Deployment branches: `main` only

## Workflow Triggers

The workflow runs:
- **Automatically** on push to `main` when files in `infra/` change
- **Manually** via "Run workflow" button in the Actions tab (choose `dev` or `prod`)

## Troubleshooting

| Issue | Fix |
|---|---|
| `AADSTS700024: Client assertion is not within its valid time range` | Clock skew — retry the workflow |
| `FederatedIdentityCredentialNotFound` | Check the `subject` claim matches your repo/branch/environment exactly |
| `AuthorizationFailed` | Service principal needs Contributor on the resource group |
| `ResourceGroupNotFound` | Run `deploy.sh` first to create the resource group, or add it to the workflow |

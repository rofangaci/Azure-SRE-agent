#!/usr/bin/env bash
set -euo pipefail

# Deploy networking-audit-agent infrastructure
# Usage: ./deploy.sh <environment> <subscription-id> <resource-group>
# Example: ./deploy.sh dev 12345678-abcd-1234-abcd-123456789012 rg-networking-audit

ENVIRONMENT="${1:?Usage: ./deploy.sh <environment> <subscription-id> <resource-group>}"
SUBSCRIPTION_ID="${2:?Subscription ID required}"
RESOURCE_GROUP="${3:?Resource group name required}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="${SCRIPT_DIR}/../infra"
PARAMS_FILE="${INFRA_DIR}/parameters/${ENVIRONMENT}.bicepparam"

# Validate environment
if [[ ! -f "${PARAMS_FILE}" ]]; then
  echo "Error: Parameter file not found: ${PARAMS_FILE}"
  echo "Available environments: $(ls "${INFRA_DIR}/parameters/" | sed 's/.bicepparam//' | tr '\n' ' ')"
  exit 1
fi

echo "=== Deploying networking-audit-agent ==="
echo "Environment:   ${ENVIRONMENT}"
echo "Subscription:  ${SUBSCRIPTION_ID}"
echo "Resource Group: ${RESOURCE_GROUP}"
echo ""

# Set subscription
az account set --subscription "${SUBSCRIPTION_ID}"

# Create resource group if it doesn't exist
az group create \
  --name "${RESOURCE_GROUP}" \
  --location "eastus2" \
  --tags project=networking-audit-agent environment="${ENVIRONMENT}" \
  --output none 2>/dev/null || true

# Deploy main infrastructure
echo "Deploying infrastructure..."
DEPLOY_OUTPUT=$(az deployment group create \
  --resource-group "${RESOURCE_GROUP}" \
  --template-file "${INFRA_DIR}/main.bicep" \
  --parameters "${PARAMS_FILE}" \
  --query 'properties.outputs' \
  --output json)

PRINCIPAL_ID=$(echo "${DEPLOY_OUTPUT}" | jq -r '.managedIdentityPrincipalId.value')
CLIENT_ID=$(echo "${DEPLOY_OUTPUT}" | jq -r '.managedIdentityClientId.value')
MI_RESOURCE_ID=$(echo "${DEPLOY_OUTPUT}" | jq -r '.managedIdentityResourceId.value')

echo ""
echo "=== Deployment Complete ==="
echo "Managed Identity Client ID:    ${CLIENT_ID}"
echo "Managed Identity Principal ID: ${PRINCIPAL_ID}"
echo "Managed Identity Resource ID:  ${MI_RESOURCE_ID}"
echo ""
echo "Next steps:"
echo "  1. Create the agent at https://sre.azure.com"
echo "  2. Assign the user-assigned managed identity: ${MI_RESOURCE_ID}"
echo "  3. Run ./setup-rbac.sh to grant access to target subscriptions"
echo "  4. Upload knowledge docs from knowledge/ to the agent"

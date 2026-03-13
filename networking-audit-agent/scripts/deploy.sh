#!/usr/bin/env bash
set -euo pipefail

# Deploy networking-audit-agent infrastructure
# Usage: ./deploy.sh <environment> <subscription-id> <resource-group> <location>
# Example: ./deploy.sh dev 12345678-abcd-1234-abcd-123456789012 rg-networking-audit eastus2

# ── Prerequisites ──────────────────────────────────────────────
check_prereqs() {
  local missing=0
  for cmd in az jq; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "Error: '$cmd' is required but not installed."
      missing=1
    fi
  done
  [[ $missing -eq 1 ]] && exit 1

  if ! az account show &>/dev/null 2>&1; then
    echo "Error: Not logged in to Azure CLI. Run 'az login' first."
    exit 1
  fi
}

check_prereqs

# ── Parameters ─────────────────────────────────────────────────
ENVIRONMENT="${1:?Usage: ./deploy.sh <environment> <subscription-id> <resource-group> <location>}"
SUBSCRIPTION_ID="${2:?Subscription ID required}"
RESOURCE_GROUP="${3:?Resource group name required}"
LOCATION="${4:?Location required (e.g. eastus2, swedencentral, australiaeast)}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="${SCRIPT_DIR}/../infra"
PARAMS_FILE="${INFRA_DIR}/parameters/${ENVIRONMENT}.bicepparam"

# Validate environment parameter file exists
if [[ ! -f "${PARAMS_FILE}" ]]; then
  echo "Error: Parameter file not found: ${PARAMS_FILE}"
  echo "Available environments: $(ls "${INFRA_DIR}/parameters/" | sed 's/.bicepparam//' | tr '\n' ' ')"
  exit 1
fi

# Validate location
ALLOWED_LOCATIONS=("eastus2" "swedencentral" "australiaeast")
if [[ ! " ${ALLOWED_LOCATIONS[*]} " =~ " ${LOCATION} " ]]; then
  echo "Error: Location '${LOCATION}' is not supported."
  echo "Allowed locations: ${ALLOWED_LOCATIONS[*]}"
  exit 1
fi

echo "=== Deploying networking-audit-agent ==="
echo "Environment:    ${ENVIRONMENT}"
echo "Subscription:   ${SUBSCRIPTION_ID}"
echo "Resource Group: ${RESOURCE_GROUP}"
echo "Location:       ${LOCATION}"
echo ""

# ── Deploy ─────────────────────────────────────────────────────
az account set --subscription "${SUBSCRIPTION_ID}"

echo "Ensuring resource group exists..."
az group create \
  --name "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --tags project=networking-audit-agent environment="${ENVIRONMENT}" \
  --output none 2>/dev/null || true

echo "Deploying infrastructure..."
# Create temp params file with CLI-provided location
# (bicepparam files with 'using' don't support additional --parameters overrides)
TEMP_PARAMS="${INFRA_DIR}/parameters/.tmp-${ENVIRONMENT}.bicepparam"
sed "s|param location = .*|param location = '${LOCATION}'|" "${PARAMS_FILE}" > "${TEMP_PARAMS}"
trap 'rm -f "${TEMP_PARAMS}"' EXIT

DEPLOY_RAW=$(az deployment group create \
  --resource-group "${RESOURCE_GROUP}" \
  --parameters "${TEMP_PARAMS}" \
  --query 'properties.outputs' \
  --output json 2>/dev/null)
# az CLI may emit non-JSON lines (e.g. Bicep install messages); extract only JSON
DEPLOY_OUTPUT=$(echo "${DEPLOY_RAW}" | sed -n '/^{/,/^}/p')

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
echo "  3. Run ./setup-rbac.sh ${PRINCIPAL_ID} <target-subscription-id> to grant access"
echo "  4. Run ./upload-knowledge.sh to upload knowledge docs to the agent"

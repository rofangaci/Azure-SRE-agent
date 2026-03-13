#!/usr/bin/env bash
set -euo pipefail

# Grant the agent's managed identity RBAC access to target subscriptions
# Usage: ./setup-rbac.sh <principal-id> <subscription-id> [additional-subscription-ids...]
# Example: ./setup-rbac.sh abc-123 sub-1 sub-2

# ── Prerequisites ──────────────────────────────────────────────
check_prereqs() {
  if ! command -v az &>/dev/null; then
    echo "Error: 'az' (Azure CLI) is required but not installed."
    exit 1
  fi
  if ! az account show &>/dev/null 2>&1; then
    echo "Error: Not logged in to Azure CLI. Run 'az login' first."
    exit 1
  fi
}

check_prereqs

# ── Parameters ─────────────────────────────────────────────────
PRINCIPAL_ID="${1:?Usage: ./setup-rbac.sh <principal-id> <subscription-id> [additional-subscription-ids...]}"
shift
SUBSCRIPTION_IDS=("$@")

if [[ ${#SUBSCRIPTION_IDS[@]} -eq 0 ]]; then
  echo "Error: At least one subscription ID is required."
  echo "Usage: ./setup-rbac.sh <principal-id> <subscription-id> [additional-subscription-ids...]"
  exit 1
fi

# Roles needed for networking audit (see docs/SECURITY.md for details)
ROLES=(
  "acdd72a7-3385-48ef-bd42-f606fba81ae7:Reader"
  "4d97b98b-1d4f-4787-a291-c67834d212e7:Network Contributor"
)

echo "=== Setting up RBAC for networking-audit-agent ==="
echo "Principal ID: ${PRINCIPAL_ID}"
echo "Roles: Reader, Network Contributor"
echo "See docs/SECURITY.md for role justification and least-privilege alternatives."
echo ""

for SUB_ID in "${SUBSCRIPTION_IDS[@]}"; do
  echo "--- Subscription: ${SUB_ID} ---"
  for ROLE_ENTRY in "${ROLES[@]}"; do
    ROLE_ID="${ROLE_ENTRY%%:*}"
    ROLE_NAME="${ROLE_ENTRY##*:}"

    echo "  Assigning: ${ROLE_NAME}"
    az role assignment create \
      --assignee-object-id "${PRINCIPAL_ID}" \
      --assignee-principal-type ServicePrincipal \
      --role "${ROLE_ID}" \
      --scope "/subscriptions/${SUB_ID}" \
      --output none 2>/dev/null || echo "    (already assigned or insufficient permissions)"
  done
  echo ""
done

echo "=== RBAC setup complete ==="
echo ""
echo "Verify with:"
echo "  az role assignment list --assignee ${PRINCIPAL_ID} --all --output table"

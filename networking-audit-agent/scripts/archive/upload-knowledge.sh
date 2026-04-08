#!/usr/bin/env bash
set -euo pipefail

# Upload knowledge documents to the SRE Agent knowledge base
# Usage: ./upload-knowledge.sh <agent-resource-id>
# Example: ./upload-knowledge.sh /subscriptions/.../providers/Microsoft.App/agents/networking-audit-agent

# ── Prerequisites ──────────────────────────────────────────────
check_prereqs() {
  local missing=0
  for cmd in az curl jq; do
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
AGENT_RESOURCE_ID="${1:?Usage: ./upload-knowledge.sh <agent-resource-id>}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KNOWLEDGE_DIR="${SCRIPT_DIR}/../knowledge"
SKILLS_DIR="${SCRIPT_DIR}/../skills"

# ── Get access token ───────────────────────────────────────────
echo "=== Uploading knowledge documents ==="
echo "Agent: ${AGENT_RESOURCE_ID}"
echo ""

TOKEN=$(az account get-access-token --query accessToken -o tsv 2>/dev/null)
if [[ -z "${TOKEN}" ]]; then
  echo "Error: Failed to get access token. Ensure you are logged in with 'az login'."
  exit 1
fi

API_BASE="https://management.azure.com${AGENT_RESOURCE_ID}"
API_VERSION="2025-01-01-preview"

# ── Upload each knowledge document ─────────────────────────────
SUCCESS=0
FAILED=0

# Collect knowledge docs + skill playbooks.
FILES=()
for FILE in "${KNOWLEDGE_DIR}"/*.md; do
  if [[ -f "${FILE}" && "$(basename "${FILE}")" != "agent-persona.md" ]]; then
    FILES+=("${FILE}")
  fi
done
for FILE in "${SKILLS_DIR}"/*.md; do
  if [[ -f "${FILE}" && "$(basename "${FILE}")" != "README.md" ]]; then
    FILES+=("${FILE}")
  fi
done

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "No .md files found in ${KNOWLEDGE_DIR}"
  exit 1
fi

echo "Found ${#FILES[@]} knowledge documents to upload."
echo ""

for FILE in "${FILES[@]}"; do
  if [[ ! -f "${FILE}" ]]; then
    continue
  fi

  FILENAME=$(basename "${FILE}")
  echo "  Uploading: ${FILENAME}..."

  CONTENT=$(cat "${FILE}")
  PAYLOAD=$(jq -n --arg name "${FILENAME}" --arg content "${CONTENT}" \
    '{ properties: { displayName: $name, content: $content, contentType: "markdown" } }')

  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X PUT \
    "${API_BASE}/knowledge/${FILENAME}?api-version=${API_VERSION}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${PAYLOAD}")

  if [[ "${HTTP_CODE}" =~ ^2 ]]; then
    echo "    Success (HTTP ${HTTP_CODE})"
    ((SUCCESS++))
  else
    echo "    Failed (HTTP ${HTTP_CODE})"
    ((FAILED++))
  fi
done

echo ""
echo "=== Upload Complete ==="
echo "  Success: ${SUCCESS}"
echo "  Failed:  ${FAILED}"

if [[ ${FAILED} -gt 0 ]]; then
  echo ""
  echo "If uploads failed, you can upload manually:"
  echo "  UI: Go to the agent at https://sre.azure.com -> Knowledge -> Upload"
  echo "  Ensure you have Contributor access to the agent resource."
fi

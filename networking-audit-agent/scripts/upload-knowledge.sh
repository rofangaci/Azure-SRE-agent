#!/usr/bin/env bash
set -euo pipefail

# Upload knowledge documents to the SRE Agent knowledge base
# Usage: ./upload-knowledge.sh <agent-endpoint>
# Example: ./upload-knowledge.sh https://my-agent--abc123.def456.swedencentral.azuresre.ai

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
AGENT_ENDPOINT="${1:?Usage: ./upload-knowledge.sh <agent-endpoint>}"
# Strip trailing slash if present
AGENT_ENDPOINT="${AGENT_ENDPOINT%/}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KNOWLEDGE_DIR="${SCRIPT_DIR}/../knowledge"

# ── Get access token ───────────────────────────────────────────
echo "=== Uploading knowledge documents ==="
echo "Agent: ${AGENT_ENDPOINT}"
echo ""

# SRE Agent data plane uses a dedicated audience
SRE_AUDIENCE="59f0a04a-b322-4310-adc9-39ac41e9631e"
TOKEN=$(az account get-access-token --resource "${SRE_AUDIENCE}" --query accessToken -o tsv 2>/dev/null)
if [[ -z "${TOKEN}" ]]; then
  echo "Error: Failed to get access token. Ensure you are logged in with 'az login'."
  exit 1
fi

# ── Upload knowledge documents ─────────────────────────────────
# Build -F arguments for all markdown files
CURL_ARGS=()
for FILE in "${KNOWLEDGE_DIR}"/*.md; do
  if [[ ! -f "${FILE}" ]]; then
    continue
  fi
  CURL_ARGS+=(-F "files=@${FILE}")
  echo "  Queued: $(basename "${FILE}")"
done

if [[ ${#CURL_ARGS[@]} -eq 0 ]]; then
  echo "No knowledge documents found in ${KNOWLEDGE_DIR}"
  exit 0
fi

echo ""
echo "  Uploading..."

RESPONSE=$(curl -s -w '\n%{http_code}' \
  -X POST \
  "${AGENT_ENDPOINT}/api/v1/agentmemory/upload" \
  -H "Authorization: Bearer ${TOKEN}" \
  "${CURL_ARGS[@]}")

HTTP_CODE=$(echo "${RESPONSE}" | tail -1)
BODY=$(echo "${RESPONSE}" | sed '$d')

if [[ "${HTTP_CODE}" =~ ^2 ]]; then
  echo "  Success (HTTP ${HTTP_CODE})"
  echo "${BODY}" | jq -r '.uploaded[]' 2>/dev/null | while read -r f; do
    echo "    ✓ ${f}"
  done
else
  echo "  Failed (HTTP ${HTTP_CODE})"
  echo "${BODY}"
  exit 1
fi

echo ""
echo "=== Upload Complete ==="

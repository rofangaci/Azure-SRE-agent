#!/usr/bin/env bash
set -euo pipefail

# Upload knowledge documents to the agent
# This is a placeholder — knowledge upload is done via the SRE Agent UI or API
# Usage: ./upload-knowledge.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KNOWLEDGE_DIR="${SCRIPT_DIR}/../knowledge"

echo "=== Knowledge Documents ==="
echo "The following documents should be uploaded to the agent's knowledge base:"
echo ""

for FILE in "${KNOWLEDGE_DIR}"/*.md; do
  if [[ -f "${FILE}" ]]; then
    FILENAME=$(basename "${FILE}")
    LINES=$(wc -l < "${FILE}")
    echo "  - ${FILENAME} (${LINES} lines)"
  fi
done

echo ""
echo "Upload methods:"
echo "  1. UI: Go to the agent in https://sre.azure.com → Knowledge → Upload"
echo "  2. API: Use the agent's REST API to upload documents programmatically"
echo ""
echo "Tip: Connect this GitHub repo to the agent for automatic code context."

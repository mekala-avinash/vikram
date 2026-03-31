#!/usr/bin/env bash
# =============================================================================
# deploy.sh — Deploy the KSeF Logic App to a given Azure environment
# =============================================================================
# Usage:
#   ./deploy.sh --env dev
#   ./deploy.sh --env staging
#   ./deploy.sh --env production
#
# Prerequisites:
#   - Azure CLI logged in: az login
#   - jq installed: brew install jq
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV=""

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV="$2"; shift 2 ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

if [[ -z "$ENV" ]]; then
  echo "ERROR: --env argument is required (dev|staging|production)"
  exit 1
fi

PARAMS_FILE="$SCRIPT_DIR/environments/$ENV/parameters.json"
if [[ ! -f "$PARAMS_FILE" ]]; then
  echo "ERROR: Parameter file not found: $PARAMS_FILE"
  exit 1
fi

echo "=== Deploying to: $ENV ==="
echo "=== Using parameters: $PARAMS_FILE ==="

# Copy env parameters to the logic-app-v2 folder for deployment
cp "$PARAMS_FILE" "$SCRIPT_DIR/logic-app-v2/parameters.json"
echo "✓ Parameters staged"

# --- Deploy map (XSLT) to Integration Account (if configured) ---
IA_NAME="${LOGIC_APP_INTEGRATION_ACCOUNT_NAME:-}"
RG_NAME="${AZURE_RESOURCE_GROUP:-}"
if [[ -n "$IA_NAME" && -n "$RG_NAME" ]]; then
  echo "=== Uploading XSLT map to Integration Account: $IA_NAME ==="
  az logic integration-account map create \
    --resource-group "$RG_NAME" \
    --integration-account-name "$IA_NAME" \
    --name "KsefFa3" \
    --map-type "Xslt" \
    --content-type "application/xml" \
    --content @"$SCRIPT_DIR/logic-app-v2/maps/KsefFa3.xslt" \
    --output none
  echo "✓ Map uploaded"
else
  echo "! Skipping Integration Account map upload (LOGIC_APP_INTEGRATION_ACCOUNT_NAME or AZURE_RESOURCE_GROUP not set)"
fi

# --- Deploy schemas to Integration Account ---
if [[ -n "$IA_NAME" && -n "$RG_NAME" ]]; then
  echo "=== Uploading schemas ==="
  for xsd in "$SCRIPT_DIR/logic-app-v2/schemas/"*.xsd; do
    schema_name="$(basename "${xsd%.*}")"
    az logic integration-account schema create \
      --resource-group "$RG_NAME" \
      --integration-account-name "$IA_NAME" \
      --name "$schema_name" \
      --schema-type "Xml" \
      --content-type "application/xml" \
      --content @"$xsd" \
      --output none
    echo "✓ Schema uploaded: $schema_name"
  done
fi

echo ""
echo "=== Deployment complete for: $ENV ==="
echo ""
echo "Next steps:"
echo "  1. Open the Logic App in Azure Portal and verify workflow parameters"
echo "  2. Confirm Key Vault references resolve: KsefClientSecret-$ENV"
echo "  3. Trigger a test message on the Service Bus topic"

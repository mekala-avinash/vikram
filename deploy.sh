#!/usr/bin/env bash
# =============================================================================
# deploy.sh — Deploy the KSeF Logic App to a given Azure environment
# =============================================================================
# Usage:
#   ./deploy.sh --env dev
#   ./deploy.sh --env staging
#   ./deploy.sh --env production
#
# Required environment variables:
#   AZURE_RESOURCE_GROUP         — Resource group containing the Logic App
#   LOGIC_APP_NAME               — Logic App (Standard) resource name
#
# Optional environment variables:
#   LOGIC_APP_INTEGRATION_ACCOUNT_NAME  — Supply to upload maps & schemas
#
# Prerequisites:
#   - Azure CLI logged in: az login
#   - jq installed: brew install jq
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGIC_APP_DIR="$SCRIPT_DIR/logic-app"
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

# --- Validate required environment variables ---
: "${AZURE_RESOURCE_GROUP:?ERROR: AZURE_RESOURCE_GROUP is not set}"
: "${LOGIC_APP_NAME:?ERROR: LOGIC_APP_NAME is not set}"

PARAMS_FILE="$SCRIPT_DIR/environments/$ENV/parameters.json"
if [[ ! -f "$PARAMS_FILE" ]]; then
  echo "ERROR: Parameter file not found: $PARAMS_FILE"
  exit 1
fi

echo "=== Deploying to: $ENV ==="
echo "=== Resource Group: $AZURE_RESOURCE_GROUP ==="
echo "=== Logic App: $LOGIC_APP_NAME ==="
echo "=== Using parameters: $PARAMS_FILE ==="

# --- Stage parameters for deployment ---
cp "$PARAMS_FILE" "$LOGIC_APP_DIR/parameters.json"
echo "✓ Parameters staged to logic-app/parameters.json"

# --- Sync non-secret App Settings from parameters.json ---
# Extracts all String (non-SecureString) parameters and pushes them as App Settings.
# SecureString values (e.g. KsefClientSecret) must be set separately via Key Vault references
# in the Azure Portal or your CI/CD pipeline — they are never synced here.
echo "=== Syncing App Settings to Logic App ==="
APP_SETTINGS_ARGS=()
while IFS= read -r line; do
  APP_SETTINGS_ARGS+=("$line")
done < <(jq -r '
  to_entries
  | map(select(
      .key != "_comment"
      and .key != "\$schema"
      and (.value.type // "" | ascii_downcase) != "securestring"
    ))
  | map("\(.key)=\(.value.value)")
  | .[]
' "$PARAMS_FILE")

if [[ ${#APP_SETTINGS_ARGS[@]} -gt 0 ]]; then
  az logicapp config appsettings set \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --name "$LOGIC_APP_NAME" \
    --settings "${APP_SETTINGS_ARGS[@]}" \
    --output none
  echo "✓ App Settings synced (${#APP_SETTINGS_ARGS[@]} values)"
else
  echo "! No non-secret App Settings to sync"
fi

# --- Deploy map (XSLT) to Integration Account (if configured) ---
IA_NAME="${LOGIC_APP_INTEGRATION_ACCOUNT_NAME:-}"
if [[ -n "$IA_NAME" ]]; then
  echo "=== Uploading XSLT map to Integration Account: $IA_NAME ==="
  az logic integration-account map create \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --integration-account-name "$IA_NAME" \
    --name "KsefFa3" \
    --map-type "Xslt" \
    --content-type "application/xml" \
    --content @"$LOGIC_APP_DIR/maps/KsefFa3.xslt" \
    --output none
  echo "✓ Map uploaded: KsefFa3.xslt"
else
  echo "! Skipping Integration Account map upload (LOGIC_APP_INTEGRATION_ACCOUNT_NAME not set)"
fi

# --- Deploy schemas to Integration Account ---
if [[ -n "$IA_NAME" ]]; then
  echo "=== Uploading schemas ==="
  for xsd in "$LOGIC_APP_DIR/schemas/"*.xsd; do
    schema_name="$(basename "${xsd%.*}")"
    az logic integration-account schema create \
      --resource-group "$AZURE_RESOURCE_GROUP" \
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
echo "  1. Open the Logic App in Azure Portal and verify workflow parameters resolved"
echo "  2. Confirm Key Vault reference resolves: KsefClientSecret-$ENV"
echo "  3. Trigger a test message on the Service Bus topic: invoice-ready-for-transformation"

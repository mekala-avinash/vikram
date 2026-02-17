#!/bin/bash

# ============================================================================
# Azure Verified Modules Download Script
# ============================================================================
# This script downloads all required Azure Verified Modules to the local
# modules directory for use in Terraform configuration.
# ============================================================================

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Base directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MODULES_DIR="$PROJECT_ROOT/modules"

echo -e "${GREEN}Azure Verified Modules Download Script${NC}"
echo "========================================"
echo ""

# Create modules directory
mkdir -p "$MODULES_DIR"
cd "$MODULES_DIR"

# Array of required modules
declare -a MODULES=(
    "terraform-azurerm-avm-res-resources-resourcegroup"
    "terraform-azurerm-avm-res-managedidentity-userassignedidentity"
    "terraform-azurerm-avm-res-network-virtualnetwork"
    "terraform-azurerm-avm-res-storage-storageaccount"
    "terraform-azurerm-avm-res-keyvault-vault"
    "terraform-azurerm-avm-res-insights-component"
    "terraform-azurerm-avm-res-sql-server"
    "terraform-azurerm-avm-res-web-serverfarm"
    "terraform-azurerm-avm-res-web-site"
)

# GitHub organization
GITHUB_ORG="Azure"

echo "Downloading modules to: $MODULES_DIR"
echo ""

# Download each module
for MODULE in "${MODULES[@]}"; do
    echo -e "${YELLOW}Downloading module: $MODULE${NC}"
    
    # Extract module name without terraform- prefix
    MODULE_NAME="${MODULE#terraform-azurerm-}"
    
    # Check if module already exists
    if [ -d "$MODULE_NAME" ]; then
        echo -e "${YELLOW}  Module already exists. Updating...${NC}"
        cd "$MODULE_NAME"
        git pull
        cd ..
    else
        # Clone the repository
        REPO_URL="https://github.com/$GITHUB_ORG/$MODULE.git"
        
        if git clone "$REPO_URL" "$MODULE_NAME"; then
            echo -e "${GREEN}  ✓ Successfully downloaded $MODULE_NAME${NC}"
        else
            echo -e "${RED}  ✗ Failed to download $MODULE_NAME${NC}"
            echo -e "${RED}    Repository: $REPO_URL${NC}"
            exit 1
        fi
    fi
    
    echo ""
done

echo -e "${GREEN}========================================"
echo -e "All modules downloaded successfully!"
echo -e "========================================${NC}"
echo ""
echo "Modules location: $MODULES_DIR"
echo ""
echo "You can now run:"
echo "  cd $PROJECT_ROOT/terraform"
echo "  terraform init"
echo "  terraform plan"

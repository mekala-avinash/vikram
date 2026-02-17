# Example terraform.tfvars file
# Copy this to terraform.tfvars and update with your values
# DO NOT commit terraform.tfvars to version control!

# ============================================================================
# BASIC CONFIGURATION
# ============================================================================
location     = "eastus"
environment  = "demo"
project_name = "xmlintegration"

# ============================================================================
# SQL DATABASE CONFIGURATION
# ============================================================================
sql_admin_username = "sqladmin"
sql_admin_password = "CHANGE_ME_SecurePassword123!"  # Use strong password
sql_database_name  = "XmlDataDB"
sql_table_name     = "CanonicalXmlData"
sql_sku_name       = "S0"  # Basic tier for dev, scale up for production

# ============================================================================
# FUNCTION APP CONFIGURATION
# ============================================================================
# Timer schedule in NCRONTAB format
# Examples:
#   "0 0 * * * *"     - Every hour (default)
#   "0 */30 * * * *"  - Every 30 minutes
#   "0 0 */2 * * *"   - Every 2 hours
#   "0 0 9 * * *"     - Every day at 9:00 AM
function_timer_schedule = "0 0 * * * *"

# ============================================================================
# VENDOR API CONFIGURATION
# ============================================================================
vendor_api_url       = "https://vendor-api.example.com/fa3/submit"
vendor_api_auth_type = "apikey"  # Options: apikey, oauth, certificate

# Note: API keys and secrets are stored as environment variables in the Function App
# instead of Key Vault for demo purposes

# ============================================================================
# STORAGE CONFIGURATION
# ============================================================================
storage_account_tier        = "Standard"
storage_account_replication = "LRS"  # LRS for dev, GRS for production

# ============================================================================
# APP SERVICE PLAN CONFIGURATION
# ============================================================================
app_service_plan_sku = "Y1"  # Y1 = Consumption plan (pay per execution)

# ============================================================================
# TAGS
# ============================================================================
tags = {
  ManagedBy   = "Terraform"
  Project     = "XML-FA3-Integration"
  Environment = "Development"
  CostCenter  = "IT"
  Owner       = "DataTeam"
}

# ============================================================================
# RESOURCE GROUP
# ============================================================================
module "resource_group" {
  source  = "Azure/avm-res-resources-resourcegroup/azurerm"
  version = "~> 0.1"
  
  name     = "${local.resource_prefix}-rg"
  location = var.location
  tags     = local.common_tags
}

# ============================================================================
# MANAGED IDENTITY
# ============================================================================
module "managed_identity" {
  source  = "Azure/avm-res-managedidentity-userassignedidentity/azurerm"
  version = "~> 0.3"
  
  name              = "${local.resource_prefix}-identity"
  location          = var.location
  resource_group_id = module.resource_group.id
  tags              = local.common_tags
}

# ============================================================================
# VIRTUAL NETWORK (for secure communication)
# ============================================================================
module "virtual_network" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "~> 0.4"
  
  name          = "${local.resource_prefix}-vnet"
  location      = var.location
  parent_id     = module.resource_group.id
  address_space = ["10.0.0.0/16"]
  
  subnets = {
    function_subnet = {
      address_prefixes = ["10.0.1.0/24"]
      delegation = [{
        name = "Microsoft.Web/serverFarms"
        service_delegation = {
          name = "Microsoft.Web/serverFarms"
          actions = [
            "Microsoft.Network/virtualNetworks/subnets/action"
          ]
        }
      }]
    }
    sql_subnet = {
      address_prefixes = ["10.0.2.0/24"]
      service_endpoints = ["Microsoft.Sql"]
    }
  }
  
  tags = local.common_tags
}

# ============================================================================
# STORAGE ACCOUNT (for FA3 data and function code)
# ============================================================================
module "storage_account" {
  source  = "Azure/avm-res-storage-storageaccount/azurerm"
  version = "~> 0.2"
  
  name                     = "${replace(local.resource_prefix, "-", "")}sa"
  location                 = var.location
  resource_group_name      = module.resource_group.name
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_account_replication
  
  # Enable blob versioning for FA3 data
  blob_properties = {
    versioning_enabled = true
    container_delete_retention_policy = {
      days = 7
    }
  }
  
  # Containers for FA3 data and function code
  containers = {
    fa3_data = {
      name                  = local.fa3_container_name
      container_access_type = "private"
    }
    function_code = {
      name                  = local.function_code_container
      container_access_type = "private"
    }
  }
  
  tags = local.common_tags
}

# ============================================================================
# APPLICATION INSIGHTS (for monitoring)
# ============================================================================
module "application_insights" {
  source  = "Azure/avm-res-insights-component/azurerm"
  version = "~> 0.1"
  
  name             = "${local.resource_prefix}-appinsights"
  location         = var.location
  resource_group_name = module.resource_group.name
  application_type = "web"
  
  tags = local.common_tags
}

# ============================================================================
# SQL SERVER AND DATABASE
# ============================================================================
module "sql_server" {
  source  = "Azure/avm-res-sql-server/azurerm"
  version = "0.1.6"
  
  name                         = "${local.resource_prefix}-sqlserver"
  location                     = var.location
  resource_group_name          = module.resource_group.name
  server_version               = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = var.sql_admin_password
  
  # Firewall rules - allow Azure services
  firewall_rules = {
    AllowAzureServices = {
      start_ip_address = "0.0.0.0"
      end_ip_address   = "0.0.0.0"
    }
  }
  
  tags = local.common_tags
}

# SQL Database
resource "azurerm_mssql_database" "xml_database" {
  name      = var.sql_database_name
  server_id = module.sql_server.id
  sku_name  = var.sql_sku_name
  
  tags = local.common_tags
}

# ============================================================================
# APP SERVICE PLAN (for Function App)
# ============================================================================
module "app_service_plan" {
  source  = "Azure/avm-res-web-serverfarm/azurerm"
  version = "~> 0.2"
  
  name                = "${local.resource_prefix}-asp"
  location            = var.location
  resource_group_name = module.resource_group.name
  os_type             = "Linux"
  sku_name            = var.app_service_plan_sku
  
  tags = local.common_tags
}

# ============================================================================
# FUNCTION APP
# ============================================================================
module "function_app" {
  source  = "Azure/avm-res-web-site/azurerm"
  version = "~> 0.10"
  
  name                = "${local.resource_prefix}-func"
  location            = var.location
  resource_group_name = module.resource_group.name
  kind                = "functionapp,linux"
  
  service_plan_id = module.app_service_plan.id
  
  # Function App configuration
  site_config = {
    linux_fx_version = "PYTHON|3.11"
    
    application_stack = {
      python_version = "3.11"
    }
    
    # Enable VNet integration
    vnet_route_all_enabled = true
  }
  
  # App settings
  app_settings = merge(
    local.function_app_settings,
    {
      # Storage account connection for function runtime
      AzureWebJobsStorage        = module.storage_account.primary_connection_string
      WEBSITE_CONTENTAZUREFILECONNECTIONSTRING = module.storage_account.primary_connection_string
      WEBSITE_CONTENTSHARE       = "${local.resource_prefix}-func-content"
      
      # SQL connection string (stored as environment variable instead of Key Vault)
      SQL_CONNECTION_STRING = local.sql_connection_string
    }
  )
  
  # Managed Identity
  identity = {
    type         = "UserAssigned"
    identity_ids = [module.managed_identity.id]
  }
  
  # VNet integration
  virtual_network_subnet_id = module.virtual_network.subnets["function_subnet"].id
  
  tags = local.common_tags
}

# ============================================================================
# ROLE ASSIGNMENTS
# ============================================================================

# Grant Function App Managed Identity access to Storage Account
resource "azurerm_role_assignment" "function_storage_blob_contributor" {
  scope                = module.storage_account.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = module.managed_identity.principal_id
}

# Grant Function App Managed Identity access to SQL Database
resource "azurerm_role_assignment" "function_sql_contributor" {
  scope                = azurerm_mssql_database.xml_database.id
  role_definition_name = "SQL DB Contributor"
  principal_id         = module.managed_identity.principal_id
}

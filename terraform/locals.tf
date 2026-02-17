locals {
  # Resource naming convention
  resource_prefix = "${var.project_name}-${var.environment}"
  
  # Common tags
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment
      Location    = var.location
      DeployedOn  = timestamp()
      created-by  = "vikram"
    }
  )

  # Storage container names
  fa3_container_name      = "fa3-data"
  function_code_container = "function-code"

  # Function App settings
  function_app_settings = {
    FUNCTIONS_WORKER_RUNTIME       = "python"
    FUNCTIONS_EXTENSION_VERSION    = "~4"
    APPINSIGHTS_INSTRUMENTATIONKEY = module.application_insights.instrumentation_key
    
    # SQL Database connection
    SQL_SERVER_FQDN     = module.sql_server.resource.fully_qualified_domain_name
    SQL_DATABASE_NAME   = var.sql_database_name
    SQL_TABLE_NAME      = var.sql_table_name
    SQL_ADMIN_USERNAME  = var.sql_admin_username
    
    # Storage Account
    STORAGE_ACCOUNT_NAME = module.storage_account.name
    FA3_CONTAINER_NAME   = local.fa3_container_name
    
    # Timer schedule
    TIMER_SCHEDULE = var.function_timer_schedule
    
    # Vendor API configuration
    VENDOR_API_URL       = var.vendor_api_url
    VENDOR_API_AUTH_TYPE = var.vendor_api_auth_type
    
    # Use Managed Identity
    AZURE_CLIENT_ID = module.managed_identity.client_id
  }

  # SQL connection string (stored as environment variable)
  sql_connection_string = "Server=tcp:${module.sql_server.resource.fully_qualified_domain_name},1433;Initial Catalog=${var.sql_database_name};Persist Security Info=False;User ID=${var.sql_admin_username};Password=${var.sql_admin_password};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
}

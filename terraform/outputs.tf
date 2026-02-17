output "resource_group_name" {
  description = "Name of the resource group"
  value       = module.resource_group.name
}

output "resource_group_id" {
  description = "ID of the resource group"
  value       = module.resource_group.resource_id
}

output "sql_server_fqdn" {
  description = "Fully qualified domain name of the SQL Server"
  value       = module.sql_server.resource.fully_qualified_domain_name
}

output "sql_server_name" {
  description = "Name of the SQL Server"
  value       = module.sql_server.resource.name
}

output "sql_database_name" {
  description = "Name of the SQL Database"
  value       = azurerm_mssql_database.xml_database.name
}

output "sql_database_id" {
  description = "ID of the SQL Database"
  value       = azurerm_mssql_database.xml_database.id
}

output "storage_account_name" {
  description = "Name of the Storage Account"
  value       = module.storage_account.name
}

output "storage_account_primary_blob_endpoint" {
  description = "Primary blob endpoint of the Storage Account"
  value       = module.storage_account.resource.primary_blob_endpoint
}

output "fa3_container_name" {
  description = "Name of the FA3 data container"
  value       = local.fa3_container_name
}

output "application_insights_instrumentation_key" {
  description = "Application Insights instrumentation key"
  value       = module.application_insights.instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Application Insights connection string"
  value       = module.application_insights.connection_string
  sensitive   = true
}

output "function_app_name" {
  description = "Name of the Function App"
  value       = module.function_app.name
}

output "function_app_default_hostname" {
  description = "Default hostname of the Function App"
  value       = module.function_app.default_hostname
}

output "function_app_id" {
  description = "ID of the Function App"
  value       = module.function_app.id
}

output "managed_identity_principal_id" {
  description = "Principal ID of the Managed Identity"
  value       = module.managed_identity.principal_id
}

output "managed_identity_client_id" {
  description = "Client ID of the Managed Identity"
  value       = module.managed_identity.client_id
}

output "virtual_network_name" {
  description = "Name of the Virtual Network"
  value       = module.virtual_network.name
}

output "virtual_network_id" {
  description = "ID of the Virtual Network"
  value       = module.virtual_network.id
}

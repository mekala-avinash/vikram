variable "location" {
  description = "Azure region where resources will be deployed"
  type        = string
  default     = "eastus"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "xmlintegration"
}

variable "sql_admin_username" {
  description = "SQL Server administrator username"
  type        = string
  default     = "sqladmin"
}

variable "sql_admin_password" {
  description = "SQL Server administrator password"
  type        = string
  sensitive   = true
}

variable "sql_database_name" {
  description = "Name of the SQL database containing XML data"
  type        = string
  default     = "XmlDataDB"
}

variable "sql_sku_name" {
  description = "SQL Database SKU"
  type        = string
  default     = "S0"
}

variable "sql_table_name" {
  description = "Name of the table containing XML data"
  type        = string
  default     = "CanonicalXmlData"
}

variable "function_timer_schedule" {
  description = "NCRONTAB expression for timer trigger (default: every hour)"
  type        = string
  default     = "0 0 * * * *"
}

variable "vendor_api_url" {
  description = "Vendor API endpoint URL"
  type        = string
}

variable "vendor_api_auth_type" {
  description = "Vendor API authentication type (apikey, oauth, certificate)"
  type        = string
  default     = "apikey"
  validation {
    condition     = contains(["apikey", "oauth", "certificate"], var.vendor_api_auth_type)
    error_message = "Authentication type must be apikey, oauth, or certificate."
  }
}

variable "storage_account_tier" {
  description = "Storage account tier"
  type        = string
  default     = "Standard"
}

variable "storage_account_replication" {
  description = "Storage account replication type"
  type        = string
  default     = "LRS"
}

variable "app_service_plan_sku" {
  description = "App Service Plan SKU for Function App"
  type        = string
  default     = "Y1" # Consumption plan
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Project   = "XML-FA3-Integration"
  }
}

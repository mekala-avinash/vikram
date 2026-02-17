# Azure Verified Modules (AVM) Parameter Reference

## Common Parameter Changes

When using Azure Verified Modules from the Terraform Registry, note these parameter differences from standard azurerm resources:

### Resource Group References
- **Standard**: `resource_group_name = "name"`
- **AVM**: `parent_id = module.resource_group.id` (for child resources)
- **AVM**: `resource_group_id = module.resource_group.id` (for some modules)
- **AVM**: `resource_group_name = "name"` (for some modules - check docs)

### Module-Specific Parameters

#### Virtual Network
```hcl
module "virtual_network" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  
  parent_id = module.resource_group.id  # NOT resource_group_name
  # ...
}
```

#### Managed Identity
```hcl
module "managed_identity" {
  source  = "Azure/avm-res-managedidentity-userassignedidentity/azurerm"
  
  resource_group_id = module.resource_group.id  # NOT resource_group_name
  # ...
}
```

#### SQL Server
```hcl
module "sql_server" {
  source  = "Azure/avm-res-sql-server/azurerm"
  
  server_version = "12.0"  # NOT version (conflicts with module version)
  # ...
}
```

## Troubleshooting

### Error: "argument is required, but no definition was found"
- Check the module documentation for required parameters
- AVM modules often use different parameter names than standard resources

### Error: "argument is not expected here"
- The parameter name has changed in AVM
- Check if it should be `parent_id`, `resource_group_id`, or `resource_group_name`

### Error: "argument specified multiple times"
- Usually happens with `version` parameter in SQL Server module
- Use `server_version` instead of `version` for SQL Server version

## Resources

- [Azure Verified Modules Registry](https://registry.terraform.io/namespaces/Azure)
- [AVM Documentation](https://azure.github.io/Azure-Verified-Modules/)

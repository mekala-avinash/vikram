# Quick Start: Deploy in Azure Cloud Shell

## 🚀 Fast Track Deployment

### Step 1: Open Cloud Shell
Go to https://shell.azure.com

### Step 2: Upload Terraform Files
Upload only the `terraform/` directory to Cloud Shell:
```bash
# After uploading, navigate to the directory
cd terraform
```

### Step 3: Configure
Edit `terraform.tfvars`:
```bash
vi terraform.tfvars
```

Update the SQL password:
```hcl
sql_admin_password = "YourSecurePassword123!"
```

### Step 4: Deploy
```bash
# Initialize (downloads modules from Terraform Registry)
terraform init

# Review plan
terraform plan

# Deploy
terraform apply
```

That's it! ✅

## What Changed?

The Terraform configuration now uses **remote modules** from the Terraform Registry instead of local modules. This means:

- ✅ No need to download modules manually
- ✅ No need to upload the `modules/` directory
- ✅ Terraform automatically downloads modules during `terraform init`
- ✅ Works seamlessly in Cloud Shell

## Module Sources

All modules are now sourced from the official Azure Verified Modules:

```hcl
module "resource_group" {
  source  = "Azure/avm-res-resources-resourcegroup/azurerm"
  version = "~> 0.1"
  ...
}
```

## Troubleshooting

### Module Download Issues
If `terraform init` fails to download modules:
```bash
# Clear cache and retry
rm -rf .terraform
terraform init
```

### Authentication
Cloud Shell is pre-authenticated. Verify with:
```bash
az account show
```

### Version Conflicts
If you encounter version conflicts, you can update module versions in `main.tf`.

## Next Steps

After deployment:
1. Note the outputs (Function App URL, SQL Server FQDN)
2. Deploy your Function App code
3. Test the integration

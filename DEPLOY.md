# Azure XML Integration - Terraform Deployment

## 🎯 Quick Deploy in Cloud Shell

### Prerequisites
- Azure subscription
- Access to Azure Cloud Shell

### Steps

1. **Open Cloud Shell**: https://shell.azure.com

2. **Upload `terraform/` directory** using the upload button

3. **Configure**:
   ```bash
   cd terraform
   vi terraform.tfvars
   # Update sql_admin_password
   ```

4. **Deploy**:
   ```bash
   terraform init   # Downloads modules automatically
   terraform plan
   terraform apply
   ```

## 📦 What Gets Deployed

- Resource Group
- Virtual Network (with function & SQL subnets)
- SQL Server & Database
- Storage Account (for FA3 data)
- Function App (Python 3.11)
- Application Insights
- Managed Identity

## 🔑 Key Features

- ✅ **No Key Vault** - Secrets stored as environment variables (demo only)
- ✅ **Remote Modules** - Automatically downloaded from Terraform Registry
- ✅ **No Manual Downloads** - Just upload `terraform/` folder
- ✅ **Cloud Shell Ready** - Pre-authenticated, no setup needed

## 📝 Important Notes

- Update `sql_admin_password` in `terraform.tfvars` before deploying
- For production, add Key Vault for secret management
- Estimated cost: ~$18-25/month for low usage

## 📚 Documentation

- [CLOUD_SHELL_DEPLOY.md](CLOUD_SHELL_DEPLOY.md) - Quick start guide
- [walkthrough.md](brain/.../walkthrough.md) - Detailed configuration info
- [README.md](README.md) - Full project documentation

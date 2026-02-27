# Azure Portal Manual Setup Guide

This guide will walk you through creating all the necessary Azure resources manually using the Azure Portal web interface. No prior Azure experience needed!

## What You'll Build

You'll create a complete cloud infrastructure for processing XML data, including:
- A storage space for your data
- A database to store information
- A serverless function that runs your code automatically
- Networking and security components

**Estimated time**: 45-60 minutes

---

## Prerequisites

1. **Azure Account**: Sign up at https://azure.microsoft.com (free tier available)
2. **Web Browser**: Chrome, Firefox, or Edge
3. **Notepad**: Keep one handy to save important values as you go

---

## Step 1: Create a Resource Group

Think of a Resource Group as a folder that holds all your Azure resources together.

1. Go to https://portal.azure.com and sign in
2. In the search bar at the top, type **"Resource groups"** and click it
3. Click **"+ Create"** button
4. Fill in the form:
   - **Subscription**: Select your subscription (usually "Pay-As-You-Go" or "Free Trial")
   - **Resource group name**: `xml-integration-rg` (or any name you prefer)
   - **Region**: Choose closest to you (e.g., "East US", "West Europe")
5. Click **"Review + create"**, then **"Create"**

✅ **Save this info**: Write down your resource group name and region

---

## Step 2: Create a Storage Account

This is like a hard drive in the cloud where your files will be stored.

1. In the search bar, type **"Storage accounts"** and click it
2. Click **"+ Create"**
3. Fill in the **Basics** tab:
   - **Resource group**: Select the one you just created
   - **Storage account name**: `xmlintegrationsa` (must be lowercase, no spaces, globally unique)
   - **Region**: Same as your resource group
   - **Performance**: Standard
   - **Redundancy**: LRS (Locally-redundant storage) - cheapest option
4. Click **"Review"**, then **"Create"**
5. Wait for deployment (about 1 minute)
6. Click **"Go to resource"**

### Create Containers (Folders)

1. In the left menu, click **"Containers"** (under Data storage)
2. Click **"+ Container"**
3. Create first container:
   - **Name**: `fa3-data`
   - **Public access level**: Private
   - Click **"Create"**
4. Click **"+ Container"** again
5. Create second container:
   - **Name**: `function-code`
   - **Public access level**: Private
   - Click **"Create"**

### Get Connection String

1. In the left menu, click **"Access keys"**
2. Click **"Show"** next to "Connection string" under key1
3. Click the copy button
4. ✅ **Save this**: Paste it in your notepad as "Storage Connection String"

---

## Step 3: Create a Virtual Network

This creates a private network for your resources to communicate securely.

1. Search for **"Virtual networks"** and click it
2. Click **"+ Create"**
3. Fill in the **Basics** tab:
   - **Resource group**: Select your resource group
   - **Name**: `xml-integration-vnet`
   - **Region**: Same as before
4. Click **"Next: IP Addresses"**
5. Keep the default IP address space (10.0.0.0/16)
6. Click **"+ Add subnet"** and create:
   - **Subnet name**: `function-subnet`
   - **Subnet address range**: `10.0.1.0/24`
   - Click **"Add"**
7. Click **"+ Add subnet"** again and create:
   - **Subnet name**: `sql-subnet`
   - **Subnet address range**: `10.0.2.0/24`
   - Click **"Add"**
8. Click **"Review + create"**, then **"Create"**

---

## Step 4: Create a Managed Identity

This is like a digital ID card that allows your function to access other resources securely.

1. Search for **"Managed Identities"** and click it
2. Click **"+ Create"**
3. Fill in:
   - **Resource group**: Select your resource group
   - **Region**: Same as before
   - **Name**: `xml-integration-identity`
4. Click **"Review + create"**, then **"Create"**
5. After creation, click **"Go to resource"**
6. ✅ **Save this**: Copy the **"Client ID"** (looks like: 12345678-1234-1234-1234-123456789abc)

---

## Step 5: Create a SQL Server and Database

This is where your structured data will be stored.

### Create SQL Server

1. Search for **"SQL servers"** and click it
2. Click **"+ Create"**
3. Fill in the **Basics** tab:
   - **Resource group**: Select your resource group
   - **Server name**: `xml-integration-sqlserver` (must be globally unique)
   - **Location**: Same region as before
   - **Authentication method**: Use SQL authentication
   - **Server admin login**: `sqladmin`
   - **Password**: Create a strong password (e.g., `MySecurePass123!`)
   - **Confirm password**: Re-enter the password
4. ✅ **Save this**: Write down your SQL admin username and password
5. Click **"Next: Networking"**
6. Under **Connectivity method**, select **"Public endpoint"**
7. Under **Firewall rules**:
   - Enable **"Allow Azure services and resources to access this server"**
8. Click **"Review + create"**, then **"Create"**
9. Wait for deployment, then click **"Go to resource"**

### Create SQL Database

1. In your SQL Server page, click **"+ Create database"** at the top
2. Fill in:
   - **Database name**: `xml_database`
   - **Compute + storage**: Click **"Configure database"**
     - Select **"Basic"** (cheapest option, ~$5/month)
     - Click **"Apply"**
3. Click **"Review + create"**, then **"Create"**
4. Wait for deployment

### Get SQL Server FQDN

1. Go back to your SQL Server (not the database)
2. On the Overview page, find **"Server name"**
3. ✅ **Save this**: Copy the full server name (e.g., `xml-integration-sqlserver.database.windows.net`)

---

## Step 6: Create Log Analytics Workspace

This collects logs and monitoring data from your application.

1. Search for **"Log Analytics workspaces"** and click it
2. Click **"+ Create"**
3. Fill in:
   - **Resource group**: Select your resource group
   - **Name**: `xml-integration-law`
   - **Region**: Same as before
4. Click **"Review + Create"**, then **"Create"**

---

## Step 7: Create Application Insights

This monitors your application's performance and helps you troubleshoot issues.

1. Search for **"Application Insights"** and click it
2. Click **"+ Create"**
3. Fill in:
   - **Resource group**: Select your resource group
   - **Name**: `xml-integration-appinsights`
   - **Region**: Same as before
   - **Log Analytics Workspace**: Select the one you just created
4. Click **"Review + create"**, then **"Create"**
5. After creation, click **"Go to resource"**
6. In the Overview page, find **"Instrumentation Key"**
7. ✅ **Save this**: Copy the Instrumentation Key

---

## Step 8: Create App Service Plan

This is the computing power that will run your function.

1. Search for **"App Service plans"** and click it
2. Click **"+ Create"**
3. Fill in:
   - **Resource group**: Select your resource group
   - **Name**: `xml-integration-asp`
   - **Operating System**: Linux
   - **Region**: Same as before
   - **Pricing tier**: Click **"Explore pricing plans"**
     - Select **"Basic B1"** (or **"Free F1"** if available)
     - Click **"Select"**
4. Click **"Review + create"**, then **"Create"**

---

## Step 9: Create Function App

This is where your code will run automatically on a schedule.

1. Search for **"Function App"** and click it
2. Click **"+ Create"**
3. Fill in the **Basics** tab:
   - **Resource group**: Select your resource group
   - **Function App name**: `xml-integration-func` (must be globally unique)
   - **Runtime stack**: Python
   - **Version**: 3.11
   - **Region**: Same as before
   - **Operating System**: Linux
   - **Plan type**: App Service Plan
   - **App Service Plan**: Select the one you created
4. Click **"Next: Storage"**
5. **Storage account**: Select the storage account you created earlier
6. Click **"Next: Networking"**
7. **Enable network injection**: Yes
8. **Virtual Network**: Select your virtual network
9. **Subnet**: Select `function-subnet`
10. Click **"Review + create"**, then **"Create"**
11. Wait for deployment (2-3 minutes)

### Configure Function App Settings

1. After deployment, click **"Go to resource"**
2. In the left menu, click **"Configuration"** (under Settings)
3. Click **"+ New application setting"** and add each of these:

   | Name | Value |
   |------|-------|
   | `APPINSIGHTS_INSTRUMENTATIONKEY` | Your Application Insights key |
   | `SQL_SERVER_FQDN` | Your SQL Server name (e.g., `xyz.database.windows.net`) |
   | `SQL_DATABASE_NAME` | `xml_database` |
   | `SQL_TABLE_NAME` | `xml_data` |
   | `SQL_ADMIN_USERNAME` | `sqladmin` |
   | `SQL_CONNECTION_STRING` | `Server=tcp:YOUR_SQL_SERVER.database.windows.net,1433;Initial Catalog=xml_database;User ID=sqladmin;Password=YOUR_PASSWORD;Encrypt=True;` |
   | `MANAGED_IDENTITY_CLIENT_ID` | Your Managed Identity Client ID |
   | `VENDOR_API_URL` | Your vendor's API URL |
   | `VENDOR_API_KEY` | Your vendor's API key |

4. Click **"Save"** at the top
5. Click **"Continue"** when prompted

### Enable Managed Identity

1. In the left menu, click **"Identity"** (under Settings)
2. Click the **"User assigned"** tab
3. Click **"+ Add"**
4. Select your managed identity (`xml-integration-identity`)
5. Click **"Add"**

---

## Step 10: Set Up Permissions

Now we need to give your Function App permission to access the Storage and Database.

### Storage Account Permissions

1. Go to your **Storage Account**
2. In the left menu, click **"Access Control (IAM)"**
3. Click **"+ Add"** → **"Add role assignment"**
4. **Role**: Search for and select **"Storage Blob Data Contributor"**
5. Click **"Next"**
6. **Assign access to**: Managed identity
7. Click **"+ Select members"**
8. **Managed identity**: User-assigned managed identity
9. Select your identity (`xml-integration-identity`)
10. Click **"Select"**, then **"Review + assign"**, then **"Review + assign"** again

### SQL Database Permissions

1. Go to your **SQL Database** (not the server)
2. In the left menu, click **"Access Control (IAM)"**
3. Click **"+ Add"** → **"Add role assignment"**
4. **Role**: Search for and select **"SQL DB Contributor"**
5. Click **"Next"**
6. **Assign access to**: Managed identity
7. Click **"+ Select members"**
8. **Managed identity**: User-assigned managed identity
9. Select your identity (`xml-integration-identity`)
10. Click **"Select"**, then **"Review + assign"**, then **"Review + assign"** again

---

## Step 11: Verify Everything

Let's make sure everything is set up correctly:

1. Go to your **Resource Group**
2. You should see these resources:
   - ✅ Storage account
   - ✅ Virtual network
   - ✅ Managed identity
   - ✅ SQL server
   - ✅ SQL database
   - ✅ Log Analytics workspace
   - ✅ Application Insights
   - ✅ App Service plan
   - ✅ Function App

---

## Next Steps

Now that your infrastructure is ready:

1. **Deploy your Function code**: Use VS Code with Azure Functions extension or Azure CLI
2. **Create the SQL table**: Connect to your database and run your table creation script
3. **Test the function**: Trigger it manually to ensure it works
4. **Set up the timer**: Configure it to run on your desired schedule

---

## Cost Estimate

With the basic configuration:
- Storage Account (LRS): ~$0.02/GB/month
- SQL Database (Basic): ~$5/month
- App Service Plan (Basic B1): ~$13/month
- Application Insights: Free tier (5GB/month)
- Virtual Network: Free
- **Total**: ~$18-20/month

---

## Troubleshooting

### Can't connect to SQL Database
- Check firewall rules allow Azure services
- Verify your SQL password is correct
- Make sure you're using the full server name (with `.database.windows.net`)

### Function App not starting
- Check Application Settings are configured correctly
- Verify the storage account connection string
- Check the App Service Plan is running

### Permission errors
- Verify Managed Identity is assigned to the Function App
- Check role assignments on Storage and SQL Database
- Wait 5-10 minutes for permissions to propagate

---

## Cleanup (When Done Testing)

To avoid ongoing charges:

1. Go to your **Resource Group**
2. Click **"Delete resource group"** at the top
3. Type the resource group name to confirm
4. Click **"Delete"**

This will delete everything at once!

---

## Need Help?

- **Azure Documentation**: https://docs.microsoft.com/azure
- **Azure Support**: Available in the Azure Portal (? icon)
- **Community Forums**: https://docs.microsoft.com/answers/products/azure

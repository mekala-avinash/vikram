# Phase 3 & 4 Demo Setup Guide — Azure Portal

> **Assumption**: Phase 1 & 2 are already deployed. You have:
> - A Resource Group (e.g., `xmlintegration-demo-rg`)
> - A SQL Database with `EDIIntegrationTable` containing rows at **Status = 2** (Canonical XML Generated)
> - A Service Bus namespace with the topic `invoice-ready-for-transformation`
> - A Managed Identity
>
> **Goal**: Set up Phase 3 (Logic App XSLT transform) and Phase 4 (Function App KSeF submission) and run a live demo.

---

## What You'll Build

| Phase | Component | What it does |
|-------|-----------|-------------|
| 3 | Logic App Standard | Picks up message from Service Bus topic → fetches Canonical XML from DB → transforms via XSLT → saves KSeF XML |
| 4 | Azure Function (SubmitToPartner) | Reads KSeF XML from DB → POSTs to KSeF API → updates status to Success/Failed |

**Estimated time**: 30–40 minutes

---

## Phase 3: Logic App (XSLT Transformation)

### Step 3.1 — Create a Storage Account for Logic App

Logic App Standard needs its own storage account for runtime state.

1. In the Azure Portal search bar, type **"Storage accounts"** → click it
2. Click **"+ Create"**
3. Fill in:
   - **Resource group**: Select your existing resource group
   - **Storage account name**: `xmlintegrationlast` (must be lowercase, no spaces)
   - **Region**: Same as your other resources
   - **Redundancy**: LRS
4. Click **"Review + create"** → **"Create"**

---

### Step 3.2 — Create an App Service Plan for Logic App

This is the compute that runs the Logic App.

1. Search for **"App Service plans"** → click it
2. Click **"+ Create"**
3. Fill in:
   - **Resource group**: Your resource group
   - **Name**: `xmlintegration-la-asp`
   - **Operating System**: **Windows** ← important!
   - **Region**: Same as before
   - **Pricing tier**: Click **"Explore pricing plans"** → select **"Workflow Standard WS1"** → **"Select"**
4. Click **"Review + create"** → **"Create"**

---

### Step 3.3 — Create the Logic App Standard

1. Search for **"Logic apps"** → click it
2. Click **"+ Add"**
3. Select **"Standard"** (not Consumption) → click **"Select"**
4. Fill in the **Basics** tab:
   - **Resource group**: Your resource group
   - **Logic App name**: `xmlintegration-demo-la`
   - **Region**: Same as before
   - **Windows Plan**: Select the plan you just created (`xmlintegration-la-asp`)
   - **Pricing plan**: WS1
5. Click **"Next: Storage"**
6. **Storage account**: Select the storage account you created (`xmlintegrationlast`)
7. Click **"Review + create"** → **"Create"**
8. Wait ~2 minutes, then click **"Go to resource"**

---

### Step 3.4 — Add the XSLT Map

The Logic App needs the XSLT file to transform Canonical XML → KSeF format.

1. In your Logic App, click **"Artifacts"** in the left menu (under Development Tools)
2. Click **"Maps"**
3. Click **"+ Add"**
4. Fill in:
   - **Name**: `KsefFa3`
   - **Map type**: XSLT
   - **Map**: Upload the file `logic-app/maps/KsefFa3.xslt` from the project
5. Click **"OK"**

---

### Step 3.5 — Create the Workflow

1. In your Logic App, click **"Workflows"** in the left menu
2. Click **"+ Add"**
3. Fill in:
   - **Name**: `TransformToKsefXml`
   - **State type**: Stateful
4. Click **"Create"**
5. Click on the workflow name to open it
6. Click **"Designer"** in the left menu

#### Add the Service Bus Trigger

7. In the designer, click **"Add a trigger"**
8. Search for **"Service Bus"** → select **"When messages are available in a topic subscription (peek-lock)"**
9. Fill in the connection:
   - **Connection name**: `ServiceBusConnection`
   - **Connection string**: Paste your Service Bus **primary connection string**
     - (Find it: Service Bus namespace → Shared access policies → RootManageSharedAccessKey → Primary Connection String)
10. Click **"Create"**
11. Configure the trigger:
    - **Topic name**: `invoice-ready-for-transformation`
    - **Subscription name**: `logic-app-transform`
    - **Maximum message count**: 1

#### Add SQL Action — Get Canonical XML

12. Click **"+"** below the trigger → **"Add an action"**
13. Search for **"SQL Server"** → select **"Execute a SQL query (V2)"**
14. Fill in the connection:
    - **Connection name**: `SqlConnection`
    - **Authentication type**: SQL Server Authentication
    - **SQL server name**: Your SQL server FQDN (e.g., `xyz.database.windows.net`)
    - **SQL database name**: Your database name
    - **Username / Password**: Your SQL admin credentials
15. Click **"Create"**
16. In the **Query** field, paste:
    ```sql
    SELECT CanonicalXml FROM dbo.EDIIntegrationTable
    WHERE EDIIntegrationId = @EDIIntegrationId
    ```
17. Under **Query Parameters**, add:
    - Name: `EDIIntegrationId`
    - Value: Click in the field → select **"Expression"** → type:
      `int(json(base64ToString(triggerBody()?['ContentData']))['EDIIntegrationId'])`

#### Add Transform XML Action

18. Click **"+"** → **"Add an action"**
19. Search for **"Transform XML"** → select it (built-in)
20. Fill in the three fields:
    - **Content**: The SQL step returns a nested structure, so you can't pick `CanonicalXml` directly from Dynamic content. Instead:
      1. Click inside the **Content** field
      2. Click the **"Expression"** tab (not Dynamic content)
      3. Paste this expression:
         ```
         body('Execute_a_SQL_query_(V2)')?['resultSets']?[0]?[0]?['CanonicalXml']
         ```
         > ⚠️ The name `Execute_a_SQL_query_(V2)` must match your SQL step name exactly. Check it by clicking the SQL step — the name appears at the top.
      4. Click **"OK"**
    - **Map Source**: Select **"LogicApp"** from the dropdown
    - **Map Name**: Select **"KsefFa3"** from the dropdown

    > **Why the expression?** The SQL action wraps results in `resultSets[0][0]` — that's why you only see "Query results" and "Result sets" in Dynamic content, not the individual column names. The expression drills into the first result set, first row, and extracts the `CanonicalXml` column.

#### Add SQL Action — Save KSeF XML

21. Click **"+"** → **"Add an action"**
22. Search for **"SQL Server"** → select **"Execute stored procedure (V2)"**
23. Select your SQL connection
24. Fill in:
    - **Procedure name**: `[dbo].[usp_InsertPartnerSubmission]`
    - **EDIIntegrationId**: (Dynamic content → EDIIntegrationId from trigger)
    - **KSeFXml**: (Dynamic content → Transformed XML output)

#### Complete the Service Bus Message

25. Click **"+"** → **"Add an action"**
26. Search for **"Service Bus"** → select **"Complete the message in a topic subscription"**
27. Fill in:
    - **Topic name**: `invoice-ready-for-transformation`
    - **Subscription name**: `logic-app-transform`
    - **Lock token**: (Dynamic content → Lock Token from trigger)

28. Click **"Save"** at the top

---

### Step 3.6 — Test Phase 3

1. Go to your **Service Bus namespace** → **Topics** → `invoice-ready-for-transformation`
2. Click **"Service Bus Explorer"**
3. Click **"Send messages"**
4. Paste this JSON as the message body (replace with a real EDIIntegrationId from your DB):
   ```json
   {"EDIIntegrationId": 1}
   ```
5. Click **"Send"**
6. Go back to your Logic App → **"Workflows"** → **"TransformToKsefXml"** → **"Run History"**
7. ✅ You should see a successful run appear within 30 seconds
8. Verify in SQL: `SELECT * FROM dbo.PartnerSubmission WHERE EDIIntegrationId = 1`
   - Should show a new row with `Status = 1` (Ready to Submit)

---

## Phase 4: SubmitToPartner Function

### Step 4.1 — Create the Function App

> **Note**: If you already have a Function App from Phases 1 & 2, you can add the new function to it and skip to Step 4.3.

1. Search for **"Function App"** → click it
2. Click **"+ Create"**
3. Fill in:
   - **Resource group**: Your resource group
   - **Function App name**: `xmlintegration-demo-func`
   - **Runtime stack**: Python
   - **Version**: 3.11
   - **Region**: Same as before
   - **Operating System**: Linux
   - **Plan type**: Consumption (Serverless)
4. Click **"Review + create"** → **"Create"**

---

### Step 4.2 — Configure Application Settings

1. Go to your Function App → **"Configuration"** (under Settings)
2. Click **"+ New application setting"** for each of these:

   | Name | Value |
   |------|-------|
   | `SQL_CONNECTION_STRING` | `Server=tcp:YOUR_SERVER.database.windows.net,1433;Initial Catalog=YOUR_DB;User ID=sqladmin;Password=YOUR_PASSWORD;Encrypt=True;` |
   | `KSEF_API_URL` | `https://ksef-test.mf.gov.pl/api/online/Invoice/Send` |
   | `KSEF_API_KEY` | Your KSeF API key (or leave empty for demo) |
   | `SUBMIT_TIMER_SCHEDULE` | `0 */5 * * * *` (every 5 minutes) |
   | `SUBMIT_BATCH_SIZE` | `10` |

3. Click **"Save"** → **"Continue"**

---

### Step 4.3 — Deploy the Function Code

#### Option A: Using VS Code (Recommended for demo)

1. Install the **Azure Functions** extension in VS Code
2. Open the `function-app/` folder
3. Press **F1** → type **"Azure Functions: Deploy to Function App"**
4. Select your Function App → click **"Deploy"**

#### Option B: Using Azure Portal (Quick demo)

1. In your Function App, click **"Functions"** → **"+ Create"**
2. Select **"Timer trigger"**
3. Fill in:
   - **Name**: `SubmitToPartner`
   - **Schedule**: `0 */5 * * * *`
4. Click **"Create"**
5. Click **"Code + Test"**
6. Replace the code with the contents of `function-app/SubmitToPartner/__init__.py`
7. Click **"Save"**

---

### Step 4.4 — Run the SQL Scripts

Before testing, create the stored procedures in your database.

1. Go to your **SQL Database** in Azure Portal
2. Click **"Query editor (preview)"** in the left menu
3. Log in with your SQL admin credentials
4. Copy and paste the contents of `sql/usp_InsertPartnerSubmission.sql` → click **"Run"**
5. Copy and paste the contents of `sql/usp_UpdatePartnerSubmissionStatus.sql` → click **"Run"**

---

### Step 4.5 — Test Phase 4

#### Manual trigger for demo

1. Go to your Function App → **"Functions"** → click **"SubmitToPartner"**
2. Click **"Code + Test"**
3. Click **"Test/Run"** at the top
4. Click **"Run"**
5. Watch the **Logs** panel at the bottom

#### What to show the team

- **Logs panel**: Shows each submission being processed
  ```
  Found 1 pending submission(s) to process.
  Processing PartnerSubmissionId=1 (EDIIntegrationId=1)
  SUCCESS: PartnerSubmissionId=1 | KSeF Ref=REF-20260218...
  ```
- **SQL verification**: Run this query in Query Editor:
  ```sql
  SELECT
      ps.PartnerSubmissionId,
      ps.EDIIntegrationId,
      ps.Status,
      ps.KSeFReferenceNumber,
      ps.SubmittedAt,
      edi.Status AS EDIStatus
  FROM dbo.PartnerSubmission ps
  JOIN dbo.EDIIntegrationTable edi ON ps.EDIIntegrationId = edi.EDIIntegrationId
  ORDER BY ps.CreatedAt DESC
  ```
  - `Status = 2` = ✅ Submitted successfully
  - `Status = 3` = ❌ Failed (check `ErrorMessage` column)

---

## Full End-to-End Demo Flow

For a complete demo showing both phases:

```
1. Place a message on the Service Bus topic (Step 3.6)
   → Logic App triggers automatically
   → Canonical XML fetched from DB
   → XSLT transformation applied
   → KSeF XML saved to PartnerSubmission (Status=1)

2. Manually trigger SubmitToPartner function (Step 4.5)
   → Picks up Status=1 row
   → Calls KSeF API
   → Updates to Status=2 (success) or Status=3 (failed)
   → KSeF reference number saved
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Logic App run fails at SQL step | Check SQL connection string in Logic App connection settings |
| Logic App run fails at Transform step | Verify `KsefFa3.xslt` was uploaded correctly in Artifacts → Maps |
| No messages received by Logic App | Check Service Bus subscription name matches exactly: `logic-app-transform` |
| Function shows "No pending submissions" | Ensure Phase 3 ran first and created a row in `PartnerSubmission` with `Status=1` |
| KSeF API returns 401 | Check `KSEF_API_KEY` in Function App configuration |
| KSeF API returns 400 | The XSLT output doesn't match KSeF schema — update `KsefFa3.xslt` field mappings |

---

## Cost for Demo (Approximate)

| Resource | Cost |
|----------|------|
| Logic App Standard WS1 | ~$1.50/day |
| Service Bus Standard | ~$0.01/day |
| Function App (Consumption) | Free for demo volume |
| **Total** | **~$1.50/day** — remember to delete after demo! |

### Clean Up After Demo
1. Go to your Resource Group
2. Select the Logic App, Logic App Plan, and Logic App Storage Account
3. Click **"Delete"** to remove just these resources (keeps Phase 1 & 2 intact)

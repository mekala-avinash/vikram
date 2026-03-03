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
| 3 | Logic App Standard | Picks up message from Service Bus topic → fetches Canonical XML from DB → transforms via XSLT map → saves KSeF XML |
| 4 | Logic App (SubmitToPartner) | Reads KSeF XML from DB → fetches OAuth Token → POSTs to SmartKSeF API → updates status to Success/Failed |

**Estimated time**: 30–40 minutes

---

## Phase 3: Logic App (XSLT XML Transformation)

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

The Logic App needs the XSLT file to transform Canonical XML → KSeF FA(3) XML format.

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
    - **PartnerXML**: (Dynamic content → Transformed XML output)

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

## Phase 4: SubmitToPartner Logic App

### Step 4.1 — Create the `SubmitToPartner` Workflow

Since we are replacing the Function App with a Logic App for Phase 4, we will add a new workflow to the existing Logic App created in Phase 3.

1. Go to your Logic App `xmlintegration-demo-la`
2. Click **"Workflows"** in the left menu
3. Click **"+ Add"**
4. Fill in:
   - **Name**: `SubmitToPartner`
   - **State type**: Stateful
5. Click **"Create"**
6. Click on the workflow name to open it
7. Click **"Designer"** in the left menu

### Step 4.2 — Add the Service Bus Queue Trigger

1. In the designer, click **"Add a trigger"**
2. Search for **"Service Bus"** → select **"When one or more messages arrive in a queue (auto-complete)"**
3. Configure the trigger:
   - **Queue name**: `invoice-ready-for-submission`

### Step 4.3 — Add Parse JSON Action

1. Click **"+"** below the trigger → **"Add an action"**
2. Search for **"Data Operations"** → select **"Parse JSON"**
3. Configure the action:
   - **Content**: `triggerBody()?['ContentData']` (Needs to be parsed from Base64 via expression: `@base64ToString(triggerBody()?['ContentData'])`)
   - **Schema**:
     ```json
     {
         "type": "object",
         "properties": {
             "PartnerSubmissionId": { "type": "integer" }
         }
     }
     ```

### Step 4.4 — Add SQL Action — Get Partner XML

1. Click **"+"** below the Parse JSON action → **"Add an action"**
2. Search for **"SQL Server"** → select **"Execute a SQL query (V2)"**
3. Select the `<SqlConnection>` we created in Phase 3
4. In the **Query** field, paste:
   ```sql
   SELECT PartnerSubmissionId, PartnerXML FROM [dbo].[PartnerSubmission] WHERE PartnerSubmissionId = @PartnerSubmissionId
   ```
5. In the **Query Parameters**, configure:
   - Name: `PartnerSubmissionId`
   - Value: Dynamic content `PartnerSubmissionId` from the Parse JSON step.

### Step 4.5 — Configure App Settings for OAuth

Before adding the HTTP actions, add your SmartKSeF API credentials to your Logic App.
1. Go to your Logic App → **Environment Variables** (or **Configuration** depending on portal version)
2. Add the following app settings:
   - `SMARTKSEF_CLIENT_ID`: Your Client ID
   - `SMARTKSEF_CLIENT_SECRET`: Your Client Secret

### Step 4.6 — Add OAuth2 HTTP Action

1. Before the **For each** loop, click **"+"** → **"Add an action"**
2. Search for **"HTTP"** → select **"HTTP"**
3. Rename the action to `Get_OAuth_Token`
4. Configure the HTTP action:
   - **Method**: `POST`
   - **URI**: `https://login.smartksef-staging.exorigo-upos.pl/d92dfc98-2b80-4938-97f5-d4bee2112678/oauth2/v2.0/token?p=B2C_1_susi_default`
   - **Headers**:
     - `Content-Type`: `application/x-www-form-urlencoded`
   - **Body**: `grant_type=client_credentials&client_id=@{appsetting('SMARTKSEF_CLIENT_ID')}&client_secret=@{appsetting('SMARTKSEF_CLIENT_SECRET')}&scope=https://login.smartksef-staging.exorigo-upos.pl/api/invoices/.default`

### Step 4.7 — Add Parse JSON Action

1. Below `Get_OAuth_Token`, add a **Parse JSON** action.
2. Rename it to `Parse_OAuth_Token`.
3. **Content**: Select **Body** from `Get_OAuth_Token` step in dynamic content.
4. **Schema**: Use the following schema:
   ```json
   {
       "type": "object",
       "properties": {
           "access_token": { "type": "string" },
           "token_type": { "type": "string" },
           "expires_in": { "type": "integer" }
       }
   }
   ```

### Step 4.8 — Add HTTP POST to SmartKSeF API

1. Below `Parse_OAuth_Token`, click **"+"** → **"Add an action"**
2. Search for **"HTTP"** → select **"HTTP"**
3. Rename the action to `POST_to_KSeF_API`
4. Configure the HTTP action:
   - **Method**: `POST`
   - **URI**: `https://api.smartksef-staging.exorigo-upos.pl/invoices`
   - **Headers**:
     - `Content-Type`: `application/x.ksef.invoice+xml`
     - `Accept`: `application/json`
     - `Authorization`: `Bearer @{body('Parse_OAuth_Token')?['access_token']}`
   - **Body**: Expression pointing to the PartnerXML from the SQL query step:
     ```
     body('Execute_a_SQL_query_(V2)')?['resultSets']?[0]?[0]?['PartnerXML']
     ```

### Step 4.9 — Add Condition for Success/Failure

1. Below the HTTP action, click **"+"** → **"Add an action"**
2. Search for **"Control"** → select **"Condition"**
3. Configure Condition:
   - First box (Expression): `outputs('POST_to_KSeF_API')['statusCode']`
   - Operator: `is greater than or equal to`
   - Second box: `200`
   - Click **Add** -> **Add row** (AND)
   - First box (Expression): `outputs('POST_to_KSeF_API')['statusCode']`
   - Operator: `is less than`
   - Second box: `300`

### Step 4.10 — True Branch (Success) — Update SQL

1. In the **True** branch, click **"Add an action"**
2. Select **"Execute a SQL query (V2)"**
3. **Query**:
   ```sql
   EXEC [dbo].[usp_UpdatePartnerSubmissionStatus] @PartnerSubmissionId = @Id, @Status = 2, @KSeFReferenceNumber = @Ref
   ```
4. **Query Parameters**:
   - `Id`: Expression `body('Parse_JSON')?['PartnerSubmissionId']`
   - `Ref`: Expression `coalesce(body('POST_to_KSeF_API')?['referenceNumber'], body('POST_to_KSeF_API')?['ReferenceNumber'], 'REF-LOGICAPP')`

### Step 4.11 — False Branch (Failed) — Update SQL

1. In the **False** branch, click **"Add an action"**
2. Select **"Execute a SQL query (V2)"**
3. **Query**:
   ```sql
   EXEC [dbo].[usp_UpdatePartnerSubmissionStatus] @PartnerSubmissionId = @Id, @Status = 3, @ErrorMessage = @Err
   ```
4. **Query Parameters**:
   - `Id`: Expression `body('Parse_JSON')?['PartnerSubmissionId']`
   - `Err`: Expression `substring(string(body('POST_to_KSeF_API')), 0, 500)`

5. Click **"Save"**

---

### Step 4.12 — Run the SQL Scripts

Before testing, create the stored procedures in your database.

1. Go to your **SQL Database** in Azure Portal
2. Click **"Query editor (preview)"** in the left menu
3. Log in with your SQL admin credentials
4. Copy and paste the contents of `sql/usp_InsertPartnerSubmission.sql` → click **"Run"**
5. Copy and paste the contents of `sql/usp_UpdatePartnerSubmissionStatus.sql` → click **"Run"**

---

### Step 4.13 — Test Phase 4

#### Manual trigger for demo

1. Go to your Logic App → **"Workflows"** → click **"SubmitToPartner"**
2. Click **"Overview"**
3. Click **"Run Trigger"** at the top
4. Wait a few seconds, then view the **Run History**

#### What to show the team

- **Run History**: Shows each action's inputs and outputs. Check the `For each` loop to see it iterate over submitted entries.
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

2. Phase 4 listens to the `invoice-ready-for-submission` Service Bus Queue.
   → Picks up the message containing the ID.
   → Fetches the XML by ID.
   → Calls KSeF API via HTTP action
   → Updates to Status=2 (success) or Status=3 (failed)
   → Completes Service Bus Message.

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Logic App run fails at SQL step | Check SQL connection string in Logic App connection settings |
| Logic App run fails at Transform step | Verify `KsefFa3.xslt` was uploaded correctly in Artifacts → Maps |
| No messages received by Logic App | Check Service Bus subscription name matches exactly: `logic-app-transform` |
| Function shows "No pending submissions" | Ensure Phase 3 ran first and created a row in `PartnerSubmission` with `Status=1` |
| HTTP action returns 401 | Check Authorization header in HTTP action |
| KSeF API returns 400 | The XSLT output doesn't match KSeF schema — update `KsefFa3.xslt` field mappings |

---

## Cost for Demo (Approximate)

| Resource | Cost |
|----------|------|
| Logic App Standard WS1 | ~$1.50/day (handles Phase 3 & 4) |
| Service Bus Standard | ~$0.01/day |
| **Total** | **~$1.50/day** — remember to delete after demo! |

### Clean Up After Demo
1. Go to your Resource Group
2. Select the Logic App, Logic App Plan, and Logic App Storage Account
3. Click **"Delete"** to remove just these resources (keeps Phase 1 & 2 intact)

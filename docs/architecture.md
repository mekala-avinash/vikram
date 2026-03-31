# KSeF Azure XML Integration — Architecture

## Overview

This integration receives invoices from eLIMS, transforms them to the KSeF FA(3) XML standard, and submits them to the SmartKSeF partner API.

```
eLIMS ERP
    │
    │  CanonicalInvoice XML
    ▼
Azure Service Bus Topic: invoice-ready-for-transformation
    │
    ▼
Logic App: TransformToKsefXml
    │  XSLT: KsefFa3.xslt (v8.0)
    │  Schema validation against FA3_schemat.xsd
    ▼
Azure Service Bus Queue: ksef-xml-ready-for-submission
    │
    ▼
Logic App: SubmitToPartner
    │  OAuth2 token acquisition (KSeF B2C)
    │  HTTP POST to SmartKSeF API
    ▼
SmartKSeF Partner API
```

---

## Repository Structure

```
azure-xml-integration/
│
├── deploy.sh                          # Multi-environment deploy script
├── .gitignore
├── README.md
│
├── logic-app-v2/                      # Logic App Standard deployment package
│   ├── workflows/
│   │   ├── TransformToKsefXml/
│   │   │   └── workflow.json          # Phase 3: Transform workflow
│   │   └── SubmitToPartner/
│   │       └── workflow.json          # Phase 4: Submit workflow
│   ├── maps/
│   │   └── KsefFa3.xslt              # XSLT v8.0 — CanonicalInvoice → FA(3)
│   ├── schemas/
│   │   ├── FA3_schemat.xsd            # KSeF FA(3) schema
│   │   ├── ElementarneTypyDanych_v10-0E.xsd
│   │   ├── KodyKrajow_v10-0E.xsd
│   │   └── StrukturyDanych_v10-0E.xsd
│   ├── connections.json               # Connector definitions (uses @appsetting)
│   └── parameters.json               # Placeholder — populated by deploy.sh
│
├── environments/
│   ├── parameters.example.json        # Template — copy & fill per environment
│   ├── dev/
│   │   └── parameters.json            # Dev-specific non-secret config
│   ├── staging/
│   │   └── parameters.json            # Staging non-secret config
│   └── production/
│       └── parameters.json            # Production non-secret config
│
├── tests/
│   ├── test_transform.py              # XSLT regression test runner
│   └── fixtures/
│       └── input_corrective.xml       # Canonical test input (corrective invoice)
│
└── docs/
    └── architecture.md                # This file
```

---

## Environment Configuration

All environment-specific values live in `environments/<env>/parameters.json`.

**Secrets** (e.g. `KsefClientSecret`) are **never stored** in this repo. They are injected using Azure Key Vault references:

```json
"KsefClientSecret": {
  "type": "SecureString",
  "value": "@Microsoft.KeyVault(SecretUri=https://<kv-name>.vault.azure.net/secrets/KsefClientSecret-Dev/)"
}
```

The Logic App's Managed Identity must have `Key Vault Secrets User` role on the vault.

---

## Deploying

```bash
# Deploy to dev
./deploy.sh --env dev

# Deploy to staging
./deploy.sh --env staging

# Deploy to production
./deploy.sh --env production
```

Set these environment variables before running for Integration Account uploads:
```bash
export AZURE_RESOURCE_GROUP="rg-ksef-staging"
export LOGIC_APP_INTEGRATION_ACCOUNT_NAME="ia-ksef-staging"
```

---

## XSLT Map — KsefFa3.xslt

- **Version**: v8.0 (production hardened)
- **Standard**: KSeF FA(3), schema v1-0E
- **Processor**: XSLT 1.0 (compatible with Azure Logic Apps, xsltproc, Saxon)

### Key features
- NaN-safe number formatting via `safe-amount` helper template
- Early payload validation with invoice-number-prefixed FATAL messages
- Bank account resolution from `Payment`, `Header`, and `Seller/BankDetails`
- No hardcoded secrets or dummy fallback values

---

## App Settings Required (Logic App Standard)

| Setting | Description |
|---|---|
| `ServiceBusConnectionString` | Azure Service Bus namespace connection string |
| `SqlConnectionString` | Azure SQL database connection string |
| `sql_ConnectionRuntimeUrl` | Managed API SQL connector runtime URL |
| `sql_ConnectionKey` | Managed API SQL connector key |
| `WORKFLOWS_SUBSCRIPTION_ID` | Azure subscription ID |
| `WORKFLOWS_RESOURCE_GROUP_NAME` | Resource group name |
| `WORKFLOWS_LOCATION_NAME` | Azure region (e.g. `westeurope`) |

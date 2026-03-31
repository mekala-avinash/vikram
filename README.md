# KSeF Azure XML Integration

Azure Logic App integration for submitting invoices to the Polish KSeF (Krajowy System e-Faktur) FA(3) standard via the SmartKSeF partner API.

## Quick Start

### Prerequisites
- Azure CLI (`az login`)
- Access to the Azure subscription and target resource group
- Key Vault configured with `KsefClientSecret-<env>` secret

### Deploy

```bash
# Clone the repo
git clone <repo-url>
cd azure-xml-integration

# Deploy to staging
./deploy.sh --env staging

# Deploy to production
export AZURE_RESOURCE_GROUP="rg-ksef-prod"
export LOGIC_APP_INTEGRATION_ACCOUNT_NAME="ia-ksef-prod"
./deploy.sh --env production
```

## Repository Layout

| Path | Purpose |
|---|---|
| `logic-app-v2/` | Logic App Standard deployment package |
| `logic-app-v2/maps/KsefFa3.xslt` | XSLT v8.0 — transforms CanonicalInvoice → KSeF FA(3) XML |
| `logic-app-v2/schemas/` | KSeF XSD schemas for validation |
| `logic-app-v2/workflows/` | Logic App workflow definitions |
| `environments/` | Per-environment parameter files (non-secret) |
| `environments/parameters.example.json` | Template — copy to create a new environment |
| `tests/` | XSLT regression test runner + fixture inputs |
| `docs/architecture.md` | Full architecture documentation |

## Configuration

Environment-specific values are in `environments/<env>/parameters.json`.  
**Secrets are stored in Azure Key Vault — never in this repo.**

See [docs/architecture.md](docs/architecture.md) for full details on:
- App Settings required
- Key Vault secret references
- Integration Account deployment

## Running Tests

```bash
cd tests
python test_transform.py
```

## XSLT Map

The XSLT (`logic-app-v2/maps/KsefFa3.xslt`) converts a `CanonicalInvoice` XML document to KSeF FA(3) format. It resolves bank account numbers from multiple input locations:

1. `Payment/BankAccount/AccountNumber`
2. `Header/BankAccount/AccountNumber`
3. `Seller/BankDetails/AccountNumber`
4. `Seller/BankAccount/AccountNumber`

See [docs/architecture.md](docs/architecture.md) for full XSLT feature list.

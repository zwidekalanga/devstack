# Usage

Once the stack is running, there are three ways to interact with the platform: through the REST API, by publishing transactions to Kafka, or through the admin portal.

## Admin Portal

The Fraud Ops Portal is a standalone React application where analysts review alerts, manage fraud rules, and monitor system activity. It runs outside Docker. With the backend services up:

```bash
cd fraud-ops-portal
pnpm install
pnpm dev
```

Open http://localhost:3000.

## Creating a Transaction via the REST API

The Core Banking API is the entry point for all transactions. When you create a transaction, the banking service calls Fraud Detection over gRPC for a real-time risk score and publishes the transaction to Kafka for background processing. The response includes a `fraud_evaluation` object with the `risk_score`, `decision`, and `triggered_rules`.

### 1. Get an access token

```bash
curl -s http://localhost:8001/api/v1/auth/admin/login \
  -d "username=admin&password=admin123"
```

Copy the `access_token` from the response.

### 2. Get a customer and account ID

```bash
curl -s http://localhost:8001/api/v1/customers?size=1 \
  -H "Authorization: Bearer <YOUR_TOKEN>" | python3 -m json.tool
```

Copy the `id` from the response (`CUSTOMER_ID`). Then fetch their account:

```bash
curl -s "http://localhost:8001/api/v1/accounts?customer_id=<CUSTOMER_ID>&size=1" \
  -H "Authorization: Bearer <YOUR_TOKEN>" | python3 -m json.tool
```

Copy the `id` from the response (`ACCOUNT_ID`).

### 3. Create a normal transaction

```bash
curl -s http://localhost:8001/api/v1/transactions \
  -H "Authorization: Bearer <YOUR_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "external_id": "TXN-TEST-001",
    "account_id": "<ACCOUNT_ID>",
    "customer_id": "<CUSTOMER_ID>",
    "type": "purchase",
    "amount": 250.00,
    "currency": "ZAR",
    "merchant_name": "Woolworths",
    "merchant_category": "5411",
    "channel": "pos",
    "country_code": "ZA",
    "device_id": "fp_abc123",
    "description": "Grocery purchase"
  }' | python3 -m json.tool
```

### 4. Create a fraud-triggering transaction

```bash
curl -s http://localhost:8001/api/v1/transactions \
  -H "Authorization: Bearer <YOUR_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "external_id": "TXN-FRAUD-001",
    "account_id": "<ACCOUNT_ID>",
    "customer_id": "<CUSTOMER_ID>",
    "type": "transfer",
    "amount": 150000.00,
    "currency": "ZAR",
    "channel": "online",
    "country_code": "KP",
    "merchant_name": "Pyongyang Transfer",
    "merchant_category": "crypto",
    "description": "High-risk transfer from sanctioned country"
  }' | python3 -m json.tool
```

## Generating Transactions via Kafka

You can also publish transactions directly to Kafka to simulate load or test the async pipeline.

### Publish bulk transactions

```bash
make dev.txn.kafka COUNT=1000
```

Publishes transactions to the `transactions.raw` Kafka topic. The consumer evaluates each one against the fraud rules and creates alerts for any that are flagged. 20% of generated transactions are high-risk.

### Run throughput benchmark

```bash
make dev.txn.benchmark COUNT=1000
```

Publishes 1000 transactions to Kafka, then polls the database until all are processed. Reports end-to-end throughput statistics including per-transaction rule evaluation times.

## Running Tests

```bash
make dev.test              # All tests with coverage
make dev.test.unit         # Unit tests only
make dev.test.integration  # Integration tests only
```

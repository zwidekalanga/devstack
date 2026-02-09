# Capitec Fraud Engine — Devstack

This is the local development environment for the Capitec Fraud Engine platform. It brings together three separate services into a single Docker Compose setup so you can run the full stack on your machine with a few Make commands.

## How It Works

The platform evaluates financial transactions for fraud in real time. When a transaction is created through the Core Banking API, two things happen: the banking service calls the Fraud Detection service over gRPC to get an immediate risk score, and it publishes the transaction to Kafka for background processing and alert creation.

The Fraud Detection service runs every enabled rule against the transaction and adds up the scores. Depending on the total, the transaction is either approved, flagged for manual review, or escalated automatically. Analysts can then manage these alerts through the Fraud Ops Portal.

Three services make this work:

- **[Core Banking](https://github.com/zwidekalanga/core-banking)** — Manages customers, accounts, and transactions. This is the entry point for all transaction activity. Runs on port 8001.
- **[Core Fraud Detection](https://github.com/zwidekalanga/core-fraud-detection)** — The rules engine. Evaluates transactions, calculates risk scores, and creates alerts. Powered by [pylitmus](https://pypi.org/project/pylitmus/). Runs on port 8000.
- **[Fraud Ops Portal](https://github.com/zwidekalanga/fraud-ops-portal)** — A React admin dashboard where analysts review alerts, manage rules, and monitor system activity. Runs on port 3000 outside of Docker.

The infrastructure underneath — PostgreSQL, Redis, Apache Kafka, and RabbitMQ — is all managed by Docker Compose.

## Getting Started

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) v4+
- GNU Make (pre-installed on macOS and Linux)
- Set `CAPITEC_DEVSTACK_WORKSPACE` in `.env` to the directory containing all service repos. The default value assumes they sit under the same parent directory. If your layout differs, set it to an absolute path.

### Quick Setup

```bash
git clone git@github.com:zwidekalanga/devstack.git
cd devstack
cp .env.example .env
make dev.clone
make dev.up
make dev.setup
```

This clones all three service repositories, starts the infrastructure and backend services, then runs database migrations and seeds initial data including default fraud rules and test users.

### Verify the Setup

Run `make dev.health` to check all services, or open the API docs directly:

- Core Banking — http://localhost:8001/docs
- Fraud Detection — http://localhost:8000/docs

Default credentials: **admin** / **admin123**

## Common Commands

```bash
make dev.up          # Start all services
make dev.down        # Stop all services
make dev.clean       # Stop and remove all volumes (full reset)
make dev.test        # Run all tests with coverage
make dev.health      # Health check all services
```

Run `make help` for the full list.

## Further Reading

- **[USAGE.md](USAGE.md)** — Admin portal, REST API walkthrough, Kafka transactions, and testing
- **[RULES.md](RULES.md)** — Fraud detection rules, scoring, and decision tiers

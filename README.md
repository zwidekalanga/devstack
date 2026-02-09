# Capitec Fraud Engine — Devstack

Local development environment for the Capitec Fraud Engine platform.

## Overview

I submitted the Fraud Rule Engine Service project. I had it setup as a set of microservices a fraud detection engine, a supporting banking system API and an admin portal to wrap the lot up. This devstack repo allows easey local setup with few Make commands to get everything running locally.

### Services

| Service | Repository | Description |
| --- | --- | --- |
| **Core Fraud Detection** | [core-fraud-detection](https://github.com/zwidekalanga/core-fraud-detection) | Rules engine, Kafka consumer, gRPC API, Celery workers |
| **Core Banking** | [core-banking](https://github.com/zwidekalanga/core-banking) | Customer, account, and transaction management |
| **Fraud Ops Portal** | [fraud-ops-portal](https://github.com/zwidekalanga/fraud-ops-portal) | React admin dashboard (optional, runs standalone) |

### Infrastructure

PostgreSQL, Redis, Apache Kafka (KRaft), and RabbitMQ — all managed via Docker Compose.

## Prerequisites

| Tool | Version | Install |
| --- | --- | --- |
| Docker Desktop | v4+ | [docker.com](https://www.docker.com/products/docker-desktop/) |
| GNU Make | 3.81+ | Pre-installed on macOS/Linux |

## Getting Started

### Step 1 — Clone this repo and configure the workspace

```bash
git clone git@github.com:zwidekalanga/devstack.git
cd devstack
cp .env.example .env
```

The `.env` we set `CAPITEC_DEVSTACK_WORKSPACE`, this is what the Makefile will use to find the all other services repos. The default value (..) assumes such layout:

```
capitec-swe-assessment/       <-- CAPITEC_DEVSTACK_WORKSPACE
  devstack/                   <-- this repo
  core-fraud-detection/
  core-banking/
  fraud-ops-portal/
```

If your layout differs, set an absolute path in `.env`:

```bash
CAPITEC_DEVSTACK_WORKSPACE=/Users/{username}/Workspace/capitec-swe-assessment
```

### Step 2 — Clone the service repositories

```bash
make dev.clone
```

This clones `core-fraud-detection`, `core-banking`, and `fraud-ops-portal` into the workspace directory.

### Step 3 — Start all services

```bash
make dev.up
```

This starts containers in order:
1. **Infrastructure** — Postgres, Redis, Kafka, RabbitMQ (waits for health checks)
2. **Core Banking** — Banking API on port 8001
3. **Core Fraud Detection** — Fraud API, gRPC server, Kafka consumer, Celery workers

### Step 4 — Run migrations and seed data

```bash
make dev.setup
```

This runs database migrations and seeds initial data for both services:
- **Core Banking** — creates the `admin_users` table and seeds three default users
- **Core Fraud Detection** — creates fraud tables and seeds default detection rules

### Step 5 — Verify

Open the API docs to confirm both services are running:

| Service | URL |
| --- | --- |
| Core Banking API | http://localhost:8001/docs |
| Fraud Detection API | http://localhost:8000/docs |

Login with the default credentials: **admin** / **admin123**

You can also run `make dev.health` to check all services at once.

## Running Tests

```bash
make dev.test              # All tests with coverage
make dev.test.unit         # Unit tests only
make dev.test.integration  # Integration tests only
```

## Stopping Services

```bash
make dev.down    # Stop all containers
make dev.clean   # Stop and remove all volumes (full reset)
```

## Admin Portal (Optional)

The Fraud Ops Portal is a standalone React app. With the backend services running:

```bash
cd fraud-ops-portal
pnpm install
pnpm dev
```

Available at http://localhost:3000. See the [fraud-ops-portal README](https://github.com/zwidekalanga/fraud-ops-portal) for details.

## Further Reading

- Run `make help` to see all available commands
- See [SUPPORT.md](SUPPORT.md) for port mappings, full command reference, and troubleshooting

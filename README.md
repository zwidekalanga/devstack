# Capitec Fraud Engine — Devstack

Local development environment for the Capitec Fraud Engine platform.

## Overview

The Capitec Fraud Engine is a microservices platform for real-time transaction fraud detection. This devstack orchestrates the local infrastructure and services needed for development.

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

**1. Clone this repository and configure the environment**

```bash
cd devstack
cp .env.example .env
```

The `.env` file sets `CAPITEC_DEVSTACK_WORKSPACE`, which tells the Makefile where to find the service repos. The default value (`..`) expects this layout:

```
your-workspace/
  devstack/                 # <-- you are here
  core-fraud-detection/
  core-banking/
  fraud-ops-portal/
```

If your layout differs, update `.env` with an absolute path:

```bash
CAPITEC_DEVSTACK_WORKSPACE=/Users/{username}/Workspace/capitec-swe-assessment
```

**2. Clone the service repositories**

```bash
make dev.clone
```

**3. Start all services**

```bash
make dev.up
```

This starts infrastructure first, waits for health checks, then brings up the banking and fraud detection services.

**4. Run migrations and seed data**

```bash
make dev.setup
```

Once running:

| Service | URL |
| --- | --- |
| Fraud Detection API | http://localhost:8000/docs |
| Core Banking API | http://localhost:8001/docs |

> **Default credentials:** admin / admin123

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

The Fraud Ops Portal is a standalone React application. With backend services running:

```bash
cd fraud-ops-portal
pnpm install
pnpm dev
```

Available at http://localhost:3000. See the [fraud-ops-portal README](https://github.com/zwidekalanga/fraud-ops-portal) for details.

## Getting Help

- Run `make help` to see all available commands
- See [SUPPORT.md](SUPPORT.md) for port mappings, full command reference, and troubleshooting
- Open an [issue](https://github.com/zwidekalanga/devstack/issues) for bugs or questions

## License

This project is proprietary and confidential.

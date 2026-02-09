# Capitec Fraud Engine — Devstack

Local development environment for the Capitec Fraud Engine platform.

## Prerequisites

| Tool | Version | Install |
| --- | --- | --- |
| Docker Desktop | v4+ | [docker.com](https://www.docker.com/products/docker-desktop/) |
| GNU Make | 3.81+ | Pre-installed on macOS/Linux |

## Getting Started

```bash
# 1. Navigate to devstack
cd devstack

# 2. Configure environment
cp .env.example .env
# Edit .env and set CAPITEC_DEVSTACK_WORKSPACE (see below)

# 3. Clone service repositories
make dev.clone

# 4. Start all services
make dev.up

# 5. Run migrations and seed data
make dev.setup
```

Once running, the following services are available:

| Service | URL |
| --- | --- |
| Fraud Detection API (Swagger) | http://localhost:8000/docs |
| Core Banking API (Swagger) | http://localhost:8001/docs |

> **Default credentials:** admin / admin123

## Running Tests

```bash
make dev.test            # All tests with coverage
make dev.test.unit       # Unit tests only
make dev.test.integration # Integration tests only
```

## Stopping Services

```bash
make dev.down   # Stop all containers
make dev.clean  # Stop and remove all volumes (full reset)
```

## Environment Configuration

`CAPITEC_DEVSTACK_WORKSPACE` must point to the **parent directory** that contains (or will contain) all service repos. The Makefile expects this layout:

```
<CAPITEC_DEVSTACK_WORKSPACE>/
  core-fraud-detection/
  core-banking/
  fraud-ops-portal/
  devstack/              # (this repo)
```

Since `devstack/` sits inside the workspace, the default value `..` (one level up) works when your directory structure looks like:

```
capitec-swe-assessment/  <-- this is the workspace
  devstack/
  core-fraud-detection/
  core-banking/
  fraud-ops-portal/
```

If your layout differs, set an absolute path in `.env`:

```bash
CAPITEC_DEVSTACK_WORKSPACE=/Users/{username}/Workspace/capitec-swe-assessment
```

## Admin Portal (Optional)

To run the Fraud Ops Portal UI, ensure the backend services are running, then:

```bash
cd fraud-ops-portal
pnpm install
pnpm dev
```

The portal will be available at http://localhost:3000. See [fraud-ops-portal/README.md](../fraud-ops-portal/README.md) for details.

## Further Reading

- [SUPPORT.md](SUPPORT.md) — Port mappings, full command reference, and troubleshooting

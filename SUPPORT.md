# Support

## Port Map

| Service | Host | Container |
| --- | ---: | ---: |
| PostgreSQL | 5433 | 5432 |
| Redis | 6380 | 6379 |
| RabbitMQ (AMQP) | 5672 | 5672 |
| RabbitMQ (Management) | 15672 | 15672 |
| Kafka | 9092 | 9092 |
| Kafka UI | 8080 | 8080 |
| Fraud Detection API | 8000 | 8000 |
| Core Banking API | 8001 | 8001 |

## Command Reference

Run `make help` for a complete list. Key commands grouped by category:

### Repositories

| Command | Description |
| --- | --- |
| `make dev.clone` | Clone all service repos |
| `make dev.pull` | Pull latest for all repos |
| `make dev.status` | Show git status across repos |

### Dependencies (local development without Docker)

| Command | Description |
| --- | --- |
| `make dev.deps` | Install Python packages for all services via `uv` |
| `make dev.deps.fraud` | Install fraud-detection packages only |
| `make dev.deps.banking` | Install core-banking packages only |

### Lifecycle

| Command | Description |
| --- | --- |
| `make dev.up` | Start all services (infra, banking, fraud) |
| `make dev.up.infra` | Start infrastructure only (Postgres, Redis, Kafka, RabbitMQ) |
| `make dev.up.banking` | Start core banking service only |
| `make dev.up.fraud` | Start fraud detection services only |
| `make dev.down` | Stop all services |
| `make dev.clean` | Stop and remove all volumes |
| `make dev.ps` | Show container status |
| `make dev.health` | Run health checks against all services |
| `make dev.logs` | Tail fraud service logs |
| `make dev.logs.infra` | Tail infrastructure logs |

### Database

| Command | Description |
| --- | --- |
| `make dev.migrate` | Run Alembic migrations |
| `make dev.migrate.new MSG="..."` | Generate a new migration |
| `make dev.seed` | Seed default fraud rules |
| `make dev.setup` | First-time setup (migrate + seed) |

### Testing & Quality

| Command | Description |
| --- | --- |
| `make dev.test` | Run all tests with coverage |
| `make dev.test.unit` | Run unit tests only |
| `make dev.test.integration` | Run integration tests only |
| `make dev.lint` | Run linter (ruff) |
| `make dev.format` | Format code (ruff) |
| `make dev.typecheck` | Run type checker (mypy) |

### Shell Access

| Command | Description |
| --- | --- |
| `make dev.shell.api` | Python shell in the API container |
| `make dev.shell.db` | PostgreSQL interactive terminal |
| `make dev.shell.redis` | Redis CLI |

## Troubleshooting

### Port conflicts

If ports are already in use, stop the conflicting process or adjust mappings in `docker-compose.yml`.

```bash
# Find what is using a port (e.g. 8000)
lsof -i :8000
```

### Kafka slow to start

Kafka can take 30–60 seconds to become healthy. `make dev.up` blocks until health checks pass. If it times out:

```bash
make dev.logs.infra
```

### Stale data after schema changes

If migrations fail against an existing volume, reset everything:

```bash
make dev.clean
make dev.up
make dev.setup
```

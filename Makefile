.PHONY: help \
	dev.clone dev.clone.https dev.pull dev.status dev.reset dev.deps dev.deps.fraud dev.deps.banking \
	dev.up dev.up.infra dev.up.banking dev.up.fraud dev.down dev.clean dev.restart dev.ps dev.health \
	dev.logs dev.logs.infra dev.build \
	dev.migrate dev.migrate.new dev.seed dev.setup \
	dev.test dev.test.unit dev.test.integration dev.lint dev.lint.fix dev.format dev.typecheck \
	dev.shell.api dev.shell.db dev.shell.redis dev.shell.rabbitmq \
	dev.generate dev.proto dev.proto.lint dev.proto.breaking \
	dev.kafka.topics dev.kafka.create-topics

# Default target
.DEFAULT_GOAL := help

# Load .env (CAPITEC_DEVSTACK_WORKSPACE, etc.)
-include .env
export

# Validate workspace is set
ifndef CAPITEC_DEVSTACK_WORKSPACE
$(error CAPITEC_DEVSTACK_WORKSPACE is not set. Copy .env.example to .env and set the workspace path.)
endif

# Colors
CYAN := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
RESET := \033[0m

# Compose commands — infra is local, services are found via workspace env var
INFRA := docker compose -f docker-compose.yml
FRAUD := docker compose -f $(CAPITEC_DEVSTACK_WORKSPACE)/core-fraud-detection/docker-compose.yml
BANKING := docker compose -f $(CAPITEC_DEVSTACK_WORKSPACE)/core-banking/docker-compose.yml

help: ## Show this help message
	@echo "$(CYAN)Capitec Devstack - Available Commands$(RESET)"
	@echo ""
	@echo "  Workspace: $(CAPITEC_DEVSTACK_WORKSPACE)"
	@echo ""
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_.-]+:.*?## / {printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# ==================== REPOS ====================

dev.clone: ## Clone all service repos (SSH)
	./repos.sh clone

dev.clone.https: ## Clone all service repos (HTTPS)
	./repos.sh clone_https

dev.pull: ## Pull latest for all service repos
	./repos.sh pull

dev.status: ## Show git status of all service repos
	./repos.sh status

dev.reset: ## Reset all service repos to default branch
	./repos.sh reset

# ==================== DEPENDENCIES ====================

dev.deps: dev.deps.fraud dev.deps.banking ## Install Python dependencies for all services (requires uv)

dev.deps.fraud: ## Install fraud-detection dependencies via uv
	@echo "$(CYAN)Installing core-fraud-detection dependencies...$(RESET)"
	cd $(CAPITEC_DEVSTACK_WORKSPACE)/core-fraud-detection && uv sync
	@echo "$(GREEN)Fraud detection dependencies installed.$(RESET)"

dev.deps.banking: ## Install core-banking dependencies via uv
	@echo "$(CYAN)Installing core-banking dependencies...$(RESET)"
	cd $(CAPITEC_DEVSTACK_WORKSPACE)/core-banking && uv sync
	@echo "$(GREEN)Core banking dependencies installed.$(RESET)"

# ==================== LIFECYCLE ====================

dev.up: ## Start all services (infra first, then banking + fraud)
	@echo "$(CYAN)Starting infrastructure...$(RESET)"
	$(INFRA) up -d --wait
	@echo "$(GREEN)Infrastructure healthy.$(RESET)"
	@echo "$(CYAN)Starting core banking service...$(RESET)"
	$(BANKING) up -d --wait
	@echo "$(GREEN)Core banking healthy.$(RESET)"
	@echo "$(CYAN)Starting fraud detection service...$(RESET)"
	$(FRAUD) up -d --wait
	@echo "$(GREEN)Fraud detection healthy.$(RESET)"
	@echo ""
	@echo "$(GREEN)All services running:$(RESET)"
	@echo "  Banking API: http://localhost:8001/docs"
	@echo "  Fraud API:   http://localhost:8000/docs"
	@echo "  RabbitMQ:    http://localhost:15672 (guest/guest)"
	@echo "  Kafka UI:    http://localhost:8080"

dev.up.infra: ## Start only infrastructure services
	@echo "$(CYAN)Starting infrastructure...$(RESET)"
	$(INFRA) up -d

dev.up.banking: ## Start only core banking service
	@echo "$(CYAN)Starting core banking service...$(RESET)"
	$(BANKING) up -d

dev.up.fraud: ## Start only fraud detection services
	@echo "$(CYAN)Starting fraud detection service...$(RESET)"
	$(FRAUD) up -d

dev.down: ## Stop all services
	@echo "$(CYAN)Stopping all services...$(RESET)"
	$(FRAUD) down
	$(BANKING) down
	$(INFRA) down

dev.clean: ## Stop services and remove volumes
	@echo "$(CYAN)Stopping services and removing volumes...$(RESET)"
	$(FRAUD) down -v
	$(BANKING) down -v
	$(INFRA) down -v

dev.logs: ## View fraud service logs
	$(FRAUD) logs -f

dev.logs.infra: ## View infrastructure logs
	$(INFRA) logs -f

dev.restart: ## Restart fraud services
	$(FRAUD) restart

# ==================== DATABASE ====================

dev.migrate: ## Run database migrations
	@echo "$(CYAN)Running database migrations...$(RESET)"
	$(FRAUD) exec -T fraud-inbound-http alembic upgrade head

dev.migrate.new: ## Create new migration (usage: make dev.migrate.new MSG="description")
	$(FRAUD) exec fraud-inbound-http alembic revision --autogenerate -m "$(MSG)"

dev.seed: ## Seed default fraud rules
	@echo "$(CYAN)Seeding fraud rules...$(RESET)"
	$(FRAUD) exec -T fraud-inbound-http python -m scripts.seed_rules || true

dev.setup: ## First-time setup: migrate + seed
	@echo "$(CYAN)Running first-time setup...$(RESET)"
	$(FRAUD) exec -T fraud-inbound-http alembic upgrade head
	$(FRAUD) exec -T fraud-inbound-http python -m scripts.seed_rules || true
	@echo "$(GREEN)Setup complete!$(RESET)"

# ==================== TESTING ====================

dev.test: ## Run all tests
	$(FRAUD) exec -T fraud-inbound-http pytest tests/ -v --cov=app --cov-report=term-missing

dev.test.unit: ## Run unit tests only
	$(FRAUD) exec -T fraud-inbound-http pytest tests/unit/ -v

dev.test.integration: ## Run integration tests only
	$(FRAUD) exec -T fraud-inbound-http pytest tests/integration/ -v

# ==================== CODE QUALITY ====================

dev.lint: ## Run linter
	$(FRAUD) exec -T fraud-inbound-http ruff check app/

dev.lint.fix: ## Fix linting issues
	$(FRAUD) exec -T fraud-inbound-http ruff check app/ --fix

dev.format: ## Format code
	$(FRAUD) exec -T fraud-inbound-http ruff format app/

dev.typecheck: ## Run type checker
	$(FRAUD) exec -T fraud-inbound-http mypy app/

# ==================== UTILITIES ====================

dev.shell.api: ## Open Python shell in API container
	$(FRAUD) exec fraud-inbound-http python

dev.shell.db: ## Open PostgreSQL shell
	$(INFRA) exec postgres psql -U postgres -d core_fraud_detection

dev.shell.redis: ## Open Redis CLI
	$(INFRA) exec redis redis-cli

dev.shell.rabbitmq: ## Open RabbitMQ management CLI
	$(INFRA) exec rabbitmq rabbitmqctl

# ==================== GENERATION ====================

dev.generate: ## Generate test transactions (usage: make dev.generate COUNT=20)
	$(FRAUD) exec -T fraud-inbound-http python -m scripts.generate_transactions --count $(or $(COUNT),20)

dev.proto: ## Regenerate gRPC stubs from proto definitions
	@echo "$(CYAN)Regenerating gRPC stubs...$(RESET)"
	$(FRAUD) exec -T fraud-inbound-http bash scripts/generate_proto.sh
	@echo "$(GREEN)Stubs generated!$(RESET)"

dev.proto.lint: ## Lint proto files with Buf (requires buf CLI)
	@echo "$(CYAN)Linting proto files...$(RESET)"
	buf lint $(CAPITEC_DEVSTACK_WORKSPACE)/core-fraud-detection/proto
	@echo "$(GREEN)Proto lint passed!$(RESET)"

dev.proto.breaking: ## Check for breaking proto changes against main branch (requires buf CLI)
	@echo "$(CYAN)Checking for breaking changes...$(RESET)"
	cd $(CAPITEC_DEVSTACK_WORKSPACE) && buf breaking core-fraud-detection/proto --against '.git#branch=main,subdir=core-fraud-detection/proto'
	@echo "$(GREEN)No breaking changes detected!$(RESET)"

# ==================== HEALTH CHECKS ====================

dev.health: ## Check health of all services
	@echo "$(CYAN)Checking service health...$(RESET)"
	@curl -sf http://localhost:8001/health > /dev/null && echo "$(GREEN)✓ Banking API$(RESET)" || echo "$(RED)✗ Banking API$(RESET)"
	@curl -sf http://localhost:8000/health > /dev/null && echo "$(GREEN)✓ Fraud API$(RESET)" || echo "$(RED)✗ Fraud API$(RESET)"
	@curl -sf http://localhost:8000/ready > /dev/null && echo "$(GREEN)✓ Fraud API Ready$(RESET)" || echo "$(RED)✗ Fraud API Ready$(RESET)"
	@$(INFRA) exec -T postgres pg_isready -U postgres > /dev/null && echo "$(GREEN)✓ PostgreSQL$(RESET)" || echo "$(RED)✗ PostgreSQL$(RESET)"
	@$(INFRA) exec -T redis redis-cli ping > /dev/null && echo "$(GREEN)✓ Redis$(RESET)" || echo "$(RED)✗ Redis$(RESET)"
	@$(INFRA) exec -T rabbitmq rabbitmq-diagnostics -q ping > /dev/null 2>&1 && echo "$(GREEN)✓ RabbitMQ$(RESET)" || echo "$(RED)✗ RabbitMQ$(RESET)"
	@$(INFRA) exec -T kafka kafka-broker-api-versions --bootstrap-server localhost:29092 > /dev/null 2>&1 && echo "$(GREEN)✓ Kafka$(RESET)" || echo "$(RED)✗ Kafka$(RESET)"

# ==================== KAFKA ====================

dev.kafka.topics: ## List Kafka topics
	$(INFRA) exec -T kafka kafka-topics --bootstrap-server localhost:29092 --list

dev.kafka.create-topics: ## Create required Kafka topics
	@echo "$(CYAN)Creating Kafka topics...$(RESET)"
	$(INFRA) exec -T kafka kafka-topics --bootstrap-server localhost:29092 --create --if-not-exists --topic transactions.raw --partitions 3 --replication-factor 1
	$(INFRA) exec -T kafka kafka-topics --bootstrap-server localhost:29092 --create --if-not-exists --topic transactions.dlq --partitions 1 --replication-factor 1
	@echo "$(GREEN)Topics created!$(RESET)"

# ==================== BUILD ====================

dev.build: ## Build all Docker images
	$(FRAUD) build

dev.ps: ## Show status of all containers
	@echo "$(CYAN)=== Infrastructure ===$(RESET)"
	@$(INFRA) ps
	@echo ""
	@echo "$(CYAN)=== Core Banking Service ===$(RESET)"
	@$(BANKING) ps
	@echo ""
	@echo "$(CYAN)=== Fraud Detection Service ===$(RESET)"
	@$(FRAUD) ps

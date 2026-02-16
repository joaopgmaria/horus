.PHONY: help setup build up down shell test format credo dialyzer check db-setup db-migrate db-reset

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

setup: ## Initial project setup (scaffold Phoenix app)
	@echo "Building Docker image..."
	docker-compose build
	@echo "Scaffolding Phoenix project..."
	docker-compose run --rm app mix phx.new . --app horus --module Horus --database postgres --no-html --no-assets --binary-id
	@echo "Installing dependencies..."
	docker-compose run --rm app mix deps.get
	@echo "Setup complete! Run 'make up' to start the application."

build: ## Build Docker images
	docker-compose build

up: ## Start all services
	docker-compose up

down: ## Stop all services
	docker-compose down

shell: ## Open a shell in the app container
	docker-compose run --rm app sh

iex: ## Open IEx shell
	docker-compose run --rm app iex -S mix

test: ## Run tests
	docker-compose run --rm -e MIX_ENV=test app mix test

format: ## Format code
	docker-compose run --rm app mix format

format-check: ## Check code formatting
	docker-compose run --rm app mix format --check-formatted

credo: ## Run Credo linter
	docker-compose run --rm app mix credo --strict

dialyzer: ## Run Dialyzer type checker
	docker-compose run --rm app mix dialyzer

check: format-check credo test dialyzer deps-audit  ## Run all pre-commit checks

db-setup: ## Setup database
	docker-compose run --rm app mix ecto.setup

db-migrate: ## Run database migrations
	docker-compose run --rm app mix ecto.migrate

db-reset: ## Reset database
	docker-compose run --rm app mix ecto.reset

clean: ## Clean build artifacts
	docker-compose run --rm app mix clean
	docker-compose down -v

logs: ## Show application logs
	docker-compose logs -f app

deps-get: ## Install dependencies
	docker-compose run --rm app mix deps.get

deps-update: ## Update dependencies
	docker-compose run --rm app mix deps.update --all

deps-audit: ## Audit dependencies for vulnerabilities
	docker-compose run --rm app mix deps.audit

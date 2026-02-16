# Docker Development Setup

This guide explains how to set up and use the Docker-based development environment for Horus.

## Prerequisites

- Docker Desktop (or Docker Engine + Docker Compose)
- Make (optional, for convenience commands)

## Quick Start

### 1. Initial Setup

Scaffold the Phoenix project and install dependencies:

```bash
make setup
```

This will:
- Build the Docker image with Elixir 1.17 and Phoenix
- Run `mix phx.new` to create the Phoenix project structure
- Install all dependencies

### 2. Start the Application

```bash
make up
```

The application will be available at http://localhost:4000

Press `Ctrl+C` to stop the services.

## Common Commands

### Development

```bash
make up          # Start all services (app + database)
make down        # Stop all services
make logs        # View application logs
make shell       # Open shell in app container
make iex         # Open IEx (Elixir interactive shell)
```

### Code Quality

```bash
make test              # Run test suite
make format            # Format code
make format-check      # Check code formatting
make credo             # Run Credo linter
make dialyzer          # Run Dialyzer type checker
make check             # Run all pre-commit checks
```

### Database

```bash
make db-setup     # Setup database (create + migrate)
make db-migrate   # Run pending migrations
make db-reset     # Drop, create, and migrate database
```

### Dependencies

```bash
make deps-get       # Install dependencies
make deps-update    # Update all dependencies
```

### Maintenance

```bash
make clean       # Clean build artifacts and volumes
make build       # Rebuild Docker image
```

## Without Make

If you don't have Make installed, use Docker Compose directly:

```bash
# Setup
docker-compose build
docker-compose run --rm app mix phx.new . --app horus --module Horus --database postgres --no-html --no-assets --binary-id
docker-compose run --rm app mix deps.get

# Start services
docker-compose up

# Run tests
docker-compose run --rm app mix test

# Open shell
docker-compose run --rm app sh
```

## Development Workflow

### 1. Making Changes

The current directory is mounted as a volume, so changes to code are immediately reflected in the container.

### 2. Running Tests

Before committing:

```bash
make check
```

This runs formatting checks, linter, and tests.

### 3. Adding Dependencies

Edit `mix.exs`, then run:

```bash
make deps-get
```

### 4. Database Migrations

Create a migration:

```bash
docker-compose run --rm app mix ecto.gen.migration migration_name
```

Run migrations:

```bash
make db-migrate
```

## Troubleshooting

### Port Already in Use

If port 4000 or 5432 is already in use:

```bash
# Edit docker-compose.yml to change ports
# For app: "4001:4000"
# For db: "5433:5432"
```

### Permission Issues

If you encounter permission issues with volumes:

```bash
# On Linux, you may need to adjust ownership
docker-compose run --rm --user root app chown -R $(id -u):$(id -g) .
```

### Clean Start

To start fresh:

```bash
make clean
make setup
```

### Database Connection Issues

Ensure the database service is healthy:

```bash
docker-compose ps
```

The `db` service should show `healthy` status.

## Architecture

### Services

- **app**: Phoenix application (Elixir 1.17)
- **db**: PostgreSQL 15

### Volumes

- `postgres_data`: Persists database data
- `deps`: Caches Elixir dependencies
- `_build`: Caches compiled artifacts

### Environment Variables

Configured in `docker-compose.yml`:

- `DATABASE_URL`: PostgreSQL connection string
- `MIX_ENV`: Environment (dev/test/prod)
- `SECRET_KEY_BASE`: Phoenix secret key

## Next Steps

After setup:

1. Configure database in `config/dev.exs` (already set via DATABASE_URL)
2. Start implementing Phase 0 deliverables
3. Follow the Git workflow in CLAUDE.md for creating PRs

## Production Deployment

For production deployment, see the main README.md for Kubernetes/Docker deployment instructions.

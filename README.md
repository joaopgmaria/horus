# Horus - Validation Service

A flexible, expression-based validation service built with Elixir/Phoenix for validating JSON, XML, and YAML payloads against user-defined rules.

## Overview

Horus enables engineers to create reusable validation blueprints using a natural language DSL, instantiate them as rules with specific parameters, and execute validations via REST API or web UI. The service is designed for multi-tenant environments and supports both synchronous and asynchronous validation modes.

## Core Concepts

### Architecture: Blueprints → Rules → Validation

- **Blueprints**: Reusable validation templates written in DSL (like classes)
- **Rules**: Instantiated blueprints with bound parameters (like objects)
- **Rulesets**: Collections of rules grouped for specific use cases
- **Validation**: Execution of rulesets against payloads

### Expression-Based DSL

Everything is an expression that evaluates recursively:

```elixir
# Type checking
"${field} is a string"

# Field presence
"${field} is required"

# Value equality
"${field} is ${expected_value}"

# Conditional logic
"if ${country} is a string then ${postal_code} is required"
```

### Blueprint → Rule Example

**Blueprint** (template):
```
"${field} is a ${type}"
```

**Rule** (instance):
```elixir
parameters: %{
  "field" => "/customer/age",
  "type" => "integer"
}

# Bound expression: "/customer/age is a integer"
```

## Features

### MVP (Phase 1-3)
- ✅ Natural language DSL with 4 essential operators
- ✅ Expression-based AST compilation
- ✅ JSON format support
- ✅ Synchronous validation API
- ✅ Multi-tenant isolation
- ✅ Web UI for blueprint/rule management
- ✅ Validation testing interface

### v1.0 (Phase 4-6)
- 🔄 Asynchronous validation with Oban
- 🔄 Polling API with progress tracking
- 🔄 Rule versioning system
- 🔄 XML format plugin
- 🔄 Additional comparison operators

### Future Enhancements
- 📋 Complete operator set (aggregates, composites, functions)
- 📋 Pluggable operator system
- 📋 Real-time dashboard with metrics
- 📋 Admin UI for user/tenant management
- 📋 Advanced caching layer
- 📋 YAML & Protocol Buffers support

## DSL Operators (MVP)

| Operator | Example | Description |
|----------|---------|-------------|
| `is a` | `${age} is a number` | Type checking |
| `is required` | `${email} is required` | Field presence |
| `is` / `equals` | `${status} is "active"` | Value equality (`is` is an alias for `equals`) |
| `if...then` | `if ${type} is "premium" then ${card} is required` | Conditional logic |

See [Blueprint DSL & Compilation](docs/notion/blueprint-dsl.md) for complete operator reference.

## API

### Authentication
```bash
Authorization: Bearer YOUR_API_KEY
```

### Create Validation (Sync)
```bash
POST /v1/validations
{
  "ruleset": "order_validation",
  "payload": {
    "order_id": "12345",
    "total": 99.99
  },
  "mode": "sync"
}
```

### Create Validation (Async)
```bash
POST /v1/validations
{
  "ruleset": "bulk_import",
  "payload": {...},
  "mode": "async",
  "callback_url": "https://myapp.com/webhooks/horus"
}
```

### Get Validation Status
```bash
GET /v1/validations/{id}
```

**Import Postman Collection**: [`Horus_API.postman_collection.json`](Horus_API.postman_collection.json)

## Tech Stack

- **Framework**: Phoenix 1.7+ (Elixir)
- **Database**: PostgreSQL 15+
- **Parser**: NimbleParsec for DSL compilation
- **Background Jobs**: Oban (for async validation)
- **UI**: Phoenix LiveView
- **Testing**: ExUnit + Mox
- **Deployment**: Docker Compose

## Project Structure

```
horus/
├── lib/
│   ├── horus/
│   │   ├── blueprint/          # DSL parser & compiler
│   │   ├── expression/         # Expression types & evaluator
│   │   ├── engine/             # Rule execution engine
│   │   ├── format_plugin/      # JSON/XML/YAML plugins
│   │   └── rules/              # Rule management
│   └── horus_web/
│       ├── controllers/        # REST API
│       └── live/               # LiveView UI
├── priv/
│   └── repo/migrations/        # Database migrations
└── test/
```

## Getting Started

### Prerequisites
- Elixir 1.17+
- PostgreSQL 15+
- Docker (optional)

### Setup

```bash
# Clone repository
git clone https://github.com/joaopgmaria/horus.git
cd horus

# Install dependencies
mix deps.get

# Setup database
mix ecto.setup

# Start server
mix phx.server

# Visit http://localhost:4000
```

### Running Tests
```bash
mix test
```

### Docker Compose
```bash
docker-compose up
```

## Documentation

- **[CLAUDE.md](CLAUDE.md)**: AI assistant context and project guidelines
- **[Implementation Plan](docs/IMPLEMENTATION_PLAN.md)**: Phased development roadmap
- **[API Reference](docs/API.md)**: Complete REST API documentation
- **[Blueprint DSL](docs/BLUEPRINT_DSL.md)**: DSL syntax and examples
- **[Architecture](docs/ARCHITECTURE.md)**: System design and components

## Multi-Tenancy

- **Row-level isolation**: Rules and validations are tenant-scoped
- **Global blueprints**: Shared across all tenants
- **API key authentication**: Per-user access control
- **Role hierarchy**: User, Engineer, Admin

## Execution Strategies

| Strategy | Behavior |
|----------|----------|
| `run_all` (default) | Execute all rules, return all results |
| `fail_fast` | Stop on first failure |
| `after_n_errors` | Stop after N failures |

## Format Plugins

Horus uses a plugin architecture for payload format support:

- **JSON** (built-in): JSONPath syntax
- **XML** (v1.0): XPath syntax
- **YAML** (future): YAML path syntax
- **Protocol Buffers** (future): Field descriptors

All plugins translate from Horus universal path syntax to format-specific paths.

## Async Result Delivery

- **Polling** (default): Client polls `GET /validations/:id`
- **Webhooks**: Server POSTs to callback URL
- **SSE** (future): Server-Sent Events for streaming
- **Message Queue** (future): Publish to queue

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Roadmap

See [Implementation Plan](docs/IMPLEMENTATION_PLAN.md) for detailed roadmap.

**Current Phase**: Phase 0 - Foundation

**Next Milestones**:
- Phase 1: Core Engine (DSL parser, expression evaluator, rule execution)
- Phase 2: API & Multi-tenancy
- Phase 3: Basic UI for Testing

## Contact

- **Author**: João Maria
- **GitHub**: [@joaopgmaria](https://github.com/joaopgmaria)
- **Project**: [https://github.com/joaopgmaria/horus](https://github.com/joaopgmaria/horus)

---

Built with ❤️ using Elixir and Phoenix

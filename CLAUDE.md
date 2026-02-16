# Horus - Elixir Validation Service

## Project Overview
Horus is a Phoenix-based validation service designed to run flexible, configurable validations over generic payloads. It uses a natural language DSL for defining validation logic, enabling non-technical users to create and manage validation rules without writing code.

## Tech Stack
- **Framework**: Phoenix
- **Language**: Elixir
- **Build Tool**: Mix
- **Database**: PostgreSQL with Ecto
- **Job Queue**: Oban
- **Cache**: Cachex
- **Monitoring**: Telemetry + Prometheus + Grafana
- **Target**: Multi-tenant validation engine with plugin architecture

## Core Concepts

### Three-Tier Architecture
1. **Blueprints**: Engineer-created templates using natural language DSL, compiled to AST
2. **Rules**: User-created instances of blueprints with specific parameters
3. **Attributes**: Format-agnostic path expressions (`/field`, `/parent/child`, `/array[1]`, `/array[*]`) targeting specific payload fields

**Analogy**: Blueprint is to Rule as Class is to Object

### Path Syntax
- **Format-Agnostic**: Universal path syntax works across all formats
- **Simple**: `/name` (root field), `/customer/email` (nested), `/items[*]/price` (all array elements)
- **Position-Based**: Array indexing is 1-based (e.g., `/items[1]` for first element)
- **Translation**: Format plugins translate to native syntax (JSONPath for JSON, XPath for XML)

### Multi-Tenancy
- Row-level tenant isolation for rules, rulesets, and executions
- Shared global blueprints across all tenants
- Role-based access: User (tenant-scoped) < Engineer (global) < Admin (full)

### Plugin Architecture
- **Storage Adapters**: PostgreSQL (default), Redis, MongoDB
- **Format Plugins**: JSON (default), XML, YAML, Protocol Buffers
- **Delivery Plugins**: Polling (default), Webhooks, SSE, WebSockets, Message Queues
- **Validation Plugins**: AI/ML validation, external APIs, custom logic

## Architecture Components

### Blueprint DSL & Compilation
- Natural language DSL with placeholders: `${field} must be an integer between ${lower_bound} and ${upper_bound}`
- Compiled to expression-based Abstract Syntax Tree (AST) using NimbleParsec
- **Expression System**: Everything is an expression that evaluates itself recursively
  - FieldExpression: Fetches values via format plugins
  - TypeExpression: Represents types (integer, string, etc.)
  - IntegerExpression, StringExpression, DateExpression, RegexExpression: Literal values or function results
  - BooleanExpression: Returns true/false
    - ComparisonExpression: "is a", "is", "greater than", "matches", etc.
    - ConditionalExpression: if/then logic
    - CompositeExpression: and/or combinators
    - AggregateExpression: "all", "any", "none", "exactly one" (applies comparison to array elements)
  - FunctionExpression: Wraps functions (count of, uppercase, etc.) and declares return type
- **Fluent Type System**: Expressions know what types they accept (compile-time validation)
- **Context-Aware Placeholders**: `${field}` has no inherent type - context determines if it becomes FieldExpression, TypeExpression, etc.
- **Evaluation Flow**: Cascades down expression tree, bubbles results up
- **Parameter Binding**: Happens at rule creation time (not execution) - bound AST stored for fast execution
- Stored as serialized expression tree in database

### Validation Engine
- **Parallel Execution**: Rules execute concurrently using Elixir Tasks
- **Execution Strategies**: run_all (default), fail_fast, after_n_errors
- **Exception Handling**: fail, continue (default), silence per rule
- **Timeout Handling**: Same strategies as exceptions
- **Sandboxing**: Isolated processes with resource limits
- **Async Jobs**: Oban with configurable queues and fairness

### Rule Storage & Versioning
- **Hybrid Storage**: Rules store both bound AST (for execution) and parameters (for UI/traceability)
  - `bound_ast`: Pre-bound expression tree ready for immediate execution
  - `parameters`: Original arguments for display and editing
  - `blueprint_id` + `blueprint_version_id`: For traceability and audit
- **Binding**: Parameters bound to blueprint AST at rule creation time (not execution)
- **Automatic Versioning**: Every rule update creates a new version
- **Version Capture**: Queued validations capture rule version at enqueue time
- **Historical Preservation**: All versions preserved for audit trail
- **Stability**: Blueprint changes don't affect existing rules

### Result Aggregation
- Valid/Invalid determination based on rule failures
- Detailed results with status: passed, failed, inconclusive, silenced
- Summary statistics: total, passed, failed, inconclusive counts

### Caching Strategy
- Cache key: Hash of payload + rules version hash
- Invalidation: On payload change or any rule version change
- TTL-based expiration with configurable retention

## Project Structure
```
lib/
  horus/
    application.ex              # App supervision tree
    blueprint/
      parser.ex                 # DSL parser (NimbleParsec)
      ast.ex                    # AST node definitions
      executor.ex               # AST execution engine
    engine/
      coordinator.ex            # Orchestrates validation workflow
      executor.ex               # Parallel rule execution
      sandbox.ex                # Isolated rule execution
      aggregator.ex             # Result aggregation
      cache.ex                  # Result caching
    storage/
      adapters/
        postgres.ex             # Default storage
        redis.ex                # Optional adapter
    format_plugins/
      json.ex                   # Default format
      xml.ex                    # Optional format
    delivery_plugins/
      polling.ex                # Default delivery
      webhook.ex                # Optional delivery
    workers/
      validation_worker.ex      # Oban async worker
    context.ex                  # Auth context
    policy.ex                   # Authorization policies
    telemetry.ex                # Instrumentation
  horus_web/
    controllers/
      validation_controller.ex
      rule_controller.ex
      blueprint_controller.ex
    plugs/
      require_auth.ex
      rate_limit.ex
test/
  horus/
    blueprint/
      parser_test.exs
      executor_test.exs
    engine/
      coordinator_test.exs
      executor_test.exs
priv/
  repo/
    migrations/
```

## Database Schema

### Core Tables
- **tenants**: Multi-tenancy support
- **users**: User accounts with roles
- **user_tenants**: User-tenant assignments
- **blueprints**: Global validation templates
- **blueprint_versions**: Blueprint version history
- **rules**: Instantiated blueprints per tenant
- **rule_versions**: Rule version history
- **rulesets**: Named collections of rules
- **ruleset_rules**: Many-to-many rule assignments
- **validation_executions**: Validation requests/results
- **rule_results**: Individual rule execution outcomes
- **validation_cache**: Cached validation results
- **audit_logs**: Complete audit trail

### Key Features
- UUID primary keys throughout
- Automatic versioning with foreign key references
- JSONB columns for flexible metadata
- Partitioning for large tables (validation_executions)
- Materialized views for analytics
- Row-level security (optional)

## API Design

### REST Endpoints
- **POST /validations**: Create validation (sync/async)
  - Parameters: ruleset, payload, format, mode, strategy, callback_url, metadata
  - Strategies: run_all, fail_fast, after_n_errors
- **GET /validations/:id**: Retrieve validation status/results
  - Returns immediately (no long-polling/holding)
  - Response includes: status, total_rules, completed_rules, pending_rules (if in progress)
  - Results included when status is completed
- **GET /validations**: List validations with filters
- **DELETE /validations/:id**: Cancel queued/running validation

### Execution Modes
- **Sync**: Immediate execution, returns result
- **Async**: Queued via Oban, returns execution ID

### Delivery Strategies (Async)
- **Polling** (default): Client polls GET /validations/:id
  - Server returns immediately (no long-polling)
  - Response format same as querying current/past executions
  - Includes status, total_rules, completed_rules, pending_rules
  - Future enhancement: expected time to completion
- **Webhooks**: Server POSTs to callback_url when complete
- **SSE**: Server-Sent Events streaming
- **WebSockets**: Bidirectional connection
- **Message Queue**: RabbitMQ/Kafka pub/sub

## Authentication & Authorization

### Authentication
- API Keys (hashed SHA256)
- JWT tokens (24h expiry)
- Bearer token in Authorization header

### Roles & Permissions
- **User**: Create/manage rules and rulesets (assigned tenants only)
- **Engineer**: Manage blueprints globally, access all tenants
- **Admin**: Full system control, tenant management, user management

### Authorization Flow
1. Extract user from API key or JWT
2. Build context with user, tenant, role
3. Check policy for action + resource
4. Scope queries to tenant (for User role)

## Monitoring & Observability

### Telemetry Events
- `[:horus, :validation, :start/:stop/:exception]`
- `[:horus, :rule, :execute]`
- `[:horus, :cache, :hit/:miss]`
- `[:horus, :repo, :query]`
- `[:horus, :oban, :job, :*]`

### Metrics (Prometheus)
- Validation count by tenant/ruleset/status
- Validation duration (p50, p95, p99)
- Rule execution time by blueprint
- Cache hit rate
- Queue depth by queue
- Database query time

### Logging
- Structured JSON logs via Logger
- Contextual metadata: request_id, tenant_id, user_id
- Log levels: debug, info, warning, error
- Log aggregation via ELK stack

### Alerting
- High error rate (>10% for 5m)
- Slow validations (p95 > 5s for 10m)
- Queue buildup (>1000 jobs)
- High memory usage (>2GB)
- Database pool exhaustion

### Dashboards (Grafana)
- Validation performance (throughput, latency, errors)
- Rule performance (execution time by blueprint)
- System health (memory, CPU, queue depth)
- Business metrics (validations by tenant, active tenants)

## Development Standards
- Use descriptive module and function names
- Write comprehensive tests (unit + integration)
- Document public APIs with @doc and @moduledoc
- Follow OTP principles (supervision trees, GenServers)
- Keep functions focused and single-purpose
- Pattern match extensively
- Use `with` for error handling pipelines
- Prefer immutability and pure functions
- Validate inputs at boundaries
- Use Ecto changesets for data validation

## Testing Strategy
- Unit tests for business logic
- Integration tests for API endpoints
- No unit tests for rules/blueprints (runtime data)
- Test error cases and edge conditions
- Use ExUnit and Mox for mocking
- Test isolation with sandbox mode
- Performance testing for high-volume scenarios (future)

## Deployment

### Container Configuration
- Docker multi-stage builds
- Elixir releases for production
- Health check endpoint: GET /health
- Metrics endpoint: GET /metrics (port 9568)

### Environment Variables
- `DATABASE_URL`: PostgreSQL connection
- `SECRET_KEY_BASE`: Phoenix secret
- `JWT_SECRET`: Token signing key
- `OBAN_QUEUES`: Queue configuration
- `TELEMETRY_ENABLED`: Monitoring toggle

### Kubernetes Resources
- Deployment with rolling updates
- Service for HTTP traffic
- ConfigMap for configuration
- Secret for credentials
- HPA for autoscaling
- PVC for persistent storage (if needed)

## Security Best Practices
- Never commit secrets or API keys
- Use environment variables for configuration
- Hash API keys before storage (SHA256)
- Sign and encrypt JWTs
- Validate and sanitize all user input
- Implement rate limiting per tenant
- Use prepared statements (Ecto protects against SQL injection)
- Audit log all sensitive operations
- Row-level security for additional isolation (optional)
- Regular security updates for dependencies

## Feature Documentation
Comprehensive features and architecture documented in Notion:
- **Main Page**: [Horus - Validation Service](https://www.notion.so/308ed25fc08c81a7b5c1ccbd9bbf8f43)
- **Location**: Pet Projects > Horus
- **Page ID**: `308ed25f-c08c-81a7-b5c1-ccbd9bbf8f43`

### Documentation Pages
- **Core Architecture**: Blueprints, Rules, Attributes, Blueprint DSL & Compilation, Validation Engine
- **API & Integration**: API, Plugins, Callbacks
- **Infrastructure**: Database Schema, Multi-tenancy & Authorization, Monitoring & Observability
- **Planning**: Elixir vs Ruby Implementation, Q&A

**Important**: All new Notion pages should be created as children of the main Horus page.

## Getting Started
```bash
# Install dependencies
mix deps.get

# Run tests
mix test

# Start the application
iex -S mix
```

## Notes for AI Assistant
- Prioritize type safety and pattern matching
- Use GenServer for stateful validation contexts if needed
- Consider using behaviours for validator contracts
- Ensure validation errors are structured and informative
- Test edge cases thoroughly

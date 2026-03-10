# Parallel Workflows

Safe parallelization patterns for Go service development via Task tool.

## When to Parallelize
- Independent layer creation (entity + VO simultaneously)
- Multi-layer reviews (security + performance + architecture)
- Documentation updates (changelog + CLAUDE.md + system docs)
- Research phases (existing patterns + tech research + impact analysis)

## When NOT to Parallelize
- Usecase needs entity types → entity first
- Handler needs usecase types → usecase first
- Migration → SQLC generate → repository impl (sequential chain)
- Proto definition → buf generate → gRPC service impl (sequential chain)
- Tests that depend on code being compiled first

## Patterns per Mode

### Create New Service (`:parallel`)
```
Phase 1 (seq): Scaffolding — dirs, go.mod, Makefile, configs, .env_example
Phase 2 (parallel):
  Agent A: Domain entities + VOs
  Agent B: Application repo interfaces + constants
Phase 3 (seq): DB migrations, schema.sql, SQLC queries, sqlc generate, query adapters
Phase 4 (parallel):
  Agent A: Persistence repo impl + UoW
  Agent B: HTTP handlers + server
  Agent C: gRPC proto + service impl + server
Phase 5 (seq): Entrypoint (cmd/api/api.go), usecases factory
Phase 6 (seq): go build + go test + structure verification
```

### Code (`:parallel`)
```
Phase 1 (seq): Entity + VO (domain foundation)
Phase 2 (parallel):
  Agent A: Usecases
  Agent B: HTTP handlers
Phase 3 (seq): Migrations, SQLC, query adapters, repository impl
Phase 4 (parallel):
  Agent A: gRPC proto + service
  Agent B: Tests (entity, usecase, handler)
Phase 5 (seq): go build + go test + integration
```

### Review (`:parallel`)
```
Parallel (4 agents):
  Agent A: Architecture + Database layers
  Agent B: Security layer
  Agent C: Performance + Resilience layers
  Agent D: Observability + Testing layers
Sequential: Consolidate reports → single review with unified severity counts
```

### Test (`:parallel`)
```
Parallel (4 agents):
  Agent A: Entity + VO unit tests
  Agent B: Usecase unit tests (gomock)
  Agent C: Handler tests (httptest)
  Agent D: Integration tests (real DB)
Sequential: Run full suite `go test ./... -v -cover`
```

### Plan (`:parallel`)
```
Parallel (4 agents):
  Agent A: Schema design (tables, migrations, SQLC queries)
  Agent B: Domain analysis (entities, VOs, business rules)
  Agent C: Protocol design (gRPC RPCs, HTTP routes, request/response)
  Agent D: Security/Impact analysis (ACL scopes, cross-service deps)
Sequential: Consolidate into plan.md + phase files
```

## File Ownership Rules

| Agent | Owns | NEVER touches |
|-------|------|---------------|
| Entity agent | `domain/entity/*.go`, `domain/vo/*.go` | usecases, handlers |
| Usecase agent | `application/usecases/*.go` | entity, handler |
| Handler agent | `api/handlers/*.go`, `api/http-server/server.go` | entity, usecase |
| Repository agent | `infra/persistence/*.go`, `pkg/queries/*.go` | entity, handler |
| gRPC agent | `api/proto/*.proto`, `infra/grpc-service/*.go`, `api/grpc-server/server.go` | entity, handler |
| Test agent | `*_test.go`, `test/mock/*` | production code |

## Context Passing Between Phases
Sequential phases receive context from previous:
- **Phase 1 → Phase 2**: Directory structure, go.mod module path, entity names
- **Phase 2 → Phase 3**: Entity types (for SQLC params), VO types, repo interface methods
- **Phase 3 → Phase 4**: SQLC generated types, query adapter functions, migration applied
- **Phase 4 → Phase 5**: All components ready for entrypoint wiring

Pass via: agent prompt including relevant file paths and type signatures.

## Resource Limits
- Max 4 parallel agents per phase
- ~200K token context each agent
- Each agent runs `go build ./...` on owned files
- Final sequential phase runs `go build ./... && go test ./...` on everything

## User Feedback (MANDATORY for Orchestrator)

The orchestrator (main agent) MUST print visible text to the user at every stage:

1. **Before launching**: List agents being spawned and their purpose
2. **After each agent completes**: Print brief summary of findings (don't just stay silent)
3. **Between phases**: Print phase transition message with what comes next
4. **During consolidation**: Print "All agents complete. Consolidating..." before writing report
5. **After report**: Print key findings inline (critical count, recommendation), not just file path

**Anti-pattern (FORBIDDEN):** Spawning agents and going silent until all complete. User must see progress.

## Conflict Resolution
If 2 agents need same file: make sequential (not parallel).
If agent discovers dependency: STOP, report conflict, let orchestrator re-sequence.

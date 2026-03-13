# Plan Mode

## Trigger
Feature request, refactor, architectural change in existing service.

## PUA Enforcement
Activate `/pua` skill before planning. Plans must have concrete granularity — every phase needs inputs, outputs, validation criteria. Granularity too coarse = L2. No vague "implement feature X" steps without specifying files, patterns, and success criteria.

## Process

1. **Read service context:**
   - `apps/{service}/CLAUDE.md`
   - `docs/code-standards.md`
   - `docs/system-architecture.md`
   - `docs/design-guidelines.md`
2. **Analyze codebase impact:**
   - Existing entities, usecases, handlers affected
   - Database schema changes needed
   - gRPC proto changes
   - Cross-service dependencies
3. **Generate plan in `plans/{YYMMDD-HHMM-slug}/`:**
   - `plan.md` — overview (<80 lines)
   - `phase-XX-{name}.md` — detailed phase files
   - `research/` — researcher agent reports
   - `reports/` — execution reports

## Research Phase (Before Plan)

Spawn parallel researcher agents for independent technical topics:
1. **Domain researcher** — entity modeling, business rules, VOs needed
2. **Protocol researcher** — gRPC method design, request/response shapes
3. **Database researcher** — schema design, migrations, indexes, SQLC queries
4. **Integration researcher** — ACL scopes, cross-service calls, events
5. **Security researcher** — auth requirements, permission model

Consolidate research reports into plan.

## Plan Structure

### plan.md (Overview)
```markdown
# Feature: {name}
## Status: Planning | In Progress | Complete
## Phases
- [ ] Phase 1: Domain changes (entities, VOs)
- [ ] Phase 2: Application layer (usecases, interfaces)
- [ ] Phase 3: Infrastructure (migrations, SQLC, query adapters)
- [ ] Phase 4: gRPC proto & handlers
- [ ] Phase 5: HTTP handlers
- [ ] Phase 6: Tests (domain, usecases, integration)
- [ ] Phase 7: Documentation updates
## Dependencies
## New Ports/Scopes
## Breaking Changes
```

### Phase Files (`phase-XX-{name}.md`)
Each phase must include:
- **Context Links**: related reports, files, docs
- **Overview**: priority, status, description
- **Key Insights**: findings from research
- **Requirements**: functional + non-functional
- **Architecture**: design, component interactions, data flow
- **Related Code Files**: modify/create/delete lists
- **Implementation Steps**: numbered, specific, actionable
- **Todo Checklist**: tasks with [ ] checkboxes
- **Success Criteria**: definition of done, validation methods
- **Risk Assessment**: potential issues, mitigation
- **Security Considerations**: ACL checks, auth, data protection
- **Next Steps**: dependencies unblocked, follow-up tasks

## Go-Specific Readiness Checklist

Before marking plan complete, verify:

### Domain Layer
- [ ] New entities identified with business rules (RN-ENTITY-XX)
- [ ] VOs needed (new or reused from existing)
- [ ] Validation logic defined for entities and VOs
- [ ] Entity test cases planned (constructor, Validate(), business methods)

### Application Layer
- [ ] Usecases identified (1 per operation: {entity}_{action})
- [ ] ACL scopes defined for each usecase ({entity}:read/write/delete)
- [ ] Input/Output DTOs designed
- [ ] UoW type chosen (Transactionless vs Transaction)
- [ ] Error constants defined (domain-specific + ErrNoPermission reused)
- [ ] Usecase test cases with gomock planned

### Infrastructure Layer
- [ ] Database migrations designed (up + down)
- [ ] Tables include: id (KSUID 27 chars), created_at, updated_at, deleted_at, company_id where applicable
- [ ] Indexes identified for frequent queries
- [ ] SQLC queries written (:exec, :one, :many, :execrows)
- [ ] Query adapters planned (entity → SQLC params, SQLC result → entity)
- [ ] Repository methods mapped to SQLC queries

### Protocol Impact
- [ ] Service type identified: gRPC-only, HTTP-only, or dual-protocol
- [ ] gRPC proto changes identified (new RPCs, request/response messages)
- [ ] HTTP routes planned (method, path, auth, body/query schema)
- [ ] Error mapping defined (domain error → HTTP status / gRPC code)
- [ ] Response schemas designed (RespondSuccess, RespondCreated, RespondPaginated)
- [ ] HTTP-only services: Swagger/OpenAPI spec + Scalar UI at `/docs`

### Cross-Service Integration
- [ ] ACL service calls identified (Check{Entity}{Read|Write|Delete})
- [ ] gRPC calls to other services identified
- [ ] RabbitMQ events if async needed

### Tracing & Observability
- [ ] Tracing spans planned for new handlers (SpanTypeController)
- [ ] Tracing spans planned for new usecases (SpanTypeUseCase)
- [ ] Tracing spans planned for new infra methods (SpanTypeInfra)

### Security
- [ ] Auth requirements (JWT via x-api-key, applicant_id extraction)
- [ ] ACL checks as first operation in usecases
- [ ] company_id from body/query (NOT JWT)
- [ ] No credentials in code

### Testing
- [ ] Domain unit tests (entities, VOs): 100% coverage
- [ ] Usecase unit tests with gomock: 90%+ coverage
- [ ] Handler integration tests via httptest
- [ ] gRPC handler tests if applicable

### Documentation
- [ ] Service CLAUDE.md updates planned
- [ ] Changelog entry planned
- [ ] API docs updates if routes changed

## Parallel Variant (`:parallel`)

Spawn multiple agents analyzing in parallel:
1. **Schema agent** — DB migrations, indexes, SQLC queries
2. **Domain agent** — entities, VOs, business rules
3. **Protocol agent** — gRPC proto, HTTP routes, request/response
4. **Security agent** — ACL scopes, auth flow, permissions
5. **Impact agent** — existing code affected, breaking changes

Consolidate outputs into single plan.

## Key Files to Read

| File | Purpose |
|------|---------|
| `apps/{service}/CLAUDE.md` | Service-specific docs |
| `apps/{service}/internalpkg/core/domain/entity/` | Existing entities |
| `apps/{service}/internalpkg/core/application/usecases/` | Existing usecases |
| `apps/{service}/api/proto/` | Existing gRPC proto |
| `apps/{service}/api/handlers/` | Existing HTTP handlers |
| `apps/{service}/db/schema.sql` | Database schema |
| `docs/code-standards.md` | Coding rules |
| `docs/system-architecture.md` | Architecture overview |

## Validation: After plan approval, run `go build ./... && go vet ./... && go test -race ./...` for compliance checks during implementation.

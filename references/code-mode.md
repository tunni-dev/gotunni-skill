# Code Mode

## Trigger
Implement feature, fix bug, refactor in existing Go service.

## Before Starting
Read compliance-profile.md. Read service CLAUDE.md. Read architecture-patterns.md. Read plan (if exists in plans/).

## Module Order (Feature)
1. **Entity/VO** → `internalpkg/core/domain/entity/`, `vo/`
2. **Usecase** → `internalpkg/core/application/usecases/`
3. **Repository interface** → `application/repository/` (if new methods)
4. **Constants** → `application/constants/errors.go` (if new errors)
5. **Migrations** → `db/migrations/00000X_{desc}.{up|down}.sql`
6. **Schema** → `db/schema.sql` (update for SQLC)
7. **SQLC queries** → `pkg/sqlc/queries/{entity}_{action}.sql`, then `cd configs && sqlc generate`
8. **Query adapters** → `pkg/queries/{entity}_queries.go`
9. **Repository impl** → `internalpkg/infra/persistence/{service}_repository.go`
10. **Handler** → `api/handlers/{entity}_handler.go`, register in http-server
11. **Proto** → `api/proto/`, then `buf generate`
12. **gRPC service** → `internalpkg/infra/grpc-service/`, register in grpc-server
13. **Usecases factory** → `api/usecases-factory/usecases.go`
14. **Tests** → entity, usecase, handler tests

After each module: `go build ./...`
After all: `go test ./...`

## Entity Pattern (with VOs)
```go
type Entity struct { id vo.Id; companyId vo.Id; name string; status string; createdAt time.Time; updatedAt time.Time }
func NewEntity(id vo.Id, companyId vo.Id, name string, ...) Entity { return Entity{...} }
func (e Entity) Validate() error { /* RN-ENTITY-XX: rule description */ }
func (e Entity) Id() vo.Id { return e.id }
// Getters only. No setters. Business methods: Activate(), Deactivate()
```

## Entity Pattern (raw fields, no VOs)
When service doesn't use VO types (e.g., payment service with raw strings):
```go
type Subscription struct {
    id         string  // PRIVATE — never public
    customerId string
    status     SubscriptionStatus
    createdAt  time.Time
}
func NewSubscription(id, customerId string, ...) Subscription { return Subscription{id: id, ...} }
// ReconstructXxx for hydrating from DB (bypasses validation, all fields accepted as-is)
func ReconstructSubscription(id, customerId string, status SubscriptionStatus, ...) Subscription {
    return Subscription{id: id, customerId: customerId, status: status, ...}
}
func (s Subscription) Id() string { return s.id }
func (s Subscription) CustomerId() string { return s.customerId }
func (s Subscription) Validate() error { ... }
func (s *Subscription) Cancel(now time.Time) { s.status = ...; s.cancelledAt = &now }
// CRITICAL: Fields MUST be lowercase (private). Use Reconstruct* for DB hydration.
```

## Usecase Pattern
```go
type EntityCreate struct { repo repository.ServiceRepository; uow repository.UnitOfWorkTransactionlessRepository; tracing repository.TracingRepository; idGen repository.IdRepository; acl repository.ACLRepository }
type EntityCreateInput struct { ApplicantId string; CompanyId string; Name string }
type EntityCreateOutput struct { Id string }
func (uc *EntityCreate) Execute(ctx context.Context, input EntityCreateInput) (EntityCreateOutput, error) {
    ctx = uc.tracing.StartSpan(ctx, "EntityCreate.Execute", SpanTypeUseCase)
    aclResp, err := uc.acl.CheckEntityWrite(ctx, input.ApplicantId, input.CompanyId) // ACL FIRST
    if err != nil || !aclResp.HasPermission { return ..., constants.ErrNoPermission }
    ctx, err = uc.uow.Begin(ctx); defer uc.uow.Release(ctx)
    id := uc.idGen.Generate()
    e := entity.NewEntity(vo.NewId(id), vo.NewId(input.CompanyId), input.Name, ...)
    if err := e.Validate(); err != nil { return ..., err }
    if err := uc.repo.EntityCreate(ctx, e); err != nil { return ..., err }
    uc.uow.Commit(ctx)
    return EntityCreateOutput{Id: id}, nil
}
```

## Ownership Verification (IDOR Prevention)
For resource-specific operations (cancel, update, delete), ALWAYS verify ownership:
```go
func (uc *EntityCancel) Execute(ctx context.Context, input EntityCancelInput) (...) {
    // ... fetch entity ...
    if input.ApplicantId != "" && entity.CustomerId() != input.ApplicantId {
        return nil, errors.New("no permission") // ownership check, not ACL
    }
    // ... proceed with cancellation
}
```

## Error Wrapping
ALWAYS use `fmt.Errorf` with `%w` verb. NEVER concatenate errors:
```go
// CORRECT:
return nil, fmt.Errorf("failed to cancel on gateway: %w", err)
// WRONG:
return nil, errors.New("failed to cancel: " + err.Error())
```

## HTTP Handler Pattern
```go
func (h *EntityHandler) Create(w http.ResponseWriter, r *http.Request) {
    applicantId := ctxkeys.GetUserID(r.Context()) // from JWT
    var body struct { CompanyId string `json:"company_id"`; Name string `json:"name"` }
    DecodeJSON(r, &body)
    output, err := h.usecases.EntityCreate.Execute(r.Context(), usecases.EntityCreateInput{...})
    if err != nil {
        if errors.Is(err, constants.ErrNoPermission) { RespondError(w, 403, "forbidden"); return }
        if errors.Is(err, constants.ErrNotFound) { RespondError(w, 404, "not found"); return }
        RespondError(w, 400, "invalid request"); return
    }
    RespondCreated(w, output)
}
```

## gRPC Handler Pattern (SECURITY CRITICAL)
```go
func (p ServiceGrpcAdapter) ENTITYCREATE(ctx context.Context, req *pb.Request) (*pb.Response, error) {
    // 1. Span with SpanTypeController (NOT SpanTypeInfra)
    span, ctx := p.tracing.StartSpan(ctx, "ServiceGrpcAdapter.ENTITYCREATE", repository.SpanTypeController)
    defer span.End()
    // 2. API key check
    if err := p.checkXApiKey(ctx); err != nil {
        return nil, status.Error(codes.PermissionDenied, "forbidden")
    }
    // 3. JWT validation (REQUIRED for user-resource operations)
    claims, err := p.checkUserToken(ctx)
    if err != nil { return nil, status.Error(codes.Unauthenticated, "unauthorized") }
    customerId, _ := claims.GetSubject()
    // 4. Execute usecase
    output, err := p.usecases.EntityCreate.Execute(ctx, input)
    if err != nil {
        p.tracing.CaptureError(ctx, err)
        // 5. ERROR SANITIZATION — NEVER expose err.Error() to client
        if errors.Is(err, constants.ErrNoPermission) { return nil, status.Error(codes.PermissionDenied, "no permission") }
        if errors.Is(err, constants.ErrNotFound) { return nil, status.Error(codes.NotFound, "not found") }
        return nil, status.Error(codes.Internal, "internal error") // generic message
    }
    return &pb.Response{...}, nil
}
```

## Webhook Handler Pattern
```go
func (h *WebhookHandler) Handle(w http.ResponseWriter, r *http.Request) {
    span, ctx := h.tracing.StartSpan(r.Context(), "WebhookHandler.Handle", repository.SpanTypeController)
    defer span.End()
    // FAIL-CLOSED: reject if token not configured or mismatch
    token := r.Header.Get("provider-token")
    expected := h.envRepo.GetWebhookToken()
    if expected == "" || token != expected { http.Error(w, "forbidden", 403); return }
    // Body size limit
    r.Body = http.MaxBytesReader(w, r.Body, 1<<20) // 1MB
    // ... decode and process
}
```

## External API Adapter Pattern
```go
type ExternalAdapter struct {
    client *externalClient
    cb     *gobreaker.CircuitBreaker // REQUIRED for external APIs
}
func NewExternalAdapter(...) ExternalAdapter {
    return ExternalAdapter{client: ..., cb: newCircuitBreaker("service-name")}
}
func (a ExternalAdapter) DoAction(ctx context.Context, ...) (string, error) {
    result, err := a.cb.Execute(func() (interface{}, error) {
        return a.client.DoAction(...)
    })
    if err != nil { return "", fmt.Errorf("failed to do action: %w", err) }
    return result.(string), nil
}
```

## Bug Fix Variant
1. Read error/bug report, locate code
2. Diagnose root cause (read tests, logs)
3. Fix in-place (minimal change)
4. Add regression test reproducing bug
5. `go build ./... && go test ./...`

## Refactor Variant
1. Run review mode first (identify issues)
2. Plan refactor steps
3. Refactor in-place maintaining behavior
4. Verify all existing tests pass
5. No new features during refactor

## Parallel Variant (`:parallel`)
Read parallel-workflows.md. File ownership:
- Entity agent: `domain/entity/*.go`, `domain/vo/*.go`
- Usecase agent: `application/usecases/*.go`
- Handler agent: `api/handlers/*.go`
- Repository agent: `infra/persistence/*.go`, `pkg/queries/*.go`
ONLY modify assigned files. Report any conflicts.

## Post-Implementation Checklist (MANDATORY)

### Build & Test
- [ ] `go build ./...` compiles
- [ ] `go test -race ./... -cover` passes with race detector
- [ ] `go vet ./...` passes
- [ ] All function return types match (no `return err` when signature is `(output, error)`)

### Domain
- [ ] Entity fields PRIVATE (lowercase) with getters
- [ ] `Reconstruct*` function for DB hydration (if no VOs)
- [ ] `Validate()` method on all entities
- [ ] No dead code or orphaned functions/tests
- [ ] No provider-specific naming in domain (use `ExternalProviderId`, not `AsaasId`)
- [ ] Boolean fields derived from logic, not hardcoded (e.g., `IsAdmin` from scopes)

### Code Quality (Commit-Proven Errors)
- [ ] No `fmt.Printf("DEBUG...")` or `log.Printf("DEBUG...")` left in code
- [ ] No `tracing.CaptureError()` used as debug log (only for real errors)
- [ ] No commented-out code (TODOs, old relationships, dead comments)
- [ ] No binary files committed (`.exe`, compiled binaries, `payment-server`)
- [ ] No generated/temp files committed (`*.out`, `cover*.out`, `coverage.out`, `hook-log.jsonl`)
- [ ] No mock/fallback dependencies in production (`if key == "" { useMock }` is FORBIDDEN)
- [ ] All code paths reachable — switch/if-else chains must have explicit default/else
- [ ] Consistent function signatures — don't change return type mid-feature without updating all callers

### Security
- [ ] gRPC handlers: JWT validation (`checkUserToken`) on user-resource ops
- [ ] Ownership verification: requester owns the resource (IDOR check)
- [ ] Error sanitization: NEVER `err.Error()` to client — use `"internal error"`
- [ ] Error mapping: `errors.Is(err, ErrX)` — NEVER string comparison
- [ ] Webhook handlers: fail-closed token check + body size limit
- [ ] No `fmt.Sprintf`/string concat in SQL — SQLC parameterized only
- [ ] Required env vars validated at startup with `panic()` — NEVER silently use empty strings

### Resilience
- [ ] Circuit breaker on ALL external API adapter methods
- [ ] Error wrapping: `fmt.Errorf("ctx: %w", err)` — NEVER concatenation
- [ ] Graceful shutdown in entrypoint (if modified)
- [ ] Payment method routing uses explicit switch/if-else with error on unknown type

### Observability
- [ ] Handlers: `SpanTypeController` + `defer span.End()`
- [ ] Usecases: `SpanTypeUseCase` + `defer span.End()`
- [ ] Infra: `SpanTypeInfra` + `defer span.End()`
- [ ] `CaptureError()` on all error paths (real errors only, not debug)

### Database
- [ ] Business invariants enforced at DB level (unique indexes, constraints)
- [ ] List queries have LIMIT
- [ ] SQLC adapter exists for every query
- [ ] Migrations: up + down present, sequential numbering, never squash published migrations
- [ ] Files <200 lines (split if exceeded)

### Architecture
- [ ] Domain layer has NO provider-specific types/naming (Asaas, Stripe, etc.)
- [ ] No obsolete interfaces/entities left after refactoring (clean up old files)
- [ ] Dependencies are REQUIRED or not present — no conditional mock fallbacks
- [ ] Workflow/event IDs defined as named constants, not inline strings
- [ ] Commit message follows conventional commits: `type(scope): description`

### Git Hygiene
- [ ] No `*.out`, `*.log`, `*.tmp` files staged
- [ ] No `hook-log.jsonl` or `.claude/hooks/.logs/` files staged
- [ ] No compiled binaries staged
- [ ] `.gitignore` updated if new generated file types introduced

## Reports
`{reports_path}/code-{date}-{feature}.md`: files modified, tasks completed, build/test status, issues.

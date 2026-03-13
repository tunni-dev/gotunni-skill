# Review Mode

## Trigger
Code review for Go service changes. Post-implementation quality gate.

## PUA Enforcement
Activate `/pua` skill. Verify findings with evidence (read source, run commands). Guessing without searching = L2. Flag real issues backed by code references, not cosmetic opinions.

## Before Starting
Read compliance-profile.md FIRST (defines severity). Read target code. Read architecture-patterns.md. Read service CLAUDE.md.

## Severity Calibration
Use compliance-profile.md severity, NOT personal judgment:
- REQUIRED missing → 🔴 CRITICAL (must fix)
- RECOMMENDED missing → 🟡 WARNING (should fix)
- OPTIONAL missing → 🔵 SUGGESTION (nice to have)
- N/A → SKIP (do not flag)

## 7-Layer Review

### Layer 1: Architecture
- Clean Arch boundaries (domain→application→infra, no reverse imports)
- Entity: private fields, constructor (New*), Validate(), getters only
- VO: constructor, Validate(), String(), IsEmpty(), immutable
- Usecase: struct with injected deps, Input/Output DTOs, Execute()
- Repository interface in application, impl in infra
- No business logic in infra layer
- HTTP-exposed services: Swagger/OpenAPI spec + Scalar UI at `/docs`

### Layer 2: Security
- ACL check present in every usecase
- ACL check FIRST (before any business logic, before UoW)
- Auth via x-api-key header (NOT Authorization Bearer)
- applicant_id from JWT via ctxkeys.GetUserID(ctx)
- company_id from body/query (NOT from JWT)
- ErrNoPermission = "no permission" (exact string)
- No hardcoded credentials
- Input validation via entity/VO Validate()

### Layer 3: Performance
- No N+1 queries (use :many with WHERE IN or JOIN)
- SQLC query adapters used (not direct SQLC)
- Pagination for list endpoints (RespondPaginated)
- Context propagation (no context.Background() in handlers)
- Connection pool usage (pgxpool, not raw pgx)

### Layer 4: Resilience
- Error handling in every usecase Execute()
- UoW rollback: defer Release() ensures rollback on error
- Panic recovery via Chi Recoverer middleware
- Context propagation through all layers
- Timeout on external calls (ACL gRPC, etc.)
- Circuit breaker on ALL external API adapters (gobreaker.CircuitBreaker)

### Layer 5: Observability
- APM span in handlers: SpanTypeController
- APM span in usecases: SpanTypeUseCase
- APM span in infra: SpanTypeInfra
- CaptureError for all error paths
- Correct SpanTypes (not swapped)

### Layer 6: Database
- Migration exists (up + down) for schema changes
- schema.sql updated for SQLC
- SQLC queries annotated (:exec, :one, :many, :execrows)
- Query adapters in pkg/queries/ (entity↔SQLC conversion)
- No inline SQL anywhere
- Soft delete pattern (deleted_at column)
- Down migration reverses up

### Layer 7: Testing
- Entity: table-driven tests, testify/assert, constructor + Validate()
- VO: table-driven tests, String(), IsEmpty()
- Usecase: gomock for repos, test ACL denied, UoW lifecycle
- Handler: httptest, error mapping (403/400/404/500)
- Coverage: domain 100%, usecases 90%+, infra 60%+

## Output Format
```markdown
# Code Review: {feature}
## Summary: {✅ APPROVED | 🟡 NEEDS CHANGES | 🔴 BLOCKED}
## Compliance Profile: references/compliance-profile.md
## Files Reviewed: {list with line counts}
## Findings
### 🔴 Critical (REQUIRED missing)
[compliance item X REQUIRED] {issue} {file:line}
### 🟡 Warnings (RECOMMENDED missing)
### 🔵 Suggestions (OPTIONAL)
### ✅ What's Good
## Summary: Critical X, Warnings Y, Suggestions Z
## Recommendation: APPROVE | REQUEST CHANGES | REJECT
```

Save to: `{plans_path}/reports/review-{date}-{feature}.md`

## Parallel Variant (`:parallel`)
4 agents reviewing simultaneously:
- Agent A: Architecture + Database layers
- Agent B: Security layer
- Agent C: Performance + Resilience layers
- Agent D: Observability + Testing layers
Sequential: consolidate into single report with unified counts.

## Automation: Run `go build ./... && go vet ./... && go test -race ./...` before manual review to catch common issues.

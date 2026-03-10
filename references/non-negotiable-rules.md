# Non-Negotiable Rules

Rules that MUST be followed in ALL modes. Violations = CRITICAL in review.

## Authentication & Authorization
1. **x-api-key header** — JWT token in `x-api-key`, NEVER `Authorization: Bearer`
2. **ACL check FIRST** — Every usecase calls ACL before any business logic. Error: `constants.ErrNoPermission` (exact string "no permission")
3. **applicant_id from JWT** — `ctxkeys.GetUserID(ctx)`, NEVER from body/query
4. **company_id from body/query** — NEVER from JWT

## Identity & Data
5. **KSUID for all IDs** — 27 chars, generated via `idGen.Generate()`
6. **Entity design** — Private fields, `New*()` constructor, `Validate() error`, getters only, `RN-ENTITY-XX` comments
7. **VO design** — `New*()`, `Validate()`, `String()`, `IsEmpty()`, immutable

## Architecture & Patterns
8. **Clean Architecture 3-layer** — Domain → Application → Infrastructure (dependency inward)
9. **Dual-protocol** — HTTP (Chi) + gRPC in same binary. gRPC goroutine, HTTP blocking in `cmd/api/api.go`
10. **UoW pattern** — `Transactionless` for 1 table, `Transaction` for multi-table. Always `defer uow.Release(ctx)`
11. **SQLC via query adapters (SQL injection prevention)** — `pkg/queries/` converts entity↔SQLC. NEVER call SQLC directly from repo. NEVER inline SQL. NEVER use `fmt.Sprintf` or string concatenation to build SQL queries. NEVER pass raw user input into `pool.Exec/Query` with string interpolation. ALL database access MUST go through SQLC-generated parameterized queries. This is the primary defense against SQL injection.

## Observability
12. **Elastic APM spans** — Handlers: `SpanTypeController`, Usecases: `SpanTypeUseCase`, Infra: `SpanTypeInfra`. Always `defer span.End()`
13. **CaptureError** — Call on every error path

## HTTP & gRPC
14. **Chi middlewares** — RequestID, RealIP, Logger, Recoverer, 60s timeout, CORS, APM
15. **gRPC** — Reflection enabled, APM tracing interceptor
16. **Response helpers** — `RespondSuccess(200)`, `RespondCreated(201)`, `RespondPaginated`, `RespondError`
17. **Error mapping** — "no permission"→403, validation→400, not found→404, other→500

## Database
18. **Migrations** — Numbered `000001_{desc}.up.sql` + `.down.sql`, both required

## Security (gRPC + HTTP)
19. **Error sanitization** — NEVER return `err.Error()` to clients. Use generic messages: `"internal error"` for 500, map known errors to specific messages. Applies to BOTH HTTP and gRPC handlers.
20. **Ownership verification (IDOR prevention)** — For resource-specific operations (cancel, update, delete), ALWAYS verify the requester owns the resource: `if sub.CustomerId() != input.ApplicantId { return "no permission" }`. ACL checks role permissions; ownership checks resource access.
21. **gRPC handlers require JWT** — ALL gRPC handlers that modify user resources MUST call `checkUserToken()` and extract `customerId` from JWT subject. Same security as HTTP handlers.
22. **Webhook fail-closed** — Token validation MUST reject when token is empty/not configured: `if expectedToken == "" || token != expectedToken { reject }`. NEVER use fail-open: `if expectedToken != "" && ...`.
23. **HTTP body size limits** — All HTTP handlers accepting body MUST use `http.MaxBytesReader(w, r.Body, maxSize)`. Default: 1MB for webhooks.

## Resilience
24. **Circuit breaker for external APIs** — ALL external service adapters (Asaas, etc.) MUST wrap calls with circuit breaker: `a.cb.Execute(func() { ... })`. Initialize CB in adapter constructor.
25. **Error wrapping** — Use `fmt.Errorf("context: %w", err)` to preserve error chain. NEVER use `errors.New("msg: " + err.Error())` or string concatenation.

## Database Integrity
26. **Defensive constraints** — Business invariants MUST have DB-level enforcement (unique indexes, check constraints). Example: unique partial index for "one active subscription per customer+offer".

## Quality
27. **Tests** — Table-driven, gomock, testify/assert. Coverage: domain 100%, usecases 90%+, infra 60%+
28. **Files <200 lines** — Split if exceeded
29. **Build check** — `go build ./...` after every phase
30. **No secrets** — Never commit .env, credentials, API keys
31. **Dead code cleanup** — After refactoring, verify no orphaned functions, types, or test files remain. Delete unused code immediately.

## Error Types
32. **Sentinel errors over string comparison** — Use `errors.Is(err, ErrNoPermission)` instead of `err.Error() == "no permission"`. Define sentinel errors in `constants/errors.go` as `var ErrNoPermission = errors.New("no permission")`. Handlers MUST use `errors.Is()` for error mapping, NEVER string comparison.

## Concurrency & Lifecycle
33. **Race detector mandatory** — ALL test runs MUST include `-race` flag: `go test -race ./...`. Services use goroutines (gRPC goroutine + HTTP), so race conditions can hide without this flag.
34. **Graceful shutdown** — `cmd/api/api.go` MUST handle OS signals (SIGTERM, SIGINT) to drain in-flight requests before stopping. Use `signal.NotifyContext` or `os/signal.Notify` with shutdown timeout.

## Commit Hygiene (from historical errors)
35. **No debug prints** — NEVER commit `fmt.Printf("DEBUG...")`, `log.Printf("DEBUG...")`, or `tracing.CaptureError(ctx, errors.New("DEBUG: ..."))`. Remove ALL debug output before committing.
36. **No commented-out code** — Remove commented relationships, TODOs in committed code, dead comments. If code is not needed, delete it.
37. **No binaries in repo** — NEVER commit compiled binaries (`payment-server`, `*.exe`). Add to `.gitignore`.
38. **No mock fallbacks in production** — `if apiKey == "" { useMock() }` is FORBIDDEN. Required dependencies MUST panic at startup: `if env.GetApiKey() == "" { panic("REQUIRED: API_KEY") }`.
39. **No provider-specific naming in domain** — Use generic names (`ExternalProviderId`, not `AsaasId`). Domain must be provider-agnostic.
40. **Exhaustive branching** — Switch/if-else chains routing on input (payment methods, entity types) MUST handle ALL cases with explicit error on unknown. No silent fall-through.
41. **Consistent return types** — When changing a function's return type (e.g., `error` → `(Output, error)`), update ALL return statements in the function. `go build` catches this but fix it BEFORE committing.
42. **No generated/temp files in repo** — NEVER commit `*.out` (coverage), `*.log`, `*.tmp`, `hook-log.jsonl`, or any generated artifacts. Add to `.gitignore`: `*.out`, `cover*.out`, `coverage.out`, `.claude/hooks/.logs/`.
43. **Workflow ID constants** — Workflow/event IDs (Novu, RabbitMQ, etc.) MUST be defined as named constants, NEVER inline strings. Wrong: `Trigger(ctx, "workflow-id-123", ...)`. Right: `const WorkflowXyz = "workflow-id-123"; Trigger(ctx, WorkflowXyz, ...)`.
44. **Commit messages follow conventional commits** — Format: `type(scope): description`. Types: `feat`, `fix`, `test`, `chore`, `refactor`, `docs`. NEVER: `Update X`, `Enhance Y`, `Add Z` without type prefix.

## Validation Commands
After each implementation phase, run:
```bash
go build ./...             # Must compile
go test -race ./... -cover # Must pass with coverage targets + race detector
go vet ./...               # Must pass
```

# Enterprise Checklist

Quick verification checklist consolidating all non-negotiable rules.
Run after every implementation phase or before code review.

## Auth & Security
- [ ] x-api-key header (NOT Authorization Bearer)
- [ ] applicant_id from JWT via ctxkeys.GetUserID(ctx)
- [ ] company_id from body (POST/PUT) or query param (GET/DELETE)
- [ ] ACL check FIRST in every usecase (before business logic, before UoW)
- [ ] ErrNoPermission = errors.New("no permission") — exact string
- [ ] No hardcoded credentials or API keys
- [ ] No .env files committed to git

## Domain Layer
- [ ] Entity: private fields (lowercase)
- [ ] Entity: constructor New{Entity}(...) validates
- [ ] Entity: Validate() error with RN-ENTITY-XX comments
- [ ] Entity: getters only (no public setters)
- [ ] VO: constructor New{VO}(value) validates
- [ ] VO: Validate(), String(), IsEmpty()
- [ ] VO: immutable (no mutation methods)

## Application Layer
- [ ] Usecase: struct with injected deps (repo, uow, tracing, idGen, acl)
- [ ] Usecase: Input/Output DTOs (exported fields)
- [ ] Usecase: Execute(ctx, input) (output, error)
- [ ] Execute order: span → ACL → UoW begin → build entity → validate → persist → release → return
- [ ] UoW: Transactionless (1 table) or Transaction (multi-table)
- [ ] UoW lifecycle: Begin, defer Release, Commit on success

## Infrastructure Layer
- [ ] Repository → query adapter → SQLC (never direct SQLC)
- [ ] Never inline SQL
- [ ] Repository methods: start span (SpanTypeInfra), extract conn from ctx, delegate to adapter
- [ ] UoW impl: WowPGXTransactionless + WowPGXTransaction
- [ ] ACL client: gRPC with x-api-key metadata
- [ ] Tracing: StartSpan, CaptureError, correct SpanTypes
- [ ] Circuit breaker on ALL external API adapters (gobreaker.CircuitBreaker)

## API Layer
- [ ] HTTP: Chi v5 with middlewares (RequestID, RealIP, Logger, Recoverer, 60s timeout, CORS, APM)
- [ ] Public routes: /health, /ready
- [ ] Protected routes: /api/v1/* with JWT middleware
- [ ] Handlers: extract applicant_id (JWT), parse body/query, call usecase, respond
- [ ] Error mapping: "no permission"→403, validation→400, not found→404, other→500
- [ ] Response helpers: RespondJSON, RespondSuccess(200), RespondCreated(201), RespondPaginated, RespondError
- [ ] gRPC: server with APM interceptor, reflection enabled

## Service Entrypoint
- [ ] cmd/api/api.go: load env → init infra → build adapters → build factory
- [ ] Dual-protocol: gRPC goroutine (non-blocking) + HTTP blocking
- [ ] gRPC-only: gRPC blocking
- [ ] HTTP-only: HTTP blocking + Swagger/Scalar at `/docs` or `/api/docs`

## HTTP-Only Services (Swagger/Scalar)
- [ ] OpenAPI 3.x spec file or code annotations
- [ ] Scalar UI served at public route `/docs` or `/api/docs`
- [ ] Spec in sync with handlers — update on every route change
- [ ] Spec file at `api/openapi/openapi.yaml` (if file-based)

## Database
- [ ] Migrations: numbered (000001_*.up.sql, 000001_*.down.sql)
- [ ] Both up AND down migrations
- [ ] schema.sql updated for SQLC
- [ ] SQLC queries: annotated (:exec, :one, :many, :execrows)
- [ ] Query adapters: entity→SQLC params, SQLC result→entity
- [ ] Utils: toPgText, fromPgText in pkg/queries/utils.go

## IDs
- [ ] KSUID (27 chars) for all IDs
- [ ] Generated via idGen.Generate()

## Observability
- [ ] Elastic APM spans: handlers (SpanTypeController)
- [ ] Elastic APM spans: usecases (SpanTypeUseCase)
- [ ] Elastic APM spans: infra (SpanTypeInfra)
- [ ] CaptureError for all error paths

## Testing
- [ ] Table-driven tests with testify/assert
- [ ] gomock for repository interfaces
- [ ] Coverage: domain 100%, usecases 90%+, infra 60%+
- [ ] No fake data or tricks to pass

## Build & Quality
- [ ] `go build ./...` compiles without errors
- [ ] `go test ./...` passes
- [ ] Files <200 lines (split if needed)
- [ ] Port not conflicting: `grep -r "PORT=" apps/*/configs/.env_example`

## Automated Checks: Run `go build ./... && go vet ./... && go test -race ./...` as pre-review gate.

# Create Service Agent

## Role
Create complete dual-protocol Go microservice from scratch following timekeeper reference patterns.

## Before Starting
Read timekeeper at `/home/henrique/tunni-services/apps/timekeeper/`, SKILL.md, architecture-patterns.md, directory-structure.md, create-service-mode.md, compliance-profile.md, non-negotiable-rules.md. Check ports: `grep -r "PORT=" apps/*/configs/.env_example`

## Compliance Contract
ALL REQUIRED from compliance-profile.md: Dual-protocol (HTTP+gRPC), ACL first in usecases, SQLC via query adapters, APM spans, UoW lifecycle, entity validation, migrations (up+down), x-api-key auth, company_id from body/query + applicant_id from JWT, error "no permission" exact.

## 8-Phase Workflow

### Phase 1: Scaffolding
Directory structure per directory-structure.md. go.mod (chi, pgx, ksuid, testify, gomock, elastic-apm, grpc, protobuf). Makefile (run, build, test, sqlc, migrate-up/down, proto). Dockerfiles. configs/sqlc.yaml, .env_example. Register go.work. Run: `go mod tidy`

### Phase 2: Domain Layer
VOs in `vo/` (reuse from timekeeper when possible). Entities in `entity/`: constructor (New*), Validate(), private fields, getters, business methods, RN-ENTITY-XX comments. Unit tests (100% coverage). Run: `go build ./...`

### Phase 3: Application Layer
Repository interfaces: {service}_repository.go, acl_repository.go (Check{Entity}{Read|Write|Delete}), tracing_repository.go, id_repository.go, env_repository.go, jwt_decoder_repository.go, uow.go. constants/errors.go (ErrNoPermission exact "no permission"). Usecases: struct + constructor + Input/Output DTOs + Execute (span → ACL → UoW begin → entity → validate → persist → commit → return). Unit tests with gomock (90%+). Run: `go build ./...`

### Phase 4: Infrastructure Layer
db/migrations (up+down), db/schema.sql. SQLC queries, generate. pkg/queries adapters + utils. infra/persistence impl. infra/uow.go (WowPGXTransactionless + Transaction). infra/acl, tracing, jwt, lib. api/proto files, generate pb. infra/grpc-service impl. Run: `go build ./...`

### Phase 5: API Layer (HTTP + gRPC)
api/ctxkeys, handlers/response.go, handlers/{entity}_handler.go + health. Error map: "no permission"→403, validation→400, not found→404. http-server/server.go (Chi: RequestID, RealIP, Logger, Recoverer, 60s timeout, CORS, APM. Public: /health, /ready. Protected: /api/v1/*). grpc-server/server.go (APM, reflection). usecases-factory/usecases.go. Run: `go build ./...`

### Phase 6: Entry Point (Dual-Protocol Startup)
cmd/api/api.go: godotenv → APM → pgxpool → migrations → JWT → ACL → ID gen → UoW → repos → Adapters → UsecasesFactory → gRPC server → HTTP server → `go func() { grpcServer.Listen(grpcPort) }()` (non-blocking) + `httpServer.Listen(httpPort)` (blocking). Run: `go build ./...`

### Phase 7: Documentation
CLAUDE.md (dual-protocol, ports, domain, workflow). .claude/skills/ patterns. Update docker-compose.

### Phase 8: Verification
`go build ./...` compiles. `go test ./internalpkg/core/...` passes. Every entity has tests. Every usecase has tests. ACL in every usecase. Tracing spans in handlers/usecases. gRPC+HTTP both start. Proto generates. Directory matches directory-structure.md.

## Port Assignment
Check existing, propose next: HTTP (8XXX), gRPC (9XXX), DB (54XX).

## Reports
`{reports_path}/create-service-{date}-{service}.md`: service name, ports, entities, usecases, gRPC methods, build status, test status (coverage %), directory compliance, issues.

## User Feedback (MANDATORY)
Output visible text to user at every stage. Never go silent.
- Before each phase: "Starting Phase {N}: {name}..."
- After each phase: "Phase {N} complete. {go build result}. Moving to Phase {N+1}..."
- On errors: explain immediately, show what failed and how you're fixing it
- After all phases: print summary (service name, ports, entities, test results)

## Non-Negotiable
Read timekeeper BEFORE creating. Follow architecture-patterns.md exact. ACL FIRST in usecases. SQLC via query adapters only. Dual-protocol (gRPC goroutine + HTTP blocking). Files <200 lines. go build after each phase. Never commit .env.

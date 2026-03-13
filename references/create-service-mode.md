# Create Service Mode

## Trigger
Create new microservice from scratch in tunni-services monorepo with dual-protocol (HTTP + gRPC).

## PUA Enforcement
Activate `/pua` skill. Every phase MUST compile (`go build ./...` with output pasted). End-to-end validation mandatory at finish. "Good enough" = L3.

## Minimum Input
- Service name (e.g., "organization", "inventory")
- Domain description (e.g., "manages equipment inventory for companies")

## Agent Infers & Proposes
Before implementation, deduce and present for approval:
1. Entities from domain description
2. Next available ports (HTTP, gRPC, DB) via grep in docker-compose/.env_example
3. ACL scopes ({entity}:read, {entity}:write, {entity}:delete)
4. gRPC inter-service methods
5. RabbitMQ/events if async communication suggested

## 8-Phase Workflow

### Phase 1: Scaffolding
1. Full directory tree per `references/directory-structure.md`
2. `go.mod` with deps: chi, pgx, ksuid, testify, gomock, elastic-apm, grpc, protobuf, godotenv, golang-migrate, viper
3. `Makefile` targets: run, build, test, sqlc, migrate-up, migrate-down, tidy, proto
4. Dockerfiles (dev + prod), `configs/sqlc.yaml`, `.env_example`
5. Register in monorepo `go.work`
6. Validate: directory structure matches timekeeper

### Phase 2: Domain Layer
1. VOs in `domain/vo/` (reuse from timekeeper when possible, else recreate same logic)
2. Entities in `domain/entity/`: private fields, `New{Entity}(...)`, `Validate()`, getters, RN-ENTITY-XX
3. Unit tests (100% coverage)
4. Validate: `go build ./... && go test ./internalpkg/core/domain/...`

### Phase 3: Application Layer
1. Repository interface, supporting interfaces (acl, tracing, id, env, jwt_decoder, uow)
2. `constants/errors.go` with `ErrNoPermission = errors.New("no permission")`
3. Usecases: Execute order = span → ACL → UoW begin → build entity → validate → persist → commit → return
4. Unit tests with gomock (90%+ coverage)
5. Validate: `go build ./... && go test ./internalpkg/core/application/...`

### Phase 4: Infrastructure Layer
1. Migrations (000001_{desc}.up.sql + .down.sql), `db/schema.sql`
2. SQLC queries + generate (`cd configs && sqlc generate`)
3. Query adapters in `pkg/queries/` (entity ↔ SQLC conversion + utils.go)
4. Persistence repo impl (span → extract conn → delegate to adapter)
5. UoW impl (WowPGXTransactionless + WowPGXTransaction)
6. ACL client (gRPC, x-api-key), tracing (APM), JWT adapter, lib helpers
7. Proto files + `buf generate`/`protoc`
8. gRPC service impl
9. Validate: `go build ./...`

### Phase 5: API Layer (HTTP + gRPC)
1. ctxkeys, response helpers (RespondJSON, RespondSuccess, RespondCreated, RespondPaginated, RespondError)
2. Entity handlers (extract applicant_id JWT, parse body, call usecase, error mapping)
3. HTTP server (Chi v5, middlewares, public + protected routes)
4. gRPC server (APM interceptor, reflection, Listen)
5. UsecasesFactory (DI container)
6. Validate: `go build ./...`

### Phase 6: Entrypoint
`cmd/api/api.go`: Load env → APM → pgxpool → migrations → JWT → ACL → ID gen → UoW → repos → Adapters → UsecasesFactory → gRPC goroutine → HTTP blocking.

### Phase 7: Documentation & Config
Service CLAUDE.md, docker-compose updates if needed.

### Phase 8: Verification
- [ ] `go build ./...` + `go test ./...` pass
- [ ] Entity + usecase tests with proper coverage
- [ ] ACL first in every usecase, tracing spans everywhere
- [ ] Dual-protocol startup (gRPC goroutine + HTTP blocking)
- [ ] Migrations up+down, SQLC generates clean
- [ ] No .env or credentials committed

## Edge Cases
- **No external gRPC**: Still create gRPC structure with health-check RPC
- **No own ACL scope**: Reuse parent entity scope
- **VO in timekeeper**: Recreate in new service (internalpkg = non-exported)
- **RabbitMQ needed**: Add `infra/events/` with Watermill

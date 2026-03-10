# Architecture Patterns

## 3-Layer Clean Architecture

**Domain → Application → Infrastructure**

### Domain Layer (`internalpkg/core/domain/`)
- **Entity** (`entity/{name}.go`): Private fields, constructor `New{Entity}(...)`, `Validate() error`, getters only, business methods, RN-ENTITY-XX comments
- **Value Object** (`vo/{name}.go`): Constructor `New{VO}(value)`, `Validate()`, `String()`, `IsEmpty()`, immutable

### Application Layer (`internalpkg/core/application/`)
- **Usecase** (`usecases/{entity}_{action}.go`):
  - Struct with injected deps (repo, uow, tracing, idGen, acl)
  - Constructor `New{Entity}{Action}(...)`, Input/Output DTOs
  - `Execute(ctx, input) (output, error)`
  - **Execute order:** span start → ACL check FIRST → UoW Begin → build entity → Validate → persist → Release/Commit → return
- **Repository Interface** (`repository/{service}_repository.go`): CRUD methods returning domain entities
- **Supporting Interfaces**: acl_repository, tracing_repository, id_repository, env_repository, jwt_decoder_repository, uow
- **Constants** (`constants/errors.go`): `ErrNoPermission = errors.New("no permission")` (exact string)

### Infrastructure Layer (`internalpkg/infra/`)
- **Persistence** (`persistence/{service}_repository.go`): Implements interface, span SpanTypeInfra, extract conn from ctx, delegate to query adapters. **NEVER call SQLC directly, NEVER inline SQL**
- **UoW** (`persistence/uow.go`): `WowPGXTransactionless` (pool conn), `WowPGXTransaction` (tx + commit/rollback)
- **gRPC Service** (`grpc-service/{service}_service.go`): Implements proto, maps proto ↔ usecase
- **ACL** (`acl/acl_repository.go`): gRPC client, x-api-key via metadata
- **Tracing** (`tracing/apm.go`): Elastic APM, SpanTypeController/SpanTypeUseCase/SpanTypeInfra
- **JWT** (`jwt/jwt_adapter.go`): Wraps packages/jwt, JWKS URI from Zitadel
- **Lib** (`lib/`): database.go (pgxpool), migrations.go, adapters.go (container), env.go

## Service Protocol Types

Three supported types — same Clean Architecture layers, different API exposure:

| Type | Example | Entrypoint pattern |
|------|---------|-------------------|
| **Dual-protocol** | timekeeper | gRPC goroutine + HTTP blocking |
| **gRPC-only** | payment (current) | gRPC blocking only |
| **HTTP-only** | future services | HTTP blocking + Swagger/Scalar |

### Dual-Protocol Entrypoint (`cmd/api/api.go`)
Load env → APM → pgxpool → migrations → JWT → ACL → ID gen → UoW → repos → Adapters → UsecasesFactory →
```go
go func() { grpcServer.Listen(grpcPort) }() // Non-blocking
httpServer.Listen(httpPort)                 // Blocking
```

### HTTP Server (`api/http-server/server.go`)
Chi v5: RequestID, RealIP, Logger, Recoverer, 60s timeout, CORS all origins, APM.
Public: `/health`, `/ready`. Protected: `/api/v1/*` with JWT middleware (x-api-key header).

### HTTP-Only Services: Swagger/OpenAPI + Scalar
HTTP-exposed services MUST provide API documentation via Swagger/OpenAPI + Scalar UI:
- Generate OpenAPI 3.x spec from handler annotations or spec file
- Serve Scalar UI at `/docs` or `/api/docs` (public route, no auth)
- Spec file at `api/openapi/openapi.yaml` or generated from code annotations
- Keep spec in sync with handlers — update on every route change

### gRPC Server (`api/grpc-server/server.go`)
grpc.Server with APM interceptor, reflection enabled, `Listen(port)`.

### Authentication
- x-api-key header (contains JWT), NOT Authorization Bearer
- applicant_id from JWT via `ctxkeys.GetUserID(ctx)`
- company_id from body/query param (NOT from JWT)

## SQLC Query Adapter Pattern

**Repository → Query Adapter → SQLC**

### Query Adapter (`pkg/queries/{entity}_queries.go`)
```go
func CreateBranchParams(entity entity.Branch) sqlc.CreateBranchParams {
    return sqlc.CreateBranchParams{
        ID: toPgText(entity.Id().Value()),
        CompanyID: toPgText(entity.CompanyId().Value()),
        Name: toPgText(entity.Name()),
    }
}

func ToBranchEntity(row sqlc.Branch) entity.Branch {
    return entity.NewBranch(
        vo.NewId(fromPgText(row.ID)),
        vo.NewId(fromPgText(row.CompanyID)),
        fromPgText(row.Name),
    )
}
```

### Utils (`pkg/queries/utils.go`)
Helpers: `toPgText`, `fromPgText`, `toPgInt4`, `fromPgInt4`, etc.

### SQLC Queries (`pkg/sqlc/queries/{entity}_{action}.sql`)
```sql
-- name: CreateBranch :exec
INSERT INTO branches (...) VALUES (...);
-- name: GetBranchById :one
SELECT * FROM branches WHERE id = $1 AND deleted_at IS NULL;
-- name: ListBranches :many
SELECT * FROM branches WHERE company_id = $1 AND deleted_at IS NULL;
```

## Response Patterns

### HTTP Responses (`api/handlers/response.go`)
- `RespondJSON(w, status, data)`, `RespondSuccess(w, data)` (200), `RespondCreated(w, data)` (201)
- `RespondPaginated(w, items, page, size, total)`, `RespondError(w, status, message)`
- `DecodeJSON(r, v)` — parse request body

### Error Mapping
"no permission" → 403 | Validation → 400 | Not found → 404 | Other → 500

# Compliance Profile — Code ↔ Review Contract

Shared source of truth for code-agent and review-agent.
Code-agent MUST generate code matching REQUIRED items.
Review-agent MUST use severity mappings (not own interpretation).

## Severity Rules
- **REQUIRED** → 🔴 CRITICAL if missing
- **RECOMMENDED** → 🟡 WARNING if missing
- **OPTIONAL** → 🔵 SUGGESTION if missing
- **N/A** → SKIP (do not flag)

## Domain Layer (`domain/entity/`, `domain/vo/`)

### Entity
- REQUIRED: Private fields, constructor `New{Entity}(...)`, `Validate() error`, getters only
- REQUIRED: Business rule comments `RN-ENTITY-XX: description`
- RECOMMENDED: Business methods (Activate, Deactivate)
- OPTIONAL: Custom error types per entity

### Value Object
- REQUIRED: Constructor `New{VO}(value)`, `Validate()`, `String()`, `IsEmpty()`
- REQUIRED: Immutable (no mutation methods)

## Application Layer (`usecases/`, `repository/`, `constants/`)

### Usecase
- REQUIRED: Struct with injected deps (repo, uow, tracing, idGen, acl)
- REQUIRED: Constructor `New{Entity}{Action}(...)`, Input/Output DTOs (exported fields)
- REQUIRED: `Execute(ctx, input) (output, error)`
- REQUIRED: Execute order: span → ACL → UoW begin → build entity → validate → persist → commit → return
- REQUIRED: ACL check FIRST (before any business logic)
- REQUIRED: Tracing span `SpanTypeUseCase`, UoW lifecycle (Begin, defer Release, Commit)
- RECOMMENDED: CaptureError to tracing
- OPTIONAL: Event emission after persistence

### Repository Interface
- REQUIRED: CRUD methods return domain entities (not SQLC types)
- REQUIRED: ACL repo `Check{Entity}{Read|Write|Delete}(ctx, applicantId, companyId) (ACLResponse, error)`
- REQUIRED: Tracing repo `StartSpan(ctx, name, spanType)`, `CaptureError(ctx, err)`
- REQUIRED: ID repo `Generate() string` (KSUID 27 chars)
- REQUIRED: UoW interfaces: `UnitOfWorkTransactionlessRepository`, `UnitOfWorkTransactionRepository`
- RECOMMENDED: Env repo, JWT decoder repo

### Constants
- REQUIRED: `var ErrNoPermission = errors.New("no permission")` as sentinel error
- REQUIRED: Handlers MUST use `errors.Is(err, constants.ErrNoPermission)` — NEVER `err.Error() == "no permission"`
- RECOMMENDED: Domain-specific sentinel errors (ErrNotFound, ErrAlreadyExists, etc.)

## Infrastructure Layer (`persistence/`, `grpc-service/`, `acl/`, `tracing/`)

### Persistence Repository
- REQUIRED: Implements repo interface, start span `SpanTypeInfra`
- REQUIRED: Extract conn from ctx (UoW-injected keys), delegate to query adapters
- REQUIRED: NEVER call SQLC directly, NEVER inline SQL
- REQUIRED: **SQL Injection Prevention** — NEVER use `fmt.Sprintf`, string concatenation, or `pool.Exec(ctx, "SELECT ... WHERE id = '"+id+"'")` to build queries. ALL queries MUST use SQLC-generated parameterized functions. If a query can't be expressed in SQLC, use `pgx` parameterized queries (`$1`, `$2`) — NEVER interpolate values
- RECOMMENDED: CaptureError to tracing

### UoW Implementation
- REQUIRED: `WowPGXTransactionless` (Begin acquires pool, Release returns)
- REQUIRED: `WowPGXTransaction` (Begin starts tx, Commit commits, Release rollbacks)
- REQUIRED: Inject conn via ctx keys (PGXHANDLER_PGXCONN, PGXHANDLER_PGXPOOLCONN, PGXHANDLER_TX)

### gRPC Service (SECURITY CRITICAL)
- REQUIRED: Implements proto interface, maps proto → usecase input → proto response
- REQUIRED: Span type `SpanTypeController` (NOT SpanTypeInfra)
- REQUIRED: JWT validation (`checkUserToken()`) for user-resource operations — extract customerId from subject
- REQUIRED: Error sanitization — NEVER return `err.Error()` to client. Use: `"internal error"` for unknown errors, map known errors to specific messages
- REQUIRED: Error mapping: `"no permission"→PermissionDenied`, `"not found"→NotFound`, validation→InvalidArgument, other→Internal with generic message
- RECOMMENDED: Input validation before usecase

### ACL Client
- REQUIRED: gRPC client, `x-api-key` header via metadata (NOT Authorization Bearer)

### Tracing
- REQUIRED: Elastic APM, StartSpan, CaptureError
- REQUIRED: SpanTypes: `SpanTypeController`, `SpanTypeUseCase`, `SpanTypeInfra`

## API Layer (`handlers/`, `http-server/`, `grpc-server/`)

### HTTP Handlers
- REQUIRED: `applicant_id` from JWT via `ctxkeys.GetUserID(ctx)` (NOT body/query)
- REQUIRED: `company_id` from body (POST/PUT) or query param (GET/DELETE)
- REQUIRED: Error mapping: "no permission"→403, validation→400, not found→404, other→500
- REQUIRED: Response helpers: RespondJSON, RespondSuccess(200), RespondCreated(201), RespondPaginated, RespondError
- REQUIRED: Auth via `x-api-key` header (NOT Authorization Bearer)
- RECOMMENDED: Tracing span `SpanTypeController`

### HTTP Server
- REQUIRED: Chi v5, middlewares (RequestID, RealIP, Logger, Recoverer, 60s timeout, CORS, APM)
- REQUIRED: Public `/health`, `/ready`; Protected `/api/v1/*` with JWT middleware

### gRPC Server
- REQUIRED: grpc.Server with APM interceptor, reflection, `Listen(port)`

### Entrypoint (`cmd/api/api.go`)
- REQUIRED: Load env → APM → pgxpool → migrations → JWT → ACL → ID gen → UoW → repos → Adapters → UsecasesFactory
- REQUIRED: gRPC goroutine `go func() { grpcServer.Listen(grpcPort) }()`; HTTP blocking `httpServer.Listen(httpPort)`

## Database Layer (`db/`, `pkg/sqlc/`, `pkg/queries/`)

### Migrations
- REQUIRED: Numbered `000001_{desc}.up.sql` + `.down.sql`
- RECOMMENDED: Idempotent (IF NOT EXISTS)

### SQLC Queries
- REQUIRED: `schema.sql`, queries in `pkg/sqlc/queries/{entity}_{action}.sql`
- REQUIRED: Annotations: `:exec`, `:one`, `:many`, `:execrows`

### Query Adapters
- REQUIRED: `pkg/queries/{entity}_queries.go` (entity↔SQLC conversion)
- REQUIRED: Utils: `toPgText`, `fromPgText` in `pkg/queries/utils.go`

## Security (Cross-Cutting)
- REQUIRED: Error sanitization — NEVER return raw `err.Error()` to clients (HTTP or gRPC). Map known errors to specific messages, use generic "internal error" for unknown
- REQUIRED: Ownership verification — For resource-specific operations (cancel, update, delete), verify requester owns the resource (IDOR prevention). ACL checks roles; ownership checks resource access
- REQUIRED: Webhook fail-closed — Token validation MUST reject when token empty/not configured. `if expected == "" || token != expected { reject }`
- REQUIRED: HTTP body size limits — `http.MaxBytesReader(w, r.Body, 1<<20)` on webhook and public endpoints
- REQUIRED: Error wrapping — Use `fmt.Errorf("context: %w", err)`, NEVER `errors.New("msg: " + err.Error())`

## Resilience
- REQUIRED: Circuit breaker on ALL external API adapters (Asaas, ACL gRPC, etc.) — `gobreaker.CircuitBreaker` wrapping calls
- REQUIRED: Consistent CB usage — when adapter already has CB for some methods, ALL methods must use it
- RECOMMENDED: Retry with backoff for transient failures
- RECOMMENDED: Timeout contexts for external calls

## Database Integrity
- REQUIRED: Business invariants enforced at DB level (unique indexes, check constraints), not just application code
- REQUIRED: List queries MUST have LIMIT (default 100) to prevent unbounded result sets
- RECOMMENDED: Handle unique constraint violations gracefully (e.g., `pgerrcode.UniqueViolation`)

## Observability
- REQUIRED: Spans in handlers/usecases/infra with correct SpanTypes
- REQUIRED: CaptureError for all error paths
- RECOMMENDED: Structured logging, custom span metadata

## Code Quality
- REQUIRED: No dead code — delete orphaned functions, types, and test files after refactoring
- REQUIRED: Entity `Reconstruct*` function for DB hydration when using private fields without VOs
- REQUIRED: No debug prints (`fmt.Printf("DEBUG...")`, `log.Printf("DEBUG...")`) in committed code
- REQUIRED: No `tracing.CaptureError()` used as debug log — only for actual errors
- REQUIRED: No commented-out code committed (TODOs, dead relationships, old logic)
- REQUIRED: No compiled binaries in repo — add to `.gitignore`
- REQUIRED: No mock/fallback dependencies in production code (`if key == "" { useMock }` is FORBIDDEN)
- REQUIRED: No provider-specific naming in domain layer (use `ExternalProviderId`, not `AsaasId`)
- REQUIRED: Exhaustive branching — switch/if-else on input types must handle ALL cases with error on unknown
- REQUIRED: Consistent return types — when changing signature, update ALL return statements
- RECOMMENDED: Split adapter files by domain when they exceed 200 lines (e.g., `asaas.go` → `asaas_subscription.go`)

## Startup & Configuration
- REQUIRED: Required env vars validated at startup with `panic()` — NEVER silently use empty strings or fall back to mocks
- REQUIRED: Required dependencies are ALWAYS real — no conditional mock injection based on env var presence
- RECOMMENDED: Validate all external service configs (API keys, URLs) at startup, fail fast

## Testing
- REQUIRED: Entity/VO: table-driven, testify/assert, 100% coverage
- REQUIRED: Usecase: gomock, test ACL denied + happy path + errors, verify UoW, 90%+ coverage
- REQUIRED: Handler: httptest, test 200/400/403/404/500, verify JSON format
- RECOMMENDED: Integration tests (full request → response)

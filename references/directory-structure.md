# Directory Structure — Dual-Protocol Service

Reference: `apps/timekeeper/`

```
apps/{service-name}/
├── api/
│   ├── proto/                          # gRPC protocol definitions
│   │   ├── buf.yaml                    # Buf config
│   │   ├── {service}_service.proto     # Service + RPC methods
│   │   ├── {method}_request.proto      # 1 file per request
│   │   └── {method}_response.proto     # 1 file per response
│   ├── grpc-server/                    # gRPC server setup
│   │   └── server.go                   # NewGrpcServer, RegisterServices, Listen
│   ├── http-server/                    # HTTP server setup
│   │   └── server.go                   # Chi router, middlewares, routes
│   ├── handlers/                       # HTTP handlers
│   │   ├── {entity}_handler.go         # CRUD handlers
│   │   ├── health_handler.go           # Health check
│   │   └── response.go                 # Response helpers
│   ├── usecases-factory/               # DI container
│   │   └── usecases.go                 # Builds all usecases from Adapters
│   └── ctxkeys/                        # Context keys
│       └── ctxkeys.go                  # UserIDKey, UserClaimsKey
├── cmd/
│   └── api/
│       └── api.go                      # Entrypoint: gRPC goroutine + HTTP blocking
├── internalpkg/
│   ├── core/
│   │   ├── domain/
│   │   │   ├── entity/
│   │   │   │   ├── {entity}.go         # Entity with constructor, Validate(), getters
│   │   │   │   └── {entity}_test.go    # Unit tests (100% coverage)
│   │   │   └── vo/
│   │   │       ├── {vo}.go             # Value Object: constructor, Validate(), String(), IsEmpty()
│   │   │       └── {vo}_test.go        # Unit tests (100% coverage)
│   │   └── application/
│   │       ├── usecases/
│   │       │   ├── {entity}_{action}.go        # 1 usecase per file
│   │       │   └── {entity}_{action}_test.go   # Unit tests with gomock (90%+ coverage)
│   │       ├── repository/
│   │       │   ├── {service}_repository.go     # Main repo interface (100+ methods)
│   │       │   ├── acl_repository.go           # Check{Entity}{Read|Write|Delete}
│   │       │   ├── tracing_repository.go       # StartSpan, CaptureError, SpanTypes
│   │       │   ├── id_repository.go            # Generate() string (KSUID)
│   │       │   ├── env_repository.go           # GetPort, GetGrpcPort, etc.
│   │       │   ├── jwt_decoder_repository.go   # DecodeToken
│   │       │   └── uow.go                      # UnitOfWork interfaces
│   │       └── constants/
│   │           └── errors.go                   # ErrNoPermission + domain errors
│   └── infra/
│       ├── grpc-service/                       # gRPC handler implementations
│       │   └── {service}_service.go            # Proto interface impl, maps proto ↔ usecase
│       ├── persistence/
│       │   ├── {service}_repository.go         # Implements repo interface → query adapters
│       │   └── uow.go                          # WowPGXTransactionless + WowPGXTransaction
│       ├── acl/
│       │   └── acl_repository.go               # gRPC client to ACL service
│       ├── tracing/
│       │   └── apm.go                          # Elastic APM adapter
│       ├── jwt/
│       │   └── jwt_adapter.go                  # packages/jwt wrapper
│       └── lib/
│           ├── database.go                     # pgxpool.New()
│           ├── migrations.go                   # golang-migrate runner
│           ├── adapters.go                     # Adapters container struct
│           └── env.go                          # os.Getenv wrappers
├── pkg/
│   ├── grpc/pb/                                # Generated protobuf code (DO NOT EDIT)
│   ├── sqlc/
│   │   ├── queries/
│   │   │   └── {entity}_{action}.sql           # SQLC annotated queries
│   │   └── gen/                                # Generated SQLC code (DO NOT EDIT)
│   └── queries/
│       ├── {entity}_queries.go                 # Query adapters: entity ↔ SQLC params
│       └── utils.go                            # toPgText, fromPgText, mappers
├── db/
│   ├── schema.sql                              # Full DDL for SQLC
│   └── migrations/
│       ├── 000001_{desc}.up.sql                # Migration up
│       └── 000001_{desc}.down.sql              # Migration down
├── configs/
│   ├── sqlc.yml                                # SQLC config
│   └── env.example                             # PORT, GRPC_PORT, DATABASE_*, ACL_SERVICE_URL, etc.
├── build/
│   ├── Dockerfile.dev                          # Dev container
│   └── Dockerfile.prod                         # Prod container
├── test/
│   └── mock/
│       └── mock_{service}_repository.go        # gomock generated
├── CLAUDE.md                                   # Service-specific docs
├── Makefile                                    # run, build, test, sqlc, migrate-up, migrate-down, proto
├── go.mod
└── go.sum
```

## Key Directory Annotations

### api/
- `proto/`: Buf-managed proto files (1 service file, 1 request/response per RPC)
- `grpc-server/`: gRPC server with reflection + APM
- `http-server/`: Chi router with middlewares (RequestID, RealIP, Logger, Recoverer, timeout, CORS, APM)
- `handlers/`: HTTP handlers extract JWT claims, parse body/query, call usecases, respond
- `usecases-factory/`: DI container builds all usecases from Adapters
- `ctxkeys/`: Context keys for UserID, UserClaims

### internalpkg/core/
- `domain/entity/`: Business entities (private fields, constructors, Validate(), getters, business methods)
- `domain/vo/`: Value Objects (immutable, constructor validates)
- `application/usecases/`: 1 file per operation (Execute: span → ACL → UoW → entity → validate → persist)
- `application/repository/`: Interfaces only (no implementation)
- `application/constants/`: Error constants (ErrNoPermission mandatory)

### internalpkg/infra/
- `grpc-service/`: Implements proto service interface, maps proto ↔ usecase
- `persistence/`: Implements repo interface, delegates to query adapters
- `acl/`: gRPC client to ACL service (adds x-api-key header)
- `tracing/`: Elastic APM wrapper (StartSpan, CaptureError, SpanTypes)
- `jwt/`: JWT decoder using JWKS URI
- `lib/`: Adapters container, database pool, migrations, env config

### pkg/
- `grpc/pb/`: Generated from proto (buf generate or protoc)
- `sqlc/queries/`: SQL files with SQLC annotations (:exec, :one, :many, :execrows)
- `sqlc/gen/`: Generated Go code from SQLC (DO NOT EDIT)
- `queries/`: Query adapters convert entity ↔ SQLC params/results (NEVER call SQLC directly from repo)

### db/
- `schema.sql`: Full DDL for SQLC to parse
- `migrations/`: Numbered migrations (000001_*.up.sql, 000001_*.down.sql)

### cmd/api/
- `api.go`: Entrypoint — load env → init infra → start gRPC goroutine + HTTP blocking

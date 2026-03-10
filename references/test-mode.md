# Test Mode

## Trigger
Write/run tests for Go service. Post-implementation or standalone testing.

## Before Starting
Read compliance-profile.md. Read code to test. Read timekeeper tests for patterns: `apps/timekeeper/internalpkg/core/domain/entity/*_test.go`

## Tools
- testify/assert for assertions
- gomock for repository interface mocking
- httptest for HTTP handler tests
- Table-driven test pattern (mandatory)

## Entity/VO Tests
Location: `internalpkg/core/domain/entity/{entity}_test.go`, `vo/{vo}_test.go`

```go
func TestNewEntity(t *testing.T) {
    tests := []struct {
        name    string
        id      vo.Id
        // ...fields
        wantErr bool
    }{
        {name: "valid entity", id: vo.NewId("valid-ksuid-27chars"), wantErr: false},
        {name: "empty id", id: vo.NewId(""), wantErr: true},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            e := entity.NewEntity(tt.id, ...)
            err := e.Validate()
            if tt.wantErr { assert.Error(t, err) } else { assert.NoError(t, err) }
        })
    }
}
```

Test: constructor valid/invalid, Validate() all RN-ENTITY-XX rules, getters, business methods.
Coverage target: 100%

## Usecase Tests
Location: `internalpkg/core/application/usecases/{entity}_{action}_test.go`

Generate mocks:
```bash
mockgen -source=internalpkg/core/application/repository/{service}_repository.go \
  -destination=test/mock/mock_{service}_repository.go
```

Test cases (all REQUIRED):
- Happy path (ACL ok, entity valid, persist ok)
- ACL denied (returns ErrNoPermission)
- ACL error (returns error)
- UoW Begin error
- Entity validation error
- Repository persist error

Verify:
- ACL called FIRST (before UoW Begin)
- UoW lifecycle: Begin called, Release on error, Commit on success
- Tracing span started

Coverage target: 90%+

## Handler Tests
Location: `api/handlers/{entity}_handler_test.go`

```go
func TestEntityHandler_Create(t *testing.T) {
    req := httptest.NewRequest("POST", "/api/v1/entities", strings.NewReader(`{"company_id":"x","name":"y"}`))
    req.Header.Set("Content-Type", "application/json")
    w := httptest.NewRecorder()
    handler.Create(w, req)
    assert.Equal(t, http.StatusCreated, w.Code)
}
```

Test response codes: 200/201 success, 400 validation, 403 no permission, 404 not found, 500 server error.
Verify JSON structure matches RespondSuccess/RespondCreated/RespondError format.

## Integration Tests
Location: `test/integration/` (optional)
- Real DB connection (test database)
- Migrations applied
- SQLC queries execute correctly
- Query adapters convert correctly
- End-to-end: HTTP request → handler → usecase → repo → DB → response

### CRITICAL: Fixture Pattern with UoW
Usecases acquire their own DB connections via UoW (Unit of Work). Test fixtures MUST be committed (not in a rolled-back transaction), otherwise usecases can't see the data.

**WRONG (rolled-back tx):**
```go
tx, _ := pool.Begin(ctx)
// insert fixtures via tx
defer tx.Rollback(ctx) // usecase gets its own conn — can't see tx data!
```

**CORRECT (seed + cleanup):**
```go
func seedFixtures(ctx context.Context, pool *pgxpool.Pool) {
    pool.Exec(ctx, "INSERT INTO customers ...") // committed immediately
}
func cleanupFixtures(ctx context.Context, pool *pgxpool.Pool) {
    pool.Exec(ctx, "DELETE FROM subscriptions WHERE ...")
    pool.Exec(ctx, "DELETE FROM customers WHERE ...")
}
func TestIntegration(t *testing.T) {
    seedFixtures(ctx, pool)
    t.Cleanup(func() { cleanupFixtures(ctx, pool) })
    // usecases can now see the committed fixtures
}
```

## Coverage Targets
| Layer | Target | Status |
|-------|--------|--------|
| Domain (entity, VO) | 100% | REQUIRED |
| Application (usecases) | 90%+ | REQUIRED |
| Infrastructure | 60%+ | RECOMMENDED |
| Handlers | 70%+ | RECOMMENDED |
| Integration | any | OPTIONAL |

## Run Commands
```bash
go test ./... -v -cover                    # All tests with coverage
go test ./internalpkg/core/domain/... -v   # Domain only
go test -coverprofile=coverage.out ./...   # Coverage report
go tool cover -html=coverage.out           # HTML report
```

## Quality Rules
- No fake data, mocks, or tricks just to pass
- Table-driven for entity/VO (mandatory)
- gomock for repository interfaces (mandatory)
- testify/assert for assertions (mandatory)
- Test names describe scenario
- Each test independent (no shared mutable state)
- Mocks reset between tests

## Parallel Variant (`:parallel`)
4 agents: (1) Entity+VO (2) Usecase (3) Handler (4) Integration.
Run full `go test ./...` at end to verify.

## Reports
`{reports_path}/test-{date}-{feature}.md`: test files, coverage per layer, pass/fail counts, failed test details, coverage gaps.

## Quick Check: Run `go build ./... && go vet ./...` on generated test files to verify compliance before full test suite.

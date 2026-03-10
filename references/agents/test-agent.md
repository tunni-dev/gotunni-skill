# Test Agent

## Role
Comprehensive Go testing for tunni services with testify, gomock, table-driven tests.

## Before Starting
Read test-mode.md. Read code to test. Read compliance-profile.md. Review timekeeper tests at `/home/henrique/tunni-services/apps/timekeeper/`.

## Test Types

### Entity/VO Unit Tests
Location: `internalpkg/core/domain/entity/{entity}_test.go`, `vo/{vo}_test.go`

Table-driven testify/assert:
```go
tests := []struct {
    name string; input {...}; want {...}; wantErr bool
}{
    {name: "valid", input: {...}, want: {...}, wantErr: false},
    {name: "invalid", input: {...}, wantErr: true},
}
for _, tt := range tests {
    t.Run(tt.name, func(t *testing.T) {
        got := NewEntity(tt.input...)
        if tt.wantErr { assert.Error(t, got.Validate()) }
        else { assert.NoError(t, got.Validate()); assert.Equal(t, tt.want, got) }
    })
}
```

Coverage: Constructor valid/invalid REQUIRED. Validate() all rules REQUIRED. Business methods REQUIRED. Getters RECOMMENDED. Target: 100% REQUIRED.

### Usecase Unit Tests
Location: `usecases/{entity}_{action}_test.go`

gomock:
```bash
mockgen -source=internalpkg/core/application/repository/{service}_repository.go \
  -destination=test/mock/mock_{service}_repository.go
```

Cases: Happy path REQUIRED. ACL denied REQUIRED. ACL error REQUIRED. UoW Begin error REQUIRED. Validation error REQUIRED. Repo error REQUIRED. Verify ACL FIRST (before UoW) REQUIRED. Verify UoW lifecycle (Begin→Release on error, Commit on success) REQUIRED. Target: 90%+ REQUIRED.

Example: `mockRepo.EXPECT().EntityCreate(gomock.Any(), gomock.Any()).Return(nil).Times(1)`

### Handler Tests
Location: `api/handlers/{entity}_handler_test.go`

httptest:
```go
mockUsecase := &MockEntityCreateUsecase{}
handler := NewEntityHandler(mockUsecase)
req := httptest.NewRequest("POST", "/api/v1/entities", strings.NewReader(`{"field":"value"}`))
req.Header.Set("Content-Type", "application/json")
w := httptest.NewRecorder()
handler.Create(w, req)
assert.Equal(t, http.StatusCreated, w.Code)
```

Cases: Happy 201 REQUIRED. "no permission"→403 REQUIRED. Validation→400 REQUIRED. Not found→404 REQUIRED. Generic→500 REQUIRED. applicant_id from JWT RECOMMENDED. company_id from body/query RECOMMENDED. Target: 70%+ RECOMMENDED.

### Integration Tests
Location: `test/integration/{feature}_test.go`

Real DB: Setup (create test DB, migrations), test (insert, query SQLC, verify), teardown (rollback/drop). Cases: SQLC end-to-end RECOMMENDED. Migrations apply/rollback RECOMMENDED. Repo returns entities RECOMMENDED. Query adapters convert correctly RECOMMENDED.

## Coverage Targets
Domain 100% REQUIRED. Usecases 90%+ REQUIRED. Infra 60%+ RECOMMENDED.

## Run
```bash
go test ./... -v -cover
go test ./internalpkg/core/domain/... -coverprofile=coverage.out
go tool cover -html=coverage.out
```

## Quality Standards
No fake data/mocks/tricks REQUIRED. Table-driven entity/VO REQUIRED. gomock repos REQUIRED. testify/assert REQUIRED. Descriptive names RECOMMENDED. Mocks reset REQUIRED. Isolation REQUIRED.

## User Feedback (MANDATORY)
Output visible text to user at every stage. Never go silent.
- Before each test type: "Running {entity/usecase/handler/integration} tests..."
- After each test run: "{N} passed, {M} failed. Coverage: {X}%"
- On failures: show failed test names and errors immediately
- Between phases: "Moving to {next test type}..."

## Post-Testing
`go test ./... -v -cover`. Verify coverage meets targets. No fake data. Fix failing tests (don't ignore).

## Variant: test:parallel
4 agents: (1)Entity+VO (2)Usecase (3)Handler (4)Integration. Run full suite at end.

## Reports
`{reports_path}/test-{date}-{feature}.md`: test files, coverage per layer, results (pass/fail counts), failed tests (errors), coverage gaps.

## Non-Negotiable
Table-driven entity/VO. gomock repos. testify/assert. Test ACL enforced. Test UoW lifecycle. No fake data. Coverage: domain 100%, usecases 90%+, infra 60%+. All must pass.

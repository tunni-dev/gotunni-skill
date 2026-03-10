#!/bin/bash
# validate-go-service.sh - Validates a Go service against gotunni compliance rules
# Usage: ./validate-go-service.sh <service-path>
# Example: ./validate-go-service.sh apps/timekeeper
#
# Part of the GoTunni DevKit "Generate-Validate-Fix" pattern.
# Checks build, tests, entity encapsulation, ACL, SQLC adapters, file size, tracing, and env safety.

set -euo pipefail

# ── Colors ─────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

PASS="${GREEN}PASS${RESET}"
FAIL="${RED}FAIL${RESET}"
SKIP="${YELLOW}SKIP${RESET}"
WARN="${YELLOW}WARN${RESET}"

# ── Args ───────────────────────────────────────────────────────────────────────
SERVICE_PATH="${1:-}"
if [[ -z "$SERVICE_PATH" ]]; then
  echo -e "${RED}Usage: $0 <service-path>${RESET}"
  echo -e "  Example: $0 apps/timekeeper"
  exit 1
fi

# Resolve absolute path — support both relative and absolute
if [[ "$SERVICE_PATH" = /* ]]; then
  ABS_PATH="$SERVICE_PATH"
else
  ABS_PATH="$(pwd)/$SERVICE_PATH"
fi

if [[ ! -d "$ABS_PATH" ]]; then
  echo -e "${RED}Error: directory '$ABS_PATH' not found.${RESET}"
  exit 1
fi

SERVICE_NAME="$(basename "$ABS_PATH")"
echo -e "\n${BOLD}${CYAN}GoTunni Compliance Validator${RESET}"
echo -e "${BOLD}Service:${RESET} $SERVICE_NAME  (${ABS_PATH})"
echo -e "$(date '+%Y-%m-%d %H:%M:%S')\n"

# ── Result tracking ────────────────────────────────────────────────────────────
TOTAL=0; PASSED=0; FAILED=0; SKIPPED=0; WARNED=0

record() {
  local status="$1" label="$2" detail="${3:-}"
  TOTAL=$((TOTAL + 1))
  case "$status" in
    pass)  PASSED=$((PASSED + 1));   echo -e "  [${PASS}] $label${detail:+ — $detail}" ;;
    fail)  FAILED=$((FAILED + 1));   echo -e "  [${FAIL}] $label${detail:+ — $detail}" ;;
    skip)  SKIPPED=$((SKIPPED + 1)); echo -e "  [${SKIP}] $label${detail:+ — $detail}" ;;
    warn)  WARNED=$((WARNED + 1));   echo -e "  [${WARN}] $label${detail:+ — $detail}" ;;
  esac
}

section() { echo -e "\n${BOLD}${BLUE}$1${RESET}"; }

# ── Check 1: go build ──────────────────────────────────────────────────────────
section "1. Build"
pushd "$ABS_PATH" > /dev/null
if go build ./... 2>/tmp/gotunni-build-err; then
  record pass "go build ./..."
else
  record fail "go build ./..." "$(head -5 /tmp/gotunni-build-err | tr '\n' ' ')"
fi
popd > /dev/null

# ── Check 2: go vet ────────────────────────────────────────────────────────────
section "2. Vet"
pushd "$ABS_PATH" > /dev/null
if go vet ./... 2>/tmp/gotunni-vet-err; then
  record pass "go vet ./..."
else
  ISSUES="$(wc -l < /tmp/gotunni-vet-err | tr -d ' ') issue(s)"
  record fail "go vet ./..." "$ISSUES"
fi
popd > /dev/null

# ── Check 3: go test ───────────────────────────────────────────────────────────
section "3. Tests"
TEST_FILES="$(find "$ABS_PATH" -name '*_test.go' 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$TEST_FILES" -eq 0 ]]; then
  record skip "go test ./..." "no test files found"
else
  pushd "$ABS_PATH" > /dev/null
  if go test ./... -count=1 -timeout 120s 2>/tmp/gotunni-test-err; then
    record pass "go test ./..." "$TEST_FILES test file(s)"
  else
    FAIL_COUNT="$(grep -c '^--- FAIL' /tmp/gotunni-test-err 2>/dev/null || echo '?')"
    record fail "go test ./..." "$FAIL_COUNT failing test(s)"
  fi
  popd > /dev/null
fi

# ── Check 4: Entity private fields ────────────────────────────────────────────
section "4. Entity Encapsulation"
ENTITY_DIR="$ABS_PATH/internalpkg/core/domain/entity"
if [[ ! -d "$ENTITY_DIR" ]]; then
  record skip "Entity private fields" "no entity/ directory found"
else
  # Exported struct fields look like:  FieldName  Type  (capitalized, inside a struct block)
  EXPORTED_FIELDS="$(grep -rn '^\s\+[A-Z][a-zA-Z0-9]*\s\+[a-zA-Z]' "$ENTITY_DIR" --include='*.go' \
    | grep -v '//' | grep -v 'struct{' | grep -v 'interface{' || true)"
  if [[ -z "$EXPORTED_FIELDS" ]]; then
    record pass "Entity private fields"
  else
    COUNT="$(echo "$EXPORTED_FIELDS" | wc -l | tr -d ' ')"
    record fail "Entity private fields" "$COUNT exported field(s) detected — entities must use private fields + getters"
  fi
fi

# ── Check 5: New* constructors in entities ────────────────────────────────────
section "5. Entity Constructors"
if [[ ! -d "$ENTITY_DIR" ]]; then
  record skip "New* constructors" "no entity/ directory"
else
  ENTITY_FILES="$(find "$ENTITY_DIR" -name '*.go' ! -name '*_test.go' 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "$ENTITY_FILES" -eq 0 ]]; then
    record skip "New* constructors" "no entity files"
  else
    MISSING_CTOR="$(for f in $(find "$ENTITY_DIR" -name '*.go' ! -name '*_test.go'); do
      if ! grep -q 'func New' "$f"; then echo "$f"; fi
    done || true)"
    if [[ -z "$MISSING_CTOR" ]]; then
      record pass "New* constructors in all entity files"
    else
      COUNT="$(echo "$MISSING_CTOR" | wc -l | tr -d ' ')"
      record warn "New* constructors" "$COUNT entity file(s) missing constructor"
    fi
  fi
fi

# ── Check 6: ACL check in usecases ────────────────────────────────────────────
section "6. ACL Checks"
USECASE_DIR="$ABS_PATH/internalpkg/core/usecases"
if [[ ! -d "$USECASE_DIR" ]]; then
  record skip "ACL check in usecases" "no usecases/ directory"
else
  UC_FILES="$(find "$USECASE_DIR" -name '*.go' ! -name '*_test.go' ! -name 'interfaces.go' 2>/dev/null)"
  if [[ -z "$UC_FILES" ]]; then
    record skip "ACL check in usecases" "no usecase files"
  else
    MISSING_ACL=""
    while IFS= read -r f; do
      if ! grep -qE 'Check.*(Write|Read|Delete|Create|Update|List)' "$f"; then
        MISSING_ACL="$MISSING_ACL\n    $(basename "$f")"
      fi
    done <<< "$UC_FILES"
    if [[ -z "$MISSING_ACL" ]]; then
      record pass "ACL check present in all usecases"
    else
      COUNT="$(echo -e "$MISSING_ACL" | grep -c '\.go' || true)"
      record fail "ACL check in usecases" "$COUNT usecase(s) missing ACL check — must call acl.Check before business logic"
    fi
  fi
fi

# ── Check 7: No direct SQLC calls in repositories (must use adapters) ─────────
section "7. SQLC Adapter Usage"
PERSIST_DIR="$ABS_PATH/internalpkg/infra/persistence"
if [[ ! -d "$PERSIST_DIR" ]]; then
  record skip "SQLC adapter usage" "no persistence/ directory"
else
  # Direct SQLC calls look like: q.CreateXxx or queries.CreateXxx without going through adapter
  DIRECT_SQLC="$(grep -rn '\bq\.\(Get\|List\|Create\|Update\|Delete\|Insert\|Upsert\)' \
    "$PERSIST_DIR" --include='*.go' | grep -v '_test.go' | grep -v 'adapter' || true)"
  if [[ -z "$DIRECT_SQLC" ]]; then
    record pass "SQLC queries go through adapters"
  else
    COUNT="$(echo "$DIRECT_SQLC" | wc -l | tr -d ' ')"
    record warn "SQLC adapter usage" "$COUNT direct SQLC call(s) — prefer query adapters in pkg/queries/"
  fi
fi

# ── Check 8: File size (<200 lines) ───────────────────────────────────────────
section "8. File Size"
OVERSIZED=""
while IFS= read -r f; do
  LINES="$(wc -l < "$f")"
  if [[ "$LINES" -gt 200 ]]; then
    OVERSIZED="$OVERSIZED\n    $(basename "$f") ($LINES lines)"
  fi
done < <(find "$ABS_PATH" -name '*.go' ! -name '*_test.go' 2>/dev/null)

if [[ -z "$OVERSIZED" ]]; then
  record pass "All Go files under 200 lines"
else
  COUNT="$(echo -e "$OVERSIZED" | grep -c '\.go' || true)"
  record warn "File size" "$COUNT file(s) over 200 lines — consider splitting:$OVERSIZED"
fi

# ── Check 9: Tracing spans in handlers and usecases ───────────────────────────
section "9. Tracing Spans"
HANDLER_DIR="$ABS_PATH/internalpkg/infra"
if [[ ! -d "$HANDLER_DIR" ]]; then
  record skip "Tracing spans" "no infra/ directory"
else
  SPAN_FILES="$(grep -rl 'StartSpan\|apm\.StartSpan\|tracer\.StartSpan\|tracing\.Start' \
    "$ABS_PATH" --include='*.go' 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "$SPAN_FILES" -gt 0 ]]; then
    record pass "Tracing spans present" "$SPAN_FILES file(s) with spans"
  else
    record warn "Tracing spans" "no APM span calls found — handlers and usecases should instrument spans"
  fi
fi

# ── Check 10: No committed .env files ─────────────────────────────────────────
section "10. Env Safety"
ENV_FILES="$(find "$ABS_PATH" -name '.env' ! -name '.env_example' ! -name '.env.example' 2>/dev/null || true)"
if [[ -z "$ENV_FILES" ]]; then
  record pass "No .env files committed"
else
  COUNT="$(echo "$ENV_FILES" | wc -l | tr -d ' ')"
  record fail "Env safety" "$COUNT .env file(s) present — must not be committed"
fi

# ── Check 11: Test coverage (informational) ────────────────────────────────────
section "11. Coverage"
if [[ "$TEST_FILES" -eq 0 ]]; then
  record skip "Coverage report" "no test files"
else
  pushd "$ABS_PATH" > /dev/null
  COV_OUT="$(go test ./... -cover -count=1 -timeout 120s 2>/dev/null | grep 'coverage:' || true)"
  if [[ -n "$COV_OUT" ]]; then
    echo -e "${COV_OUT}" | while IFS= read -r line; do
      PKG="$(echo "$line" | awk '{print $1}')"
      PCT="$(echo "$line" | grep -oE '[0-9]+\.[0-9]+%' || echo '?')"
      echo -e "    $PKG → $PCT"
    done
    record pass "Coverage data collected"
  else
    record skip "Coverage report" "could not collect (build may have failed)"
  fi
  popd > /dev/null
fi

# ── Summary ────────────────────────────────────────────────────────────────────
echo -e "\n${BOLD}─────────────────────────────────────────${RESET}"
echo -e "${BOLD}Results for: $SERVICE_NAME${RESET}"
echo -e "  Total checks : $TOTAL"
echo -e "  ${GREEN}Passed${RESET}       : $PASSED"
echo -e "  ${RED}Failed${RESET}       : $FAILED"
echo -e "  ${YELLOW}Warnings${RESET}     : $WARNED"
echo -e "  ${YELLOW}Skipped${RESET}      : $SKIPPED"
echo -e "${BOLD}─────────────────────────────────────────${RESET}\n"

if [[ "$FAILED" -gt 0 ]]; then
  echo -e "${RED}${BOLD}COMPLIANCE: FAIL${RESET} — $FAILED critical issue(s) must be fixed."
  exit 1
elif [[ "$WARNED" -gt 0 ]]; then
  echo -e "${YELLOW}${BOLD}COMPLIANCE: WARN${RESET} — $WARNED warning(s). Review before merging."
  exit 0
else
  echo -e "${GREEN}${BOLD}COMPLIANCE: PASS${RESET} — Service meets gotunni standards."
  exit 0
fi

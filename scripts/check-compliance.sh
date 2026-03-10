#!/bin/bash
# check-compliance.sh - Quick compliance check for generated Go code
# Usage: ./check-compliance.sh <file-or-directory>
# Example: ./check-compliance.sh apps/payment/internalpkg/core/domain/entity/invoice.go
#          ./check-compliance.sh apps/payment/internalpkg/core/usecases/
#
# Designed to run after code generation (gotunni code mode) to catch
# compliance violations before they reach review. Fast — no compilation.

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
TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
  echo -e "${RED}Usage: $0 <file-or-directory>${RESET}"
  echo -e "  Example: $0 apps/payment/internalpkg/core/domain/entity/invoice.go"
  echo -e "  Example: $0 apps/payment/internalpkg/core/usecases/"
  exit 1
fi

# Resolve absolute path
if [[ "$TARGET" = /* ]]; then
  ABS_TARGET="$TARGET"
else
  ABS_TARGET="$(pwd)/$TARGET"
fi

if [[ ! -e "$ABS_TARGET" ]]; then
  echo -e "${RED}Error: '$ABS_TARGET' not found.${RESET}"
  exit 1
fi

# Collect .go files to check
if [[ -f "$ABS_TARGET" ]]; then
  mapfile -t GO_FILES < <(echo "$ABS_TARGET")
else
  mapfile -t GO_FILES < <(find "$ABS_TARGET" -name '*.go' ! -name '*_test.go' 2>/dev/null)
fi

if [[ "${#GO_FILES[@]}" -eq 0 ]]; then
  echo -e "${YELLOW}No Go files found at '$ABS_TARGET'.${RESET}"
  exit 0
fi

TARGET_LABEL="${TARGET}"
echo -e "\n${BOLD}${CYAN}GoTunni Quick Compliance Check${RESET}"
echo -e "${BOLD}Target:${RESET} $TARGET_LABEL"
echo -e "${BOLD}Files:${RESET}  ${#GO_FILES[@]} Go file(s)"
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

section() { echo -e "\n${BOLD}${BLUE}── $1${RESET}"; }

# ── Helpers ────────────────────────────────────────────────────────────────────

# Returns files matching a path pattern (substring)
files_matching() {
  local pattern="$1"
  printf '%s\n' "${GO_FILES[@]}" | grep -i "$pattern" || true
}

# Returns files NOT matching a path pattern
files_not_matching() {
  local pattern="$1"
  printf '%s\n' "${GO_FILES[@]}" | grep -iv "$pattern" || true
}

# ── Check 1: Entity private fields + New* constructor + Validate() ─────────────
section "1. Entity Structure"
ENTITY_FILES="$(files_matching 'entity')"
if [[ -z "$ENTITY_FILES" ]]; then
  record skip "Entity checks" "no entity files in target"
else
  while IFS= read -r f; do
    FNAME="$(basename "$f")"

    # Private fields: exported struct fields inside type...struct blocks
    EXPORTED="$(grep -n '^\s\+[A-Z][a-zA-Z0-9]*\s\+[a-zA-Z]' "$f" \
      | grep -v '//' | grep -v 'struct{' | grep -v 'interface{' || true)"
    if [[ -n "$EXPORTED" ]]; then
      COUNT="$(echo "$EXPORTED" | wc -l | tr -d ' ')"
      record fail "[$FNAME] Private fields" "$COUNT exported field(s) — use private fields + getters"
    else
      record pass "[$FNAME] Private fields"
    fi

    # New* constructor
    if grep -q 'func New' "$f"; then
      record pass "[$FNAME] New* constructor"
    else
      record fail "[$FNAME] New* constructor" "no New* constructor found"
    fi

    # Validate() method
    if grep -q 'func.*Validate()' "$f"; then
      record pass "[$FNAME] Validate() method"
    else
      record warn "[$FNAME] Validate() method" "no Validate() found — domain entities should self-validate"
    fi
  done <<< "$ENTITY_FILES"
fi

# ── Check 2: Usecase ACL check before business logic ──────────────────────────
section "2. Usecase ACL"
USECASE_FILES="$(files_matching 'usecase')"
if [[ -z "$USECASE_FILES" ]]; then
  record skip "Usecase ACL check" "no usecase files in target"
else
  while IFS= read -r f; do
    FNAME="$(basename "$f")"
    if grep -qE 'Check.*(Write|Read|Delete|Create|Update|List)' "$f"; then
      # Ensure ACL call appears BEFORE the first business logic (repository call)
      ACL_LINE="$(grep -n 'Check.*\(Write\|Read\|Delete\|Create\|Update\|List\)' "$f" | head -1 | cut -d: -f1)"
      REPO_LINE="$(grep -n '\brepo\.\|uc\.repo\.\|\.repository\.' "$f" | head -1 | cut -d: -f1)"
      if [[ -n "$ACL_LINE" && -n "$REPO_LINE" && "$ACL_LINE" -lt "$REPO_LINE" ]]; then
        record pass "[$FNAME] ACL check before business logic (line $ACL_LINE < repo line $REPO_LINE)"
      elif [[ -n "$ACL_LINE" && -z "$REPO_LINE" ]]; then
        record pass "[$FNAME] ACL check present (no repo calls detected)"
      else
        record warn "[$FNAME] ACL check order" "ACL line $ACL_LINE may be AFTER repo call line $REPO_LINE"
      fi
    else
      record fail "[$FNAME] ACL check" "no acl.Check call found — must check permissions before business logic"
    fi
  done <<< "$USECASE_FILES"
fi

# ── Check 3: Handler uses ctxkeys.GetUserID (not manual JWT parsing) ──────────
section "3. Handler Auth"
HANDLER_FILES="$(files_matching 'handler\|controller\|route')"
if [[ -z "$HANDLER_FILES" ]]; then
  record skip "Handler auth" "no handler files in target"
else
  while IFS= read -r f; do
    FNAME="$(basename "$f")"

    # Should use ctxkeys helper
    if grep -q 'ctxkeys.GetUserID\|ctxkeys\.Get' "$f"; then
      record pass "[$FNAME] Uses ctxkeys.GetUserID"
    else
      # Only flag if file actually handles a request (has http.Request or chi.URLParam)
      if grep -qE 'r\.Header|r\.Context|chi\.URLParam' "$f"; then
        record warn "[$FNAME] ctxkeys usage" "handler doesn't use ctxkeys.GetUserID — avoid manual JWT parsing"
      else
        record skip "[$FNAME] ctxkeys check" "doesn't appear to handle HTTP requests"
      fi
    fi

    # Should NOT do manual JWT parsing
    if grep -qE 'ParseJWT|jwt\.Parse|token\.Claims|Authorization.*Bearer' "$f"; then
      record fail "[$FNAME] No manual JWT parsing" "manual JWT parsing found — use ctxkeys.GetUserID instead"
    else
      record pass "[$FNAME] No manual JWT parsing"
    fi
  done <<< "$HANDLER_FILES"
fi

# ── Check 4: Response helpers (RespondSuccess / RespondCreated / RespondError) ─
section "4. Response Helpers"
if [[ -z "$HANDLER_FILES" ]]; then
  record skip "Response helpers" "no handler files in target"
else
  while IFS= read -r f; do
    FNAME="$(basename "$f")"
    if grep -qE 'RespondSuccess|RespondCreated|RespondPaginated|RespondError|RespondJSON' "$f"; then
      record pass "[$FNAME] Uses response helpers"
    else
      if grep -qE 'w\.Write|json\.NewEncoder|http\.Error' "$f"; then
        record fail "[$FNAME] Response helpers" "raw http.ResponseWriter write found — use Respond* helpers"
      else
        record skip "[$FNAME] Response helpers" "no HTTP writes detected"
      fi
    fi
  done <<< "$HANDLER_FILES"
fi

# ── Check 5: No inline SQL (only SQLC adapter calls) ──────────────────────────
section "5. No Inline SQL"
SQL_CHECKED=0
SQL_FAIL_COUNT=0
while IFS= read -r f; do
  FNAME="$(basename "$f")"
  SQL_CHECKED=$((SQL_CHECKED + 1))
  # Use case-sensitive match (no -i) so Go function names like Update/Delete don't trigger
  INLINE_SQL="$(grep -nE '\b(SELECT|INSERT|UPDATE|DELETE|FROM|WHERE)\b' "$f" \
    | grep -v '//' | grep -v '`' || true)"
  if [[ -n "$INLINE_SQL" ]]; then
    COUNT="$(echo "$INLINE_SQL" | wc -l | tr -d ' ')"
    record fail "[$FNAME] No inline SQL" "$COUNT SQL keyword(s) in non-query file — use SQLC adapters"
    SQL_FAIL_COUNT=$((SQL_FAIL_COUNT + 1))
  fi
done < <(printf '%s\n' "${GO_FILES[@]}" | grep -iv 'query\|sqlc\|migration\|_test' || true)

if [[ "$SQL_CHECKED" -gt 0 && "$SQL_FAIL_COUNT" -eq 0 ]]; then
  record pass "No inline SQL in $SQL_CHECKED non-query file(s)"
fi

# ── Check 6: Tracing spans ────────────────────────────────────────────────────
section "6. Tracing Spans"
HANDLER_OR_UC="$(printf '%s\n' "${GO_FILES[@]}" | grep -iE 'handler|usecase|controller' || true)"
if [[ -z "$HANDLER_OR_UC" ]]; then
  record skip "Tracing spans" "no handler/usecase files in target"
else
  HAS_SPANS=0
  MISSING_SPANS=0
  while IFS= read -r f; do
    FNAME="$(basename "$f")"
    if grep -qE 'StartSpan|apm\.StartSpan|tracer\.Start|tracing\.Start' "$f"; then
      HAS_SPANS=$((HAS_SPANS + 1))
    else
      MISSING_SPANS=$((MISSING_SPANS + 1))
      record warn "[$FNAME] Tracing span" "no APM span found — add StartSpan in Execute/handler function"
    fi
  done <<< "$HANDLER_OR_UC"
  if [[ "$HAS_SPANS" -gt 0 ]]; then
    record pass "Tracing spans present in $HAS_SPANS file(s)"
  fi
fi

# ── Check 7: File size (<200 lines) ───────────────────────────────────────────
section "7. File Size"
OVER_LIMIT=0
for f in "${GO_FILES[@]}"; do
  LINES="$(wc -l < "$f")"
  FNAME="$(basename "$f")"
  if [[ "$LINES" -gt 200 ]]; then
    record warn "[$FNAME] File size" "$LINES lines — exceeds 200-line limit, consider splitting"
    OVER_LIMIT=$((OVER_LIMIT + 1))
  fi
done
if [[ "$OVER_LIMIT" -eq 0 ]]; then
  record pass "All ${#GO_FILES[@]} file(s) within 200-line limit"
fi

# ── Summary ────────────────────────────────────────────────────────────────────
echo -e "\n${BOLD}─────────────────────────────────────────${RESET}"
echo -e "${BOLD}Results for: $TARGET_LABEL${RESET}"
echo -e "  Total checks : $TOTAL"
echo -e "  ${GREEN}Passed${RESET}       : $PASSED"
echo -e "  ${RED}Failed${RESET}       : $FAILED"
echo -e "  ${YELLOW}Warnings${RESET}     : $WARNED"
echo -e "  ${YELLOW}Skipped${RESET}      : $SKIPPED"
echo -e "${BOLD}─────────────────────────────────────────${RESET}\n"

if [[ "$FAILED" -gt 0 ]]; then
  echo -e "${RED}${BOLD}COMPLIANCE: FAIL${RESET} — $FAILED issue(s) must be fixed before review."
  exit 1
elif [[ "$WARNED" -gt 0 ]]; then
  echo -e "${YELLOW}${BOLD}COMPLIANCE: WARN${RESET} — $WARNED warning(s). Review recommended before merging."
  exit 0
else
  echo -e "${GREEN}${BOLD}COMPLIANCE: PASS${RESET} — Generated code meets gotunni standards."
  exit 0
fi

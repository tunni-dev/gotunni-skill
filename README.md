# GoTunni — Claude Code Skill for Go Microservices

> Full-cycle enterprise development skill that teaches Claude how to create, plan, implement, test, and review Go microservices with Clean Architecture patterns.

## Why GoTunni?

Without GoTunni, every conversation starts from scratch — you re-explain your architecture, coding standards, and review criteria every time. With GoTunni, Claude **already knows** your patterns:

| Without | With GoTunni |
|---------|-------------|
| "Use private fields with getters..." | Just say `/gotunni:code` |
| "Check ACL first, then UoW..." | Already enforced |
| "Review for security, performance..." | 7-layer review built-in |
| "Use table-driven tests with gomock..." | Auto-generated |
| 15+ messages of context-setting | **Zero** — patterns embedded |

## Modes

| Command | What it does |
|---------|-------------|
| `/gotunni:create-new-service` | Scaffolds a complete Go microservice in 8 phases: domain → app → infra → API → docs |
| `/gotunni:plan` | Analyzes requirements and generates a phased implementation plan with research |
| `/gotunni:code` | Implements entities, usecases, handlers following strict Clean Architecture |
| `/gotunni:review` | 7-layer enterprise code review: architecture, security, performance, resilience, observability, database, testing |
| `/gotunni:test` | Generates table-driven tests with gomock, testify. Targets: domain 100%, usecases 90%+ |
| `/gotunni:brainstorm` | Interactive architecture co-design with 4 mandatory user checkpoints |

### Variants

Append `:parallel` to run with multiple agents simultaneously:
- `/gotunni:code:parallel` — parallel implementation across layers
- `/gotunni:review:parallel` — 4 agents reviewing different layers concurrently
- `/gotunni:test:parallel` — parallel test generation per layer

Other variants: `/gotunni:code:fix` (minimal bug fix), `/gotunni:code:refactor` (preserve behavior), `/gotunni:plan:hard` (deep planning with research)

## Stack

| Technology | Purpose |
|-----------|---------|
| Go 1.23+ | Language |
| Chi v5 | HTTP router |
| gRPC + Protobuf (Buf) | RPC framework |
| PostgreSQL (pgx/v5) | Database |
| SQLC | Type-safe SQL |
| Elastic APM | Observability |
| RabbitMQ (Watermill) | Event publishing |
| KSUID (27 chars) | ID generation |
| Zitadel JWT/JWKS | Authentication |
| ACL service (gRPC) | Authorization |
| Swagger/OpenAPI + Scalar | HTTP API docs |

## Service Types Supported

- **gRPC-only** — e.g. payment service (internal microservice)
- **HTTP-only** — with Swagger/Scalar documentation (public-facing APIs)
- **Dual-protocol** — gRPC + HTTP Chi in the same binary (e.g. timekeeper)

## PUA Protocol (Mandatory)

Every GoTunni process runs under the [PUA skill](https://openpua.ai/) — a pressure-escalation engine that prevents lazy behavior, empty claims, and passive debugging.

**What it enforces:**
- `/pua` activates before any mode executes — no exceptions
- Every subagent spawned includes full PUA methodology (3 iron rules + 5-step method + proactivity checklist) in its prompt
- Failure triggers automatic pressure escalation (L1 mild → L4 hardcore)
- Completion requires evidence (build output, test output), not just claims
- A verification gate checklist must pass before any mode reports "done"

**Companion Superpowers (mandatory with PUA):**

| Superpower | Role |
|-----------|------|
| `systematic-debugging` | PUA adds motivation; systematic-debugging provides methodology (reproduce → isolate → hypothesize → test → verify) |
| `verification-before-completion` | Prevents fake "fixed!" claims. PUA drives solving; verification ensures it actually works. No stale proof — output must be AFTER last change |

**Per-mode enforcement:**

| Mode | PUA Rule |
|------|----------|
| `plan` | No vague steps — concrete inputs, outputs, validation criteria required |
| `code` | `go build` after every module, output pasted as proof |
| `code:fix` | Exhaust all hypotheses before asking user |
| `test` | No mocks to cheat, no skipping failures |
| `review` | Evidence-backed findings only, no guessing |
| `brainstorm` | Minimum 3 fundamentally different approaches |
| `create-new-service` | Every phase must compile, end-to-end validation at finish |

## What Claude Enforces

GoTunni embeds **44 non-negotiable rules** and a **compliance profile** that Claude checks automatically:

### Architecture
- Clean Architecture: domain → application → infrastructure (no reverse imports)
- Entity: private fields, `New*` constructor, `Validate()`, getters only
- Value Objects: immutable, `Validate()`, `String()`, `IsEmpty()`
- SQLC via query adapters only (never direct SQLC calls, never inline SQL)

### Security
- ACL check **first** in every usecase (before any business logic)
- `errors.Is(err, constants.ErrNoPermission)` — sentinel errors, never string comparison
- `x-api-key` header auth (JWT), never `Authorization: Bearer`
- Error sanitization: never expose `err.Error()` to clients
- Circuit breaker on all external API adapters

### Observability
- Elastic APM spans in handlers (`SpanTypeController`), usecases (`SpanTypeUseCase`), infra (`SpanTypeInfra`)
- `CaptureError()` on all error paths

### Testing
- Table-driven tests with `testify/assert` (mandatory)
- `gomock` for repository interfaces (mandatory)
- Coverage: domain 100%, usecases 90%+, infrastructure 60%+

## 7-Layer Code Review

When you run `/gotunni:review`, Claude evaluates your code across:

1. **Architecture** — Clean Arch boundaries, entity encapsulation, SQLC patterns
2. **Security** — ACL checks, auth flow, error sanitization, input validation
3. **Performance** — N+1 queries, pagination, context propagation, connection pools
4. **Resilience** — Error handling, UoW lifecycle, circuit breakers, timeouts
5. **Observability** — APM spans, CaptureError, correct SpanTypes
6. **Database** — Migrations (up+down), schema.sql, SQLC annotations, query adapters
7. **Testing** — Coverage targets, test quality, no fake data

Severity levels follow the compliance profile:
- 🔴 **CRITICAL** (REQUIRED missing) — blocks merge
- 🟡 **WARNING** (RECOMMENDED missing) — should fix
- 🔵 **SUGGESTION** (OPTIONAL) — nice to have

## Installation

### Claude Code

```bash
git clone https://github.com/tunni-dev/gotunni-skill.git ~/.claude/skills/gotunni
```

> **Note:** The [PUA skill](https://openpua.ai/) is a mandatory dependency. GoTunni will auto-install it on first run if not already present (clones from [github.com/tanweai/pua](https://github.com/tanweai/pua) to `~/.claude/skills/pua`).

### Claude.ai

1. Download this repo as ZIP
2. Go to **Settings > Capabilities > Skills**
3. Upload the ZIP file

### Updating

```bash
cd ~/.claude/skills/gotunni
git pull origin main
```

## Quick Start

After installation, just use any command in Claude Code:

```
> /gotunni:plan
> Add a CreateSubscription usecase to the payment service

> /gotunni:code
> Implement the subscription entity with monthly/yearly periodicity

> /gotunni:test
> Write tests for the subscription domain entity

> /gotunni:review
> Review the last 3 commits on feat/payment-asaas
```

## File Structure

```
gotunni-skill/
├── SKILL.md                          # Main skill file (always loaded)
├── references/                       # Loaded on demand
│   ├── architecture-patterns.md      # Entity, VO, usecase, SQLC templates
│   ├── code-mode.md                  # Code generation patterns
│   ├── review-mode.md                # 7-layer review checklist
│   ├── test-mode.md                  # Testing patterns
│   ├── plan-mode.md                  # Planning workflow
│   ├── brainstorm-mode.md            # Co-design workflow
│   ├── create-service-mode.md        # Service scaffold
│   ├── compliance-profile.md         # Severity definitions
│   ├── non-negotiable-rules.md       # 44 rules
│   ├── enterprise-checklist.md       # Pre-review gate
│   ├── directory-structure.md        # Canonical layout
│   ├── parallel-workflows.md         # Multi-agent patterns
│   └── agents/                       # Agent definitions for parallel mode
│       ├── code-agent.md
│       ├── review-agent.md
│       ├── test-agent.md
│       ├── plan-agent.md
│       ├── brainstorm-agent.md
│       └── create-service-agent.md
├── scripts/                          # Automation scripts
│   ├── ensure-pua-installed.sh       # Auto-installs PUA skill if missing
└── assets/                           # Templates
```

## License

MIT

---

Built for the [tunni-services](https://github.com/tunni-dev) monorepo. Follows the [Anthropic Skill Standard](https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/skills).

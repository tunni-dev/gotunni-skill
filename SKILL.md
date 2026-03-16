---
name: gotunni
description: "Full-cycle Go microservice development for tunni-services monorepo: create, plan, implement, test, review. Clean Architecture, dual-protocol (HTTP Chi + gRPC), PostgreSQL SQLC, ACL, Elastic APM. Use when user says 'create go service', 'implement go feature', 'plan go architecture', 'review go code', 'test go service', 'brainstorm go design', or works with apps/ services. NOT for: TypeScript, frontend, DevOps, or non-Go codebases."
compatibility: "claude-code"
metadata:
  author: tunni-dev
  version: 2.1.0
---

# GoTunni — Tunni Services Go Development Kit

Full-cycle enterprise development for Go microservices in the tunni-services monorepo. Covers service creation, planning, implementation, testing, and review.

## Activation Examples

**Should trigger:**
- "Create a new Go service for billing"
- "Add a CreateSubscription usecase to payment service"
- "Review my handler in apps/timekeeper"
- "Write tests for the invoice domain entity"
- "Brainstorm the architecture for the notification service"
- "Plan the implementation of the webhook processor"

**Should NOT trigger:**
- "Fix the TypeScript API gateway"
- "Update the React dashboard"
- "Configure the Kubernetes deployment"
- "Write a Python ETL script"

## PUA Protocol (MANDATORY — ALL MODES)

**Every gotunni process MUST activate `/pua` skill.** No exceptions. No mode is exempt.

### Activation Rules
1. **On session start**: Run `bash scripts/ensure-pua-installed.sh` to verify PUA is installed (auto-clones if missing). Then load PUA skill
2. **On agent spawn**: Every subagent prompt MUST include: `Activate /pua skill. Load PUA methodology (3 iron rules + 5-step method + proactivity checklist). Apply pressure escalation on failures.`
3. **On failure**: PUA pressure escalation activates automatically (L1→L4)
4. **On completion**: PUA proactivity checklist is mandatory before declaring "done"

### Integration Per Mode
| Mode | PUA Enforcement |
|------|----------------|
| **plan** | No vague plans. Every phase needs concrete steps, inputs, outputs, validation. Granularity too coarse = L2 |
| **code** | Build after every module. No "I think it works" — run `go build`, paste output. Empty claims = L2 |
| **code:fix** | Exhaust all hypotheses before asking user. Giving up without trying = L3 |
| **test** | No mocks to cheat. No skipping failing tests. Failed test = new hypothesis, not surrender |
| **review** | Flag real issues, not cosmetics. Verify findings with evidence. Guessing without searching = L2 |
| **brainstorm** | Explore ≥3 fundamentally different approaches. Stuck in same loop = L1 |
| **create-new-service** | Every phase must compile. End-to-end validation at finish. "Good enough" = L3 |

### Companion Superpowers (MANDATORY with PUA)
PUA alone motivates — these superpowers provide the methodology and verification:

**systematic-debugging**: Applied on every failure. PUA drives persistence; systematic-debugging provides the structured method (reproduce → isolate → hypothesize → test → verify). No random guessing — follow the method.

**verification-before-completion**: Prevents fake "fixed!" claims. Every "done" statement MUST be backed by verification output. PUA drives solving; verification ensures it actually works. No mode can report completion without passing the verification gate below.

### Verification Gate (ALL modes)
Before any mode reports completion, execute this PUA-enforced checklist:
- [ ] Code compiles? (`go build ./...` output attached)
- [ ] Tests pass? (`go test ./...` output attached)
- [ ] Same-module similar issues checked?
- [ ] Upstream/downstream impact verified?
- [ ] Edge cases covered?
- [ ] Evidence provided, not just claims?
- [ ] Verification ran AFTER last change? (not stale output from before the fix)

Failure to complete this checklist activates proactivity enforcement. "You said it's done — where's the evidence?"

## Before Any Code

1. **Activate `/pua` skill** (mandatory first step)
2. Read `/home/henrique/tunni-services/apps/timekeeper/` as reference implementation
3. Read `docs/code-standards.md` and `docs/system-architecture.md`
4. Read service-specific `CLAUDE.md` if maintaining existing service
5. Check existing ports: `grep -r "PORT=" apps/*/configs/.env_example`

## Stack

Go 1.23+ | Chi v5 (HTTP) | gRPC+Protobuf (Buf) | PostgreSQL (pgx/v5) | SQLC | Elastic APM | RabbitMQ (Watermill) | KSUID (27 chars) | Zitadel JWT/JWKS | ACL service (gRPC) | Swagger/OpenAPI + Scalar (HTTP docs)

## Architecture Summary

Clean Architecture, 3 layers:
- **Domain** (`entity` + `vo`): Private fields, `New*` constructors, `Validate()`, getters
- **Application** (`usecases` + `repository` interfaces): `Execute(ctx, input)`, ACL check first, UoW lifecycle
- **Infrastructure** (`persistence` + `grpc-service` + `lib` + `tracing`): Repo impl, gRPC handlers, adapters

**Service types**: gRPC-only (e.g. payment), HTTP-only (with Swagger/Scalar), or dual-protocol (gRPC goroutine + HTTP blocking). Entrypoint: `cmd/api/api.go`. HTTP-exposed services MUST serve Swagger/OpenAPI via Scalar UI. Details: `references/architecture-patterns.md`

## Modes

| Mode | Command | One-liner | Details |
|------|---------|-----------|---------|
| Create service | `/gotunni create-new-service` | 8-phase scaffold: domain → app → infra → API → docs | `references/create-service-mode.md` |
| Plan | `/gotunni plan` | Analyze requirements, generate phased plan in `plans/` | `references/plan-mode.md` |
| Code | `/gotunni code` | Generate entities, usecases, handlers. Variants: `:fix`, `:refactor`, `:parallel` | `references/code-mode.md` |
| Review | `/gotunni review` | 7-layer review: arch, security, perf, resilience, observability, DB, testing | `references/review-mode.md` |
| Test | `/gotunni test` | Table-driven tests, gomock, testify. Coverage: domain 100%, usecases 90%+ | `references/test-mode.md` |
| Brainstorm | `/gotunni brainstorm` | Interactive co-design with 4 mandatory user checkpoints. Never decides alone | `references/brainstorm-mode.md` |

## Composite Workflows

All workflows run under PUA protocol. `/pua` activates at start, persists through every phase.

| Flow | Chain |
|------|-------|
| New service | **pua** → create-new-service (all 8 phases) → pua verification gate |
| Feature | **pua** → plan → code → test → review → pua verification gate |
| Bug fix | **pua** → code:fix → test → pua verification gate |
| Review+fix | **pua** → review → code:fix → test → pua verification gate |
| Migration | **pua** → plan → code (migrations) → test → pua verification gate |
| Refactor | **pua** → review → code:refactor → test → pua verification gate |

Add `:parallel` to code/test/review for multi-agent execution. Details: `references/parallel-workflows.md`

## Key References

- **Non-negotiable rules** (44 rules, CRITICAL): `references/non-negotiable-rules.md`
- **Compliance profile** (CRITICAL/WARNING/SUGGESTION severity): `references/compliance-profile.md`
- **Architecture patterns** (entity/VO/usecase templates): `references/architecture-patterns.md`
- **Directory structure** (canonical layout): `references/directory-structure.md`
- **Enterprise checklist** (pre-review gate): `references/enterprise-checklist.md`
- **Agent files** (parallel mode): `references/agents/` — one agent per mode for parallel Task delegation

## User Feedback Protocol (MANDATORY)

The orchestrator MUST output visible text to the user at every stage. Silence is unacceptable.

### When Spawning Agents
**Before** launching agents, print a summary of what's about to happen.
**MANDATORY**: Every agent prompt MUST include PUA activation instruction.
```
Launching {N} agents in parallel (PUA enforced):
- Agent A: {description}
- Agent B: {description}
Estimated: ~{time} per agent. I'll report as each completes.
```

### On Agent Completion
**Immediately** after each background agent returns, print a brief summary:
```
Agent A (Architecture) completed: {X} critical, {Y} warnings found.
{2/4 done. Waiting for remaining agents...}
```

### Between Phases (Sequential Workflows)
When transitioning between sequential phases, print:
```
Phase 1 complete: {brief result}.
Starting Phase 2: {what happens next}...
```

### On Long Operations
If a `go build`, `go test`, or `sqlc generate` takes >5 seconds, print:
```
Running {command}... (this may take a moment)
```

### Consolidation
Before writing final reports, print:
```
All agents complete. Consolidating findings...
```

### Never Go Silent
- If waiting for background agents: tell the user you're waiting
- If blocked by an error: explain immediately
- If retrying something: say what failed and what you're trying next
- After writing a report: show the key findings inline, not just a file path

## Key Commands

`make run` | `make test` | `make sqlc` | `make proto` | `go build ./...` | `go test ./...` | `make migrate-up`

## Validation Commands

After each implementation phase, run:
```bash
go build ./...             # Must compile
go test -race ./... -cover # Must pass with race detector
go vet ./...               # Must pass
```

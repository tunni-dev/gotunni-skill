# Brainstorm Mode

## Trigger
Architecture decisions, entity modeling, cross-service design, gRPC API design, event patterns, refactoring strategies, performance optimization.

## Before Starting
Read SKILL.md. Read architecture-patterns.md, directory-structure.md. Read relevant service CLAUDE.md files. Read timekeeper as reference.

## Process — 8 Interactive Phases

**CRITICAL: Phases 2, 5, 6, 8 require `AskUserQuestion`. NEVER skip.**

### Phase 1: Scout
Discover relevant files/patterns. Read docs/. Map services, entities, dependencies.

### Phase 2: Discovery — `AskUserQuestion`
Clarify requirements, constraints, priorities. Confirm problem understanding.

### Phase 3: Research
Search docs, external sources, existing service patterns. Use `docs-seeker`, `WebSearch`, `sequential-thinking` as needed.

### Phase 4: Analysis
Evaluate 2-3 approaches against Clean Arch, dual-protocol, compliance. Go-specific implications.

### Phase 5: Debate — `AskUserQuestion`
Present options frankly. Challenge preferences. Ask which resonate, what's missing, what trade-offs matter.

### Phase 6: Consensus — `AskUserQuestion`
Present trade-off matrix. Ensure alignment before recommending.

### Phase 7: Documentation
Write report to `{plans_path}/reports/brainstorm-{date}-{topic}.md` with problem, options (user input included), co-decided recommendation, risks, next steps.

### Phase 8: Finalize — `AskUserQuestion`
Ask if user wants `/plan` for implementation. If yes, invoke with brainstorm context.

## Go Architecture Topics

- **Entity Modeling**: boundaries, aggregates, VOs, business rules, validation
- **Cross-Service**: gRPC sync vs RabbitMQ async, ACL scopes, proto versioning
- **Database**: KSUID, SQLC queries, UoW, migrations, indexes
- **Performance**: N+1, pgxpool, caching, goroutines, pagination
- **Events**: Watermill pub/sub, event schema, idempotency, DLQ
- **Observability**: Elastic APM spans, structured logging, metrics

## Key Constraints
- Clean Architecture boundaries (domain independence)
- Dual-protocol (HTTP Chi + gRPC) impact
- ACL integration, SQLC query adapter pattern
- Entity private fields / constructor / Validate()
- Files <200 lines
- Reference existing services as precedent

## Related: See references/non-negotiable-rules.md for constraints that designs must respect.

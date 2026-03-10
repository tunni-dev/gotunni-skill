# GoTunni — Claude Code Skill for Go Microservices

Full-cycle enterprise development skill for Go microservices in the tunni-services monorepo.

## What it does

Teaches Claude how to create, plan, implement, test, and review Go microservices following Clean Architecture, dual-protocol (HTTP Chi + gRPC), PostgreSQL SQLC, ACL, and Elastic APM patterns.

## Modes

| Mode | Command | Description |
|------|---------|-------------|
| Create | `/gotunni create-new-service` | 8-phase scaffold |
| Plan | `/gotunni plan` | Phased implementation plan |
| Code | `/gotunni code` | Entity, usecase, handler generation |
| Review | `/gotunni review` | 7-layer code review |
| Test | `/gotunni test` | Table-driven tests with gomock |
| Brainstorm | `/gotunni brainstorm` | Architecture co-design |

## Installation

### Claude Code (recommended)

```bash
# Clone to your Claude skills directory
git clone https://github.com/tunni-dev/gotunni-skill.git ~/.claude/skills/gotunni
```

### Updating

```bash
cd ~/.claude/skills/gotunni
git pull origin main
```

### Claude.ai

1. Download this repo as ZIP
2. Go to Settings > Capabilities > Skills
3. Upload the ZIP

## Stack

Go 1.23+ | Chi v5 | gRPC + Protobuf (Buf) | PostgreSQL (pgx/v5) | SQLC | Elastic APM | RabbitMQ (Watermill) | KSUID | Zitadel JWT/JWKS | ACL (gRPC) | Swagger/OpenAPI + Scalar

## Service Types Supported

- **gRPC-only** (e.g. payment service)
- **HTTP-only** (with Swagger/Scalar docs)
- **Dual-protocol** (gRPC + HTTP in same binary)

## License

MIT

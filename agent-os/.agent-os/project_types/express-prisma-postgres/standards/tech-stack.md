# Tech Stack

## Context

Global tech stack defaults for Agent OS projects, overridable in project-specific `.agent-os/product/tech-stack.md`.

- App Framework: Express
- Language: Node.js LTS
- Primary Database: PostgreSQL 17+
- ORM: Prisma
- Import Strategy: Node.js modules
- Package Manager: pnpm
- Node Version: 22 LTS
- Application Hosting: Amazon ECS
- Hosting Region: Amazon us west
- Database Hosting: Neon PostgreSQL
- Asset Storage: Amazon S3
- CDN: CloudFront
- Asset Access: Private with signed URLs
- CI/CD Platform: GitHub Actions
- CI/CD Trigger: Push to main branch
- Tests: Run before deployment
- Production Environment: main branch
- Staging Environment: main branch

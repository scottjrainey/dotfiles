# Prisma Style Guide

## Schema Design

- Use meaningful, domain-driven model names.
- Leverage Prisma schema features:
  - Use @id for primary keys.
  - Use @unique for natural unique identifiers.
  - Utilize @relation for explicit relationship definitions.
- Keep schemas normalized and DRY.
- Use meaningful field names and types.
- Implement soft delete with deletedAt timestamp.
- Use Prisma's native type decorators.

## Prisma Client Usage

- Always use type-safe Prisma client operations.
- Prefer transactions for complex, multi-step operations.
- Use Prisma middleware for cross-cutting concerns:
  - Logging
  - Soft delete
  - Auditing
- Handle optional relations explicitly.
- Use Prisma's filtering and pagination capabilities.

## Database Migrations

- Create migrations for schema changes.
- Use descriptive migration names.
- Review migrations before applying.
- Never modify existing migrations.
- Keep migrations idempotent.

## Error Handling with Prisma

- Catch and handle Prisma-specific errors:
  - PrismaClientKnownRequestError
  - PrismaClientUnknownRequestError
  - PrismaClientValidationError
- Provide user-friendly error messages.
- Log detailed error information for debugging.

## Testing Prisma Code

- Use in-memory database for unit tests.
- Mock Prisma client for isolated testing.
- Test different scenarios:
  - Successful operations
  - Error cases
  - Edge conditions
- Use factory methods for test data generation.
- Implement integration tests with actual database.

## Performance Considerations

- Use select and include judiciously.
- Avoid N+1 query problems.
- Use findMany with take and skip for pagination.
- Leverage Prisma's distinct for unique results.
- Profile and optimize database queries.

## Security Best Practices

- Never expose raw Prisma client in APIs.
- Use input validation before database operations.
- Implement row-level security.
- Sanitize and validate all user inputs.
- Use Prisma's built-in protections against SQL injection.

## Coding Style

- Keep Prisma-related code in dedicated repositories/modules.
- Separate data access logic from business logic.
- Create repository patterns for complex queries.
- Use dependency injection for Prisma services.

## Code Quality

- Follow SOLID principles.
- Prefer composition over inheritance.
- Write clean, readable, and maintainable code.
- Continuously refactor and improve code structure.

# Code Style Guide

## Context

Global code style rules for Agent OS projects.

<conditional-block context-check="general-formatting">
IF this General Formatting section already read in current context:
  SKIP: Re-reading this section
  NOTE: "Using General Formatting rules already in context"
ELSE:
  READ: The following formatting rules

## General Formatting

### Indentation

- Use 2 spaces for indentation (never tabs)
- Maintain consistent indentation throughout files
- Align nested structures for readability

### Naming Conventions

- **Methods and Variables**: Use snake_case (e.g., `user_profile`, `calculate_total`)
- **Classes and Modules**: Use PascalCase (e.g., `UserProfile`, `PaymentProcessor`)
- **Constants**: Use UPPER_SNAKE_CASE (e.g., `MAX_RETRY_COUNT`)

### String Formatting

- Use single quotes for strings: `'Hello World'`
- Use double quotes only when interpolation is needed
- Use template literals for multi-line strings or complex interpolation

### Code Comments

- Add brief comments above non-obvious business logic
- Document complex algorithms or calculations
- Explain the "why" behind implementation choices
- Never remove existing comments unless removing the associated code
- Update comments when modifying code to maintain accuracy
- Keep comments concise and relevant
</conditional-block>

<conditional-block task-condition="javascript" context-check="javascript-style">
IF current task involves writing or updating JavaScript:
  IF javascript-style.md already in context:
    SKIP: Re-reading this file
    NOTE: "Using JavaScript style guide already in context"
  ELSE:
    <context_fetcher_strategy>
      IF current agent is Claude Code AND context-fetcher agent exists:
        USE: @agent:context-fetcher
        REQUEST: "Get JavaScript style rules from code-style/javascript-style.md"
        PROCESS: Returned style rules
      ELSE:
        READ: @.agent-os/standards/code-style/javascript-style.md
    </context_fetcher_strategy>
ELSE:
  SKIP: JavaScript style guide not relevant to current task
</conditional-block>

<conditional-block task-condition="express" context-check="express-style">
IF current task involves writing or updating an Express web app:
  IF express-style.md already in context:
    SKIP: Re-reading this file
    NOTE: "Using Express style guide already in context"
  ELSE:
    <context_fetcher_strategy>
      IF current agent is Claude Code AND context-fetcher agent exists:
        USE: @agent:context-fetcher
        REQUEST: "Get Express style rules from code-style/express-style.md"
        PROCESS: Returned style rules
      ELSE:
        READ: @.agent-os/standards/code-style/express-style.md
    </context_fetcher_strategy>
ELSE:
  SKIP: Express style guide not relevant to current task
</conditional-block>

<conditional-block task-condition="prisma" context-check="prisma-style">
IF current task involves writing or updating Prisma schemas or ORM logic:
  IF prisma-style.md already in context:
    SKIP: Re-reading this file
    NOTE: "Using Prisma style guide already in context"
  ELSE:
    <context_fetcher_strategy>
      IF current agent is Claude Code AND context-fetcher agent exists:
        USE: @agent:context-fetcher
        REQUEST: "Get Prisma style rules from code-style/prisma-style.md"
        PROCESS: Returned style rules
      ELSE:
        READ: @.agent-os/standards/code-style/prisma-style.md
    </context_fetcher_strategy>
ELSE:
  SKIP: Prisma style guide not relevant to current task
</conditional-block>

<conditional-block task-condition="postgres" context-check="postgres-style">
IF current task involves writing or updating SQL:
  IF postgres-style.md already in context:
    SKIP: Re-reading this file
    NOTE: "Using Postgres style guide already in context"
  ELSE:
    <context_fetcher_strategy>
      IF current agent is Claude Code AND context-fetcher agent exists:
        USE: @agent:context-fetcher
        REQUEST: "Get Postgres style rules from code-style/postgres-style.md"
        PROCESS: Returned style rules
      ELSE:
        READ: @.agent-os/standards/code-style/postgres-style.md
    </context_fetcher_strategy>
ELSE:
  SKIP: Postgres style guide not relevant to current task
</conditional-block>

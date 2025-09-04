# Javascript Style Guide

## General

- Use ES6+ features with TypeScript for modern, maintainable code.
- Target ES2020 or later in `tsconfig.json` for optimal performance.
- Enable strict mode and strict null checks for type safety.
- Organize code into modules using import/export syntax.

## Module Organization

- Use named exports over default exports for better IDE support.
- Import only what you need to avoid namespace pollution.
- Group related functionality into logical modules.

```typescript
// ✅ Good
export { ChatAgent, VisionAgent };
import { ChatAgent, VisionAgent } from './agents';

// ❌ Bad  
export default { ChatAgent, VisionAgent };
```

## Variable Declarations

- Use `const` for values that won't be reassigned.
- Use `let` for values that will be reassigned.
- Never use `var` - it has function scope and can cause issues.

```typescript
// ✅ Good
const apiKey = process.env.API_KEY;
let retryCount = 0;

// ❌ Bad
var apiKey = process.env.API_KEY;
var retryCount = 0;
```

## Classes

- Use access modifiers (`private`, `protected`, `public`) for encapsulation.
- Define interfaces for class contracts.
- Use `readonly` for properties that shouldn't change after construction.

```typescript
interface IAgent {
  process(input: string): Promise<string>;
}

export class ChatAgent implements IAgent {
  private readonly apiKey: string;
  protected config: AgentConfig;

  constructor(apiKey: string, config: AgentConfig) {
    this.apiKey = apiKey;
    this.config = config;
  }

  async process(input: string): Promise<string> {
    return this.callAPI(input);
  }
}
```

## Functions

- Use arrow functions for callbacks and short functions.
- Use regular functions for class methods when `this` binding matters.
- Always define parameter and return types.

```typescript
// ✅ Good - Arrow function for callbacks
const processMessages = (messages: string[]): void => {
  messages.forEach(msg => console.log(msg));
};

// ✅ Good - Method with explicit types
async processInput(input: string): Promise<ProcessResult> {
  // implementation
}
```

## Destructuring

- Use destructuring for cleaner object and array access.
- Use rest/spread operators to handle variable arguments.

```typescript
// ✅ Good
const { model, temperature, maxTokens } = config;
const [first, ...rest] = responses;

// ❌ Bad
const model = config.model;
const temperature = config.temperature;
const first = responses[0];
```

## String Handling

- Use template literals for string interpolation and multi-line strings.
- Avoid string concatenation with `+` operator.

```typescript
// ✅ Good
const prompt = `
Context: ${context}
Question: ${question}
Please provide a response.
`;

// ❌ Bad
const prompt = 'Context: ' + context + '\nQuestion: ' + question;
```

## Async Operations

- Use async/await instead of promise chains for better readability.
- Always handle errors with try/catch blocks.
- Return typed promises.

```typescript
async processRequest(input: string): Promise<ProcessResult> {
  try {
    const validated = await this.validate(input);
    const response = await this.callModel(validated);
    return { success: true, data: response };
  } catch (error) {
    return { success: false, error: error.message };
  }
}
```

## Type Safety

- Define explicit interfaces for complex objects.
- Use union types for variables that can have multiple types.
- Avoid `any` - use `unknown` if type is truly unknown.

```typescript
interface AgentConfig {
  model: string;
  temperature: number;
  maxTokens?: number;
}

type ProcessResult = 
  | { success: true; data: string }
  | { success: false; error: string };

// ✅ Good
function parseResponse(response: unknown): string {
  if (typeof response === 'string') {
    return response;
  }
  throw new Error('Invalid response type');
}

// ❌ Bad
function parseResponse(response: any): string {
  return response;
}
```

## Error Handling

- Create custom error classes for different error types.
- Use strict null checks to prevent null/undefined errors.
- Validate inputs and provide meaningful error messages.

```typescript
class APIError extends Error {
  constructor(
    message: string,
    public statusCode: number
  ) {
    super(message);
    this.name = 'APIError';
  }
}

async callAPI(input: string): Promise<string> {
  if (!input.trim()) {
    throw new Error('Input cannot be empty');
  }
  
  const response = await fetch('/api', {
    method: 'POST',
    body: JSON.stringify({ input })
  });
  
  if (!response.ok) {
    throw new APIError(`API call failed`, response.status);
  }
  
  return response.text();
}
```

## Configuration

Configure `tsconfig.json` for modern TypeScript development:

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ES2020",
    "strict": true,
    "strictNullChecks": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "declaration": true
  }
}
```


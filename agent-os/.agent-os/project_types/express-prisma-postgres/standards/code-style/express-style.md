# Express.js Style Guide

- Use proper middleware order: body parsers, custom middleware, routes, error handlers
- Organize routes using Express Router for modular code structure
- Use async/await with proper error handling and try/catch blocks
- Create a centralized error handler middleware as the last middleware
- Use environment variables for configuration with a config module
- Implement request validation using libraries like express-validator
- Use middleware for authentication and authorization
- Use appropriate HTTP status codes in responses

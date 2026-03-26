# Claude Code Global Instructions

This file contains cross-project guidance that applies to all development work.

## General Coding Principles

### Code Quality
- Always read existing code patterns before implementing new features
- Maintain consistency with project conventions
- Ask for clarification when requirements are ambiguous
- Prefer small, focused changes over large refactors unless explicitly requested
- Follow the principle of least surprise - make code predictable

### Communication
- Be direct and concise in responses
- Avoid unnecessary commentary during execution
- Focus on actionable information
- Ask clarifying questions early in the process

### Error Handling
- Never ignore errors silently
- Log errors with appropriate context
- Provide helpful error messages to users
- Fail fast when something is wrong

## Testing Philosophy

### Test First When Possible
- Write tests for bug fixes to prevent regression
- Test edge cases and error conditions
- Ensure tests are maintainable and clear

### Test Coverage
- Aim for comprehensive coverage of business logic
- Don't test implementation details
- Focus on behavior, not structure

## Documentation Standards

### Code Documentation
- Document "why" not "what" in comments
- Keep documentation close to code
- Update docs when changing functionality
- Use meaningful variable and function names

### Project Documentation
- Check for project-specific CLAUDE.md files
- Maintain README files when making structural changes
- Document architectural decisions

## Security Best Practices

### Never Commit Secrets
- API keys, passwords, tokens stay in environment variables
- Use `.env` files locally, never commit them
- Check for accidental secret commits before pushing

### Input Validation
- Never trust user input
- Validate on the server, not just client
- Sanitize data before storage or display
- Be careful with user-generated SQL or code

## Version Control

### Commit Practices
- Never commit code, this should be left to the developer

## Performance Considerations

### Optimize When Necessary
- Profile before optimizing
- Focus on algorithmic improvements over micro-optimizations
- Consider caching for expensive operations
- Be mindful of database query performance

## Code Snippets and Tips

### Web Frameworks
- When working on HEEX or HTML use `{elixir}` instead of `<%= elixir %>`
- Prefer semantic HTML elements
- Use appropriate HTTP status codes
- Follow RESTful conventions when applicable

### Database
- Use transactions for related changes
- Index foreign keys and commonly queried columns
- Avoid N+1 query problems
- Use database constraints for data integrity

### API Design
- Version APIs when making breaking changes
- Use consistent naming conventions
- Provide clear error responses
- Document API endpoints

## Project-Specific Overrides

Always check for and prioritize:
1. Project-specific CLAUDE.md files
2. Team coding standards
3. Existing patterns in the codebase
4. Technology-specific best practices

## Continuous Improvement

- Learn from code review feedback
- Stay updated with best practices
- Adapt to project evolution
- Share knowledge through documentation

@RTK.md

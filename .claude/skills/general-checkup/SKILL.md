---
name: general-checkup
user-invocable: true
description: Comprehensive branch quality review covering completeness, testing, security, and refactoring opportunities.
---

# General Branch Checkup

Perform a comprehensive quality review of all changes in the current branch.

$ARGUMENTS

## Execution

### 1. Gather Context

First, understand what changed in this branch:

```bash
# See what files changed
git diff main...HEAD --name-only

# See the actual changes
git diff main...HEAD

# Review commit history
git log main..HEAD --oneline
```

### 2. Code Completeness

Review for incomplete work:
- [ ] All TODO/FIXME comments addressed or intentional
- [ ] No placeholder code or debug statements (dbg, IO.inspect)
- [ ] No commented-out code that should be removed
- [ ] Feature flags properly configured
- [ ] All new strings translated (if i18n applies)

### 3. Test Coverage

Assess test quality:
- [ ] Run `MIX_ENV=test mix coveralls` for coverage report
- [ ] New features have corresponding tests
- [ ] Edge cases and error conditions tested
- [ ] Tests are meaningful (not just testing implementation details)
- [ ] No skipped or pending tests without explanation

```bash
# Run tests with coverage
MIX_ENV=test mix coveralls

# Run only new/changed test files
mix test --failed
```

### 4. Code Quality

Check for code issues:

```bash
# Compile with warnings as errors
mix compile --warnings-as-errors

# Check for unused dependencies
mix deps.unlock --check-unused

# Verify formatting
mix format --check-formatted
```

Review for:
- [ ] No unused variables or imports
- [ ] Functions have appropriate complexity
- [ ] Pattern matching used over conditionals where appropriate
- [ ] Error handling is consistent and informative

### 5. Integration Check

Verify changes work well together:
- [ ] New features integrate with existing functionality
- [ ] No breaking changes to public APIs (or documented if intentional)
- [ ] Database migrations are safe for rollback
- [ ] Background jobs handle failures gracefully
- [ ] LiveView/frontend changes work across browsers

### 6. Security Quick Check

Basic security review:
- [ ] No hardcoded secrets or credentials
- [ ] Input validation present on user inputs
- [ ] Proper authorization checks on new actions
- [ ] No sensitive data logged
- [ ] CSRF protection in place for forms

### 7. Performance Considerations

Review for performance:
- [ ] No N+1 queries introduced
- [ ] Database queries are properly indexed
- [ ] Large data sets use streaming/pagination
- [ ] No blocking operations in request handlers

### 8. Documentation

Check documentation status:
- [ ] Complex logic has explanatory comments
- [ ] Public APIs are documented
- [ ] CHANGELOG updated if needed
- [ ] README updated if architecture changed

## Output Format

Create a report with findings organized by severity:

### Summary
Brief overview of branch changes and overall quality.

### Critical (Must fix before merge)
Issues that would cause bugs, security vulnerabilities, or data loss.

### High (Should fix before merge)
Issues that significantly impact code quality or user experience.

### Medium (Consider fixing)
Improvements that would enhance maintainability or performance.

### Low (Nice to have)
Minor suggestions and polish items.

### Positive Observations
Things done well that should continue.

### Refactoring Opportunities
Potential improvements for future work (not blockers).

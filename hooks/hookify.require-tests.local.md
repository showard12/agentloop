---
name: require-tests-before-stop
enabled: true
event: stop
action: block
conditions:
  - field: transcript
    operator: not_contains
    pattern: pytest|npm test|npm run test|npm run typecheck|cargo test|go test|bun test|vitest|jest|make test
---

**AgentLoop: Tests must be run before stopping!**

You have not run any test commands during this session. Before stopping:

1. Check `agentloop.config.json` for the project's test commands
2. Run ALL configured test commands
3. Ensure all tests pass
4. If tests fail, fix the issues and re-run

Only stop once all tests are passing.

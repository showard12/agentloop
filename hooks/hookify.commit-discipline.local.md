---
name: enforce-commit-message-format
enabled: true
event: bash
conditions:
  - field: command
    operator: regex_match
    pattern: git\s+commit.*-m
action: warn
---

**AgentLoop: Commit message format reminder**

Ensure your commit message follows the convention:
```
feat: [Task ID] - [Task Title]
```

Examples:
- `feat: 1.1 - Set up project structure`
- `fix: 2.3 - Fix authentication token refresh`
- `refactor: 3.1 - Extract shared validation utilities`

The Task ID must match the development plan's hierarchical ID (e.g., 1.1, 2.3, 4.5).

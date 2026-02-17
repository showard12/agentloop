---
name: require-progress-update
enabled: true
event: stop
action: warn
conditions:
  - field: transcript
    operator: not_contains
    pattern: agentloop-progress|progress\.txt|Progress Log
---

**AgentLoop: Remember to update the progress file!**

Before stopping, APPEND your iteration summary to the progress file. This is critical for future iterations to learn from your work.

Format:
```
## [Date] - [Task ID] - [Task Title]
- Implemented: [brief summary]
- Files: [list of files changed]
- Tests: PASS/FAIL
- **Learnings for future iterations:**
  - [patterns discovered]
  - [gotchas encountered]
---
```

If you discovered a reusable pattern, also add it to the `## Codebase Patterns` section at the top.

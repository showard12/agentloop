---
name: require-ac-verification
enabled: true
event: stop
action: warn
conditions:
  - field: transcript
    operator: not_contains
    pattern: AC Verification|Acceptance Criteria.*\[x\]|criteria met|Verification:.*\[x\]
---

**AgentLoop: Acceptance criteria verification required!**

Before stopping, you must explicitly verify each acceptance criterion from the Task Details section of the development plan.

Document your verification like this:

```
## AC Verification: [Task ID] - [Task Title]
- [x] Criterion 1 — How you verified it
- [x] Criterion 2 — How you verified it
```

Then update the VibeKanban task description with the verification results.

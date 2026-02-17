---
name: epic-completion-memory-save
enabled: true
event: stop
action: warn
conditions:
  - field: transcript
    operator: not_contains
    pattern: EPIC COMPLETE|epic.*complete|Epic.*fully complete
---

**AgentLoop: Did you check for epic completion?**

After completing a task, check if ALL tasks in the same epic are now `done` in VibeKanban.

If the epic is complete, you MUST save a comprehensive epic summary to claude-mem:

```
mcp__plugin_claude-mem_mcp-search__save_memory
  project: [from config]
  title: "EPIC COMPLETE: [Epic N] - [Epic Name]"
  text: |
    Tasks completed, architecture decisions, patterns established,
    integration points, gotchas & warnings for future work.
```

This epic-level memory is critical — it captures the big picture that individual task memories miss. Future iterations and sessions will search for these summaries when working on related features.

If no epic completed this iteration, you can ignore this warning.

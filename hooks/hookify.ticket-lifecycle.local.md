---
name: require-ticket-update-before-stop
enabled: true
event: stop
action: block
conditions:
  - field: transcript
    operator: not_contains
    pattern: mcp__vibe_kanban__update_task
---

**AgentLoop: VibeKanban ticket update required before stopping!**

You MUST update the VibeKanban task status before ending this session:

1. **Task completed**: Set status to `done` with completion log appended to description
2. **Task blocked**: Set status back to `todo` with blocking notes in description
3. **Task partially done**: Keep as `inprogress` with progress notes

Use `mcp__vibe_kanban__update_task` to update the task, then try stopping again.

---
description: Run a single AgentLoop iteration in the current session for debugging
allowed-tools: mcp__vibe_kanban__list_projects, mcp__vibe_kanban__list_tasks, mcp__vibe_kanban__get_task, mcp__vibe_kanban__update_task, mcp__plugin_claude-mem_mcp-search__search, mcp__plugin_claude-mem_mcp-search__get_observations, mcp__plugin_claude-mem_mcp-search__save_memory
version: 0.1.0
---

# AgentLoop — Single Iteration (Debug Mode)

Run ONE iteration of the autonomous loop directly in this session. Unlike the bash loop (which spawns fresh Claude instances), this runs in-process so you can see exactly what happens at each step.

## Pre-Flight

First, verify the setup by running these checks IN ORDER. Stop and report if any fail.

### Check 1: Config File

Read `agentloop.config.json`. If missing:
```
FAIL: agentloop.config.json not found.
Run /onboard-agentloop first to set up the project.
```

Print the config summary:
```
Project: [project_name]
VK Project ID: [vk_project_id]
Branch: [working_branch]
Test Commands: [list each]
Sprint Epics: [active_sprint.epics]
```

### Check 2: Development Plan

Read the file at `paths.development_plan` from config. If missing:
```
FAIL: Development plan not found at [path].
Run /onboard-agentloop to generate it.
```

Print: `Development plan: OK ([path])`

### Check 3: VibeKanban Connection

Use `mcp__vibe_kanban__list_projects` to list all projects.

If the tool call fails entirely:
```
FAIL: VibeKanban MCP server not responding.
Check ~/.claude/settings.json has the vibe_kanban MCP server configured.
```

If the project ID from config is not found in the list:
```
FAIL: VK project [id] not found.
Available projects: [list names and IDs]
```

Print: `VibeKanban: OK (project found)`

### Check 4: Task State

Use `mcp__vibe_kanban__list_tasks` for the project.

Print task counts:
```
Tasks: [total]
  todo:       [N]
  inprogress: [N]
  done:       [N]
```

If 0 todo tasks:
```
FAIL: No todo tasks available. All tasks may be done or blocked.
```

### Check 5: claude-mem Connection

Try `mcp__plugin_claude-mem_mcp-search__search` with query `"test"`, limit 1.

If the tool call fails (Chroma error, connection refused, etc.):
```
WARN: claude-mem not available (Chroma server not reachable).
Memory steps (2, 12, 13) will be SKIPPED. The loop will still work.
To fix: check that the claude-mem worker is running.
```
Set an internal flag: `MEMORY_AVAILABLE = false`

If it succeeds:
```
claude-mem: OK
```
Set: `MEMORY_AVAILABLE = true`

### Check 6: Progress File

Check if `agentloop-progress.txt` exists (or path from config). If missing:
```
WARN: Progress file not found. Will create on first completion.
```

Print: `Progress file: OK`

---

## If all checks pass, print:

```
All pre-flight checks passed. Starting iteration...
========================================
```

---

## Execute Iteration

Now run the full iteration workflow. Print a header before each step so it's easy to see progress.

### STEP 1/14: Load Context
```
>>> STEP 1/14: Loading context...
```
Read agentloop.config.json, the Codebase Patterns section of progress file, and AGENTS.md if it exists.

### STEP 2/14: Search Memory
```
>>> STEP 2/14: Searching memory...
```
**Skip if MEMORY_AVAILABLE is false** — print `Skipped (claude-mem unavailable)` and move on.

Otherwise, use `mcp__plugin_claude-mem_mcp-search__search` with query about the project area and the claude_mem_project from config.

### STEP 3/14: Select Next Task
```
>>> STEP 3/14: Selecting next task...
```
1. Read the development plan for task tables with dependencies
2. Use `mcp__vibe_kanban__list_tasks` to get current statuses
3. Cross-reference: available = status `todo` AND all dependencies `done` AND in active sprint epics
4. Rank by priority, complexity, epic order, unblocking factor
5. Print the ranking:
```
Available tasks:
  1. [ID] - [Title] (Priority: [H/M/L], Size: [S/M/L], Epic: [N]) — Score: [N]
  2. [ID] - [Title] ...

Selected: [ID] - [Title]
```

### STEP 4/14: Mark In Progress
```
>>> STEP 4/14: Marking task in progress...
```
Use `mcp__vibe_kanban__update_task` to set status to `inprogress`.

### STEP 5/14: Gather Task Context
```
>>> STEP 5/14: Gathering task context...
```
Read the Task Details section from the development plan for this task. Read relevant PRD sections. Explore relevant source files.

### STEP 6/14: Implement
```
>>> STEP 6/14: Implementing...
```
Plan approach, then make changes. ONE task only. Follow existing patterns.

### STEP 7/14: Verify Acceptance Criteria
```
>>> STEP 7/14: Verifying acceptance criteria...
```
Document verification of each criterion:
```
## AC Verification: [Task ID] - [Task Title]
- [x] Criterion 1 — How verified
- [x] Criterion 2 — How verified
```

### STEP 8/14: Run Tests
```
>>> STEP 8/14: Running tests...
```
Use `mcp__vibe_kanban__update_task` to set the task status to `inreview`.

Run ALL test commands from config. All must pass.

### STEP 9/14: Commit
```
>>> STEP 9/14: Committing...
```
Stage specific files and commit with format: `feat: [Task ID] - [Task Title]`

### STEP 10/14: Update VibeKanban
```
>>> STEP 10/14: Updating VibeKanban...
```
Append completion log to task description, set status to `done`.

### STEP 11/14: Log Progress
```
>>> STEP 11/14: Logging progress...
```
Append structured entry to progress file.

### STEP 12/14: Save Task Memory
```
>>> STEP 12/14: Saving memory...
```
**Skip if MEMORY_AVAILABLE is false** — print `Skipped (claude-mem unavailable)` and move on.

Otherwise, save to claude-mem with project tag.

### STEP 13/14: Check Epic Completion
```
>>> STEP 13/14: Checking epic completion...
```
Check if all tasks in the same epic are done in VK. If yes and **MEMORY_AVAILABLE is true**, save epic summary to claude-mem. If memory unavailable, just log the epic completion to progress file.

### STEP 14/14: Check Overall Completion
```
>>> STEP 14/14: Checking overall completion...
```
If all VK tasks done, print `ALL_TASKS_COMPLETE`. Otherwise print iteration summary.

---

## Completion

Print a final summary:
```
========================================
Iteration complete!
  Task: [ID] - [Title]
  Status: [done/failed]
  Commit: [hash if committed]
  Tests: [PASS/FAIL]
  VK Updated: [yes/no]
========================================
```

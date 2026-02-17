---
description: Check AgentLoop progress — task status, iteration history, and completion percentage
allowed-tools: mcp__vibe_kanban__list_projects, mcp__vibe_kanban__list_tasks
version: 0.1.0
---

# AgentLoop Status

You are checking the current status of the AgentLoop for this project.

## Instructions

### 1. Read Configuration

Read `agentloop.config.json`. If it doesn't exist:
```
AgentLoop is not configured for this project.
Run /onboard-agentloop to set up.
```

### 2. Read Progress File

Read the progress file (path from config, default `agentloop-progress.txt`).

Extract:
- Total iterations completed (count `##` headers that have task IDs)
- Last task completed (most recent entry)
- Any pause or failure entries
- Codebase patterns discovered

### 3. Query VibeKanban

Use `mcp__vibe_kanban__list_projects` and `mcp__vibe_kanban__list_tasks`.

Calculate:
- Total tasks
- Tasks by status: todo, inprogress, inreview, done
- Completion percentage: done / total

### 4. Read Development Plan

Read `docs/development-plan.md` (or configured path).

Calculate per-epic progress by cross-referencing VK task statuses with plan task IDs.

### 5. Display Status Report

```
╔═══════════════════════════════════════════════════════════════╗
║  AgentLoop Status Report                                      ║
╠═══════════════════════════════════════════════════════════════╣
║  Project:     [name]                                          ║
║  Branch:      [working_branch]                                ║
║  Started:     [from progress file header]                     ║
║  Iterations:  [count from progress file]                      ║
╠═══════════════════════════════════════════════════════════════╣
║  Overall Progress: [N]% ([done]/[total] tasks)                ║
║  ████████████████████░░░░░░░░░░ [N]%                          ║
╠═══════════════════════════════════════════════════════════════╣
║  Task Breakdown:                                              ║
║    Done:        [N]                                           ║
║    In Progress: [N]                                           ║
║    In Review:   [N]                                           ║
║    Todo:        [N]                                           ║
╠═══════════════════════════════════════════════════════════════╣
║  Epic Progress:                                               ║
║    1. [Epic Name]     ████████████████████ 100% (5/5)         ║
║    2. [Epic Name]     ██████████░░░░░░░░░░  50% (4/8)        ║
║    3. [Epic Name]     ░░░░░░░░░░░░░░░░░░░░   0% (0/6)       ║
╠═══════════════════════════════════════════════════════════════╣
║  Active Sprint: Epics [1, 2, 3]                               ║
║  Sprint Progress: [N]% ([done in sprint]/[total in sprint])   ║
╠═══════════════════════════════════════════════════════════════╣
║  Last Completed: [Task ID] - [Title] ([date])                 ║
║  Next Available: [Task ID] - [Title] ([priority], [complexity])║
╚═══════════════════════════════════════════════════════════════╝

Codebase Patterns Discovered: [N]
Pause/Failure Events: [N]
```

### 6. Show Warnings (if any)

- Tasks stuck `inprogress` for more than 1 iteration
- Dependencies that are violated (task done but dependency not done)
- Sprint complete but config not updated to next sprint
- Progress file shows consecutive failures

### 7. Suggest Actions

Based on status:
- If sprint complete: "Sprint 1 is complete! Update `active_sprint` in config to advance to next sprint."
- If tasks stuck: "Consider resetting stuck tasks to `todo` and investigating the blockers."
- If loop is paused: "Loop was paused. Remove `.agentloop-pause` and run `./agentloop.sh` to resume."
- If all done: "All tasks complete! Consider running /sync-plan to update the development plan."

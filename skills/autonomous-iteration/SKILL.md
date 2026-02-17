---
name: autonomous-iteration
description: Execute one task from the VibeKanban backlog autonomously — pick, implement, verify, commit, update
---

# Autonomous Iteration

This skill defines the per-iteration workflow for AgentLoop. Each iteration picks ONE task, implements it fully, and updates all tracking systems.

## Prerequisites

- `agentloop.config.json` exists in the project root
- VibeKanban MCP server is configured and accessible
- Development plan exists at the configured path
- Progress file exists (or will be created)

## Workflow

### Step 1: Load Context

1. Read `agentloop.config.json` for all project settings
2. Read the `## Codebase Patterns` section at the top of the progress file
3. Read `AGENTS.md` (if it exists) for project conventions

### Step 2: Search Memory

Query claude-mem for relevant past observations:
```
mcp__plugin_claude-mem_mcp-search__search
  query: [area you're about to work in]
  project: [from config: memory.claude_mem_project]
  limit: 5
```

If relevant results found, fetch details with `get_observations`.

### Step 3: Select Next Task

1. Read the development plan for epic structure, task tables, dependencies, and acceptance criteria
2. Use `mcp__vibe_kanban__list_projects` to find the VK project
3. Use `mcp__vibe_kanban__list_tasks` to get current statuses
4. Cross-reference to find **available** tasks:
   - Status = `todo` in VK
   - All "Depends On" tasks are `done` in VK
   - (If active sprint configured) Task is in an active epic

5. Rank available tasks:
   - Priority: High (30pts) > Medium (20pts) > Low (10pts)
   - Complexity: S (20pts) > M (15pts) > L (10pts) > XL (5pts)
   - Epic order: Earlier epics score higher
   - Unblocking: +5pts per task this unblocks

6. Select the highest-scoring task

### Step 4: Mark In Progress

Use `mcp__vibe_kanban__update_task` to set status to `inprogress`.

### Step 5: Gather Full Context

1. Read the Task Details / acceptance criteria section in the development plan
2. Read relevant PRD sections for product context
3. Read testing instructions
4. Explore relevant source code files

### Step 6: Implement

- Plan approach before writing code
- Make incremental, focused changes
- Follow existing patterns and conventions
- ONE task only — stay focused

### Step 7: Verify Acceptance Criteria

Document verification of EACH criterion:
```
## AC Verification: [Task ID] - [Task Title]
- [x] Criterion 1 — How verified
- [x] Criterion 2 — How verified
```

### Step 8: Run Tests

Run all test commands from the config. All must pass.

### Step 9: Commit

```bash
git add [specific files only]
git commit -m "feat: [Task ID] - [Task Title]"
```

### Step 10: Update VibeKanban

1. Get current task description
2. Append completion log with changes and AC verification
3. Set status to `done`

### Step 11: Log Progress

APPEND to progress file:
```
## [Date] - [Task ID] - [Task Title]
- Implemented: [summary]
- Files: [list]
- Tests: PASS/FAIL
- **Learnings:** [patterns, gotchas]
---
```

### Step 12: Save Task Memory

Save to claude-mem with project tag — summary of work done and patterns discovered.

### Step 13: Check Epic Completion — Save Epic Memory

After marking a task done, check if ALL other tasks in the same epic are also `done` in VK.

If the epic is complete:
1. Save a **comprehensive epic summary** to claude-mem with title `"EPIC COMPLETE: [Epic N] - [Name]"` containing: all tasks completed, architecture decisions, patterns established, integration points, and gotchas
2. Append an epic completion entry to progress.txt
3. Update AGENTS.md with conventions established during this epic

This is the most valuable memory save — it captures the big picture that individual task memories miss.

### Step 14: Check Overall Completion

If ALL VK tasks are `done`: output `<promise>ALL_TASKS_COMPLETE</promise>`
Otherwise: end normally for next iteration.

## Rules

- ONE task per iteration
- NEVER skip tests
- NEVER mark done without verifying AC
- ALWAYS update VK before stopping
- ALWAYS log to progress file
- On rate limit: output `RATE_LIMIT_DETECTED` and stop

---
description: Start the AgentLoop autonomous execution loop
allowed-tools: mcp__vibe_kanban__list_projects, mcp__vibe_kanban__list_tasks
version: 0.1.0
---

# Start AgentLoop

You are starting the AgentLoop autonomous execution loop for this project.

## Pre-Flight Checks

### 1. Verify Configuration Exists

Read `agentloop.config.json`. If it doesn't exist:
```
AgentLoop is not configured for this project.
Run /onboard-agentloop to set up autonomous development.
```

### 2. Verify VibeKanban Connectivity

Use `mcp__vibe_kanban__list_projects` to find the project. If not found:
```
VibeKanban project not found. Check:
1. Is the VK MCP server configured in Claude settings?
2. Does the project exist in VibeKanban?
3. Is vk_project_id correct in agentloop.config.json?
```

### 3. Show Task Summary

Use `mcp__vibe_kanban__list_tasks` and display:

```
╔═══════════════════════════════════════════════════════╗
║  AgentLoop Pre-Flight Check                           ║
╠═══════════════════════════════════════════════════════╣
║  Project: [name]                                      ║
║  Branch:  [working_branch]                            ║
╠═══════════════════════════════════════════════════════╣
║  Tasks: [total]                                       ║
║    Todo:        [N] ░░░░░░░░░░░░░░░░░░░░             ║
║    In Progress: [N] ████                              ║
║    In Review:   [N] ██                                ║
║    Done:        [N] ████████████████████████████████   ║
╠═══════════════════════════════════════════════════════╣
║  Sprint Epics: [active epics from config]             ║
║  Max Iterations: [from config]                        ║
║  Rate Limit Pause: [seconds]                          ║
╚═══════════════════════════════════════════════════════╝
```

### 4. Check for Blockers

- If ALL tasks are `done`: "All tasks are already complete! Nothing to do."
- If any tasks are `inprogress`: "Warning: [N] tasks are still in progress. These may be from a previous interrupted run. Consider resetting them to `todo` before starting."
- If `.agentloop-pause` exists: "Removing previous pause sentinel."

### 5. Confirm and Launch

Remove `.agentloop-pause` if it exists.

Display:
```
Ready to start AgentLoop.

To launch the autonomous loop, run in your terminal:
  ./agentloop.sh

Or with limited iterations for testing:
  ./agentloop.sh --max-iterations 5

The loop will run autonomously, picking up tasks from VibeKanban.
Monitor progress with /loop-status or by watching the terminal output.
Pause anytime with /loop-pause.
```

Note: The actual loop must be started from the terminal (not from within Claude Code) because it spawns fresh Claude instances.

---
description: Set up AgentLoop autonomous development for a project — generates PRD, plan, VK tasks, config, and hooks
allowed-tools: mcp__vibe_kanban__list_projects, mcp__vibe_kanban__create_task, mcp__vibe_kanban__list_tasks, mcp__vibe_kanban__get_task, mcp__plugin_claude-mem_mcp-search__save_memory
version: 0.1.0
---

# Onboard Project for AgentLoop

You are setting up a project for fully autonomous development using AgentLoop. This is an interactive onboarding process that will generate all required artifacts.

## Step 0: Verify Dependencies

Before starting, verify the required dependencies are available. Check each one and report status:

### Required
- **VibeKanban MCP**: Try `mcp__vibe_kanban__list_projects`. If it fails: "FAIL: VibeKanban MCP not configured. Run `./install.sh` from the agentloop plugin directory or add vibe_kanban to your MCP config."
- **hookify plugin**: Check if hookify rules can be created in `.claude/`. If the plugin isn't active, warn but continue.
- **jq**: Run `which jq`. If missing: "FAIL: jq required for agentloop.sh. Install with `brew install jq`."
- **git**: Run `git status`. If not a git repo: "WARN: Not a git repo. Initialize with `git init`."

### Optional (report status but don't block)
- **claude-mem**: Try `mcp__plugin_claude-mem_mcp-search__search` with query "test", limit 1. If it fails: "WARN: claude-mem unavailable — memory features will be skipped. To fix: `cd ~/.claude/plugins/marketplaces/thedotmack && bun run worker:restart`"
- **mobile-mcp**: Check if mobile MCP tools are available. If not: "INFO: mobile-mcp not installed. For mobile projects, run `claude mcp add mobile -- npx -y @mobilenext/mobile-mcp@latest`"
- **dev-browser**: Check if dev-browser skills are available. If not: "INFO: dev-browser not installed. For visual web testing, install from claude-plugins-official marketplace."
- **Docker**: Run `docker-compose version`. If missing: "INFO: Docker not found. Manual service management may be needed."

Print a summary table:
```
Dependency Check:
  ✓ VibeKanban MCP     — connected
  ✓ hookify            — active
  ✓ jq                 — v1.7
  ✓ git                — repo initialized
  ⚠ claude-mem         — unavailable (memory steps will be skipped)
  ⓘ mobile-mcp         — not installed (optional)
  ⓘ dev-browser         — not installed (optional)
  ✓ Docker             — v24.0.7
```

If any REQUIRED dependency fails, stop and tell the user how to fix it. Otherwise continue.

## Step 1: Gather Project Information

Ask the user for:

1. **Project roadmap/requirements** — One of:
   - Path to an existing PRD, roadmap, or requirements document
   - Path to CLAUDE.md or README with project documentation
   - Or the user can describe the project and features inline

2. **Testing instructions** — One of:
   - Path to existing testing docs
   - Or ask: "What commands run your tests?" (e.g., `pytest`, `npm test`, `npm run typecheck`)

3. **Setup instructions** — One of:
   - Path to existing setup docs
   - Or ask: "What commands set up the dev environment?" (e.g., `npm install`, `pip install -e '.[dev]'`)

4. **Project name** — Short identifier (used for VK project, claude-mem, branch names)

## Step 2: Auto-Detect Tech Stack

Explore the project root to detect:
- `package.json` → Node.js/TypeScript (npm/bun test commands)
- `pyproject.toml` / `setup.py` → Python (pytest)
- `Cargo.toml` → Rust (cargo test)
- `go.mod` → Go (go test)
- `Makefile` → Check for test/lint/build targets
- `docker-compose.yml` → Docker infrastructure
- `tsconfig.json` → TypeScript (tsc --noEmit for typecheck)

Report what you detected and confirm with the user.

## Step 3: Generate PRD

If the user provided a roadmap doc but NOT a structured PRD:

1. Read the roadmap document thoroughly
2. Use the `/generate-prd` workflow to create a structured PRD:
   - Ask 3-5 clarifying questions about scope, priorities, constraints
   - Generate `docs/prd.md` with clear feature descriptions and success criteria
3. Run `/prd-review` to identify gaps and refine

If the user already has a PRD at `docs/prd.md`, skip to Step 4.

## Step 4: Create Development Plan

Run the `/create-plan` workflow:
- Generate `docs/development-plan.md` with:
  - 3-10 epics organized by feature area
  - Tasks sized for ONE context window each (follow sizing guidelines below)
  - Dependencies mapped across epics
  - Priority assigned (High/Medium/Low)
  - Complexity estimated (S/M/L/XL)
  - Per-task acceptance criteria with testable conditions

**Task Sizing Guidelines (critical for autonomous execution):**
Right-sized tasks (fit in one iteration):
- Add a database column and migration
- Add a single API endpoint
- Add one UI component
- Write tests for one module
- Add validation to one form
- Configure one integration

Too big (must be split):
- "Build entire dashboard"
- "Add authentication"
- "Refactor the API layer"
- Anything requiring changes to 10+ files

## Step 5: Generate VibeKanban Tasks

Run the `/generate-tasks` workflow:
- Create VK tasks from the development plan
- Link task IDs back to the plan via `<!-- vk:ID -->` comments
- Set priorities and epic labels

Report the task count and breakdown by epic.

## Step 6: Generate Configuration

Create `agentloop.config.json` in the project root:

```json
{
  "project_name": "[detected/confirmed name]",
  "vk_project_id": "[from VK project creation]",
  "branch_prefix": "agentloop/",
  "main_branch": "main",
  "working_branch": "agentloop/sprint-1",
  "testing": {
    "commands": ["[detected test commands]"],
    "required_before_commit": true
  },
  "setup": {
    "commands": ["[detected setup commands]"],
    "verify_command": "[command to verify setup works]"
  },
  "loop": {
    "max_iterations": 100,
    "max_consecutive_failures": 3,
    "pause_on_rate_limit": true,
    "rate_limit_pause_seconds": 3600,
    "active_sprint": {
      "epics": [1, 2, 3],
      "description": "Foundation and core features"
    }
  },
  "memory": {
    "claude_mem_project": "[project-name-lowercase]",
    "save_task_completions": true
  },
  "paths": {
    "prd": "docs/prd.md",
    "development_plan": "docs/development-plan.md",
    "testing_instructions": "docs/testing.md",
    "setup_instructions": "docs/setup.md",
    "progress_file": "agentloop-progress.txt",
    "agents_md": "AGENTS.md"
  }
}
```

## Step 7: Install Hookify Rules

Copy the 6 hookify rule templates from the AgentLoop plugin to the project's `.claude/` directory:

1. `hookify.ticket-lifecycle.local.md` — Block stop without VK update
2. `hookify.require-tests.local.md` — Block stop without running tests
3. `hookify.require-ac-verify.local.md` — Block stop without AC verification
4. `hookify.progress-update.local.md` — Warn if progress file not updated
5. `hookify.commit-discipline.local.md` — Warn on commit format
6. `hookify.prevent-destructive.local.md` — Block destructive operations

**Important:** Customize the test command pattern in `hookify.require-tests.local.md` to match the project's actual test commands. For example, if the project uses `bun test`, add `bun test` to the pattern.

Read each template from the plugin's `hooks/` directory, customize if needed, and write to `.claude/` in the project root.

## Step 8: Initialize Progress File

Create `agentloop-progress.txt` in the project root:

```
# AgentLoop Progress Log - [Project Name]
Started: [current date/time]
Branch: agentloop/sprint-1
---

## Codebase Patterns
[Will be populated by autonomous iterations]

---
```

## Step 9: Save Project Context to Memory

Use `mcp__plugin_claude-mem_mcp-search__save_memory` to save:
- Project name and tech stack
- Key architectural decisions from the PRD
- Testing approach
- Directory structure overview
- Active sprint scope

## Step 10: Copy agentloop.sh

Copy the `agentloop.sh` script from the plugin directory to the project root. The plugin root can be found at `${CLAUDE_PLUGIN_ROOT}` or the user can specify the path.

Make it executable: `chmod +x agentloop.sh`

## Step 11: Verify Setup

1. Run one of the test commands to verify the test suite works
2. Verify VK connectivity: `mcp__vibe_kanban__list_projects` should show the project
3. Check git status is clean (or warn about uncommitted changes)

## Step 12: Output Summary

```
╔═══════════════════════════════════════════════════════════════╗
║  AgentLoop Onboarding Complete!                               ║
╠═══════════════════════════════════════════════════════════════╣
║  Project:        [name]                                       ║
║  VK Project:     [id]                                         ║
║  Tasks created:  [N] across [M] epics                         ║
║  Sprint 1:       Epics [1, 2, 3] ([N] tasks)                 ║
║  Testing:        [commands]                                   ║
║  Hookify rules:  6 active                                     ║
║  Branch:         agentloop/sprint-1                            ║
╚═══════════════════════════════════════════════════════════════╝

Files created:
  agentloop.config.json      — Project configuration
  agentloop-progress.txt     — Cross-iteration learnings
  agentloop.sh               — Orchestration loop script
  docs/prd.md                — Product requirements
  docs/development-plan.md   — Epic/task structure
  .claude/hookify.*.local.md — 6 enforcement rules

To start autonomous execution:
  ./agentloop.sh

To start with limited iterations:
  ./agentloop.sh --max-iterations 5

To check status:
  /loop-status

To pause a running loop:
  /loop-pause
```

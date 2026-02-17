#!/bin/bash
# AgentLoop - Autonomous agentic developer loop
# Bridges Ralph's fresh-instance pattern with VibeKanban task management
#
# Usage: ./agentloop.sh [--config path/to/config.json] [--max-iterations N]
#
# Prerequisites:
#   - claude CLI installed (npm install -g @anthropic-ai/claude-code)
#   - jq installed (brew install jq)
#   - Git repository initialized
#   - agentloop.config.json configured (run /onboard-agentloop first)
#   - VibeKanban MCP server configured in Claude settings

set -e

# ─── Logging (initialized early so errors are captured) ──────────────────────

LOG_DIR="agentloop-logs"
mkdir -p "$LOG_DIR"
RUN_TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
RUN_LOG="$LOG_DIR/run-${RUN_TIMESTAMP}.log"
LATEST_LOG="$LOG_DIR/latest.log"

log() {
  echo "$@" | tee -a "$RUN_LOG"
}

{
  echo "AgentLoop Run Log"
  echo "Started: $(date)"
  echo "=========================================="
  echo ""
} > "$RUN_LOG"

ln -sf "run-${RUN_TIMESTAMP}.log" "$LATEST_LOG"

# Capture all script output to the log
exec > >(tee -a "$RUN_LOG") 2>&1

# ─── Defaults ────────────────────────────────────────────────────────────────

CONFIG_FILE="agentloop.config.json"
MAX_ITERATIONS_CLI=""
VERBOSE=false

# ─── Parse Arguments ─────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case $1 in
    --config)
      CONFIG_FILE="$2"
      shift 2
      ;;
    --config=*)
      CONFIG_FILE="${1#*=}"
      shift
      ;;
    --max-iterations)
      MAX_ITERATIONS_CLI="$2"
      shift 2
      ;;
    --max-iterations=*)
      MAX_ITERATIONS_CLI="${1#*=}"
      shift
      ;;
    --verbose|-v)
      VERBOSE=true
      shift
      ;;
    --help|-h)
      echo "AgentLoop - Autonomous agentic developer loop"
      echo ""
      echo "Usage: ./agentloop.sh [options]"
      echo ""
      echo "Options:"
      echo "  --config PATH        Path to agentloop.config.json (default: ./agentloop.config.json)"
      echo "  --max-iterations N   Override max iterations from config"
      echo "  --verbose, -v        Show detailed output"
      echo "  --help, -h           Show this help"
      echo ""
      echo "Setup: Run /onboard-agentloop in Claude Code first."
      exit 0
      ;;
    *)
      # Accept bare number as max iterations for convenience
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS_CLI="$1"
      else
        echo "Warning: Unknown argument '$1'"
      fi
      shift
      ;;
  esac
done

# ─── Validate Prerequisites ─────────────────────────────────────────────────

if ! command -v claude &> /dev/null; then
  echo "Error: 'claude' CLI not found. Install with: npm install -g @anthropic-ai/claude-code"
  exit 1
fi

if ! command -v jq &> /dev/null; then
  echo "Error: 'jq' not found. Install with: brew install jq (macOS) or apt-get install jq (Linux)"
  exit 1
fi

if ! git rev-parse --is-inside-work-tree &> /dev/null 2>&1; then
  echo "Error: Not inside a git repository."
  exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: Config file '$CONFIG_FILE' not found."
  echo "Run /onboard-agentloop in Claude Code to set up this project."
  exit 1
fi

# ─── Read Configuration ─────────────────────────────────────────────────────

PROJECT_NAME=$(jq -r '.project_name // "Unknown"' "$CONFIG_FILE")
WORKING_BRANCH=$(jq -r '.working_branch // "main"' "$CONFIG_FILE")
MAIN_BRANCH=$(jq -r '.main_branch // "main"' "$CONFIG_FILE")
PROGRESS_FILE=$(jq -r '.paths.progress_file // "agentloop-progress.txt"' "$CONFIG_FILE")
DEVPLAN_PATH=$(jq -r '.paths.development_plan // "docs/development-plan.md"' "$CONFIG_FILE")
PRD_PATH=$(jq -r '.paths.prd // "docs/prd.md"' "$CONFIG_FILE")
TESTING_PATH=$(jq -r '.paths.testing_instructions // "docs/testing.md"' "$CONFIG_FILE")
SETUP_PATH=$(jq -r '.paths.setup_instructions // "docs/setup.md"' "$CONFIG_FILE")
AGENTS_MD=$(jq -r '.paths.agents_md // "AGENTS.md"' "$CONFIG_FILE")
CLAUDE_MEM_PROJECT=$(jq -r '.memory.claude_mem_project // "default"' "$CONFIG_FILE")

# Loop settings
MAX_ITERATIONS_CONFIG=$(jq -r '.loop.max_iterations // 100' "$CONFIG_FILE")
MAX_CONSECUTIVE_FAILURES=$(jq -r '.loop.max_consecutive_failures // 3' "$CONFIG_FILE")
PAUSE_ON_RATE_LIMIT=$(jq -r '.loop.pause_on_rate_limit // true' "$CONFIG_FILE")
RATE_LIMIT_PAUSE=$(jq -r '.loop.rate_limit_pause_seconds // 3600' "$CONFIG_FILE")

# Active sprint (for 1000+ task scale)
ACTIVE_EPICS=$(jq -r '.loop.active_sprint.epics // [] | join(", ")' "$CONFIG_FILE" 2>/dev/null)
if [[ -z "$ACTIVE_EPICS" || "$ACTIVE_EPICS" == "" ]]; then
  ACTIVE_EPICS="all"
fi

# Testing commands
TESTING_COMMANDS=$(jq -r '.testing.commands // [] | .[]' "$CONFIG_FILE" 2>/dev/null)

# Use CLI override if provided, otherwise use config value
if [[ -n "$MAX_ITERATIONS_CLI" ]]; then
  MAX_ITERATIONS="$MAX_ITERATIONS_CLI"
else
  MAX_ITERATIONS="$MAX_ITERATIONS_CONFIG"
fi

# ─── Archiving ───────────────────────────────────────────────────────────────

ARCHIVE_DIR="agentloop-archive"
LAST_BRANCH_FILE=".agentloop-last-branch"

if [[ -f "$LAST_BRANCH_FILE" ]]; then
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")
  if [[ -n "$LAST_BRANCH" && "$LAST_BRANCH" != "$WORKING_BRANCH" ]]; then
    DATE=$(date +%Y-%m-%d)
    FOLDER_NAME=$(echo "$LAST_BRANCH" | sed 's|^agentloop/||')
    ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"
    echo "Archiving previous run: $LAST_BRANCH"
    mkdir -p "$ARCHIVE_FOLDER"
    [[ -f "$PROGRESS_FILE" ]] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
    [[ -f "$CONFIG_FILE" ]] && cp "$CONFIG_FILE" "$ARCHIVE_FOLDER/"
    echo "  Archived to: $ARCHIVE_FOLDER"
    # Reset progress for new branch
    echo "# AgentLoop Progress Log - $PROJECT_NAME" > "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
    echo "Branch: $WORKING_BRANCH" >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"
    echo "" >> "$PROGRESS_FILE"
    echo "## Codebase Patterns" >> "$PROGRESS_FILE"
    echo "" >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"
  fi
fi

echo "$WORKING_BRANCH" > "$LAST_BRANCH_FILE"

# ─── Initialize Progress File ───────────────────────────────────────────────

if [[ ! -f "$PROGRESS_FILE" ]]; then
  echo "# AgentLoop Progress Log - $PROJECT_NAME" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "Branch: $WORKING_BRANCH" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
  echo "" >> "$PROGRESS_FILE"
  echo "## Codebase Patterns" >> "$PROGRESS_FILE"
  echo "" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

# ─── Ensure Correct Branch ──────────────────────────────────────────────────

CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
if [[ "$CURRENT_BRANCH" != "$WORKING_BRANCH" ]]; then
  log "Switching to branch: $WORKING_BRANCH"
  if ! git checkout "$WORKING_BRANCH" 2>/dev/null; then
    if ! git checkout -b "$WORKING_BRANCH" "$MAIN_BRANCH" 2>/dev/null; then
      log "Warning: Could not switch to $WORKING_BRANCH. Continuing on $CURRENT_BRANCH."
    fi
  fi
fi

# ─── Generate Per-Iteration Prompt ──────────────────────────────────────────

generate_iteration_prompt() {
  local iteration=$1
  local prompt_file=".claude/agentloop-iteration.md"

  mkdir -p .claude

  # Build testing commands list
  local test_cmds=""
  while IFS= read -r cmd; do
    if [[ -n "$cmd" ]]; then
      test_cmds="${test_cmds}\n- \`${cmd}\`"
    fi
  done <<< "$TESTING_COMMANDS"

  cat > "$prompt_file" << PROMPT_EOF
# AgentLoop — Iteration ${iteration} of ${MAX_ITERATIONS}

You are an autonomous coding agent. Execute ONE task per iteration, fully and completely.

## STEP 1: Read Context

Read these files for project context:
- \`${CONFIG_FILE}\` — Project configuration
- \`${PROGRESS_FILE}\` — Focus on the \`## Codebase Patterns\` section at the top
- \`${AGENTS_MD}\` — Project conventions (if it exists)

## STEP 2: Search Memory (OPTIONAL — skip if it fails)

Try searching for relevant past observations about this project:
\`\`\`
Use mcp__plugin_claude-mem_mcp-search__search with:
  query: "[project area you're about to work on]"
  project: "${CLAUDE_MEM_PROJECT}"
  limit: 5
\`\`\`
If results are relevant, fetch details with \`mcp__plugin_claude-mem_mcp-search__get_observations\`.

**If the memory tools fail** (Chroma connection error, MCP error, etc.), skip this step and continue. Memory is optional — the loop must not stop because of claude-mem issues.

## STEP 3: Select Next Task

1. Read \`${DEVPLAN_PATH}\` to understand epics, tasks, dependencies, and acceptance criteria
2. Use \`mcp__vibe_kanban__list_projects\` to find the project
3. Use \`mcp__vibe_kanban__list_tasks\` to get current task statuses
4. Cross-reference VK task statuses with the plan's dependency graph

A task is **available** if:
- Status is \`todo\` in VibeKanban
- ALL tasks listed in its "Depends On" column are \`done\` in VibeKanban
${ACTIVE_EPICS:+- Task belongs to active sprint epics: ${ACTIVE_EPICS}}

Rank available tasks by (in order):
1. **Dependencies satisfied** — Must be true (gate)
2. **Priority** — High > Medium > Low
3. **Complexity** — S > M > L (prefer smaller for momentum)
4. **Epic order** — Earlier epics first
5. **Unblocking factor** — Tasks that are dependencies for other tasks get a boost

Select the highest-ranked task.

## STEP 4: Mark Task In Progress

Use \`mcp__vibe_kanban__update_task\` to set the selected task's status to \`inprogress\`.

Output clearly: "Working on: [Task ID] - [Task Title]"

## STEP 5: Gather Task Context

1. Read the **Task Details** section in \`${DEVPLAN_PATH}\` for this task's acceptance criteria
2. Read relevant sections of \`${PRD_PATH}\` for product context
3. Read \`${TESTING_PATH}\` for testing instructions (if exists)
4. Explore relevant source files in the codebase

## STEP 6: Implement

- Plan your approach briefly before writing code
- Make incremental, focused changes
- Follow existing code patterns and conventions
- Stay focused on THIS task only — do not work on other tasks
- Keep changes atomic and reviewable

## STEP 7: Verify Acceptance Criteria

For EACH acceptance criterion from the Task Details:
\`\`\`
## AC Verification: [Task ID] - [Task Title]
- [x] [Criterion 1] — [How you verified it]
- [x] [Criterion 2] — [How you verified it]
\`\`\`

## STEP 8: Run Tests

Execute ALL of these test commands:
${test_cmds}

ALL tests must pass before proceeding to commit. If tests fail, fix the issues and re-run.

## STEP 9: Commit

Stage ONLY the files you changed (no \`git add .\`):
\`\`\`bash
git add [specific files]
git commit -m "feat: [Task ID] - [Task Title]"
\`\`\`

## STEP 10: Update VibeKanban

1. Use \`mcp__vibe_kanban__get_task\` to read the current task description
2. Use \`mcp__vibe_kanban__update_task\` to set the description to the original PLUS this appended:

\`\`\`
---
## Completion Log
**Agent:** AgentLoop iteration ${iteration}
**Branch:** ${WORKING_BRANCH}

### Changes
- [file1]: [what changed]
- [file2]: [what changed]

### AC Verification
- [x] [criterion 1] — [how verified]
- [x] [criterion 2] — [how verified]
\`\`\`

3. Set the task status to \`done\`

## STEP 11: Update Progress File

APPEND (never replace) to \`${PROGRESS_FILE}\`:

\`\`\`
## $(date '+%Y-%m-%d %H:%M') - [Task ID] - [Task Title]
- Implemented: [brief summary]
- Files: [list of files changed]
- Tests: PASS/FAIL
- **Learnings for future iterations:**
  - [patterns discovered]
  - [gotchas encountered]
---
\`\`\`

If you discovered a REUSABLE pattern, also add it to the \`## Codebase Patterns\` section at the TOP of the file.

## STEP 12: Save Task Memory (OPTIONAL — skip if it fails)

Try to save to claude-mem. **If the tool fails, skip and continue.**

Use \`mcp__plugin_claude-mem_mcp-search__save_memory\`:
- project: "${CLAUDE_MEM_PROJECT}"
- text: Summary of what was done, key decisions, patterns discovered
- title: "[Task ID] - [Task Title] completion"

## STEP 13: Check Epic Completion — Save Epic Memory (memory save optional)

After marking a task done, check if ALL other tasks in the same epic are also \`done\` in VK.

**How to check:** Look at the development plan's task table for the epic this task belongs to. For each task in that epic, check its VK status. If every task in the epic is now \`done\`:

1. This epic is complete! Try to save a **comprehensive epic summary** to claude-mem (skip if tool fails):
\`\`\`
Use mcp__plugin_claude-mem_mcp-search__save_memory with:
  project: "${CLAUDE_MEM_PROJECT}"
  title: "EPIC COMPLETE: [Epic N] - [Epic Name]"
  text: |
    Epic [N] - [Epic Name] is fully complete.

    ## Tasks Completed
    - [ID] [Title] — [1-line summary]
    - [ID] [Title] — [1-line summary]
    ...

    ## Architecture Decisions
    - [Key decisions made during this epic]

    ## Patterns Established
    - [Coding patterns, conventions, utilities created]

    ## Integration Points
    - [How this epic's work connects to other epics]

    ## Gotchas & Warnings
    - [Things future work should watch out for]
\`\`\`

2. Also append to \`${PROGRESS_FILE}\`:
\`\`\`
## EPIC COMPLETE: [Epic N] - [Epic Name]
All [N] tasks done. Key outcomes: [summary]
Patterns: [list]. Gotchas: [list].
---
\`\`\`

3. Update \`${AGENTS_MD}\` with any project-wide conventions established during this epic.

If the epic is NOT complete yet, skip this step.

## STEP 14: Check Overall Completion

Use \`mcp__vibe_kanban__list_tasks\` to check remaining tasks:
- If ALL tasks are \`done\`: Output \`<promise>ALL_TASKS_COMPLETE</promise>\` and stop
- If tasks remain: End normally (the loop will spawn the next iteration)
- If an epic just completed and the next sprint's epics aren't in the active config: mention "Sprint advancement may be needed"

## CRITICAL RULES

- Work on **ONE task** per iteration
- **NEVER** skip tests
- **NEVER** mark a task done without verifying ALL acceptance criteria
- **ALWAYS** update VibeKanban before stopping
- **ALWAYS** append to progress file before stopping
- **ALWAYS** commit changes before updating VK status
- Keep commits focused and atomic
- Follow existing code conventions
- If you encounter a rate limit or API error, output \`RATE_LIMIT_DETECTED\` and stop cleanly

PROMPT_EOF

  echo "$prompt_file"
}

# ─── Main Loop ───────────────────────────────────────────────────────────────

CONSECUTIVE_FAILURES=0
TASKS_COMPLETED=0

log ""
log "╔═══════════════════════════════════════════════════════════════╗"
log "║  AgentLoop — Autonomous Agentic Developer Loop               ║"
log "╠═══════════════════════════════════════════════════════════════╣"
log "║  Project:        $PROJECT_NAME"
log "║  Branch:         $WORKING_BRANCH"
log "║  Max iterations: $MAX_ITERATIONS"
log "║  Sprint epics:   $ACTIVE_EPICS"
log "║  Config:         $CONFIG_FILE"
log "║  Log file:       $RUN_LOG"
log "╚═══════════════════════════════════════════════════════════════╝"
log ""

for i in $(seq 1 "$MAX_ITERATIONS"); do
  log ""
  log "═══════════════════════════════════════════════════════════════"
  log "  Iteration $i of $MAX_ITERATIONS | Tasks completed: $TASKS_COMPLETED | Failures: $CONSECUTIVE_FAILURES"
  log "  $(date '+%Y-%m-%d %H:%M:%S')"
  log "═══════════════════════════════════════════════════════════════"

  # Per-iteration log file
  ITER_LOG="$LOG_DIR/iteration-$(printf '%03d' $i)-${RUN_TIMESTAMP}.log"

  # ── Check for pause sentinel ────────────────────────────────────────────
  if [[ -f ".agentloop-pause" ]]; then
    log ""
    log "AgentLoop PAUSED (found .agentloop-pause sentinel)"
    log "Remove .agentloop-pause and re-run to continue."
    echo "" >> "$PROGRESS_FILE"
    echo "## $(date '+%Y-%m-%d %H:%M') - PAUSED BY USER" >> "$PROGRESS_FILE"
    echo "Paused at iteration $i after $TASKS_COMPLETED tasks completed." >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"
    rm -f ".claude/agentloop-iteration.md"
    exit 0
  fi

  # ── Generate per-iteration prompt ───────────────────────────────────────
  PROMPT_FILE=$(generate_iteration_prompt "$i")

  # ── Run Claude instance ─────────────────────────────────────────────────
  log "Spawning Claude instance..."
  OUTPUT=$(claude --dangerously-skip-permissions --print < "$PROMPT_FILE" 2>&1 | tee -a "$ITER_LOG" | tee /dev/stderr) || true

  # Append iteration summary to run log
  {
    echo "--- Iteration $i output ($(wc -l < "$ITER_LOG" | tr -d ' ') lines) → $ITER_LOG ---"
    echo ""
  } >> "$RUN_LOG"

  # ── Check for ALL TASKS COMPLETE ────────────────────────────────────────
  if echo "$OUTPUT" | grep -q "<promise>ALL_TASKS_COMPLETE</promise>"; then
    TASKS_COMPLETED=$((TASKS_COMPLETED + 1))
    log ""
    log "╔═══════════════════════════════════════════════════════════════╗"
    log "║  ALL TASKS COMPLETE!                                         ║"
    log "║  Finished at iteration $i                                    ║"
    log "║  Total tasks completed: $TASKS_COMPLETED                     ║"
    log "╚═══════════════════════════════════════════════════════════════╝"
    echo "" >> "$PROGRESS_FILE"
    echo "## $(date '+%Y-%m-%d %H:%M') - ALL TASKS COMPLETE" >> "$PROGRESS_FILE"
    echo "Finished at iteration $i. Total tasks completed: $TASKS_COMPLETED" >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"
    rm -f ".claude/agentloop-iteration.md"
    exit 0
  fi

  # ── Check for rate limiting ─────────────────────────────────────────────
  if echo "$OUTPUT" | grep -qiE "RATE_LIMIT_DETECTED|rate.limit|429|too.many.requests|overloaded_error"; then
    if [[ "$PAUSE_ON_RATE_LIMIT" == "true" ]]; then
      log ""
      log "Rate limit detected. Pausing for ${RATE_LIMIT_PAUSE}s ($(( RATE_LIMIT_PAUSE / 60 )) minutes)..."
      echo "" >> "$PROGRESS_FILE"
      echo "## $(date '+%Y-%m-%d %H:%M') - RATE LIMIT PAUSE" >> "$PROGRESS_FILE"
      echo "Paused at iteration $i for ${RATE_LIMIT_PAUSE}s." >> "$PROGRESS_FILE"
      echo "---" >> "$PROGRESS_FILE"
      sleep "$RATE_LIMIT_PAUSE"
      # Don't count rate limit as failure
      continue
    fi
  fi

  # ── Check for successful commit (indicates task completion) ─────────────
  if echo "$OUTPUT" | grep -qE "feat:|fix:|chore:|refactor:|test:|docs:"; then
    CONSECUTIVE_FAILURES=0
    TASKS_COMPLETED=$((TASKS_COMPLETED + 1))
    log "Task completed successfully. ($TASKS_COMPLETED total)"
  else
    CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
    log "Warning: No commit detected in iteration $i (failure $CONSECUTIVE_FAILURES of $MAX_CONSECUTIVE_FAILURES)"

    if [[ $CONSECUTIVE_FAILURES -ge $MAX_CONSECUTIVE_FAILURES ]]; then
      log ""
      log "╔═══════════════════════════════════════════════════════════════╗"
      log "║  STOPPED: $MAX_CONSECUTIVE_FAILURES consecutive failures     ║"
      log "║  Tasks completed before stopping: $TASKS_COMPLETED           ║"
      log "╚═══════════════════════════════════════════════════════════════╝"
      echo "" >> "$PROGRESS_FILE"
      echo "## $(date '+%Y-%m-%d %H:%M') - STOPPED: Consecutive failures" >> "$PROGRESS_FILE"
      echo "Stopped after $CONSECUTIVE_FAILURES consecutive failures at iteration $i." >> "$PROGRESS_FILE"
      echo "Tasks completed: $TASKS_COMPLETED" >> "$PROGRESS_FILE"
      echo "---" >> "$PROGRESS_FILE"
      rm -f ".claude/agentloop-iteration.md"
      exit 1
    fi
  fi

  log "Iteration $i complete. Sleeping 2s..."
  sleep 2
done

log ""
log "AgentLoop reached max iterations ($MAX_ITERATIONS)."
log "Tasks completed: $TASKS_COMPLETED"
log "Check $PROGRESS_FILE for full status."
log "Full logs: $LOG_DIR/"
echo "" >> "$PROGRESS_FILE"
echo "## $(date '+%Y-%m-%d %H:%M') - MAX ITERATIONS REACHED" >> "$PROGRESS_FILE"
echo "Reached $MAX_ITERATIONS iterations. Tasks completed: $TASKS_COMPLETED" >> "$PROGRESS_FILE"
echo "---" >> "$PROGRESS_FILE"
rm -f ".claude/agentloop-iteration.md"
exit 1

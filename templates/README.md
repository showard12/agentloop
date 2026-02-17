# AgentLoop Templates

These templates are used by the `/onboard-agentloop` command during project setup.

## Files

- **agentloop.config.json** — Config template with all fields and sensible defaults
- **agentloop-progress.txt** — Progress file template with placeholder variables

## Hookify Rules

The `hooks/` directory contains hookify rule templates that get copied to a project's `.claude/` directory:

| Rule | Event | Action | Purpose |
|------|-------|--------|---------|
| ticket-lifecycle | stop | block | Must update VK task before stopping |
| require-tests | stop | block | Must run tests before stopping |
| require-ac-verify | stop | block | Must verify acceptance criteria |
| progress-update | stop | warn | Reminder to update progress file |
| commit-discipline | bash | warn | Commit message format reminder |
| prevent-destructive | bash | block | Block force-push, rm -rf, etc. |

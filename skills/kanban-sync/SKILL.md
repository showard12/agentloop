---
name: kanban-sync
description: Export VibeKanban board to repo or recover/restore it from the exported file
---

# Kanban Sync — Export & Recover

Manages a `kanban-export.json` file in the repo root that mirrors the VibeKanban board. This enables recovery if VK data is lost and keeps a version-controlled snapshot of task state.

## Determine Operation

Parse the user's request (or the ARGUMENTS) to determine which operation:

- **export** (default if no argument): Dump current VK state to `kanban-export.json`
- **recover**: Recreate VK issues from `kanban-export.json`
- **diff**: Show what changed between the file and VK

---

## Operation: Export

### Step 1: Read Config

Read `agentloop.config.json` to get `vk_project_id`.

### Step 2: Fetch All Issues

```
mcp__vibe_kanban__list_issues(project_id=..., limit=100)
```

Then fetch full details for each issue:

```
mcp__vibe_kanban__get_issue(issue_id=...)
```

Do this in parallel batches of 8-10 for efficiency.

### Step 3: Build Export Object

Structure:

```json
{
  "exported_at": "ISO timestamp",
  "project": {
    "id": "uuid",
    "name": "string",
    "organization_id": "uuid"
  },
  "summary": {
    "total": N,
    "done": N,
    "todo": N,
    "inprogress": N
  },
  "issues": [
    {
      "id": "uuid",
      "title": "string",
      "status": "To do | Done | In progress",
      "description": "string (full markdown)",
      "created_at": "ISO timestamp",
      "updated_at": "ISO timestamp"
    }
  ]
}
```

Sort issues by title (epic number, then task number) for readability.

### Step 4: Write File

Write to `kanban-export.json` in the project root (same directory as `agentloop.config.json`).

### Step 5: Report

```
Kanban exported to kanban-export.json
  Total: N issues (N done, N todo, N in progress)
  File size: N KB
```

---

## Operation: Recover

Use this when VK issues are missing or the project needs to be rebuilt.

### Step 1: Read Export File

Read `kanban-export.json`. If missing:
```
FAIL: kanban-export.json not found. Run /kanban-sync export first.
```

### Step 2: Read Config

Read `agentloop.config.json` for the `vk_project_id`.

### Step 3: Fetch Current VK State

```
mcp__vibe_kanban__list_issues(project_id=..., limit=100)
```

### Step 4: Compute Delta

Compare export file issues with current VK issues by title (NOT by ID, since IDs change on recreation).

Categorize:
- **Missing from VK**: Issues in export but not in VK (need creation)
- **Status mismatch**: Issues in both but with different status (need update)
- **Extra in VK**: Issues in VK but not in export (leave alone, warn)

### Step 5: Confirm with User

Print the delta and ask for confirmation:

```
Kanban Recovery Plan:
  Create: N issues
  Update status: N issues
  Already synced: N issues
  Extra in VK (will keep): N issues

Proceed? (Issues will be created/updated in VK)
```

### Step 6: Execute Recovery

For missing issues, create them:
```
mcp__vibe_kanban__create_issue(
  project_id=...,
  title=issue.title,
  description=issue.description
)
```

For status mismatches, update them:
```
mcp__vibe_kanban__update_issue(
  issue_id=...,
  status=issue.status
)
```

### Step 7: Update Config

If the project_id changed (new project), update `agentloop.config.json`.

### Step 8: Update Export File

Re-export to capture the new issue IDs:
```
Run the Export operation to update kanban-export.json with new IDs.
```

### Step 9: Report

```
Kanban recovered:
  Created: N issues
  Updated: N issues
  Skipped: N issues
  New export written with updated IDs
```

---

## Operation: Diff

### Step 1: Read Both Sources

Read `kanban-export.json` and fetch current VK state.

### Step 2: Compare

Match issues by title. Report:

```
Kanban Diff (export file vs live VK):

  Synced:          N issues (same title + status)
  Status changed:  N issues
    - [Epic 3] 3.3: ... — file: To do → VK: Done
  Missing from VK: N issues
  Extra in VK:     N issues

Export file age: N hours/days old
```

---

## Notes

- Always sort issues by title for consistent ordering
- The export file should be committed to the repo for version control
- Run export after completing tasks to keep the file current
- The AgentLoop iteration skill should call export after updating VK

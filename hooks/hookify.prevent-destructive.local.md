---
name: prevent-destructive-operations
enabled: true
event: bash
conditions:
  - field: command
    operator: regex_match
    pattern: git\s+push\s+--force|git\s+push\s+-f\s|git\s+reset\s+--hard|git\s+clean\s+-f|rm\s+-rf\s+/|drop\s+table|drop\s+database
action: block
---

**AgentLoop: Destructive operation blocked!**

The following operations are blocked in autonomous mode:
- `git push --force` / `git push -f`
- `git reset --hard`
- `git clean -f`
- `rm -rf /`
- SQL `DROP TABLE` / `DROP DATABASE`

These operations can cause irreversible damage. If you need to perform a destructive operation, the human operator must intervene manually.

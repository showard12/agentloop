---
description: Gracefully pause the AgentLoop between iterations
version: 0.1.0
---

# Pause AgentLoop

You are creating a pause sentinel to gracefully stop the AgentLoop between iterations.

## Instructions

1. Create the file `.agentloop-pause` in the project root:

```bash
touch .agentloop-pause
```

2. Inform the user:

```
AgentLoop pause sentinel created.

The loop will stop gracefully after the current iteration completes.
The running Claude instance will finish its current task before stopping.

To resume: Remove .agentloop-pause and run ./agentloop.sh
To check status: /loop-status
```

3. If `.agentloop-pause` already exists:
```
AgentLoop is already paused (or pause is pending).
The loop will stop after the current iteration.

To resume: rm .agentloop-pause && ./agentloop.sh
```

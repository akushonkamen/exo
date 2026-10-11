---
title: Forks and snapshots
description: Branch conversation history and restore sandbox state.
---

# Forks and snapshots

::: warning Under construction
These docs are still being written, and some documented features are still being implemented. See [Planned additions](/agent-definition#planned-additions).
:::

Exo keeps conversation history in an append-only event log. You can fork
that history to try another approach, and snapshot a sandbox to preserve
the environment the agent was working in.

## Forking history

A fork creates a new thread with a copy of the source thread's history.
The original thread is unchanged, and each branch can continue independently.
You can fork at the latest event or select an earlier event:

```bash
exo thread fork support-analyst THREAD
exo thread fork support-analyst THREAD --up-to EVENT_ID
```

`--up-to` selects the history copied into the new thread. It does not undo
commands the agent already ran, roll back an external service, or restore
the sandbox's filesystem to that moment.

## Restoring the environment

Sandboxes can be snapshotted, which writes a snapshot id into the event log.
A snapshot captures sandbox state that can later be restored. What it
captures depends on the backend: filesystem snapshots preserve files,
while Firecracker also supports full VM snapshots, including memory.

Filesystem restoration requires a corresponding sandbox snapshot. The
event log records tool calls and their results, but it is not a copy of
every file those commands read or wrote.

| Operation | What changes |
|:----------|:-------------|
| Fork a thread | Creates a new branch of conversation history |
| Snapshot a sandbox | Captures sandbox state for later restoration |
| Restore a snapshot | Restores sandbox state; does not rewrite conversation history |

Snapshot and restore support varies by provider. See [Sandboxes](sandboxes).

## Why this matters for self-modifying agents

An agent that experiments on itself — editing its tools, prompts, or
harness code — needs a recovery path it cannot break. The event log stays
in the trusted exoharness, below the agent's own code. You can fork from
before a change, restore an appropriate sandbox snapshot, and retain the
record of what went wrong to learn from.

---
title: Lifecycles
description: How agents, threads, sessions, turns, and sandboxes relate over time.
---

# Lifecycles

::: warning Under construction
These docs are still being written, and some documented features are still being implemented. See [Planned additions](/agent-definition#planned-additions).
:::

Exo's components have different lifetimes and ownership rules. An agent
can exist without running, a thread can sit idle for days, and a turn can
continue after the client that started it disconnects.

```text
Agent (identity + default configuration)
 └── Thread (history + configuration + execution state)
      ├── Sessions (client interactions)
      │    └── Turns (submitted input → model/tool work → result)
      └── Sandbox (persistent working environment)
```

For what each object is, see [Data model](../reference/data-model).

## Agents and threads

Creating an agent saves its definition and allocates an identity. Nothing
needs to be running yet. Multiple threads can use the same agent with
different environments, vaults, and configuration overrides.

Creating a thread allocates its identity and durable state. Running a turn
materializes resources and prepares the sandbox as needed. Subsequent
sessions resume that thread's history and working environment.

Updating an agent changes its defaults. Saved thread overrides still take
precedence when resolving configuration. See [Configuration overrides](../agent-definition#configuration-overrides).

## Sessions and turns

A session represents a client's interaction with the agent. Each submitted
input starts a turn, which may involve many model calls and tool calls.
The turn remains associated with the session that started it; another
client can later follow its progress.

Exo durably queues submitted turns and serializes execution within a
thread. While running, the harness appends messages, tool requests, and
results, then records completion or failure. Those events remain available
after the client disconnects or the service restarts.

Disconnecting a client does not delete the thread. Whether an interrupted
turn can resume after a service restart depends on the harness's recovery
implementation. See [Harnesses](../reference/harnesses#coding-agent-harnesses).

## Sandboxes

Managed-agent sandboxes normally belong to a thread and retain filesystem
state across sessions. Stopping execution, restoring a sandbox snapshot,
and forking conversation history are separate operations.

| Operation | Conversation history | Sandbox state |
|:----------|:---------------------|:--------------|
| Disconnect a client | Preserved | Not deleted by the disconnect |
| Resume a thread | Continues the same history | Reuses its working environment |
| Fork a thread | Creates a new branch | Not automatically restored to the fork event |
| Restore a snapshot | Preserved | Restored from the snapshot |

See [Sandboxes](sandboxes) for create, start, stop, attach, and detach,
and [Forks and snapshots](time-travel) for the distinction between
conversation history and filesystem restoration.

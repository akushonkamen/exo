---
title: Data Model
description: Agents, threads, sessions, turns, events, and artifacts.
---

# Data Model

::: warning Under construction
These docs are still being written, and some documented features are still being implemented. See [Planned additions](/agent-definition#planned-additions).
:::

## Agent

A configuration object containing instructions, tools, MCP servers,
resources, and defaults for the harness and model. Threads select their
environment and vaults, and can override the agent's defaults.

## Thread, session, turn

- A **thread** contains an agent's conversation history, execution state,
  filesystem state, and configuration. It can stop and resume, and may
  accumulate millions of interactions over a very long time. The low-level
  exoharness API calls this a **conversation**.
- A **session** represents a client's interaction with an agent within a
  thread. A thread, or even a turn, can continue across multiple sessions.
- A **turn** is one user input, which may map to many LLM calls (tool
  loops, subagents) before producing a final result.

Exo durably queues submitted turns before execution. When execution starts,
`beginTurn(...)` records the user's input and returns a **turn handle**
the executor uses to append events and finish the turn. Head
tracking and write ordering stay inside the exoharness, so the executor can
start the model call as quickly as possible once execution begins.

For creating, resuming, and forking threads, see [Threads](/agent-definition#threads-sessions-and-turns).

## Event

An event is an append-only record of a change to conversation state:
executor-emitted LLM inputs and outputs (formatted as
[Lingua](https://github.com/braintrustdata/lingua) messages), system
updates like session openings, tool requests and results, and
executor-defined custom types.

The exoharness stores and orders events durably; executors *interpret* them
to construct message history and higher-level behavior. Events use UUIDv7
ids, so ordered comparison and pagination are efficient, and they're
exposed through structured APIs — `getEvents(...)`, `getEvent(...)`,
`watchEvents(...)` — as typed cursor scans, not raw SQL or payload
archaeology.

Custom event types are allowed and should be namespaced. This is how
concepts like compaction stay out of the substrate: an executor writes a
custom event pointing at a derived context view or summary. Compaction
never needs to be a first-class exoharness concept.

Note that the full event log is not the same as the prompt: the executor
decides which events (or which summary of them) to send to the model on a
given round. The log is the durable record; the prompt is a view the
executor builds from it.

## Artifact

An artifact is an opaque, immutable, versioned set of bytes the agent can
set and retrieve. Updates flow through the event log (e.g.
`CreateArtifact(path, contents)` returns a version), and you can fetch the
latest or any specific version.

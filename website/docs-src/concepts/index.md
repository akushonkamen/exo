---
title: Architecture
description: Exo's runtime layers, durable state, execution lifecycle, and trust boundaries.
---

# Architecture

::: warning Under construction
These docs are still being written, and some documented features are still being implemented. See [Planned additions](/agent-definition#planned-additions).
:::

The [agent definition](../agent-definition) walks through how to configure
and use Exo. These pages explain how the pieces work underneath:

- [Exoharness and executor](exoharness-and-executor) — separating durable
  infrastructure from the harness's semantics.
- [Data model](../reference/data-model) — threads, sessions, turns, events,
  and artifacts.
- [Harnesses](../reference/harnesses) — the execution loop and recovery
  of interrupted turns.
- [Lifecycles](lifecycles) — what runs, what persists, and what happens
  when a client disconnects.
- [Sandboxes](sandboxes) — providers, ownership, and snapshots.
- [Forks and snapshots](time-travel) — branching history and restoring
  the working environment.
- [Vaults and credentials](bindings-and-secrets) — credential selection,
  substitution, and destination policies.
- [Tools](tools) — implementations and their trust boundary.

The lower-level runtime contract lives in
[`exoharness/docs/spec.md`](https://github.com/exoharness/exo/blob/main/exoharness/docs/spec.md).

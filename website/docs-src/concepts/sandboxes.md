---
title: Sandboxes
description: Isolated execution, sandbox ownership, and snapshots.
---

# Sandboxes

::: warning Under construction
These docs are still being written, and some documented features are still being implemented. See [Planned additions](/agent-definition#planned-additions).
:::

Agents benefit from being able to write and run commands in secure
environments. The exoharness runs sandboxes with pluggable backends and
provides lifecycle operations — create, start, stop, snapshot — plus
command execution inside them.

An **environment** defines the image, provider, mounts, and network policy.
A **sandbox** is the running instance of that configuration. Managed agents
normally use a sandbox scoped to their thread, so files survive across
sessions without being shared with another thread.

## Backends

| Backend | Type | Notes |
|:--------|:-----|:------|
| `smolvm` | Local | MicroVM; the default |
| `firecracker` | Local | MicroVM; full VM snapshots, including memory |
| `docker` | Local | Container |
| `apple_container` | Local | Container on macOS |
| `local_process` | Local | Commands run on the host without isolation |
| `daytona` | Hosted | Daytona sandbox |
| `e2b` | Hosted | E2B sandbox |
| `sprites` | Hosted | Sprites sandbox |
| `vercel` | Hosted | Vercel Sandbox |
| `aws_agentcore` | Hosted | Amazon Bedrock AgentCore |

The default devbox image includes the selected harness, Python, and a
Node.js/TypeScript development environment. You can select another image
or provider through an environment. See [Environments](../agent-definition#environments)
for the configuration syntax.

Support varies by backend. Exo's credential substitution and proxy-based
network controls currently require SmolVM or Firecracker.

## Lifecycle and ownership

The exoharness owns sandbox lifecycle; the harness decides which commands
to run and when to request a snapshot. A sandbox can outlive the client
session that started it.

| Operation | Effect |
|:----------|:-------|
| Create | Provision a sandbox from an image, mounts, provider, and network policy |
| Start | Ensure it is running, optionally restoring a supported snapshot |
| Run | Execute a command inside it |
| Snapshot | Capture state and record a snapshot id in the event log |
| Stop | Stop a sandbox created by Exo |
| Attach | Register an externally created environment, currently an existing Docker container |
| Detach | Release a borrowed environment without stopping it |

Create is the default path. Attach is useful when another system has
already provisioned the environment and Exo should execute there. Attached
sandboxes are borrowed: detach them when done instead of stopping them.

The low-level API also supports agent-scoped sandboxes shared across
threads. That is a different ownership choice from the managed-agent
default of a separate sandbox per thread.

## Snapshots

Snapshotting writes a snapshot id to the event log, tying sandbox state
to conversation history. Filesystem snapshots capture files; full VM
snapshots can also preserve memory and running processes. The backend
determines which formats are available and which can be restored.

Restoring a snapshot does not erase or rewind the conversation log.
Forking a thread's history is a separate operation — see
[Forks and snapshots](time-travel).

## Credentials and host mounts

Sandbox processes can use placeholder credentials. The runtime substitutes
the real value only for requests to destinations permitted by the secret's
policy. See [Vaults and credentials](bindings-and-secrets).

Host mounts expose actual files on the runtime host. Read-only mounts
prevent writes, but still allow the agent to read their contents. A mount
containing a raw API key does not provide credential substitution's isolation.

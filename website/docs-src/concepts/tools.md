---
title: Tools
description: Tool calls, implementations, and their trust boundary.
---

# Tools

::: warning Under construction
These docs are still being written, and some documented features are still being implemented. See [Planned additions](/agent-definition#planned-additions).
:::

A **tool** is a function the model calls during an active turn. The harness
exposes its definition to the model and records the request and result in
the thread's durable history.

Tools are an executor concept. The exoharness supplies durable events,
artifacts, secrets, and sandbox processes; the harness decides which tools
the model sees and how to dispatch their calls.

## Definition and implementation

A definition describes a tool's name, purpose, and input schema. Its
implementation can be supplied by the environment, a client, or an MCP
server. These implementations have different execution locations:

| Implementation | Where it runs |
|:---------------|:--------------|
| Environment tool module | The runtime host; its handler can execute commands in the thread's sandbox |
| Client tool | The connected application, eg. a UI asking the user a question |
| MCP tool | The MCP server |

The same agent can use different implementations in different environments.
For declarations and configuration, see [Custom tools](../agent-definition#custom-tools)
and [Tool implementations](../agent-definition#tool-implementations).

## Trust model

TypeScript tool modules run as trusted code in the harness process. Loading
one is a trust decision. Commands that a handler starts inside the thread's
sandbox still use that sandbox's policy, but there is not a capability
sandbox around the tool module itself.

Sandbox network policies constrain sandbox processes. They do not constrain
arbitrary host-side code in a tool module or the client application's own
network access.

Credentials belong in vaults. Tool configuration can refer to a credential;
definitions, prompts, and results should not contain its raw value. See
[Vaults and credentials](bindings-and-secrets).

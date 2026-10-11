---
title: Adapters
description: Connect an agent to Slack, Discord, WhatsApp, Signal, or IRC.
---

# Adapters

::: info Planned
This feature is not implemented yet.
:::

Adapters let you talk to an agent from a messaging app. They submit messages to
Exo threads and send the agent's responses back to the same conversation. You can
use the same agent from chat, the terminal, or an HTTP client.

Add an adapter to the agent's frontmatter:

```yaml
adapters:
  - type: slack
    vault: support-slack
```

Then serve the agent:

```bash
exo run support-analyst.md --serve
```

Exo maintains the connection while the server is running. Each chat conversation
maps to a persistent Exo thread, so follow-ups retain its history and filesystem.
Replies are delivered automatically; the agent doesn't need a tool or special
instructions to send them.

`name` is optional and defaults to the adapter's type. Give adapters distinct
names if you connect two accounts of the same type:

```yaml
adapters:
  - type: slack
    name: support
    vault: support-slack
  - type: slack
    name: internal
    vault: internal-slack
```

## Setup

- [Slack](slack): a Slack app using Socket Mode or a public HTTP endpoint.
- [Discord](discord): a bot connected through Discord's Gateway.
- [WhatsApp](whatsapp): link an account by scanning a QR code.
- [Signal](signal): link an account using `signal-cli`.
- [IRC](irc): connect a bot to a network and channel.

Each page describes the required credentials, configuration, and how chats map
to threads. The first implementation covers text messages; media support follows
separately.

## Credentials

Bot tokens belong in a dedicated vault selected by the adapter's `vault` field.
Exo reads that vault to connect the adapter, without attaching it to agent threads.
The agent's model and other integrations still use the thread's selected vaults.
See [Vaults](../architecture/vaults) for those credentials.

WhatsApp and Signal use linked-device profiles instead of bot tokens. Exo keeps
those profiles in private adapter state on the runtime host, outside the agent's
sandbox. IRC can connect without a credential when the network permits it.

Incoming chat users do not automatically become Exo users or select their own
vaults. Adapter threads run with the deployment owner's defaults. Use separate
agent deployments when conversations need different credentials or access.

## Running the server

`exo run FILE_OR_AGENT --serve` starts that agent's adapters alongside its HTTP API.
`exo run --serve` serves the whole local provider. Keep the provider's state when
restarting so conversation mappings and linked-device profiles survive.

Removing an adapter from the definition stops its connection and preserves its
Exo threads. A connection failure is shown in server logs, and Exo reconnects.
Accepted input and pending replies are persisted, so delivery can resume after a
restart. Retries can still duplicate an external reply if the messaging provider
doesn't support idempotent sends.

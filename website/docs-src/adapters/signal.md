---
title: Signal
description: Link a Signal account to an Exo agent using signal-cli.
---

# Signal

::: info Planned
This feature is not implemented yet.
:::

The adapter uses [signal-cli](https://github.com/AsamK/signal-cli), an unofficial
Signal client, to receive and send messages through a linked device.

## Install signal-cli

Install `signal-cli` and its required runtime on the machine running the Exo
server, following its [installation instructions](https://github.com/AsamK/signal-cli#installation).
It needs to be on that server's `PATH`, outside the agent's sandbox:

```bash
signal-cli --version
```

## Link the account

Add this to your agent's frontmatter:

```yaml
adapters:
  - type: signal
    device_name: Exo
```

Run the server:

```bash
exo run support-analyst.md --serve
```

On the first connection, Exo displays a linking QR code. In Signal on your phone,
open **Settings → Linked devices**, add a device, and scan it. See Signal's
[linked-device instructions](https://support.signal.org/hc/en-us/articles/360007320551-Linked-Devices).
Send a message to the linked account from another account to try the agent.

Exo keeps the Signal profile in private adapter state. Preserve the provider's
state across restarts to retain the link. There is no bot token to import into a
vault, and the profile is not mounted into the agent's sandbox.

## Options

| Field | Default | Meaning |
| --- | --- | --- |
| `name` | `signal` | Distinguishes linked accounts on one agent. |
| `device_name` | `Exo` | Name shown in Signal's linked-device list. |
| `trigger` | `direct_messages` | Accept direct messages. `all_messages` also accepts group messages. |

Each sender or group maps to a separate Exo thread. Replies go to that same
conversation; the adapter ignores outgoing-message sync events.

## Troubleshooting

- `signal-cli` isn't found: install it on the runtime host and check the server's `PATH`.
- Link failed: request a fresh QR by restarting the adapter and scan it promptly.
- Connection stops working: check that the device is still linked and that `signal-cli` is current.

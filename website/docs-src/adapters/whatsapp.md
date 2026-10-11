---
title: WhatsApp
description: Link a WhatsApp account to an Exo agent.
---

# WhatsApp

::: info Planned
This feature is not implemented yet.
:::

The WhatsApp adapter uses [Baileys](https://github.com/WhiskeySockets/Baileys), an
unofficial WhatsApp Web client. It links to a WhatsApp account as another device;
you don't need a bot token or a public endpoint.

## Link the account

Add this to your agent's frontmatter:

```yaml
adapters:
  - type: whatsapp
```

Start the server:

```bash
exo run support-analyst.md --serve
```

On the first connection, Exo displays a QR code in the terminal. On your phone,
open WhatsApp's **Linked devices**, choose **Link a device**, and scan it. Send a
message to that account from another account to try the agent.

Exo stores the linked-device profile in private adapter state. Keep the provider's
state when restarting; you don't need to scan the QR again. The profile is not
available to the agent's sandbox.

## Options

| Field | Default | Meaning |
| --- | --- | --- |
| `name` | `whatsapp` | Distinguishes linked accounts on one agent. |
| `trigger` | `direct_messages` | Accept direct messages. `all_messages` also accepts group messages. |
| `allowed_chats` | Omitted | Accept chats matching the trigger. Supply WhatsApp chat IDs to restrict them; `[]` accepts none. |

Each chat, including each enabled group, maps to its own Exo thread. Replies go
to that chat. The bot ignores its own messages.

## Troubleshooting

- QR expired: wait for the next code and scan again.
- Account was unlinked: restart the adapter and pair it again.
- Group is ignored: use `trigger: all_messages` and check `allowed_chats`.
- Message from the linked account itself is ignored: test from a second account.

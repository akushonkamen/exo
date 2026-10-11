---
title: Discord
description: Connect a Discord bot to an Exo agent.
---

# Discord

::: info Planned
This feature is not implemented yet.
:::

The adapter uses Discord's [Gateway](https://docs.discord.com/developers/events/gateway)
connection, so the Exo server doesn't need a public endpoint.

## Create the bot

Create an application in the [Discord Developer Portal](https://discord.com/developers/applications)
and open its **Bot** settings. Generate a bot token and enable **Message Content
Intent** so the adapter can read channel messages. Install the bot in your server
with **View Channels**, **Send Messages**, **Read Message History**, and **Send
Messages in Threads** permissions. Discord's
[bot setup guide](https://docs.discord.com/developers/quick-start/getting-started)
walks through creating and installing an app.

Set `DISCORD_BOT_TOKEN` in your shell and import it:

```bash
exo vault create support-discord
exo vault secret create support-discord bot-token --token-env DISCORD_BOT_TOKEN
```

## Connect the agent

Add this to your agent's frontmatter:

```yaml
adapters:
  - type: discord
    vault: support-discord
```

Then start the server:

```bash
exo run support-analyst.md --serve
```

Mention the bot in a server channel, or send it a DM. The agent's answer is posted
back to the same conversation.

## Options

| Field | Default | Meaning |
| --- | --- | --- |
| `vault` | Required | Vault containing `bot-token`. |
| `name` | `discord` | Distinguishes multiple Discord adapters. |
| `trigger` | `mentions_only` | Accept mentions in server channels and messages in DMs. `all_messages` accepts other channel messages too. |
| `allowed_channels` | Omitted | Accept accessible server channels. Supply channel IDs to restrict them; `[]` disables server-channel input. |
| `direct_messages` | `true` | Accept DMs independently of the channel allowlist. |

Enable Developer Mode in Discord to copy a channel's ID. Quote numeric IDs in YAML:

```yaml
adapters:
  - type: discord
    vault: support-discord
    allowed_channels: ["123456789012345678"]
```

A channel maps to one Exo thread shared by its participants. Discord threads and
DMs have distinct channel IDs and map to separate Exo threads. An allowlisted parent
channel also permits its Discord threads. With `mentions_only`, mention the bot
again for each request in a server channel or Discord thread.

## Troubleshooting

- Bot doesn't connect: check the token and installation.
- Message text is missing or the Gateway rejects an intent: check Message Content Intent in the portal.
- Bot receives input but can't answer: check its send permissions in that channel or thread.
- Channel is ignored: check its ID and the adapter's allowlist.

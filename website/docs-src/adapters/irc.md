---
title: IRC
description: Connect an Exo agent to an IRC channel.
---

# IRC

::: info Planned
This feature is not implemented yet.
:::

The IRC adapter connects to a network, joins a channel, and answers messages
directed at its nick. It doesn't need a public endpoint.

## Connect the agent

Add the network, nick, and channel to your agent's frontmatter:

```yaml
adapters:
  - type: irc
    server: irc.libera.chat
    nick: supportbot
    channel: "#support-test"
```

Choose an available nick and a channel you can join. Quote the channel name so
YAML doesn't treat `#` as a comment. Start the server:

```bash
exo run support-analyst.md --serve
```

In that channel, send `supportbot: what is 1+1?`. The answer goes to the channel.
Its participants share one Exo thread, which persists across reconnections.

## Options

| Field | Default | Meaning |
| --- | --- | --- |
| `server` | Required | IRC server hostname. |
| `nick` | Required | Bot nickname. |
| `channel` | Required | Channel to join. |
| `name` | `irc` | Distinguishes multiple IRC adapters. |
| `tls` | `true` | Use a TLS connection. |
| `port` | `6697` with TLS; otherwise `6667` | Server port. |
| `trigger` | `mentions_only` | Accept nick mentions. `all_messages` accepts every channel message. |
| `vault` | Omitted | Optional vault containing a server `password`. |

For a server requiring an IRC `PASS` password, set `IRC_PASSWORD` and import it:

```bash
exo vault create support-irc
exo vault secret create support-irc password --token-env IRC_PASSWORD
```

Then add `vault: support-irc` to the adapter. This supplies a server password, not
NickServ or SASL authentication. The first implementation covers one channel per
adapter; private messages are a separate addition.

## Troubleshooting

- Nick rejected: choose a shorter, available nick.
- Can't join: check the channel's invitation, registration, and membership requirements.
- Connection rejected: check the network's TLS port and password requirements.
- Bot is quiet: address its nick, or use `trigger: all_messages`.

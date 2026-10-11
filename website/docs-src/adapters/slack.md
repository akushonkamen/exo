---
title: Slack
description: Set up a Slack app using Socket Mode or an HTTP endpoint.
---

<script setup>
import SlackSetupTabs from '../.vitepress/theme/SlackSetupTabs.vue';
</script>

# Slack

::: info Planned
This feature is not implemented yet.
:::

Choose how Slack connects to Exo:

- **Socket Mode** is the default and easiest for local setup. Exo connects outward to Slack, so you don't need a public URL or tunnel.
- **HTTP** lets Slack call a public HTTPS endpoint. Use it when you want to receive events through a webhook on your server.

Both have the same conversation and reply behavior. Pick a tab below for the
setup instructions. Slack also documents the two options:
[Socket Mode](https://docs.slack.dev/apis/events-api/using-socket-mode/) and
[HTTP](https://docs.slack.dev/apis/events-api/using-http-request-urls/).

## Setup

<SlackSetupTabs>
<template #socket>

### 1. Create the app

In [Slack's app settings](https://api.slack.com/apps), choose **Create New App**,
then **From a manifest**, and select your workspace. Use this
[manifest](https://docs.slack.dev/reference/app-manifest/):

```yaml
display_information:
  name: Support analyst
features:
  bot_user:
    display_name: Support analyst
    always_online: false
  app_home:
    home_tab_enabled: false
    messages_tab_enabled: true
    messages_tab_read_only_enabled: false
oauth_config:
  scopes:
    bot:
      - app_mentions:read
      - chat:write
      - channels:history
      - im:history
settings:
  socket_mode_enabled: true
  event_subscriptions:
    bot_events:
      - app_mention
      - message.channels
      - message.im
  interactivity:
    is_enabled: true
```

Install the app and copy its bot token (`xoxb-...`) from **OAuth & Permissions**.

Under **Basic Information → App-Level Tokens**, generate an app token (`xapp-...`)
with [`connections:write`](https://docs.slack.dev/reference/scopes/connections.write/).

### 2. Store the credentials

Set `SLACK_BOT_TOKEN` and `SLACK_APP_TOKEN` in your shell, then import them:

```bash
exo vault create support-slack
exo vault secret create support-slack bot-token --token-env SLACK_BOT_TOKEN
exo vault secret create support-slack app-token --token-env SLACK_APP_TOKEN
```

### 3. Connect the agent

Add this to the frontmatter of your agent file:

```yaml
adapters:
  - type: slack
    transport: socket
    vault: support-slack
```

Enable **Socket Mode** in the app settings, then run the server:

```bash
exo run support-analyst.md --serve
```

</template>
<template #http>

### 1. Create the app

In [Slack's app settings](https://api.slack.com/apps), choose **Create New App**,
then **From scratch**. Name the app and select your workspace.

Under **OAuth & Permissions**, add these **Bot Token Scopes**:

- `app_mentions:read`
- `chat:write`
- `channels:history`
- `im:history`

Under **App Home**, enable the **Messages Tab** and allow users to send messages
to the app. Install the app to your workspace and copy its bot token (`xoxb-...`).
Under **Basic Information → App Credentials**, copy the **Signing Secret**.

### 2. Store the credentials

Set `SLACK_BOT_TOKEN` and `SLACK_SIGNING_SECRET` in your shell, then import them:

```bash
exo vault create support-slack
exo vault secret create support-slack bot-token --token-env SLACK_BOT_TOKEN
exo vault secret create support-slack signing-secret --token-env SLACK_SIGNING_SECRET
```

### 3. Connect the agent

Add this to the frontmatter of your agent file:

```yaml
adapters:
  - type: slack
    transport: http
    vault: support-slack
```

Start the server:

```bash
exo run support-analyst.md --serve
```

### 4. Set the public URL

The server exposes a built-in Slack webhook at `/exo/adapter/slack`. Use a reverse
proxy or tunnel to make it available over HTTPS, e.g.
`https://exo.example.com/exo/adapter/slack` forwarding to
`http://127.0.0.1:4766/exo/adapter/slack`.

In Slack's app settings:

1. Disable **Socket Mode**.
2. Under **Event Subscriptions**, set **Request URL** to the public HTTPS URL. Keep Exo running while Slack verifies it.
3. Subscribe to the bot events `app_mention`, `message.channels`, and `message.im`.
4. Under **Interactivity & Shortcuts**, enable interactivity and set its **Request URL** to the same URL, so approval buttons work.

Exo handles Slack's URL-verification challenge and verifies incoming events and
interactions with the app's
[signing secret](https://docs.slack.dev/authentication/verifying-requests-from-slack/).

</template>
</SlackSetupTabs>

## Try it

Open the app's **Messages** tab in Slack and send `What is 1+1?`. For a channel,
invite the bot and mention it, e.g. `@Support analyst investigate this ticket`.
Exo delivers the answer in that Slack thread. Reply there to continue without
mentioning the bot again.

The adapter's credentials are separate from the model credential used by the
agent's threads.

`message.channels` and `channels:history` let the bot receive follow-ups in public
channel threads without another mention. Exo filters these events to conversations
the bot participates in. See Slack's
[channel event reference](https://docs.slack.dev/reference/events/message.channels/).
For private channels, also add `groups:history` and `message.groups`, reinstall the
app, and invite it to the channel.

## Options

| Field | Default | Meaning |
| --- | --- | --- |
| `vault` | Required | Vault containing `bot-token`, plus `app-token` for Socket Mode or `signing-secret` for HTTP. |
| `transport` | `socket` | `socket` for Socket Mode, or `http` for a public webhook endpoint. |
| `name` | `slack` | Distinguishes multiple Slack adapters on one agent. |
| `trigger` | `mentions_only` | Mentions, participating thread follow-ups, and DMs. `all_messages` also starts work for other channel messages. |
| `allowed_channels` | Omitted | Accept channels the bot has access to. Supply channel IDs to restrict them; `[]` disables channel input. |
| `direct_messages` | `true` | Accept DMs independently of the channel allowlist. |

For example, limit the bot to a support channel and disable DMs:

```yaml
adapters:
  - type: slack
    vault: support-slack
    allowed_channels: [C123456]
    direct_messages: false
```

Each channel thread maps to its own Exo thread. Top-level messages in a DM share
one Exo thread; an explicit Slack reply thread gets a separate one. The mapping
survives server restarts. Approvals appear as buttons in the originating conversation
and can be answered by the user who submitted the request.

The webhook path uses the adapter's name, e.g. `/exo/adapter/support` for
`name: support`. When serving the whole provider with `exo run --serve`, include
the agent as well: `/exo/agent/support-analyst/adapter/slack`.

## Troubleshooting

- Socket connection fails: check that Socket Mode is enabled and that the app token has `connections:write`.
- HTTP URL won't verify: check that Socket Mode is disabled, the Exo server is running, and the public URL forwards to its webhook path.
- HTTP requests are rejected: check the signing secret and the server clock, and make sure the proxy preserves the request body and Slack signature headers.
- Approval buttons don't work over HTTP: check the Interactivity Request URL.
- No channel response: invite the bot, mention it, and check `allowed_channels`.
- No follow-up response: check the channel event subscription and history scope; reinstall after changing scopes.
- Can't send a DM: enable the app's Messages tab and allow users to send messages to it.
- Token rejected: check that the credentials belong to the same app and that the app is installed.

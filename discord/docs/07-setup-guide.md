# 07 · Setup Guide

Step-by-step instructions for the Owner. Allow about one hour. Nothing in this guide has been run on a real Discord server yet; the scripts were tested offline only (see [09-qa-report.md](09-qa-report.md)).

## What you need to provide

| Item | Where to get it | Where it goes |
|---|---|---|
| A Discord server you own (new and empty is best) | Discord app → "+" → Create My Own | — |
| Bot token (`DISCORD_TOKEN`) | Developer Portal → your application → Bot → Reset Token | `discord/bot/.env` only |
| Application ID (`DISCORD_CLIENT_ID`) | Developer Portal → General Information | `.env` |
| Server ID (`DISCORD_GUILD_ID`) | Discord → Settings → Advanced → Developer Mode on; right-click the server icon → Copy Server ID | `.env` |
| Your user ID (`OWNER_USER_ID`) | Right-click your own name → Copy User ID | `.env` |
| A computer or server that runs 24/7 with Node.js 22.13 or newer | See "Hosting" in [05](05-bots-and-integrations.md#hosting) | — |

**Keep the token secret.** Never paste it in Discord, never commit it, never show it in a screenshot. `.env` is listed in `.gitignore`. If it ever leaks: Developer Portal → Bot → Reset Token, then update `.env`.

## Step 1 · Prepare the server

1. Create the server (or use an existing one; the setup never deletes anything).
2. **Server Settings → Enable Community.** Follow the wizard; when it asks for a rules channel and an updates channel, pick any channel for now (you can change them to #rules and #official-notices after Step 5).
3. **Server Settings → Safety Setup:** verification level *Medium*, explicit media filter *all members*, turn on *Require 2FA for moderator actions* (your own account needs 2FA for this).

## Step 2 · Create the bot

1. Go to <https://discord.com/developers/applications> → **New Application** → name it "Ro-Nation" (or similar).
2. **General Information:** copy the *Application ID*. Optional: upload `discord/assets/kagundi-emblem.png` as the app icon.
3. **Bot:** click *Reset Token* and copy the token (you only see it once). Turn **off** *Public Bot*. Turn **on** *Server Members Intent*. Leave *Message Content Intent* off.
4. **Installation** (or OAuth2 → URL Generator): scopes `bot` and `applications.commands`. For the first setup use this invite link (replace `YOUR_APPLICATION_ID`):

   ```
   https://discord.com/oauth2/authorize?client_id=YOUR_APPLICATION_ID&scope=bot%20applications.commands&permissions=275146460184
   ```

   `275146460184` = View Channels, Send Messages, Send Messages in Threads, Embed Links, Attach Files, Read Message History, Manage Roles, Manage Channels **and Administrator**. Administrator is needed only during Step 5, because Discord lets a bot hand out only permissions it holds itself. You remove it again in Step 6.
5. Open the link, choose your server, confirm.

## Step 3 · Install the bot

On the computer that will run the bot:

1. Install **Node.js 22 LTS** (22.13 or newer) from <https://nodejs.org>. Check with `node --version`.
2. Get the code: clone the repository (GitHub Desktop works) and open a terminal in `discord/bot`.
3. Install dependencies:

   ```
   npm install
   ```

4. Create the settings file: copy `.env.example` to `.env` (Windows: `copy .env.example .env`, macOS/Linux: `cp .env.example .env`) and fill in `DISCORD_TOKEN`, `DISCORD_CLIENT_ID`, `DISCORD_GUILD_ID` and `OWNER_USER_ID`. The other settings can stay as they are.
5. Run the tests to check the installation (no Discord connection needed):

   ```
   npm test
   ```

   Expected: `# pass 67` and `# fail 0`.

## Step 4 · Look at the plan (dry run)

```
npm run setup-server
```

This connects to Discord, compares your server with the blueprint and lists what it *would* create or change. Nothing is changed. The full plan is also saved to `data/setup-plan-<time>.txt`. Read the warnings: it tells you if Community is off or the bot lacks Administrator.

## Step 5 · Build the server

First, in **Server Settings → Roles**, drag the bot's role (named like your application) to the **very top** of the list. A bot can only create, edit and order roles below its own role.

Then, on a new server:

```
npm run setup-server -- --apply --sync-existing
```

On a server that already has channels you want to keep unchanged, leave out `--sync-existing`: existing roles and channels with the same names are then only reported, not changed.

The script creates 40 roles, 16 categories and 86 channels (77 text, announcement or forum channels and 9 voice channels) with their permissions, in the right order. It never deletes anything; roles and channels that are not in the blueprint are listed at the end so you can decide yourself. The IDs are saved to `data/guild-ids.json`. Running it again is safe: the second run should report everything as "ok".

## Step 6 · Lock the bot down (important)

1. **Server Settings → Roles.** Drag the bot's role (named like your application) **down** until it sits directly **below "Economic Administrator"** and above "Leader of the Revolution".
2. Click the bot's role → Permissions → turn **off Administrator** and **Manage Channels**. Keep on: View Channels, Send Messages, Send Messages in Threads, Embed Links, Attach Files, Read Message History, Manage Roles. (The bot keeps Manage Channels inside the TICKETS category through that category's own permissions.)
3. Give yourself the **Owner** role (the bot cannot, because Owner is above it).
4. Give your staff their roles by hand: Administrator (1–3 trusted people), Moderator, Support Team, Developer, Economic Administrator.

Run `npm run setup-server` (dry run) once more. It should report every role and channel as "ok" and no warnings.

**Running the setup again later** (for example after the blueprint was changed in an update): give the bot role Administrator again and drag it back to the top of the role list for the run, then repeat this step.

## Step 7 · Register the slash commands

```
npm run deploy-commands
```

Registers the 21 commands on your server (they appear within seconds). `npm run deploy-commands -- --dry-run` only lists them.

## Step 8 · Start the bot

```
npm start
```

The bot logs "Logged in as …" and how many roles and channels it found, and creates `data/economy.db`. **The first start is economic day 1.** Keep it running: on a VPS use a process manager, for example

```
npm install -g pm2
pm2 start npm --name ro-nation -- start
pm2 save
pm2 startup
```

If the bot stops with "Used disallowed intents", Server Members Intent is still off (Step 2.3).

## Step 9 · Post the messages and buttons

```
npm run post-messages
npm run post-messages -- --apply
```

The first command shows what will be posted, the second posts all welcome, rules, guide and info texts and the button panels (verification, Civilian, tickets). Running it again later edits the existing messages instead of posting new ones. `/panel` can re-post a single panel.

## Step 10 · Finish in Discord

- **Community settings:** set the rules channel to #rules and the community updates channel to #official-notices.
- **AutoMod** (Server Settings → AutoMod): turn on *Block Mention Spam* (limit 5), *Block Commonly Flagged Words*, a custom keyword rule for slurs and invite links (`discord.gg/*`, `discord.com/invite/*`) in public channels. Send alerts to #moderation-log. Exempt Moderator and Administrator.
- **Server icon:** upload `discord/assets/kagundi-emblem.png` (or the flag).
- **Lore:** pin the welcome message in #welcome. If you want, pin the Kagundi encyclopedia (PDF or link) in #kagundi-lore.
- **#government-information:** post the office-holder list from [04-messages.md](04-messages.md#templates-for-office-holders) (as the Leader's account or ask an Administrator, since the bot has no access there).
- **Onboarding** (optional): Server Settings → Onboarding can show #welcome, #rules and #verify as default channels. Do not let Onboarding hand out the Verified Member role; the verify button does that.
- **Default notifications:** Only @mentions.

## Step 11 · Test it yourself

Use a second Discord account (an alt) to check:

1. Before verifying, it sees only START HERE and cannot write.
2. The verify button unlocks the server (alt accounts younger than 7 days get the "ask a moderator" message; use `/mod verify` on them).
3. `/bank balance` shows 2,500 KGD (if the alt is older than 14 days) only to the alt.
4. Opening a support ticket creates a private channel only the alt, the Support Team and Administrators can see.
5. After the next midnight (Europe/Berlin) the first report appears in #national-economic-report.

## Troubleshooting

| What you see | What to do |
|---|---|
| `npm run post-messages` prints nothing at all | You have the old version from before 26 October 2026 (Windows bug). Pull the latest code and run it again. |
| `Posting failed: … could not be posted` with "Missing Access" | The bot cannot see that channel. Check the bot role permissions (Step 6) and run `npm run setup-server` (dry run) to find channels whose permissions differ. |
| `channel not found on the server` | Run `npm run setup-server -- --apply` first, then post again. |
| `Login failed: enable "Server Members Intent"` | Developer Portal → Bot → Privileged Gateway Intents → Server Members Intent on, save, start again. |
| `Node.js … is too old` or `No such built-in module: node:sqlite` | Install the current Node.js LTS from nodejs.org, then `npm install` again. |
| `cannot start a transaction within a transaction` | Old version of the code on Node.js 22.13–22.15. Pull the latest code. |
| `Missing settings in .env` | The `.env` file is missing or not in `discord/bot/`. On Windows make sure it is called `.env` and not `.env.txt`. |
| The bot is offline in Discord | The bot only runs while the terminal with `npm start` is open. Closing the window stops it. For 24/7 use a server or pm2 (Step 8). |
| Slash commands say "The application did not respond" | The bot is not running, or it crashed: look at the terminal where you started it. |

When asking for help, copy the last 20 lines of the terminal output (never the token).

## Everyday operation

| Task | How |
|---|---|
| Update the bot | Stop it, pull the new code, `npm install`, `npm test`, `npm run deploy-commands` (if commands changed), start it |
| Change a text | Edit the file in `discord/messages/`, run `npm run post-messages -- --apply` |
| Check the daily processing | `/econ-admin tick-status` |
| Missed tick after a crash | Start the bot; it catches up automatically. `/econ-admin tick-run` forces it |
| Backups | Automatic after every day (`data/backups/`, 30 kept). `/econ-admin backup` for an extra one. Copy the folder elsewhere regularly |
| Restore a backup | Stop the bot, copy the backup file over `data/economy.db`, start the bot. Days after the backup are processed again from the stored data; player actions after the backup are lost |
| Pause the economy | `/econ-admin maintenance` (Owner) |
| Department leaders | Give them their Command role; they use `/roster add` for their members |

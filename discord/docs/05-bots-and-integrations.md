# 05 · Bots and Integrations

## Summary

Ro-Nation needs **one custom bot**, the *Ro-Nation Economy Bot* in [`discord/bot/`](../bot/). It runs the economic simulation and the daily National Economic Report, and it also handles verification, tickets, department rosters and member restrictions. Using one bot instead of four or five public bots keeps the number of accounts with Manage Roles small and keeps all logs in one place.

Everything else uses features Discord already has (AutoMod, Community, Onboarding, 2FA requirement). A Roblox account-linking bot is optional.

| Need | Solution | Status |
|---|---|---|
| Economy, banking, businesses, loans, AVK, property, fines | Ro-Nation Economy Bot | Code written and tested offline (see 09) |
| Daily National Economic Report at 00:00 Europe/Berlin | Ro-Nation Economy Bot | Code written and tested offline |
| Verification button, automatic New/Community Member roles | Ro-Nation Economy Bot | Code written, not yet run on Discord |
| Tickets: support, reports, appeals, applications, legal, registry | Ro-Nation Economy Bot | Code written, not yet run on Discord |
| Department rosters (`/roster`), restrictions (`/mod`) | Ro-Nation Economy Bot | Code written and tested offline |
| Spam, slurs, invite links, mention spam | Discord AutoMod | Manual setup (see 07) |
| Roblox username on Discord | Optional: Bloxlink or RoVer | Not required; see below |
| Link between the Roblox game and the economy | Ro-Nation Economy Bot: Roblox bridge (`src/bridge/`) and `/link` | Code written and tested offline; **off by default** (see end of page) |

## The Ro-Nation Economy Bot

**Stack:** Node.js 22.13 or newer, discord.js 14, SQLite through Node's built-in `node:sqlite` (no database server needed). One process, one database file (`data/economy.db`).

**Gateway intents:** `Guilds` and `GuildMembers`. *Server Members Intent* is a privileged intent and must be switched on in the Developer Portal. The bot does **not** read message content.

**Permissions in normal operation:** View Channels, Send Messages, Send Messages in Threads, Embed Links, Attach Files, Read Message History, Manage Roles. Manage Channels is granted only on the TICKETS category so the bot can create ticket channels there. The bot never needs Administrator, Kick, Ban or Manage Server. (It needs Administrator *temporarily* while the setup script creates roles and channels, because Discord only lets a bot hand out permissions it holds itself. The setup guide removes it again afterwards.)

**Role position:** the bot's role sits directly below *Economic Administrator*. It can therefore assign every government, service, civilian and community role, but no staff role.

### Code layout

| Folder | Content |
|---|---|
| `src/economy/` | The simulation: ledger, citizens, businesses, employment, market, credit, AVK, property, fines, invoices, treasury, policy, events, daily tick, report. No Discord code. |
| `src/db/` | Database schema, migrations and backup helper |
| `src/bridge/` | Roblox bridge (off by default): HTTP interface for Roblox game servers, exactly-once operation records |
| `src/discord/` | Slash commands, buttons and tickets, bot-level permission checks, ID lookup |
| `src/blueprint/` | Single source of truth for roles, channels, permission overwrites and ticket types |
| `src/setup/` | Compares the blueprint with the live server and plans changes; reads the message files; builds the generated docs |
| `scripts/` | `setup-server`, `deploy-commands`, `post-messages`, `simulate`, `bridge-staging`, `generate-docs` |
| `test/` | 89 automated tests |

### Slash commands

22 commands. The full list with every option is in [appendix-command-reference.md](appendix-command-reference.md).

| Command | Who | What |
|---|---|---|
| `/economy` | Verified Members | Economic overview, commodity prices with duties and tariffs, earlier reports, public finances |
| `/bank` | Verified Members | Balance, pay, deposit and withdraw cash, statement, credit score |
| `/work`, `/jobs` | Verified Members | One paid shift per economic day; job board, applications, resignations |
| `/business` | Owners and managers | Register, business account, staff and job postings, stock, imports and exports, closure |
| `/invoice` | Verified Members | Create, pay, cancel invoices between citizens, businesses and the state |
| `/loan`, `/card` | Verified Members | Credit checks, loans (35% debt-to-income limit), credit cards |
| `/insurance` | Verified Members | AVK products, quotes, policies, claims |
| `/property` | Verified Members | Rent, buy, sell, list property; state property for authorised officials |
| `/fine` | Police, Gendarmerie, Judges (issue); everyone (pay) | Fines with appeal path |
| `/treasury`, `/policy` | Secretary for Economy and Education, Secretary-General, Leader | Public spending (two-person approval above 25,000 KGD), budget, wages, taxes, tariffs |
| `/registry` | Secretary for Economy, Government Officials, Economic Administrators | Approve, reject, suspend, reinstate businesses |
| `/credit-office` | Secretary for Economy, Economic Administrators | Loan applications above 5,000 KGD |
| `/avk` | AVK Officers | Decide insurance claims |
| `/central-bank` | Everyone (status), Owner (financing) | Policy rate, money stock; emergency treasury financing |
| `/econ-admin` | Economic Administrators (Owner for large corrections and maintenance) | Inspect, correct, freeze, events, tick status and recovery, backups, audit log, remove an account link |
| `/link` | Verified Members | Link the Discord account to the Roblox account with the code from the game; status; remove (24-hour delay) or keep |
| `/roster` | Department leaders, Administrators | Assign and remove department roles |
| `/panel` | Administrators | Post button panels again |
| `/mod` | Moderators, Administrators | Verify by hand, restrict, unrestrict |

Private information (balances, statements, credit scores, loans, policies, fines, inspections) is only ever shown in replies that only the user can see. Public channels get anonymous totals only.

### Buttons

- **#verify:** "I accept the rules" gives Verified Member and New Member. Accounts younger than `MIN_ACCOUNT_AGE_DAYS` (default 7) are asked to open a ticket; a moderator can then use `/mod verify`.
- **#start-here:** add or remove the Civilian role.
- **Ticket panels** in #support, #player-reports, #appeals, #faction-applications, #business-registration, #legal-information. Each ticket is a private channel in the TICKETS category; at most 3 open tickets per member; close → reopen or delete (Administrators); a text transcript goes to #ticket-transcripts before deletion.

### Automatic jobs

The scheduler runs every 30 seconds:

1. **Daily tick:** every economic day that has ended (00:00 Europe/Berlin) and is not processed yet is processed once, oldest first, inside a single database transaction. A database backup (`data/backups/economy-day-NNNNN.db`, last 30 kept) is made after each successful run. Failures are retried after 1, 2, 4 … up to 30 minutes and reported in #bot-alerts.
2. **Report publishing:** the stored report is posted to #national-economic-report and the price board to #commodity-markets. Failed posts are retried (up to 10 times). After downtime only the newest report is posted; older ones stay readable with `/economy history`.
3. **Audit mirror:** sensitive actions are copied to #economy-audit-log.
4. **Member graduation** (every 10 minutes): New Member → Community Member after 7 days.

### Logs and alerts

| Channel | What appears there | Who can read it |
|---|---|---|
| #economy-audit-log | Every sensitive economic or administrative action: who, what, amount, old and new value, reason | Administrators, Economic Administrators |
| #bot-alerts | Failed or late ticks, publishing errors, catch-up notices | Developers, Administrators, Economic Administrators |
| #moderation-log | `/mod` actions and AutoMod alerts | Administrators, Moderators |
| #ticket-transcripts | Transcripts of deleted tickets | Administrators |

The bot's console output does not contain tokens or private balances.

## Discord features to switch on (no bot needed)

- **Community** (Server Settings → Enable Community): needed for announcement and forum channels. Turn it on *before* running the setup script, otherwise those channels are created as normal text channels and the script warns you.
- **AutoMod:** block common slurs and profanity, block invite links and suspicious links in public channels, block mention spam (5+ mentions), send alerts to #moderation-log. Exempt Moderator and Administrator.
- **Verification level:** Medium (verified e-mail and Discord account older than 5 minutes).
- **Explicit media filter:** scan media from all members.
- **Require 2FA for moderation:** on (Server Settings → Safety Setup). Everyone with Moderator, Administrator or Owner needs two-factor authentication.
- **Default notifications:** "Only @mentions".

## Optional: Roblox account linking

Not required for anything in this setup. If you want Roblox usernames verified, add **one** linking bot (for example Bloxlink or RoVer). Rules if you do:

- Give it only Manage Roles and Manage Nicknames, never Administrator.
- Put its role below the Ro-Nation bot role and let it manage only its own "Roblox Verified" role. Do not let it assign faction roles; that stays with `/roster`.
- Keep the Ro-Nation verification button as the gate for server access.

## Roblox bridge: game ↔ economy link

The bot stays the only economy. The Roblox game reads and changes it only through the **Roblox bridge**, a small HTTP interface inside the bot process (`src/bridge/`, Node's built-in `http`, no extra package). Full design and rules: [`docs/game/05-economy-integration.md`](../../docs/game/05-economy-integration.md).

- **Off by default.** It only starts with `BRIDGE_ENABLED=true` and a `BRIDGE_API_KEY` of at least 32 characters in `.env`. Without them the bot behaves exactly as before.
- **Who may call it:** only Roblox game servers, with the API key (`Authorization: Bearer <key>` or `X-Api-Key`). Roblox clients never see the address or the key. The key lives in `.env` and in the experience's Secrets, never in a script, chat or Git.
- **Listens on** `127.0.0.1:8787` by default. To reach it from Roblox's servers it needs a public HTTPS address (reverse proxy or tunnel) on the 24/7 host.
- **Linking:** the game asks for a single-use code (8 characters, 10 minutes); the member confirms it with `/link confirm`. One Discord account ↔ one Roblox account. `/link remove` takes effect after 24 hours; staff can remove a link at once with `/econ-admin link-remove` (audited).
- **Exactly once:** every write carries an operation ID; repeats get the stored answer. Money movements also use the ledger key `bridge:<operationId>`.
- **Never from Roblox:** starting grants, citizen records, daily processing, approvals.
- **Maintenance mode** blocks bridge writes (answer 503); reads keep working.
- **Staging:** `npm run bridge-staging` runs a separate test bridge on this computer (`localhost:8788`, own database `data/staging.db`, own key in `data/bridge-staging.key`, no Discord login) for Roblox Studio tests. Only staging allows the small test cash transfer (`BRIDGE_TEST_OPERATIONS`, keep it `false` on the live bot).

Endpoints (API version 1): `GET /v1/health`, `POST /v1/links/start`, `GET /v1/players/{robloxUserId}/summary`, `GET /v1/players/{robloxUserId}/transactions`, `POST /v1/operations/test-cash-transfer` (staging only), `POST /v1/operations/{operationId}/resolve`.

## Hosting

The bot must run 24/7 so the daily tick happens at midnight. Requirements: Node.js 22.13+, about 200 MB RAM, and a disk that keeps `data/` between restarts.

| Option | Good for | Watch out for |
|---|---|---|
| Small Linux VPS (any provider) | Recommended. Always on, a few euros per month | You run `npm` and a process manager (pm2 or systemd) yourself |
| Raspberry Pi or an always-on home PC | Free if you already have one | Power cuts and internet outages delay ticks (the bot catches up) |
| "Free" bot hosts that sleep or wipe the disk | Not recommended | Lost database = lost economy; sleeping hosts miss midnight |

For pm2 the bot ships a settings file, `bot/ecosystem.config.cjs` (`pm2 start ecosystem.config.cjs`, details in [07](07-setup-guide.md#step-8--start-the-bot)). It starts Node directly, which also works on Windows.

If the bot is offline at midnight, nothing is lost: when it starts again it processes the missed days in order (late days collect obligations but skip penalties) and posts the newest report.

**Backups:** daily automatic backups are kept on the same machine. Copy `data/backups/` to a second place now and then (for example once a week to your PC). `/econ-admin backup` makes an extra backup on demand.

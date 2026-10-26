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
| Link between the Roblox game and the economy | Not built | Future work (see end of page) |

## The Ro-Nation Economy Bot

**Stack:** Node.js 22.13 or newer, discord.js 14, SQLite through Node's built-in `node:sqlite` (no database server needed). One process, one database file (`data/economy.db`).

**Gateway intents:** `Guilds` and `GuildMembers`. *Server Members Intent* is a privileged intent and must be switched on in the Developer Portal. The bot does **not** read message content.

**Permissions in normal operation:** View Channels, Send Messages, Send Messages in Threads, Embed Links, Attach Files, Read Message History, Manage Roles. Manage Channels is granted only on the TICKETS category so the bot can create ticket channels there. The bot never needs Administrator, Kick, Ban or Manage Server. (It needs Administrator *temporarily* while the setup script creates roles and channels, because Discord only lets a bot hand out permissions it holds itself. The setup guide removes it again afterwards.)

**Role position:** the bot's role sits directly below *Economic Administrator*. It can therefore assign every government, service, civilian and community role, but no staff role.

### Code layout

| Folder | Content |
|---|---|
| `src/economy/` | The simulation: ledger, citizens, businesses, employment, market, credit, AVK, property, fines, invoices, treasury, policy, events, daily tick, report. No Discord code. |
| `src/db/` | Database schema and backup helper |
| `src/discord/` | Slash commands, buttons and tickets, bot-level permission checks, ID lookup |
| `src/blueprint/` | Single source of truth for roles, channels, permission overwrites and ticket types |
| `src/setup/` | Compares the blueprint with the live server and plans changes; reads the message files; builds the generated docs |
| `scripts/` | `setup-server`, `deploy-commands`, `post-messages`, `simulate`, `generate-docs` |
| `test/` | 67 automated tests |

### Slash commands

21 commands. The full list with every option is in [appendix-command-reference.md](appendix-command-reference.md).

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
| `/econ-admin` | Economic Administrators (Owner for large corrections and maintenance) | Inspect, correct, freeze, events, tick status and recovery, backups, audit log |
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

## Not built yet: game ↔ economy link

The economy runs in Discord only. Paychecks, purchases and fines are not yet connected to the Roblox game. Connecting them later would need a small authenticated web endpoint next to the bot and Roblox `HttpService` calls from the game server. This is listed as future work in [10-summary.md](10-summary.md).

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

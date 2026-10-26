# 05 · Economy Integration: System Boundaries and Bridge Design

Status: Milestone 0 audit, 2026-10-26. Based on Justin's architecture update of 2026-10-26 and on the bot source code at default-branch commit `b8e905e` (after PRs #2, #3 and #5). Everything under "Verified" was read in the code or run in this session. Everything under "Design" is a proposal that Milestone 1 implements and tests; nothing in it exists yet.

## 1. Ground rule

There is **one** Kagundi economy: the Ro-Nation Economy Bot in `discord/bot`. Roblox is a physical world and a set of interfaces on top of it. Roblox never keeps a writable copy of financial state, never runs its own daily processing, and never pays the starting grant.

## 2. Verified: what the bot has today

### 2.1 No external interface

- The bot has **no HTTP or other network API**. Its only dependency is `discord.js`; no file in `src/` or `scripts/` starts a server (searched for `createServer`, `listen(`, `express`, `node:http`).
- The economic logic lives in `src/economy/` and contains no Discord code. Every function takes the economy object (`eco`) and runs inside a synchronous SQLite transaction (`node:sqlite`, one process, one database file `data/economy.db`).
- The bot's 67 automated tests passed in this session (Node 22.22, `npm test`, 67/67).

### 2.2 Rules the integration must respect

| Rule | Where it is enforced | Test today |
|---|---|---|
| **Starting grant** 2,500 KGD (policy `starting_grant`, 0–5,000), paid **once per Discord user**. It is paid by `ensureCitizen` on the member's first economy command, not by the verification button itself, and only if the member holds *Verified Member* and the Discord account is at least `GRANT_MIN_ACCOUNT_AGE_DAYS` (default 14) days old. Once-only through `citizens.starting_grant_paid` and the idempotency key `grant:<discordId>`. | `src/economy/citizens.js`, `src/discord/commands/common.js` | `ledger.test.js`: "starting grant is paid exactly once and only when eligible" |
| **One paid shift per economic day**: `clockIn` refuses a second shift and the table has `UNIQUE (econ_day, user_id)`. Wages are paid at the daily tick (`processPayroll`, key `wage:<shiftId>`); public-sector jobs come from Discord role keys. | `src/economy/employment.js`, `src/db/schema.sql` | Used in tests, but **no test checks that a second shift is refused** |
| **At most 2 businesses per owner** (pending, active or suspended count); at most 5 managers per business. | `src/economy/businesses.js` (`MAX_BUSINESSES_PER_OWNER = 2`) | **No test for the third business** |
| **Treasury spending above 25,000.00 KGD needs a second official.** `requestSpending` stores it as pending; `approveSpending` refuses the requester and payments to the approver. | `src/economy/treasury.js` (`APPROVAL_THRESHOLD = 2500000` minor units) | `economy.test.js`, `commands.test.js` |
| **Fines**: only City Police, Police Command, Gendarmerie, Gendarmerie Command and judges; max 50,000 KGD; due after 3 days; nobody can fine themselves. | `src/discord/auth.js` (`fines.issue`), `src/economy/fines.js` | `commands.test.js`, `economy.test.js` |
| **Exactly-once money movements**: `transfer` accepts an idempotency key (unique column `transactions.idempotency_key`); a repeated key returns the first transaction. `payAccount` passes a key through, but `citizenPay` (used by `/bank pay`) does **not** accept one yet. | `src/economy/ledger.js`, `src/economy/payments.js` | `ledger.test.js`: "idempotency key prevents duplicate payments" |
| **Maintenance mode** (Owner) blocks state-changing player actions; **frozen accounts** block voluntary payments. | `src/economy/admin.js`, `src/economy/ledger.js` | `commands.test.js`: "maintenance mode blocks player changes but not reading"; `ledger.test.js`: "frozen accounts block voluntary payments…" |
| **Permissions** are role keys mapped in `PERMISSIONS` (`src/discord/auth.js`); the Owner is `OWNER_USER_ID` or the Owner role. Fictional offices never grant Discord moderation rights. | `src/discord/auth.js` | `permissions.test.js` |
| **Citizens are identified by Discord user ID.** There is no Roblox ID and no link table. | `src/db/schema.sql` (`citizens.user_id`) | — |
| **Properties** have an owner (`state`, `citizen`, `business`) and an optional tenant; 16 state properties exist at launch (`GENESIS_PROPERTIES`). | `src/db/schema.sql`, `src/economy/constants.js` | `economy.test.js` |

### 2.3 Differences from the description in the architecture update

- The starting grant is paid on the first economy command after verification (for example `/bank balance`), not by pressing the verification button. The rules (once, verified, account age) are as described.
- `/business` and the inventory exist; "a maximum of two businesses" is enforced at registration, as described.
- No other differences found.

## 3. System boundaries

| Data or process | Owner | Roblox may |
|---|---|---|
| KGD balances, transactions, credit scores, loans, cards | Bot | Show read-only views; request changes through the bridge |
| Businesses, managers, employees, jobs, shifts, inventory | Bot | Show; submit shift completions and production through the bridge |
| Properties, ownership, leases | Bot | Read to decide physical access |
| AVK policies and claims | Bot | Offer access points; submit claims through the bridge (later milestone) |
| Treasury, budgets, policy, spending approvals | Bot | Show information; submit spending requests that follow the same approval rule |
| Fines | Bot | Submit fines through the bridge with the same permission rules |
| Daily processing, reports, backups, catch-up | Bot | Read reports and prices for in-game boards |
| Faction roles | Discord roles via `/roster` | Read through the bridge; never assign |
| Discord ↔ Roblox account link | Bot (new) | Start a link; read its status |
| Character appearance, settings, non-financial progression, inventory of physical items, vehicle keys, criminal and court records | Roblox DataStores | Own and save |
| Map, buildings, which building belongs to which property or business | Roblox place + config | Own; buildings carry a `PropertyId` or `BusinessId` attribute |

## 4. Design: the Economy Bridge

### 4.1 Shape

```
Roblox client ──(RemoteEvent, intent only)──▶ Roblox game server
   EconomyGateway (server-only module, validates, rate-limits, stores pending operations)
        ──HTTPS + API key──▶ reverse proxy or tunnel on the bot host
             ──▶ Bridge module inside the bot process (src/bridge/, Node's built-in http, no new package)
                  ──▶ existing src/economy functions ──▶ SQLite (data/economy.db)
```

Why inside the bot process: SQLite then has a single writer; bridge calls use the same synchronous transactions, the same permission table and the same Discord member roles as slash commands; and the daily tick, backups and audit mirror keep working unchanged. The bridge is **off by default** (`BRIDGE_ENABLED=false`), so the bot behaves exactly as today until it is switched on.

### 4.2 Authentication and trust

- Only Roblox **game servers** call the bridge. Clients never see the address or the key.
- The key is a long random API key, sent as a bearer token over HTTPS. On Roblox it lives in the experience's secrets store and is attached to the request header without ever appearing in a script; on the bot it lives in `discord/bot/.env`. *Milestone 1 verifies the current Roblox secrets API and whether a secret can be bound to the bridge's domain.*
- Separate keys for staging and production. A key can only call bridge operations, never admin functions.
- The bridge trusts the game server to say which Roblox user is acting (Roblox authenticates players), maps that Roblox user ID to the linked Discord ID, and then checks permissions with the member's **current Discord roles**, exactly like a slash command.
- Rate limits per key and per player; request size limits; every mutation and every refusal is written to the bot's audit log.

### 4.3 Account linking (design)

1. A player clicks "Link Discord" in game. The game server asks the bridge for a code for that Roblox user ID.
2. The bridge returns a single-use code (for example 8 characters, valid 10 minutes, stored only as a hash, at most 5 open attempts).
3. The player enters the code in Discord with a new command (proposed: `/link confirm code:`). Discord authenticates the Discord account; the game authenticated the Roblox account. Only when both halves match does the link become active.
4. One Discord account ↔ one Roblox account. A second link attempt for either side is refused until the first link is removed.
5. Unlinking: the player can request removal in Discord (proposed `/link remove`), which takes effect after a cooling-off period (proposed 24 hours) so a stolen session cannot instantly move an identity. Staff recovery (proposed `/econ-admin link-remove`) is audited and needs a reason.
6. Linking never creates money. If the Discord member has no citizen record yet, the Discord command opens it with the **normal Discord rules** (`ensureCitizen` with the same eligibility check as every other command), so the starting grant can still only be paid once and only under the Discord rules. Roblox logins never call `ensureCitizen` with grant eligibility.
7. Unlinked players can play non-financial roleplay; money, property access, jobs with pay and faction tools stay locked.

New commands are proposals that change the bot; they are added backward-compatibly, with tests, in a reviewed pull request.

### 4.4 Operations (minimal set for Milestone 1, each mapped to an existing function)

| Operation (proposed) | Type | Existing function used | Notes |
|---|---|---|---|
| Health and status | read | tick status, `isMaintenance` | Lets the game show "financial services unavailable" |
| Start link | write | new `account_links` / `link_codes` tables | Returns the one-time code |
| Player summary | read | `personalAccounts`, credit score, role keys | Link status, bank and cash balance, maintenance flag |
| Recent transactions | read | `accountTransactions` | Paged |
| Test transfer between two linked staging players | write | `citizenPay` with a new optional idempotency key | The "safe test transaction" for Milestone 1, staging only |

Added in later milestones, always by calling the existing function: clock in a shift (`clockIn`, Milestone 4), property access check (properties table, Milestone 4), market prices and report data (Milestone 4/7), fines (`issueFine`, Milestone 6), business and production terminals (Milestone 7), AVK claims (Milestone 7), treasury requests (`requestSpending` only, never a direct payout, Milestone 7).

### 4.5 Exactly once

- Every write carries an **operation ID** created by the Roblox server *before* the first attempt and reused on every retry.
- The bridge stores each operation (new table `bridge_operations`: ID, Roblox user, kind, payload hash, status, result). A repeated ID with the same payload returns the stored result; a repeated ID with a different payload is refused.
- Money movements additionally use the ledger's idempotency key (`bridge:<operationId>`), so even a crash between the ledger write and the operation record cannot pay twice.

### 4.6 When the bot is unreachable

- Non-financial roleplay continues. Bank terminals, job pay, purchases, property purchases and government payments show "Financial services are temporarily unavailable".
- No replacement balances, no provisional wages, no purchase or item without a confirmed success, no inventory change without confirmation, no property access from an unconfirmed new purchase, no bypassing approvals.
- Read views may show the last confirmed values with their time ("as of 14:02") for a short time, but are never used to decide anything.
- Requests use a timeout (proposed 10 s) and at most 3 retries with backoff, always with the same operation ID. Unfinished operations are saved in a Roblox DataStore and reconciled later by asking the bridge for the operation's result.

### 4.7 Daily processing

Roblox runs no daily simulation. It reads the latest report and market data for bank displays, price boards, government screens and business terminals.

## 5. Map ↔ economy links

- The 16 launch properties have names that the map must honour, for example *Gundiville Riverside Apartment*, *Gundiville Embassy Row House*, *Gundiville Market Street Retail Unit*, *Stokondo Courthouse Quarter Apartment*, *Stokondo Polyclinic Lane Apartment*, *Kagundali Freight Warehouse*, *Kagundali Ore Yard Industrial Lot*, *Oberdueshuson Tobacco Fields*, *Oberdueshuson Garrison Town Apartment*. Each gets a building or plot in the matching district, tagged with its property ID (see [02-map-plan.md](02-map-plan.md), section 10).
- Business premises are linked to a property record or a business ID by attribute, never by name matching alone.
- In-game job activities submit to the job the player actually holds (public jobs by Discord role, private jobs by business).

## 6. Staging

- Automated: bridge tests in `discord/bot/test/` start the bridge on a local port against an in-memory economy (the same way the existing tests do) and check authentication, linking, idempotency, refusals and downtime behaviour.
- Live staging: a second bot instance with its own database (`data/staging.db`), its own key and its own port on the bot host, used by Roblox Studio tests. Production data is never used for tests. *Whether Studio can reach a bridge on Justin's own PC (localhost) is checked in Milestone 1; otherwise staging runs on the 24/7 host.*

## 7. Acceptance criteria for the integration (from the architecture update)

The economy integration is complete only when all of these have been tested and recorded in the QA report:

- [ ] Discord and Roblox identities can be securely linked (single-use, time-limited, both sides).
- [ ] The same KGD balance is shown in Discord and Roblox.
- [ ] A Roblox-initiated payment is recorded exactly once, also under retries.
- [ ] Starting funds cannot be claimed twice; Roblox never pays them.
- [ ] One paid shift per day across both platforms.
- [ ] At most two owned businesses.
- [ ] Property access follows verified ownership or lease records.
- [ ] Restricted actions require valid institutional permissions.
- [ ] Government spending above 25,000 KGD cannot bypass the second approval.
- [ ] Financial actions appear in the audit log.
- [ ] Backend failure creates no money, no duplicate items and no inconsistent transactions.
- [ ] Daily processing stays with the bot.

## 8. Required bot changes (all backward-compatible, reviewed and tested before deployment)

1. New module `src/bridge/` started from `src/index.js` only when `BRIDGE_ENABLED=true`.
2. New tables through a numbered migration: `account_links`, `link_codes`, `bridge_operations`.
3. Optional `key` parameter for `citizenPay` (default `null`, so `/bank pay` behaves exactly as before).
4. New Discord commands for linking (`/link confirm`, `/link status`, `/link remove`) and a staff recovery command; added to the command reference through `npm run generate-docs`.
5. New tests: second shift refused, third business refused, plus all bridge tests.
6. `.env.example` gains `BRIDGE_ENABLED`, `BRIDGE_PORT`, `BRIDGE_API_KEY` (placeholders only).

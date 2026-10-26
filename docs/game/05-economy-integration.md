# 05 · Economy Integration: System Boundaries and Bridge Design

Status: updated in Milestone 1, 2026-10-26. Sections 1–3 are the Milestone 0 audit (bot at default-branch commit `b8e905e`). Section 4 now describes what Milestone 1 **built**: the bridge in the bot (bot pull request from branch `claude/project-thread-55jwuj-bridge`, off by default) and the game side in `src/server/Services/`. "Tested" below always says where: the bot's automated tests and a local staging run in the cloud session; **no Roblox Studio test has happened yet** (see section 6 and [testing/m1-staging-checklist.md](testing/m1-staging-checklist.md)).

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

- Only Roblox **game servers** call the bridge. Clients never see the address or the key: the client only talks to `RemoteFunction`s in `ReplicatedStorage.RoNationRemotes`, and `EconomyGateway` is a server-only module (`ServerScriptService`).
- The key is a long random API key (at least 32 characters, the bridge refuses to start with a shorter one), sent as `Authorization: Bearer <key>` (or `X-Api-Key: <key>`). The bridge compares SHA-256 hashes with `crypto.timingSafeEqual`.
- **Roblox side (verified in the Roblox documentation, not yet in Studio):** `HttpService:GetSecret("RoNationBridgeKey")` returns a `Secret` object whose text scripts cannot read; `Secret:AddPrefix("Bearer ")` builds the header value; a secret may only be used in request headers or the URL and only for the domain it is bound to. Published games keep secrets under *Creator Dashboard → experience → Secrets*; Studio uses *File → Experience Settings → Security → Local Secrets*, a JSON text box of the form `{"<name>": ["<value>", "<domain>"]}` (seen in Justin's Studio on 2026-10-26; invalid JSON gives *Failed to parse secrets: Can't parse JSON*). The name is set in `src/server/Config/BridgeConfig.luau` (`SecretName`).
- **Bot side:** the live key is `BRIDGE_API_KEY` in `discord/bot/.env`. The staging key is a separate one (`BRIDGE_STAGING_API_KEY` or the generated file `data/bridge-staging.key`); staging refuses to start with the live key.
- Separate keys for staging and production. A key can only call bridge operations, never admin functions.
- The bridge trusts the game server to say which Roblox user is acting (Roblox authenticates players), maps that Roblox user ID to the linked Discord ID, and then checks permissions with the member's **current Discord roles**, exactly like a slash command.
- Rate limits per key and per player; request size limits; every mutation and every refusal is written to the bot's audit log.

### 4.3 Account linking (built in Milestone 1)

1. A player clicks "Link Discord" in game. The game server asks the bridge for a code for that Roblox user ID.
2. The bridge returns a single-use code: 8 characters from an alphabet without look-alikes (shown as `ABCD-EFGH`), valid 10 minutes, stored only as a SHA-256 hash. At most 5 codes per Roblox account per 10 minutes, and at most 5 failed confirmations per Discord account per 10 minutes (failures are audited as `link.confirm_failed`).
3. The player enters the code in Discord with `/link confirm code:`. Discord authenticates the Discord account; the game authenticated the Roblox account. Only when both halves match does the link become active.
4. One Discord account ↔ one Roblox account. A second link attempt for either side is refused until the first link is removed.
5. Unlinking: the player requests removal with `/link remove`, which takes effect after 24 hours so a stolen session cannot instantly move an identity; `/link keep` cancels it, `/link status` shows it. Staff recovery is `/econ-admin link-remove reason: [user:] [roblox_id:]` (permission `econ.admin`, reason of at least 5 characters, audited).
6. Linking never creates money. If the Discord member has no citizen record yet, the Discord command opens it with the **normal Discord rules** (`ensureCitizen` with the same eligibility check as every other command), so the starting grant can still only be paid once and only under the Discord rules. Roblox logins never call `ensureCitizen` with grant eligibility.
7. Unlinked players can play non-financial roleplay; money, property access, jobs with pay and faction tools stay locked.

Tables (migration 2 in `discord/bot/src/db/database.js`, all `CREATE … IF NOT EXISTS`): `account_links` (one active link per Discord ID and per Roblox ID through partial unique indexes), `link_codes`, `bridge_operations`. Code: `discord/bot/src/economy/links.js`, `discord/bot/src/discord/commands/link.js`. These are new commands that change the bot; they come in a separate reviewed pull request and reach the live bot only after Justin's go.

### 4.4 Endpoints (API version 1, built in Milestone 1)

All answers are JSON with a boolean `ok`. Requests need `Content-Type: application/json` (for bodies), at most 8 KB. Limits: 600 requests per key and 60 per Roblox player per minute (answer 429 `rate_limited`). Amounts are in minor units (1 KGD = 100).

| Endpoint | Type | Existing function used | Answer |
|---|---|---|---|
| `GET /v1/health` | read | tick status, `isMaintenance` | `service`, `apiVersion`, `maintenance`, `econDay`, `lastCompletedDay`, `testOperations`, `time` |
| `POST /v1/links/start` `{robloxUserId, robloxName}` | write | new `createLinkCode` | `status: "code"` with `code`, `expiresAt`, `command`; or `status: "linked"` if already linked |
| `GET /v1/players/{robloxUserId}/summary` | read | `personalAccounts`, credit score, Discord role keys | `linked`; when linked: Discord display name, pending removal time, citizen flag, bank balance and frozen flag, cash, credit score, role keys, `econDay`, `maintenance`, `asOf` |
| `GET /v1/players/{robloxUserId}/transactions?account=bank\|cash&page=1..50` | read | `accountTransactions` | 10 items per page: `id`, `day`, `createdAt`, `direction`, `amount`, `counterparty`, `category`, `memo` |
| `POST /v1/operations/test-cash-transfer` `{operationId, robloxUserId, direction: "withdraw"\|"deposit", amount: 1..10000}` | write | `withdrawCash` / `depositCash` (new optional `key` and `memo`, default `null`) | The "safe test transaction": moves money between the player's **own** bank account and cash. **404 unless `BRIDGE_TEST_OPERATIONS=true`** (only the staging process sets it). |
| `POST /v1/operations/{operationId}/resolve` | write | `bridge_operations` | The stored answer of that operation, or marks it `voided` (410) if it never arrived, so a late copy can no longer run |

Error codes: 400 `bad_request`/`bad_json`, 401 `unauthorised`, 404 `not_found`, 405 `method_not_allowed`, 409 `operation_conflict`, 410 `voided`, 413 `too_large`, 415 `unsupported_media_type`, 422 `refused` (a rule of the economy said no; the message is safe to show to the player), 429 `rate_limited`, 503 `maintenance` (writes only), 500 `internal_error` (nothing was changed).

**Deviation from the Milestone 0 design:** the test transaction is no longer a payment between two linked players with `citizenPay`. A withdraw/deposit on one's own accounts needs only one linked account, cannot move money to anybody else and still proves the full write path (operation ID, ledger key, retries, audit). The idempotency key for `citizenPay` follows in Milestone 4, when the first real in-game payment needs it.

Added in later milestones, always by calling the existing function: clock in a shift (`clockIn`, Milestone 4), property access check (properties table, Milestone 4), market prices and report data (Milestone 4/7), fines (`issueFine`, Milestone 6), business and production terminals (Milestone 7), AVK claims (Milestone 7), treasury requests (`requestSpending` only, never a direct payout, Milestone 7).

### 4.5 Exactly once (built in Milestone 1)

- Every write carries an **operation ID** (`HttpService:GenerateGUID(false)`) created by the Roblox server *before* the first attempt and reused on every retry.
- The bridge stores each operation in `bridge_operations` (ID, kind, Roblox user, Discord ID, payload hash, state `succeeded`/`refused`/`voided`, HTTP status, result) **in the same database transaction** as the money movement. A repeated ID with the same payload returns the stored answer (`replayed: true`); a repeated ID with a different payload gets 409 `operation_conflict`. Refusals (422) are stored too, so a retry cannot turn a "no" into a "yes" later. Maintenance (503) is not stored, so the same operation may run after maintenance.
- Money movements additionally use the ledger's idempotency key (`bridge:<operationId>`).
- Code: `discord/bot/src/bridge/operations.js` and `server.js`; on Roblox `src/server/Services/EconomyGateway.luau`.

### 4.6 When the bot is unreachable

- Non-financial roleplay continues. Bank terminals, job pay, purchases, property purchases and government payments show "Financial services are temporarily unavailable".
- No replacement balances, no provisional wages, no purchase or item without a confirmed success, no inventory change without confirmation, no property access from an unconfirmed new purchase, no bypassing approvals.
- Read views may show the last confirmed values with their time ("as of 14:02") for a short time, but are never used to decide anything.
- Requests use a timeout of 10 s and at most 3 retries (after 1, 2 and 4 s), always with the same operation ID (`BridgeConfig.TimeoutSeconds`, `RetryDelays`). Before the first attempt the operation is saved in the DataStore `RoNation_PendingEconomyOps_v1`; it is removed once the bridge gave a final answer. Every 60 s the server asks the bridge (`/resolve`) about operations older than 30 s: either it gets the stored answer, or the operation is voided so it can never run later. The player is told the outcome by a notification.
- The game server checks `/v1/health` every 30 s. The account window shows "Financial services are temporarily unavailable" when the bridge cannot be reached, and "maintenance" during maintenance mode.

### 4.7 Daily processing

Roblox runs no daily simulation. It reads the latest report and market data for bank displays, price boards, government screens and business terminals.

## 5. Map ↔ economy links

- The 16 launch properties have names that the map must honour, for example *Gundiville Riverside Apartment*, *Gundiville Embassy Row House*, *Gundiville Market Street Retail Unit*, *Stokondo Courthouse Quarter Apartment*, *Stokondo Polyclinic Lane Apartment*, *Kagundali Freight Warehouse*, *Kagundali Ore Yard Industrial Lot*, *Oberdueshuson Tobacco Fields*, *Oberdueshuson Garrison Town Apartment*. Each gets a building or plot in the matching district, tagged with its property ID (see [02-map-plan.md](02-map-plan.md), section 10).
- Business premises are linked to a property record or a business ID by attribute, never by name matching alone.
- In-game job activities submit to the job the player actually holds (public jobs by Discord role, private jobs by business).

## 6. Staging

- **Automated (ran in the cloud session, 89/89 passing):** `test/bridge.test.js`, `test/links.test.js`, `test/limits.test.js` and the `/link` cases in `test/commands.test.js` start the bridge on a local port against an in-memory economy and check authentication, linking, no grant or citizen record from Roblox, exactly once under replays, stored refusals, maintenance, resolve/void, the test-operation switch, validation and paging.
- **Staging process:** `npm run bridge-staging` in `discord/bot` starts *only* the bridge (no Discord login, so it cannot clash with the live bot's token) on `127.0.0.1:8788` with its own database `data/staging.db` (it refuses the live database path), its own key and the test operation switched on. Its console simulates the Discord side: `confirm ABCD-EFGH` confirms a code for `OWNER_USER_ID` (it opens a staging citizen and pays the staging starting balance once, as Discord does for an eligible member; this only touches `data/staging.db`), `status`, `balance`, `history`, `unlink`, `quit`. A smoke run in the cloud session linked a test user, read the summary, ran one test transfer and got the same transaction back on a replay.
- **Roblox Studio → staging (not tested yet):** `BridgeConfig.BaseUrl` is `http://localhost:8788` and `StudioOnly = true`, so the game only talks to the bridge inside Studio. Open points that only Justin's Studio test can settle: whether Studio allows `http://localhost` for game scripts, whether the `Authorization` header with a `Secret` is accepted (fallback: `AuthHeader = "X-Api-Key"`), and which domain value the Local Secret needs. Steps: [testing/m1-staging-checklist.md](testing/m1-staging-checklist.md).
- **Production:** later, with a public HTTPS address on the 24/7 host and the secret in the Creator Dashboard. Production data is never used for tests.

## 7. Acceptance criteria for the integration (from the architecture update)

The economy integration is complete only when all of these have been tested and recorded in the QA report:

- [ ] Discord and Roblox identities can be securely linked (single-use, time-limited, both sides). *Bot side tested automatically; Studio test pending.*
- [ ] The same KGD balance is shown in Discord and Roblox. *Bridge returns the bot's balance; Studio test pending.*
- [ ] A Roblox-initiated payment is recorded exactly once, also under retries. *Bot side tested automatically and in the staging smoke run; Studio test pending.*
- [ ] Starting funds cannot be claimed twice; Roblox never pays them. *Bot side tested automatically.*
- [ ] One paid shift per day across both platforms. *Bot rule tested (new test); Roblox path comes in Milestone 4.*
- [ ] At most two owned businesses. *Bot rule tested (new test); Roblox path comes in Milestone 7.*
- [ ] Property access follows verified ownership or lease records.
- [ ] Restricted actions require valid institutional permissions.
- [ ] Government spending above 25,000 KGD cannot bypass the second approval.
- [ ] Financial actions appear in the audit log.
- [ ] Backend failure creates no money, no duplicate items and no inconsistent transactions.
- [ ] Daily processing stays with the bot.

## 8. Bot changes (Milestone 1, separate pull request, not deployed)

All backward-compatible; with `BRIDGE_ENABLED=false` (the default) the bot behaves as before, apart from the new `/link` command and the new staff subcommand.

1. ✓ New module `src/bridge/` (`server.js`, `operations.js`), started from `src/index.js` only when `BRIDGE_ENABLED=true` and the key is long enough; closed on shutdown.
2. ✓ Migration 2: `account_links`, `link_codes`, `bridge_operations`.
3. ✓ Optional `key` and `memo` for `withdrawCash` / `depositCash` (default `null`, so `/bank deposit` and `/bank withdraw` behave exactly as before). *Changed from the design:* `citizenPay` gets its key in Milestone 4.
4. ✓ `/link confirm`, `/link status`, `/link remove`, `/link keep` and `/econ-admin link-remove`; command reference regenerated (22 commands).
5. ✓ New tests: second shift refused (including the database constraint), third business refused, plus all bridge, link and command tests (89 in total, all passing).
6. ✓ `.env.example` gains `BRIDGE_ENABLED`, `BRIDGE_HOST`, `BRIDGE_PORT`, `BRIDGE_API_KEY`, `BRIDGE_TEST_OPERATIONS` (placeholders only).
7. ✓ `npm run bridge-staging` (section 6).
8. ✓ The audit mirror shows Roblox actors (`roblox:<id>`) as text instead of a broken Discord mention.

Deploying to the live bot is a separate step after the pull request is merged and needs Justin's go.

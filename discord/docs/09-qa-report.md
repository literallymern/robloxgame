# 09 · QA Report

**Date:** 26 October 2026 · **Environment:** Linux build container, Node.js 22.22.0, discord.js 14.27.0 · **Discord access:** none from the build environment (discord.com was not reachable and no bot token was available). The Owner's own first setup is described below.

## Summary

| Area | Result |
|---|---|
| Automated tests | **67 of 67 passed**, 0 failed (`npm test`) |
| 30-day offline simulation | **Passed**: books balanced on every day, report generated from recorded data |
| Syntax check of every source file | Passed |
| Scripts without credentials | Passed: dry runs work; missing settings give a clear message |
| Live Discord test (setup, commands, buttons, tickets, report posting) | **Not done**: no server, token or network access. Must be done by the Owner (checklist [08 · H](08-build-checklist.md#h-test-before-opening-owner-with-a-second-account)) |

The Owner built the server with `npm run setup-server` on 26 October 2026. Starting the bot and posting the messages failed on Windows; the causes are fixed in this version (see below) and still need to be confirmed on the Owner's PC.

## What was tested, and how

### 1. Books and money (`test/ledger.test.js`, 8 tests: all passed)

- Launch: books balance to zero, treasury and AVK funded
- Starting grant paid exactly once and only when eligible
- Transfers never create money and reject overdrafts
- An idempotency key prevents duplicate payments
- Cash withdrawals and deposits keep the total
- Frozen accounts block voluntary payments but not scheduled obligations
- Admin corrections are limited (10,000 KGD), audited and never make balances negative
- Money input parsing rejects bad values (zero, negative, more than two decimals, not a number)

### 2. Daily processing (`test/tick.test.js`, 6 tests: all passed)

- The economic day changes exactly at 00:00 Europe/Berlin, also across the daylight-saving changes
- A day cannot be processed before it ends, and only once
- Wages are paid exactly once even when the tick runs repeatedly
- Catch-up after downtime processes every missed day in order, marks them late, and leaves only the newest report for publishing
- A failing day is rolled back completely (no partial changes) and succeeds on retry
- Reports are built from recorded data

### 3. Economy rules (`test/economy.test.js`, 12 tests: all passed)

- Business registration: fee only on approval, no self-approval, rejection costs nothing
- Turnover tax on business income; distribution tax and state share on withdrawals
- Production turns shifts into stock; export duties are charged; export bans are enforced
- Wage limits; unpaid wages when a business has no money
- Credit bands 300–850 with 18/14/10/7/5% rates and the 35% debt-to-income rule
- AVK: waiting period, one claim per incident, no decision on own policy, payout exactly once
- Treasury: budget lines and two-person approval above 25,000 KGD
- Policy changes stay within limits and are audited
- Fines and invoices
- Economic events are bounded and never overlap with themselves
- Closing a business pays out the rest and frees employees
- A 30-day simulation keeps the books balanced

### 4. Permissions (`test/permissions.test.js`, 14 tests: all passed)

Uses an offline copy of Discord's permission calculation on the exact overwrites the setup script writes.

- @everyone has no server-wide permissions
- Only Owner, Administrator and Moderator hold dangerous permissions (ban, kick, manage roles …); the Administrator role does **not** hold Discord's Administrator flag
- Government, justice, security, public-service and civilian roles have **no** server-wide permissions
- Unverified members see only the start channels and cannot write anywhere
- Restricted members see the start channels and #appeals, read-only
- Civilians cannot see staff, government-internal, department or audit channels
- New members cannot post links or files; community members can
- Government and security roles never see staff or moderation areas
- Departments see only their own channels
- The bot can post where it needs to and holds no moderation permissions
- Staff see what they moderate
- Ticket channels are private to the member, the reviewers, Administrators and the bot
- Every role and channel key used anywhere exists
- In-game economic powers are separate from Discord staff roles

### 5. Slash commands (`test/commands.test.js`, 13 tests: all passed)

Commands were run against fake Discord interactions (no network).

- All 21 command definitions are valid for Discord (names, lengths, option order, limits)
- Economy commands require verification
- `/bank balance` opens an account with the starting grant, reply private
- `/bank pay` and `/work`
- Business registration and registry approval, including the automatic Business Owner role
- In-game powers come from in-game offices, not from Discord staff roles
- Staff economy tools are limited to Economic Administrators and audited
- Maintenance mode blocks player changes but not reading
- Treasury spending above the threshold needs a second official
- Only Police, Gendarmerie and Judges can issue fines
- `/roster`: department leaders manage only their own department
- Autocomplete never fails for users without data
- Reading other people's financial data is not possible

### 6. Server setup plan (`test/setup-plan.test.js`, 5 tests: all passed)

- On an empty server everything is created and nothing is deleted; the bot's own role is ignored
- Without `--sync-existing`, existing roles and channels are only reported
- Without Community, forum and announcement channels become text channels with a warning
- A missing Administrator permission is reported before any change; after the setup (nothing to change) the warning no longer appears
- A server built from the plan is reported as fully correct on the next run (the setup is repeatable)

### 7. Messages and panels (`test/messages.test.js`, 7 tests: all passed)

- Every message file targets a real channel and fits into Discord's 2,000-character limit after splitting
- No message pings @everyone or @here
- Every `#channel` and every `/command` mentioned in a text exists
- Channel names are turned into links when the IDs are known
- Long texts are split at paragraph boundaries
- Every button panel can be built

### 8. Documentation (`test/docs.test.js`, 1 test: passed)

- Documents 01–03 and the command reference are identical to what the generator builds from the current blueprint and command definitions, so the documentation cannot silently drift from the code.

### 9. Simulation run (`npm run simulate -- 30`)

10 simulated players, 2 businesses (gold mine, tobacco farm), 30 economic days. Result on day 30:

- Ledger check OK (sum of all balances = 0) after every day
- Report generated with all sections; numbers match the database
- CPI 103.13 (+3.13% over 30 days), exchange rate 10.055 KGD/EUR
- Treasury 1,451,979.50 KGD, daily deficit 1,585.38 KGD (public wages 3,300 KGD vs. revenue 1,714.62 KGD)
- Exports 4,660.40 KGD on day 30; one loan active and paid on schedule; one AVK policy active
- Random events started and ended within their limits

### 10. Scripts without credentials

| Command | Result |
|---|---|
| `npm run deploy-commands -- --dry-run` | Lists the 21 commands |
| `npm run post-messages` | Lists 24 message files and 8 panels with their target channels |
| `npm run setup-server` | Stops with "Missing settings in .env …" and changes nothing |
| `npm start` | Stops with "Missing settings in .env …" |
| `npm start` with a dummy token | Stops with "Login failed" (no network to Discord), database created cleanly |

## Problems found in the first real setup (26 October 2026, fixed)

The Owner ran the setup on Windows. Building the server worked; starting the bot and posting the messages did not. Causes found and fixed:

- **`npm run post-messages` did nothing on Windows.** The script compared its own file path in a way that never matched on Windows, so it exited without doing anything. The script now always runs; the shared code moved to `src/setup/messages.js`.
- **Message files with Windows line endings** (Git for Windows converts line endings by default) were not split at paragraphs. They are now normalised when read (new test).
- **Bot start on Node.js 22.13–22.15:** the database code used a Node feature that only exists from 22.16, so the first start could fail with "cannot start a transaction within a transaction". The code no longer needs it.
- **Unclear error on old Node.js versions:** every script now checks the Node.js version first and says which version is needed.
- **Posting stopped at the first failing channel:** it now continues with the other channels and lists every failure with a hint at the end.

## Problems found during development (all fixed)

- Setup: a bot can only grant permissions it holds → the setup now requires temporary Administrator, warns before any change, and the guide removes it afterwards.
- Setup: role positions were read before new roles existed → positions are re-read; only roles below the bot are reordered.
- Moderators could not swap roles without Manage Roles → added `/mod restrict` / `/mod unrestrict` (the bot does the role change and remembers the old roles).
- The bot could not post job offers into the #employment forum → the bot got access and posts forum threads.
- Business registrations were announced in a public channel → now go to #economic-administration.
- Zero values were rejected for rent, budgets and policy settings → separate input check that allows zero where it makes sense.
- Markdown tables do not render in Discord → replaced by lists in the guides.
- The guides mentioned a "credit officer" role that does not exist → now the Secretariat for Economy and Education.
- `npm test` did not find the test files on Node 22 → fixed the test command.

## Not tested / incomplete

| Item | Why | What to do |
|---|---|---|
| Running the setup on a real server | No Discord access | Owner: [07](07-setup-guide.md) Steps 4–6, then checklist [08 · H](08-build-checklist.md) |
| Real button clicks, ticket channels, transcripts, DMs | No Discord access | Owner test with a second account |
| Posting the report and price board to Discord | No Discord access | Wait for the first midnight after the start |
| Exact appearance of embeds and long messages | Not visible offline | Look once after `post-messages` and adjust texts if needed |
| Real Discord permission behaviour | Checked with an offline copy of the algorithm, not on a live server | Owner test with the persona list in [03](03-permission-matrix.md) |
| Running on Windows or macOS | Tested on Linux only | `npm test` on the hosting machine |
| Load with many players at once | Not tested; designed for 20–25 players (SQLite, one process) | Watch #bot-alerts in the first week |
| Link between the Roblox game and the economy | Not built (out of scope) | Future work, see [10](10-summary.md) |

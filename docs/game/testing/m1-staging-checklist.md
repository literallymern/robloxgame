# Milestone 1 · Studio Staging Checklist

Run by Justin in Roblox Studio on his PC, against the **staging bridge** (`npm run bridge-staging`), never against the live economy. Claude cannot run this test (no Studio access). A German step-by-step version is in the project files (`game/milestone-1/Studio-Test-Meilenstein-1.md`).

Result of the last run: **not run yet**.

## Before you start

- Both Milestone 1 pull requests (game and bot bridge) are merged, and GitHub Desktop has pulled the default branch.
- `rojo serve` was restarted after the pull (the project file changed) and the Rojo plugin is connected.
- Node.js 22.13 or newer is installed (the live bot already needs it).
- The live bot keeps running as usual; the staging bridge uses its own port (8788), database (`discord/bot/data/staging.db`) and key.

## Steps and expected results

| # | Step | Expected result | Checks |
|---|---|---|---|
| 1 | *File → Experience Settings → Security*: turn on **Allow HTTP Requests** and **Enable Studio Access to API Services**, save | Saved | Setup steps 4–5 in [03](../03-dependencies-and-setup.md) |
| 2 | Press **Play**, open *View → Output* | `[Ro-Nation:Server] Ro-Nation 0.1.0 (Milestone 1) server started (4/4 services).` and `[Ro-Nation:Client] … client started for <name> (3/3 controllers).`; an **Account** button top left | Service loader, controller loader, remotes |
| 3 | Stop (the command bar must run in edit mode; during Play it runs on the client, which cannot see ServerStorage). In *View → Command Bar* run `require(game.ServerStorage.StudioTools.CheckSetup)()` | `OK` for experience ID `10773079581`, owner Group `60169080`, HTTP requests, streaming, flag and emblem | A15, B5, D2 |
| 4 | In a terminal in `discord/bot`: `npm install` (first time only), then `npm run bridge-staging` | "Ro-Nation STAGING bridge is running", address `http://localhost:8788`, key file `data/bridge-staging.key` | Staging process |
| 5 | Copy the line in `discord/bot/data/bridge-staging.key`. In *Experience Settings → Security → Local Secrets* add a secret (form *Edit secret*): Name `RoNationBridgeKey`, Domain `localhost` (default is `*`), New value = that line. Delete leftover secrets from earlier attempts | Secret saved | A13 |
| 6 | Press **Play** | Output shows `[Ro-Nation:EconomyGateway] Economy status: available` within about 30 seconds | A11 (http://localhost), A12 (Authorization header with a Secret) |
| 7 | **Account** → the window "Kagundi Bank Account" | "Your Roblox account is not linked to Discord yet." | Summary endpoint, unlinked state |
| 8 | **Link Discord** | A code like `ABCD-EFGH`, the command `/link confirm code:ABCD-EFGH` and the expiry time | Link code endpoint |
| 9 | In the staging terminal: `confirm ABCD-EFGH` (the code from step 8) | "Linked to Roblox <name> (ID <id>). Starting balance paid once: 2,500.00 KGD." | Link confirmation (stands in for `/link confirm`) |
| 10 | In Studio: **Refresh** | "Linked to Discord: Staging Owner", Bank 2,500.00 KGD, Cash 0.00 KGD, "As of HH:mm"; the two test buttons are visible (Owner) | Same balance on both sides |
| 11 | In the terminal: `balance` | The same two numbers as in step 10 | Same balance on both sides |
| 12 | Look at the buttons | **Link Discord** is gone while the account is linked (a second link is refused by the bot; tested automatically) | One link per account |
| 13 | **Test: withdraw 1 KGD**, then **Refresh** | "Done: transaction #N."; Bank 2,499.00, Cash 1.00 | Safe test transaction |
| 14 | In the terminal: `history` | Exactly one new transaction number with a key `[bridge:…]`; it is listed under *Bank* as `-1.00 KGD` and under *Cash* as `+1.00 KGD` (one movement, two accounts) | Exactly once, ledger key |
| 15 | **Test: deposit 1 KGD**, **Refresh**, then `history` | Bank 2,500.00, Cash 0.00; exactly one more new transaction number | Exactly once |
| 16 | Stop the staging bridge (`quit`). In Studio press **Test: withdraw 1 KGD** and wait | After about 10 seconds: "The economy did not answer in time. The request is saved …"; **Refresh** shows "Financial services are temporarily unavailable"; yellow `GET /v1/health failed` lines in Output are expected | Downtime: nothing invented |
| 17 | Start the staging bridge again (`npm run bridge-staging`) and stay in Play for 2 minutes | Notification "A delayed economy request was cancelled. Nothing was changed."; Output `Settled operation …: voided` | Reconciliation, pending store |
| 18 | In the terminal: `balance` and `history` | Unchanged since step 15: no transaction from step 16 | Backend failure creates no money |
| 19 | Stop Play; `quit` in the terminal | — | — |

Optional: `unlink` in the terminal removes the staging link, so steps 7–12 can be repeated.

## If something fails

| Symptom | Likely cause | Fix |
|---|---|---|
| `Economy status: not_configured` | The Local Secret is missing or has another name | Step 5; the name must be exactly `RoNationBridgeKey` |
| `The bridge refused the API key` | The secret value is not the staging key | Copy the key file's line again, without spaces |
| `GET /v1/health failed: …` while the staging bridge runs | Studio refused `http://localhost`, the header or the secret's domain (A11–A13) | Send Claude the exact yellow line (it never contains the key). Possible fixes: domain `*` for the staging secret only; `AuthHeader = "X-Api-Key"`; an HTTPS tunnel |
| `No DataStore for pending operations` | Studio API access is off, or the place is not the published one | Step 1; open the published place |
| Test buttons missing | Not Owner/staff, or the bridge is not the staging one | Use the Owner account; staging must be running |
| CheckSetup `FIX` for flag or emblem | The ID is a decal ID | Send Claude the line |
| PowerShell: *running scripts is disabled on this system* | Windows execution policy blocks `npm.ps1` | Use `npm.cmd install` and `npm.cmd run bridge-staging` |
| The Local Secret is gone after restarting Studio | Studio keeps only about 2,500 bytes of local secrets in total (known Roblox limit) | Delete unused local secrets, then add `RoNationBridgeKey` again |

## Record

Write the date, which steps passed, and the exact text of any failure into the Milestone 1 log in [MILESTONES.md](../MILESTONES.md) (Claude does this from Justin's report). Never paste the key.

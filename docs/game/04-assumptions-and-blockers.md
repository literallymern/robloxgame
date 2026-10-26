# 04 · Assumptions, Proposals and Blockers

Status: updated in Milestone 1, 2026-10-26. Items are removed or updated as they are confirmed or solved.

## 1. Assumptions

| ID | Assumption | How it gets confirmed |
|---|---|---|
| A1 | The Studio place contains only the default Baseplate and the Rojo test scripts. | **Confirmed** by Justin (2026-10-26): nothing built yet |
| A2 | The Owner's Roblox account is user `2595858454` (LiterallyDrJustin). It gets Owner rights in game and is the statue avatar. | Stated in the master prompt; group owner is the same account |
| A3 | Normally one server with up to 25 players runs. The code must still be correct with two or more servers. | Design rule |
| A4 | North = −Z, East = +X; 1 stud ≈ 0.28 m; city distances are compressed for gameplay. | Accepted with this blueprint |
| A5 | The map shows only the East District. Other districts are not built. | Canon: all major cities are in the East District |
| A6 | The economy bot's ledger stays the only place where money exists. Roblox keeps no writable copy of any balance. | **Confirmed** by Justin (D1 and the architecture update, 2026-10-26) |
| A7 | Faction membership comes from Discord roles assigned with `/roster`. | Follows from the architecture update (Discord is the identity source); used in Milestone 6 |
| A8 | All in-game text is English; German titles and Kagundisch words are used as flavour, as in the encyclopedia. | Canon |
| A9 | The encyclopedia PDF of 26 Oct 2026 is the latest canon. Justin's city reference guide of the same date gives the visual direction and is not canon where it differs. | Justin sends a new version if it changes |
| A10 | The bot behaves as recorded in [05-economy-integration.md](05-economy-integration.md), section 2, checked against the source code on the default branch at commit `b8e905e`. | **Re-checked in Milestone 1:** the bridge branch starts from `7caabc7`, and `discord/bot` has no changes between `b8e905e` and `7caabc7`; the 67 earlier tests still pass next to the new ones |
| A11 | Roblox Studio lets game scripts call `http://localhost:8788` (the staging bridge on Justin's PC). The documentation asks for HTTPS; developer reports say Studio allows localhost. | **Confirmed 2026-10-26** in Justin's Studio test: `Economy status: available` against `http://localhost:8788` |
| A12 | Roblox accepts a `Secret` in the `Authorization` header (`Secret:AddPrefix("Bearer ")`). | **Confirmed 2026-10-26:** the bridge checks the key on every route, including `/v1/health`, and answered with status 200 |
| A13 | A Local Secret can be bound to the domain `localhost`. | **Confirmed 2026-10-26** (Studio shows a form: Name, Domain, value) |
| A14 | `GroupService:GetRolesInGroupAsync` returns `IsMember` and the roles with their `Rank` (used for staff checks; `GetRankInGroup` is deprecated). | Studio checklist: the test buttons appear for the Owner; staff ranks are tested when staff join |
| A15 | `StreamingEnabled` and `Lighting.ClockTime` can be set from `default.project.json` with `$properties`. | `CheckSetup` prints OK for streaming |

## 2. Proposed implementation choices (not canon)

These are additions needed to build the game. None of them changes an established name, date or institution. Each can be changed by Justin.

| ID | Proposal | Reason |
|---|---|---|
| P1 | Development road numbers N1–N5 and R1–R4 | The canon names no roads; numbers help building and signage |
| P2 | Two international border crossings: East and South. Neighbouring countries stay unnamed for now. | The canon requires border crossings but names no neighbours |
| P3 | An unnamed river running from the northern highlands past Gundiville to the south | Rwanda-like highlands; gives bridges and the water-treatment site. Optional |
| P4 | Statue faces **north, towards the Congress** | Justin's city reference guide describes the statue as "facing Congress". Arriving players walk up the avenue behind it and see the Congress over its shoulders |
| P5 | Statue finish: the avatar in its **original colours and clothing** on a stone pedestal; a single-material (stone or bronze) version stays an option | The reference screenshot shows that the suit, tie and beard are 2D clothing and face textures. A single-material statue would lose them and keep only blocky shapes, hair and glasses. Decided in Milestone 3 after seeing both in Studio |
| P6 | Statue scale about 6× (figure about 30 studs) on a 14-stud pedestal | Visible along the 900-stud avenue without hiding the Congress façade |
| P7 | A modest memorial to the 1917 Kagundali Strike in Kagundali | Requested in Justin's city reference guide; the canon marks the strike as founding history and a public holiday (Streiktag) |
| P8 | The Air Force uses a military apron at the cargo airport | The canon lists an Air Force but no air base |
| P9 | New players arrive at a bus terminal at the south end of the ceremonial avenue | Shows the avenue, the statue and the Congress on the first walk |
| P10 | The square in front of the Congress serves as both ceremonial and market square, with stalls along its sides | The canon lists a "main market square"; the prompt places the statue in "the main market or ceremonial square" |
| P11 | The bridge is a module inside the existing bot process (`src/bridge/`), off by default, with a staging instance first | Uses the bot's own economy services and database directly, so no second copy of any rule exists. Details in [05](05-economy-integration.md), section 4. Built as a prototype in Milestone 1 |
| P12 | Discord ↔ Roblox account link through a single-use, time-limited code shown in game and confirmed with `/link confirm` in Discord | No third-party bot needed; both sides take part; the link lives in the economy bot. Details in [05](05-economy-integration.md), section 4.3 |
| P13 | Property locations for the 16 genesis properties, incl. a "Market Street" and an "Embassy Row" in Gundiville | The bot's property names need places on the map; see [02](02-map-plan.md), section 10 |
| P14 | Staging is a bridge-only process (`npm run bridge-staging`) with its own database, key and port, and a console that stands in for `/link confirm`, instead of a second full bot instance | A second bot instance would log in with the live bot's Discord token or need a second Discord application. The bridge-only process never touches Discord or the live database. Built in Milestone 1 |
| P15 | The "safe test transaction" moves 1 KGD between the player's own bank account and cash, only on staging (`BRIDGE_TEST_OPERATIONS=true`) and only for staff in game | Needs one linked account instead of two, cannot pay anybody else, and still tests operation IDs, retries and the ledger key. Replaces the `citizenPay` test transfer of the Milestone 0 design; see [05](05-economy-integration.md), section 4.4 |

## 3. Open decisions for Justin

| ID | Question | Recommendation | Needed by |
|---|---|---|---|
| D1 | Should the economy bot stay the only place where money exists, with the game connected through a bridge? | **Decided 2026-10-26: yes**, confirmed by the architecture update. The bridge prototype is part of Milestone 1. | — |
| D2 | Publish the experience under the group "Democratic Republic of Kagundi"? | **Decided 2026-10-26: yes, the game runs under the group.** Assets are uploaded under the group too. | — |
| D3 | Statue finish (P5). The direction is settled: it faces the Congress (P4). | Original colours on a stone pedestal, confirmed after a test render in Studio | Milestone 3 |
| D4 | Approve the bot changes listed in [05](05-economy-integration.md), section 8 (bridge module off by default, three new tables, `/link` commands, optional key for `citizenPay`, new tests), delivered as a separate reviewed pull request | **Decided 2026-10-26: approved.** The bot pull request is still reviewed before merge, and deploying to the live bot needs a separate go. | — |

## 4. Blockers and limits

| ID | Blocker | Effect | Work-around |
|---|---|---|---|
| B1 | No Studio access for Claude | Claude cannot place parts, run Play tests or publish | Builder scripts + Studio checklists run by Justin |
| B2 | Roblox web APIs are blocked from Claude's environment | The avatar data cannot be read from here | Justin's screenshot serves as the visual reference; the statue builder uses Roblox's engine functions inside Studio (Milestone 3) |
| B3 | Running downloaded dev tool binaries was blocked in the cloud session | — | **Resolved in Milestone 1:** with Justin's approval (2026-10-26) StyLua and selene were built from crates.io and luau-lsp from its source code; all Milestone 1 code passes them. StyLua and selene are pinned in `rokit.toml` for Justin's PC |
| B4 | The economy bot runs only while Justin's PC is on; the bridge exists (Milestone 1 bot pull request) but is off and not deployed | No money features on live servers yet | Justin is arranging 24/7 hosting (2026-10-26). Studio tests use the staging bridge on Justin's PC. Until the bot is reachable, the game shows "temporarily unavailable" and never invents balances |
| B5 | Flag and emblem uploaded on 2026-10-26 (flag `104179974183727`, emblem `88703156887446`); not yet checked in Studio | If an ID is a decal ID instead of an image ID, scripts cannot show it | Both IDs are in `src/shared/Config/Assets.luau`. `CheckSetup` reads their asset type in Studio (Image = OK, Decal = needs the image ID); fix the IDs there if one is wrong |
| B6 | Claude cannot see the current place file | Hand-built content could be missed | Resolved for now: Justin confirmed nothing is built (A1) |

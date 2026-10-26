# 04 · Assumptions, Proposals and Blockers

Status: Milestone 0, 2026-10-26 (updated after Justin's architecture update of the same day). Items are removed or updated as they are confirmed or solved.

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
| A10 | The bot behaves as recorded in [05-economy-integration.md](05-economy-integration.md), section 2, checked against the source code on the default branch at commit `b8e905e`. | Re-checked at the start of Milestone 1 before any bot change |

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

## 3. Open decisions for Justin

| ID | Question | Recommendation | Needed by |
|---|---|---|---|
| D1 | Should the economy bot stay the only place where money exists, with the game connected through a bridge? | **Decided 2026-10-26: yes**, confirmed by the architecture update. The bridge prototype is part of Milestone 1. | — |
| D2 | Publish the experience under the group "Democratic Republic of Kagundi"? | **Decided 2026-10-26: yes, the game runs under the group.** Assets are uploaded under the group too. | — |
| D3 | Statue finish (P5). The direction is settled: it faces the Congress (P4). | Original colours on a stone pedestal, confirmed after a test render in Studio | Milestone 3 |
| D4 | Approve the bot changes listed in [05](05-economy-integration.md), section 8 (bridge module off by default, three new tables, `/link` commands, optional key for `citizenPay`, new tests), delivered as a separate reviewed pull request | Approve; nothing reaches the live bot without your go | Start of Milestone 1 |

## 4. Blockers and limits

| ID | Blocker | Effect | Work-around |
|---|---|---|---|
| B1 | No Studio access for Claude | Claude cannot place parts, run Play tests or publish | Builder scripts + Studio checklists run by Justin |
| B2 | Roblox web APIs are blocked from Claude's environment | The avatar data cannot be read from here | Justin's screenshot serves as the visual reference; the statue builder uses Roblox's engine functions inside Studio (Milestone 3) |
| B3 | Running downloaded dev tools (luau-lsp, selene, StyLua, Lune) was blocked in this session | No automated Luau checks here yet | Ask for approval in Milestone 1; Justin can run them locally through Rokit |
| B4 | The economy bot runs only while Justin's PC is on and has no HTTP bridge | No money features in game until both exist | Justin is arranging 24/7 hosting (2026-10-26); bridge prototype against a staging instance in Milestone 1; until the bot is reachable, the game shows "temporarily unavailable" and never invents balances |
| B5 | Flag and emblem uploaded on 2026-10-26 (flag `104179974183727`, emblem `88703156887446`); not yet checked in Studio | If an ID is a decal ID instead of an image ID, scripts cannot show it | Milestone 1 puts both IDs into `Config/Assets.luau` and the Studio checklist shows both images; fix the IDs there if one does not load |
| B6 | Claude cannot see the current place file | Hand-built content could be missed | Resolved for now: Justin confirmed nothing is built (A1) |

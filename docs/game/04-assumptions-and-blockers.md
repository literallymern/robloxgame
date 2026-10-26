# 04 · Assumptions, Proposals and Blockers

Status: Milestone 0, 2026-10-26. Items are removed or updated as they are confirmed or solved.

## 1. Assumptions

| ID | Assumption | How it gets confirmed |
|---|---|---|
| A1 | The Studio place contains only the default Baseplate and the Rojo test scripts. | **Confirmed** by Justin (2026-10-26): nothing built yet |
| A2 | The Owner's Roblox account is user `2595858454` (LiterallyDrJustin). It gets Owner rights in game and is the statue avatar. | Stated in the master prompt; group owner is the same account |
| A3 | Normally one server with up to 25 players runs. The code must still be correct with two or more servers. | Design rule |
| A4 | North = −Z, East = +X; 1 stud ≈ 0.28 m; city distances are compressed for gameplay. | Accepted with this blueprint |
| A5 | The map shows only the East District. Other districts are not built. | Canon: all major cities are in the East District |
| A6 | The economy bot's ledger stays the only place where money exists. | **Confirmed** by Justin (D1, 2026-10-26) |
| A7 | Faction membership comes from Discord roles assigned with `/roster`. | Follows the same model as D1; confirm in Milestone 8 |
| A8 | All in-game text is English; German titles and Kagundisch words are used as flavour, as in the encyclopedia. | Canon |
| A9 | The encyclopedia PDF of 26 Oct 2026 is the latest canon. | Justin sends a new version if it changes |

## 2. Proposed implementation choices (not canon)

These are additions needed to build the game. None of them changes an established name, date or institution. Each can be changed by Justin.

| ID | Proposal | Reason |
|---|---|---|
| P1 | Development road numbers N1–N5 and R1–R4 | The canon names no roads; numbers help building and signage |
| P2 | Two international border crossings: East and South. Neighbouring countries stay unnamed for now. | The canon requires border crossings but names no neighbours |
| P3 | An unnamed river running from the northern highlands past Gundiville to the south | Rwanda-like highlands; gives bridges and the water-treatment site. Optional |
| P4 | Statue faces **south**, down the ceremonial avenue, with its back to the Congress | Arriving players see the statue's face with the Congress behind it. Alternative: facing the Congress |
| P5 | Statue finish: the avatar in its **original colours and clothing** on a stone pedestal; a single-material (stone or bronze) version stays an option | The reference screenshot shows that the suit, tie and beard are 2D clothing and face textures. A single-material statue would lose them and keep only blocky shapes, hair and glasses. Decided in Milestone 3 after seeing both in Studio |
| P6 | Statue scale about 6× (figure about 30 studs) on a 14-stud pedestal | Visible along the 900-stud avenue without hiding the Congress façade |
| P7 | A memorial to the 1917 Kagundali Strike at the gold fields or in Kagundali | The canon marks the strike as founding history and a public holiday (Streiktag) |
| P8 | The Air Force uses a military apron at the cargo airport | The canon lists an Air Force but no air base |
| P9 | New players arrive at a bus terminal at the south end of the ceremonial avenue | Shows the avenue, the statue and the Congress on the first walk |
| P10 | The square in front of the Congress serves as both ceremonial and market square, with stalls along its sides | The canon lists a "main market square"; the prompt places the statue in "the main market or ceremonial square" |
| P11 | Pull a minimal Economy Bridge forward to before Milestone 7 (**accepted**, D1) | Milestone 7 needs real balances; the bot already implements banking, jobs, businesses, property, credit and AVK |
| P12 | Discord ↔ Roblox account link through a one-time code shown in game and confirmed with a Discord command | No third-party bot needed; keeps the link inside the economy bot |

## 3. Open decisions for Justin

| ID | Question | Recommendation | Needed by |
|---|---|---|---|
| D1 | Should the economy bot stay the only place where money exists, with the game connected through a bridge that is built before Milestone 7? | **Decided 2026-10-26: yes.** The minimum bridge comes with Milestones 6/7. | — |
| D2 | Publish the experience under the group "Democratic Republic of Kagundi"? | **Decided 2026-10-26: yes, the game runs under the group.** Assets are uploaded under the group too. | — |
| D3 | Statue direction and finish (P4, P5) | South-facing; original colours on a stone pedestal, confirmed after a test render in Studio | Milestone 3 |

## 4. Blockers and limits

| ID | Blocker | Effect | Work-around |
|---|---|---|---|
| B1 | No Studio access for Claude | Claude cannot place parts, run Play tests or publish | Builder scripts + Studio checklists run by Justin |
| B2 | Roblox web APIs are blocked from Claude's environment | The avatar data cannot be read from here | Justin's screenshot serves as the visual reference; the statue builder uses Roblox's engine functions inside Studio (Milestone 3) |
| B3 | Running downloaded dev tools (luau-lsp, selene, StyLua, Lune) was blocked in this session | No automated Luau checks here yet | Ask for approval in Milestone 1; Justin can run them locally through Rokit |
| B4 | The economy bot runs only while Justin's PC is on and has no HTTP bridge | No real money in game until both exist | Justin is arranging 24/7 hosting (2026-10-26); bridge built in Milestones 6/7; sandbox money for Studio tests until then |
| B5 | Flag and emblem are not uploaded to Roblox yet | Flags and seals cannot show in game | Justin is uploading them under the group (2026-10-26) and sends the asset IDs; builders use plain colour placeholders until then |
| B6 | Claude cannot see the current place file | Hand-built content could be missed | Resolved for now: Justin confirmed nothing is built (A1) |

# Ro-Nation Milestone Tracker

Work happens one milestone at a time. A milestone starts only after Justin writes `NEXT MILESTONE`. Status values: **Done**, **In progress**, **Waiting for approval**, **Not started**, **Blocked**.

Last update: 2026-10-26. The sequence below is the **integration-aware plan from Justin's architecture update of 2026-10-26**. It replaces the earlier 0–14 plan.

| # | Milestone | Status | Key prerequisites | Main deliverable |
|---|---|---|---|---|
| 0 | Technical and repository audit | **Done** | — | `docs/game/` (this folder), incl. bot audit and system boundaries ([05](05-economy-integration.md)) |
| 1 | Core architecture and integration prototype | **In progress:** code done and checked in the cloud; Justin's Studio staging test outstanding | Milestone 0; Studio API access and HTTP requests on (03, steps 4–5); a staging key | Roblox foundation (services, remotes, logging, permissions); bridge prototype in the bot (off by default); account linking; verified staging test: read an account and make one safe test transfer exactly once |
| 2 | Complete country map blockout | Not started | Milestone 1; Justin runs builders and saves the place | Terrain, roads, footprints of all four cities, airport, border crossings |
| 3 | Gundiville government district | Not started | Milestone 2; flag and emblem IDs (done) | General People's Congress, Hausali, Leader's residence, square, statue of Dr. Justin Wachmann |
| 4 | First playable gameplay loop | Not started | Milestones 1–3; bot reachable over HTTPS for live tests | Spawning, navigation, one working vehicle, bank interface, one civilian job, one property interaction, connected to the bot where feasible; Roblox player profiles (non-financial) |
| 5 | Secondary cities and infrastructure | Not started | Milestone 2 | Stokondo, Kagundali, Oberdueshuson, airport, customs, fuel, utilities, transport network |
| 6 | Institutional gameplay | Not started | Milestones 4–5 | Faction access from `/roster` roles, City Police, Gendarmerie, courts, military facilities, EMS, Brandwehr |
| 7 | Expanded economic interactions | Not started | Milestones 4, 6 | Business activities, production, logistics, property access, insurance, government financial interfaces, all through the bot |
| 8 | Interface and world polish | Not started | Milestones 4–7 | Player interfaces, institutional terminals, signage, interactive facilities, environment details, onboarding |
| 9 | Security, performance and quality assurance | Not started | All | QA report incl. the integration acceptance criteria ([05](05-economy-integration.md), section 7) |

Where topics of the earlier plan went: Roblox player profiles → 4; vehicles → 4 (first vehicle), 6 (service vehicles), 8 (polish); military, police, justice, EMS, Brandwehr → 6; banking, business, property, credit, AVK → 1 (bridge), 4 (first interfaces), 7 (expanded); UI → 4 and 8; full economy data in game (reports, prices) → 4 and 7; QA → 9.

## Rules that apply to every milestone

- The Discord economy bot is the only economy. No second financial simulation, no Roblox balances, no daily processing in Roblox, no starting grant from Roblox.
- Bot changes are backward-compatible, tested and delivered as reviewed pull requests; nothing is deployed to the live bot without Justin's go.
- Endpoints, tables and commands are only implemented after checking the existing code; [05-economy-integration.md](05-economy-integration.md) records what was checked.

## Milestone log

### Milestone 0 — Technical and repository audit (2026-10-26)

- Audited the repository, Rojo setup, lore sources, assets, the economy bot and the development environment ([00-audit.md](00-audit.md)).
- Defined architecture, Roblox hierarchy, service model, security rules and sources of truth ([01-architecture.md](01-architecture.md)).
- Defined map size, coordinates, city footprints, road network and the Gundiville government district ([02-map-plan.md](02-map-plan.md), [map-plan.svg](map-plan.svg), [gundiville-plan.svg](gundiville-plan.svg)); added the requirements from Justin's city reference guide.
- Audited the economy bot against the full command reference and the source code; recorded system boundaries, the bridge design, downtime rules and the integration acceptance criteria ([05-economy-integration.md](05-economy-integration.md)).
- Listed dependencies and manual setup ([03-dependencies-and-setup.md](03-dependencies-and-setup.md)), assumptions, proposals and blockers ([04-assumptions-and-blockers.md](04-assumptions-and-blockers.md)), and the file inventory ([FILE-INVENTORY.md](FILE-INVENTORY.md)).
- Recorded Justin's decisions: the bot stays the only economy (D1), the game runs under the group (D2), the bot changes for the bridge are approved (D4), flag and emblem uploaded.
- Tests: `rojo build` with Rojo 7.7.1 succeeded; the bot's test suite passed (67/67) on the current default branch; both plans were rendered and checked visually. No Roblox tests (no Studio access).

### Milestone 1 — Core architecture and integration prototype (2026-10-26)

Two pull requests: the game (branch `claude/project-thread-55jwuj`) and the bot bridge (branch `claude/project-thread-55jwuj-bridge`).

- **Roblox foundation:** `default.project.json` (name *Ro-Nation*, `ServerStorage.StudioTools`, streaming, lighting); `Main.server.luau` and `Main.client.luau` load services and controllers in a fixed order, each failure isolated; shared `Config` (GameConfig with universe ID `10773079581`, group, Owner, staff rank), `Lore`, `Assets` (flag, emblem), `Net/Remotes`, `Types/Economy`, `Util/Log`, `Util/Signal`, `Util/Format`.
- **Server services:** `PermissionService` (Owner and staff from the group rank), `RemoteService` (creates the remotes, rate limits per player, safe error replies), `EconomyGateway` (bridge client: secret header, timeout, 3 retries with the same operation ID, pending operations in a DataStore, reconciliation, health checks), `AccountLinkService` (account view, link code, transactions, staff-only test transfer).
- **Client:** `NotificationController`, `UIController` (menu), `AccountController` ("Kagundi Bank Account": status, balances with "as of" time, Link Discord with code and command, last 5 bank transactions, test buttons for staff on staging).
- **Studio tool:** `CheckSetup` prints OK/FIX for the game ID, group owner, HTTP requests, streaming, asset types of flag and emblem, and the remotes.
- **Bot (off by default):** bridge module with 6 endpoints, migration 2 (`account_links`, `link_codes`, `bridge_operations`), `/link`, `/econ-admin link-remove`, optional ledger key for cash withdraw/deposit, `npm run bridge-staging`; see [05](05-economy-integration.md), sections 4, 6 and 8.
- **Tools:** StyLua 2.6.0 and selene 0.28.0 pinned in `rokit.toml` with `stylua.toml` and `selene.toml`.
- **Tests that ran (cloud session):** bot tests 89/89 (67 earlier + 22 new); staging smoke run of `npm run bridge-staging` (link, summary, one test transfer, replay returned the same transaction); `rojo build` OK; StyLua, selene and luau-lsp (strict, Roblox definitions) with 0 findings.
- **Not tested yet:** everything inside Roblox Studio. The checklist is [testing/m1-staging-checklist.md](testing/m1-staging-checklist.md). Open points: A11–A15 in [04](04-assumptions-and-blockers.md).
- **Deviations from the preview:** `InteractionController` moved to Milestone 4 (no interactive objects exist yet); `LogService` became the small utility `Util/Log`; `Util/Result` was not needed (the remotes use one `Reply` type); Lune not pinned (no pure-module tests yet); the test transaction is a 1 KGD bank ↔ cash movement on one's own account instead of a payment between two players, and `citizenPay` gets its key in Milestone 4 (P15).

## Milestone 2 plan (preview)

Details are fixed when the milestone starts. Source: [02-map-plan.md](02-map-plan.md).

1. `src/shared/Config/MapLayout.luau`: coordinates, footprints, heights and roads from the map plan as the single source.
2. Builder scripts in `src/studio/` that Justin runs once in Studio: terrain (basins, highland plateau, hills, boundary mountains, optional river), road builder from reusable segments (N1–N5, R1–R4, bridges), city footprints as simple blocks, airport runway and apron, both border crossings, property plots tagged with their property IDs.
3. Spawn at the Gundiville bus terminal; streaming checked with the blockout.
4. Studio checklist: run the builders, walk and fly the map, check drive times, save and back up the place.

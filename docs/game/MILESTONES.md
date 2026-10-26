# Ro-Nation Milestone Tracker

Work happens one milestone at a time. A milestone starts only after Justin writes `NEXT MILESTONE`. Status values: **Done**, **In progress**, **Waiting for approval**, **Not started**, **Blocked**.

Last update: 2026-10-26. The sequence below is the **integration-aware plan from Justin's architecture update of 2026-10-26**. It replaces the earlier 0–14 plan.

| # | Milestone | Status | Key prerequisites | Main deliverable |
|---|---|---|---|---|
| 0 | Technical and repository audit | **Done, waiting for `NEXT MILESTONE`** | — | `docs/game/` (this folder), incl. bot audit and system boundaries ([05](05-economy-integration.md)) |
| 1 | Core architecture and integration prototype | Not started | Milestone 0; Studio API access and HTTP requests on (03, steps 4–5); a staging key | Roblox foundation (services, remotes, logging, permissions); bridge prototype in the bot (off by default); account linking; verified staging test: read an account and make one safe test transfer exactly once |
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

## Milestone 1 plan (preview)

Details are fixed when the milestone starts.

**Roblox foundation**
1. Extend `default.project.json`: `ServerStorage.StudioTools`, `Workspace` streaming properties, basic `Lighting` settings.
2. `Main.server.luau` service loader with dependency order and isolated failures; `Main.client.luau` controller loader.
3. Shared modules: `Config/GameConfig`, `Config/Lore`, `Config/Assets` (flag `104179974183727`, emblem `88703156887446`), `Net/Remotes`, `Util/Log`, `Util/Signal`, `Util/Result`.
4. Server services: `LogService`, `RemoteService` (validation, rate limits), `PermissionService` (Owner and staff), `EconomyGateway` (bridge client with operation IDs, timeouts, bounded retries, pending-operation store).
5. Client controllers: `InteractionController`, `UIController`, `NotificationController`, plus a minimal "Link Discord" and "My account" screen for the prototype.
6. Replace the German test scripts with a startup message from the new entry points; pin StyLua, selene and Lune in `rokit.toml`.

**Bot (pull request, bridge off by default)**
7. `src/bridge/` with authentication, rate limits, audit records and the minimal operations from [05](05-economy-integration.md), section 4.4.
8. Migration: `account_links`, `link_codes`, `bridge_operations`; optional idempotency key for `citizenPay`; `/link` commands; regenerated command reference.
9. Tests: second shift refused, third business refused, bridge authentication, linking, idempotency, maintenance and outage behaviour.

**Verification**
10. Automated: `rojo build`, bot tests (old and new), Luau checks if approved in this environment.
11. Staging test in Studio by Justin with a checklist: link a test account, read the same balance as `/bank balance`, send one test transfer, repeat the request, confirm exactly one transaction in Discord.

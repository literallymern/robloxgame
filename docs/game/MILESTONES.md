# Ro-Nation Milestone Tracker

Work happens one milestone at a time. A milestone starts only after Justin writes `NEXT MILESTONE`. Status values: **Done**, **In progress**, **Waiting for approval**, **Not started**, **Blocked**.

Last update: 2026-10-26 (Milestone 0; decision D1 recorded).

| # | Milestone | Status | Key prerequisites | Main deliverable |
|---|---|---|---|---|
| 0 | Project audit and technical blueprint | **Done, waiting for `NEXT MILESTONE`** | — | `docs/game/` (this folder) |
| 1 | Project foundation and architecture | Not started | Milestone 0 | Service loader, remotes, logging, permissions skeleton, Rojo tree |
| 2 | Complete country map blockout | Not started | Milestone 1; Justin runs builders and saves the place | Terrain, roads, city footprints, airport, borders |
| 3 | Gundiville and the parliamentary plaza | Not started | Milestone 2; flag/emblem uploaded (03, step 2) | Government district and the Leader's statue |
| 4 | The three secondary cities | Not started | Milestone 2 | Stokondo, Kagundali, Oberdueshuson facilities |
| 5 | National infrastructure and map polish | Not started | Milestones 2–4 | Airport, customs, fuel, utilities, signage, vegetation |
| 6 | Player identity and persistence | Not started | Milestone 1; experience published under the group (D2 decided); Studio API access on | Session-locked, versioned profiles; account link and `EconomyGateway` (start of the minimum bridge) |
| 7 | Banking, economy and business (in-game front-ends) | Not started | Milestone 6; minimum Economy Bridge live (bot reachable over HTTPS) | Terminals for bank, jobs, business, property, credit, AVK on top of the bot |
| 8 | City Police, Gendarmerie and justice | Not started | Milestones 6 (records), 4 (Stokondo court) | Arrests, records, cases, appeals |
| 9 | Military, Revolutionary Guard and Intelligence | Not started | Milestones 6, 4 (Oberdueshuson) | Membership, ranks, orders, facility access |
| 10 | Healthcare, EMS and Brandwehr | Not started | Milestones 6, 3 (hospital, CRC) | Calls, treatment, fire and rescue |
| 11 | Vehicles, transport and interactions | Not started | Milestones 2–5 (roads), 6 (ownership) | Vehicle spawning, ownership, fuel, repairs |
| 12 | UI, navigation and player experience | Not started | Most gameplay systems | Onboarding, HUD, map, notifications |
| 13 | Discord economy integration (full) | Not started | Minimum bridge from Milestones 6/7 | Reports, snapshots, prices, treasury data, reconciliation |
| 14 | Performance, security and final QA | Not started | All | QA report |

## Economy bridge moved forward (decision D1, 2026-10-26)

Justin decided that the bridge to the economy bot comes before Milestone 7. The bot in `discord/bot` already implements banking, jobs, wages, businesses, property, loans, credit scores, AVK and fines, so the game uses it instead of a second economy:

- **Milestone 6 or 7** gets a *minimum Economy Bridge*: Discord ↔ Roblox account link, balance read, and idempotent transfers with transaction IDs, plus the game-side `EconomyGateway`.
- **Milestone 7** builds in-game front-ends (ATMs, bank counters, job boards, business and property terminals) on top of that bridge instead of a new money system.
- **Milestone 13** completes the rest: daily snapshots, commodity prices and treasury information in game, reconciliation tools, failure recovery and hardening.

Until the bot is hosted 24/7 with a public HTTPS address, the game can only be tested against the Studio-only sandbox money. Hosting is therefore a prerequisite for finishing Milestone 7 with real balances.

## Milestone log

### Milestone 0 — Project audit and technical blueprint (2026-10-26)

- Audited the repository, Rojo setup, lore sources, assets, the economy bot and the development environment ([00-audit.md](00-audit.md)).
- Defined architecture, Roblox hierarchy, service model, security rules and sources of truth ([01-architecture.md](01-architecture.md)).
- Defined map size, coordinates, city footprints, road network and the Gundiville government district ([02-map-plan.md](02-map-plan.md), [map-plan.svg](map-plan.svg), [gundiville-plan.svg](gundiville-plan.svg)).
- Listed dependencies and manual setup ([03-dependencies-and-setup.md](03-dependencies-and-setup.md)), assumptions, proposals and blockers ([04-assumptions-and-blockers.md](04-assumptions-and-blockers.md)), and the file inventory ([FILE-INVENTORY.md](FILE-INVENTORY.md)).
- Tests: `rojo build` of the current project with Rojo 7.7.1 succeeded; both plans were rendered and checked visually. No Roblox tests (no Studio access).

## Milestone 1 plan (preview)

Scope, so the next step is clear. Details are fixed when the milestone starts.

1. Extend `default.project.json`: `ServerStorage.StudioTools`, `Workspace` streaming properties, basic `Lighting` settings.
2. `src/server/Main.server.luau` service loader with dependency order and isolated failures; `src/client/Main.client.luau` controller loader.
3. Shared modules: `Config/GameConfig`, `Config/Lore` (canon names in one place), `Net/Remotes` (declarations and argument rules), `Util/Log`, `Util/Signal`, `Util/Result`.
4. Server services: `LogService`, `RemoteService` (creates remotes, validates, rate limits), `PermissionService` (Owner and staff; factions later).
5. Client controllers: `InteractionController`, `UIController`, `NotificationController` (skeletons with one working round trip: a client request that the server validates and answers).
6. Workspace container folders and a placeholder spawn.
7. Replace the German test scripts with a startup message from the new entry points.
8. Pin StyLua, selene and Lune in `rokit.toml`; add a `selene.toml` and `stylua.toml`.
9. Studio test checklist for Justin (start without errors, see the startup log, round trip works, rate limit rejects spam).

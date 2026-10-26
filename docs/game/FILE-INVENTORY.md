# Project File Inventory

Every file and folder of the project, what it is for and which milestone owns it. Updated at the end of every milestone.

Last update: 2026-10-26 (Milestone 2).

## Repository root

| Path | Purpose | Owner milestone | Status |
|---|---|---|---|
| `README.md` | German guide for Justin: Rojo, GitHub Desktop, daily workflow | Setup | Keep; links to `docs/game/` |
| `default.project.json` | Rojo tree (files → Studio): project name *Ro-Nation*, `src/studio` → `ServerStorage.StudioTools`, streaming (on, target radius 1,024, minimum 256, pause outside loaded area), `Lighting` (afternoon sun, atmosphere, bloom, sun rays, colour correction) | 1, 2 | Updated in Milestone 2 (rev. 2: lighting) |
| `rokit.toml` | Pinned tools: Rojo 7.7.1, selene 0.28.0, StyLua 2.6.0 | 1 | Updated in Milestone 1 |
| `selene.toml` | selene settings (`std = "roblox"`) | 1 | New in Milestone 1 |
| `stylua.toml` | StyLua settings (Luau, tabs, 120 columns) | 1 | New in Milestone 1 |
| `.gitignore` | Ignores place files and system files | — | Keep |

## Game code (`src/`, synced by Rojo)

The Rojo test scripts (`src/shared/Begruessung.luau`, `src/server/Start.server.luau`, `src/client/Start.client.luau`) were removed in Milestone 1.

| Path | Studio location | Purpose | Milestone |
|---|---|---|---|
| `src/shared/Config/GameConfig.luau` | `ReplicatedStorage.Shared.Config.GameConfig` | Game name, version, universe ID, group, Owner, staff rank, server size | 1 |
| `src/shared/Config/Lore.luau` | `…Shared.Config.Lore` | Country, capital, district, cities, currency, economic-day time zone (canon names in one place) | 1 |
| `src/shared/Config/Assets.luau` | `…Shared.Config.Assets` | Flag and emblem image IDs | 1 |
| `src/shared/Net/Remotes.luau` | `…Shared.Net.Remotes` | Names of all remotes; lookup helpers | 1 |
| `src/shared/Types/Economy.luau` | `…Shared.Types.Economy` | Shared types: reply, account view, link code, transaction | 1 |
| `src/shared/Util/Log.luau` | `…Shared.Util.Log` | Tagged logger `[Ro-Nation:Tag]` | 1 |
| `src/shared/Util/Signal.luau` | `…Shared.Util.Signal` | Small event helper | 1 |
| `src/shared/Util/Format.luau` | `…Shared.Util.Format` | KGD amounts and local times for display | 1 |
| `src/server/Main.server.luau` | `ServerScriptService.Server.Main` | Server entry point; loads services in a fixed order | 1 |
| `src/server/Config/BridgeConfig.luau` | `…Server.Config.BridgeConfig` | Bridge address, secret name, timeouts, retries (server only, no secret values) | 1 |
| `src/server/Services/PermissionService.luau` | `…Server.Services.PermissionService` | Owner and staff from the group rank | 1 |
| `src/server/Services/RemoteService.luau` | `…Server.Services.RemoteService` | Creates remotes, rate limits, safe replies, notifications | 1 |
| `src/server/Services/EconomyGateway.luau` | `…Server.Services.EconomyGateway` | Only connection to the economy bridge: secret header, retries, operation IDs, pending store, health | 1 |
| `src/server/Services/AccountLinkService.luau` | `…Server.Services.AccountLinkService` | Account view, link code, transactions, staff test transfer | 1 |
| `src/client/Main.client.luau` | `StarterPlayer.StarterPlayerScripts.Client.Main` | Client entry point; loads controllers | 1 |
| `src/client/Util/Ui.luau` | `…Client.Util.Ui` | UI building helpers and colours | 1 |
| `src/client/Controllers/NotificationController.luau` | `…Client.Controllers.NotificationController` | Toast notifications | 1 |
| `src/client/Controllers/UIController.luau` | `…Client.Controllers.UIController` | Screen GUI and menu | 1 |
| `src/client/Controllers/AccountController.luau` | `…Client.Controllers.AccountController` | "Kagundi Bank Account" window | 1 |
| `src/studio/CheckSetup.luau` | `ServerStorage.StudioTools.CheckSetup` | Read-only setup report for the Studio command bar | 1 |
| `src/shared/Config/MapLayout.luau` | `ReplicatedStorage.Shared.Config.MapLayout` | Every map coordinate: bounds, height anchors, hills, mountains and passes, places, zones, farming, road classes and roads, river, lakes, vegetation regions, road furniture, airport, crossings, property plots, Gundiville placeholders, spawn (single source) | 2 |
| `src/studio/BuildMap.luau` | `ServerStorage.StudioTools.BuildMap` | Entry point: `require(…BuildMap).run()` in the command bar (edit mode) builds terrain and parts | 2 |
| `src/studio/Map/Geometry.luau` | `…StudioTools.Map.Geometry` | 2D helpers: rectangle and segment distances, intersections, rounded corners, resampling (pure) | 2 |
| `src/studio/Map/SegmentGrid.luau` | `…StudioTools.Map.SegmentGrid` | Spatial grid for nearest road/river segment (pure) | 2 |
| `src/studio/Map/Land.luau` | `…StudioTools.Map.Land` | Land shape: base heights, noise, hills, boundary mountains, flattened places (pure) | 2 |
| `src/studio/Map/River.luau` | `…StudioTools.Map.River` | River course, downhill water level, carved channel (pure) | 2 |
| `src/studio/Map/RoadNetwork.luau` | `…StudioTools.Map.RoadNetwork` | Road centre lines, height profiles, junctions, bridges (pure) | 2 |
| `src/studio/Map/Heightfield.luau` | `…StudioTools.Map.Heightfield` | Finished terrain surface and materials per column (pure) | 2 |
| `src/studio/Map/Hash.luau` | `…StudioTools.Map.Hash` | Repeatable pseudo-random numbers from grid positions (pure) | 2 (rev. 2) |
| `src/studio/Map/Lakes.luau` | `…StudioTools.Map.Lakes` | Lakes: irregular shore, automatic water level, carved basin (pure) | 2 (rev. 2) |
| `src/studio/Map/Biomes.luau` | `…StudioTools.Map.Biomes` | Vegetation regions: forest cover, tree kinds, dryness (pure) | 2 (rev. 2) |
| `src/studio/Map/Fields.luau` | `…StudioTools.Map.Fields` | Farm field patchwork, crop rows, tobacco barns (pure) | 2 (rev. 2) |
| `src/studio/Map/Vegetation.luau` | `…StudioTools.Map.Vegetation` | Positions of trees, bushes, hedges and rocks (pure) | 2 (rev. 2) |
| `src/studio/Map/RoadDetails.luau` | `…StudioTools.Map.RoadDetails` | Positions of markings, marker posts, guard rails, street lights, signs, power lines (pure) | 2 (rev. 2) |
| `src/studio/Map/Builders/Util.luau` | `…Map.Builders.Util` | Generated-content marking, parts, wedges, cylinders, ellipsoids, strips, labels | 2 |
| `src/studio/Map/Builders/Terrain.luau` | `…Map.Builders.Terrain` | Writes the terrain and water in 64 × 64-stud chunks | 2 |
| `src/studio/Map/Builders/Roads.luau` | `…Map.Builders.Roads` | Road surface parts along straight runs, junction joints | 2 |
| `src/studio/Map/Builders/Bridges.luau` | `…Map.Builders.Bridges` | Bridge decks, railings, piers | 2 |
| `src/studio/Map/Builders/Places.luau` | `…Map.Builders.Places` | Place outlines, names, Gundiville placeholders | 2 |
| `src/studio/Map/Builders/Airport.luau` | `…Map.Builders.Airport` | Runway, taxiway, apron, airport building blocks | 2 |
| `src/studio/Map/Builders/Crossings.luau` | `…Map.Builders.Crossings` | Customs canopy, barrier, office, truck inspection | 2 |
| `src/studio/Map/Builders/Properties.luau` | `…Map.Builders.Properties` | 16 property plot markers, tag `PropertyPlot` | 2 |
| `src/studio/Map/Builders/Spawn.luau` | `…Map.Builders.Spawn` | Bus terminal spawn; removes the template Baseplate and SpawnLocation | 2 |
| `src/studio/Map/Builders/Boundary.luau` | `…Map.Builders.Boundary` | Invisible walls along the map edge | 2 |
| `src/studio/Map/Builders/Environment.luau` | `…Map.Builders.Environment` | Terrain colours, water colour, animated grass, clouds | 2 (rev. 2) |
| `src/studio/Map/Builders/RoadDetails.luau` | `…Map.Builders.RoadDetails` | Builds markings, marker posts, guard rails, street lights, power lines and signs | 2 (rev. 2) |
| `src/studio/Map/Builders/Signs.luau` | `…Map.Builders.Signs` | Sign models: town, facility, speed, stop, direction, chevron, welcome | 2 (rev. 2) |
| `src/studio/Map/Builders/Countryside.luau` | `…Map.Builders.Countryside` | Pasture fences and tobacco barns | 2 (rev. 2) |
| `src/studio/Map/Builders/Vegetation.luau` | `…Map.Builders.Vegetation` | Tree, bush and rock parts in 1,024-stud area folders | 2 (rev. 2) |

Planned folders: `src/server/{Persistence,Economy,Packages}` (Milestone 4), `src/client/UI` (Milestone 4/8). See [01-architecture.md](01-architecture.md), section 3.

## Offline tests (`tests/`, not synced to Studio)

| Path | Purpose | Milestone |
|---|---|---|
| `tests/map/run.py` | Bundles the map modules with a stand-in for `script`/`require` and runs a Luau test script with the Luau CLI | 2 |
| `tests/map/test_all.py` | Runs all map checks (`--quick` skips the builder run) | 2 |
| `tests/map/heightfield.spec.luau` | Checks of the layout and the terrain calculations | 2 |
| `tests/map/landscape.spec.luau` | Checks of river cascades, lakes, fields, road details and vegetation | 2 (rev. 2) |
| `tests/map/builders.spec.luau` | Runs the real `BuildMap` against the Roblox stand-in and checks the result | 2 |
| `tests/map/roblox-mock.luau` | Strict stand-in for the Roblox API parts the builders use | 2 |
| `tests/map/preview.luau`, `tests/map/preview.py` | Renders the map preview image (needs Pillow and numpy) | 2 |

## Game documentation (`docs/game/`)

| File | Content |
|---|---|
| `README.md` | Index of the game documentation |
| `00-audit.md` | Milestone 0 audit: environment, repository, lore, assets, avatar, group, economy |
| `testing/m1-staging-checklist.md` | Milestone 1 Studio test against the staging bridge |
| `testing/m2-map-checklist.md` | Milestone 2 Studio map build and walk-through |
| `map-blockout-preview.png` | Preview of the generated map (from `tests/map/preview.py`) |
| `01-architecture.md` | Architecture, hierarchy, services, security, sources of truth, persistence, streaming, testing |
| `02-map-plan.md` | Map size, coordinates, footprints, roads, Gundiville district |
| `03-dependencies-and-setup.md` | Manual steps for Justin, tools, engine features, third-party code, external systems |
| `04-assumptions-and-blockers.md` | Assumptions, non-canon proposals, open decisions, blockers |
| `05-economy-integration.md` | Verified bot audit, system boundaries, bridge endpoints and account linking as built, exactly-once rules, downtime rules, staging, integration acceptance criteria, bot changes |
| `MILESTONES.md` | Milestone tracker and log |
| `FILE-INVENTORY.md` | This file |
| `map-plan.svg` | Overview map of the East District (generated plan image) |
| `gundiville-plan.svg` | Plan of the Gundiville government district |

## Discord package (`discord/`, from PR #2, #3 and #5)

| Path | Files | Purpose |
|---|---|---|
| `discord/README.md` | 1 | Overview of the Discord package |
| `discord/docs/` | 11 | Server blueprint, roles, permissions, messages, bots, economy design, setup guide, checklist, QA report, summary, command reference |
| `discord/messages/` | 24 | Ready-to-post channel texts |
| `discord/assets/` | 2 | Flag and emblem PNGs |
| `discord/bot/src/economy/` | 26 | Economic simulation (ledger, citizens, businesses, employment, market, credit, AVK, property, fines, invoices, treasury, policy, events, daily tick, report) |
| `discord/bot/src/discord/` | 11 | Slash commands, buttons, tickets, permissions |
| `discord/bot/src/blueprint/`, `src/setup/`, `src/db/` | 9 | Roles/channels source of truth, setup planner and texts, SQLite schema |
| `discord/bot/src/index.js`, `src/config.js`, `src/check-node.js` | 3 | Bot entry point, configuration, Node version check |
| `discord/bot/scripts/` | 5 | setup-server, deploy-commands, post-messages, simulate, generate-docs |
| `discord/bot/test/` | 9 | Automated tests |
| `discord/bot/package.json`, `package-lock.json`, `.env.example`, `.gitignore`, `ecosystem.config.cjs` | 5 | Node project files and the pm2 start file (no secrets in Git) |

The Milestone 1 bot pull request (branch `claude/project-thread-55jwuj-bridge`, decision D4) adds, once merged: `discord/bot/src/bridge/server.js` and `operations.js` (Roblox bridge, off by default), `src/economy/links.js` (account links), `src/discord/commands/link.js` (`/link`), `scripts/bridge-staging.js` (staging bridge), and the tests `limits.test.js`, `links.test.js`, `bridge.test.js`; it changes `src/db/database.js` (migration 2), `src/config.js`, `src/index.js`, `src/economy/payments.js`, `src/discord/commands/admin.js` and `index.js`, `.env.example`, `package.json`, and the docs `05-bots-and-integrations.md`, `10-summary.md` and the command reference. Details: [05-economy-integration.md](05-economy-integration.md), section 8.

## Not on the default branch yet

| Path | Where | Purpose |
|---|---|---|
| `lore/Kagundi-Lore-Bible.md` | PR #1 | Lore Bible (Revision 2) |
| `lore/images/kagundi-flag.png`, `lore/images/kagundi-emblem.png` | PR #1 | Flag and emblem |

## Shared project files (outside Git)

| Path | Purpose |
|---|---|
| `lore/Kagundi-Encyclopedia.pdf` | Authoritative lore reference (15 pages) |
| `lore/kagundi-flag.png`, `lore/kagundi-emblem.png` | Official visual references |
| `lore/roblox-upload/Kagundi-Flag-1024x609.png`, `Kagundi-Emblem-1024x1024.png` | Roblox-sized versions used for the uploads |
| `lore/Ro-Nation_Kagundi_City_References.pdf` | Justin's city development reference guide (visual direction, not canon) |
| `rojo/Rojo-Anleitung.md` | German Rojo guide (copy of the README section) |
| `game/milestone-0/map-plan.png`, `gundiville-plan.png` | Rendered map plans from Milestone 0 |
| `game/milestone-1/Studio-Test-Meilenstein-1.md` | German step-by-step guide for Justin's Milestone 1 Studio test |
| `game/milestone-2/Studio-Test-Meilenstein-2.md`, `Karte-Vorschau.png` | German step-by-step guide for Justin's Milestone 2 Studio test and the map preview |
| `game/reference/owner-avatar-2595858454.jpg` | Justin's avatar screenshot, visual reference for the statue |

## Roblox (outside Git)

| Item | Where | Status |
|---|---|---|
| Place file (terrain, buildings, statue) | Roblox, edited in Studio | Fresh Baseplate (confirmed) |
| Experience | Universe ID 10773079581, group 60169080 | Published 2026-10-26 (D2) |
| Local Secret `RoNationBridgeKey` | Studio, Experience Settings → Security → Local Secrets | Set by Justin during the Milestone 1 Studio test (staging key only) |
| Flag and emblem images | Roblox asset library (group) | Image IDs: flag `74627674981379`, emblem `124794973631384` (decals `88703156887446` and `104179974183727`) |
| Group "Democratic Republic of Kagundi" | roblox.com, ID 60169080 | Exists, owned by LiterallyDrJustin |

# Project File Inventory

Every file and folder of the project, what it is for and which milestone owns it. Updated at the end of every milestone.

Last update: 2026-10-28 (Milestone 3 revision 2: building overhaul).

## Repository root

| Path | Purpose | Owner milestone | Status |
|---|---|---|---|
| `README.md` | German guide for Justin: Rojo, GitHub Desktop, daily workflow | Setup | Keep; links to `docs/game/` |
| `default.project.json` | Rojo tree (files → Studio): project name *Ro-Nation*, `src/studio` → `ServerStorage.StudioTools`, streaming (on, target radius 1,024, minimum 256, pause outside loaded area), `Lighting` (neutral highland preset; effects `RoNationAtmosphere`, `RoNationBloom`, `RoNationSunRays`, `RoNationColorCorrection`) | 1, 2 | Updated in Milestone 2 (rev. 2 lighting; rev. 3/4 renamed effects and the neutral preset shared with the weather model) |
| `rokit.toml` | Pinned tools: Rojo 7.7.1, selene 0.28.0, StyLua 2.6.0 | 1 | Updated in Milestone 1 |
| `selene.toml` | selene settings (`std = "roblox"`) | 1 | New in Milestone 1 |
| `stylua.toml` | StyLua settings (Luau, tabs, 120 columns) | 1 | New in Milestone 1 |
| `.gitignore` | Ignores place files and system files | — | Keep |
| `assets/audio/` | Original rain loop and thunder WAVs (CC0) with an upload guide; not synced by Rojo | 2 (rev. 3) | New; silent in game until uploaded (B7) |
| `tools/generate-weather-audio.py` | Generates the weather WAVs (needs numpy) | 2 (rev. 3) | New |
| `tools/preview-canopies.py`, `tools/preview-junction-trees.py` | Software previews of the tree source geometry (not Roblox renders) | 2 (rev. 3/4) | New |

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
| `src/server/Main.server.luau` | `ServerScriptService.Server.Main` | Server entry point; loads services in a fixed order (5 since rev. 3, 6 with `DoorService` since Milestone 3 rev. 2) | 1, 3 |
| `src/server/Config/BridgeConfig.luau` | `…Server.Config.BridgeConfig` | Bridge address, secret name, timeouts, retries (server only, no secret values) | 1 |
| `src/server/Services/PermissionService.luau` | `…Server.Services.PermissionService` | Owner and staff from the group rank | 1 |
| `src/server/Services/RemoteService.luau` | `…Server.Services.RemoteService` | Creates remotes, rate limits, safe replies, notifications | 1 |
| `src/server/Services/EconomyGateway.luau` | `…Server.Services.EconomyGateway` | Only connection to the economy bridge: secret header, retries, operation IDs, pending store, health | 1 |
| `src/server/Services/AccountLinkService.luau` | `…Server.Services.AccountLinkService` | Account view, link code, transactions, staff test transfer | 1 |
| `src/server/Services/DoorService.luau` | `…Server.Services.DoorService` | Swings the tagged building doors on their prompt (server tween of a hinge part; no remotes) | 3 (rev. 2) |
| `src/client/Main.client.luau` | `StarterPlayer.StarterPlayerScripts.Client.Main` | Client entry point; loads controllers (5 since rev. 3) | 1 |
| `src/client/Util/Ui.luau` | `…Client.Util.Ui` | UI building helpers and colours | 1 |
| `src/client/Controllers/NotificationController.luau` | `…Client.Controllers.NotificationController` | Toast notifications | 1 |
| `src/client/Controllers/UIController.luau` | `…Client.Controllers.UIController` | Screen GUI and menu | 1 |
| `src/client/Controllers/AccountController.luau` | `…Client.Controllers.AccountController` | "Kagundi Bank Account" window | 1 |
| `src/studio/CheckSetup.luau` | `ServerStorage.StudioTools.CheckSetup` | Read-only setup report for the Studio command bar | 1 |
| `src/shared/Config/Environment.luau` | `…Shared.Config.Environment` | Weather and day/night settings: 60-minute day, five weather profiles, transitions, quality, optional audio IDs | 2 (rev. 3) |
| `src/shared/Environment/Model.luau` | `…Shared.Environment.Model` | Deterministic lighting and weather maths shared by server and client | 2 (rev. 3) |
| `src/shared/Environment/Presentation.luau` | `…Shared.Environment.Presentation` | Owned Lighting effects, legacy migration, respects custom effects | 2 (rev. 3) |
| `src/server/Services/EnvironmentService.luau` | `…Server.Services.EnvironmentService` | One weather schedule per server; replicates small state attributes (no remotes) | 2 (rev. 3) |
| `src/client/Controllers/EnvironmentController.luau` | `…Client.Controllers.EnvironmentController` | Smooth sky and clock, street lights near the camera | 2 (rev. 3) |
| `src/client/Controllers/WeatherEffects.luau` | `…Client.Controllers.WeatherEffects` | Camera-local rain, lightning and optional sounds | 2 (rev. 3) |
| `src/client/Controllers/EnvironmentQualityController.luau` | `…Client.Controllers.EnvironmentQualityController` | Weather menu: effect quality for the session | 2 (rev. 3) |
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
| `src/studio/Map/Builders/Util.luau` | `…Map.Builders.Util` | Generated-content marking, parts, wedges, cylinders, ellipsoids, strips, labels (reflectance option since 3) | 2, 3 |
| `src/studio/Map/Builders/Terrain.luau` | `…Map.Builders.Terrain` | Writes the terrain and water in 64 × 64-stud chunks | 2 |
| `src/studio/Map/Builders/Roads.luau` | `…Map.Builders.Roads` | Road surface parts along straight runs, junction joints | 2 |
| `src/studio/Map/Builders/Bridges.luau` | `…Map.Builders.Bridges` | Bridge decks, railings, piers | 2 |
| `src/studio/Map/Builders/Places.luau` | `…Map.Builders.Places` | Place outlines, names, Gundiville placeholders (skips those the government district replaces) | 2, 3 |
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
| `src/studio/CheckEnvironment.luau` | `ServerStorage.StudioTools.CheckEnvironment` | Read-only report of the saved environment, junction and lighting revisions | 2 (rev. 3) |
| `src/studio/Map/LandscapeConfig.luau` | `…StudioTools.Map.LandscapeConfig` | Artist controls for the highland relief and soil detail | 2 (rev. 3) |
| `src/studio/Map/OriginalSurface.luau` | `…StudioTools.Map.OriginalSurface` | Frozen copy of the earlier terrain formulas, so saved columns can be recognised | 2 (rev. 3) |
| `src/studio/Map/ExistingTerrain.luau` | `…StudioTools.Map.ExistingTerrain` | Protects hand-built parts and places plants on the saved terrain | 2 (rev. 3) |
| `src/studio/Map/Builders/TerrainUpgrade.luau` | `…Map.Builders.TerrainUpgrade` | Patches only saved terrain columns that match the earlier generator | 2 (rev. 3) |
| `src/studio/Map/Builders/CanopyLibrary.luau` | `…Map.Builders.CanopyLibrary` | Native CSG tree crowns, compiled once and kept in ServerStorage | 2 (rev. 3) |
| `src/studio/UpgradeKagundali.luau` | `ServerStorage.StudioTools.UpgradeKagundali` | Command: apply the R3/N5 junction benchmark to a saved place | 2 (rev. 4) |
| `src/studio/UseCreatorStoreAssets.luau` | `ServerStorage.StudioTools.UseCreatorStoreAssets` | Command: import the Roblox packs, then run `UpgradeKagundali` | 2 (rev. 4) |
| `src/studio/Map/JunctionLandscape.luau` | `…StudioTools.Map.JunctionLandscape` | Bounds, ground shapes and revisions of the junction area | 2 (rev. 4) |
| `src/studio/Map/KagundaliUpdate.luau` | `…StudioTools.Map.KagundaliUpdate` | Staged, repeatable junction update shared by the commands and `BuildMap` | 2 (rev. 4) |
| `src/studio/Map/CreatorAssets.luau` | `…StudioTools.Map.CreatorAssets` | Imports Forest Pack and City Props Pack (creator check, visual parts only, no scripts) | 2 (rev. 4) |
| `src/studio/Map/Builders/Kagundali.luau` | `…Map.Builders.Kagundali` | Junction plants, shoulders, drainage, sign construction, workshop | 2 (rev. 4) |
| `src/studio/Map/Builders/JunctionTrees.luau` | `…Map.Builders.JunctionTrees` | Original tree, bush and fern templates for the junction (fallback without the packs) | 2 (rev. 4) |
| `src/studio/Map/Builders/JunctionMarkings.luau` | `…Map.Builders.JunctionMarkings` | Restores road markings on the saved road surface at the junction | 2 (rev. 4) |
| `src/shared/Config/GovernmentDistrict.luau` | `ReplicatedStorage.Shared.Config.GovernmentDistrict` | Government district: streets, square, buildings, residence, statue (user, size, finish, inscription), part budget (single source; 33,000 since rev. 3) | 3 |
| `src/studio/BuildGundiville.luau` | `ServerStorage.StudioTools.BuildGundiville` | Commands: `run()`, `statue({ Finish = … })`, `focus()`, `remove()` (edit mode, one undo step each); `run()` installs the interior library when it is missing | 3 |
| `src/studio/UseInteriorAssets.luau` | `ServerStorage.StudioTools.UseInteriorAssets` | Command: (re)load the official Roblox interior library | 3 (rev. 3) |
| `src/studio/Gundiville/Kit.luau` | `…StudioTools.Gundiville.Kit` | Building kit: walls with openings, windows, shutters, columns, pediments, roofs, dome, flags, emblem, inscriptions, lamps, trees, furniture (part counter moved to `Architecture.Parts` in rev. 2) | 3 |
| `src/studio/Gundiville/District.luau` | `…Gundiville.District` | Builds the whole district into one folder and reports parts per builder | 3 |
| `src/studio/Gundiville/Ground.luau` | `…Gundiville.Ground` | Measures the saved terrain under the district (raycasts, terrain only read) and the roads the avenue and main street meet; the district is raised onto it with footings and end ramps | 3 |
| `src/studio/Gundiville/Streets.luau` | `…Gundiville.Streets` | Carriageways, sidewalks, avenue median with trees and lights, centre lines, zebra crossings, street name signs | 3 |
| `src/studio/Gundiville/Square.luau` | `…Gundiville.Square` | Main square: paving, 16 market stalls (awning, counter, goods, stool, trade sign), flags, lamps, benches, trees | 3 (rev. 2) |
| `src/studio/Gundiville/Congress.luau` | `…Gundiville.Congress` | General People's Congress with dome: facades, space plan of all storeys (entrance hall, chamber with 50 seats, offices, committee rooms, press room) | 3 (rev. 2) |
| `src/studio/Gundiville/Hausali.luau` | `…Gundiville.Hausali` | Hausali: facades, risalit, balcony, garden and the space plan of all storeys (lobby, offices, cabinet room, salons) | 3 (rev. 2) |
| `src/studio/Gundiville/CentralBank.luau` | `…Gundiville.CentralBank` | Central Bank: facades and space plan (banking hall with five tellers, vault, offices; no money functions) | 3 (rev. 2) |
| `src/studio/Gundiville/Residence.luau` | `…Gundiville.Residence` | Leader's residence: walls, gate, furnished guard posts, two-storey villa with 17 rooms (Leader's office, salon, music room, private rooms), gardens, gazebo | 3 (rev. 2) |
| `src/studio/Gundiville/Statue.luau` | `…Gundiville.Statue` | Statue of Dr. Justin Wachmann: loads the Owner's avatar, poses it from its joints and accessory attachments, finishes (gold by default), pedestal, plaques, floodlights; stand-in fallback | 3 |
| `src/studio/Architecture/Parts.luau` | `…StudioTools.Architecture.Parts` | Counted, anchored part creation shared by the kit and the architecture modules; footings; material variants | 3 (rev. 2/3) |
| `src/studio/Architecture/StoreAssets.luau` | `…Architecture.StoreAssets` | Official Roblox interior library: catalogue of 73 Duvall Drive templates, creator check, clean-up, floor material variants, `place()` | 3 (rev. 3) |
| `src/studio/Architecture/Materials.luau` | `…Architecture.Materials` | Material and colour presets (plaster, stone, tiles, wood, fabric, metal, glass), mid-tone paints, panelling woods, carpets, parquet variants | 3 (rev. 2/3) |
| `src/studio/Architecture/Openings.luau` | `…Architecture.Openings` | Windows (frame, mullions, sills, surrounds, shutters) and doors (frames, leaves, handles, prompt, `RoNationDoor` tag) in real wall openings | 3 (rev. 2) |
| `src/studio/Architecture/Shell.luau` | `…Architecture.Shell` | Facade wall runs with openings, storey by storey (painted inner lining); maps every window to the room behind it | 3 (rev. 2/3) |
| `src/studio/Architecture/Plan.luau` | `…Architecture.Plan` | Space plans: partitions with doors, floor slabs, finishes, skirting, ceiling lights and chandeliers, door signs, stairs; building styles; window and reachability report | 3 (rev. 2/3) |
| `src/studio/Architecture/Stairs.luau` | `…Architecture.Stairs` | Switchback staircases with landings and handrails | 3 (rev. 2) |
| `src/studio/Architecture/Rooms.luau` | `…Architecture.Rooms` | 44 furnishing recipes by room type (official models where they fit); dados, panelling, cornices; placement that keeps doors and windows clear | 3 (rev. 2/3) |
| `src/studio/Architecture/Furniture.luau` | `…Architecture.Furniture` | 62 furniture pieces and fittings (seats are `Seat` parts, lamps, chandeliers, radiators, curtains, runners, fire safety); places official templates | 3 (rev. 2/3) |
| `src/studio/Architecture/Exterior.luau` | `…Architecture.Exterior` | Gutters, downpipes, AC units, rooftop condensers, vents, roof hatches | 3 (rev. 2) |

Planned folders: `src/server/{Persistence,Economy,Packages}` (Milestone 4), `src/client/UI` (Milestone 4/8). See [01-architecture.md](01-architecture.md), section 3.

## Offline tests (`tests/`, not synced to Studio)

| Path | Purpose | Milestone |
|---|---|---|
| `tests/map/run.py` | Bundles the map modules with a stand-in for `script`/`require` and runs a Luau test script with the Luau CLI | 2 |
| `tests/map/test_all.py` | Runs all map checks (`--quick` skips the builder run) | 2 |
| `tests/map/heightfield.spec.luau` | Checks of the layout and the terrain calculations | 2 |
| `tests/map/landscape.spec.luau` | Checks of river cascades, lakes, fields, road details and vegetation | 2 (rev. 2) |
| `tests/map/builders.spec.luau` | Runs the real `BuildMap` against the Roblox stand-in and checks the result | 2 |
| `tests/map/roblox-mock.luau` | Strict stand-in for the Roblox API parts the builders use (since 3 also seats, decals, lights, humanoid characters, `Players`, `ChangeHistoryService`; since rev. 2 signals, tags, prompts, `TweenService`) | 2, 3 |
| `tests/map/gundiville.spec.luau` | 177 checks of the government district build (plan, budget, buildings, flags, rooms, statue, reruns, store assets) | 3 |
| `tests/map/architecture.spec.luau` | 71 checks of the four buildings: every window has a room, rooms reachable, budgets, doors, furniture, stairs, DoorService | 3 (rev. 2) |
| `tests/map/interior-assets.spec.luau` | 47 checks of the interior library (importer against synthetic packs) and of the four buildings furnished with it | 3 (rev. 3) |
| `tests/map/preview.luau`, `tests/map/preview.py` | Renders the map preview image (needs Pillow and numpy) | 2 |
| `tests/map/*.spec.luau` (17 more: river detail, roads realism, vegetation builders, canopy, highland relief, soil, original parity, terrain upgrade, infrastructure, bridge and road ground, Kagundali, Kagundali terrain, junction markings, creator assets, upgrade entry, environment inspection) | Checks of the environment overhaul and the junction benchmark; all run by `test_all.py` | 2 (rev. 3/4) |
| `tests/map/preview-canopies.luau`, `tests/map/preview-junction.luau` | Geometry data for the tree previews in `tools/` | 2 (rev. 3/4) |
| `tests/environment/run.py` and `*.spec.luau` | Weather model, service, effects, quality menu and lighting presentation checks | 2 (rev. 3) |

## Game documentation (`docs/game/`)

| File | Content |
|---|---|
| `README.md` | Index of the game documentation |
| `00-audit.md` | Milestone 0 audit: environment, repository, lore, assets, avatar, group, economy |
| `testing/m1-staging-checklist.md` | Milestone 1 Studio test against the staging bridge |
| `testing/m2-map-checklist.md` | Milestone 2 Studio map build and walk-through |
| `testing/m3-district-checklist.md` | Milestone 3 Studio district build and walk-through |
| `gundiville-district-preview.jpg` | Offline preview of the government district (six views; simplified renderer) |
| `map-blockout-preview.png` | Preview of the generated map (from `tests/map/preview.py`) |
| `06-environment-overhaul.md` | Weather, day/night, lighting and the `highland-4` saved-terrain upgrade |
| `07-kagundali-junction.md` | R3/N5 junction benchmark: what it builds and how to apply it |
| `08-kagundali-screenshot-fixes.md` | Fixes after Justin's Studio screenshots of 28 October |
| `09-creator-store-assets.md` | Import of Roblox's Forest Pack and City Props Pack |
| `11-interior-realism.md` | Interior overhaul: official Roblox furniture library, linings and panelling, interior lighting, building styles |
| `interior-previews-1.jpg`, `interior-previews-2.jpg` | Offline previews of twelve rooms with the official models (not Roblox renders) |
| `canopy-geometry-preview.png`, `kagundali-tree-sources.png` | Software previews of the tree geometry (not Roblox renders) |
| `01-architecture.md` | Architecture, hierarchy, services, security, sources of truth, persistence, streaming, testing |
| `02-map-plan.md` | Map size, coordinates, footprints, roads, Gundiville district (as built: section 14) |
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

## Lore (`lore/`, from PR #1, merged 2026-10-26)

| Path | Purpose |
|---|---|
| `lore/Kagundi-Lore-Bible.md` | Lore Bible (Revision 2) |
| `lore/images/kagundi-flag.png`, `lore/images/kagundi-emblem.png` | Flag and emblem |

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
| Place file (terrain, buildings, statue) | Roblox, edited in Studio | Map built with `BuildMap.run()` (2026-10-26); junction benchmark applied (junction-2, 2026-10-28) |
| Experience | Universe ID 10773079581, group 60169080 | Published 2026-10-26 (D2) |
| Local Secret `RoNationBridgeKey` | Studio, Experience Settings → Security → Local Secrets | Set by Justin during the Milestone 1 Studio test (staging key only) |
| Flag and emblem images | Roblox asset library (group) | Image IDs: flag `74627674981379`, emblem `124794973631384` (decals `88703156887446` and `104179974183727`) |
| Group "Democratic Republic of Kagundi" | roblox.com, ID 60169080 | Exists, owned by LiterallyDrJustin |

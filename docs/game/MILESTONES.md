# Ro-Nation Milestone Tracker

Work happens one milestone at a time. A milestone starts only after Justin writes `NEXT MILESTONE`. Status values: **Done**, **In progress**, **Waiting for approval**, **Not started**, **Blocked**.

Last update: 2026-10-28 (Milestone 3 built). The sequence below is the **integration-aware plan from Justin's architecture update of 2026-10-26**. It replaces the earlier 0–14 plan.

| # | Milestone | Status | Key prerequisites | Main deliverable |
|---|---|---|---|---|
| 0 | Technical and repository audit | **Done** | — | `docs/game/` (this folder), incl. bot audit and system boundaries ([05](05-economy-integration.md)) |
| 1 | Core architecture and integration prototype | **Done** (Studio staging test passed 2026-10-26) | Milestone 0; Studio API access and HTTP requests on (03, steps 4–5); a staging key | Roblox foundation (services, remotes, logging, permissions); bridge prototype in the bot (off by default); account linking; verified staging test: read an account and make one safe test transfer exactly once |
| 2 | Complete country map blockout | **Done** (closed by Justin on 2026-10-28 when he moved on to Milestone 3; terrain work continues with Codex) | Milestone 1; Justin runs builders and saves the place | Terrain, roads, footprints of all four cities, airport, border crossings |
| 3 | Gundiville government district | **Waiting for approval** (built offline 2026-10-28; Justin's Studio test pending) | Milestone 2; flag and emblem IDs (done) | General People's Congress, Hausali, Leader's residence, square, statue of Dr. Justin Wachmann |
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
- **Studio staging test (Justin, 2026-10-26): passed.** [testing/m1-staging-checklist.md](testing/m1-staging-checklist.md): setup check OK (experience ID, group owner, HTTP, streaming); `Economy status: available` (confirms A11–A13); link code confirmed in the staging console; balance shown in game; test withdrawal and deposit worked; outage test: the window showed "temporarily unavailable", the request was cancelled after the bridge came back, and no money was created (as reported by Justin).
- **Found in the test:** CheckSetup must run in edit mode (checklist clarified); Local Secrets is a form, not a JSON box (docs corrected); flag and emblem IDs were decal IDs in swapped order; the image IDs are now in `Config/Assets` (B5 resolved).
- **Deviations from the preview:** `InteractionController` moved to Milestone 4 (no interactive objects exist yet); `LogService` became the small utility `Util/Log`; `Util/Result` was not needed (the remotes use one `Reply` type); Lune not pinned (no pure-module tests yet); the test transaction is a 1 KGD bank ↔ cash movement on one's own account instead of a payment between two players, and `citizenPay` gets its key in Milestone 4 (P15).

### Milestone 2 — Complete country map blockout (2026-10-26)

One pull request (branch `claude/project-thread-55jwuj`). Details and the as-built numbers: [02-map-plan.md](02-map-plan.md), section 12.

- **Single source:** `src/shared/Config/MapLayout.luau` holds every map coordinate: bounds, 30 height anchors, hills, boundary mountains with three passes, 16 places (4 cities, 7 facilities incl. a new cattle ranch yard, 2 border crossings, 3 plots), surface zones, road classes, 16 roads, the river, airport, crossings, the 16 property plots, Gundiville placeholders and the spawn.
- **Pure calculations (offline-tested):** `src/studio/Map/` — `Geometry` (distances, intersections, rounded corners, resampling), `SegmentGrid` (fast nearest-segment lookup), `Land` (blended base heights, rolling noise, noisy hill ridges, ridged boundary mountains, flattened places), `River` (water level that only falls downstream, carved bed, banks and valley walls), `RoadNetwork` (curves at least the class radius, grade-limited height profiles, flat in places, level at junctions, bridges detected where roads cross the river and raised 12 studs above the water), `Heightfield` (the finished surface and materials).
- **Studio builders:** `src/studio/BuildMap.luau` (one command in the command bar) and `src/studio/Map/Builders/` — terrain in 64 × 64-stud chunks with water, road parts with round joints and centre lines, five bridges with railings and piers, place outlines, names and entry signs, Gundiville district placeholders, airport (runway, taxiway, apron, terminal, hangar, tower), both border crossings (canopy, barrier, customs office, truck inspection), 16 property plots tagged `PropertyPlot`, invisible edge walls, and the spawn at the Gundiville bus terminal. Reruns replace only what they generated.
- **Project file:** streaming target radius 1,024, minimum radius 256, integrity mode *pause outside loaded area*.
- **Tests that ran (cloud session):** `python3 tests/map/test_all.py` — 456 checks of the layout and calculations (all roads within their grade and curve limits, exactly the five planned bridges with clearance, river never uphill, no road touching the river outside bridges, every road end connected, places flat, no cliffs inside the ring, plots not on roads, spawn on flat ground), the 16 plots match the bot's `GENESIS_PROPERTIES` by name, city and type, and 42 checks of the real `BuildMap` run against a strict Roblox stand-in (all 25,600 terrain chunks written, voxel heights match the calculation at 12 probe points, water written, 1,521 parts inside the map, road parts on the profile, rerun without duplicates and without touching hand-built parts). `rojo build` OK; StyLua, selene and luau-lsp (strict) with 0 findings. Preview image rendered: [map-blockout-preview.png](map-blockout-preview.png).
- **Not tested yet:** anything in Roblox Studio (rendering, real build time, streaming, walking and driving). Justin's checklist: [testing/m2-map-checklist.md](testing/m2-map-checklist.md).
- **Deviations from the preview:** roads end at place edges (P16); property plots carry the property name, not an ID, because the game cannot know the bot's IDs yet (P18); drive times are timed on foot at car speed (WalkSpeed 90) because the first vehicle comes in Milestone 4; Lune was replaced by the Luau command line tool for the offline tests.

**Revision 2 — landscape pass (2026-10-26).** Justin asked, before his Studio test, to rework the whole terrain with decoration, road signs, markings and vegetation so it looks livelier and more realistic. Second pull request on branch `claude/project-thread-55jwuj`; details in [02-map-plan.md](02-map-plan.md), section 13.

- **Terrain:** medium noise layer, river 18 → 60 studs wide with 98 cascades and flat voxel-aligned pools, three lakes with automatic water level, 174 fields with crop rows (tobacco, maize, fallow, meadow, pasture), materials by region and slope (red laterite earth, basalt, slate, lush river banks). Layout version 2.
- **Vegetation:** about 8,200 trees of four kinds (broadleaf, acacia, eucalyptus, pine) by region, groves, a river belt, avenues and windbreaks; about 4,100 bushes and hedgerows; about 2,700 rocks. One knob, `MapLayout.Vegetation.Density`, and the build option `{ Vegetation = false }`.
- **Roads:** centre, edge and stop lines on the road pieces; marker posts, guard rails, street lights, power lines; town, facility, speed, stop, direction and welcome signs (81). Farms: fences and 10 tobacco barns.
- **Light:** afternoon sun, atmosphere, bloom, sun rays and colour correction in `default.project.json`; terrain colours, water, animated grass and clouds set by `BuildMap`.
- **New modules:** `Map/Hash`, `Map/Lakes`, `Map/Biomes`, `Map/Fields`, `Map/Vegetation`, `Map/RoadDetails` (pure, offline-tested); builders `Environment`, `RoadDetails`, `Signs`, `Countryside`, `Vegetation`.
- **Tests that ran (cloud session):** `python3 tests/map/test_all.py` — 456 layout and terrain checks, the 16 plots match the bot, 61 new landscape checks (cascades only drop, pools voxel-aligned, river never narrows; lakes hold water below their shore and fade into the land, at least 20 studs from roads; fields off roads, water and places; markings inside and on the road surface; posts, signs, lights and poles beside the road on dry ground; a stop sign at every junction and a town sign on every road into a city; trees off roads, water, fields, places and power lines, below the tree line; repeatable), and 44 checks of the real `BuildMap` against the Roblox stand-in (37,281 parts inside the map, under the 45,000 budget; rerun without duplicates). `rojo build` OK (Lighting effects present); StyLua, selene and luau-lsp (strict) with 0 findings. Preview re-rendered.
- **Not tested yet:** anything in Roblox Studio (how the landscape looks, real build time, frame rate with about 37,000 parts and streaming).
- **Studio build (Justin, 2026-10-26):** `BuildMap.run()` finished with `Done in 34 s`; the Output matched the expected lines (16 roads, 5 bridges, 1,430 marking parts, 81 signs, 8,207 trees, 4,109 bushes, 2,687 rocks). Studio refused to switch on animated grass (`Could not switch on animated grass`), so `Terrain.Decoration` is ticked by hand (A23). The full walk-through of [testing/m2-map-checklist.md](testing/m2-map-checklist.md) was not reported; Justin sent screenshots that led to the next two revisions.

**Revision 3 — highland environment, `highland-4` (Codex, 2026-10-26 to 2026-10-27).** Pull requests #13 and #14 and three direct commits on the default branch. Details: [06-environment-overhaul.md](06-environment-overhaul.md).

- **Weather and day/night:** `EnvironmentService` (one weather schedule per server, only small attributes replicate, no remotes), client `EnvironmentController`, `WeatherEffects` (camera-local rain, lightning) and `EnvironmentQualityController` (Weather menu: Automatic, Minimal, Low, Medium, High for the session); `Config/Environment` (60-minute day, five weather profiles); shared `Environment/Model` and `Environment/Presentation`.
- **Landscape:** native CSG tree crowns (`CanopyLibrary`), terrain relief and soil refinement (`LandscapeConfig`), roadside drainage, bridge foundations and furniture grounded on the saved terrain.
- **Saved places:** `BuildMap.upgradeEnvironment()` patches only terrain columns that still match the earlier generator (`OriginalSurface`, `TerrainUpgrade`, `ExistingTerrain`); `refreshEnvironment()` replaces generated geometry; `StudioTools.CheckEnvironment` reports the saved state.
- **Audio:** original rain and thunder WAVs in `assets/audio/` (CC0); silent until uploaded (B7).

**Revision 4 — Kagundali junction benchmark (Codex, 2026-10-28).** Three direct commits on the default branch. Details: [07-kagundali-junction.md](07-kagundali-junction.md), [08-kagundali-screenshot-fixes.md](08-kagundali-screenshot-fixes.md), [09-creator-store-assets.md](09-creator-store-assets.md).

- A bounded art benchmark at the R3/N5 junction (X 64–832, Z 2944–3648): own tree, bush and fern templates, a transport workshop, gravel shoulders, drainage, restored markings and larger direction signs; neutral lighting shared by the Rojo preset and the weather model.
- `UpgradeKagundali()` applies it to a saved place; `UseCreatorStoreAssets()` imports trees and lamps from Roblox's own Forest Pack and City Props Pack (creator check before loading, scripts stripped) and then runs the update.
- Justin applied junction-2 in Studio on 2026-10-28 (64 trees, 49 bushes, 47 ferns, workshop present); junction-3 and the pack import are not tested in Studio yet.

**Clean-up (Claude, 2026-10-28).** Weather menu text in English (A8), luau-lsp (strict) back to 0 findings (42 type errors in the new modules fixed without behaviour changes), docs 07–09 translated to English, this tracker, [FILE-INVENTORY.md](FILE-INVENTORY.md) and [04](04-assumptions-and-blockers.md) brought up to date.

- **Tests that ran (cloud session, default branch after the clean-up):** `python3 tests/map/test_all.py` (1,513 Luau checks and the property match with the bot, 39,643 parts under `Workspace.Map`) and `python3 tests/environment/run.py` (86 checks) all pass; StyLua, luau-lsp (strict) with 0 findings, `rojo build` OK.
- **Not tested yet:** the environment, the junction benchmark and the pack import in Roblox Studio; frame rate with about 39,600 parts.

**Closed (2026-10-28).** Justin moved on to Milestone 3 and handed the terrain to Codex: from now on Codex works on terrain and Claude on the milestones, never at the same time (B8). Open Studio checks of revisions 3 and 4 stay with that terrain work.

### Milestone 3 — Gundiville government district (2026-10-28)

Pushed directly to the default branch `claude/project-thread-5krwdh` (Justin's instruction, no pull request). Details and numbers: [02-map-plan.md](02-map-plan.md), section 14; preview: [gundiville-district-preview.jpg](gundiville-district-preview.jpg).

- **Single source:** `src/shared/Config/GovernmentDistrict.luau` holds the streets, square, the four buildings, the residence layout, the statue (user, position, size, finish, inscription) and the part budget (7,000). Footprints are those of the map plan and the Milestone 2 placeholders.
- **Builders:** `src/studio/BuildGundiville.luau` (commands `run()`, `statue({ Finish = … })`, `focus()`, `remove()`; one undo step each; refuses to replace a folder it did not build) and `src/studio/Gundiville/` — `Kit` (walls with openings, windows with shutters, columns, pediments, roofs, dome, flags with mirrored backs, emblem, inscriptions, lamps, trees, benches), `Streets`, `Square`, `Congress`, `Hausali`, `CentralBank`, `Residence`, `Statue`, `District`.
- **Built:** six streets with sidewalks, centre lines, zebra crossings, the avenue median with trees and double lights; the square with 16 market stalls and six flags; the General People's Congress (113 studs, dome, walkable hall and chamber with 50 seats); the Hausali (walkable lobby, speaker's balcony, garden); the Central Bank (walkable banking hall, no money functions); the Leader's residence (walls, guard posts, barrier, villa with walkable hall and office, gardens); the statue of Dr. Justin Wachmann from the Owner's avatar, 30 studs, facing the Congress, with plaques and floodlights. 26 flags and 10 emblems. 3,341 parts (3,274 with the Roblox packs).
- **Store assets:** if `ServerStorage.RoNationCreatorAssets` exists (Roblox's Forest Pack and City Props Pack, imported by `Map.CreatorAssets`), the district uses those trees and street lamps; otherwise its own. The Creator Store cannot be searched from the cloud session, so no further store models were picked.
- **Map builder:** `BuildMap` keeps `Workspace.Map.GovernmentDistrict` and skips the placeholders it replaces; terrain tools do not touch it.
- **Tests that ran (cloud session):** `python3 tests/map/test_all.py` — all specs pass (1,690 Luau checks, including 177 new district checks: footprints and streets match the plan, part budget, everything anchored, Congress tallest, flags and emblems on every government building, mirrored flag backs, readable inscriptions, seats, lamps wired for the night switch, walkable entrances and rooms (collision probes), no building part on a carriageway, statue height, pedestal, north facing and collider, the three finishes, stand-in when the avatar cannot load, `Workspace.StatueSource`, rerun without duplicates, `remove()`, store-asset variant, foreign folder refused); `BuildMap` against the stand-in still passes (39,643 parts). `rojo build` OK; StyLua and luau-lsp (strict) with 0 findings; selene with 0 findings in the new code (its offline Roblox definitions lack `Random` and `UserSettings`, which three weather scripts use). Six views rendered with an offline renderer and checked visually.
- **Not tested yet:** anything in Roblox Studio: loading the avatar with `Players:CreateHumanoidModelFromUserId` in edit mode (A29), the mirrored flag backs (A30), how the buildings look with Roblox lighting, walking through the doors, frame rate. Justin's checklist: [testing/m3-district-checklist.md](testing/m3-district-checklist.md).
- **Deviations from the preview:** none in scope. Additions: street names (P28, proposal), the Hausali directory text (P29), gate open and barrier raised until Milestone 6 (P30). Decision D3 (statue finish) is made after Justin compares the finishes in Studio.
- **Revision 1 (2026-10-28, after Justin's first Studio build):** the statue is gold and much bigger (body 50 studs on a 20-stud pedestal; D3 decided, P5, P6); the builder poses the avatar from its joints and fits accessories to the body attachments, because edit mode does not (A29); the district measures the saved terrain and stands on it, with footings and ramps to N4 and N5 (A33, new module `Gundiville/Ground.luau`). District spec: 189 checks.

## Milestone 4 plan (preview)

Details are fixed when the milestone starts. Sources: the table above, [01-architecture.md](01-architecture.md), sections 3 and 7, and [05-economy-integration.md](05-economy-integration.md).

1. Spawning and new-player arrival at the Gundiville bus terminal; navigation help.
2. One working vehicle.
3. Bank interface in the Central Bank, connected to the bot through the existing bridge (balances, linking, transfers within the bot's rules).
4. One civilian job with a shift (`clockIn` through the bot) and one property interaction.
5. Non-financial Roblox player profiles (session-locked DataStore).

Prerequisite: the bot is reachable over HTTPS for live tests (B4).

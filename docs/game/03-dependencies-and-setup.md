# 03 · Dependencies and Manual Setup

Status: updated in Milestone 1, 2026-10-26, milestone numbers from the integration-aware plan (0–9) in [MILESTONES.md](MILESTONES.md). "Needed by" is the first milestone that cannot be finished without the item.

## 1. Steps only Justin can do

| # | Step | Where | Needed by | Why |
|---|---|---|---|---|
| 1 | **Decided: the experience is owned by the group "Democratic Republic of Kagundi" (ID 60169080).** Publish it under the group before any data is saved. **Published 2026-10-26** (experience/universe ID `10773079581`, stored in `GameConfig.UniverseId`). The Studio check `CheckSetup` confirms the group owner. | Studio: *File → Publish to Roblox As…*, choose the group as creator | Milestone 1 | The security settings in steps 4–6 need a published experience. Saved data belongs to one experience; moving later leaves it behind. A group-owned game also lets staff help without sharing Justin's account. |
| 2 | Upload the flag and the emblem as images, owned by the same creator as the game (the group if step 1 = group). Send Claude the two asset IDs. **Done 2026-10-26.** Image IDs (checked in Studio): flag `74627674981379`, emblem `124794973631384`. The IDs first sent were the decals, and in swapped order (decal `88703156887446` = flag, `104179974183727` = emblem). | Studio: *Asset Manager → Import*, or Creator Dashboard → Development Items → Decals | Milestone 1 (check in Studio), 3 (flags, seals), 8 (UI logo) | Images must be on Roblox to show in game. Using the same owner avoids permission problems. |
| 3 | Set the game icon (emblem) and thumbnails. | Creator Dashboard → the experience → Places/Icons | Before public testing | Branding |
| 4 | Turn on **Enable Studio Access to API Services**. | Studio: *File → Experience Settings → Security* (called *Game Settings* in older Studio versions) | Milestone 1 | DataStores in Studio tests (pending economy operations in Milestone 1, profiles in Milestone 4) |
| 5 | Turn on **Allow HTTP Requests**. | Studio: *File → Experience Settings → Security* | Milestone 1 | The game server talks to the economy bot |
| 6 | Store the bridge API key in Roblox's secrets store under the name `RoNationBridgeKey` (never in a script, never in Git, never in chat). Staging and live get different keys. For Milestone 1 only the **staging** key goes into Studio's *Local Secrets*. | Studio: *File → Experience Settings → Security → Local Secrets* (staging). Live servers later: Creator Dashboard → the experience → Secrets | Milestone 1 (staging key) | Keeps the key away from clients, the repository and logs |
| 7 | Set server size to **25 players**. | Creator Dashboard → Places → Server size | Before public testing | Target population 20–25 |
| 8 | Run the builder scripts when a milestone asks for it, then **publish/save the place** and keep a `.rbxl` backup outside Git. | Studio command bar (instructions come with each milestone) | Milestones 2, 3, 5 | Terrain and buildings live in the place file |
| 9 | Host the economy bot 24/7 with a public HTTPS address (small VPS plus a domain or a tunnel), and finish any remaining steps from `discord/docs/07-setup-guide.md`. Justin confirmed 24/7 hosting is coming (2026-10-26). | Outside Roblox | Milestone 1 only if Studio refuses `http://localhost`; otherwise Milestone 4 at the latest (first live server test) | Roblox servers can only reach the bot over the internet |
| 10 | Merge the two Milestone 1 pull requests (game and bot bridge; bot changes approved in D4 on 2026-10-26), then run [testing/m1-staging-checklist.md](testing/m1-staging-checklist.md) in Studio with `npm run bridge-staging`. Merging changes no running bot; deploying to the live bot is a separate go. | GitHub Desktop, Studio, a terminal in `discord/bot` | Milestone 1 | The bot is the only economy; nothing changes there without review |
| 11 | Optional: enable Team Create if other people will build in Studio. | Studio: *File → Collaboration* (or Home → Team Create) | Any time | Several builders; scripts still come from Git through Rojo |

## 2. Developer tools

| Tool | Version | Status | Purpose |
|---|---|---|---|
| Rokit | — | Installed on Justin's PC | Installs the pinned tools |
| Rojo | 7.7.1 | Installed on Justin's PC; verified here | File → Studio sync, project builds |
| GitHub Desktop | — | Installed on Justin's PC | Pull Claude's changes |
| VS Code + Luau Language Server | — | Recommended | Errors while typing |
| StyLua | 2.6.0 | Pinned in `rokit.toml` (Milestone 1); settings in `stylua.toml` | Formatting: `stylua src` |
| selene | 0.28.0 | Pinned in `rokit.toml` (Milestone 1); settings in `selene.toml` (`std = "roblox"`) | Linting: `selene src` |
| Lune | — | Not pinned yet; there are no pure-module tests yet | Unit tests of pure modules, when needed |

The Milestone 1 code was checked in the cloud session with StyLua 2.6.0, selene 0.31.0 (built from crates.io; same rules, newer than the pinned Windows build) and luau-lsp 1.70.1 in strict analysis with Roblox type definitions and a Rojo sourcemap: 0 findings each. These cloud checks do not replace a Studio test.
| Node.js 22.13+ | — | Needed for the economy bot | Bot and bridge |

## 3. Roblox engine features the plan relies on

All are standard, first-party Roblox features. Each is verified against the current documentation in the milestone that first uses it.

| Feature | Used for | Milestone |
|---|---|---|
| Rojo project `$properties` on services | Workspace streaming and lighting settings from Git | 1 |
| `RemoteEvent` / `RemoteFunction` | Client requests | 1 |
| CollectionService tags, Attributes | Finding gameplay objects in the map | 1 |
| Terrain API (`FillBlock`, `FillWedge`, `FillBall`, `WriteVoxels`) | Terrain builder | 2 |
| Instance streaming (`StreamingEnabled`, `ModelStreamingMode`) | Large map performance | 2 |
| `Players:GetHumanoidDescriptionFromUserId`, `Players:CreateHumanoidModelFromDescription`, `Model:ScaleTo` | Statue of the Leader | 3 |
| DataStoreService (with session locking) | Pending economy operations (1), non-financial player profiles and records (4) | 1, 4 |
| ProximityPrompt | Interactions | 4–8 |
| HttpService (`RequestAsync`, `GetSecret`) | Economy bridge | 1 |
| PhysicsService collision groups, constraints | Vehicles, cells | 4, 6 |
| TextChatService | Radio/department chat if needed | 6 |

## 4. Third-party code (proposed, each needs a license check before it is added)

| Package | Use | Decision point |
|---|---|---|
| ProfileStore (loleris) | Session-locked, non-financial player profiles | Milestone 4; alternative: small own implementation |
| A vehicle chassis (community chassis or own constraint-based chassis) | Cars, trucks, emergency vehicles | Milestone 4 |

No package manager (Wally) is planned; vendored single files keep the setup simple for Justin.

## 5. External systems

| System | State | Needed for |
|---|---|---|
| Ro-Nation Economy Bot (`discord/bot`) | Discord server built; bot runs on Justin's PC while a terminal is open (pm2 setup merged in PR #5); no 24/7 host. With the Milestone 1 bot pull request: 89/89 tests pass | Every money feature in game; the only economy |
| Economy Bridge (HTTP API inside the bot) | Built in Milestone 1 (bot pull request), **off by default**, not deployed; staging with `npm run bridge-staging`; see [05-economy-integration.md](05-economy-integration.md), section 4 | Game ↔ economy link |
| Discord ↔ Roblox account link | Built in Milestone 1 (`/link`, bot pull request), not deployed; see [05](05-economy-integration.md), section 4.3 | Knowing which Discord citizen a Roblox player is |
| Public HTTPS hosting | Not set up | Bridge reachable from Roblox servers |

# 03 · Dependencies and Manual Setup

Status: Milestone 0, 2026-10-26. "Needed by" is the first milestone that cannot be finished without the item.

## 1. Steps only Justin can do

| # | Step | Where | Needed by | Why |
|---|---|---|---|---|
| 1 | **Decide who owns the experience: Justin's account or the group "Democratic Republic of Kagundi" (ID 60169080).** Recommended: the group. | Studio: *File → Publish to Roblox As…*, choose the group as creator | Before Milestone 6 | Saved player data belongs to one experience. Moving to another experience later leaves all saved data behind. A group-owned game also lets staff help without sharing Justin's account. |
| 2 | Upload the flag and the emblem as images, owned by the same creator as the game (the group if step 1 = group). Send Claude the two asset IDs. | Studio: *Asset Manager → Import*, or Creator Dashboard → Development Items → Decals | Milestone 3 (flags, seals); Milestone 12 (UI logo) | Images must be on Roblox to show in game. Using the same owner avoids permission problems. |
| 3 | Set the game icon (emblem) and thumbnails. | Creator Dashboard → the experience → Places/Icons | Before public testing | Branding |
| 4 | Turn on **Enable Studio Access to API Services**. | Studio: *Game Settings → Security* | Milestone 6 | DataStores in Studio tests |
| 5 | Turn on **Allow HTTP Requests**. | Studio: *Game Settings → Security* | Economy bridge (Milestone 6/7 if pulled forward, otherwise 13) | The game server talks to the economy bot |
| 6 | Store the bridge API key in Roblox's secrets store (never in a script). | Creator Dashboard → the experience → Secrets (*verify the exact location in Milestone 13*) | Economy bridge | Keeps the key away from clients and from Git |
| 7 | Set server size to **25 players**. | Creator Dashboard → Places → Server size | Before public testing | Target population 20–25 |
| 8 | Run the builder scripts when a milestone asks for it, then **publish/save the place** and keep a `.rbxl` backup outside Git. | Studio command bar (instructions come with each milestone) | Milestones 2–5 | Terrain and buildings live in the place file |
| 9 | Host the economy bot 24/7 with a public HTTPS address (small VPS plus a domain or a tunnel), and finish any remaining steps from `discord/docs/07-setup-guide.md`. | Outside Roblox | Economy bridge | Roblox servers can only reach the bot over the internet |
| 10 | Optional: enable Team Create if other people will build in Studio. | Studio: *File → Collaboration* (or Home → Team Create) | Any time | Several builders; scripts still come from Git through Rojo |

## 2. Developer tools

| Tool | Version | Status | Purpose |
|---|---|---|---|
| Rokit | — | Installed on Justin's PC | Installs the pinned tools |
| Rojo | 7.7.1 | Installed on Justin's PC; verified here | File → Studio sync, project builds |
| GitHub Desktop | — | Installed on Justin's PC | Pull Claude's changes |
| VS Code + Luau Language Server | — | Recommended | Errors while typing |
| StyLua, selene, Lune | to be pinned in Milestone 1 | Proposed | Formatting, linting, unit tests of pure modules |
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
| DataStoreService (with session locking) | Player profiles, records | 6 |
| ProximityPrompt | Interactions | 6–11 |
| HttpService (`RequestAsync`, secrets) | Economy bridge | 6/7 or 13 |
| PhysicsService collision groups, constraints | Vehicles, cells | 8, 11 |
| TextChatService | Radio/department chat if needed | 8–10 |

## 4. Third-party code (proposed, each needs a license check before it is added)

| Package | Use | Decision point |
|---|---|---|
| ProfileStore (loleris) | Session-locked player profiles | Milestone 6; alternative: small own implementation |
| A vehicle chassis (community chassis or own constraint-based chassis) | Cars, trucks, emergency vehicles | Milestone 11 |

No package manager (Wally) is planned; vendored single files keep the setup simple for Justin.

## 5. External systems

| System | State | Needed for |
|---|---|---|
| Ro-Nation Economy Bot (`discord/bot`) | Discord server built; bot runs on Justin's PC while a terminal is open; no 24/7 host | Every money feature in game |
| Economy Bridge (HTTP API inside the bot) | Not built | Game ↔ economy link |
| Discord ↔ Roblox account link | Not built | Knowing which Discord citizen a Roblox player is |
| Public HTTPS hosting | Not set up | Bridge reachable from Roblox servers |

# Project File Inventory

Every file and folder of the project, what it is for and which milestone owns it. Updated at the end of every milestone.

Last update: 2026-10-26 (Milestone 1).

## Repository root

| Path | Purpose | Owner milestone | Status |
|---|---|---|---|
| `README.md` | German guide for Justin: Rojo, GitHub Desktop, daily workflow | Setup | Keep; links to `docs/game/` |
| `default.project.json` | Rojo tree (files → Studio): project name *Ro-Nation*, `src/studio` → `ServerStorage.StudioTools`, streaming on, `Lighting.ClockTime` 14 | 1 | Updated in Milestone 1 |
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

Planned folders: `src/server/{Persistence,Economy,Packages}` (Milestone 4), `src/client/UI` (Milestone 4/8), builders in `src/studio/` (Milestone 2), `tests/` (Lune unit tests, when needed). See [01-architecture.md](01-architecture.md), section 3.

## Game documentation (`docs/game/`)

| File | Content |
|---|---|
| `README.md` | Index of the game documentation |
| `00-audit.md` | Milestone 0 audit: environment, repository, lore, assets, avatar, group, economy |
| `testing/m1-staging-checklist.md` | Milestone 1 Studio test against the staging bridge |
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
| `game/reference/owner-avatar-2595858454.jpg` | Justin's avatar screenshot, visual reference for the statue |

## Roblox (outside Git)

| Item | Where | Status |
|---|---|---|
| Place file (terrain, buildings, statue) | Roblox, edited in Studio | Fresh Baseplate (confirmed) |
| Experience | Universe ID 10773079581, group 60169080 | Published 2026-10-26 (D2) |
| Local Secret `RoNationBridgeKey` | Studio, Experience Settings → Security → Local Secrets | Set by Justin during the Milestone 1 Studio test (staging key only) |
| Flag and emblem images | Roblox asset library (group) | Image IDs: flag `74627674981379`, emblem `124794973631384` (decals `88703156887446` and `104179974183727`) |
| Group "Democratic Republic of Kagundi" | roblox.com, ID 60169080 | Exists, owned by LiterallyDrJustin |

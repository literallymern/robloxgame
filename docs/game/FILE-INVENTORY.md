# Project File Inventory

Every file and folder of the project, what it is for and which milestone owns it. Updated at the end of every milestone.

Last update: 2026-10-26 (Milestone 0).

## Repository root

| Path | Purpose | Owner milestone | Status |
|---|---|---|---|
| `README.md` | German guide for Justin: Rojo, GitHub Desktop, daily workflow | Setup | Keep; links to `docs/game/` |
| `default.project.json` | Rojo tree (files → Studio) | 1 | Keep; extended in Milestone 1 |
| `rokit.toml` | Pinned tools (Rojo 7.7.1) | 1 | Keep; dev tools added in Milestone 1 |
| `.gitignore` | Ignores place files and system files | — | Keep |

## Game code (`src/`, synced by Rojo)

| Path | Studio location | Purpose | Status |
|---|---|---|---|
| `src/shared/Begruessung.luau` | `ReplicatedStorage.Shared.Begruessung` | Rojo test module | Replaced in Milestone 1 |
| `src/server/Start.server.luau` | `ServerScriptService.Server.Start` | Rojo test script (server) | Replaced in Milestone 1 |
| `src/client/Start.client.luau` | `StarterPlayer.StarterPlayerScripts.Client.Start` | Rojo test script (client) | Replaced in Milestone 1 |

Planned folders (Milestone 1 onwards): `src/shared/{Config,Types,Net,Util}`, `src/server/{Services,Persistence,Economy,Packages}`, `src/client/{Controllers,UI}`, `src/studio/` (builders), `tests/` (Lune unit tests). See [01-architecture.md](01-architecture.md), section 3.

## Game documentation (`docs/game/`)

| File | Content |
|---|---|
| `README.md` | Index of the game documentation |
| `00-audit.md` | Milestone 0 audit: environment, repository, lore, assets, avatar, group, economy |
| `01-architecture.md` | Architecture, hierarchy, services, security, sources of truth, persistence, streaming, testing |
| `02-map-plan.md` | Map size, coordinates, footprints, roads, Gundiville district |
| `03-dependencies-and-setup.md` | Manual steps for Justin, tools, engine features, third-party code, external systems |
| `04-assumptions-and-blockers.md` | Assumptions, non-canon proposals, open decisions, blockers |
| `MILESTONES.md` | Milestone tracker and log |
| `FILE-INVENTORY.md` | This file |
| `map-plan.svg` | Overview map of the East District (generated plan image) |
| `gundiville-plan.svg` | Plan of the Gundiville government district |

## Discord package (`discord/`, from PR #2)

| Path | Files | Purpose |
|---|---|---|
| `discord/README.md` | 1 | Overview of the Discord package |
| `discord/docs/` | 11 | Server blueprint, roles, permissions, messages, bots, economy design, setup guide, checklist, QA report, summary, command reference |
| `discord/messages/` | 24 | Ready-to-post channel texts |
| `discord/assets/` | 2 | Flag and emblem PNGs |
| `discord/bot/src/economy/` | 26 | Economic simulation (ledger, citizens, businesses, employment, market, credit, AVK, property, fines, invoices, treasury, policy, events, daily tick, report) |
| `discord/bot/src/discord/` | 11 | Slash commands, buttons, tickets, permissions |
| `discord/bot/src/blueprint/`, `src/setup/`, `src/db/` | 7 | Roles/channels source of truth, setup planner, SQLite schema |
| `discord/bot/src/index.js`, `src/config.js` | 2 | Bot entry point and configuration |
| `discord/bot/scripts/` | 5 | setup-server, deploy-commands, post-messages, simulate, generate-docs |
| `discord/bot/test/` | 9 | Automated tests |
| `discord/bot/package.json`, `package-lock.json`, `.env.example`, `.gitignore` | 4 | Node project files (no secrets in Git) |

The Economy Bridge for the game will be added inside `discord/bot/src/` (planned as `src/bridge/`).

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
| `rojo/Rojo-Anleitung.md` | German Rojo guide (copy of the README section) |
| `game/milestone-0/map-plan.png`, `gundiville-plan.png` | Rendered map plans from Milestone 0 |
| `game/reference/owner-avatar-2595858454.jpg` | Justin's avatar screenshot, visual reference for the statue |

## Roblox (outside Git)

| Item | Where | Status |
|---|---|---|
| Place file (terrain, buildings, statue) | Roblox, edited in Studio | Fresh Baseplate (confirmed) |
| Experience owner | Group 60169080 | Decided (D2) |
| Flag and emblem images | Roblox asset library (group) | Being uploaded by Justin; IDs pending |
| Group "Democratic Republic of Kagundi" | roblox.com, ID 60169080 | Exists, owned by LiterallyDrJustin |

# 00 · Project Audit (Milestone 0)

Audit date: 2026-10-26, extended the same day after Justin's architecture update (the economy bot is the only economy). Everything below was checked in this session unless it is marked as an assumption. The detailed bot audit and the system boundaries are in [05-economy-integration.md](05-economy-integration.md).

## 1. Development environment

| Capability | Available? | What was checked |
|---|---|---|
| Direct Roblox Studio access for Claude | **No** | Claude runs in a Linux cloud container. Roblox Studio only runs on Windows and macOS, so Claude cannot open, edit, play or publish the place. |
| Writing Luau code | Yes | Through this Git repository. Justin pulls with GitHub Desktop and Rojo syncs the code into Studio. |
| Building the Rojo project | Yes | `rojo build default.project.json` with Rojo 7.7.1 (Linux release, same version as `rokit.toml`) succeeded and produced a place file. |
| Static analysis, lint, format, unit tests (luau-lsp, selene, StyLua, Lune) | Partly | The release files can be downloaded here, but running them was blocked by this session's safety check (downloaded programs). They can be added to `rokit.toml` for Justin's PC; running them here needs approval. |
| Roblox web APIs from Claude's environment | **No** | Requests to `avatar.roblox.com` and `users.roblox.com` were refused by the network policy. A public profile page could be read through the web reader. |
| Asset uploads (images, meshes) | No (Claude) | Needs Justin in Studio or the Creator Dashboard. |
| Testing inside Roblox (Play, Team Test, DataStores, physics) | Justin only | Each milestone will include a short Studio test checklist. |
| Economy bot tests | **Yes** | Node.js 22 is available here. The bot's test suite (`npm test`) ran on the default branch at commit `b8e905e`: 67 of 67 tests passed. |

**Consequence for the plan:** every Studio change is delivered as code. Map and buildings are made by builder scripts that Justin runs once in Studio and then saves into the place (see [01-architecture.md](01-architecture.md), section 2). Engine behaviour is tested by Justin with checklists; nothing is reported as tested in Roblox unless Justin ran it.

## 2. Repository

Default branch: `claude/project-thread-5krwdh`. Working branch for this milestone: `claude/project-thread-55jwuj`.

| Path | Content | Verdict |
|---|---|---|
| `default.project.json` | Rojo tree: `src/shared` → `ReplicatedStorage.Shared`, `src/server` → `ServerScriptService.Server`, `src/client` → `StarterPlayer.StarterPlayerScripts.Client` | **Keep.** Milestone 1 extends it (ServerStorage tools, service properties). |
| `rokit.toml` | Pins Rojo 7.7.1 | **Keep.** Milestone 1 adds dev tools. |
| `src/shared/Begruessung.luau`, `src/server/Start.server.luau`, `src/client/Start.client.luau` | German "Rojo works" test scripts | **Replace in Milestone 1** with the real entry points, keeping a startup message so Justin can still see that Rojo works. |
| `README.md` | German Rojo guide for Justin | **Keep**, add a link to these docs. |
| `discord/` | Discord server blueprint, channel texts, and the **Ro-Nation Economy Bot** (Node.js 22, discord.js 14, built-in SQLite; 67 tests) | **Keep and preserve.** The bot is the single authoritative economy: banking, jobs, businesses, loans, AVK, property, fines, treasury and the daily report. The game connects to it and never builds a second economy. Changes only as backward-compatible, reviewed pull requests ([05](05-economy-integration.md), section 8). |
| `lore/` | Not on the default branch yet. The Lore Bible and the flag and emblem images are in **PR #1** (open, not merged). | Merge PR #1 when convenient; the encyclopedia PDF stays the authority. |

Pull requests: #1 "Kagundi Lore Bible (Revision 2)" is open. #2 (Discord package), #3 (Discord bot fixes for Windows) and #5 (pm2 start on Windows) are merged into the default branch (head `b8e905e`); this branch includes them. #4 is this milestone.

## 3. Studio place

Claude cannot see the place file. From the Rojo setup and Justin's earlier tests:

- Known content: the three Rojo test scripts above.
- Apart from them, the place is a fresh Baseplate. **Confirmed by Justin** on 2026-10-26: nothing has been built yet.
- The experience runs under the group "Democratic Republic of Kagundi" (Justin's decision, 2026-10-26). See [03-dependencies-and-setup.md](03-dependencies-and-setup.md).

## 4. Lore sources read

| Source | Status |
|---|---|
| `Kagundi-Encyclopedia.pdf` (15 pages, 26 Oct 2026), project files `lore/` | Read in full. **Authoritative.** |
| `lore/Kagundi-Lore-Bible.md` (PR #1 branch) | Geography, cities, institutions, economy and technical sections read. No conflicts with the encyclopedia found for anything the game uses. |
| `discord/docs/` (role hierarchy, economy design, integrations) | Read. Defines the in-game factions, public-sector wages and the economy rules the game must respect. |
| `discord/docs/appendix-command-reference.md` | Read in full and compared with the source code ([05](05-economy-integration.md), section 2). |
| *Ro-Nation Kagundi City Development Reference Guide* (Justin, 26 Oct 2026, project files `lore/Ro-Nation_Kagundi_City_References.pdf`) | Read in full. Visual direction and required sites per city; illustrations are concept art, not canon. Its requirements are in [02-map-plan.md](02-map-plan.md). |

Canon facts the game depends on (no changes allowed without a proposal): Democratic Republic of Kagundi; Gundiville, Stokondo, Kagundali, Oberdueshuson, all in the East District; Hausali; General People's Congress; People's Councils; Leader of the Revolution Dr. Justin Wachmann (since 2021); Secretary-General of the People's Committee; the four secretariats; City Police, Gendarmerie, Land Forces, Air Force, Revolutionary Guard, Intelligence Service; mayors as first-instance judges ("Maista"), second instance in Stokondo, 72-hour appeal deadline, Military Tribunal; AVK; Brandwehr with the Crisis Response Center in Gundiville; Kagundi Dinar (KGD); cargo airport near the capital; border crossings with customs; economic day at 00:00 Europe/Berlin.

## 5. Visual assets

| Asset | Where | Size | Use |
|---|---|---|---|
| National flag | Project files `lore/kagundi-flag.png`; `discord/assets/kagundi-flag.png`; PR #1 `lore/images/` | 1438 × 855 PNG | Flags on buildings and poles, UI accents |
| National emblem (round, gold ring) = Ro-Nation logo | Project files `lore/kagundi-emblem.png`; `discord/assets/`; PR #1 | 1024 × 1024 PNG with transparency | Seal on government buildings, vehicles, uniforms, UI logo, game icon |

Both have to be uploaded to Roblox as images before they can be used in the game (Justin, see 03). Update 2026-10-26: Justin uploaded Roblox-sized versions (flag 1024 × 609, emblem 1024 × 1024): flag `104179974183727`, emblem `88703156887446`.

## 6. Statue avatar (Roblox user `2595858454`)

- The public profile exists: username **LiterallyDrJustin**, display name **Bustin** (read from the profile page).
- The Roblox avatar API is blocked from here by the network policy. Justin sent a screenshot of the current avatar on 2026-10-26, saved as the **visual reference** in project files `game/reference/owner-avatar-2595858454.jpg`. It shows a classic blocky body with light skin; messy dark-brown hair; round wire-rim glasses; a face with stubble beard and a smirk; a navy pinstripe double-breasted suit with gold buttons, white shirt and a red/orange/brown striped tie (2D clothing); dark shoes. Whether the rig is R6 or R15 cannot be told from the screenshot; the builder reads it from the avatar data. The statue is checked against this reference in Milestone 3.
- Planned method (Milestone 3): Roblox's own engine functions `Players:GetHumanoidDescriptionFromUserId` and `Players:CreateHumanoidModelFromDescription`, run by a builder script in Studio. The result is converted into a static, anchored model, scaled with `Model:ScaleTo` and saved in the place. Before relying on this, Milestone 3 verifies that these functions behave as expected in the current Studio version.
- Fallback if the automatic method fails: Justin loads his avatar in a Play session, copies the character model, stops, pastes it into the place, and the same builder converts it into the statue. If that also fails, the blocker is reported; no generic figure is substituted.

## 7. Roblox group

The shared link `https://www.roblox.com/share/g/60169080` leads to the group **Democratic Republic of Kagundi** (group ID 60169080, owner LiterallyDrJustin, 1 member at the time of the audit). Recommended as the owner of the published experience and its assets (see 03).

## 8. Economy and Discord

The economy bot is the existing and only economic system: double-entry ledger in KGD minor units, idempotency keys, one daily tick at 00:00 Europe/Berlin, starting grant, wages, taxes, businesses, loans with credit scores 300–850, AVK, property, fines, invoices and the national report in `#national-economic-report`. Citizens are identified by **Discord user ID**. State on 2026-10-26: Justin has built the Discord server with the setup script and the bot runs on his PC while a terminal is open; the Windows fixes (PR #3, #5) are merged. There is **no 24/7 hosting** yet, **no HTTP interface** and **no Discord ↔ Roblox link**. Linking it to the game needs (a) a Discord ↔ Roblox account link, (b) an authenticated HTTPS bridge inside the bot and (c) 24/7 hosting with a public HTTPS address.

Findings from the source audit (details and file references in [05](05-economy-integration.md), section 2):

- The rules the architecture update requires exist in the bot: one paid shift per economic day, at most 2 businesses per owner, dual approval for treasury spending above 25,000 KGD (self-approval refused), one starting grant per citizen.
- The starting grant is paid on a citizen's **first economy command**, not on the verification button, and only to Discord accounts at least 14 days old. A Roblox login must never trigger it.
- No automated test covers "second shift refused" or "third business refused" yet; Milestone 1 adds them.
- `/bank pay` (`citizenPay`) has no idempotency key; the bridge needs an optional one (backward-compatible).

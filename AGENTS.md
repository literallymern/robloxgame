# Rules for AI agents working on Ro-Nation

Several AI agents work on this game for the owner, Justin: Claude, Codex and possibly an assistant in Visual Studio Code. They share this repository and one Roblox Studio place, and all of them can reach Studio through the Roblox Studio MCP server. These rules keep them out of each other's way. Read them before you start.

## Who does what

- **Claude:** the milestones in `docs/game/MILESTONES.md`, buildings, interiors, interior lighting, interaction components and gameplay.
- **Codex:** terrain, vegetation, highways and roads, global lighting, weather, day and night, environment effects and dynamic flags.
- Stay in your area unless Justin asks otherwise. Claude owns `src/studio/Gundiville/`, `src/studio/Architecture/`, `src/server/Main.server.luau`, `tests/map/roblox-mock.luau`, `tests/map/gundiville.spec.luau` and `tests/map/run.py`. Codex does not run `BuildGundiville` and puts no terrain into the government district.

## One agent at a time

- Only one agent works at a time, in the repository and in Studio. Justin decides whose turn it is. Being connected to Studio is fine; acting in Studio without a task from Justin is not.
- Before you start, pull the latest default branch `claude/project-thread-5krwdh`. Another agent may have pushed since your last session.
- When you finish, commit and push, and tell Justin in German what changed and whether he needs to save the place in Studio. Then the next agent can start.

## Git

- Work directly on the default branch `claude/project-thread-5krwdh`. No extra branches or pull requests unless Justin asks.
- If a push is rejected, rebase onto the latest default branch and push again. Never force-push.
- Before you push code, run `stylua src` and `selene src`, and the offline map tests `python3 tests/map/test_all.py --quick` if the `luau` command line tool is installed.
- When you add files, update `docs/game/FILE-INVENTORY.md`, and `docs/game/MILESTONES.md` where it applies.

## Roblox Studio MCP

- Rojo syncs one way, from `src/` into Studio. These Studio folders come from Rojo and are overwritten on every sync:
  - `ServerScriptService.Server` (`src/server`)
  - `StarterPlayer.StarterPlayerScripts.Client` (`src/client`)
  - `ReplicatedStorage.Shared` (`src/shared`)
  - `ServerStorage.StudioTools` (`src/studio`)
- Never edit scripts in those folders through MCP (`multi_edit`, or `execute_luau` that writes `Source`). Change the files in `src/` and let Rojo sync them.
- Use MCP to:
  - look: `search_game_tree`, `inspect_instance`, `screen_capture`
  - run the existing Studio tools, for example `require(game.ServerStorage.StudioTools.BuildGundiville).run()`
  - playtest: `start_stop_play`, `get_console_output`, character and input simulation
- Call `list_roblox_studios` first and target the Ro-Nation place.
- Map changes made in Studio (terrain, buildings) live only in the place file, not in Git. Tell Justin to save or publish the place when you are done.
- Before a large change through MCP, ask Justin to save a backup copy (File > Save to File As).
- Never claim a Studio test or import that did not happen.

## Assets

- Official Roblox assets (creator ID 1) are fine. Check the actual creator, not the title.
- Third-party Creator Store assets and anything paid need Justin's approval first. This includes `search_asset` and `insert_asset` through MCP.
- Never invent asset IDs. Never keep scripts from Store models without reviewing them.

## Language

- Talk to Justin in German. He is new to Roblox development, so keep steps simple.
- Code, repository docs and in-game text are in English (the game's community is English-speaking).

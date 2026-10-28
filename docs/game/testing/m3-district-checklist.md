# Milestone 3 · Studio District Checklist

Run by Justin in Roblox Studio on his PC. Claude cannot run this test (no Studio access). A German step-by-step version is in the project files (`game/milestone-3/Studio-Test-Meilenstein-3.md`), together with the preview image.

This checklist covers the Gundiville government district (district version `district-1`, [02-map-plan.md](../02-map-plan.md), section 14). It does not touch terrain; terrain work stays with Codex.

Result of the last run: **not run yet.**

## What was tested before this checklist (cloud session, not Studio)

- `python3 tests/map/test_all.py`: all specs pass, among them 177 checks of the district build against a stand-in for the Roblox API:
  - plan: footprints of the map plan, streets connect to N4 and N5, buildings stay off the carriageways, part budget (3,341 of 7,000);
  - buildings: everything anchored, Congress the tallest (113 studs), flags and emblems on every government building, flag backs mirrored, inscriptions present, 89 seats (50 in the chamber), lamps wired for the night switch;
  - walkability: collision probes at the entrances and in the Congress hall and chamber, the Hausali lobby, the banking hall and the residence hall and office;
  - statue: 30 studs, on the pedestal, facing north, centred, no scripts left, one invisible collider; the three finishes; stone stand-in when the avatar cannot load; `Workspace.StatueSource` used when present;
  - reruns replace the district without duplicates; `remove()` restores the placeholders; a folder not built by the tool is refused; with the Roblox packs the district uses their trees and lamps.
- `BuildMap` against the stand-in still passes (39,643 parts; it keeps the district folder).
- `rojo build` OK; StyLua and luau-lsp (strict) with 0 findings; selene with 0 findings in the new code.
- Six views rendered with a simple offline renderer ([preview](../gundiville-district-preview.jpg)). It shows shapes and colours only, not Roblox lighting, and the statue in it is a test figure.

## Before you start

- GitHub Desktop has pulled the default branch, `rojo serve` is running and the Rojo plugin is connected. Explorer shows `ServerStorage > StudioTools > BuildGundiville` and `StudioTools > Gundiville` (9 modules), and `ReplicatedStorage > Shared > Config > GovernmentDistrict`.
- **Back up the place first:** *File → Save to File As…* → `Ro-Nation-before-M3.rbxl` outside the Git folder.
- Codex is not working on the place at the same time.

## Steps and expected results

| # | Step | Expected result | Checks |
|---|---|---|---|
| 1 | *Optional, for Roblox's own trees and street lamps:* in **edit mode** run `require(game.ServerStorage.StudioTools.Map.CreatorAssets).install()` | Output: `[Ro-Nation:Assets] Forest Pack (6432306802): … templates selected.` and the same for the City Props Pack; `ServerStorage > RoNationCreatorAssets` exists. This only adds a folder to ServerStorage; it changes no terrain. If it prints an error, skip it: the district then uses its own trees and lamps | A27, store assets |
| 2 | In **edit mode** (Play stopped) with *View → Output* open, run `require(game.ServerStorage.StudioTools.BuildGundiville).run()` in the command bar | Output: `District version district-1. Building streets, square, buildings and the statue...`, `Removed 6 placeholder blocks that the district replaces.`, `Built … parts (CentralBank 406, Congress 756, Hausali 694, Residence 584, Square 279, Statue …, Streets 594).` (about 3,300–3,400; with step 1 slightly fewer), `Statue: avatar of user 2595858454, finish Original, figure 30.0 studs high.`, `Done in … s` | Builder runs in Studio |
| 3 | Look for yellow warnings with `[Ro-Nation:BuildGundiville]` | None. If the statue warning appears (`Statue avatar could not be loaded`), see *If something goes wrong* | A29 |
| 4 | The camera has moved over the square (or run `….BuildGundiville).focus()`). Fly around | The six grey placeholder blocks are gone. Square with stalls, the statue in the middle, the Congress with its green dome at the north end, the Hausali (red roof) east, the bank west, the residence behind walls to the north-east | Layout |
| 5 | Avenue south of the square | Two carriageways with dashed lines, a planted median with trees and double lamps, sidewalks with kerbs, zebra crossings, street name signs "Avenue du 12 Mai" at both ends. The avenue runs south into N5 without a step | Streets |
| 6 | Square | Light paving with granite bands, 8 stalls on each side with coloured awnings and goods, six flags in front of the Congress steps, lamps, benches, trees in the corners | Square |
| 7 | Statue | Your avatar, about 30 studs tall, with clothing and face, on a granite pedestal, **looking at the Congress**. Bronze plaques on the north and south face read "DR. JUSTIN WACHMANN / LEADER OF THE REVOLUTION / LEITER DER REVOLUTION · DI LAITA". Four floodlights on the platform corners | Statue (P4–P6) |
| 8 | Statue finish for decision D3: run `….BuildGundiville).statue({ Finish = "Bronze" })`, look, then `{ Finish = "Stone" }`, then back with `{ Finish = "Original" }` (or keep the one you like) | Only the statue is rebuilt each time; Output `Statue rebuilt: …, finish Bronze, …` | D3 |
| 9 | Congress outside | Wide steps up to a portico of eight columns, "GENERAL PEOPLE'S CONGRESS" and the emblem in the pediment, cream façade with three rows of windows, drum and dome with a flag on top. Tallest building of the district | Congress |
| 10 | Congress inside (walk in through the middle door) | Entrance hall with lights, then the chamber: red carpet, 47 seats in four rising rows facing the dais with three seats, the emblem and two flags behind it. Seats can be sat on in Play | Walkable rooms |
| 11 | Hausali | White building with ochre bands and green shutters, red tile roof, central part with the door, a balcony, "HAUSALI" and the emblem in the gable, flags. Inside: lobby with reception desk, directory board, benches, emblem and flags. Walled garden with a fountain behind (look over the wall) | Hausali |
| 12 | Central Bank | Granite ground floor, sandstone upper floor, six columns, "CENTRAL BANK" above them, emblem in the pediment. Inside: banking hall with a counter behind glass (five windows), sign "CENTRAL BANK / KAGUNDI DINAR · KGD", benches, the round vault door. No money functions yet (Milestone 4) | Bank |
| 13 | Residence: follow North Street east, behind the Congress, to the gate | Wall with pillars, open gate between two lit pillars, guard posts with "GUARD POST" signs, raised red-and-white barrier, name plaque "RESIDENCE OF THE LEADER OF THE REVOLUTION". Drive to a fountain, white villa with portico, balcony, emblem and flags; lawns, hedges, flowers, trees, a gazebo. Inside: hall and your office (desk, chair, visitor chairs, sofas, bookshelves, emblem, flags) | Residence (P30) |
| 14 | Look at any flag from behind | The flag reads correctly from both sides (the back is mirrored like real cloth). If the back is blank or wrong, note it | A30 |
| 15 | Press **Play**, walk from the bus terminal up the avenue to the square and into each walkable room | You can walk through every door listed above without getting stuck; the stalls, benches and statue block you, the doorways do not. Movement stays smooth | Walkability, A31 |
| 16 | Night: in Play switch the command bar to **Server** (Home tab: *Client/Server* button) and run `require(game.ServerScriptService.Server.Services.EnvironmentService).setClockTime(21)` | Street lamps, gate lanterns and the statue floodlights near you light up | Night lights |
| 17 | Stop Play. *File → Save to Roblox* (or Publish), then *File → Save to File As…* → `Ro-Nation-M3.rbxl` outside the Git folder | Place saved, backup exists | |

## If something goes wrong

- `BuildGundiville is not a valid member of StudioTools`: Rojo is not connected or GitHub Desktop has not pulled.
- `Stop Play first`: the command ran during Play. Stop Play and run it again.
- `Map.GovernmentDistrict was not built by this tool`: something else is called `GovernmentDistrict` under `Workspace.Map`. Rename or move it, then run again.
- **Statue warning** (`Statue avatar could not be loaded …`, a plain stone figure stands on the pedestal): insert your avatar by hand: start Play once, select your character under `Workspace` in the Explorer, copy it (Ctrl+C), stop Play, paste it into `Workspace` (Ctrl+V) and rename it to `StatueSource`. Then run `….BuildGundiville).statue()`. `StatueSource` is copied, not moved; you can delete it afterwards.
- Something looks wrong after the build: Ctrl+Z undoes the whole build in one step. `….BuildGundiville).remove()` removes the district and puts the placeholder blocks back.
- To go back completely: *File → Open from File* → `Ro-Nation-before-M3.rbxl`.

Send Claude the Output lines (copy and paste), which statue finish you want (step 8), and screenshots of the overview, the statue, each building and anything that looks wrong.

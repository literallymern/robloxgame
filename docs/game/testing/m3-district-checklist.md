# Milestone 3 · Studio District Checklist

Run by Justin in Roblox Studio on his PC. Claude cannot run this test (no Studio access). A German step-by-step version is in the project files (`game/milestone-3/Studio-Test-Meilenstein-3.md`), together with the preview image.

This checklist covers the Gundiville government district (district version `district-2`, [02-map-plan.md](../02-map-plan.md), section 14). It does not touch terrain; terrain work stays with Codex.

Result of the last run: **first build on 2026-10-28** (Justin): 3,309 parts, avatar loaded, flags visible. Found: the statue came out tiny with one accessory floating away, and the saved terrain (about Y 61.5 to 62) covered the streets and lawns. Both fixed in revision 1 (statue posed from its joints and attachments, now gold and 50 studs; district measured onto the terrain). Steps 2, 3, 5, 7 and 8 below are updated for revision 1. Revision 2 (building overhaul) has its own steps R1–R8 below; not run in Studio yet.

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

- GitHub Desktop has pulled the default branch, `rojo serve` is running and the Rojo plugin is connected. Explorer shows `ServerStorage > StudioTools > BuildGundiville`, `StudioTools > Gundiville` (9 modules) and `StudioTools > Architecture` (9 modules), `ServerScriptService > Server > Services > DoorService`, and `ReplicatedStorage > Shared > Config > GovernmentDistrict`.
- **Back up the place first:** *File → Save to File As…* → `Ro-Nation-before-M3.rbxl` outside the Git folder.
- Codex is not working on the place at the same time.

## Steps and expected results

| # | Step | Expected result | Checks |
|---|---|---|---|
| 1 | *Optional, for Roblox's own trees and street lamps:* in **edit mode** run `require(game.ServerStorage.StudioTools.Map.CreatorAssets).install()` | Output: `[Ro-Nation:Assets] Forest Pack (6432306802): … templates selected.` and the same for the City Props Pack; `ServerStorage > RoNationCreatorAssets` exists. This only adds a folder to ServerStorage; it changes no terrain. If it prints an error, skip it: the district then uses its own trees and lamps | A27, store assets |
| 2 | In **edit mode** (Play stopped) with *View → Output* open, run `require(game.ServerStorage.StudioTools.BuildGundiville).run()` in the command bar | Output: `District version district-2. Building streets, square, buildings and the statue...`, then a `Ground:` line with the measured terrain height and the lift (for example `Ground: saved terrain under the district at Y 61.5 to 62.0; district raised by 1.95 studs to stand on it.`), `Removed 6 placeholder blocks that the district replaces.`, `Built … parts (…)`, `Statue: avatar of user 2595858454, finish Gold, figure 50.0 studs high.`, `Done in … s`. A line `Statue: 1 accessory of the avatar fit nowhere on the body and were left out.` is information, not an error | Builder runs in Studio, A33 |
| 3 | Look for yellow warnings with `[Ro-Nation:BuildGundiville]` | None. If the statue warning appears (`Statue avatar could not be loaded`), see *If something goes wrong*. If a warning says the terrain reaches higher than the maximum lift, send a screenshot of that area | A29, A33 |
| 4 | The camera has moved over the square (or run `….BuildGundiville).focus()`). Fly around | The six grey placeholder blocks are gone. Square with stalls, the statue in the middle, the Congress with its green dome at the north end, the Hausali (red roof) east, the bank west, the residence behind walls to the north-east | Layout |
| 5 | Avenue south of the square | Two carriageways with dashed lines, a planted median with trees and double lamps, sidewalks with kerbs, zebra crossings, street name signs "Avenue du 12 Mai" at both ends. Asphalt, sidewalks and lawns lie on top of the terrain, nowhere under it. At its south end the avenue ramps gently onto N5, and the main street onto N4 at its east end, without a step | Streets, A33 |
| 6 | Square | Light paving with granite bands, 8 stalls on each side with coloured awnings and goods, six flags in front of the Congress steps, lamps, benches, trees in the corners | Square |
| 7 | Statue | Your avatar in **gold**, about 50 studs tall (hair and hats on top), complete: no part floating beside it, hair, hat and glasses on the head. On a tall granite pedestal with a stepped base and a gold band, **looking at the Congress**. Bronze plaques on the north and south face read "DR. JUSTIN WACHMANN / LEADER OF THE REVOLUTION / LEITER DER REVOLUTION · DI LAITA". Four floodlights on the platform corners | Statue (P4–P6, A29) |
| 8 | *Optional:* other finishes: `….BuildGundiville).statue({ Finish = "Original" })` (avatar colours), `{ Finish = "Bronze" }`, `{ Finish = "Stone" }`, back with `{ Finish = "Gold" }` | Only the statue is rebuilt each time, at the same height as the district; Output `Statue rebuilt: …, finish …, figure 50.0 studs high.` | D3 (decided: gold) |
| 9 | Congress outside | Wide steps up to a portico of eight columns, "GENERAL PEOPLE'S CONGRESS" and the emblem in the pediment, cream façade with three rows of windows, drum and dome with a flag on top. Tallest building of the district | Congress |
| 10 | Congress inside (walk in through the middle door) | Entrance hall with lights, then the chamber: red carpet, 47 seats in four rising rows facing the dais with three seats, the emblem and two flags behind it. Seats can be sat on in Play | Walkable rooms |
| 11 | Hausali | White building with ochre bands and green shutters, red tile roof, central part with the door, a balcony, "HAUSALI" and the emblem in the gable, flags. Inside: lobby with reception desk, directory board, benches, emblem and flags. Walled garden with a fountain behind (look over the wall) | Hausali |
| 12 | Central Bank | Granite ground floor, sandstone upper floor, six columns, "CENTRAL BANK" above them, emblem in the pediment. Inside: banking hall with a counter behind glass (five windows), sign "CENTRAL BANK / KAGUNDI DINAR · KGD", benches, the round vault door. No money functions yet (Milestone 4) | Bank |
| 13 | Residence: follow North Street east, behind the Congress, to the gate | Wall with pillars, open gate between two lit pillars, guard posts with "GUARD POST" signs, raised red-and-white barrier, name plaque "RESIDENCE OF THE LEADER OF THE REVOLUTION". Drive to a fountain, white villa with portico, balcony, emblem and flags; lawns, hedges, flowers, trees, a gazebo. Inside: hall and your office (desk, chair, visitor chairs, sofas, bookshelves, emblem, flags) | Residence (P30) |
| 14 | Look at any flag from behind | The flag reads correctly from both sides (the back is mirrored like real cloth). If the back is blank or wrong, note it | A30 |
| 15 | Press **Play**, walk from the bus terminal up the avenue to the square and into each walkable room | You can walk through every door listed above without getting stuck; the stalls, benches and statue block you, the doorways do not. Movement stays smooth | Walkability, A31 |
| 16 | Night: in Play switch the command bar to **Server** (Home tab: *Client/Server* button) and run `require(game.ServerScriptService.Server.Services.EnvironmentService).setClockTime(21)` | Street lamps, gate lanterns and the statue floodlights near you light up | Night lights |
| 17 | Stop Play. *File → Save to Roblox* (or Publish), then *File → Save to File As…* → `Ro-Nation-M3.rbxl` outside the Git folder | Place saved, backup exists | |

## Revision 2 — building overhaul (after steps 1–17)

The four buildings were rebuilt with furnished rooms behind every window and working doors (district version `district-2`, [MILESTONES.md](../MILESTONES.md), Milestone 3, revision 2). Tested before this checklist, in the cloud session only: `tests/map/architecture.spec.luau` (71 checks) and the whole `test_all.py`; offline floor plans and 3D views. Nothing of revision 2 has been seen in Roblox Studio yet. The build now makes about 28,000 parts, so `run()` takes longer than before.

| # | Step | Expected result | Checks |
|---|---|---|---|
| R1 | Step 2 again (`….BuildGundiville).run()` in edit mode) | `District version district-2…`, `Built …` with about 28,000 parts. No yellow `[Ro-Nation:Plan] … cannot be reached` warning and no `over the district budget` warning | Build |
| R2 | Fly round each building | Window frames with mullions and sills; shutters on the villa and the Hausali; gutters and downpipes on the Hausali and the villa; AC units on the back and side walls of the Hausali, the bank and the villa; condensers, vents and hatches on the flat roofs of the Congress and the bank. Behind every window you see a furnished room, a corridor or a stair with a ceiling light, never an empty box or a wall | Windows have rooms |
| R3 | Press **Play**. Walk to a closed door inside a building and press **E** at the prompt *Open* | The door swings open in about half a second; the prompt now says *Close*; pressing again closes it. The main portals and the villa's front door start open | DoorService |
| R4 | Walk through every storey of the Congress, the Hausali and the bank by the stairs | Corridors connect the rooms; every door leads somewhere; you walk up the stairs without jumping; rooms have desks, chairs, shelves, plants, lamps that fit the room | Floor plans, stairs |
| R5 | Residence: guard posts at the gate, then the villa | Each guard post: door that opens, window, glazed counter, desk with computer and chair. Villa ground floor: hall with stair, salon, music room with a piano, dining room, kitchen, library, aide-de-camp's office, the Leader's office (desk with nameplate, chair you can sit on, conference table). Upstairs: upper hall onto the balcony, bedrooms, bathrooms, dressing room, guest suite | Residence |
| R6 | Square | Each stall: striped awning, counter with crates, shelves of goods, baskets, a stool and a sign (FRUIT, VEGETABLES, SPICES, COFFEE & TEA, TEXTILES) | Stalls |
| R7 | In Play open *View → Stats* or press **Shift+F5**, stand in the Congress hall, on the square and in the villa | Note the frame rate in each place. Below about 40 FPS on your PC, send a screenshot of the numbers | Performance (20–25 players) |
| R8 | Stop Play. Save as in step 17 | Place saved | |

If a room looks wrong, a door does not open, or a window shows no room, send a screenshot with the building and storey, and the Output lines.

## Revision 3 — interiors (after R1–R8)

The interiors were reworked with furniture from Roblox's own Duvall Drive packs, wall
panelling, skirting and warmer, weaker interior lights ([11-interior-realism.md](../11-interior-realism.md);
offline previews [1](../interior-previews-1.jpg) and [2](../interior-previews-2.jpg), rendered outside Roblox).
Tested before this checklist, in the cloud session only: `tests/map/interior-assets.spec.luau`
(48 checks against synthetic packs) and the whole `test_all.py`. Nothing of revision 3 has
been seen in Roblox Studio yet.

| # | Step | Expected result | Checks |
|---|---|---|---|
| I1 | Pull in GitHub Desktop, `rojo serve`, Rojo connected. Edit mode: `require(game.ServerStorage.StudioTools.BuildGundiville).run()` | Output: `Interior furnishings: official Roblox library installed 73 templates, 2 material variants.`, then `Built …` with about 31,000 parts and no `over the district budget` warning. A yellow `Official interior library not available (…)` warning means the import failed: the build still finishes with built furniture; send the warning | A35 |
| I2 | Explorer: `ServerStorage` and `MaterialService`. Then in the command bar: `local n = 0 for _, d in game.ServerStorage.RoNationInteriorAssets:GetDescendants() do if d:IsA("LuaSourceContainer") then n += 1 end end print(n)` | `RoNationInteriorAssets` holds 73 models and a `MaterialVariants` folder; `MaterialService` has `Wood Floor Herringbone MV` and `Wood Floor MV`; the command prints `0` (no scripts) | Clean import |
| I3 | Play. Visit the Congress committee rooms (first floor), the Hausali cabinet room (second floor), the bank's board room and governor's office (first floor), the residence salon, dining room and the Leader's office | No white glare on walls and ceilings; warm light; brass chandeliers; wooden panelling to the window sills; furniture like the previews (desks, leather chairs, bookcases, sofas, rugs, paintings, plants). Note any room that is too dark or too bright | A36, lighting |
| I4 | Sit on a sofa, an office chair, a dining chair and the Leader's chair | You sit; you can get up with Space | Seats |
| I5 | Walk the corridors of each building | Extinguishers, hose cabinets, fire call points, evacuation plans, exit and direction signs; doors still open with **E**; no furniture blocks a doorway or a corridor | Corridors, doors |
| I6 | Look at the walls in a few rooms closely | Skirting along the floor, no stone of the façade inside, no plant leaves or furniture sticking through a wall | Finish |
| I7 | **Shift+F5** in the Congress hall, the Hausali lobby and the residence | Note the frame rate as in R7 | Performance |
| I8 | Stop Play. Save as in step 17 | The library in `ServerStorage` and the two material variants are saved with the place | |

Ctrl+Z undoes the district build, but not the library import (it is a separate step). To go
back to built furniture: delete `ServerStorage.RoNationInteriorAssets` and run `run()` again;
`run()` then loads the library again, so to keep built furniture permanently, tell Claude.

## If something goes wrong

- `BuildGundiville is not a valid member of StudioTools`: Rojo is not connected or GitHub Desktop has not pulled.
- `Stop Play first`: the command ran during Play. Stop Play and run it again.
- `Map.GovernmentDistrict was not built by this tool`: something else is called `GovernmentDistrict` under `Workspace.Map`. Rename or move it, then run again.
- **Statue warning** (`Statue avatar could not be loaded …`, a plain stone figure stands on the pedestal): insert your avatar by hand: start Play once, select your character under `Workspace` in the Explorer, copy it (Ctrl+C), stop Play, paste it into `Workspace` (Ctrl+V) and rename it to `StatueSource`. Then run `….BuildGundiville).statue()`. `StatueSource` is copied, not moved; you can delete it afterwards.
- Something looks wrong after the build: Ctrl+Z undoes the whole build in one step. `….BuildGundiville).remove()` removes the district and puts the placeholder blocks back.
- To go back completely: *File → Open from File* → `Ro-Nation-before-M3.rbxl`.

Send Claude the Output lines (copy and paste), which statue finish you want (step 8), and screenshots of the overview, the statue, each building and anything that looks wrong.

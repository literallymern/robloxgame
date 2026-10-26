# Milestone 2 · Studio Map Checklist

Run by Justin in Roblox Studio on his PC. Claude cannot run this test (no Studio access). A German step-by-step version is in the project files (`game/milestone-2/Studio-Test-Meilenstein-2.md`), together with a preview image of the map.

Result of the last run: **not run yet.**

## What was tested before this checklist (cloud session, not Studio)

- `python3 tests/map/test_all.py`: 456 checks of the layout and the terrain calculations (road grades and curve radii, five bridges with clearance, a river that never flows uphill, flat places, plots that match the bot's 16 properties, no cliffs inside the ring) and 42 checks of the real `BuildMap` script run against a stand-in for the Roblox API (full terrain written, 1,521 parts, a second run without duplicates). The stand-in checks argument shapes, materials and sizes; it cannot show how Roblox renders or how fast Studio is.
- `rojo build`, StyLua, selene and luau-lsp (strict) with 0 findings.

## Before you start

- The Milestone 2 pull request is merged and GitHub Desktop has pulled the default branch.
- `rojo serve` was restarted after the pull (the project file changed) and the Rojo plugin is connected. Explorer shows `ServerStorage > StudioTools > BuildMap` and `StudioTools > Map`.
- **Back up the place first:** *File → Save to File As…* → `Ro-Nation-before-M2.rbxl` outside the Git folder.

## Steps and expected results

| # | Step | Expected result | Checks |
|---|---|---|---|
| 1 | In **edit mode** (Play stopped) open *View → Output* and *View → Command Bar*. Run `require(game.ServerStorage.StudioTools.BuildMap).run()` | Output: `Map layout version 1. Calculating the landscape...`, `Landscape ready: 16 roads, 5 bridges.`, then `Terrain 10 % … 100 %` with time estimates, `Removed the template Baseplate…`, `Parts built: Airport 46, Boundary 20, Bridges 192, Crossings 20, Places 137, Properties 16, Roads 1102…`, `Done in … s` | Builder runs in Studio; time (expected 1–5 minutes; Studio stays usable between steps) |
| 2 | Note the time from the `Done in … s` line. Look for red errors or yellow warnings with `[Ro-Nation:BuildMap]` | No errors, no "height plan" warnings | |
| 3 | Fly over the map in edit mode (right mouse + WASD, Q/E; Shift for slow). Start at Gundiville (origin) | Flat paved city with the district placeholder blocks (Congress tallest), the avenue south to the city edge, four roads leaving the city | Terrain, footprints, placeholders |
| 4 | Follow every road: N1 to Stokondo (north-west), N2 to Kagundali (south-west), N3 to Oberdueshuson (north-east), N4 east past the airport to the east border, N5 south to the south border, R1–R4 and the access roads | Roads are continuous, end at a place or another road, no road ends at a cliff; city name signs where roads enter | Road network |
| 5 | Find the five bridges (R2, N3, N4, N5, R3) | Concrete deck with railings and a pier; water flows under each bridge | Bridges, river |
| 6 | Follow the river from the northern mountains to the south-west exit | Water the whole way, flowing downhill; steps in the water near the source are expected (blockout) | River |
| 7 | Airport (east of Gundiville, south of N4) | Runway, taxiway, apron, terminal, hangar and tower blocks, apron road from N4 | Airport |
| 8 | Both border crossings (east end of N4, south end of N5) | Canopy over the road, red barrier, customs office; truck inspection shed at the south crossing; mountains on both sides of the pass | Crossings, passes |
| 9 | Property plots: green see-through slabs. Select one and look at its *Attributes* and *Tags* | 16 plots; attributes `PropertyName`, `City`, `PropertyType`; tag `PropertyPlot` | Plot markers for the bot's properties |
| 10 | Press **Play** | You spawn on the blue spawn pad at the Gundiville bus terminal, not inside the ground; Output shows the usual Milestone 1 start lines | Spawn, streaming |
| 11 | Walk to the city edge and onto N4. Optional "car speed" test: in the command bar (it runs on your client during Play) run `game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 90` and run along N1 from Gundiville to Stokondo with a stopwatch | Terrain and parts load around you as you move (streaming); about 25–40 s from the Gundiville edge to Stokondo at 90 studs/s. A short pause screen while running fast is the streaming safety pause | Streaming, travel times |
| 12 | Walk into the mountains towards the map edge | You can climb, but an invisible wall stops you at the edge | Boundary |
| 13 | Stop Play. *File → Save to Roblox* (or Publish), then *File → Save to File As…* → `Ro-Nation-M2.rbxl` outside the Git folder | Place saved, backup file exists | Setup step 8 |

## If something goes wrong

- `StudioTools is not a valid member of ServerStorage`: the command ran during Play. Stop Play and run it again.
- `BuildMap is not a valid member of StudioTools`: Rojo is not connected or GitHub Desktop has not pulled the branch.
- Studio becomes slow after the build: save, close and reopen the place (the undo history of the terrain is large).
- Only the parts need rebuilding (terrain is fine): `require(game.ServerStorage.StudioTools.BuildMap).run({ Terrain = false })`.
- To go back completely: *File → Open from File* → `Ro-Nation-before-M2.rbxl`.

Send Claude the Output lines (copy and paste) and screenshots of anything that looks wrong.

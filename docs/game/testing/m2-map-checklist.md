# Milestone 2 · Studio Map Checklist

Run by Justin in Roblox Studio on his PC. Claude cannot run this test (no Studio access). A German step-by-step version is in the project files (`game/milestone-2/Studio-Test-Meilenstein-2.md`), together with a preview image of the map.

This checklist covers the blockout and the landscape pass (layout version 2, [02-map-plan.md](../02-map-plan.md), sections 12 and 13).

Result of the last run: **not run yet.**

## What was tested before this checklist (cloud session, not Studio)

- `python3 tests/map/test_all.py`:
  - 456 checks of the layout and the terrain calculations (road grades and curve radii, five bridges with clearance, a river that never flows uphill, flat places, no cliffs inside the ring) and the 16 plots match the bot's `GENESIS_PROPERTIES`.
  - 61 landscape checks: river cascades and pools, lakes (water below the shore, no step at the basin edge, away from roads), fields, markings on the road surface, posts, signs, lights and poles beside the road on dry land, a stop sign at every junction, a town sign on every road into a city, trees off roads, water, fields, places and power lines and below the tree line.
  - 44 checks of the real `BuildMap` script run against a stand-in for the Roblox API (full terrain written, 37,281 parts inside the map and under the 45,000 budget, a second run without duplicates).
- The stand-in checks argument shapes, materials and sizes; it cannot show how Roblox renders or how fast Studio is.
- `rojo build` (Lighting effects present), StyLua, selene and luau-lsp (strict) with 0 findings.

## Before you start

- The pull request is merged and GitHub Desktop has pulled the default branch.
- `rojo serve` was restarted after the pull (the project file changed: lighting) and the Rojo plugin is connected. Explorer shows `ServerStorage > StudioTools > BuildMap` and `StudioTools > Map`, and under `Lighting`: `Atmosphere`, `Bloom`, `SunRays`, `ColorCorrection`.
- **Back up the place first:** *File → Save to File As…* → `Ro-Nation-before-M2.rbxl` outside the Git folder.

## Steps and expected results

| # | Step | Expected result | Checks |
|---|---|---|---|
| 1 | In **edit mode** (Play stopped) open *View → Output* and *View → Command Bar*. Run `require(game.ServerStorage.StudioTools.BuildMap).run()` | Output: `Map layout version 2. Calculating the landscape...`, `Landscape ready: 16 roads, 5 bridges.`, `Terrain 10 % … 100 %` with time estimates, `Terrain colours, water, grass and clouds set.`, `Removed the template Baseplate…`, `Parts built: Airport 46, Boundary 20, Bridges 184, Crossings 20, Places 89, Properties 16, Roads 478…`, `Road details: 1430 marking parts, 67 signs, …`, `Vegetation: 8207 trees, 4109 bushes, 2687 rocks (30464 parts).`, `Done in … s` | Builder runs in Studio; time (expected 2–8 minutes; Studio stays usable between steps) |
| 2 | Note the time from the `Done in … s` line. Look for red errors or yellow warnings with `[Ro-Nation:BuildMap]` | No errors. A line `Could not switch on animated grass` is allowed: then tick *Workspace → Terrain → Decoration* by hand | |
| 3 | Fly over the map in edit mode (right mouse + WASD, Q/E; Shift for slow). Start at Gundiville (origin) | Flat paved city with the district placeholder blocks (Congress tallest), four roads leaving the city, tree-lined avenues on N1, N3 and N5 just outside the city | Terrain, footprints, placeholders, avenues |
| 4 | Follow every road: N1 to Stokondo (north-west), N2 to Kagundali (south-west), N3 to Oberdueshuson (north-east), N4 east past the airport to the east border, N5 south to the south border, R1–R4 and the access roads | Roads are continuous and end at a place or another road. White dashed centre line and edge lines on N and R roads, white marker posts beside the road, guard rails on embankments, wooden power poles with wires along N1–N5 | Road network, markings, road furniture |
| 5 | Signs along the way | Yellow town sign with the town name at every road into a city (crossed out on the back), blue signs at facilities, round speed signs (100 on N roads and 80 on R roads when leaving a city, 50 just after the town sign when entering), red stop sign and stop line at every junction, direction signs with arrows before junctions, welcome sign with the flag at both border crossings. Text is readable and faces the arriving traffic | Signs |
| 6 | Find the five bridges (R2, N3, N4, N5, R3) | Concrete deck with markings, railings and a pier; water under each bridge | Bridges |
| 7 | Follow the river from the northern mountains to the south-west exit | Narrow near the source, wide downstream; flat pools with small cascades and boulders between them; trees and bushes along the banks | River |
| 8 | Visit the three lakes: by the cattle ranch (south-east), west of R1 (west), in the northern highlands | Flat water with a sandy or muddy shore, no water standing above the land | Lakes |
| 9 | Farmland around Oberdueshuson and in the south-east | Patchwork of fields with crop rows, tracks and hedges between them, fenced pastures with a gate, brown tobacco barns beside tobacco fields | Fields, countryside |
| 10 | Forests and open land: forested hills between Gundiville and Stokondo, mountains at the map edge, the dry west near Kagundali | Dense mixed forest (dark pines, broadleaf trees, pale eucalyptus) in the hills, acacias with flat crowns in the west, scattered trees and bushes elsewhere, rocks on steep slopes, red earth patches, no trees on roads or in water | Vegetation |
| 11 | Airport (east of Gundiville, south of N4) and both border crossings | Airport blocks as in the blockout; canopy, red barrier and customs office at the crossings | Airport, crossings |
| 12 | Property plots: green see-through slabs. Select one and look at its *Attributes* and *Tags* | 16 plots; attributes `PropertyName`, `City`, `PropertyType`; tag `PropertyPlot` | Plot markers for the bot's properties |
| 13 | Press **Play** | You spawn on the blue spawn pad at the Gundiville bus terminal, not inside the ground; Output shows the usual Milestone 1 start lines. The sky is light blue with a soft haze in the distance | Spawn, lighting |
| 14 | Walk to the city edge and onto N4. Optional "car speed" test: in the command bar (it runs on your client during Play) run `game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 90` and run along N1 from Gundiville to Stokondo with a stopwatch | Terrain and parts load around you as you move (streaming); about 25–40 s from the Gundiville edge to Stokondo. A short pause screen while running fast is the streaming safety pause. Movement stays smooth in the forests; note where it stutters, if anywhere | Streaming, travel times, performance |
| 15 | Walk into the mountains towards the map edge | You can climb, but an invisible wall stops you at the edge | Boundary |
| 16 | Stop Play. *File → Save to Roblox* (or Publish), then *File → Save to File As…* → `Ro-Nation-M2.rbxl` outside the Git folder | Place saved, backup file exists | Setup step 8 |

## If something goes wrong

- `StudioTools is not a valid member of ServerStorage`: the command ran during Play. Stop Play and run it again.
- `BuildMap is not a valid member of StudioTools`: Rojo is not connected or GitHub Desktop has not pulled the branch.
- Studio becomes slow after the build: save, close and reopen the place (the undo history of the terrain is large). If it stays slow: set `Density = 0.6` under `Vegetation` in `src/shared/Config/MapLayout.luau` and run `require(game.ServerStorage.StudioTools.BuildMap).run({ Terrain = false })`.
- Only the parts need rebuilding (terrain is fine): `require(game.ServerStorage.StudioTools.BuildMap).run({ Terrain = false })`.
- Quick look without plants: `require(game.ServerStorage.StudioTools.BuildMap).run({ Vegetation = false })`.
- The lighting did not change: restart `rojo serve` and reconnect the plugin.
- To go back completely: *File → Open from File* → `Ro-Nation-before-M2.rbxl`.

Send Claude the Output lines (copy and paste), whether Play felt smooth (step 14) and screenshots of anything that looks wrong.

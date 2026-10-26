# Highland environment overhaul

## Scope and acceptance status

This is a partial environment implementation. The requested professional visual target has
not been demonstrated or accepted in Studio. Offline checks establish numerical behavior and
some geometry constraints, not realistic rendered appearance.

| Requested area | Delivered behavior | Remaining gap |
| --- | --- | --- |
| Lighting | Natural preset and weather/time composition; exact saved pre-overhaul lighting is migrated to prevent old bloom/saturation stacking | Custom lighting conflicts are reported and preserved; rendered comparison still required |
| Weather and day/night | Five blended states, local rain, lightning, synchronized visual clock and marked streetlights | Runs during Play; automatic weather initially waits 6–11 minutes; Studio verification still required |
| Trees and vegetation | More varied primitive crowns, joined forks and irregular avenues | No authored tree meshes, leaf transparency textures or bark texture maps; still stylized geometry |
| Vegetation density | 5,218 trees, 4,109 shrubs and 2,688 rocks in 31,920 parts | Previous build had 8,207 trees in 30,464 vegetation parts; tree density was reduced to fund more geometry per tree |
| Terrain | Local bank/sediment shape, shallow rural drainage and material patch changes | Main hills are unchanged; refresh does not apply terrain geometry changes |
| Roads and bridges | Gravel shoulders, subtle repairs, open rails, supports and foundations | Engine collision/driving and visual integration still need inspection |
| Rain and thunder sounds | Original WAV sources and runtime playback hooks | Silent until owner uploads assets and grants experience permissions |
| Performance and gameplay | Bounded local effects, streaming models, part budgets and offline regressions | No lower-end-device or 20–25-player Studio profiling; existing gameplay needs engine verification |

`Environment refreshed` means the selected generator groups were replaced successfully. It
does not mean every original acceptance criterion has been met. The tool now prints the
applied `highland-2` revision, actual generated counts, whether terrain was rebuilt, and any
lighting components skipped due to custom conflicts.

## Inspection and priorities

The existing map is generated in edit mode by `BuildMap`: `Land` and `Heightfield` establish
the landscape, `RoadNetwork` fixes road grades and bridge crossings, `River` carves the
channel, and the builders create saved geometry. `MapLayout` contains the city, property,
road and geographical anchors. Those anchors and the German-influenced sign builder remain
unchanged. Canon available here is in `Lore` and the Discord Kagundi Encyclopedia.

The previous lighting was static, with strong ambient light, bloom and saturation. There was
no weather or day/night runtime. Tree species shared very simple crowns and regular avenue
spacing. The implementation priorities were:

1. Shared natural lighting and composited weather/time with bounded client effects.
2. Preserve the existing map with a selective edit-mode refresh.
3. Distinct highland vegetation within the existing overall geometry budget.
4. Better road edges, bridge structure and riverbank/soil transitions.
5. Offline regression/build checks, followed by the Studio checks below.

## Apply to an existing place

First transfer the changed project files into the local checkout used by `rojo serve`.
For delivery through GitHub, use **Fetch origin** in GitHub Desktop, then **Current branch**
to select the update branch linked by the pull request. Pulling the default branch alone
does not include an unmerged pull request. If using the supplied update ZIP instead, extract
its contents into the local project root containing `default.project.json`.

Restart `rojo serve` after updating the project file and connect the Studio Rojo plugin.
Save and restart Studio if BuildMap was previously required in the command bar: Studio can
retain the old ModuleScript return value even after Rojo updates its source.
Stop Play and save a place backup before replacing generated geometry.
In the Studio command bar:

```lua
require(game.ServerStorage.StudioTools.BuildMap).refreshEnvironment()
```

If the command reports `CommandBar:1: attempt to call a nil value`, inspect source and the
loaded function without changing the map:

```lua
local module = game.ServerStorage.StudioTools.BuildMap
print("Current source:", string.find(module.Source, "function BuildMap.refreshEnvironment", 1, true) ~= nil)
print("Loaded function:", typeof(require(module).refreshEnvironment))
```

`false` / `nil` means the new source has not reached this place. Check the local files and
Rojo connection. `true` / `nil` indicates a stale require cache: save, restart Studio and
reconnect Rojo. The expected result is `true` / `function`. Do not substitute `BuildMap.run()`
to fix this error; that entry point rebuilds the terrain by default.

This stages replacement `Roads`, `Bridges`, `RoadDetails` and `Vegetation` folders before
swapping them into `Workspace.Map`. A staging error retains the old map. Existing signs
are moved intact into the new details folder, preserving their text, position and edits.
Terrain voxels, city/place models, property instances, countryside, spawn and custom objects
beside generated folders are retained. Generated folders themselves are replaceable output;
keep hand-built objects outside them. The tool refuses a selected folder without its
`GeneratedBy = "BuildMap"` marker.

For only the new vegetation, lighting and surface palette:

```lua
require(game.ServerStorage.StudioTools.BuildMap).refreshEnvironment({
    Roads = false,
    RoadDetails = false,
})
```

Refresh assumes saved terrain matches the existing generated `MapLayout`. The revised bank
profiles, shallow rural drainage and terrain material blending need terrain regeneration;
they cannot alter saved terrain through Rojo alone. Only for a backed-up generated landscape
whose terrain edits may be replaced, run these two commands in order:

```lua
require(game.ServerStorage.StudioTools.BuildMap).run({ Parts = false })
require(game.ServerStorage.StudioTools.BuildMap).refreshEnvironment()
```

The first command **clears all terrain**, including hand edits. For an initial empty place,
the existing `BuildMap.run()` still builds the complete map. Save the place after building.
The server never rebuilds terrain or environment geometry during Play.

## Runtime and tuning

`Config/Environment.luau` is the central configuration. A 60-minute visual day begins at
09:30; it has no effect on the economy bot's Europe/Berlin economic day. Five weather states
blend over 75 seconds, with seasonal weights and neighbouring-state progression. March-May
and September-December are wetter. This is a configurable highland interpretation rather
than additional Kagundi canon. Height adds modest haze and rain variation without snow.

The server schedules weather and lightning; clients interpolate a timestamped state, render
clouds/lighting, attenuate rain under shelter and enable nearby streetlights at night.
Roblox GlobalWind moves dynamic clouds and terrain grass. Weather and time are composed so
an overcast sunset stays overcast. Streetlights carry `RoNationStreetLight = true` on their
Light and `RoNationLamp = true` on the lamp part. Streamed additions/removals are tracked.

For Studio Play tests, use the **server** command bar:

```lua
local environment = require(game.ServerScriptService.Server.Services.EnvironmentService)
environment.setWeather("Thunderstorm") -- Clear, PartlyCloudy, Overcast, Rain, Thunderstorm
environment.setClockTime(18.5) -- cycle continues from this hour
```

Use the client command bar to override effect quality (0 minimal, 1 low, 2 medium, 3 high):

```lua
game.Players.LocalPlayer:SetAttribute("EnvironmentQuality", 1)
```

Remove the attribute to follow Roblox's saved graphics quality. Local rain is capped at 64
reused non-colliding parts by default, with 16 shared ground/roof probes every 0.2 seconds
plus a shelter probe during rain. Streetlight distance is capped at 260 studs. Trees are
small atomic streamed models with four or five parts, rather than persistent map models.
Lower `MapLayout.Vegetation.Density` for a lighter saved map and rebuild vegetation.

No external meshes, plugins or unverified asset IDs were introduced. Rain and thunder code
accept optional uploaded audio. Original generated WAV files and upload instructions are in
[`assets/audio/README.md`](../../assets/audio/README.md); `Effects.Audio.Rain` and `Thunder`
remain empty until the owner uploads them with experience permissions. Audio is silent until
configured. Custom Atmosphere/Clouds instances take precedence and are left unchanged, with
an Output warning; review any custom post-processing alongside the reserved RoNation effects.
In edit mode the builder recognizes the exact original project's Atmosphere/Bloom/SunRays/
ColorCorrection preset, adopts it or removes a proven old duplicate, then applies the new
values. Altered custom effects are preserved and reported as skipped. This prevents the old
bright bloom and saturation from silently stacking with the new setup.

## Validation and remaining Studio checks

Run the offline suites and build:

```sh
python3 tests/map/test_all.py
python3 tests/environment/run.py
rojo build default.project.json -o environment.rbxlx
```

The map suite uses a strict Roblox API stand-in, not the Roblox engine. It checks road grades,
water/terrain samples, unchanged property definitions, vegetation clearance/geometry/budgets,
bridge supports, streetlight markers, repeated builds and selective preservation. Environment
tests exercise the clock, blending, season selection, lighting composition and server lifecycle.

Executed in this workspace:

| Check | Result |
| --- | --- |
| Full map suite, including terrain writes and repeated/partial refresh | Passed: 456 heightfield, 61 landscape, 5 river, 733 road/bridge, 8 vegetation and 56 full-builder checks; all 16 economic property definitions still match |
| Environment math, server service and saved lighting migration | Passed: 16 model + 12 service + 20 presentation checks |
| Existing Discord/economy regression suite | Passed: 90 tests |
| Luau compiler | All 55 source files compiled |
| StyLua and whitespace checks | Passed |
| Rojo 7.7.1 build | Passed |
| Full generated geometry | 39,504 parts under Workspace.Map, below the 45,000-part budget; vegetation uses 31,920 parts for 5,218 trees, 4,109 shrubs and 2,688 rocks |
| Original audio generator | WAV metadata, clipping, rain-loop seam and deterministic output validated |

Selene could not obtain its Roblox API standard library in this environment. Compilation and
offline tests do not constitute a full Roblox type/API analysis or a device performance test.

## Changed files

| Area | Files |
| --- | --- |
| Lighting and configuration | `default.project.json`, `src/shared/Config/Environment.luau`, `src/shared/Environment/Model.luau`, `src/shared/Environment/Presentation.luau`, `src/studio/Map/Builders/Environment.luau` |
| Runtime integration | `src/server/Main.server.luau`, `src/server/Services/EnvironmentService.luau`, `src/client/Main.client.luau`, `src/client/Controllers/EnvironmentController.luau`, `src/client/Controllers/WeatherEffects.luau` |
| Targeted map refresh | `src/studio/BuildMap.luau` |
| Terrain and vegetation | `src/studio/Map/Heightfield.luau`, `src/studio/Map/River.luau`, `src/studio/Map/Vegetation.luau`, `src/studio/Map/Builders/Vegetation.luau` |
| Roads and bridges | `src/studio/Map/Builders/Roads.luau`, `src/studio/Map/Builders/Bridges.luau`, `src/studio/Map/Builders/RoadDetails.luau` |
| Map tests | `tests/map/run.py`, `tests/map/test_all.py`, `tests/map/roblox-mock.luau`, `tests/map/builders.spec.luau`, `tests/map/landscape.spec.luau`, plus new `river-detail.spec.luau`, `roads-realism.spec.luau`, `vegetation-builders.spec.luau` |
| Weather tests | `tests/environment/run.py`, `tests/environment/model.spec.luau`, `tests/environment/service.spec.luau`, `tests/environment/presentation.spec.luau` |
| Original audio and generation | `assets/audio/kagundi-rain-loop.wav`, `assets/audio/kagundi-thunder.wav`, `assets/audio/README.md`, `tools/generate-weather-audio.py` |
| User documentation | `README.md`, this document |

## Studio acceptance still required

Roblox Studio, a saved current place and the prompt's reference screenshots were unavailable
in this environment. Rendered appearance, physics, actual audio playback, streaming under
movement, and performance for 20-25 players require these checks before release:

- Inspect each city, river crossing and avenue in clear midday and overcast sunset.
- Drive all five bridges and junctions; check collision, shoulders, rail clearances and supports.
- Enter buildings during rain; change camera/respawn; verify shelter and no interior streaks.
- Run every weather state and midnight; verify gradual transitions, thunder delay and lamps.
- Join an already running storm; check matching sky/time on two clients and after streaming.
- Compare low/high graphics on a lower-end device and profile a 20-25-player session.
- Confirm account linking, property labels, signs and other existing gameplay still work.

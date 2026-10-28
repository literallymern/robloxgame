# Fixes after the Studio screenshots of 28 October

Current code: **`kagundali-junction-4`**. The latest accepted screenshot archive is
**`ok.zip`**, containing five PNG images. Justin explicitly withdrew
`bilder_screenshots_1355.zip`; its images must not be used to assess the latest update.
The correct images show textured trees, an imported lamp, visible road markings, a
continuous workshop driveway and no floating place labels. They also show grass entering
the concrete channels, a bulky decorative lamp and spherical shapes among the leaf meshes.
The screenshots remain outside the public repository.

The earlier Studio output that Justin copied confirms that
**junction-2** was applied before: 64 trees, 49 bushes, 47 ferns, 799 parts and the
workshop present. 70 terrain columns were changed, 30,661 were already current. The
screenshots Justin called new and the additional aerial shot
`Screenshot 2026-10-28 091306.jpg` are the starting point. They are not added to the
repository.

## Findings and changes

**Channel beds (junction-4):** terrain materials and concrete geometry now share the same
channel footprints. A narrow Ground strip clears grass-bearing voxel centres beside the
channel axis. Channel floors probe their width and length at intervals of at most four
studs, rather than just their two ends. Protected locations and severe ground dips skip
construction. The patch recognises saved junction-2/3, junction-1 and highland-4 columns;
painted or otherwise unrecognised columns stay intact. Existing heights and water levels
are unchanged relative to junction-3. The deterministic material comparison identifies
212 changed voxel columns; actual saved-place counts can differ.

**Lamp choice (junction-4):** when the installed City Props library contains `StreetLight`
templates, these take priority over alphabetically earlier decorative lamp posts. Existing
source proportions are preserved and the known day/night controller still owns the light.
This selection change uses the saved library; no new pack download is required.

**Remaining spherical crowns:** the images alone do not establish which instances produce
these shapes. The updater now replaces every generated `KagundaliJunction` folder when
duplicates exist; previously `FindFirstChild` only found one. Custom folders with that
name block the update, and old paint is retained without duplication where new probes
fail. The report counts actual imported and native tree models and replaced folders.
Duplicate folders are a supported failure case, not a confirmed explanation of the image.

**Road markings:** the output contained `Road marking probes incomplete` and
`restored 0 marking parts`. In junction-2 a single failed probe discarded the whole new
marking group. That explains why the update could finish successfully without bringing
back any visible lines.

Junction-3 keeps every section that was probed successfully on its own. Missing sections
keep the existing lines; the output names how many and up to four example coordinates.
The height probe reaches further above and below the expected road surface. Visible
terrain asphalt may be painted, grass may not. The exact cause of the original failed
raycasts cannot be determined from the earlier output alone. Generated lines outside the
area and differently named lines of your own are kept. Repeated and global updates do not
create extra lines under kept regional sections.

**Workshop driveway:** instead of twelve long pieces, sections of at most three studs
follow the ground. At each station the nine-stud-wide driveway is probed at three points.
Gravel tops sit above the ground, bottoms reach into it. The grass-free strip under the
driveway introduced earlier stays. Gravel shoulders also follow the saved ground height;
protected areas are left out.

**Yellow direction signs:** direction boards become at least 10.8 × 1.95 studs; arrow heads
and the construction on the back adjust. Existing texts and TextLabel instances are kept.
Posts that were already moved are not moved again; repeated updates do not keep enlarging
the boards.

**Trees and lamps:** the new [Creator Store import](09-creator-store-assets.md) takes
models from two official Roblox packs and connects them directly to the updater. The
library holds only visual geometry and textures. Imported trees get narrow trunk
colliders, lamps the known night-light control. Only old generated lamps that were
replaced successfully are removed.

## Earlier fix to the original tree templates

With `Part.Shape = Ball` the smallest size axis sets the sphere diameter. The earlier
offline preview had drawn freely stretched sphere meshes instead, so the native generator
could not produce the leaf shapes it showed. Roblox describes the behaviour in the official
[announcement on Part.Shape and Size](https://devforum.roblox.com/t/improvements-to-part-shape-size/2443389/1).
Since `kagundali-trees-2` a uniform sphere is first baked into a PartOperation; only its
copies are stretched and joined. These original templates stay available for places
without a Creator Store library and for missing optional plant categories. A successful
import takes priority.

## Apply and check

Pull the default branch **`claude/project-thread-5krwdh`**, back up the place and stop Play.
Sync Rojo, save, restart Studio and reconnect Rojo. The restart clears old modules that
were already loaded with `require()`. In the command bar:

```lua
require(game.ServerStorage.StudioTools.UpgradeKagundali)()
```

This reuses the imported library already visible in `ok.zip`. The output should report
**`kagundali-junction-4`**, actual imported/native tree counts and replaced region folders.
Save afterwards. If the library has not yet been installed, use the combined import command:

```lua
require(game.ServerStorage.StudioTools.UseCreatorStoreAssets)()
```

The patch is limited to X 64–832 and Z 2944–3648. It excludes the Gundiville government
district, including Congress, Hausali, Central Bank and Residence. This update does not
invoke `BuildGundiville`. Use the regional command above on the saved place.

The report separates new, kept and skipped marking pieces. `CheckEnvironment()` counts the
trees and lines that are really there and reports outdated tree versions. The normal test
scene without import contains 64 trees, 49 bushes, 47 ferns, 23 rocks and 139 marking
pieces, **1,254 BaseParts** in total. The import test scene with artificial pack models
contains **841 BaseParts and one imported lamp**. That number is not a measurement of the
real Roblox packs. The regional limit stays at 1,600 parts; going over it stops before the
old regional geometry is swapped.

## Test limits

Regression tests check partial marking failures, their heights and retention, import
failures, script removal, kept mesh and texture data, ground placement, lamp replacement
and repeated updates. The test stand-in runs neither native CSG nor Roblox rendering.
`ok.zip` provides visual evidence of the preceding update and the imported models.
**The junction-4 corrections have not yet been verified in new Studio images.** Exact live
pack hierarchy, the cause of the remaining round shapes, triangle budget, saved-place
behaviour and performance with 20–25 players still require Studio inspection.

Validation includes 29 regional scene checks, 12 terrain-migration checks and 20 import
checks. Strict luau-lsp analysis uses Roblox definitions and the current Rojo sourcemap.
The government-district test is deliberately excluded because it executes
`BuildGundiville`; the protected files are checked for unchanged contents.

The regional grass edge, distant bare mountain sides and the remaining town placeholders
are not finished in this step. Before extending along the R3, the visual comparison of the
whole junction area is still needed.

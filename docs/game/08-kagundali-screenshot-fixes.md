# Fixes after the Studio screenshots of 28 October

Current code: **`kagundali-junction-5`**. The latest accepted uploads are
**`Screenshot 2026-10-28 184333.zip`** (five images) and
**`Screenshot 2026-10-28 184502.zip`** (one image). These show the junction-4 update:
the shown grove has textured trees without the earlier spherical shapes, the slender
street light is present, road paint is visible, and channels are largely free of grass.
They also show exposed tree roots, raised-looking concrete channels and a channel
running through the workshop driveway. These are the focus of junction-5.

The earlier corrected archive was `ok.zip`. Justin explicitly withdrew
`bilder_screenshots_1355.zip`; its images must not be used to assess the update.
All user screenshots remain outside the public repository.

The earlier Studio output that Justin copied confirms that
**junction-2** was applied before: 64 trees, 49 bushes, 47 ferns, 799 parts and the
workshop present. 70 terrain columns were changed, 30,661 were already current. The
screenshots Justin called new and the additional aerial shot
`Screenshot 2026-10-28 091306.jpg` are the starting point. They are not added to the
repository.

## Findings and changes

**Root placement (junction-5):** imported tree proportions and upright trunks stay intact.
Their visual geometry is lowered by a small height-dependent amount plus the measured
nearby downhill drop. Eight ground probes surround each trunk; total embedding is capped
at three studs. Missing neighbour probes retain the conservative base depth. The actual
ground reference and narrow trunk collision do not move. This is a placement correction
for the existing Store models, not a replacement tree generator. Exact root contact still
needs the real mesh checked in Studio.

**Grounded channels (junction-5):** concrete spans are at most 16 horizontal studs long,
with shared endpoint heights. Floors probe the ground across their width and along each
span at intervals of at most two studs. Wall rims are lower, and floor/wall thickness
extends their undersides into the sampled ground. Channels skip protected points and
sharp height changes. No new terrain material or height changes are introduced relative
to junction-4.

**Driveway crossing (junction-5):** channel floors and walls are clipped outside the full
nine-stud driving corridor, with clearance for channel width. The driveway has a concrete
surface with collision where it crosses the channel, using the same ground profile as the
adjacent gravel. Additional probes between driveway stations clear intermediate terrain
lips while retaining shared endpoint heights. This removes the continuous raised wall
across the access. It does not simulate water flow or an excavated underground culvert.


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

**Earlier spherical crowns (before junction-4):** the images alone do not establish which instances produce
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

This reuses the imported library already visible in the screenshots. The output should report
**`kagundali-junction-5`**, actual imported/native tree counts and replaced region folders.
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
pieces, **1,479 BaseParts** in total. The import test scene with artificial pack models
contains **1,066 BaseParts and one imported lamp**. That number is not a measurement of the
real Roblox packs. The regional limit stays at 1,600 parts; going over it stops before the
old regional geometry is swapped.

## Test limits

Regression tests check partial marking failures, their heights and retention, import
failures, script removal, kept mesh and texture data, ground placement, lamp replacement
and repeated updates. The test stand-in runs neither native CSG nor Roblox rendering.
The six latest user images provide visual evidence of junction-4; the new junction-5
root placement, channel support and crossing geometry still require Studio comparison.
The real pack hierarchy, triangle budget and performance with 20–25 players also require
Studio inspection. Offline part counts are not rendering or performance measurements.

Validation includes 31 regional scene checks, 12 terrain-migration checks and 22 import
checks. The scene checks sample concrete undersides, floor clearance, driveway width
and the collision surface. Import checks cover flat, sloped and missing ground probes,
bounded embedding, source proportions and the real regional updater. Strict luau-lsp
analysis uses Roblox definitions and the current Rojo sourcemap. District suites are
excluded because `BuildGundiville` must not be executed; protected files are checked
against the newly pulled main-branch versions.

The regional grass edge, distant bare mountain sides and the remaining town placeholders
are not finished in this step. Before extending along the R3, the visual comparison of the
whole junction area is still needed.

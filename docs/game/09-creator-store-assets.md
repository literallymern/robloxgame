# Official Creator Store models for Kagundali

State: 28 October 2026. The map integration uses two free model packs from the Roblox
account **@Roblox (creator ID 1)**:

| Pack | Asset ID | Use |
|---|---:|---|
| [Forest Pack](https://create.roblox.com/store/asset/6432306802) | 6432306802 | Trees, bushes, ferns and rocks, where complete models are recognised |
| [City Props Pack](https://create.roblox.com/store/asset/6370681139) | 6370681139 | Street lamps at the existing generated positions in the junction area |

Roblox introduced the packs in the official
[announcement of Endorsed Models](https://devforum.roblox.com/t/new-endorsed-models-in-toolbox/1068480).
The source and asset ID are stored as attributes on imported templates and placed models.
The repository contains the import code and the IDs; the imported models are saved in the
place.

The import checks the listed IDs in Studio before loading anything: if the creator is
not Roblox (ID 1) or the asset is not a model, it stops without changing the place.

## One command for import and update

After pulling the default branch `claude/project-thread-5krwdh`, a Rojo sync and a Studio
restart, with Play stopped and the place backed up:

```lua
require(game.ServerStorage.StudioTools.UseCreatorStoreAssets)()
```

The command checks the creator ID and asset type of the two fixed packs, loads them with
`InsertService:LoadAsset()` and builds a library under
`ServerStorage.RoNationCreatorAssets`. Then `UpgradeKagundali()` runs automatically.
The camera moves to the R3/N5 area. Save the place afterwards.

[InsertService](https://create.roblox.com/docs/reference/engine/classes/InsertService)
supports Roblox's own assets, so the import does not need a general permission for any
third-party asset. Justin's corrected `ok.zip` images now show imported trees and a lamp
alongside the updated markings and driveway. These images do not expose the pack hierarchy
or establish that every selected template is suitable.

For later geometry updates `UpgradeKagundali()` is enough; it uses the saved library
without downloading again. The existing BuildMap paths use it for the junction area too.
The import does not replace vegetation in the other towns yet. The yellow direction signs
keep their project-specific text and are improved by the sign builder.

## What is taken over

- Complete models are selected by name, hierarchy, size and part count. Collection folders
  and nested parts are not taken twice.
- MeshParts and textures including SurfaceAppearance and DoubleSided are kept. Demo
  baseplates and particle geometry are left out.
- Only visual children of type SurfaceAppearance, SpecialMesh, Texture and Decal stay.
  Scripts, sounds, demo controls and all other children are removed before the library goes
  into ServerStorage or the geometry into Workspace. The downloaded pack itself is never
  parented into the place.
- Trees are aligned to the ground, scaled and get narrow trunk colliders. Leaves block
  neither players nor camera raycasts.
- Lamps get a downward light emitter with the existing attributes for night light and
  distance cut-off. Original textures are kept. Old generated lamps disappear only at
  positions that were replaced successfully; your own differently named objects and
  removed lamps stay.
- Since junction-4, `StreetLight` templates take priority over decorative lamp posts when
  both are present in the saved library. Existing imports can be reused with
  `UpgradeKagundali()`; another download is unnecessary.

The import needs at least one complete tree and one lamp template. Missing optional bush,
fern or rock categories use the existing original templates. Output names the templates
actually imported per category. Demo animations are not taken over; imported mesh trees
are static here. Roblox's animated terrain grass and the existing weather keep running.

## Failures and test limits

Download errors, a different creator or asset type, or missing complete tree and lamp
models keep the previous library. With an unknown structure the error message lists model
names for diagnosis. Your own content in the library folder blocks a swap. A geometry or
budget error in the updater that follows keeps the old regional geometry; the library
import that succeeded before stays saved. The terrain updater can already have written
terrain columns before a later geometry error. A place backup is therefore still sensible.

The direct asset download was blocked in the cloud by the network connection (proxy tunnel
HTTP 403). No Roblox Studio is available there. **The real pack hierarchies could not be
inspected locally.** The corrected user images provide visual evidence of imported models,
but the latest lamp-selection and duplicate-folder corrections still await a Studio view.
The 20 import regressions use
artificial models and check selection, script removal, texture retention, failure cases,
ground placement, night-light attributes and the connection to the real map updater. They
are not proof of a successful live download or of how the original packs look.

After the first import compare the three earlier junction views and the aerial view: crown
shape and textures, a continuous driveway, visible lines, readable direction signs, and
lamps by day and night. The 1,600-part limit is not a triangle or frame-rate measurement;
both still have to be checked with the real models.

The latest checks include 20 import regressions and 86 environment checks. All 82 Luau
source files compile; strict luau-lsp analysis, StyLua and the Rojo build pass. The map
suite excludes the government-district test so `BuildGundiville` is never executed.

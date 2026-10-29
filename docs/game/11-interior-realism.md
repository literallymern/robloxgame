# Interior realism overhaul (Milestone 3, revision 3)

State: 29 October 2026. Justin's request of 28 October ("Complete interior realism overhaul")
asked for realistic, institutional interiors in the General People's Congress, the Hausali,
the Central Bank and the Leader's residence: German and French influences, restrained
prestige, a distinct identity per building, real rooms behind every window, and lighting that
is no longer overexposed, all built by the procedural generator so a rebuild keeps it.

Scope kept: no new buildings, no city expansion, no change to Codex's terrain, vegetation,
roads, global lighting, weather, day/night, environment effects or flags. Only interiors,
interior lights and interior fittings changed.

Offline previews (official Roblox models placed by the generator, rendered outside Roblox;
the lighting is an approximation, not Roblox Studio): [interior-previews-1.jpg](interior-previews-1.jpg),
[interior-previews-2.jpg](interior-previews-2.jpg).

## 1. Official Roblox furniture

`src/studio/Architecture/StoreAssets.luau` builds a library of 73 furnishing templates from
four packs published by the Roblox account itself (creator: user ID 1, verified). Before the
selection, the publisher of each pack was checked through the Roblox catalogue; a group named
"Roblox" with invisible characters (group 158552482) that republishes such packs was ignored.

| Pack | Asset ID | Used for |
|---|---:|---|
| House Furniture Pack – Duvall Drive | 10847897579 | desks, office and dining chairs, armchairs, sofas, bookcases, credenzas, consoles, tables, beds, wardrobes, piano, clocks, display case |
| House Props Pack – Duvall Drive | 10840642581 | lamps, reproductions of classic paintings, rugs, busts, books, cups, coffee machine, kettle, bowls |
| Landscaping Pack – Duvall Drive | 10840661513 | potted plants |
| Realistic Material Variants – Duvall Drive | 10841357434 | the two wooden floor variants (`Wood Floor Herringbone MV`, `Wood Floor MV`) |

How the library is made (`StoreAssets.install()`):

- Before loading a pack, `MarketplaceService:GetProductInfo` must report creator ID 1 and
  asset type 10 (model); otherwise the import stops and the previous library stays.
- `InsertService:LoadAsset` loads the pack; the pack itself is never parented into the place.
- Only the visible geometry of the catalogued models is copied: no scripts, prompts, sounds,
  lights, particles or constraints; no hidden drawer contents, no invisible hit boxes and no
  pieces smaller than 0.16 studs (drawer knobs). Seats stay, so players can sit.
- Every template is anchored, does not fire touch events, and is normalised: its front faces
  -Z, its origin is the bottom centre (floor items, rugs), the back centre (pictures) or the
  top centre (ceiling items). Small pieces and rugs do not collide; tiny pieces cast no
  shadow.
- The library is `ServerStorage.RoNationInteriorAssets` (attributes `ManagedBy`,
  `AssetVersion = interior-1`); a folder of that name that the tool did not make is never
  replaced. The two floor variants are copied into `MaterialService`; a variant of the same
  name that someone else made stays untouched.

`BuildGundiville.run()` calls `StoreAssets.ensure()` first: it installs the library when it is
missing and says so in the Output. If the library cannot be loaded, every room recipe builds
its own furniture instead, with the same layout (the recipes lay rooms out from the measured
template sizes, so nothing moves between the two cases). To reload the library by hand:
`require(game.ServerStorage.StudioTools.UseInteriorAssets)()`.

No third-party Creator Store asset and no paid asset is used. The template sizes and part
counts in the catalogue were measured from the downloaded packs after the same clean-up.

## 2. Walls, floors and ceilings

- **Wall linings:** exterior walls now have a painted inner skin in the building's partition
  colour, so façade stone never shows inside.
- **Skirting boards** along every wall of every room except stairs, lifts and wet rooms,
  cut at doors and floor-level windows.
- **Corridors:** a wooden wainscot or an oil-paint dado to about one metre, cut below the
  window sills.
- **Representative rooms** (executive offices, committee, board and cabinet rooms, salons,
  libraries, dining and music rooms, the Leader's office, study, family room): wooden
  panelling to the sills with a chair rail, and a plaster cornice.
- **Floors** per building and room type: marble and dark marble in halls, parquet
  (herringbone variant) in state rooms, plank floors, linoleum and muted carpets elsewhere.
- **Plants** keep their leaves clear of the walls: they turn in quarter turns and are scaled
  to the free space around them.

## 3. Interior lighting

The global lighting (Codex: `Lighting.Brightness` 2.162, ambient about 0.24, bloom threshold
1.8) is unchanged. Inside, the generator compensates:

- ceiling light panels are thinner and a muted, warm Neon (no longer pure white);
- point lights are warmer (255, 226, 190) and weaker (brightness 0.6), with a shorter reach;
- representative rooms get classical brass chandeliers with candle bulbs instead of panels
  (Congress: committee and board rooms, library, lounges, executive offices, the hall and the
  chamber; Hausali: cabinet room and salon; Central Bank: board room, executive offices and
  the banking hall; residence: all state and private rooms and the halls);
- wall and ceiling paints are mid-tones instead of near-white, so walls no longer flare.

390 lights in the four buildings (interior and the night lanterns), none brighter than 0.85
inside; shadows stay off for interior lights.

## 4. Rooms

`src/studio/Architecture/Rooms.luau` has rewritten recipes that use the official models where
they fit and built furniture otherwise:

- **Offices:** desk with the user's side to the room, desk chair, visitor chairs, bookcases or
  filing cabinets, credenza, coat rack by the door, cork board or whiteboard, desk lamp,
  computer, paintings, radiators under the windows. Executive offices add an executive desk,
  a sitting group on a rug, a grandfather clock and a portrait.
- **Committee, board and cabinet rooms:** long table with arm chairs at the ends and dining
  chairs along the sides, notepads, a screen or a portrait, credenzas, a clock.
- **Library:** bookcases on the walls (tall ones where the room is high enough), a reading
  table with banker's lamps, armchairs and a floor lamp.
- **Residence:** salon with fireplace, sofas and armchairs on a large rug, display case and
  console; music room with the piano; dining room with a long table on a rug and credenzas;
  bedrooms with bed, nightstands and lamps, wardrobes, dresser, armchair and curtains; the
  Leader's office with the executive desk, the Leader's chair (the seat of the official desk
  chair, still named `LeadersChair`), bookcases, a sitting group, conference table, clock and
  curtains.
- **Corridors:** fire extinguishers, hose cabinets, fire call points and evacuation plans,
  exit signs and direction signs with the corridor name and room numbers, benches and
  paintings in wide corridors, plants at the ends.

### Identity per building

| Building | Walls and panelling | Floors | Seats and wood | Fixtures |
|---|---|---|---|---|
| General People's Congress | stone-grey walls, walnut panelling and dados | marble galleries, parquet corridors, moss and taupe carpets, green carpet in the committee rooms | walnut, brown leather | chandeliers in committee, board, library, lounges, executive offices |
| Hausali (ministries) | linen walls, sage oil-paint dado in corridors, oak panelling | grey-green linoleum corridors, grey and blue carpets, oak parquet in the cabinet room | oak, black leather | chandeliers in the cabinet room and salon; panels elsewhere |
| Central Bank | cream walls, walnut panelling | dark marble corridors, navy carpets, dark parquet in the board room and executive offices | walnut, brown leather | chandeliers in the board room, executive offices and banking hall |
| Residence | cream walls with white painted panelling; walnut in the library, study, office and dining room | parquet, marble bathrooms, red runner in the halls | walnut, beige fabric, light sofas | chandeliers in every state and private room |

## 5. Part budget

| | without the library | with the library |
|---|---:|---:|
| Congress | 10,285 | 10,093 |
| Hausali | 11,088 | 10,928 |
| Central Bank | 4,765 | 4,721 |
| Residence | 3,905 | 3,966 |
| Four buildings | 30,043 | 29,708 |
| Whole district | 31,347 | about 31,000 |

The district budget is now 33,000 (`District.MaxParts`); most new parts are thin boards and
small fittings without collision or shadows, and `StreamingEnabled` sends clients only what is
near.

## 6. Tests

- `tests/map/interior-assets.spec.luau` (new, 48 checks): runs the importer against synthetic
  packs that mirror the catalogue plus the clutter real packs carry (scripts, prompts,
  lights, sounds, hit boxes, drawer contents, knobs, a foreign material variant); checks the
  clean-up, seats (enabled, touchable), template sizes and origins, the turned clock, `place()`, a pack from the
  wrong creator, then builds the four buildings with the library: every placed model stays
  inside its room (no plant or cabinet reaches into a wall), nothing is unanchored or
  scripted, the chamber keeps its 50 seats, the Leader's chair is the official chair's seat.
- `tests/map/architecture.spec.luau` and `gundiville.spec.luau` with the new budgets.
- `python3 tests/map/test_all.py`: all specs pass.
- StyLua on the changed files. luau-lsp could not be built in this cloud session, so the
  strict type check was not run this time.
- 17 rooms exported from the generator with the real pack meshes and rendered offline; the
  previews showed one bug (the Hausali entrance lobby treated the passage through the main
  wall as an opening in its own front wall, so that wall got no panelling), fixed.

First Studio run (Justin, 29 October): the build stopped with `CorrugatedMetal is not a valid
member of "Enum.Material"` and changed nothing. That material does not exist in Roblox; the
offline stand-in had been given it by mistake. Radiators are now painted `Metal`, and the
stand-in's material list matches Roblox's again. In the same pass, template seats are kept
enabled and touchable (characters sit down on touch).

Not tested: anything else in Roblox Studio — the import with `InsertService` in edit mode (A35),
how the rooms look with Roblox lighting, frame rate. Justin's steps: [testing/m3-district-checklist.md](testing/m3-district-checklist.md), section *Revision 3*.

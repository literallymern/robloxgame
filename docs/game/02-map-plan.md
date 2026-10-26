# 02 · Map Plan: East District of Kagundi

Status: **proposed in Milestone 0** (2026-10-26). Milestone 2 builds the blockout from this plan and turns the numbers below into `src/shared/Config/MapLayout.luau`, which then becomes the single source for coordinates. Positions may move by up to about 100 studs during the blockout if the terrain needs it; this document is updated when they do.

![Map plan](map-plan.svg)

## 1. Canon this plan follows

From the Kagundi Encyclopedia (authoritative) and the Lore Bible:

- Landlocked, mostly mountainous: high plateaus, forested hills, valleys, rolling farmland.
- The capital and **all major cities lie in the East District**. The map therefore shows the East District.
- Mines and industrial sites lie **outside** the commercial centres; tobacco farms and cattle ranches fill the rural districts.
- A **cargo airport near the capital**, **international border crossings with customs posts**, and **roads linking every major city**.
- Gundiville (capital), Stokondo (justice and healthcare), Kagundali (trade and mining, site of the 1917 strike), Oberdueshuson (military and agriculture, garrison town since the Schutztruppe, starting point of the 1982 revolution).

## 2. Coordinate system and scale

| Item | Value |
|---|---|
| Map size | 10,240 × 10,240 studs (X and Z from −5,120 to +5,120), centred on the origin to avoid floating-point jitter far from (0, 0, 0) |
| Directions | **North = −Z**, East = +X, South = +Z, West = −X (*proposal*; matches Studio's default camera) |
| Scale | Roblox characters are about 5 studs tall, so 1 stud ≈ 0.28 m. Distances between cities are compressed for gameplay; buildings keep realistic proportions. |
| Playable area | Inside the mountain boundary, roughly −4,400 to +4,400 on both axes (about 8,800 studs across) |
| Boundary | A ring of steep mountains 720 studs wide, with passes only at the two border crossings. Invisible walls only where the terrain cannot stop players. |
| Heights | Valley floors Y 40–100, highland plateau Y 180, hills Y 250–450, boundary mountains Y 600–900 |

Why this size: with 20–25 players, a much larger map feels empty, while a smaller one cannot hold four distinct cities, an airport and real countryside. At a typical car speed of about 90 studs per second, the plan gives drives of roughly 40–70 seconds between neighbouring cities, long enough to feel like travel and short enough for emergency services. Walking between cities is possible but slow (16 studs per second), which makes vehicles meaningful.

## 3. Places and footprints

Footprints are axis-aligned rectangles given as X range × Z range.

| Area | Centre (X, Z) | Footprint | Ground Y | Notes |
|---|---|---|---|---|
| **Gundiville** | (0, 0) | −900…900 × −900…900 | 60 | Capital in a central basin. Government district in the north-east quarter, see section 5 |
| Cargo airport | (2,900, 950) | 1,700…4,100 × 600…1,300 | 60 | Runway about 2,200 × 120 studs, east–west. Cargo apron and terminal on the north side, access from N4 |
| **Stokondo** | (−3,000, −2,300) | −3,600…−2,400 × −2,900…−1,700 | 100 | North-west. Second-instance court, judicial administration and archive, major polyclinic |
| **Kagundali** | (−2,700, 2,700) | −3,400…−2,000 × 2,000…3,400 | 40 | South-west lowland valley. Commercial centre, trading companies, warehouses, freight yard |
| Kagundali industry and ore processing | (−1,600, 2,500) | −1,900…−1,300 × 2,100…2,900 | 40 | Between the city and N2; outside the commercial centre as the canon requires |
| Gold fields | (−3,900, 3,800) | −4,300…−3,500 × 3,400…4,200 | 80–200 | Hill mines south-west of Kagundali; place for a 1917 strike memorial (*proposal*) |
| Palladium mine | (−4,000, 1,150) | −4,300…−3,700 × 800…1,500 | 120 | West hills "near Kagundali" (1973 Concession Scandal) |
| **Oberdueshuson** | (2,400, −2,800) | 1,900…2,900 × −3,300…−2,300 | 180 | North-east highland plateau; garrison town |
| Revolutionary Guard main barracks | (3,650, −3,000) | 3,100…4,200 × −3,500…−2,500 | 180 | Barracks, military administration, vehicle and equipment depot |
| Military training grounds | (3,900, −1,950) | 3,500…4,300 × −2,400…−1,500 | 170 | Firing range, drill ground, obstacle course |
| Tobacco farms | — | 500…1,800 × −3,800…−2,700 and 1,900…3,000 × −4,300…−3,400 | 150–200 | Farms and rural settlements around Oberdueshuson |
| Farmland and cattle ranches | (2,600, 2,750) | 1,400…3,800 × 1,700…3,800 | 50–80 | South-east lowland, rural settlements |
| East border crossing | (4,900, 250) | 4,700…5,100 × 100…400 | 60 | International; customs post. Neighbouring country unnamed (*open question*) |
| South border crossing | (500, 4,900) | 350…650 × 4,700…5,100 | 50 | International; customs post and truck inspection for freight from Kagundali |
| Northern highlands | — | −2,300…1,900 × −4,400…−3,850 | 300–450 | Mountain pass for R2 |
| Forested hills | — | −2,200…−900 × −2,600…−1,500 | 150–300 | Between Gundiville and Stokondo |
| River (*proposal*, unnamed) | — | from (1,000, −4,400) south past Gundiville to (−1,500, 5,120) | — | Five bridges (R2, N3, N4, N5, R3). Can be dropped if it costs too much performance |

## 4. Road network

All four cities are connected through a hub (Gundiville) plus an outer ring, so every city can be reached by at least two routes. That matters for emergency services and for roleplay roadblocks. Road numbers are labels for development (*proposal*), not canon names.

| Road | Class | Route | Approx. length (studs) | Notes |
|---|---|---|---|---|
| N1 | National | Gundiville ↔ Stokondo | 3,200 | Through the forested hills, climbs 40 studs |
| N2 | National | Gundiville ↔ Kagundali | 3,300 | Passes the industrial zone |
| N3 | National | Gundiville ↔ Oberdueshuson | 3,000 | Climbs 120 studs to the plateau (about 4%); river bridge |
| N4 | National | Gundiville ↔ cargo airport ↔ East border | 4,800 | Main freight and airport road; river bridge |
| N5 | National | Gundiville ↔ South border | 4,600 | River bridge; R3 joins it |
| R1 | Regional | Stokondo ↔ Kagundali (west valley) | 3,800 | Access to the palladium mine |
| R2 | Regional | Stokondo ↔ Oberdueshuson (northern pass) | 4,800 | Highest road, pass at about Y 300 |
| R3 | Regional | Kagundali ↔ N5 | 2,500 | Freight route from Kagundali to the south border; river bridge |
| R4 | Regional | Oberdueshuson ↔ N4 near the airport | 2,700 | Military road past the training grounds |
| Access | Local | Mines, farms, barracks, airport apron | — | Gravel or narrow asphalt |

Road standards (*proposal*, tested with vehicles in Milestones 2 and 11):

| Class | Width | Lanes | Max gradient | Min curve radius |
|---|---|---|---|---|
| National (N) | 40 studs (2 × 16-stud lanes + shoulders) | 1 + 1 | 6% | 150 studs |
| Regional (R) | 32 studs | 1 + 1 | 10% | 90 studs |
| City avenue | 100 studs incl. median and sidewalks | 2 + 2 | 4% | — |
| City street | 40 studs incl. sidewalks | 1 + 1 | 8% | — |
| Access road | 20–24 studs | shared | 12% | 40 studs |

Every route ends in a city, a facility, a border crossing or a turning area; none ends in a cliff.

## 5. Gundiville government district

![Gundiville plan](gundiville-plan.svg)

Coordinates in studs, world space (Gundiville is centred on the origin).

| Element | Footprint (X × Z) | Faces | Notes |
|---|---|---|---|
| Ceremonial avenue | −50…50 × −20…900 | — | Main approach from the south, tree-lined median, ends at the square |
| Main square (ceremonial and market square) | −140…140 × −260…−20 | — | Market stalls along the east and west edges, parade space in the middle |
| **Statue of Dr. Justin Wachmann** | platform −30…30 × −160…−100, figure at (0, −130) | south, down the avenue | On the ceremonial axis directly in front of the Congress, visible along the whole avenue and from the Congress entrance (*proposal*: facing south; see 04 for the alternative) |
| **General People's Congress** | −140…140 × −440…−290 | south | Spans the north end of the square; forecourt and ceremonial steps at Z −290…−260. Tallest building of the district (central dome or tower) |
| **Hausali** (government headquarters) | 190…360 × −280…−40 | west, onto the square | Administrative style, clearly different from the Congress |
| **Leader's residence** | 440…720 × −800…−560 | south (gate) | Walled, guarded compound with gardens, set back from the square; separate from Congress and Hausali |
| Central bank | −330…−190 × −250…−60 | east, onto the square | |
| National university | −820…−440 × −820…−560 | south | Campus with the law programme |
| Central City Police station | −300…−90 × 140…250 | east, onto the avenue | Vehicle yard behind |
| Central hospital | 430…720 × 160…420 | north | Ambulance bay, helipad |
| Brandwehr Crisis Response Center | 430…640 × −80…70 | south, onto the main east–west street | Apparatus bays open directly onto the street towards N4 |
| Main commercial district | −360…360 × 300…860 (beside the avenue) | — | Shops, offices, market hall |
| Bus terminal and new-player arrivals | 90…300 × 700…860 | west, onto the avenue | Default spawn for new players (*proposal*) |
| Residential | west −880…−430 × −440…880; south-east 430…880 × 450…880 | — | |

## 6. Other cities (outline; detail in Milestone 4)

- **Stokondo:** court quarter around a central square (second-instance court, judicial administration, archive), polyclinic near the N1 entrance for ambulance access, a residential and commercial ring.
- **Kagundali:** commercial core with trading houses, warehouse district and freight yard on the east side towards the industrial zone and N2, mine roads to the gold fields and the palladium mine, a strike memorial (*proposal*).
- **Oberdueshuson:** small garrison town with a historic Schutztruppe-era core, the Revolutionary Guard barracks to the east, training grounds to the south-east, tobacco farms and drying barns to the west and north.

## 7. Public services and utilities (placed in Milestone 5)

| Facility | Planned location |
|---|---|
| Fuel stations | In every city, plus on N2, N3 and N4 near the airport |
| Vehicle workshops | Gundiville, Kagundali (freight), Oberdueshuson |
| Main power station | Kagundali industrial zone; substations in each city |
| Water treatment | On the river south-east of Gundiville, near (1,000, 1,300) |
| Telecommunications mast | Hill west of Gundiville, near (−1,400, −700) |
| Landfill and waste | Near R3, about (−1,000, 4,200) |
| Bus stops | Along N1–N5 at city entrances and villages |

## 8. Spawns

- New players: Gundiville bus terminal (see section 5).
- Faction spawns (later milestones): City Police station, Gendarmerie post, Revolutionary Guard barracks, hospital, Brandwehr Crisis Response Center, court in Stokondo.
- Spawn selection screen: Milestone 12.

## 9. Performance notes for the blockout

- Terrain carries most of the landscape; parts only for roads, buildings and gameplay objects.
- Roads are built from reusable segments by a road builder, not placed by hand.
- Vegetation uses a small number of reusable tree models, placed sparsely outside the cities.
- Instance streaming is on from the start, so the blockout is tested the way players will see it.

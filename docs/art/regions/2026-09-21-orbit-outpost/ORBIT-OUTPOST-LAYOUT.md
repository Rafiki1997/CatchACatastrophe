# Orbit Outpost measured layout

The base region is built and validated. This is the dimensioned contract Codex
fits art against; every number below was **measured off the built model**, not
read out of the source, by running `OrbitOutpost.build` headlessly and taking
oriented, shape-aware bounds. Source: `src/server/Map/OrbitOutpost.luau`. Brief:
`ORBIT-OUTPOST-CLAUDE-HANDOFF.md` beside this file. Approved concept:
`orbit-outpost-v7-gravity-garden.png` (V7 Gravity Garden).

**Nothing has been seen running in Roblox Studio.** See "Limitations" at the end
for the exact list of checks that are still owed.

## Coordinate frame

Everything is in the region-local frame `RegionScenery` supplies,
`CFrame.lookAt(centre, Vector3.new(0, centre.Y, 0))` with
`centre = polar(280, 390)` = `(242.487, 0, 140)`. Verified against MapBuilder
rather than hard-coded: transforming the world gate position `polar(200, 390)`
through that frame gives exactly local `(0, 0, -80)`.

| | |
|---|---|
| Local **-Z** | the hub entrance; the functional `Gate` is at `z = -80`, 20 x 12 x 2 |
| Local **+Z** | the rear, where the gravity cradle stands |
| Local **+X** | image left on walking in: the field laboratory and one drone dock |
| Local **-X** | image right: the utility nook and two drone docks |
| Ring frame | `CFrame.new(sin a * r, 0, -cos a * r) * CFrame.Angles(0, -a, 0)`; +X tangential in the direction of increasing bearing, +Z inward |
| Bearings | 0 entrance, 90 image left, 180 rear, 270 image right |
| Radius / SpawnRadius / AccessRadius | 75 / 44 / 78, unchanged |
| Authored ground top | **y = 0.30**, MapBuilder's own `Ground` disc — this module adds no floor |
| `SceneryVersion` | **3** (was 2) |

## The floor: why there is no ground skin

Every other hand-built region lays a walkable skin over MapBuilder's ground disc
(Thunderworks' asphalt yard tops out at 0.42). Orbit Outpost deliberately does
not, and this is the one finding that changed the plan:

`CaptureController` draws the Gravity Pulse telegraph as `HazardWell`, a
**cylinder 0.3 studs thick centred `origin.Y + 0.16`**, and the creature's
`origin.Y` is the region centre's 0. The disc therefore spans **y 0.01 .. 0.31**
against the ground disc's 0.30 top: it clears the floor by 0.01 of a stud. A
skin of *any* thickness buries it completely.

So the lunar floor is the region's own disc, restyled in place:

| | before | after |
|---|---|---|
| `Regions.list` Cosmic `groundColor` | 45, 40, 70 | **118, 109, 132** |
| `MapBuilder` `GROUND_MATERIAL.Cosmic` | `Metal` | **`Sand`** |

`groundColor` is read in exactly one place, `MapBuilder:557`, so the change is
scoped to this floor and nothing else. The walking height stays **0.30**, and
the violet-grey soil is far enough down in value and saturation from the
telegraph's `(210, 150, 255)` that the circle stays the brightest thing in view.
The `HazardWellColumn` — a 7-wide, 14-tall translucent ball — is unaffected
either way.

**This also applies to Thunderworks**, whose 0.42 yard skin buries the Storm
`HazardPatch` discs by the same arithmetic. It is recorded in RELAY as a
separate finding, not fixed here.

## Heights, at a glance

| Surface | Top y | Notes |
|---|---|---|
| Region ground disc | **0.30** | MapBuilder's; the only floor in the region |
| `DockPad[A-C]` | **1.20** | a 0.90 step up, walkable without stairs |
| `NookPad` | **0.90** | |
| `LabPad` | **2.00** | a 1.70 step |
| `DaisStep` treads | 0.88 .. **4.96** | 8 per flight, 0.5825 rise each |
| `GravityDais` | **5.00** | 0.04 above the top tread |
| `LabCore` | **6.80** | the highest surface a player can stand on |
| `GateShoulder` | 13.00 | |
| `EntryPillarCore` | 14.70 | |
| Rock terrace tops (`Perimeter`) | 9.50 .. 20.40 | see the schedule below |
| Barrier tops (`BarrierField`) | 18.70 .. **26.10** | the containment's real top |
| `CradleProng` (placeholder) | 25.71 | |
| `OrbitStoneMass` (placeholder) | **26.85** | the tallest thing in the region |

## What was built

**463 parts**, 95 of them solid, **6 PointLights**, **51 asset sites**.

| Model | Parts | Owns |
|---|---|---|
| `Boundary` | 73 | containment: it must survive the art pass intact |
| `Walkways` | 22 | every functional walking surface |
| `Landmarks` | 368 | replaceable placeholder art, including `PropSites` |

### Boundary (permanent collision)

| Part | Count | Size | y | plan r | Notes |
|---|---|---|---|---|---|
| `Perimeter` | 33 | 13.62 x h x 3.0 | 0 .. h | 73.5 .. 76.8 | 36-segment ring, i = 2..34, inner face **73.50** |
| `BarrierField` | 33 | 13.62 x fh x 1.3 | h-0.3 .. | 74.35 .. 75.96 | **invisible**, `Transparency = 1`: the collision inside the energy pane |
| `GateShoulder` | 2 | 3.4 x 13 x 18.81 | 0 .. 13.00 | 73.1 .. 82.8 | closes the ring from `(±11.8, -80)` to bearing ±20 at radius 75 |
| `ShoulderField` | 2 | 3.4 x 8.4 x 18.81 | 13.00 .. 21.40 | 73.1 .. 82.8 | invisible, same footprint as the shoulder |
| `EntryPillarCore` | 2 | 5.6 x 15 x 4.4 | -0.30 .. 14.70 | 78.5 .. 83.7 | at `(±13, ·, -80)`, inner face **10.20** |
| `LabCore` | 1 | 15.6 x 4.8 x 15.6 | 2.00 .. 6.80 | 55.5 .. 71.5 | the laboratory's permanent mass, inset 0.2 inside its mesh |

The barrier is deliberately two-tier, and that is the concept, not a compromise.
The visible rock terraces are only 9.5 to 20.4 tall, as they are in the render;
the cyan energy panes above them are `Landmarks` art and could be replaced, so
the containment in that volume is a **named invisible collision core** occupying
exactly the pane's space. Remove every pane and the region is still closed.

### Walkways (functional surfaces)

| Part | Count | Size | Top | Position |
|---|---|---|---|---|
| `GravityDais` | 1 | 21 x 5.4 x 16 | **5.00** | `(0, ·, 63.5)`, radius 55.50 .. 72.27 |
| `DaisStep` | 16 | 5 x top x 1.625 | 0.88 .. 4.96 | two flights at `x = ±13.0`, z 57.5 .. 70.5 |
| `LabPad` | 1 | 21 x 2.4 x 17 | **2.00** | `bearing(114, 63.25)`, radius 54.75 .. 72.51 |
| `DockPadA` | 1 | 13 x 1.5 x 11 | **1.20** | `bearing(67, 61)`, radius 55.50 .. 66.82 |
| `DockPadB` | 1 | 13 x 1.5 x 11 | **1.20** | `bearing(222, 61)` |
| `DockPadC` | 1 | 13 x 1.5 x 11 | **1.20** | `bearing(255, 61)` |
| `NookPad` | 1 | 16 x 1.2 x 11 | **0.90** | `bearing(304, 63)`, radius 57.50 .. 68.97 |

Both dais flights run **tangentially along the dais flanks**, climbing front to
back between radius 58.45 and 72.27, exactly as the brief asks: no ramp runs
down through the capture field. The top tread meets the dais with a 0.04 lip,
which is deliberate — a flush joint would be two coplanar top faces.

## Landmark contracts

### `GravityGarden` — the rear hero

- **Dais**: `Walkways/GravityDais`, **21 x 16** centred `(0, ·, 63.5)`, top
  **5.00**, front face z **55.50**, back face z **71.50**, x ±10.5.
  The brief asked for 23 x 19 at z 63. That slab reaches radius **73.4** at its
  back corners, 0.1 inside the rock terrace face at 73.5, *and* its front face
  would sit at 53.5, inside the flat catching field. 21 x 16 at z 63.5 keeps
  **55.50 in front** and **1.23 behind**. Recorded as agreed, not silently.
- **Cradle** `GravityCradle01`, bottom **y = 5.00** at the dais centre, yaw 0
  (its own +Z faces the entrance). Occupies y 5 .. 27.
- **Meteor** `GravityMeteor01`, lower extent **y = 12.00**, top **23.00**, so it
  has **4.00 studs of head** inside the cradle's 27.
- **Orbit stones** at `(±5.5, 15.0, 63.5)` and `(0, 24.3, 63.5)`, tops 17.4 and
  26.7. The brief's `x = ±5.5, y = 15, z = 63` is used verbatim for the pair;
  the third sits on the cradle's own axis above the meteor, where no prong is.
- The cradle's bounding box legitimately contains the meteor and all three
  stones. That family is the one documented exemption from the "no two placed
  meshes intersect" rule; everything else passes it outright.
- All four are **anchored, static placements**. Nothing here is ever unanchored,
  and no orbit animation is implied.

### `FieldLaboratory` — image left

Bounds: radius 54.50 .. 72.81, y -0.40 .. 15.00.

- Pad `bearing(114, 63.25)`, 21 x 17, top **2.00**, radius 54.75 .. 72.51.
- `Boundary/LabCore` 15.6 x 4.8 x 15.6, y **2.00 .. 6.80**: the permanent mass
  inside `OO_Field_Lab_Base`, inset 0.2 all round so no face is coplanar with
  the mesh and so nothing can walk into the closed building.
- `FieldLabBase01` at y 2.00, `FieldLabDome01` **stacked** at y 7.00 with
  `StackOnSite = FieldLabBase01`; both share the pad's XZ centre and yaw 66.
- **`LabGlazing` is ours and is kept through the art pass.** It is a single
  sphere part carrying a `SpecialMesh` scaled `(1, 0.8125, 1)`, centred at
  y 7.00, so it renders as a radius-8 dome rising **6.5 above the lab base**,
  matching `OO_Field_Lab_Dome_Frame` exactly. `Transparency 0.58`, `Glass`,
  `CanCollide` and `CanQuery` false. Its lower half is inside the opaque base
  and the core, which is how a Roblox dome is built. Measured bounds read
  16 x 16 x 16 because the part is a sphere and the squash lives in the mesh.
- The dome placeholder is **six thin ribs and a crown**, not a shell, so no
  opaque dummy dome fights the glazing.
- Closed facade only: the three lit windows are geometry, two of them carrying a
  PointLight. No door, no prompt, no interior, no shop.

### `SurveyDocks` — three pads

`bearing(67 / 222 / 255, 61)`, each 13 x 11 with a top at **1.20**, radius
55.50 .. 66.82. Each carries a grounded `OO_Drone_Dock` at y 1.20, an
`OO_Survey_Drone` **stacked** on it at y 2.70, and one grounded `OO_Sample_Pod`
at y 1.20 offset 4.6 tangentially and 2.4 inward.

### `UtilityNook` — image right

`bearing(304, 63)`, pad 16 x 11, top **0.90**, radius 57.50 .. 68.97. Two teal
cabinets, a tank, a cable drum, two crates and a canopy on two posts, with one
PointLight under the canopy. **This is blockout only and claims no asset site**:
the Thunderworks meshes are not part of the Orbit Outpost kit, and the brief
says the nook must not dominate the garden. It is 20 parts.

### `ResearchGateway` — the entrance

Bounds: radius 77.6 .. 84.53, y -1.30 .. 16.30.

| Element | Position | Size |
|---|---|---|
| Pier cores (solid) | `(±13, 7.2, -80)` | 5.6 x 15 x 4.4, y -0.30 .. 14.70 |
| **Opening between the pillars** | | **20.40 studs** clear (x -10.20 .. 10.20) |
| Shaft / chamfer / cap / crown | `(±13, ·, -80)` | ivory marble, top 16.30 |
| `PillarLamp` (warm, 2 of the 6 lights) | `(±10.55, 7.0, -80)` | 0.36 x 6.6 x 0.9, y 3.70 .. 10.30 |
| `GatewayRock` | `(±19.5, 1.5, -77.5)` | decoration outside the ring |

There is **no lintel**: the concept frames the way in with the pair alone. That
is why `Cosmic` now joins MapBuilder's `OWN_ENTRANCE` set, so the industrial
`GatePost` / `GateLintel` / `hazardStrip` trim is skipped — those posts stood at
x ±11 and would have interpenetrated these pillars. `Gate`, `Entrance`,
`UnlockPrompt`, `GateSign`, `GateSignStand`, the `RegionGate` tag and the
`RegionId` / `Element` / `Centre` / `SpawnRadius` / `AccessRadius` attributes are
all untouched.

### Terrace and barrier schedule

36 tangential segments on radius 75, i = 2..34, chord 13.62, rock depth 3.0.
Every segment carries a rock core, an invisible barrier field, a cyan pane, an
ivory post on its join and a lamp strip; every third also gets a shelf and two
banked boulders, and the others one boulder.

| i | bearing | rock top | barrier height | barrier top | shelf | pane height |
|---|---|---|---|---|---|---|
| 2 | 20 | 11.3 | 9.5 | 20.5 | no | 8.3 |
| 3 | 30 | 9.5 | 9.5 | 18.7 | yes | 8.3 |
| 4 | 40 | 10.4 | 9.5 | 19.6 | no | 8.3 |
| 5 | 50 | 13.4 | 8.0 | 21.1 | no | 6.8 |
| 6 | 60 | 12.6 | 8.0 | 20.3 | yes | 6.8 |
| 7 | 70 | 18.2 | 6.0 | 23.9 | no | 4.8 |
| 8 | 80 | 19.3 | 6.0 | 25.0 | no | 4.8 |
| 9 | 90 | 20.4 | 6.0 | 26.1 | yes | 4.8 |
| 10 | 100 | 16.0 | 6.0 | 21.7 | no | 4.8 |
| 11 | 110 | 17.1 | 6.0 | 22.8 | no | 4.8 |
| 12 | 120 | 18.2 | 6.0 | 23.9 | yes | 4.8 |
| 13 | 130 | 19.3 | 6.0 | 25.0 | no | 4.8 |
| 14 | 140 | 20.4 | 6.0 | 26.1 | no | 4.8 |
| 15 | 150 | 16.0 | 6.0 | 21.7 | yes | 4.8 |
| 16 | 160 | 17.1 | 6.0 | 22.8 | no | 4.8 |
| 17 | 170 | 18.2 | 6.0 | 23.9 | no | 4.8 |
| 18 | 180 | 19.3 | 6.0 | 25.0 | yes | 4.8 |
| 19 | 190 | 20.4 | 6.0 | 26.1 | no | 4.8 |
| 20 | 200 | 16.0 | 6.0 | 21.7 | no | 4.8 |
| 21 | 210 | 17.1 | 6.0 | 22.8 | yes | 4.8 |
| 22 | 220 | 18.2 | 6.0 | 23.9 | no | 4.8 |
| 23 | 230 | 19.3 | 6.0 | 25.0 | no | 4.8 |
| 24 | 240 | 20.4 | 6.0 | 26.1 | yes | 4.8 |
| 25 | 250 | 16.0 | 6.0 | 21.7 | no | 4.8 |
| 26 | 260 | 17.1 | 6.0 | 22.8 | no | 4.8 |
| 27 | 270 | 18.2 | 6.0 | 23.9 | yes | 4.8 |
| 28 | 280 | 19.3 | 6.0 | 25.0 | no | 4.8 |
| 29 | 290 | 20.4 | 6.0 | 26.1 | no | 4.8 |
| 30 | 300 | 12.6 | 8.0 | 20.3 | yes | 6.8 |
| 31 | 310 | 13.4 | 8.0 | 21.1 | no | 6.8 |
| 32 | 320 | 11.3 | 9.5 | 20.5 | no | 8.3 |
| 33 | 330 | 9.5 | 9.5 | 18.7 | yes | 8.3 |
| 34 | 340 | 10.4 | 9.5 | 19.6 | no | 8.3 |

The low run either side of the entrance bottoms out at **9.50**, and that number
is load-bearing: a character on the 0.30 floor reaches about 7.2 studs, so
anything under 7.50 would be one hop onto the containment. The side and rear
band was raised from 15.0 to **16.0** for the same reason — the 6.80 laboratory
roof sits 2.25 studs from the wall face, and a 15.0 wall left only 1.0 stud of
margin over that reach.

## Asset site table

`Landmarks/PropSites`, `AssetCount = 51`, `AssetKit = assets/orbit-outpost/props-v1`,
`AssetOrigin = bottom-centre`. Every site is one Model carrying `AssetName`,
`AssetSize`, region-local `GroundCF`, `PivotMode = "BottomCenter"`,
`CollisionRole = "none"`, `PlacementRole` and `SupportPath`, with its stand-in
confined to a `PlaceholderArt` child Model.

**Placement is** `mesh.CFrame = frame * GroundCF * CFrame.new(0, AssetSize.Y / 2, 0)`.
Do not move the site to world coordinates and do not apply `frame` twice.

`PlacementRole` says what `GroundCF` means and what holds the asset up:

| Role | `GroundCF` is | `SupportPath` names |
|---|---|---|
| `Grounded` | the bottom of the mesh, resting on a real surface | the permanent part under it |
| `Stacked` | the bottom of the mesh, resting on another site's top | the permanent part under the stack; `StackOnSite` names the site |
| `Suspended` | the intended **lower extent** of a floating mesh | the landmark it hangs against; there is no surface beneath it |

`Yaw` is the site frame's heading in degrees (the mesh's own +Z faces that way);
`r / bearing` is where it sits in the ring.

| Site | AssetName | AssetSize | GroundCF position | Yaw | r / bearing | Role | SupportPath |
|---|---|---|---|---|---|---|---|
| `AlienFern01` | OO_Alien_Fern | 4 x 3 x 4 | 25.43, 0.3, -52.13 | -177.4 | 58 / 26 | Grounded | `Ground` |
| `AlienFern02` | OO_Alien_Fern | 4 x 3 x 4 | 46.32, 0.3, -34.91 | 86.9 | 58 / 53 | Grounded | `Ground` |
| `AlienFern03` | OO_Alien_Fern | 4 x 3 x 4 | 28.12, 0.3, 50.73 | 46.2 | 58 / 151 | Grounded | `Ground` |
| `AlienFern04` | OO_Alien_Fern | 4 x 3 x 4 | -57.96, 0.3, -2.02 | -114.9 | 58 / 272 | Grounded | `Ground` |
| `AlienFern05` | OO_Alien_Fern | 4 x 3 x 4 | -35.71, 0.3, -45.7 | -96.2 | 58 / 322 | Grounded | `Ground` |
| `CosmicBeacon01` | OO_Cosmic_Beacon | 1.2 x 3 x 1.2 | -11, 0.3, -66 | -90 | 66.9 / 350.5 | Grounded | `Ground` |
| `CosmicBeacon02` | OO_Cosmic_Beacon | 1.2 x 3 x 1.2 | -11, 0.3, -56 | -90 | 57.1 / 348.9 | Grounded | `Ground` |
| `CosmicBeacon03` | OO_Cosmic_Beacon | 1.2 x 3 x 1.2 | -13, 0.3, 55.8 | -180 | 57.3 / 193.1 | Grounded | `Ground` |
| `CosmicBeacon04` | OO_Cosmic_Beacon | 1.2 x 3 x 1.2 | 11, 0.3, -66 | 90 | 66.9 / 9.5 | Grounded | `Ground` |
| `CosmicBeacon05` | OO_Cosmic_Beacon | 1.2 x 3 x 1.2 | 11, 0.3, -56 | 90 | 57.1 / 11.1 | Grounded | `Ground` |
| `CosmicBeacon06` | OO_Cosmic_Beacon | 1.2 x 3 x 1.2 | 13, 0.3, 55.8 | -180 | 57.3 / 166.9 | Grounded | `Ground` |
| `CrystalCluster01` | OO_Crystal_Cluster | 4 x 5 x 4 | 32.24, 0.3, -58.16 | 173.9 | 66.5 / 29 | Grounded | `Ground` |
| `CrystalCluster02` | OO_Crystal_Cluster | 4 x 5 x 4 | 48.64, 0.3, -45.35 | 104.4 | 66.5 / 47 | Grounded | `Ground` |
| `CrystalCluster03` | OO_Crystal_Cluster | 4 x 5 x 4 | 50.94, 0.3, 42.75 | 101.6 | 66.5 / 130 | Grounded | `Ground` |
| `CrystalCluster04` | OO_Crystal_Cluster | 4 x 5 x 4 | 25.98, 0.3, 61.21 | 11.5 | 66.5 / 157 | Grounded | `Ground` |
| `CrystalCluster05` | OO_Crystal_Cluster | 4 x 5 x 4 | -55.77, 0.3, 36.22 | -22.6 | 66.5 / 237 | Grounded | `Ground` |
| `CrystalCluster06` | OO_Crystal_Cluster | 4 x 5 x 4 | -33.25, 0.3, -57.59 | 164.2 | 66.5 / 330 | Grounded | `Ground` |
| `DroneDock01` | OO_Drone_Dock | 5 x 1.5 x 5 | 57.07, 1.2, -24.23 | 113 | 62 / 67 | Grounded | `Walkways/DockPadA` |
| `DroneDock02` | OO_Drone_Dock | 5 x 1.5 x 5 | -41.49, 1.2, 46.07 | -42 | 62 / 222 | Grounded | `Walkways/DockPadB` |
| `DroneDock03` | OO_Drone_Dock | 5 x 1.5 x 5 | -59.89, 1.2, 16.05 | -75 | 62 / 255 | Grounded | `Walkways/DockPadC` |
| `FieldLabBase01` | OO_Field_Lab_Base | 16 x 5 x 16 | 57.78, 2, 25.73 | 66 | 63.3 / 114 | Grounded | `Walkways/LabPad` |
| `FieldLabDome01` | OO_Field_Lab_Dome_Frame | 16 x 6.5 x 16 | 57.78, 7, 25.73 | 66 | 63.3 / 114 | Stacked on `FieldLabBase01` | `Walkways/LabPad` |
| `GravityCradle01` | OO_Gravity_Cradle | 16 x 22 x 16 | 0, 5, 63.5 | 0 | 63.5 / 180 | Grounded | `Walkways/GravityDais` |
| `GravityMeteor01` | OO_Gravity_Meteor | 6 x 11 x 6 | 0, 12, 63.5 | -151.4 | 63.5 / 180 | Suspended | `Landmarks/PropSites/GravityCradle01` |
| `LunarBoulder01` | OO_Lunar_Boulder | 8 x 4 x 6 | 22.74, 0.3, -62.49 | 177.2 | 66.5 / 20 | Grounded | `Ground` |
| `LunarBoulder02` | OO_Lunar_Boulder | 8 x 4 x 6 | 54.47, 0.3, -38.14 | 102.1 | 66.5 / 55 | Grounded | `Ground` |
| `LunarBoulder03` | OO_Lunar_Boulder | 8 x 4 x 6 | 66.41, 0.3, -3.48 | 138.8 | 66.5 / 87 | Grounded | `Ground` |
| `LunarBoulder04` | OO_Lunar_Boulder | 8 x 4 x 6 | 43.63, 0.3, 50.19 | 6.6 | 66.5 / 139 | Grounded | `Ground` |
| `LunarBoulder05` | OO_Lunar_Boulder | 8 x 4 x 6 | -28.1, 0.3, 60.27 | -13.5 | 66.5 / 205 | Grounded | `Ground` |
| `LunarBoulder06` | OO_Lunar_Boulder | 8 x 4 x 6 | -66.46, 0.3, 2.32 | -139.6 | 66.5 / 268 | Grounded | `Ground` |
| `MushroomCluster01` | OO_Alien_Mushroom_Cluster | 4 x 3 x 3 | 40.29, 0.3, -41.72 | 118.8 | 58 / 44 | Grounded | `Ground` |
| `MushroomCluster02` | OO_Alien_Mushroom_Cluster | 4 x 3 x 3 | 58, 0.3, 0 | 130.1 | 58 / 90 | Grounded | `Ground` |
| `MushroomCluster03` | OO_Alien_Mushroom_Cluster | 4 x 3 x 3 | 35.71, 0.3, 45.7 | 9.4 | 58 / 142 | Grounded | `Ground` |
| `MushroomCluster04` | OO_Alien_Mushroom_Cluster | 4 x 3 x 3 | -50.73, 0.3, 28.12 | -38.1 | 58 / 241 | Grounded | `Ground` |
| `MushroomTall01` | OO_Alien_Mushroom_Tall | 6 x 7 x 5 | 40.94, 0.3, -52.4 | 153.5 | 66.5 / 38 | Grounded | `Ground` |
| `MushroomTall02` | OO_Alien_Mushroom_Tall | 6 x 7 x 5 | 66.14, 0.3, 6.95 | 49.6 | 66.5 / 96 | Grounded | `Ground` |
| `MushroomTall03` | OO_Alien_Mushroom_Tall | 6 x 7 x 5 | 35.24, 0.3, 56.4 | 60.6 | 66.5 / 148 | Grounded | `Ground` |
| `OrbitStone01` | OO_Orbit_Stone | 2.8 x 2.4 x 2.6 | -5.5, 15, 63.5 | 85.5 | 63.7 / 185 | Suspended | `Landmarks/PropSites/GravityCradle01` |
| `OrbitStone02` | OO_Orbit_Stone | 2.8 x 2.4 x 2.6 | 5.5, 15, 63.5 | -85.5 | 63.7 / 175 | Suspended | `Landmarks/PropSites/GravityCradle01` |
| `OrbitStone03` | OO_Orbit_Stone | 2.8 x 2.4 x 2.6 | 0, 24.3, 63.5 | -180 | 63.5 / 180 | Suspended | `Landmarks/PropSites/GravityCradle01` |
| `SamplePod01` | OO_Sample_Pod | 3 x 4 x 3 | 55.74, 1.2, -18.66 | 95.8 | 58.8 / 71.5 | Grounded | `Walkways/DockPadA` |
| `SamplePod02` | OO_Sample_Pod | 3 x 4 x 3 | -42.63, 1.2, 40.47 | -59.2 | 58.8 / 226.5 | Grounded | `Walkways/DockPadB` |
| `SamplePod03` | OO_Sample_Pod | 3 x 4 x 3 | -57.79, 1.2, 10.72 | -92.2 | 58.8 / 259.5 | Grounded | `Walkways/DockPadC` |
| `StarBloom01` | OO_Star_Bloom_Tuft | 3 x 1.2 x 3 | 33.27, 0.3, -47.51 | 156.5 | 58 / 35 | Grounded | `Ground` |
| `StarBloom02` | OO_Star_Bloom_Tuft | 3 x 1.2 x 3 | 57.29, 0.3, -9.07 | 70.4 | 58 / 81 | Grounded | `Ground` |
| `StarBloom03` | OO_Star_Bloom_Tuft | 3 x 1.2 x 3 | 42.42, 0.3, 39.56 | 87.1 | 58 / 133 | Grounded | `Ground` |
| `StarBloom04` | OO_Star_Bloom_Tuft | 3 x 1.2 x 3 | -28.12, 0.3, 50.73 | -46.2 | 58 / 209 | Grounded | `Ground` |
| `StarBloom05` | OO_Star_Bloom_Tuft | 3 x 1.2 x 3 | -56.93, 0.3, -11.07 | -66.6 | 58 / 281 | Grounded | `Ground` |
| `SurveyDrone01` | OO_Survey_Drone | 3.2 x 2.8 x 3.2 | 57.07, 2.7, -24.23 | 113 | 62 / 67 | Stacked on `DroneDock01` | `Walkways/DockPadA` |
| `SurveyDrone02` | OO_Survey_Drone | 3.2 x 2.8 x 3.2 | -41.49, 2.7, 46.07 | -42 | 62 / 222 | Stacked on `DroneDock02` | `Walkways/DockPadB` |
| `SurveyDrone03` | OO_Survey_Drone | 3.2 x 2.8 x 3.2 | -59.89, 2.7, 16.05 | -75 | 62 / 255 | Stacked on `DroneDock03` | `Walkways/DockPadC` |

Counts by asset: Alien_Fern 5, Alien_Mushroom_Cluster 4, Alien_Mushroom_Tall 3,
Cosmic_Beacon 6, Crystal_Cluster 6, Drone_Dock 3, Field_Lab_Base 1,
Field_Lab_Dome_Frame 1, Gravity_Cradle 1, Gravity_Meteor 1, Lunar_Boulder 6,
Orbit_Stone 3, Sample_Pod 3, Star_Bloom_Tuft 5, Survey_Drone 3.
**All fifteen assets are used**, and there is exactly one cradle, one meteor, one
lab base and one lab dome frame.

`SupportPath = "Ground"` means MapBuilder's own region floor disc, which is
permanent and is the surface the garden stands on.

The garden is laid out in **two radial bands, not a scatter**: the big growth
(boulders, crystals, tall mushrooms) on the outer band at **radius 66.5**, the
low growth (ferns, blooms, small clusters) on the inner band at **58.0**. That
guarantees 0.7 studs of radial clearance between bands whatever the bearings,
and within a band bearings are at least 8 degrees apart — 9.3 studs at 66.5,
against the 7.8 an 8 x 6 boulder needs beside a crystal. Every bearing falls in
an arc the dais, the laboratory, the three dock pads and the nook leave open.

## Collision ownership

| Concern | Who owns it | Survives the art pass? |
|---|---|---|
| Rock terrace ring | `Boundary/Perimeter` | yes, do not remove |
| The barrier above the rock | `Boundary/BarrierField` (invisible) | yes — the cyan panes are art |
| Entrance closure | `Boundary/GateShoulder`, `ShoulderField`, `EntryPillarCore` + MapBuilder's `Gate` | yes |
| The laboratory's mass | `Boundary/LabCore` | yes |
| Every walking surface | all of `Walkways` | yes |
| The lab's glass dome | `Landmarks/FieldLaboratory/LabGlazing` | **yes — ours, keep it** |
| Everything else | `Landmarks` | no, all of it is replaceable |

Decoration defaults to anchored, `CanCollide` false, `CanTouch` false,
`CanQuery` false and `CastShadow` false. **No non-solid part is queryable**, so
no placeholder and no energy pane can absorb a capture ray or one of the 27
sightline rays cast at the region board. The only collision proxies are the
Boundary and Walkways parts listed above.

## Clearances

| Constraint | Target | Measured |
|---|---|---|
| Solid scenery inside the spawn radius | none inside 44 | nearest solid footprint at **54.75** (`LabPad`) |
| Same, by the live test's own AABB rule | none inside 44 | **47.47** (`LabPad`) |
| Standing scenery inside the flat field | none inside 54 | nearest at **54.50** (`LabPadRim`) |
| Approach corridor through the gate | ≥ 20 studs | **20.00** (`PillarFoot` at x ±10) |
| Footprints inside the ring | ≤ 77.5 | **76.80** (`Perimeter`, on the ring itself) |
| Gate furniture outside the disc | expected, as in every region | 84.53 (`PillarFoot` at z -80) |
| Board box overlap | zero | **0 parts** intersect `(24, 10, -90)` 18 x 10 x 0.65 |
| Board sightlines | all 27 clear | **0 blocking hits** |
| Road clearance, walk-into structure | ≥ 2 studs | smallest **3.25** (`PillarFoot`) |
| Road clearance, overhead structure | headroom | 12.475 (`PillarCap`, `ShoulderField`) |
| Crisis arena | clear | nearest part 306.7 from its centre, 272.7 clear |
| Thunderworks / Gusty Gardens | clear | 203.5 from each centre, 125.5 clear |
| Nearest city plot | clear | 91.0 from its centre, 59.0 clear |
| Coplanar top faces | none | **0 pairs** across all 463 parts |
| Placed meshes intersecting each other | none | **0** (cradle/meteor/stones exempt, see above) |
| Placed meshes inside permanent collision | none | **0** (`LabCore` inside its own base exempt) |
| Grounded sites resting on a real surface | all | **0 unsupported, 0 overhanging** |
| Stacked sites landing on the site they name | all | **0 bad stacks** |

There are **no approach decorations outside the gate** beyond the two
`GatewayRock` blocks beside the pillars. Frostbite's props landed on the Crisis
spur; rather than repeat that risk for no art gain, the outside of the entrance
is otherwise left as plain world ground and road.

## Containment

The ring was probed radially at **0.25-degree steps all the way round, at six
heights (y 1.5, 4.0, 8.0, 11.5, 15.0, 18.0)**, from radius **72.3** — outside
every interior landmark, so the dais or a pad can never stand in for a missing
wall segment — out to radius 100, against every solid part plus MapBuilder's own
`Gate`: **zero gaps**.

The 114 open samples above y 12 within 16 degrees of the entrance axis are the
doorway over the 12-stud `Gate`, which is open in every region. No character can
reach it: the two pillar cores beside it top out at 14.70 and are themselves
unreachable.

Escape was checked as a reachability search, not a spot check: start standing on
the 0.30 floor, and repeatedly step onto any solid surface whose top is within
**7.2 studs** vertically (a default Roblox jump clears 6.37) and **4.0 studs**
horizontally.

- Highest surface reachable from the floor: **6.80** (`LabCore`, the lab roof).
- Lowest containment top: **9.50** (`Perimeter`, the low run beside the gate).
- No containment surface is reached. The smallest unclimbed step from any
  reachable surface onto containment is **9.20 studs**, against a 7.2 reach —
  **2.00 studs of margin**.

Two findings drove real geometry changes here, both caught before Studio:

1. The side and rear band was 15.0 to 19.4. The laboratory roof tops out at 6.80
   and sits 2.25 studs from the wall face, so the wall was only 8.2 above it —
   1.0 stud inside a pessimistic jump. The band is now **16.0 to 20.4**.
2. The gate shoulders were 10.0 tall with a 1.3-deep field above them, and at
   y 11.5 a probe threaded the 0.8-stud slot between the `Gate` edge and the
   pillar. The shoulder core is now **13.0 tall**, its field is the same **3.4
   deep** as the core, and the pillar cores were widened to 5.6 so their inner
   face reaches x 10.2.

## Hazard readability

Cosmic's `Gravity Pulse` is unchanged: pale lavender `(210, 150, 255)`,
telegraph 1.6 s, active 0.4 s, radius 7, spawnRadius 8, pullStrength 9, plus
whatever `Capture.zoneTuning` row 6 adds. The floor it is drawn on is the
recoloured ground disc:

| Surface | Colour | Material |
|---|---|---|
| Region ground (MapBuilder) | **118, 109, 132** | **Sand** |
| Rock terraces | 96, 89, 112 | Rock |
| Dais, pads, steps | 129, 121, 146 | Rock |

Nothing bright violet, cyan or neon sits on or inside the catching field: the
amethyst crystals, the purple mushrooms and the cyan barrier lamps all live
beyond radius 54, and the nearest of them is 56.0 (`BloomMat`, which is 0.3
proud of the floor and 2 studs outside the flat field).

**One honest caveat.** A pull zone is placed at the creature's position plus 8
studs toward the player, and the creature roams inside radius 44, so the far
edge of a 7-radius telegraph disc can in principle reach radius 59. Between 54.5
and 59 it would be partly hidden behind a terrace apron. The tall
`HazardWellColumn` is unaffected and remains the dominant read.

## Limitations

- **Nothing has been seen in Roblox Studio.** No `[SelfTest]` / `[LiveTest]`
  numbers from this session, no visual review under game lighting, no
  screenshot, no top-down capture, and the Gravity Pulse telegraph has not been
  watched playing over this floor — the readability argument above is from
  measured geometry and colour values, not from a capture. A Rojo server is
  running on port 34872 and Studio is open, but this session had no bridge to
  it and could not confirm whether Play was stopped.
- The cradle, meteor, orbit stones, laboratory, dome, drones, docks, pods and
  the whole garden are **placeholders built to the manifest bounding box**, so
  the swap to a MeshPart is one for one. None of them is finished art.
- Mobile cost of 463 static parts is unmeasured.
- The terrace boulders and every other `Landmarks` rock are **non-colliding**,
  as in every other region, so a player can walk through them into the wall.
  Making them solid would have put a step under the containment.
- The concept's cosmic sky, floating distant islands, particles and any orbit
  animation are **not built**; the brief defers them to a later atmosphere pass,
  and global `Lighting` / `Sky` were not touched.
- The utility nook reuses the teal kit as blockout geometry only. If Codex ever
  wants the Thunderworks meshes there, it needs its own sites; none were created.
- No commits, no publishing, no uploads, no asset IDs invented, and nothing under
  `assets/` or `tools/blender/` was touched.

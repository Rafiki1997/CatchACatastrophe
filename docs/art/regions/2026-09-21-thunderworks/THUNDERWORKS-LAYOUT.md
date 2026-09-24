# Thunderworks measured layout

## Integration update — 2026-09-21

All 33 sites now use the eight uploaded native mesh types in ThunderPropTemplates.
Each site retains its contract attributes and now includes PivotMode=BottomCenter,
PlacementRole=Grounded and AssetPlaced=true. Only its PlaceholderArt was removed.
Boundary, Walkways/supports, collector towers, shed, catwalk and six lights remain.

The historical floor measurements below have these explicit overrides: YardSkin
was removed because its 0.42 top buried lightning warning discs (top 0.31).
Ground is Asphalt at top 0.30, colour 78/84/99. YardSeam/YardScuff/YardDrain are
non-colliding marks with tops 0.302/0.304/0.306. CableReelSite03 and Site04 have
GroundCF.Y=0.30 and SupportPath="Ground"; other site frames are unchanged.
Runtime tests verify native placements, support, field/road clearance and light
budget; 970 self-tests and 72 live tests pass. The warnings were visually verified
using the actual client renderer. No changes to hazard hit rules or progression.

## Original measured base layout

The base region is built and validated. This is the dimensioned contract Codex
fits art against; every number below was **measured off the built model**, not
read out of the source, by running `Thunderworks.build` headlessly and taking
oriented bounds. Source: `src/server/Map/Thunderworks.luau`. Brief:
`THUNDERWORKS-CLAUDE-HANDOFF.md` beside this file.

There is no approved Thunderworks concept image. The look is the written art
direction in the handoff — a chunky, weathered storm-powered electrical yard —
and nothing here should be described as matching an approved mockup.

Plan: `thunderworks-layout-plan.svg` (region-local, +X right, +Z down).

## Coordinate frame

Everything is in the region-local frame `RegionScenery` supplies,
`CFrame.lookAt(centre, Vector3.new(0, centre.Y, 0))` with
`centre = polar(280, 330)` = `(242.487, 0, -140)`. Verified against MapBuilder,
not hard-coded: transforming the world gate position `polar(200, 330)` through
that frame gives exactly local `(0, 0, -80)`.

| | |
|---|---|
| Local **-Z** | the hub entrance; the functional `Gate` is at `z = -80`, 20 x 12 x 2 |
| Local **+Z** | the rear, where the collectors stand |
| Local **+X** | image left on walking in: the maintenance catwalk and cable trench |
| Local **-X** | image right: the control shed and its service apron |
| Ring frame | `CFrame.new(sin a * r, 0, -cos a * r) * CFrame.Angles(0, -a, 0)`; +X tangential in the direction of increasing bearing, +Z inward |
| Bearings | 0 entrance, 90 image left, 180 rear, 270 image right |
| Radius / SpawnRadius / AccessRadius | 75 / 44 / 78, unchanged |
| Authored ground top | y = 0.30 (the region's own `Ground` disc) |
| `SceneryVersion` | **3** (was 2) |

## Heights, at a glance

| Surface | Top y | Notes |
|---|---|---|
| Region ground disc | 0.30 | MapBuilder's, untouched |
| `YardSkin` asphalt | **0.42** | the walkable yard; 0.105 *below* the guidance road slab at 0.525 |
| Yard scuff / seams / drains | 0.485 / 0.53 / 0.50 | flat decoration, all buried into the skin |
| `ServicePad[A-D]`, `GeneratorSupport[LR]` | **0.67** | equipment pads |
| `ServiceApron` (shed) | **0.70** | |
| `TrenchCover` | 0.72 / 0.76 | alternating, so no two covers share a top face |
| `TrenchKerb` | 0.95 / 1.00 | |
| `GeneratorPlinth` | **1.90** | a 1.48 step up from the yard, walkable without stairs |
| `CollectorPedestal` | 5.50 | solid |
| `CatStep` treads | 1.02 .. **6.42** | 10 per flight, 0.60 rise each |
| `CatDeck` | **6.48 / 6.51** | 6.09 above the yard |
| `CatKerb` | 7.38 / 7.41 | the highest surface a player can stand on |
| `GeneratorHousing` | 7.30 | solid |
| `ShedCore` | 9.50 | solid |
| Gate shoulders | 12.50 core, 13.30 coping | the lowest containment |
| Retaining wall | 12.50 .. 23.60 core, +0.80 coping | see the segment table |
| Portal header underside | **16.00** | 15.475 of headroom over the roadbed |
| Collector top (`Finial`) | **35.80** | the tallest thing in the region |

## What was built

683 parts, 234 of them solid, 6 PointLights, 33 asset sites.

| Model | Parts | Owns |
|---|---|---|
| `Boundary` | 122 | containment: it must survive the art pass intact |
| `Walkways` | 112 | every functional walking surface |
| `Landmarks` | 449 | replaceable placeholder art, including `PropSites` |

### Boundary (permanent collision)

| Part | Count | Size | Notes |
|---|---|---|---|
| `Perimeter` | 45 | 10.33 x h x 3.6 | 48-segment ring, i = 2..46, inner face at radius **73.20** |
| `WallCoping` | 45 | 10.49 x 1.0 x 4.2 | starts 0.20 below the core top, never level with it |
| `WallButtress` | 22 | 2.3 x (h + 0.55) x 2.2 | full-height pilasters in pairs, inner face radius **71.32** |
| `GateShoulder` | 2 | 3.6 x 13 x 12.94 | closes the ring from `(±11.5, -80)` to bearing ±15 at radius 75 |
| `ShoulderCoping` | 2 | 4.2 x 1.0 x 12.94 | |
| `PortalPierCore` | 2 | 4.6 x 17 x 4.6 | at `(±13, 8.2, -80)`, y -0.30 .. 16.70 |
| `ShedCore` | 1 | 18 x 9.2 x 9 | at `bearing(270, 67.25)`, y 0.30 .. 9.50 |
| `GeneratorHousing` | 1 | 11 x 5.4 x 8 | at `(0, 4.6, 66.5)`, y 1.90 .. 7.30 |
| `Collector[LR]Pedestal` | 2 | 7.4 x 3.8 x 7.4 | at `(±9.5, 3.6, 66.5)`, y 1.70 .. 5.50 |

The buttresses are deliberately **full height**. A half-height bracket would
have been a step from the catwalk onto the coping; see "Containment" below.

### Walkways (functional surfaces)

| Part | Count | Size | Top | Notes |
|---|---|---|---|---|
| `YardSkin` | 1 | cylinder, d 147, t 0.6 | 0.42 | one asphalt skin over the whole disc |
| `ServicePadA` | 1 | 13 x 0.7 x 9 | 0.67 | `bearing(34, 64)` |
| `ServicePadB` | 1 | 12 x 0.7 x 8.5 | 0.67 | `bearing(138, 64)` |
| `ServicePadC` | 1 | 12 x 0.7 x 8.5 | 0.67 | `bearing(224, 64)` |
| `ServicePadD` | 1 | 13 x 0.7 x 9 | 0.67 | `bearing(320, 64)` |
| `GeneratorSupportL` | 1 | 10 x 0.7 x 8 | 0.67 | `bearing(160, 64)` |
| `GeneratorSupportR` | 1 | 10 x 0.7 x 8 | 0.67 | `bearing(200, 64)` |
| `ServiceApron` | 1 | 24 x 0.9 x 13.5 | 0.70 | `bearing(270, 65.25)`, radius 58.50 .. 72.99 |
| `GeneratorPlinth` | 1 | 28 x 2.0 x 12 | 1.90 | `(0, 0.9, 65.5)`, z 59.5 .. 71.5, radius 59.50 .. 72.86 |
| `CatStep` | 20 | 1.82 x top x 9 | 1.02..6.42 | two flights of ten |
| `CatStepKerb` | 40 | 1.82 x (top+0.75) x 0.7 | | both sides of every tread |
| `CatDeck` | 5 | 6.40 x 0.8 x 9 | 6.48/6.51 | |
| `CatKerb` | 10 | 6.40 x 0.9 x 0.7 | 7.38/7.41 | |
| `CatLeg` | 12 | 1.0 x 5.9 x 1.0 | 5.90 | straddle the trench at ring z ±3.8 |
| `TrenchKerb` | 8 | 9.12 x 0.75 x 0.8 | 0.95/1.00 | ring z ±2.2 |
| `TrenchCover` | 8 | 4.58 x 0.45 x 4.2 | 0.72/0.76 | the trench is closed; there is no hole and no new fall |

## Landmark contracts

Each of these is its own named submodel under `Landmarks`, with its own frame.
"Permanent" means the Boundary/Walkways parts listed above; everything else in
the submodel is replaceable placeholder art.

### `GeneratorYard` — the rear hero (104 parts)

Bounds: x -16.92 .. 16.92, y 1.88 .. 35.80, z 59.40 .. 73.60.

- **Plinth**: `Walkways/GeneratorPlinth`, 28 x 2.0 x 12 centred `(0, 0.9, 65.5)`.
  Top **1.90**, front edge z **59.50**, back edge z **71.50**, x ±14.
  `PlinthNosing` marks the front lip at z 59.40 .. 60.20.
- **Collectors**, two, at `(±9.5, ·, 66.5)`. Per tower, bottom up:
  | Element | y | Size / diameter |
  |---|---|---|
  | `Pedestal` (solid) | 1.70 .. 5.50 | 7.4 x 3.8 x 7.4 |
  | `PedestalCap` | 5.40 .. 6.00 | 8.0 x 0.6 x 8.0 |
  | `Neck` x3 ceramic discs | 5.75 .. 9.85 | d 5.4 / 5.0 / 4.6, each 1.5 tall, pitch 1.3 |
  | `Collar` copper | 9.75 .. 10.45 | 4.4 x 0.7 x 4.4 |
  | `Mast` | 10.40 .. 30.40 | 3.0 square, 6 diagonal braces |
  | `Ring` A, 10 mitred copper segments | centre **16.00** | ring radius **6.50**, tube 1.20/1.14 |
  | `Ring` B, 10 segments | centre **23.50** | ring radius **5.00**, tube 1.00/0.94 |
  | `Gantry` | 24.30 .. 24.90 | 2.2 x 0.6 x 7.2 |
  | `Crown` ball | 29.20 .. 34.00 | d 4.8 |
  | `Finial` | 33.80 .. **35.80** | d 0.7 |
- **Overhead bus**: three copper tubes, d 0.75, length 21, at y **26.50**,
  z **64.9 / 66.5 / 68.1**, running x -10.5 .. 10.5. Each is carried at
  x = ±9.5 by a `BusInsulator` (d 1.3, y 24.90 .. 26.30) standing on the gantry.
  These six insulator tops are the bus attachment points.
- **Generator housing** (solid): 11 x 5.4 x 8 at `(0, 4.6, 66.5)`, top 7.30,
  with four ribs, a lid at 7.20 .. 7.90, two louvred vents on its inward face at
  z 62.40 and a worn-yellow glyph plate.
- Nothing here flashes, arcs, or does damage. The bus is static geometry.

### `MaintenanceCatwalk` + `CableTrench` — image left (30 + 16 parts)

Bounds: x 52.92 .. 69.26, y 0.42 .. 9.62, z ±34.36 / x 59.53 .. 65.43, z ±18.98.

All of it is built on the ring at **radius 65**.

| Feature | Bearings | Detail |
|---|---|---|
| Up flight | 60 → 76 | 10 treads, rise **0.60** each, tread run 1.815, tops 1.02 → **6.42** |
| Deck | 76 → 104 | 5 panels of 5.6°, tops **6.48 / 6.51**, 0.06 up from the top tread |
| Down flight | 104 → 120 | mirror of the up flight |
| Deck width | | 9.0 overall, **7.60 usable** between kerb inner faces |
| Deck radius span | | **60.50 .. 69.57** — the whole footprint is outside the flat field |
| Legs | every panel edge | 12 of them at ring z ±3.8, top 5.90 |
| Headroom under the deck | | **4.92** above the trench covers; you can walk under it |
| Trench | 74 → 106 | two kerbs at ring z ±2.2, 8 covers between them, radius 62.40 .. 67.75 |
| Trench ends | 74 and 106 | a dark recess plus three copper cable tubes, so the channel reads |

Both flights connect, so the route is a through-route and not a dead end.
The trench is closed for its whole length. No new fall mechanic was added.

### `ControlShed` — image right (34 parts)

Bounds: x -72.70 .. -58.45, y 0.70 .. 12.65, z ±12.10.

- Apron `bearing(270, 65.25)`, 24 x 0.9 x 13.5, top **0.70**, radius 58.50 .. 72.99.
- Core (solid) `bearing(270, 67.25)`, 18 x 9.2 x 9, y 0.30 .. **9.50**,
  radius 62.75 .. 72.31.
- Facade panels (`ShedFront`, `ShedBack`, `ShedSide` x2) span y 1.35 .. 9.45,
  0.05 below the core top so nothing is coplanar.
- **Roof pitch**: mono-pitch, `CFrame.Angles(0.16, 0, 0)` about the tangential
  axis, so the inward eave drops. Plate 19.2 x 0.7 x 10.2 centred y 10.80;
  measured span y **9.64 .. 11.96**, radius 62.16 .. 72.97. The eave fascia sits
  at 9.05 .. 9.65 on the inward edge, the parapet at 11.55 .. 12.65 on the outer.
- Closed facade only: the door (frame y 0.80 .. 7.20) opens onto nothing, the
  three windows are lit panels, the two louvred vents are geometry. No prompt,
  no NPC, no UI, no interior.

### `StormPortal` — the entrance (35 parts)

Bounds: x ±15.90, y 0.20 .. 20.60, z -82.90 .. -76.15.

| Element | Position | Size |
|---|---|---|
| Pier cores (solid) | `(±13, 8.2, -80)` | 4.6 x 17 x 4.6, y -0.30 .. 16.70 |
| **Opening between the piers** | | **21.40 studs** clear (x -10.70 .. 10.70) |
| Header | `(0, 17.4, -80)` | 30 x 2.8 x 3.2, underside **16.00** |
| Header tie | `(0, 15.55, -80)` | 26 x 0.9 x 1.2, underside 15.10 |
| Header conduit | `(0, 16.35, -78.6)` | copper, d 0.6, length 22 |
| Pier ledge | `(±13, 6.15, -77.6)` | 2.8 x 0.7 x 2.4, **decoration, not a collision surface** |
| Pier lamps | `(±10.1, 10.6, -80)` | 2 of the 6 PointLights |

The functional `Gate` (12 tall) clears the header underside by **4.00**; the
guidance roadbed (top 0.525) clears it by **15.475** and the tie by 14.575.

MapBuilder's `OWN_ENTRANCE` set now includes `Storm`, so its old `GatePost` /
`GateLintel` / `hazardStrip` trim is gone: the piers stand at x ±13 where the
posts sat at ±11, and the header carries the same lintel line 3.4 studs higher.
`Gate`, `Entrance`, `UnlockPrompt`, `GateSign`, `GateSignStand`, the `RegionGate`
tag and the `RegionId` / `Element` / `Centre` / `SpawnRadius` / `AccessRadius`
attributes are all untouched.

### Retaining wall + `WallPanels` (50 decorative parts)

48 tangential segments, i = 2..46, on radius 75, chord 10.33, depth 3.6. Every
fourth segment carries a pair of full-height pilasters; the even ones between
them take an inset steel panel; the low run either side of the gate is topped
with translucent chain link; four vent stacks (d 2.8, 7 tall) break the rear
skyline, reaching y 27.6 .. 31.2.

| bearing | core height | coping top | buttressed | inset panel | chain link | stack |
|---|---|---|---|---|---|---|
| 15 (i=2) | 14.3 | 15.1 | no | yes | yes | no |
| 22.5 (i=3) | 12.5 | 13.3 | no | no | yes | no |
| 30 (i=4) | 13.4 | 14.2 | yes | no | yes | no |
| 37.5 (i=5) | 14.3 | 15.1 | no | no | yes | no |
| 45 (i=6) | 18 | 18.8 | no | yes | no | no |
| 52.5 (i=7) | 19 | 19.8 | no | no | no | no |
| 60 (i=8) | 20 | 20.8 | yes | no | no | no |
| 67.5 (i=9) | 21 | 21.8 | no | no | no | no |
| 75 (i=10) | 17 | 17.8 | no | yes | no | no |
| 82.5 (i=11) | 18 | 18.8 | no | no | no | no |
| 90 (i=12) | 19 | 19.8 | yes | no | no | no |
| 97.5 (i=13) | 20 | 20.8 | no | no | no | no |
| 105 (i=14) | 21 | 21.8 | no | yes | no | no |
| 112.5 (i=15) | 17 | 17.8 | no | no | no | no |
| 120 (i=16) | 18 | 18.8 | yes | no | no | no |
| 127.5 (i=17) | 19 | 19.8 | no | no | no | no |
| 135 (i=18) | 20 | 20.8 | no | yes | no | no |
| 142.5 (i=19) | 23.6 | 24.4 | no | no | no | no |
| 150 (i=20) | 20 | 20.8 | yes | no | no | yes |
| 157.5 (i=21) | 21.2 | 22 | no | no | no | no |
| 165 (i=22) | 22.4 | 23.2 | no | yes | no | no |
| 172.5 (i=23) | 23.6 | 24.4 | no | no | no | yes |
| 180 (i=24) | 20 | 20.8 | yes | no | no | no |
| 187.5 (i=25) | 21.2 | 22 | no | no | no | no |
| 195 (i=26) | 22.4 | 23.2 | no | yes | no | yes |
| 202.5 (i=27) | 23.6 | 24.4 | no | no | no | no |
| 210 (i=28) | 20 | 20.8 | yes | no | no | no |
| 217.5 (i=29) | 21.2 | 22 | no | no | no | yes |
| 225 (i=30) | 17 | 17.8 | no | yes | no | no |
| 232.5 (i=31) | 18 | 18.8 | no | no | no | no |
| 240 (i=32) | 19 | 19.8 | yes | no | no | no |
| 247.5 (i=33) | 20 | 20.8 | no | no | no | no |
| 255 (i=34) | 21 | 21.8 | no | yes | no | no |
| 262.5 (i=35) | 17 | 17.8 | no | no | no | no |
| 270 (i=36) | 18 | 18.8 | yes | no | no | no |
| 277.5 (i=37) | 19 | 19.8 | no | no | no | no |
| 285 (i=38) | 20 | 20.8 | no | yes | no | no |
| 292.5 (i=39) | 21 | 21.8 | no | no | no | no |
| 300 (i=40) | 17 | 17.8 | yes | no | no | no |
| 307.5 (i=41) | 18 | 18.8 | no | no | no | no |
| 315 (i=42) | 19 | 19.8 | no | yes | no | no |
| 322.5 (i=43) | 13.4 | 14.2 | no | no | yes | no |
| 330 (i=44) | 14.3 | 15.1 | yes | no | yes | no |
| 337.5 (i=45) | 12.5 | 13.3 | no | no | yes | no |
| 345 (i=46) | 13.4 | 14.2 | no | yes | yes | no |
|  |
| ## asset site table |

## Asset site table

`Landmarks/PropSites`, `AssetCount = 33`, `AssetKit = assets/thunderworks/props-v1`,
`AssetOrigin = ground-centre`. Every site is one Model carrying `AssetName`,
`AssetSize`, `GroundCF`, `CollisionRole = "none"` and `SupportPath`.

**Placement is** `frame * GroundCF * CFrame.new(0, AssetSize.Y / 2, 0)`.

Every site in this region is ground-supported; there is no hanging convention
here. If a later Thunderworks landmark needs a hanging or wall-mounted pivot,
give it its own documented convention and a distinct `CollisionRole` — do not
reinterpret `GroundCF`.

`Yaw` below is the site frame's heading in degrees (the mesh's own +Z faces that
way); `r / bearing` is where it sits in the ring.

| Site | AssetName | AssetSize | GroundCF position | Yaw | r / bearing | SupportPath |
|---|---|---|---|---|---|---|
| `BollardSite01` | TW_Storm_Bollard | 1.2 x 3 x 1.2 | 29.08, 0.67, -53.48 | -34 | 60.9 / 28.5 | Walkways/ServicePadA |
| `BollardSite02` | TW_Storm_Bollard | 1.2 x 3 x 1.2 | 38.7, 0.67, -47 | -34 | 60.9 / 39.5 | Walkways/ServicePadA |
| `BollardSite03` | TW_Storm_Bollard | 1.2 x 3 x 1.2 | 44.55, 0.67, 41.7 | -138 | 61 / 133.1 | Walkways/ServicePadB |
| `BollardSite04` | TW_Storm_Bollard | 1.2 x 3 x 1.2 | -50.56, 0.67, 44.87 | 136 | 67.6 / 228.4 | Walkways/ServicePadC |
| `BollardSite05` | TW_Storm_Bollard | 1.2 x 3 x 1.2 | -43.11, 0.67, -42.67 | 40 | 60.7 / 314.7 | Walkways/ServicePadD |
| `BollardSite06` | TW_Storm_Bollard | 1.2 x 3 x 1.2 | -59.35, 0.7, 11.3 | 90 | 60.4 / 259.2 | Walkways/ServiceApron |
| `BollardSite07` | TW_Storm_Bollard | 1.2 x 3 x 1.2 | -59.35, 0.7, -11.3 | 90 | 60.4 / 280.8 | Walkways/ServiceApron |
| `CabinetSite01` | TW_Switch_Cabinet | 3.2 x 4.6 x 1.8 | 41.29, 0.67, 52.44 | -138 | 66.7 / 141.8 | Walkways/ServicePadB |
| `CabinetSite02` | TW_Switch_Cabinet | 3.2 x 4.6 x 1.8 | -37.76, 0.67, -48.73 | 40 | 61.6 / 322.2 | Walkways/ServicePadD |
| `CabinetSite03` | TW_Switch_Cabinet | 3.2 x 4.6 x 1.8 | -59.65, 0.7, 7.6 | 90 | 60.1 / 262.7 | Walkways/ServiceApron |
| `CabinetSite04` | TW_Switch_Cabinet | 3.2 x 4.6 x 1.8 | -59.65, 0.7, 3.8 | 90 | 59.8 / 266.4 | Walkways/ServiceApron |
| `CableReelSite01` | TW_Cable_Reel | 4 x 4.4 x 3 | 45.07, 0.67, 45.27 | -138 | 63.9 / 135.1 | Walkways/ServicePadB |
| `CableReelSite02` | TW_Cable_Reel | 4 x 4.4 x 3 | 40.97, 0.67, 47.89 | -106.5 | 63 / 139.5 | Walkways/ServicePadB |
| `CableReelSite03` | TW_Cable_Reel | 4 x 4.4 x 3 | 52.42, 0.42, -34.04 | -36.9 | 62.5 / 57 | Walkways/YardSkin |
| `CableReelSite04` | TW_Cable_Reel | 4 x 4.4 x 3 | 52.42, 0.42, 34.04 | -148.8 | 62.5 / 123 | Walkways/YardSkin |
| `CableReelSite05` | TW_Cable_Reel | 4 x 4.4 x 3 | -60.35, 0.7, -8.2 | 98.6 | 60.9 / 277.7 | Walkways/ServiceApron |
| `CapacitorSite01` | TW_Capacitor_Bank | 3.4 x 4.8 x 3.4 | -42.36, 0.67, 48.76 | 136 | 64.6 / 221 | Walkways/ServicePadC |
| `CapacitorSite02` | TW_Capacitor_Bank | 3.4 x 4.8 x 3.4 | 24.47, 0.67, 59.63 | -160 | 64.5 / 157.7 | Walkways/GeneratorSupportL |
| `CapacitorSite03` | TW_Capacitor_Bank | 3.4 x 4.8 x 3.4 | 19.58, 0.67, 61.41 | -160 | 64.5 / 162.3 | Walkways/GeneratorSupportL |
| `CapacitorSite04` | TW_Capacitor_Bank | 3.4 x 4.8 x 3.4 | -19.58, 0.67, 61.41 | 160 | 64.5 / 197.7 | Walkways/GeneratorSupportR |
| `CapacitorSite05` | TW_Capacitor_Bank | 3.4 x 4.8 x 3.4 | -24.47, 0.67, 59.63 | 160 | 64.5 / 202.3 | Walkways/GeneratorSupportR |
| `ConduitSite01` | TW_Conduit_Elbow | 3 x 2.5 x 2.2 | 36.1, 0.67, -49.59 | 146 | 61.3 / 36.1 | Walkways/ServicePadA |
| `ConduitSite02` | TW_Conduit_Elbow | 3 x 2.5 x 2.2 | -46.02, 0.67, 41.75 | 113.1 | 62.1 / 227.8 | Walkways/ServicePadC |
| `InsulatorSite01` | TW_Ceramic_Insulator | 1.8 x 3 x 1.8 | 32.68, 0.67, -52.02 | -34 | 61.4 / 32.1 | Walkways/ServicePadA |
| `InsulatorSite02` | TW_Ceramic_Insulator | 1.8 x 3 x 1.8 | -35.33, 0.67, -50.51 | 40 | 61.6 / 325 | Walkways/ServicePadD |
| `InsulatorSite03` | TW_Ceramic_Insulator | 1.8 x 3 x 1.8 | 21, 0.67, 57.7 | -160 | 61.4 / 160 | Walkways/GeneratorSupportL |
| `InsulatorSite04` | TW_Ceramic_Insulator | 1.8 x 3 x 1.8 | -21, 0.67, 57.7 | 160 | 61.4 / 200 | Walkways/GeneratorSupportR |
| `TransformerSite01` | TW_Transformer | 5.8 x 6.2 x 4.6 | 33.61, 0.67, -56.09 | -34 | 65.4 / 30.9 | Walkways/ServicePadA |
| `TransformerSite02` | TW_Transformer | 5.8 x 6.2 x 4.6 | 39.42, 0.67, -52.18 | -34 | 65.4 / 37.1 | Walkways/ServicePadA |
| `TransformerSite03` | TW_Transformer | 5.8 x 6.2 x 4.6 | -43.74, 0.67, -46.84 | 40 | 64.1 / 317 | Walkways/ServicePadD |
| `VentSite01` | TW_Vent_Housing | 4 x 2.4 x 3.4 | -46.43, 0.67, 46.36 | 136 | 65.6 / 225 | Walkways/ServicePadC |
| `VentSite02` | TW_Vent_Housing | 4 x 2.4 x 3.4 | -39.51, 0.67, -53 | 40 | 66.1 / 323.3 | Walkways/ServicePadD |
| `VentSite03` | TW_Vent_Housing | 4 x 2.4 x 3.4 | -60.35, 0.7, -3.4 | 90 | 60.4 / 273.2 | Walkways/ServiceApron |

Counts by asset: Transformer 3, Ceramic_Insulator 4, Cable_Reel 5,
Capacitor_Bank 5, Switch_Cabinet 4, Vent_Housing 3, Conduit_Elbow 2,
Storm_Bollard 7. All eight are used.

Each site currently holds a placeholder built to the manifest bounding box
exactly, so the swap to a MeshPart is one for one. Placeholders are anchored,
`CanCollide` / `CanTouch` / `CanQuery` false, and none of them casts a shadow.

## Collision ownership

| Concern | Who owns it | Survives the art pass? |
|---|---|---|
| Containment ring | `Boundary/Perimeter`, `WallCoping`, `WallButtress` | yes, do not remove |
| Entrance closure | `Boundary/GateShoulder`, `ShoulderCoping`, `PortalPierCore` + MapBuilder's `Gate` | yes |
| Shed / housing / pedestal masses | `Boundary/ShedCore`, `GeneratorHousing`, `Collector*Pedestal` | yes |
| Every walking surface | all of `Walkways` | yes |
| Everything else | `Landmarks` | no, all of it is replaceable |

Decoration defaults to anchored, `CanCollide` false, `CanTouch` false,
`CanQuery` false and `CastShadow` false. **No non-solid part is queryable**, so
no placeholder can ever absorb one of the 27 sightline rays the harness casts at
the region board. There are no collision proxies beyond the Boundary and
Walkways parts listed above.

## Clearances

| Constraint | Target | Measured |
|---|---|---|
| Solid scenery inside the spawn radius | none inside 44 | nearest solid standing footprint at **58.50** (`ServiceApron`) |
| Standing scenery inside the flat field | none inside 58 | nearest at **58.45** (`ApronNosing`) |
| Flat floor detail | allowed | seams/scuff/drains, tops 0.485 .. 0.53, all ≤ 0.13 proud of the yard |
| Footprints inside the ring | ≤ 77.5 | **77.28** (`WallCoping`, on the wall) |
| Gate furniture outside the disc | expected, as in every region | 84.41 (`PierFlare` at z -80) |
| Board box overlap | zero | **0 parts** intersect `(24, 9.9, -90)` 18 x 10 x 0.65 |
| Board sightlines | all 27 clear | **0 blocking hits** |
| Road clearance, walk-into structure | ≥ 2 studs | smallest **2.784** (`GateShoulder`) |
| Road clearance, overhead structure | headroom | 14.575 .. 18.775 |
| Crisis arena | clear | nearest part **64.2** from its centre, 30.2 clear of its 34-stud footprint |
| Frostbite Peaks / Orbit Outpost | clear | 202.9 from each centre, 124.9 clear |
| Nearest city plot | clear | 93.2 from its centre, 61.2 clear |
| Coplanar top faces | none | **0 pairs** across all 683 parts |

There are **no approach decorations outside the gate**. Frostbite's props landed
on the Crisis spur; rather than repeat the risk for no art gain, the outside of
the Thunderworks gate is left as plain world ground and road. The road-clearance
check above still runs over every part in the region, not only approach ones.

## Containment

The ring was probed radially at **0.25-degree steps all the way round, at four
heights (y 1.5, 4.0, 8.0, 11.5)**, from radius 55 out to 100, against every
solid part plus MapBuilder's own `Gate`: **zero gaps**. The main entrance is the
only ground opening and the Gate closes it.

Escape was checked as a reachability search, not a spot check: start standing on
the yard at 0.42, and repeatedly step onto any solid surface whose top is within
**7.2 studs** vertically (a default Roblox jump clears 6.37) and **4.0 studs**
horizontally.

- Highest surface reachable from the yard: **7.41** (`CatKerb`).
- Lowest containment top: **12.50** (`Perimeter`, the low run by the gate).
- No containment surface is reached. The smallest unclimbed step from any
  reachable surface onto containment is **9.62 studs**, against a 7.2 reach —
  **2.42 studs of margin**.

Two findings drove real geometry changes here, both caught before Studio:

1. The side wall band was 15..19 studs. The catwalk kerb tops out at 7.41, so
   the coping was 7.58 above it — inside a pessimistic jump. The band is now
   **17..21**.
2. The buttresses were half-height brackets at radius 71.32, 1.8 studs from the
   catwalk deck edge and only 4.3 studs above the kerb: a two-hop ladder onto
   the wall. They are now **full-height pilasters**, capped flush with the
   coping, so there is no intermediate step.

## Hazard readability

Storm's `Lightning` is unchanged: yellow circles `(255, 235, 110)`, telegraph
1.1 s, active 0.35 s, radius 3.5, base count 2, spawnRadius 10, plus whatever
`Capture.zoneTuning` row 5 adds. The floor it is drawn on is deliberately dark
and desaturated:

| Surface | Colour |
|---|---|
| Region ground (MapBuilder) | 70, 70, 95 Asphalt |
| `YardSkin` | 78, 84, 99 Asphalt |
| `YardSeam` | 66, 71, 85 |
| `YardScuff` | 88, 94, 109 |

There is no yellow, no neon and no painted circle anywhere on the catching
field. The only yellow in the region is `WORN_YELLOW` **172, 141, 56** on
machinery — the pier chevrons, the shed and housing glyphs, and the bollard
bands — all of it beyond radius 58 and far darker than the telegraph.

Six PointLights total, all warm and small: three shed windows, one shed lamp,
two portal lamps. No Lighting service changes, no atmosphere, no fog, no
ColorCorrection. Gusty's local atmosphere is untouched.

## Validation

Everything below was run. **Nothing has been seen in Roblox Studio yet** — see
"Not verified".

- `python tools/luau_lint.py src` — 117 files, STRUCTURE OK
- `python tools/quote_scan.py` — 117 files, NO UNBALANCED QUOTES
- `python tools/stamp.py` — ok
- `rojo build -o build/Thunderworks.rbxl` — ok, 763,035 bytes
- Every `.luau` under `src` and `tools` compiles (Luau compiler, via Lune)
- **Headless geometry suite, 25 checks, all pass.** The module is loaded and
  executed against a faithful reproduction of MapBuilder's `part()`, in the real
  region frame, and measured with oriented bounds and shape-aware footprints
  (a cylinder is measured as a cylinder, not as its bounding box):

  part budget 683/700 · lights 6/6 · all CFrames finite and positive · flags
  correct on every part · spawn field clear · flat field clear inside 58 · inside
  the ring envelope · clear of every neighbour · board box clear · all 27
  sightlines clear · road clearance · containment continuity · no jump chain to
  containment · zero coplanar top faces · kit contract on every site · AssetCount
  matches · all eight assets used · 33 sites (brief: 24-36) · every site exactly
  on a solid surface · no site overhangs its support · no two placed meshes
  intersect · tread rise ≤ 0.7 · top tread meets the deck · deck 5-7 above the yard.

- **Cosmic output proved unchanged.** `RegionScenery`'s Cosmic branch was dumped
  part-for-part before and after the edit — name, model path, size, material,
  shape, all four collision flags, colour and the full 12-component CFrame — and
  the two dumps are **identical**: 178 parts, `SceneryVersion` 2. Storm goes from
  208 parts at version 2 to **683 at version 3**, through the real
  `RegionScenery` → `Thunderworks` delegation rather than a stub.

- New live checks in `TestHarness` (they run inside Studio, not here): the
  three-model split, the full kit contract on every site, all eight assets used,
  `AssetCount` matching, every site raycast onto a solid surface, the spawn field
  and flat field clear, entrance structure clearing roads by two studs, the light
  budget, 20 treads present and every rise within a stride. `SCENERY_VERSION`
  for Storm is now 3.

### Not verified

- **No Studio run.** No `[SelfTest]` / `[LiveTest]` numbers from this session;
  the last recorded baseline is 941 / 72 with zero failures and the new Storm
  checks are additional to that. Nothing here has been seen rendered.
- No visual review: colour under the game's lighting, silhouette reading at
  distance, and whether the yard reads as an electrical works rather than a car
  park are all unjudged.
- Mobile performance of 683 static parts is unmeasured.
- The Lightning telegraph has not been watched playing over this floor; the
  contrast argument above is from the colour values, not from a screenshot.

## What is still Codex's

The eight-asset kit is a *dressing* kit. The large forms are still placeholders
awaiting a fitted-art pass with real measurements, now that they exist:

- the two lightning collectors (pedestal, ceramic neck, mast, two copper rings,
  crown) — all dimensions above
- the control shed facade and its mono-pitch roof
- the maintenance catwalk, its trench and their handrails
- the steel entrance portal
- the retaining wall's inset panels, pilaster caps and vent stacks

None of these are in `props-v1` and none of them should be guessed at; every
frame, bound and attachment point they need is recorded above.

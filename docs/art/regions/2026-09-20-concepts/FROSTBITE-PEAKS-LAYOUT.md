# Frostbite Peaks — measured layout contract

The dimensioned handoff for the fitted-art pass on the V2 "Alpine Expedition"
blockout. Source of the geometry: `src/server/Map/FrostbitePeaks.luau`.
Reference render: `frostbite-peaks-v2-alpine-expedition.png`.
Brief this answers: `FROSTBITE-PEAKS-CLAUDE-HANDOFF.md`.
Plan drawing: `frostbite-peaks-layout-plan.svg`.

**2026-09-21 approach correction:** the four local -X approach props now sit
beside the outer wall, clear of the Crisis arena spur. Ground-centre X/Z:
TreeSite23 `(-35, -72)`, TreeSite25 `(-48, -65)`, RockSite10 `(-29, -75)`,
RockSite12 `(-42, -70)`. Their yaw still follows x * 0.03 (trees) / x * 0.05
(rocks). Minimum measured mesh-footprint clearance to the road is 2.836 studs.
The local -X approach grass was moved off the road too. The original plan SVG
predates this correction; the source and updated site table below take precedence.

**Every number below was read out of the built geometry**, not out of the source:
the module was executed headless under Lune 0.10.5 with a Roblox datatype shim and
every part measured in the region's own frame. The commands are in §13.

**Status at handoff:** built, statically checked, Rojo-built, headless-measured.
**Not seen running in Roblox Studio** — there was no Studio bridge in the session
that wrote it. §12 lists exactly what that leaves unverified.

---

## 1. Coordinate frame

`RegionScenery` hands the module
`frame = CFrame.lookAt(centre, Vector3.new(0, centre.Y, 0))` with
`centre = polar(280, 270)`, i.e. world `(0, 0, -280)`. Every number in this
document is **local to that frame**, applied as `frame * CFrame.new(...)`.

| Axis | Direction |
|---|---|
| `-Z` | Entrance, toward the hub. The gate is at `z = -80`. |
| `+Z` | Rear of the region, the mountain ridge. |
| `+X` | The player's **left** on entering — image LEFT: rope bridge, frozen cascade. |
| `-X` | The player's **right** — image RIGHT: the expedition hut. |
| `+Y` | Up. World `y` equals local `y`; the region centre plane is `y = 0`. |

Verified against `MapBuilder`: `gateCF` has the same orientation as `frame` and
sits at local `(0, 0, -80)`, so the board's `signCF = gateCF * CFrame.new(24, 9.4, -10)`
is local `(24, 9.4, -90)`.

Ring frame — **use this for every perimeter placement**:

```lua
local function ring(a: number, r: number): CFrame
    return CFrame.new(math.sin(a) * r, 0, -math.cos(a) * r) * CFrame.Angles(0, -a, 0)
end
local function bearing(degrees: number, r: number): CFrame
    return ring(math.rad(degrees), r)
end
```

Bearing **0 = entrance, 90 = image left, 180 = rear, 270 = image right**. Inside
the ring frame `+X` is tangential (increasing bearing) and **`+Z` points inward**
at the region centre. Convert through `frame` exactly once.

## 2. Heights datum

| Surface | Local `y` | Note |
|---|---|---|
| Region ground disc top | **0.30** | built by `MapBuilder`, radius 75, not by this module |
| `SnowField` skin top | **0.60** | radius 57; bottom 0.10, buried in the disc |
| Cliff-foot annulus | **0.30** | bare disc, radius 57 – 69.6, where most prop sites stand |
| `LedgeDeck` top (left route) | **6.40 / 6.43** | alternating 0.03 jog; no two neighbours coplanar |
| `BridgeDeck` top | **6.37 → 5.22 → 6.37** | 1.15-stud sag, ends 0.03 under the ledge decks |
| `TerraceDeck` top (hut) | **5.20 / 5.23** | same jog |
| `PorchDeck` top | **5.42** | a 0.22 step up off the terrace |
| Highest point in the region | **44.50** | `RearPeak03` summit snow |

## 3. Radial budget

| Radius | Contents |
|---|---|
| 0 – 44 | `SpawnRadius`. **Nothing solid.** Measured innermost solid: **59.00** true / 55.35 by the harness's AABB rule. |
| 0 – 57 | `SnowField` skin. Flush `WindSweep` arcs and `FieldStone` only, tallest 0.74. |
| 57 – 58 | Empty margin. Nothing over 0.95 studs tall comes inside 58 — measured. |
| 58 – 69.6 | Cliff-foot annulus. Prop sites, drifts, firs, rocks. |
| 59.0 – 75 | `TerraceBench` (hut side) and `LedgeBench` (bridge side). |
| 60.7 – 67.3 | Rope bridge deck and kerbs. |
| 69.6 – 74.6 | `CliffBench`, the lower terrace of the perimeter cliff. |
| 73.2 – 76.8 | `Perimeter`, the continuous containment ring at radius 75. |
| 70 – 91 | Rear peaks and saddles, outside the ring. Outermost solid **91.23**. |
| 80 – 108 | Approach dressing outside the gate, on the world's own grass plane (`y = 0`). |

The map's own Frost landscape starts at radius 92.15 (its snowy trees) and 103
(its background ridges); nothing here reaches either.

## 4. Structure — and what survives the art pass

Three sibling Models under `Workspace.Regions.frostbite_peaks`:

| Model | Parts | Role |
|---|---|---|
| `Boundary` | **216** | Containment and permanent bases. **Never remove.** |
| `Walkways` | **177** | Functional walking surfaces. **Never remove.** |
| `Landmarks` | **413** | Replaceable placeholder art, including all 56 asset sites. |

**806 parts, 7 PointLights, `SceneryVersion = 3`.**

`Boundary` contents, all solid, all of which must still exist after your pass:

| Name | n | Size (one) | Top `y` | Radial band |
|---|---|---|---|---|
| `Perimeter` | 45 | 10.33 x h x 3.60 | 13.0 – 26.2 | 73.2 – 76.8 |
| `CliffBench` | 45 | 10.33 x bh x 5.00 | 2.6 – 7.0 | 69.6 – 74.6 |
| `BenchSnow` | 45 | 10.48 x 1.20 x 5.40 | 3.55 – 7.95 | 69.4 – 74.8 |
| `CliffCornice` | 45 | 10.53 x 1.50 x 4.40 | 14.20 – 27.60 | 72.8 – 77.2 |
| `CliffTier` | 9 | 5.99 x 8.20 x 3.40 | 8.20 | 71.4 – 74.9 |
| `TierSnow` | 9 | 6.11 x 0.90 x 3.70 | 8.85 | 71.3 – 75.1 |
| `GateShoulder` | 2 | 3.60 x 12.00 x 12.94 | 12.00 | gate to bearing ±15 |
| `ShoulderSnow` | 2 | 4.20 x 1.10 x 12.94 | 12.85 | as above |
| `ArchPostCore` | 2 | 2.90 x 17.00 x 2.90 | 17.15 | at `(±13, ·, -80)` |
| `GorgeWall` | 2 | 2.80 x 6.80 x 9.20 | 6.80 | bearings 95 and 111, r 64 |
| `HutCore` | 1 | 17.40 x 9.40 x 11.40 | 14.60 | bearing 238, r 68.5 |
| `PeakBase` | 5 | 16.80 x 12.88 x 8.00 (+4 sizes) | 12.88 – 20.24 | 77.4 – 91.2 |
| `RidgeSaddle` | 4 | 18.00 x 27.00 x 14.00 | 27.00 | bearings 157/172/188/203, r 80 |

`Walkways` contents, all solid, all of which must still exist:

| Name | n | Size (one) | Top `y` |
|---|---|---|---|
| `SnowField` | 1 | cylinder, d 114, t 0.50 | 0.60 |
| `LedgeStep` | 22 | 1.78 x (rising) x 8.00 | 0.85 → 6.30 | two flights of 11 |
| `LedgeStepKerb` | 44 | 1.78 x (rising) x 0.90 | 1.65 → 7.10 |
| `LedgeBench` | 12 | 7.00 x 5.96/6.00 x 9.00 | 5.96 / 6.00 |
| `LedgeDeck` | 12 | 6.72 x 0.90 x 8.20 | 6.40 / 6.43 |
| `LedgeKerb` | 12 | 6.72 x 0.90 x 0.70 | 7.30 / 7.34 |
| `BridgeDeck` | 9 | 2.45 x 0.55 x 6.40 | 5.22 – 6.37 |
| `BridgeKerb` | 18 | 2.45 x 0.95 x 0.55 | 6.17 – 7.32 |
| `TerraceStep` | 10 | 1.75 x (rising) x 8.00 | 0.78 → 5.14 |
| `TerraceStepKerb` | 20 | 1.75 x (rising) x 0.90 | 1.58 → 5.94 |
| `TerraceBench` | 6 | 7.30 x 4.76/4.80 x 16.00 | 4.76 / 4.80 |
| `TerraceDeck` | 6 | 7.04 x 0.90 x 15.20 | 5.20 / 5.23 |
| `TerraceKerb` | 4 | 7.04 x 0.90 x 0.70 | 6.10 / 6.14 | omitted in front of the hut |
| `PorchDeck` | 1 | 12.00 x 0.70 x 3.10 | 5.42 |

Everything else — 413 parts — is in `Landmarks` and is yours to replace.

## 5. The perimeter cliff

48 tangential segments at radius 75, built for `i = 2 .. 46`, leaving a
three-segment gap centred on bearing 0. Chord length `2 * 75 * tan(pi / 48) + 0.5 = 10.33`.
Segment `i` sits at bearing `i * 7.5`.

Three zones:

| Zone | Segments | Bearings | Wall height `h` | Bench height `bh` |
|---|---|---|---|---|
| low (entrance flanks) | `i <= 6`, `i >= 42` | ≤ 45, ≥ 315 | `13 + (i % 3) * 0.9` → 13.0 – 14.8 | `2.6 + (i % 3) * 0.6` → 2.6 – 3.8 |
| ridge (rear) | `20 <= i <= 28` | 150 – 210 | `23 + (i % 3) * 1.6` → 23.0 – 26.2 | `4.6 + (i % 4) * 0.8` → 4.6 – 7.0 |
| default (sides) | everything else | — | `17 + (i % 4) * 1.3` → 17.0 – 20.9 | as above |

Per segment: a `Perimeter` core wall, a `CliffBench` standing 2.9 studs inward of
it with a `BenchSnow` cap, and a `CliffCornice` over the wall top. Every fourth
non-low segment also gets a `CliffTier` + `TierSnow` shelf at `bh + 3.6`.

**Modular pieces this implies**, if you build a cliff kit: one wall face
10.33 wide x 3.6 deep at five heights (13.0, 13.9, 14.8, 17.0–20.9 in four steps,
23.0–26.2 in three); one bench face 10.33 x 5.0 at six heights; one cornice
10.53 x 1.5 x 4.4; one shelf 5.99 x 3.4.

The zone heights are paired deliberately: no snow shelf is within a 7.2-stud jump
of the wall behind it. See §12 for what that does and does not buy.

## 6. Entrance

`MapBuilder` still owns `Gate` (20 x 12 x 2 at `z = -80`), `UnlockPrompt`,
`Entrance`, `GateSign` and `GateSignStand`. This module adds the timber arch and
**Frost is now excluded from the industrial `GatePost`/`GateLintel`/`hazardStrip`
trim**, alongside Wind and Water.

| Piece | Where | Size | Notes |
|---|---|---|---|
| `ArchPostCore` | `(±13, 8.65, -80)` | 2.90 x 17.00 x 2.90 | **solid, Boundary** — the only collision here |
| `ArchPostSnow` | `(±13, 17.30, -80)` | 3.30 x 0.80 x 3.30 | cap |
| `ArchPostBand` | `(±13, 5.40 / 12.20, -80)` | 3.15 x 0.40 x 3.15 | iron bands |
| `ArchBrace` | `(±11.2, 16.2, -80)`, rolled ±0.55 rad | 0.85 x 4.60 x 0.85 | |
| `ArchTie` | `(0, 15.9, -80)` | 27.00 x 1.30 x 1.70 | underside 15.25 → **14.95 studs of headroom** |
| `ArchBeam` | `(0, 18.6, -80)` | 32.00 x 2.40 x 2.40 | main lintel |
| `ArchBeamSnow` | `(0, 20.1, -80)` | 32.40 x 0.90 x 3.00 | top of the arch, `y` 20.55 |
| `ArchPlaque` | `(0, 14.6, -79.7)` | 9.50 x 3.00 x 0.40 | **decorative, no text, no prompt** |
| `PlaqueChain` / `PlaqueGlyph` | `(±3.4, 15.8, -79.7)` / `(±1.3, 14.9, -79.94)` | | |
| `ArchLantern*` | `(±10.2, 14, -80)` | 4 parts each | 2 of the 7 PointLights |
| `GateFence*` | `(±24.5, 0.1, -80.6)`, span 18, 5 posts | height 3.2 | decorative |

**Do not put anything in the board box**: 18 x 10 x 0.65 centred at `(24, 9.4, -90)`,
i.e. `x 15..33, y 4.4..14.4, z -90.33..-89.68`. `testRegionSignVisibility` runs
`GetPartBoundsInBox` there over `Boundary` and `Landmarks` and casts 27 rays at the
board from `(x ∈ {-8, 0, 8}, 5.5, -114)`. Both measure clean today (0 intersections,
0 of 27 blocked) and both are easy to break with a tree.

## 7. Left route — stair, ledges, gorge, cascade, bridge

The whole route is at radius 64 and **climbs tangentially**, so unlike Cinder
Canyon no part of it enters the catching field.

**`LedgeStep` x22, two flights of 11** — one climbing at bearings 44 → 59, one
descending at 162 → 147, so the bridge is a route through rather than a dead end.
Width 8 (radial 60 – 68), tread 1.36, **riser 0.5455 exactly**, tops 0.85 → 6.30.
Kerbs at radial ±4.4. The last tread meets its ledge deck with a 0.10 – 0.13 step up.

**Ledge A** — six segments at bearings 62, 68, 74, 80, 86, 92.
**Ledge B** — six segments at bearings 114, 120, 126, 132, 138, 144.
Bench 7.00 x ~6.00 x 9.00 (radial 59.5 – 68.5); deck 6.72 x 0.90 x 8.20;
kerb on the inner edge at radius 60.2. `LedgeFence` posts and rails above it are
decoration (span 6.25, one post per segment).

**Gorge** — bearings 95 → 111. Two solid `GorgeWall` end caps (2.80 x 6.80 x 9.20).
Five flush `GorgeIce` stream arcs at radius 64, tops 0.54 / 0.59, and a
`CascadePool` (13.00 x 0.40 x 7.00) at bearing 103, radius 68.5, top 0.66.

**Frozen cascade** — six `CascadeRibbon` ice columns on the wall face at radius
71.8, bearings 96.5 – 109.5, spanning `y` 1.4 – 20.5, each with a paler
`CascadeCore` at radius 71.0. `CascadeLip` 16.00 x 1.70 x 3.20 at bearing 103,
radius 72.4, top 21.95, with `CascadeLipSnow` over it to 22.90.
**All of it is `CanCollide = false`** — `Ice` and `Glacier` have 0.02 and 0.05
friction and must never end up under a player's feet.

**Rope bridge** — nine planks, bearings 95.60 → 110.40 at radius 64:

| Plank | Bearing | Deck top `y` |
|---|---|---|
| 1 | 95.60 | 6.370 |
| 2 | 97.45 | 5.930 |
| 3 | 99.30 | 5.557 |
| 4 | 101.15 | 5.308 |
| 5 | 103.00 | 5.220 |
| 6 | 104.85 | 5.308 |
| 7 | 106.70 | 5.557 |
| 8 | 108.55 | 5.930 |
| 9 | 110.40 | 6.370 |

End-to-end centre span **16.49 studs**, deck width **6.40** (radial 60.81 – 67.21),
sag **1.15**, largest step between planks **0.440**. The end planks sit 0.03 below
the ledge decks they overlap. Kerbs are solid, 0.95 tall, at radial ±3.0.
Rope rails, hangers, `PortalPost`/`PortalBeam`/`PortalSnow` and two lanterns are
decoration. **If you replace the deck, keep a solid anchored surface at these
nine heights** — the route is only continuous because of them.

## 8. Hut terrace and the alpine hut

**`TerraceStep` x10** — bearings 270 → 256 at radius 67, width 8 (radial 63 – 71),
tread 1.55, **riser 0.484 exactly**, tops 0.78 → 5.14.

**Terrace** — six segments at bearings 224, 230, 236, 242, 248, 254, radius 67,
bench 7.30 x ~4.80 x 16.00 (radial **59.0 – 75.0**), deck 7.04 x 0.90 x 15.20,
kerb and fence at radius 59.7 on the four outer segments only: both are omitted at
bearings 236 and 242, where the porch reaches the terrace edge, so the hut front is open.

**`AlpineHut`** at `bearing(238, 68.5)`. In the hut's own frame (`+X` tangential,
`+Z` inward toward the field, origin on the ring at radius 68.5):

| Piece | Local CFrame | Size |
|---|---|---|
| `HutCore` **(solid, Boundary)** | `(0, 9.90, 0)` | 17.40 x 9.40 x 11.40 |
| `HutFront` | `(0, 9.95, 6)` | 18.00 x 9.50 x 0.60 |
| `HutBack` | `(0, 9.95, -6)` | 18.00 x 9.50 x 0.60 |
| `HutSide` x2 | `(±8.7, 9.91, 0)` | 0.60 x 9.50 x 12.00 |
| `HutSill` | `(0, 5.50, 0)` | 18.60 x 0.70 x 12.60 |
| `HutGable` x6 | `(±8.7, 15.25 / 16.50 / 17.75, 0)` | 0.50 x 1.50 x 10.2 / 6.8 / 3.4 |
| `HutRoof` x2 | `(0, 16.50, ±3.15)` rolled `±0.519 rad` about X | 19.40 x 0.80 x 7.40 |
| `HutRoofSnow` x2 | same, + 0.60 along the roof normal | 19.70 x 0.55 x 7.00 |
| `HutRidge` | `(0, 18.35, 0)` | 19.60 x 0.90 x 1.50 |
| `HutRidgeSnow` | `(0, 19.00, 0)` | 19.90 x 0.70 x 2.00 |
| `HutChimney` | `(-7, 15.60, -2)` | 2.40 x 8.00 x 2.40 |
| `HutChimneyCap` / `Snow` | `(-7, 19.75 / 20.20, -2)` | 2.80 x 0.60 / 2.60 x 0.45 |
| `HutDoorFrame` | `(-4.4, 8.15, 6.30)` | 3.90 x 5.90 x 0.28 |
| `HutDoor` | `(-4.4, 7.95, 6.42)` | 3.20 x 5.40 x 0.35 |
| `HutDoorHandle` | `(-3.1, 7.90, 6.62)` | 0.30 x 0.30 x 0.24 |
| `HutWindowFrame` x2 | `(1.6 / 6.4, 10.10, 6.30)` | 3.80 x 3.40 x 0.26 |
| `HutWindow` x2 | `(1.6 / 6.4, 10.10, 6.40)` | 3.20 x 2.80 x 0.30, Neon + PointLight 0.85 / range 16 |
| `HutWindowSill` x2 | `(1.6 / 6.4, 8.30, 6.45)` | 4.00 x 0.30 x 0.70 |
| `PorchDeck` **(solid, Walkways)** | `(1, 5.07, 7.85)` | 12.00 x 0.70 x 3.10 |
| `PorchPost` x2 | `(-4.2 / 6.2, 7.72, 9.1)` | 0.80 x 4.50 x 0.80 |
| `PorchBeam` | `(1, 10.30, 9.1)` | 12.20 x 0.70 x 0.80 |
| `PorchRoof` | `(1, 11.20, 7.9)` pitched `0.26 rad` | 12.60 x 0.50 x 4.20 |
| `PorchRoofSnow` | same, + 0.45 | 12.90 x 0.45 x 4.00 |
| `PorchLantern*` | `(6.2, 9.2, 9.1)` facing the field | 4 parts |

**Measured envelope, hut + porch together: 19.90 wide x 15.70 tall x 16.63 deep**
(`y` 4.72 – 20.42). Hut body and roof alone: 19.90 x 15.22 (from the terrace deck)
x 13.20. Both are inside the brief's 16–20 x 14–18 x 12–16 once the porch is
counted separately.

The **door is closed and decorative**: no ProximityPrompt, no shop, no NPC, no
interior. Please keep it that way unless a system is actually built behind it.
The back of the hut is deliberately buried in the cliff — the roof's rear eave
reaches radius 75.8 and is hidden by the `Perimeter` wall at 73.2 – 76.8.

## 9. Rear ridge

Five peaks plus four saddles, sitting behind the containment ring.

| Model | Bearing | Ring radius | Summit `y` | Base `w` x `d` | Outermost radius |
|---|---|---|---|---|---|
| `RearPeak01` | 150 | 79 | 30.50 | 22 x 17 | 89.0 |
| `RearPeak02` | 164 | 80 | 37.50 | 26 x 19 | 90.8 |
| `RearPeak03` | 180 | 80 | **44.50** | 29 x 20 | 90.9 |
| `RearPeak04` | 196 | 80 | 35.50 | 25 x 19 | 90.2 |
| `RearPeak05` | 210 | 79 | 28.50 | 21 x 16 | 88.1 |

Each is `PeakBase` (solid, Boundary, `w * 0.8` x `h1` x `d * 0.5`, shifted
`-d * 0.25` outward so it cannot be used as a step out of the region) plus
`PeakTier`, `PeakSummit`, `PeakSnow`, `PeakShoulderSnow` and `PeakFace` — all
non-colliding and all yours. `RidgeSaddle` x4 (18 x 27 x 14, solid, top 27.0) and
`SaddleSnow` x4 (top 28.60) link them so the ridge reads as one mass over the
cornice line rather than five lumps.

## 10. Codex asset sites

`Landmarks.PropSites` carries `AssetKit = "assets/frostbite-peaks/props-v1"` and
`AssetOrigin = "ground-centre"`. Each of the **56 sites** is a Model with:

| Attribute | Type | Meaning |
|---|---|---|
| `AssetName` | string | the mesh from `props-v1/manifest.json` |
| `AssetSize` | Vector3 | its exact exported dimensions |
| `GroundCF` | CFrame | **region-local**, ground-centre. Place a MeshPart at `frame * GroundCF * CFrame.new(0, AssetSize.Y / 2, 0)` |
| `CollisionRole` | string | `none`, or `hanging` |

For a **`hanging`** site (icicles) `GroundCF` is the **top** of the bounds — the
lip the cluster is fixed to — so the MeshPart goes at
`frame * GroundCF * CFrame.new(0, -AssetSize.Y / 2, 0)`.

Placeholder geometry inside each site reproduces the manifest bounding box:
**worst error across all 56 sites is 0.0007 studs**, and every site's origin sits
exactly on its bounds (0.0000 error). Every non-hanging site rests on a real solid
surface to within 0.06 studs — measured, not assumed. Delete the placeholder parts
and drop the mesh in; nothing else has to move.

| Asset | Sites |
|---|---|
| `FP_Snow_Fir_Tree` | 12 |
| `FP_Snow_Fir_Sapling` | 13 |
| `FP_Snow_Rock_Wide` | 6 |
| `FP_Snow_Rock_Tall` | 6 |
| `FP_Snow_Drift` | 5 |
| `FP_Icicle_Cluster` | 6 |
| `FP_Supply_Crate` | 5 |
| `FP_Rope_Coil` | 3 |

### Full site table

`y` is the ground-centre height (top of bounds for `hanging`); `yaw` is degrees
about local +Y within `GroundCF`.

| Site | Asset | Bearing | Radius | `y` | Yaw | Role |
|---|---|---|---|---|---|---|
| TreeSite01 | FP_Snow_Fir_Tree | 67.5 | 71.00 | 6.35 | 293.5 | on `CliffBench` snow |
| TreeSite02 | FP_Snow_Fir_Sapling | 82.5 | 71.00 | 7.95 | 358.7 | on `CliffBench` snow |
| TreeSite03 | FP_Snow_Fir_Tree | 112.5 | 71.00 | 7.95 | 129.1 | on `CliffBench` snow |
| TreeSite04 | FP_Snow_Fir_Sapling | 142.5 | 71.00 | 7.95 | 259.5 | on `CliffBench` snow |
| TreeSite05 | FP_Snow_Fir_Tree | 217.5 | 71.00 | 6.35 | 225.6 | on `CliffBench` snow |
| TreeSite06 | FP_Snow_Fir_Sapling | 277.5 | 71.00 | 6.35 | 126.5 | on `CliffBench` snow |
| TreeSite07 | FP_Snow_Fir_Tree | 292.5 | 71.00 | 7.95 | 191.7 | on `CliffBench` snow |
| TreeSite08 | FP_Snow_Fir_Sapling | 322.5 | 71.00 | 4.15 | 322.1 | on `CliffBench` snow |
| TreeSite09 | FP_Snow_Fir_Sapling | 13.0 | 65.50 | 0.30 | 24.2 | annulus |
| TreeSite10 | FP_Snow_Fir_Tree | 27.0 | 65.00 | 0.30 | 50.3 | annulus |
| TreeSite11 | FP_Snow_Fir_Sapling | 34.0 | 61.50 | 0.30 | 63.4 | annulus |
| TreeSite12 | FP_Snow_Fir_Tree | 167.0 | 62.00 | 0.30 | 311.4 | annulus |
| TreeSite13 | FP_Snow_Fir_Sapling | 188.0 | 65.00 | 0.30 | 350.6 | annulus |
| TreeSite14 | FP_Snow_Fir_Tree | 194.0 | 62.50 | 0.30 | 1.8 | annulus |
| TreeSite15 | FP_Snow_Fir_Sapling | 213.0 | 65.50 | 0.30 | 37.2 | annulus |
| TreeSite16 | FP_Snow_Fir_Tree | 275.0 | 62.00 | 0.30 | 152.8 | annulus |
| TreeSite17 | FP_Snow_Fir_Sapling | 282.0 | 65.50 | 0.30 | 165.9 | annulus |
| TreeSite18 | FP_Snow_Fir_Tree | 300.0 | 62.50 | 0.30 | 199.4 | annulus |
| TreeSite19 | FP_Snow_Fir_Sapling | 313.0 | 62.00 | 0.30 | 223.7 | annulus |
| TreeSite20 | FP_Snow_Fir_Tree | 333.0 | 65.00 | 0.30 | 261.0 | annulus |
| TreeSite21 | FP_Snow_Fir_Sapling | 340.0 | 61.50 | 0.30 | 274.0 | annulus |
| TreeSite22 | FP_Snow_Fir_Tree | 23.4 | 95.85 | 0.00 | 65.3 | approach, world grass |
| TreeSite23 | FP_Snow_Fir_Tree | 334.1 | 80.06 | 0.00 | 299.8 | approach, world grass |
| TreeSite24 | FP_Snow_Fir_Sapling | 24.4 | 106.51 | 0.00 | 75.6 | approach, world grass |
| TreeSite25 | FP_Snow_Fir_Sapling | 323.6 | 80.80 | 0.00 | 277.5 | approach, world grass |
| RockSite01 | FP_Snow_Rock_Wide | 20.0 | 61.50 | 0.30 | 37.3 | annulus |
| RockSite02 | FP_Snow_Rock_Tall | 40.0 | 64.50 | 0.30 | 74.6 | annulus |
| RockSite03 | FP_Snow_Rock_Wide | 181.0 | 61.50 | 0.30 | 337.5 | annulus |
| RockSite04 | FP_Snow_Rock_Tall | 201.0 | 65.50 | 0.30 | 14.8 | annulus |
| RockSite05 | FP_Snow_Rock_Wide | 219.0 | 62.00 | 0.30 | 48.4 | annulus |
| RockSite06 | FP_Snow_Rock_Tall | 294.0 | 65.00 | 0.30 | 188.2 | annulus |
| RockSite07 | FP_Snow_Rock_Wide | 307.0 | 65.50 | 0.30 | 212.5 | annulus |
| RockSite08 | FP_Snow_Rock_Tall | 326.0 | 61.50 | 0.30 | 247.9 | annulus |
| RockSite09 | FP_Snow_Rock_Wide | 21.3 | 88.02 | 0.00 | 91.7 | approach, world grass |
| RockSite10 | FP_Snow_Rock_Tall | 338.9 | 80.41 | 0.00 | 276.9 | approach, world grass |
| RockSite11 | FP_Snow_Rock_Wide | 27.1 | 101.07 | 0.00 | 131.8 | approach, world grass |
| RockSite12 | FP_Snow_Rock_Tall | 329.0 | 81.63 | 0.00 | 239.7 | approach, world grass |
| DriftSite01 | FP_Snow_Drift | 6.0 | 62.00 | 0.30 | 11.2 | annulus |
| DriftSite02 | FP_Snow_Drift | 175.0 | 65.50 | 0.30 | 326.3 | annulus |
| DriftSite03 | FP_Snow_Drift | 207.0 | 62.00 | 0.30 | 26.0 | annulus |
| DriftSite04 | FP_Snow_Drift | 288.0 | 61.50 | 0.30 | 177.1 | annulus |
| DriftSite05 | FP_Snow_Drift | 320.0 | 65.50 | 0.30 | 236.7 | annulus |
| IcicleSite01 | FP_Icicle_Cluster | 70.0 | 60.10 | 5.50 | 290.0 | **hanging** under `LedgeDeck` |
| IcicleSite02 | FP_Icicle_Cluster | 84.0 | 60.10 | 5.50 | 276.0 | **hanging** under `LedgeDeck` |
| IcicleSite03 | FP_Icicle_Cluster | 126.0 | 60.10 | 5.50 | 234.0 | **hanging** under `LedgeDeck` |
| IcicleSite04 | FP_Icicle_Cluster | 138.0 | 60.10 | 5.50 | 222.0 | **hanging** under `LedgeDeck` |
| IcicleSite05 | FP_Icicle_Cluster | 103.0 | 70.90 | 20.20 | 257.0 | **hanging** under `CascadeLip` |
| IcicleSite06 | FP_Icicle_Cluster | 241.4 | 58.75 | 10.35 | 302.0 | **hanging** under the porch eave |
| CrateSite01 | FP_Supply_Crate | 235.2 | 61.37 | 5.42 | 122.0 | hut porch |
| CrateSite02 | FP_Supply_Crate | 235.2 | 61.37 | 7.83 | 122.0 | **stacked on CrateSite01** |
| CrateSite03 | FP_Supply_Crate | 228.0 | 63.00 | 5.20 | 154.9 | hut terrace |
| CrateSite04 | FP_Supply_Crate | 118.0 | 62.80 | 6.40 | 293.6 | hut porch |
| CrateSite05 | FP_Supply_Crate | 348.0 | 62.00 | 0.30 | 86.5 | annulus |
| RopeSite01 | FP_Rope_Coil | 242.1 | 61.26 | 5.42 | 150.6 | hut porch |
| RopeSite02 | FP_Rope_Coil | 90.0 | 62.20 | 6.40 | 333.0 | hut porch |
| RopeSite03 | FP_Rope_Coil | 252.0 | 62.00 | 5.20 | 234.1 | hut terrace |

## 11. Lights

Seven PointLights, all at the entrance, the bridge or the hut, as the brief asks:
`ArchLanternGlass` x2 (brightness 1.0, range 14), `BridgeLanternGlass` x2
(1.0 / 11.2), `PorchLanternGlass` x1 (1.0 / 11.9), `HutWindow` x2 (0.85 / 16).
No particle systems and no change to `Lighting` or to `regionAmbience`.

## 12. Measured validation

Frostbite against the three shipped hand-built regions, same harness, same rules:

| Check | Frostbite | Cinder | Gusty | Splashwater |
|---|---|---|---|---|
| Parts | 806 | 589 | 663 | 503 |
| Innermost solid, true footprint distance | **59.00** | 50.30 | 53.68 | 46.89 |
| Solid parts inside radius 44 | **0** | 0 | 0 | 0 |
| Parts over 0.95 tall inside radius 58 | **0** | 51 | 356 | 33 |
| Neon inside radius 58 | **0** | 3 | 0 | 0 |
| Coplanar overlapping top faces (exact SAT) | **0** | 7 | 208 | 68 |
| Boundary ring opening | 14.75° | 13.75° | 14.75° | 14.25° |
| Board box intersections | 0 | 0 | 0 | 0 |
| Board sightlines blocked, of 27 | 0 | 0 | 0 | 0 |
| Non-finite transforms | 0 | 0 | 0 | 0 |

Route continuity, Frostbite only:

- **177 of 177** walkable surfaces reachable on foot from the region ground.
- Ledge route: ground → 11 steps (riser **0.5455**) → ledge A → 9 bridge planks →
  ledge B → 11 steps back down. Largest step **0.440** (the bridge sag),
  **largest horizontal gap 0.000**. Both flights measure identically.
- Terrace route: ground → 10 steps (riser **0.484**) → terrace → porch.
  Largest step **0.220** (the porch lip), largest gap 0.000.
- Largest riser anywhere **0.546**, against the brief's 0.70 target.

### The one finding worth your attention

A character with the default Humanoid can chain jumps up onto the containment ring.
Measured, hops from the field to a `Perimeter` top at a 6.0-stud reach:

| Region | Hops | Chain |
|---|---|---|
| Gusty Gardens | **1** | ground → `Perimeter` (5.9) |
| Frostbite Peaks | **3** | ground → `CliffBench` (2.6) → `CliffBench` (7.0) → `Perimeter` (13.0) |
| Cinder Canyon | **4** | ground → `Strata` x3 → `Perimeter` (10.6) |
| Splashwater Bay | unreachable at 6.0 | reachable at 7.2 |

This is a property of every region in the game, not of this one, and it is what
`RegionAccessService` exists for: its comment says *"server-side region volumes
enforce purchased access from every direction and at every height (jumping over a
fence is still entry)"*, and it re-checks a 78-stud cylinder every 0.2 s with no
height limit. So it is not an unlock bypass. The zone heights in §5 were chosen to
push Frostbite from 2 hops to 3 and to keep `PeakBase` out of reach, which is as
far as it can go without flattening the terraced cliff that is the approved
concept. **Please do not reintroduce a mid-height shelf within 7.2 studs of the
wall behind it** when you fit the cliff art.

## 13. Reproducing the measurements

No Studio needed. Lune 0.10.5, and the module is deliberately `require`-free so it
runs headless:

```
lune run measure2.luau <repo>/src/server/Map/FrostbitePeaks.luau 270 frost.json
python analyse.py     # clearance, quiet field, containment, z-fighting, board
python route.py       # route continuity, risers, asset sites
python facts.py       # every dimension in this document
python escape.py      # the chain-jump comparison
```

**Caution if you reuse that harness:** Lune 0.10.5's `CFrame.lookAt` returns the
negated Z of Roblox's — `lookAt(origin, +Z).LookVector` is `(0, 0, -1)`. The
harness patches it by mirroring the target. `CFrame.Angles` is correct.

## 14. Deviations from the V2 reference, and limitations

1. **The board is on the image LEFT, the render puts a signpost on the right.**
   `GateSign` is fixed by `MapBuilder` at local `(24, 9.4, -90)` and the brief says
   to preserve it. The arch's hanging plaque is the render's sign, decorative.
2. **The render's distant mountain range is not built.** Only the five near peaks
   inside radius 91 are, per the brief's "backdrop inspiration, not a giant terrain
   expansion".
3. **The cave mouth on the render's left cliff is not built.** It would need its own
   containment story; the alcove precedent from Cinder Canyon would suit it if wanted.
4. **The bridge is 16.5 studs, longer than the render's**, because it has to span a
   gorge wide enough to read at Roblox scale and still leave two usable ledges.
5. **The four tall firs on the cliff benches clip the wall behind them** by 1.2 – 3.7
   square studs of canopy footprint, because a bench is 3.6 studs deep in front of the
   wall face and a tall fir is 5.1 deep. It reads as a tree growing against rock and was
   left deliberately; the four saplings on benches clip nothing. Every other prop pair and
   prop-to-structure overlap in the region measures zero, checked exhaustively.
6. **Placeholder geometry, not finished art** — faceted blocks, flat colours, no
   sculpted rock, no plank texture, no rope twist.
7. **Part count 806, the highest of the four hand-built regions.** The cheapest
   trims, in order: `LedgeFence`/`TerraceFence` (34 parts), the `TierSnow`/`CliffTier`
   shelves (18), bridge rope rails and hangers (24), the second stair flight (33). Mobile frame time is unmeasured.
8. **Nothing has been seen running in Roblox Studio.** Unverified: the 935 SelfTest /
   72 LiveTest baseline, the new `SceneryVersion = 3` assertion, the live sign rays,
   creature spawning and roaming, whether the cyan Ice Wave telegraph actually reads
   against `rgb(191, 207, 220)` snow in motion, whether the stairs and bridge feel
   right to walk, and mobile cost. §12's numbers are geometry, not gameplay.

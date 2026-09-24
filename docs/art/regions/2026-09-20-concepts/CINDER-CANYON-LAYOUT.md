# Cinder Canyon layout — asset handoff — 2026-09-20

The playable blockout of the V2 **Sculpted Ravine** concept is in
`src/server/Map/CinderCanyon.luau`. Everything it builds is simple geometry in flat
identifying colours, standing in for custom Blender assets.

**Reference:** `cinder-canyon-v2-sculpted-ravine.png` in this folder.
**Concept prose:** the "Sculpted Ravine: exact prompt" section of `CINDER-ALTERNATIVES.md`.

This document is the contract. You should not have to measure a screenshot: every
placeholder's name, size, frame and collision role is below, and the numbers were
read back out of the built geometry, not copied from intent.

---

## 1. Coordinate frame

`RegionScenery` calls `CinderCanyon.build(parent, frame, radius, makePart)` with

```lua
frame = CFrame.lookAt(centre, Vector3.new(0, centre.Y, 0))   -- centre = polar(280, 210)
radius = 75
```

Every placement in the module is `frame * CFrame.new(...)`, so all coordinates below
are **local to `frame`**. In world terms Cinder Canyon's centre is
`(-242.49, 0, -140.00)` and `frame` is exactly `CFrame.new(centre) * CFrame.Angles(0, math.rad(-120), 0)`.

| Axis | Meaning |
|---|---|
| `-Z` | Entrance, toward the hub. The gate is at `z = -80`, the board at `(24, 10.6, -90)`. |
| `+Z` | Rear of the region. |
| `+X` | The player's **left** as they walk in. |
| `-X` | The player's **right** as they walk in. |
| `y = 0` | Region datum. The **walkable ground surface is `y = 0.30`**; the terracotta field skin on top of it is `y = 0.60`. |

Pivots are Roblox defaults — each part's own centre. Nothing is welded, nothing is
unanchored.

### The ring frame

Most of the region is placed on a **ring frame** at a compass bearing `a` and a radius `r`:

```lua
local function ring(a, r)
	return CFrame.new(math.sin(a) * r, 0, -math.cos(a) * r) * CFrame.Angles(0, -a, 0)
end
```

Bearing `0` is the entrance, `90` is `+X` (the player's left), `180` is the rear,
`270` is `-X` (their right). **In a ring frame, local `+Z` points inward at the region
centre** and local `+X` runs tangentially. A local offset of `d` along `+Z` lands at
radius `r - d`; a local offset along `+X` is purely tangential. Facing direction for
every ring-placed asset is therefore "inward, toward the middle of the arena".

### Mapping the render to the frame

The mockup is drawn from outside the entrance looking in, so **the image's left is `+X`**:

| In the render | Local placement |
|---|---|
| Sandstone arch, rear-left | ring bearing **152**, radius 73 |
| Three lavafalls and terraces, rear-right | ring bearing **228**, radius 73 |
| Winding walkway, left ledge | ring bearings **50–140**, radius 63 |
| Curved black-stone bridge | ring bearings **77–89**, radius 63 |
| Side alcove | ring bearing **112**, radius 74 |
| Entrance pillars | local `(+/-13.2, y, -80)`, unrotated |

---

## 2. Radial budget — the rule that must survive your pass

| Band | What may stand there |
|---|---|
| `r < 44` | **Nothing solid.** `SpawnRadius` is 44: creatures spawn at `NextNumber(10, 44)` and `EncounterService.clampToField` clamps every roaming leg to it. Only flush, walk-through decals (`CanCollide` and `CanQuery` false, under half a stud proud). |
| `44 <= r < 56` | Field skin. Flush detail only. |
| `56 <= r < 58` | Nothing. |
| `58 <= r <= 73` | All scenery. |
| `r = 75` | The boundary ring, inner face 73.4. |

A Heat eruption is `shape = "circles", radius = 4, count = 3, spawnRadius = 12` thrown
around a creature that may stand at radius 44, so the ground stays **flat and matte out
to about radius 60**. Keep glowing crack detail off the field: the telegraph has to be
the brightest thing on it.

**The one deliberate exception** is the stair up to the walkway, whose bottom tread
reaches radius 50.4 at 1.2 studs tall. That is still further out than Splashwater Bay's
shipped `TideShelf` (46.9), so it is within the precedent the game already sets.

---

## 3. What each group is, and what to replace it with

Sizes, radii and heights for every group are in the measured table in section 5.

**Boundary ring — `Perimeter`, `Strata`, `BasaltFace`, `BasaltColumn`, `Coping` (216 parts).**
48 tangential segments with `i = 2..46` built; `i = 47, 0, 1` are the entrance gap. Three
rock styles, matching the render:

| Segments | Bearings | Style |
|---|---|---|
| `i = 2..5`, `39..46` | 15–37.5, 292.5–345 | Low columnar charcoal basalt either side of the entrance, 9–10.6 tall |
| `i = 6..18` | 45–135 | Terracotta sandstone in three strata bands of different depth, 18–22.5 tall |
| `i = 19..23` | 142.5–172.5 | The same sandstone held low and level at 16–16.35, the **arch window** |
| `i = 24..38` | 180–285 | Slanted charcoal basalt with splayed columns, 21–28.8 tall |

This is the **striated curved cliff kit** the concept asks for. A reusable module: one
curved sandstone segment and one basalt segment, each about 10.3 studs of chord at radius
75, repeated round the ring. Replace the `Strata`/`BasaltColumn` shells freely — but
`Perimeter` and the `Boundary` model as a whole is the containment barrier and must keep
an unbroken solid core at every bearing except the entrance.

**Natural arch — `ArchLeg` x4, `ArchVoussoir` x7, `ArchButtress` x2.**
A **unique landmark**, the tallest thing in the region at `y = 35.6`. Ring bearing 152,
radius 73, so it straddles the wall and reads as one rock mass with it. Faceted voussoirs
on an ellipse of `rx = 19.5`, `ry = 10.5` about arch-local `(0, 22)` at
`theta = 15 + 25k` degrees — replace the lot with one sculpted mesh.

Its opening runs from the wall top (`y 17.2`) to the arc underside (`y 20.3` at the
springing, about 29.8 at the crown), 29.5 studs wide between the leg inner faces. **You
see sky and distant mesa through it; you cannot walk through it.** That is deliberate and
is what the concept means by "sculpted rock walls close all gaps below the elevated arch".
Keep the opening above `y 17` or the region stops being enclosed.

**Lavafall assembly — `FissureMouth`, `FissureGlow`, `LavaRibbon` x12, `RibbonCrust` x12,
`LavaLedge` x4, `LedgePool` x4, `LedgeLip` x4.**
Ring bearing 228, radius 73. One fissure at `y 25` feeds three ribbons at fall-local
`x = -11, 1, 12`, dropping from `y 24` to three different ledge heights (14, 8, 11) and
spilling onto a broad shelf at `y 2.6` that meets the perimeter terrace. This is the
**sculpted terrace lavafall** asset — a unique landmark, best as one mesh plus a separate
emissive lava surface so the glow can be animated later.

**Perimeter lava terrace — `TerraceBed` x10, `TerraceLava` x10, `TerraceCurb` x10,
`CurbStone` x4.** Bearings 202–268 in ten steps. Recessed on purpose: the bed tops out at
`y 0.10` and the lava at `y 0.25`, both **below** the surrounding ground at `0.30`, behind
a continuous dark curb whose top is `y 1.40` at radius 57.3–59.8. The curb is the thing
that keeps lava visually and physically off the catching field — keep it, whatever the
lava becomes.

**Recessed lava channels — `ChannelBed` x3, `ChannelLava` x3, `ChannelCurb` x6,
`ChannelStone` x6.** Three short radial footprints at bearings 30, 172 and 290, radius
57.5–68.5, each sunk below ground between its own pair of curbs. Reusable module.

**Walkway and stair — `WalkwayBench` x14, `WalkwayDeck` x14, `RailPost` x7, `RailBar` x7,
`CanyonStep` x8, `StairKerb` x16.** The left ledge: a solid rock bench at radius 59–67
with a stone deck on top at `y 5.5`, rail on the drop side at radius 60, and a gap at
bearings 78–90 for the bridge. The stair climbs outward along bearing 50 from radius 51 to
60.8 in eight risers of **0.618 studs** each.

`Walkways` is a functional model: these are walking surfaces, and replacing the art must
not remove them. Deck segments are a butt joint at the 6.59-stud chord and alternate
heights by 0.03 studs so their coplanar tops cannot z-fight; keep that trick or make one
continuous curved deck mesh.

**Bridge — `BridgeDeck` x9, `BridgeRib` x7, `BridgeRailPost` x10, `BridgeRailBar` x10,
`BridgeLantern*` x8, `CreviceFace` x2, `CreviceGlow` x1.** Bearings 77–89 at radius 63.
The deck follows `y = 5.5 + 2.2 * sin(pi * t)`, cresting at `y 7.7`. Underneath, a slot cut
in the bench down to ground level with a lava glow in it. The **curved footbridge** asset —
a unique landmark, but keep the deck traversable: measured end to end the walkway, bridge
and alcove are 24 surfaces with a largest horizontal gap of **0.00** and a largest step of
**0.84** studs.

**Side alcove — `AlcoveMass`, `AlcoveFloor`, `AlcoveSide` x2, `AlcoveHead` x5,
`AlcoveLantern*` x4.** Ring bearing 112, radius 74. A swelling of the cliff with a recess
carved into its inner face, floor level with the walkway deck, a small faceted arch over
the opening and a bronze lantern on the back wall.

**Entrance — `EntryPillar` x6, `PillarCap` x2, `PillarGroove` x4, `EntryLantern*` x8,
`GateShoulder` x2, `ShoulderCap` x2.** Two three-stage carved sandstone uprights at
`(+/-13.2, y, -80)`, 16.9 studs tall, each with a bronze lantern on its inner face at
`y 10.6`. Angled shoulders close the ring either side of the gate. The approach road is
13.5 studs wide on the centre line and **no solid part enters it** — keep it that way.

**Set dressing — `BasaltPrism` x20, `EmberCrystal` x18, `CrystalCore` x6, `DryGrass` x36,
`ErodedFin` x5, `EmberSeam` x4, `FieldStone` x7, `SedimentSweep` x24, `ApproachGrass` x18,
`ApproachBoulder` x2.** Sparse and asymmetric, as the concept asks. `FieldStone` and
`SedimentSweep` are the only things inside the field and they are flush walk-through
decals — `SedimentSweep` is the swept sediment pattern in the render's sand.

---

## 4. Collision and replaceability

Three sibling Models under `Workspace.Regions.cinder_canyon`:

| Model | Parts | Rule |
|---|---|---|
| `Boundary` | 216 | Containment. An art pass **must not** leave a bearing without a solid core, or players walk out of the region. |
| `Walkways` | 92 | Functional walking surfaces — the field skin, the walkway, the stair, the bridge deck, the alcove floor, and the curbs that separate lava from the field. Replacing art must not remove the playable floor. |
| `Landmarks` | 281 | Replaceable visual placeholders. Swap freely. |

Conventions the module holds to, and that a replacement should keep:

- **Decoration is `CanQuery = false`.** `TestHarness.testRegionSignVisibility` casts 27
  rays per board from the approach road; a queryable prop in the way fails the suite.
  Currently **zero** parts cross those sightlines.
- Every part is `Anchored`, `CanTouch = false`.
- Nothing is a `Terrain` voxel and nothing uses a `SpecialMesh` — the whole region is
  primitive parts, so a mesh swap is purely additive.
- Lava is a **coloured surface only**: no damage, no hazard, no reward, no traversal
  mechanic. `Enum.Material.Neon` with a `PointLight` on seven pieces in total.
- No part has a NaN CFrame. Avoid `CFrame.lookAt` with a vertical look direction, which
  silently produces one.

---

## 5. Measured inventory

Read out of the built geometry. "Footprint radius" is the closest the part's ground
footprint comes to the region centre; "Top y" is the highest point of the group.

| Placeholder | n | Size (studs, X/Y/Z) | Host | Footprint radius | Top y | Collision | Material |
|---|---|---|---|---|---|---|---|
| `AlcoveFloor` | 1 | 13 x 0.8 x 8.5 | Walkways | 65.1 | 5.5 | walkable | Slate |
| `AlcoveHead` | 5 | 3.6 x 2.2 x 8 | Landmarks | 65.0-65.2 | 19.3 | none | Sandstone |
| `AlcoveLanternArm` | 1 | 0.38 x 0.38 x 1.87 | Landmarks | 71.9 | 10.0 | none | Metal |
| `AlcoveLanternCage` | 1 | 1.65 x 2.31 x 1.65 | Landmarks | 70.8 | 10.7 | none | Metal |
| `AlcoveLanternCap` | 1 | 1.98 x 0.44 x 1.98 | Landmarks | 70.6 | 11.2 | none | Metal |
| `AlcoveLanternGlass` | 1 | 1.15 x 1.6 x 1.15 | Landmarks | 71.0 | 10.3 | none | Neon |
| `AlcoveMass` | 1 | 20 x 17 x 11 | Boundary | 69.2 | 17.0 | blocking | Sandstone |
| `AlcoveSide` | 2 | 2.4 x 9 x 8.5 | Boundary | 65.1 | 14.5 | blocking | Sandstone |
| `ApproachBoulder` | 2 | 4 x 2.6 x 3.4 | Landmarks | 87.0-87.2 | 3.1 | none | Rock |
| `ApproachGrass` | 18 | 0.139999 x 1.8-2.39999 x 0.399994 | Landmarks | 85.1-96.6 | 2.6 | none | Grass |
| `ArchButtress` | 2 | 7 x 9 x 7 | Boundary | 71.2 | 9.0 | blocking | Sandstone |
| `ArchLeg` | 4 | 10-11.5 x 8-17.6 x 8.60001-9.5 | Boundary | 69.8-70.3 | 24.2 | blocking | Sandstone |
| `ArchVoussoir` | 7 | 7.8 x 5.4 x 8.8 | Landmarks | 68.7-70.3 | 35.6 | none | Sandstone |
| `BasaltColumn` | 45 | 3.10001 x 21-28.8 x 1.89999 | Boundary | 72.0-72.7 | 28.8 | blocking | Basalt |
| `BasaltFace` | 24 | 3.2 x 9.7-12.5 x 1.60001 | Boundary | 72.7 | 12.5 | blocking | Basalt |
| `BasaltPrism` | 20 | 2.60001 x 9-18.6 x 2.60001 | Landmarks | 58.5-64.7 | 18.6 | blocking | Basalt |
| `BridgeDeck` | 9 | 2.8 x 0.7 x 7.2 | Walkways | 59.4 | 7.7 | walkable | Slate |
| `BridgeLanternArm` | 2 | 0.28 x 0.28 x 1.36 | Landmarks | 66.6 | 8.8 | none | Metal |
| `BridgeLanternCage` | 2 | 1.2 x 1.68 x 1.2 | Landmarks | 65.8 | 9.3 | none | Metal |
| `BridgeLanternCap` | 2 | 1.44 x 0.32 x 1.44 | Landmarks | 65.7 | 9.7 | none | Metal |
| `BridgeLanternGlass` | 2 | 0.84 x 1.16 x 0.84 | Landmarks | 66.0 | 9.1 | none | Neon |
| `BridgeRailBar` | 10 | 4 x 0.3 x 0.35 | Landmarks | 59.7-66.1 | 9.8 | none | Metal |
| `BridgeRailPost` | 10 | 0.4 x 2.2 x 0.4 | Landmarks | 59.6-66.0 | 9.9 | none | Metal |
| `BridgeRib` | 7 | 2.4 x 1.6 x 6 | Landmarks | 60.0 | 6.8 | none | Slate |
| `CanyonFloor` | 1 | 0.5 x 112 x 112 | Walkways | 0.0 | 0.6 | walkable | Sandstone |
| `CanyonStep` | 8 | 7.5 x 1.218-5.54401 x 1.39999 | Walkways | 50.4-60.2 | 5.5 | walkable | Slate |
| `ChannelBed` | 3 | 4.4 x 0.9 x 11 | Walkways | 57.5 | 0.1 | walkable | Basalt |
| `ChannelCurb` | 6 | 1.6 x 1.3 x 11.4 | Walkways | 57.3 | 1.2 | walkable | Basalt |
| `ChannelLava` | 3 | 3 x 0.24 x 10.2 | Landmarks | 57.9 | 0.1 | none | Neon |
| `ChannelStone` | 6 | 2.6 x 1.8 x 2.2 | Landmarks | 57.8-65.2 | 2.1 | blocking | Rock |
| `Coping` | 45 | 10.5315 x 0.899994-1 x 3.60001-4 | Boundary | 73.2-73.4 | 25.2 | blocking | Basalt |
| `CreviceFace` | 2 | 2.4 x 5.6 x 9 | Boundary | 58.5 | 5.6 | blocking | Rock |
| `CreviceGlow` | 1 | 11 x 0.2 x 7 | Landmarks | 59.8 | 0.5 | none | Neon |
| `CrystalCore` | 6 | 0.699997 x 3.96001-4.56 x 0.699997 | Landmarks | 58.6-66.6 | 6.1 | none | Neon |
| `CurbStone` | 4 | 3.4 x 2.2 x 2.8 | Landmarks | 55.9-56.5 | 2.6 | blocking | Rock |
| `DryGrass` | 36 | 0.139999 x 1.89999-2.5 x 0.399994 | Landmarks | 57.7-66.1 | 2.7 | none | Grass |
| `EmberCrystal` | 18 | 1.3 x 4.60001-7.60001 x 1.3 | Landmarks | 57.5-67.1 | 7.7 | none | Glass |
| `EmberSeam` | 4 | 0.300003 x 9.45-10.98 x 0.139999 | Landmarks | 72.5 | 15.2 | none | Neon |
| `EntryLanternArm` | 2 | 0.35 x 0.35 x 1.7 | Landmarks | 80.4 | 11.0 | none | Metal |
| `EntryLanternCage` | 2 | 1.5 x 2.1 x 1.5 | Landmarks | 79.7 | 11.7 | none | Metal |
| `EntryLanternCap` | 2 | 1.8 x 0.4 x 1.8 | Landmarks | 79.6 | 12.1 | none | Metal |
| `EntryLanternGlass` | 2 | 1.05 x 1.45 x 1.05 | Landmarks | 80.0 | 11.3 | none | Neon |
| `EntryPillar` | 6 | 4.60001-6.2 x 4.60001-6.39999 x 4.2-5.39999 | Boundary | 78.0-78.8 | 16.9 | blocking | Sandstone |
| `ErodedFin` | 5 | 2.2 x 9-11.25 x 4.39999 | Landmarks | 71.6 | 21.9 | none | Sandstone |
| `FieldStone` | 7 | 3.2-5 x 0.399994 x 2.39999-3.60001 | Landmarks | 21.8-39.2 | 0.8 | none | Rock |
| `FissureGlow` | 1 | 12.5 x 2.2 x 0.6 | Landmarks | 71.4 | 26.1 | none | Neon |
| `FissureMouth` | 1 | 14 x 4 x 2.2 | Landmarks | 71.6 | 27.0 | none | Basalt |
| `GateShoulder` | 2 | 3.6 x 10 x 12.94 | Boundary | 71.5 | 10.0 | blocking | Basalt |
| `LavaLedge` | 4 | 13-30 x 2.39999-3 x 8-9 | Landmarks | 62.3-64.2 | 14.0 | blocking | Basalt |
| `LavaRibbon` | 12 | 2 x 3.5-3.63333 x 0.699997 | Landmarks | 70.9-71.8 | 24.2 | none | Neon |
| `LedgeLip` | 4 | 14-31 x 1.2 x 1 | Landmarks | 60.5-63.7 | 14.4 | none | Basalt |
| `LedgePool` | 4 | 10-27 x 0.399994 x 5.5-6.5 | Landmarks | 63.2-65.6 | 14.2 | none | Neon |
| `Perimeter` | 27 | 10.3315 x 9-24.4 x 3.39999-3.60001 | Boundary | 73.4-73.5 | 24.4 | blocking | Basalt |
| `PillarCap` | 2 | 5.2 x 0.9 x 4.8 | Landmarks | 78.3 | 17.8 | none | Sandstone |
| `PillarGroove` | 4 | 0.32 x 5.2 x 0.24 | Landmarks | 79.2-81.9 | 12.0 | none | Sandstone |
| `RailBar` | 7 | 13 x 0.35 x 0.4 | Landmarks | 60.0 | 8.0 | none | Metal |
| `RailPost` | 7 | 0.5 x 2.5 x 0.5 | Landmarks | 59.8 | 8.0 | none | Metal |
| `RibbonCrust` | 12 | 3 x 3.60001-3.73334 x 0.5 | Landmarks | 71.5-72.4 | 24.3 | none | Basalt |
| `SedimentSweep` | 24 | 13.6808-30.0978 x 0.0800018 x 1.39999 | Landmarks | 19.9-44.0 | 0.7 | none | Sandstone |
| `ShoulderCap` | 2 | 4.1 x 0.8 x 12.94 | Boundary | 71.3 | 10.8 | blocking | Basalt |
| `StairKerb` | 16 | 0.800003 x 1.918-6.244 x 1.39999 | Walkways | 50.4-60.2 | 6.2 | walkable | Sandstone |
| `Strata` | 54 | 10.3315 x 5.33333-7.5 x 3-3.7 | Boundary | 73.3-73.7 | 22.5 | blocking | Sandstone |
| `TerraceBed` | 10 | 9 x 1 x 13 | Walkways | 59.7 | 0.1 | walkable | Basalt |
| `TerraceCurb` | 10 | 7.9 x 1.6 x 2.6 | Walkways | 57.3 | 1.4 | walkable | Basalt |
| `TerraceLava` | 10 | 8.4 x 0.3 x 12 | Landmarks | 60.1 | 0.3 | none | Neon |
| `WalkwayBench` | 14 | 6.89999 x 5.06-5.10001 x 8 | Walkways | 59.1 | 5.1 | walkable | Sandstone |
| `WalkwayDeck` | 14 | 6.62 x 0.8 x 7 | Walkways | 59.6 | 5.5 | walkable | Slate |

Total 589 parts: Boundary 216, Walkways 92, Landmarks 281

---

## 5b. Where `assets/cinder-canyon/props-v1` already fits

The nine reusable props in that manifest map onto placeholder groups here. Their pivot
is **ground-centre**; every placeholder below is **centre-pivoted**, so place a mesh at
the placeholder's *base*, not its centre — that is `y = top - size.Y` for the group.

| props-v1 asset | Its size (studs) | Replaces | Placeholder size | Fit |
|---|---|---|---|---|
| `CC_Basalt_Tall` 4.31 x 5.80 x 3.14 | boulder | `BasaltPrism` | 2.6 x 9.0-18.6 x 2.6 | **needs a taller variant** — the spires are 1.5-3.2x its height |
| `CC_Basalt_Wide` 5.68 x 4.00 x 3.19 | boulder | `CurbStone` 3.4 x 2.2 x 2.8, `ApproachBoulder` 4.0 x 2.6 x 3.4 | — | close; scale to about 0.65 |
| `CC_Basalt_Low` 3.82 x 2.20 x 2.87 | boulder | `ChannelStone` 2.6 x 1.8 x 2.2 | — | near-exact, scale about 0.75 |
| `CC_Ember_Tall` 2.65 x 4.38 x 1.80 | crystal | tallest shard of each `EmberCrystal` cluster | 1.3 x 5.4-7.6 x 1.3 | good; scale up about 1.3 in Y |
| `CC_Ember_Fan` 2.80 x 3.38 x 1.67 | crystal | middle `EmberCrystal` shard | 1.3 x 4.6-6.6 x 1.3 | good |
| `CC_Ember_Small` 2.23 x 1.88 x 1.20 | crystal | shortest `EmberCrystal` shard | 1.3 x 3.6-5.6 x 1.3 | good |
| `CC_Sandstone_Wide` 5.18 x 2.10 x 3.43 | rock group | `ApproachBoulder`, loose rock at the wall foot | 4.0 x 2.6 x 3.4 | near-exact |
| `CC_Sandstone_Tall` 3.01 x 3.50 x 2.53 | rock group | new dressing at the stair and alcove | — | free placement |
| `CC_Sandstone_Rubble` 4.34 x 1.25 x 2.83 | rock group | `FieldStone` | 3.2-5.0 x **0.4** x 2.4-3.6 | plan matches, but **it is 3x too tall** — `FieldStone` sits inside the catching field and must stay under half a stud proud. Flatten it or sink it. |

Cluster sites, as ring `(bearing degrees, radius)`, each holding one cluster:

- `BasaltPrism`, four spires per site: `(18, 63) (300, 66) (168, 62) (282, 64) (340, 62)`
- `EmberCrystal`, three shards per site: `(214, 67) (246, 65) (262, 63) (24, 60) (196, 68) (330, 62)`

`CrystalCore` is a small Neon core inside the tallest shard of each ember cluster and is
where the manifest's "optional Roblox light/effect at placement" belongs. Note that the
placeholder crystals are decorative (`CanCollide` false) while the basalt spires are
solid — the manifest says to disable collision on the props and rely on layout collision
underneath, which is exactly what the `Boundary` and `Walkways` models provide.

---

## 6. Known divergences from the render

1. **The board is on the player's left, not their right.** The render puts the
   information board right of the entrance. The real `GateSign` is fixed at local
   `(24, 10.6, -90)` — the player's left — by `MapBuilder`, and the brief says to preserve
   it. Do not move it.
2. **The arch opening starts above the barrier.** In the render the arch reads as a hole
   through the cliff at ground level. It cannot be: the region must stay enclosed. The
   opening runs from `y 17.2` up, over a solid 16-stud wall.
3. **Cliff strata are three flat bands, not sculpted erosion**, and arches are faceted
   voussoirs rather than curves. That is the placeholder brief — this is the geometry you
   are replacing.
4. **The lava terrace is a shallow recessed trough, not a pool with depth.** The region
   ground is one solid disc and nothing can be dug out of it, so "recessed" is achieved
   with a raised curb and a lava surface 0.05 studs below the surrounding ground.

---

## 7. Verifying a replacement

Static, from the repository root:

```
python tools/luau_lint.py src
python tools/quote_scan.py src
rojo build default.project.json -o build/CinderCanyon.rbxl
```

In Studio, the suites that cover this region are `[SelfTest]` and `[LiveTest]`:

- `region access + roaming` asserts `SceneryVersion == 4` on the Cinder model. Bump it if
  you change the builder, and update `SCENERY_VERSION` in `TestHarness.luau`.
- `region field clearance` asserts nothing solid stands inside `SpawnRadius`.
- `region sign visibility` asserts the board is unobstructed from the approach road.

By hand: walk in through the gate, cross the field, take the stair to the walkway, cross
the bridge, stand in the alcove, and start a capture in the middle to see that the
eruption circles read against the sand.

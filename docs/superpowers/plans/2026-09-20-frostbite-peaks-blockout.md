# Frostbite Peaks Alpine-Expedition Blockout Implementation Plan

> **For agentic workers:** Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Frostbite Peaks' generic Frost scenery with a playable blockout of the
approved V2 "Alpine Expedition" concept — simple geometry, flat identifying colours,
named asset sites — that Codex can dress with the `frostbite-peaks/props-v1` kit and a
later fitted-art pass without losing the floor, the containment barrier or the walkable
route.

**Architecture:** A new `src/server/Map/FrostbitePeaks.luau` following the `CinderCanyon`
precedent exactly: one `build(parent, frame, radius, makePart)` entry point that
`RegionScenery` delegates to for `element == "Frost"`. Three sibling Models split the
output by replaceability — `Boundary` (containment collision, never remove), `Walkways`
(functional walkable surfaces), `Landmarks` (replaceable visual placeholders, including
one Model per Codex asset site carrying its name, size, ground CFrame and collision role
as attributes).

**Tech Stack:** Luau, Rojo 7.7.0, Roblox Studio. Static checks `python tools/luau_lint.py src`,
`python tools/quote_scan.py`, `python tools/stamp.py`. Headless geometry measurement with
Lune 0.10.5 (`C:/Users/rahul/AppData/Local/Temp/lunebin/lune.exe`).

**Spec:** `docs/art/regions/2026-09-20-concepts/FROSTBITE-PEAKS-CLAUDE-HANDOFF.md`
**Reference image:** `docs/art/regions/2026-09-20-concepts/frostbite-peaks-v2-alpine-expedition.png`
**Concept notes:** `docs/art/regions/2026-09-20-concepts/FROSTBITE-ALTERNATIVES.md`
**Codex kit:** `assets/frostbite-peaks/props-v1/manifest.json` (exact exported dimensions)

---

## Global Constraints

Copied from the spec and from the code the spec must not break.

- **Repository:** `C:\Users\rahul\orca\Catch-a-Catastrophe`, branch `main`. Preserve the
  ~21 modified / many untracked files already in the working tree, and everything under
  `assets/frostbite-peaks/` — that is Codex's, written concurrently.
- **Do not publish. Do not commit.** (`AGENTS.md` items 6 and 8.)
- **Do not hand-patch Studio script `.Source`.** Rojo is the only sync path.
- **Do not import assets, add mesh IDs or fake imported assets.** Codex owns import.
- **Preserve** `Gate`, `UnlockPrompt`, `Entrance`, `GateSign`, `GateSignStand`, the
  `RegionGate` tag and every region attribute. No economy, species, encounter,
  progression or hazard change.
- **Clear catching field: radius 44.** Nothing solid inside it, measured from the nearest
  point of a part's ground footprint.
- **Flat matte field to radius ~56; normal props and landmark bases outside radius 58.**
- **Ground datum:** region ground disc top `y = 0.30` local; region centre `y = 0`.
  `disc()` in MapBuilder takes a **top** position and subtracts half the thickness.
- **Frost hazard is a line**, `length 11, width 2.0, travel 30, telegraph 1.2, active 1.8`,
  colour `rgb(170, 230, 255)`. Do not change it, and do not let the field go so bright
  that the cyan telegraph stops reading.
- **No slippery walking surfaces.** `Enum.Material.Ice` (friction 0.02) and `Glacier`
  (0.05) appear on `CanCollide = false` decoration only. Walkable snow is
  `Enum.Material.Snow` (friction 0.3, same as plastic).
- **Z-fighting:** no coplanar faces. Built floors bury their bottoms in the disc below;
  stacked surfaces keep >= 0.10 stud clearance; adjacent equal surfaces jog by >= 0.03.
- **Cylinders run along local X.** A vertical cylinder is `Vector3.new(height, d, d)` with
  `CFrame.Angles(0, 0, math.rad(90))`.
- **A Write hook rejects any file containing a dot followed by `format(`.** Use the
  `("%d"):format(x)` colon form.
- **The Bash tool strips one backslash level even inside quoted heredocs.** Write Luau
  with the Write/Edit tools, never a Bash heredoc.
- **Decoration is `CanQuery = false`** so it cannot absorb the 27 sightline rays
  `testRegionSignVisibility` casts per board.
- **Nothing in `Boundary` or `Landmarks` may intersect the board box** — 18 x 10 x 0.65
  centred at local `(24, 9.4, -90)`, i.e. `x 15..33, y 4.4..14.4, z -90.325..-89.675`.
  `testRegionSignVisibility` runs `GetPartBoundsInBox` over exactly those two Models.
- **Avoid degenerate `CFrame.lookAt`.** Two points differing only in Y with the default
  up vector yields NaN. Supply an alternate up vector or do not use `lookAt`.

---

## Coordinate frame (the contract Codex builds against)

`RegionScenery` hands the module `frame = CFrame.lookAt(centre, Vector3.new(0, centre.Y, 0))`,
`centre = polar(280, 270) = (0, 0, -280)` world. Every number below is **local to that
frame** and is applied as `frame * CFrame.new(...)`.

| Axis | Direction |
|---|---|
| `-Z` | Entrance, toward the hub. The gate is at `z = -80`. |
| `+Z` | Rear of the region. |
| `+X` | The player's **left** on entering — image LEFT (bridge, cascade). |
| `-X` | The player's **right** — image RIGHT (expedition hut). |
| `+Y` | Up. Ground disc top `0.30`; field skin top `0.60`. |

Verified from source: `gateCF = CFrame.new(polar(200, 270)) * CFrame.Angles(0, rad(-180), 0)`
has the same orientation as `frame` and sits at local `(0, 0, -80)`, so
`signCF = gateCF * CFrame.new(24, 9.4, -10)` is local `(24, 9.4, -90)`.

Ring frame, used for every perimeter placement:

```lua
local function ring(a: number, r: number): CFrame
    return CFrame.new(math.sin(a) * r, 0, -math.cos(a) * r) * CFrame.Angles(0, -a, 0)
end
local function bearing(degrees: number, r: number): CFrame
    return ring(math.rad(degrees), r)
end
```

Bearing 0 = entrance, 90 = image left, 180 = rear, 270 = image right. Inside the ring
frame `+X` is tangential (increasing bearing) and **`+Z` points inward** at the centre.

## Radial budget

| Radius | What lives there |
|---|---|
| 0 – 44 | `SpawnRadius`. Absolutely nothing solid. |
| 0 – 57 | `SnowField` skin, top `y = 0.60`. Flush sweeps and stones only. |
| 57 – 69.6 | Cliff-foot annulus on the bare ground disc, top `y = 0.30`. Prop sites live here, all outside 58. |
| 59 – 75 | Ledge / terrace benches, stairs, bridge, hut. Innermost solid: terrace kerb at 59.35. |
| 69.6 – 74.6 | `CliffBench`, the first terrace of the perimeter cliff. |
| 73.2 – 76.8 | `Perimeter`, the continuous containment ring at radius 75. |
| 73 – 93 | Rear peaks and saddles, outside the ring. |

## File structure

| File | Responsibility |
|---|---|
| `src/server/Map/FrostbitePeaks.luau` | **New.** The whole blockout. Self-contained: no `require`, so it runs under the headless harness. |
| `src/server/Map/RegionScenery.luau` | Add the Frost delegation; delete the dead Frost palette entry and dressing branch; simplify the two now-constant Storm/Cosmic conditionals. |
| `src/server/Map/MapBuilder.luau` | One narrow change: exclude Frost from the industrial `GatePost`/`GateLintel`/`hazardStrip` trim. |
| `src/server/Systems/TestHarness.luau` | `SCENERY_VERSION.Frost = 3`. |
| `docs/CONTRACTS.md` | Document the Frost delegation, the three-Model split and the asset-site attributes. |
| `docs/art/regions/2026-09-20-concepts/FROSTBITE-PEAKS-LAYOUT.md` | **New.** The measured asset contract for Codex. |
| `docs/art/regions/2026-09-20-concepts/frostbite-peaks-layout-plan.svg` | **New.** Measured top-down plan. |
| `RELAY.md` | New checkpoint at the top. |

---

## Task 1: The module skeleton and the catching field

**Files:** Create `src/server/Map/FrostbitePeaks.luau`.

**Interfaces:**
- Produces: `FrostbitePeaks.build(parent: Model, frame: CFrame, radius: number, makePart: (any) -> Part)`.
  Creates `Boundary`, `Walkways`, `Landmarks` under `parent` and sets
  `parent:SetAttribute("SceneryVersion", 3)`.

- [ ] **Step 1: Write the header, palette and helpers.** `part`, `disc`, `ring`, `bearing`,
  `flat`, `glow`, `lantern` and `site` copied in shape from `CinderCanyon.luau:63-108`.
  `site(host, name, asset, size, cf, role) -> Model` sets `AssetName`, `AssetSize`,
  `GroundCF`, `CollisionRole`.
- [ ] **Step 2: Build the field.** `disc("SnowField", 114, 0.5, CFrame.new(0, 0.35, 0), SNOW_FIELD, Snow, true, walkways)`
  — centre `y = 0.35`, so top `0.60`, bottom `0.10` buried in the disc below.
  Twelve `WindSweep` flush arcs and seven `FieldStone` flush stones, all `flat()`.
- [ ] **Step 3: Verify it loads.** `python tools/luau_lint.py src` and
  `python tools/quote_scan.py`. Expected: pass, file count up by one.
- [ ] **Step 4: Verify it runs headless.** Run the Lune harness (Task 9) against the module.
  Expected: `> 20 parts`, hosts `Boundary, Walkways, Landmarks`.

## Task 2: The perimeter ring and gate shoulders

**Files:** Modify `src/server/Map/FrostbitePeaks.luau`.

**Interfaces:** Consumes `part`, `ring`, `bearing` from Task 1.

- [ ] **Step 1: 48-segment ring, `i = 2, 46`.** `L = 2 * radius * tan(pi / 48) + 0.5`.
  Zones: `low` when `i <= 6 or i >= 42` (`h = 11 + (i % 3) * 0.9`), `ridge` when
  `20 <= i <= 28` (`h = 23 + (i % 3) * 1.6`), else `h = 17 + (i % 4) * 1.3`.
  Per segment, all solid in `Boundary`:
  `Perimeter` `V(L, h, 3.6)` at `CF(0, h/2, 0)`;
  `CliffBench` `V(L, bh, 5.0)` at `CF(0, bh/2, 2.9)` with `bh = 4.6 + (i % 4) * 0.8`;
  `BenchSnow` `V(L + 0.15, 1.2, 5.4)` at `CF(0, bh + 0.35, 2.9)`;
  `CliffCornice` `V(L + 0.2, 1.5, 4.4)` at `CF(0, h + 0.45 + (i % 2) * 0.2, 0)`.
  On `i % 4 == 0 and not low`, a third `CliffTier` + `TierSnow`.
- [ ] **Step 2: Gate shoulders.** For each side, `from = V(side * 11.5, 0, -80)`,
  `to = ring(rad(15), 75).Position * V(side, 1, 1)`, `along = CFrame.lookAt((from+to)/2 + V(0,6,0), to + V(0,6,0))`
  — both points share `y = 6`, so the default up vector is not parallel. `GateShoulder`
  `V(3.6, 12, run)` and `ShoulderSnow` `V(4.2, 1.1, run)` at `along * CF(0, 6.3, 0)`.
- [ ] **Step 3: Static checks.** Expected: pass.
- [ ] **Step 4: Measure.** Harness assertion: the ring opening spans exactly the same
  bearings as Gusty Gardens and Splashwater Bay, and no ring part is inside radius 58.

## Task 3: The timber entrance

**Files:** Modify `src/server/Map/FrostbitePeaks.luau`, `src/server/Map/MapBuilder.luau`.

- [ ] **Step 1: MapBuilder.** Replace
  `if def.element ~= "Wind" and def.element ~= "Water" then` (around line 591) with a
  named set so the three regions that build their own entrance are listed in one place:

```lua
-- Wind, Water and Frost build their own entrances in their scenery modules.
local OWN_ENTRANCE = { Wind = true, Water = true, Frost = true }
if not OWN_ENTRANCE[def.element] then
```

- [ ] **Step 2: `TimberGate` in Landmarks, post cores in Boundary.**
  `ArchPostCore` `V(2.9, 17, 2.9)` solid at `(+-13, 8.65, -80)`; `ArchBeam` `V(32, 2.4, 2.4)`
  at `(0, 18.6, -80)`; `ArchTie` at `(0, 15.9, -80)` leaving 14.95 studs of headroom over
  a 12-stud gate; snow caps; braces; two `ArchLantern`; a decorative `ArchPlaque` at
  `(0, 14.6, -79.7)` with no text and no prompt.
- [ ] **Step 3: Trail fences and approach dressing**, all `flat()`, all clear of the board
  box and of the sightline wedge.
- [ ] **Step 4: Static checks + Rojo build.** `rojo build -o build/FrostbitePeaks.rbxl`.
- [ ] **Step 5: Measure.** Harness assertions: zero parts intersect the board box; zero
  solid parts obstruct the 27 board sightlines; clear headroom under the arch >= 13.

## Task 4: The left ledge, the frozen cascade and the rope bridge

**Files:** Modify `src/server/Map/FrostbitePeaks.luau`.

- [ ] **Step 1: `LedgeStair`,** 11 steps climbing *tangentially* at radius 64 from bearing
  44 to 59, `top_k = 0.30 + k * 0.5455` (riser 0.5455), tread 1.36, width 8, with kerbs at
  radial `+-4.4`. Tangential climbing keeps the whole flight outside radius 59.1 — unlike
  Cinder, no part of the stair enters the field skin.
- [ ] **Step 2: `LedgeA` (bearings 62..92) and `LedgeB` (114..144),** 6 segments each at
  radius 64, 6 degrees apart. `LedgeBench` `V(7.0, 6.0 - (j%2)*0.04, 9.0)`;
  `LedgeDeck` `V(6.72, 0.9, 8.2)` with top `6.40 + (j%2)*0.03`; `LedgeKerb` on the inner
  edge; a decorative `TrailFence` above it.
- [ ] **Step 3: `FrozenCascade`,** bearings 95..111. Two solid `GorgeWall` end caps, six
  `CascadeRibbon` ice columns on the wall face at radius 71.8, a `CascadeLip`, a flush
  `GorgeIce` stream and a `CascadePool`. All ice is `CanCollide = false`.
- [ ] **Step 4: `RopeBridge`,** 9 planks at radius 64 from bearing 95.6 to 110.4,
  `y_k = 6.37 - 1.15 * sin(pi * t)` so the ends sit 0.03 below the ledge decks they
  overlap. Solid `BridgeDeck` and `BridgeKerb` in Walkways; rope rails, hangers, portals
  and two lanterns as decoration.
- [ ] **Step 5: Static checks + measure.** Assertions: every walkable surface from the
  stair foot to the far end of Ledge B is continuous — largest horizontal gap 0.00,
  largest step <= 0.70; no walkway part inside radius 58.

## Task 5: The hut terrace and the alpine hut

**Files:** Modify `src/server/Map/FrostbitePeaks.luau`.

- [ ] **Step 1: `TerraceStair`,** 10 steps tangentially at radius 67 from bearing 270 down
  to 256, `top_k = 0.30 + k * 0.484`, tread 1.55, width 8, kerbs at radial `+-4.4`.
- [ ] **Step 2: `HutTerrace`,** 6 segments at radius 67, bearings 224..254, depth 16
  (radial 59..75). `TerraceBench`, `TerraceDeck` top 5.20, `TerraceKerb`, `TrailFence`.
- [ ] **Step 3: `AlpineHut`** at `bearing(238, 68.5)`. Solid `HutCore` `V(17.4, 9.4, 11.4)`
  in Boundary; non-colliding cladding in Landmarks — four walls, gabled teal roof at
  `+-0.519 rad`, ridge, snow caps, stone chimney, closed door, two warm windows with
  `PointLight`, porch deck, posts and porch roof. Envelope reported in the layout doc.
- [ ] **Step 4: Static checks + measure.** Assertions: terrace and porch continuous with
  the stair; innermost solid >= 59.3 true radius; hut envelope within the brief's
  16-20 x 14-18 x 12-16.

## Task 6: The rear ridge

**Files:** Modify `src/server/Map/FrostbitePeaks.luau`.

- [ ] **Step 1: Five `RearPeakNN` Models** at bearings 150/164/180/196/210, radii
  79/81/82/81/79, summit `y` 30/37/44/35/28. Each is a solid `PeakBase` in Boundary plus
  two non-colliding tapering tiers, a slate face and thick snow caps in Landmarks.
- [ ] **Step 2: Four `RidgeSaddle`** solid masses at bearings 157/172/188/203, radius 80,
  top `y = 27`, so the ridge reads continuous over the cornice line rather than as five
  separate lumps.
- [ ] **Step 3: Static checks + measure.** Assertion: no peak geometry reaches past
  radius 93 (the landscape's own Frost ridges start at 103 and its snowy trees at 92).

## Task 7: Prop sites for the Codex kit

**Files:** Modify `src/server/Map/FrostbitePeaks.luau`.

Exact dimensions from `assets/frostbite-peaks/props-v1/manifest.json`:

| Asset | X | Y | Z |
|---|---|---|---|
| `FP_Snow_Rock_Wide` | 4.6076 | 2.6258 | 3.3431 |
| `FP_Snow_Rock_Tall` | 3.5510 | 3.6008 | 2.7160 |
| `FP_Snow_Fir_Tree` | 4.8950 | 9.2653 | 5.1138 |
| `FP_Snow_Fir_Sapling` | 2.8391 | 5.0657 | 2.9660 |
| `FP_Snow_Drift` | 4.8851 | 1.3140 | 2.7908 |
| `FP_Icicle_Cluster` | 3.2000 | 2.2300 | 0.4711 |
| `FP_Supply_Crate` | 2.6886 | 2.4087 | 2.6500 |
| `FP_Rope_Coil` | 2.5762 | 0.2319 | 2.1408 |

- [ ] **Step 1: `PropSites` Model** under `Landmarks`, carrying `AssetKit`,
  `AssetOrigin = "ground-centre"` and `AssetCount` attributes.
- [ ] **Step 2: One Model per site**, named `TreeSiteNN` / `RockSiteNN` / `DriftSiteNN` /
  `IcicleSiteNN` / `CrateSiteNN` / `RopeSiteNN`, each with `AssetName`, `AssetSize`
  (the exact manifest Vector3), `GroundCF` (region-local, ground-centre) and
  `CollisionRole`. Placeholder geometry inside each matches that bounding box.
- [ ] **Step 3: Icicle sites** hang under ledge lips and the hut eave: their `GroundCF`
  is the **top**-of-bounds mounting point, flagged by `CollisionRole = "hanging"`.
- [ ] **Step 4: Static checks + measure.** Assertions: every site is outside radius 58;
  every placeholder's bounding box equals its `AssetSize` to within 0.01; every site's
  `GroundCF` sits on a real surface (no float, no sink) to within 0.05.

## Task 8: Integration

**Files:** Modify `src/server/Map/RegionScenery.luau`, `src/server/Systems/TestHarness.luau`,
`docs/CONTRACTS.md`.

- [ ] **Step 1: Delegate Frost.** Add the fourth branch next to Wind/Water/Heat.
- [ ] **Step 2: Delete the dead Frost code.** The `Frost` palette entry, the
  `GlacierCrystal`/`SnowDrift`/`GlacierPillar`/`GlacierArch` branch, and the two
  conditionals that Frost was the only false case of:
  `local height = style.height + (if def.element == "Storm" or ... )` becomes
  `local height = style.height`, and the `WallRib`/`PerimeterLamp` guard goes away.
  Storm and Cosmic geometry must be byte-identical afterwards.
- [ ] **Step 3: `SCENERY_VERSION.Frost = 3`** in TestHarness.
- [ ] **Step 4: Update CONTRACTS.** The Frost delegation paragraph, `Walkways` no longer
  being Cinder-only, the `SceneryVersion` list, and the asset-site attribute schema.
- [ ] **Step 5: Static checks + Rojo build + measure Storm and Cosmic** through the
  harness before and after, to prove the generic builder is unchanged for them.

## Task 9: Headless validation

**Files:** Scratchpad only. Nothing added to the repository.

- [ ] **Step 1: Reuse `C:/Users/rahul/AppData/Local/Temp/lunebin/measure.luau`** — it
  executes a scenery module under Lune with a Roblox datatype shim and dumps every part
  in the module's own frame. Note its patch: Lune 0.10.5's `CFrame.lookAt` returns the
  negated Z of Roblox's, so the harness mirrors the target.
- [ ] **Step 2: Write `analyse.py`** in the scratchpad, asserting, for Frostbite and for
  Gusty / Splashwater / Cinder as controls:
  1. innermost solid part (true distance and the harness's AABB distance) > 44;
  2. nothing but flush detail inside radius 58;
  3. the boundary ring opening matches the shipped regions;
  4. the walkable route is continuous — every surface reachable, largest gap, largest step;
  5. stair risers <= 0.70;
  6. exact SAT test for overlapping coplanar top faces (z-fighting), with the shipped
     regions as the control;
  7. no part intersects the board box; no solid part blocks the 27 board sightlines;
  8. every transform finite;
  9. prop-site bounding boxes match the manifest.
- [ ] **Step 3: Run it. Fix every real failure in the module, then re-run.**
- [ ] **Step 4: Record the numbers** — they are the layout document's measured values.

## Task 10: Deliverables

**Files:** Create `docs/art/regions/2026-09-20-concepts/FROSTBITE-PEAKS-LAYOUT.md` and
`frostbite-peaks-layout-plan.svg`; modify `RELAY.md`.

- [ ] **Step 1: `FROSTBITE-PEAKS-LAYOUT.md`** with coordinate frame, radial budget,
  measured floor/terrace heights, every landmark's local CFrame / footprint / bounds,
  bridge endpoints and deck span, stair dimensions, hut envelopes, cliff segment
  dimensions, the prop-site table, and which collision survives asset replacement.
  Values read from the harness output, not from the source.
- [ ] **Step 2: `frostbite-peaks-layout-plan.svg`,** a measured top-down plan generated
  from the same harness output.
- [ ] **Step 3: RELAY.md checkpoint** at the top: feature, files, validation, limitations,
  Studio state, publishing state, next task. Preserve Codex's concurrent asset notes.
- [ ] **Step 4: Report honestly** which checks ran headless and which need Studio.

---

## Self-review

**Spec coverage.** Handoff requirement -> task: continuous perimeter + gate shoulders (2);
radius 44 clear, field to 56, props outside 58 (1, 4, 5, 7, 9); matte blue-grey snow, no
slippery physics (1, Global Constraints); Ice Wave readability (1, 9); rear ridge (6);
rope bridge over frozen cascade with stairs both ends (4); hut on a terrace with approach
stair, porch, warm windows, teal roof (5); safe peripheral route with <= 0.7 risers (4, 5, 9);
timber entrance arch, gate untouched (3); sparse firs and expedition props, lanterns only
at hut/entrance/bridge (3, 7); Boundary/Walkways/Landmarks split (1); named sites for all
eight props plus hut, bridge, cascade, peak, gate, cliff segments (3-7); SceneryVersion 3
and TestHarness (8); static checks and Rojo build (3, 8); measured layout doc, plan, relay
(10).

**Placeholder scan.** No TBDs. Every geometric number is stated. The one deliberately
deferred item is the SVG's exact contents, which are generated from Task 9's output.

**Type consistency.** `build(parent, frame, radius, makePart)` matches `RegionScenery`'s
call site and `CinderCanyon`'s signature. `site(host, name, asset, size, cf, role)` is used
identically in Tasks 3, 5 and 7. `bearing(degrees, r)` and `ring(radians, r)` keep Cinder's
split so a reader moving between the two modules is not surprised.

## Known risks

1. **No Roblox Studio bridge in this session.** Everything below "run it in Studio" is
   unverifiable here and must be reported as unverified, not as passing.
2. **Part count.** Cinder is 589, Gusty 663. This layout has more distinct structures;
   if the measured count lands above ~850 the fence and prop-site density come down first.
3. **Cyan-on-snow telegraph contrast** is the one art decision that could still be wrong
   in motion. The field skin is deliberately held at a blue-grey `rgb(191, 207, 220)`
   rather than white for this reason, but only Studio can settle it.

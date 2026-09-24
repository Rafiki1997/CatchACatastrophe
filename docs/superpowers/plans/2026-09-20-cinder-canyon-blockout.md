# Cinder Canyon Sculpted-Ravine Blockout Implementation Plan

> **For agentic workers:** Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Cinder Canyon's generic Heat scenery with a playable blockout of the
V2 "Sculpted Ravine" concept — simple geometry, flat identifying colours, named
placeholders — that Codex can swap for custom Blender assets without losing the floor
or the containment barrier.

**Architecture:** A new `src/server/Map/CinderCanyon.luau` following the
`GustyGardens` / `SplashwaterBay` precedent: one `build(parent, frame, radius, makePart)`
entry point that `RegionScenery` delegates to for `element == "Heat"`. Inside it,
three sibling Models split the output by replaceability — `Boundary` (containment
collision, never remove), `Walkways` (functional walkable surfaces), `Landmarks`
(replaceable visual placeholders).

**Tech Stack:** Luau, Rojo (port 34872), Roblox Studio. Static checks
`python tools/luau_lint.py src` and `python tools/quote_scan.py src`.

**Spec:** `C:\Users\rahul\OneDrive\Documents\CaC_Mockups\CinderCanyonDesign.md`
**Reference image:** `cinder-canyon-v2-sculpted-ravine.png`
**Concept notes:** `docs/art/regions/2026-09-20-concepts/CINDER-ALTERNATIVES.md`
(the "Sculpted Ravine: exact prompt" section is the authoritative art description)

---

## Global Constraints

Copied verbatim from the spec and from the code the spec must not break.

- **Repository:** `C:\Users\rahul\orca\Catch-a-Catastrophe`, branch `main`. Preserve the
  ~21 modified / 9 untracked files already in the working tree.
- **Do not publish. Do not commit.** (`AGENTS.md` items 6 and 8.)
- **Do not hand-patch Studio script `.Source`.** Rojo is the only sync path. Stop Play
  before syncing.
- **Confine changes to Cinder Canyon** and the minimum integration needed.
- **Preserve** the Cinder Canyon board, its live text, entrance access rules, region
  unlock logic and capture systems. Do not move `GateSign` or `Gate`.
- **No new gameplay.** Lava is a coloured surface: no damage, no hazards, no rewards,
  no traversal mechanics.
- **Clear catching field: radius 44.** `EncounterService.clampToField` clamps roaming
  to `SpawnRadius` = 44 and spawn homes to `rng:NextNumber(10, 44)`. Nothing solid
  inside radius 44.
- **Telegraph reach: radius ~60.** Heat hazard is `shape = "circles", radius = 4,
  count = 3, spawnRadius = 12` around a creature that can stand at radius 44.
  Ground out to radius 58 stays flat and matte; no Neon inside radius 58.
- **Ground datum:** region ground disc top is `y = 0.30` local. Region centre `y = 0`.
- **Z-fighting:** no coplanar faces. Stacked surfaces keep >= 0.15 stud clearance;
  a built floor's bottom is buried below the disc it sits on.
- **Cylinders run along local X.** A vertical cylinder is `Vector3.new(height, d, d)`
  with `CFrame.Angles(0, 0, math.rad(90))`.
- **A Write hook rejects any file containing a dot followed by `format(`.** Use the
  `("%d"):format(x)` colon form or plain concatenation.
- **The Bash tool strips one backslash level even inside quoted heredocs.** Write Luau
  with the Write/Edit tools, not Bash heredocs.
- **Decoration is `CanQuery = false`** so it cannot absorb the 27 sign sightline rays
  that `testRegionSignVisibility` casts per board.

---

## Coordinate frame (the contract Codex builds against)

`RegionScenery` hands the module `frame = CFrame.lookAt(centre, Vector3.new(0, centre.Y, 0))`.
Every number below is **local to that frame** and is applied as `frame * CFrame.new(...)`.

| Axis | Direction |
|---|---|
| `-Z` | Entrance, toward the hub. The gate is at `z = -80`. |
| `+Z` | Rear of the region. |
| `+X` | The player's **left** on entering. |
| `-X` | The player's **right** on entering. |
| `+Y` | Up. Ground (walkable) top surface is `y = 0.30`. |

Cinder Canyon's world centre is `polar(280, 210)` = `(-242.49, 0, -140.00)`.

**Image-to-local mapping.** The mockup is drawn from outside the entrance looking in,
so the image's left is `+X` and the image's right is `-X`:

| In the image | Local placement |
|---|---|
| Sandstone arch, rear-left | `+X, +Z` — ring bearing 152 deg |
| Lavafall terraces, rear-right | `-X, +Z` — ring bearing 228 deg |
| Walkway / bridge / alcove, left | `+X` — ring bearings 44–140 deg |
| Entrance pillars, front centre | `z = -80`, `x = +/-13.2` |

The board in the image sits right of the entrance; the **real** `GateSign` is at
`(24, h, -90)` (left). The board is out of scope and does not move — this is a known,
accepted divergence from the render.

**Ring bearing `a`** is the angle used by the perimeter loop:
`position = (sin a * R, y, -cos a * R)`, `rotation = CFrame.Angles(0, -a, 0)`.
`a = 0` is the entrance, 90 is `+X` (left), 180 is the rear, 270 is `-X` (right).
In a segment's own frame, **local `+Z` points inward**, toward the region centre.

## Radial budget

| Band | Content |
|---|---|
| `r < 44` | Hard clear. Flush inert decals only (<= 0.5 proud, `CanCollide`/`CanQuery` false). |
| `44 <= r < 56` | Field skin. Flush detail only. |
| `56 <= r < 58` | Field-skin lip. Nothing. |
| `58 <= r < 73` | All scenery: walkway, bridge, alcove, terraces, channels, clusters. |
| `r = 75` | Perimeter wall ring, inner face 73.4. |

---

## File Structure

| File | Responsibility |
|---|---|
| **Create** `src/server/Map/CinderCanyon.luau` | The whole blockout. Owns its own perimeter, entrance pillars, field skin and landmarks, exactly as `SplashwaterBay.luau` does. |
| **Modify** `src/server/Map/RegionScenery.luau` | Delegate `element == "Heat"` to it, and drop the now-dead Heat branch of the shared builder. |
| **Modify** `src/server/Systems/TestHarness.luau` | `expectedScenery` becomes a table lookup so Heat can be version 4; add a field-clearance live check. |
| **Modify** `docs/CONTRACTS.md` | Document the module, the three-Model split and the new `SceneryVersion`. |
| **Create** `docs/art/regions/2026-09-20-concepts/CINDER-CANYON-LAYOUT.md` | The asset handoff document: every placeholder's name, type, size, position, rotation, pivot, facing, collision and reuse flag. |
| **Copy in** `docs/art/regions/2026-09-20-concepts/cinder-canyon-v2-sculpted-ravine.png` | The spec names this path but only v1 and v3 are in the repo. |
| **Modify** `RELAY.md` | Checkpoint per `AGENTS.md` item 9. |

---

### Task 1: Copy the missing reference image into the repo

The spec cites `docs/art/regions/2026-09-20-concepts/cinder-canyon-v2-sculpted-ravine.png`
and it is not there. Codex cannot build against a file that only exists in OneDrive.

- [ ] **Step 1:** Copy it from `C:\Users\rahul\OneDrive\Documents\CaC_Mockups\`.
- [ ] **Step 2:** Confirm the three concept PNGs now sit together in the folder.

---

### Task 2: `CinderCanyon.luau` — module skeleton, palette and helpers

**Files:** Create `src/server/Map/CinderCanyon.luau`

**Interfaces:**
- Consumes: `makePart(props) -> Part` where props is MapBuilder's `P`
  (`name`, `size`, `cf`, `color?`, `material?`, `transparency?`, `collide?`, `shape?`,
  `query?`, `parent`), plus `frame: CFrame` and `radius: number` (75).
- Produces: `Canyon.build(parent: Model, frame: CFrame, radius: number, makePart: (any) -> Part)`.
  Sets `parent:SetAttribute("SceneryVersion", 4)` as its last statement.

**Three host Models**, created in this order as children of `parent`:

| Model | Contents | Rule |
|---|---|---|
| `Boundary` | Perimeter cores, copings, columnar faces, gate shoulders, alcove mass | Containment. Never removed by an art pass. |
| `Walkways` | Field skin, walkway decks and supports, steps, bridge deck and ribs, alcove floor, terrace/channel curbs | Functional walkable / separating surfaces. |
| `Landmarks` | Arch, lavafalls, lava surfaces, basalt clusters, crystals, grasses, lanterns, railings, fins | Replaceable visual placeholders. |

- [ ] **Step 1: Header and palette.**

```lua
--!strict
-- Cinder Canyon, "Sculpted Ravine" blockout. Reference:
-- docs/art/regions/2026-09-20-concepts/cinder-canyon-v2-sculpted-ravine.png
-- Simple geometry and flat colours standing in for custom Blender assets; the
-- dimensioned contract is docs/art/regions/2026-09-20-concepts/CINDER-CANYON-LAYOUT.md.
-- Local -Z is the hub entrance, +X the player's left. Everything solid stays
-- outside radius 58; the catching field inside radius 44 is flat and matte.
local Canyon = {}
local V = Vector3.new
local rgb = Color3.fromRGB
local SANDSTONE = Enum.Material.Sandstone
local BASALT_MAT = Enum.Material.Basalt
local SLATE = Enum.Material.Slate
local NEON = Enum.Material.Neon
local METAL = Enum.Material.Metal

local FIELD = rgb(198, 126, 84)
local SEDIMENT = rgb(186, 115, 76)
local SAND_LIGHT = rgb(206, 124, 86)
local SAND_MID = rgb(178, 98, 68)
local SAND_DARK = rgb(146, 76, 54)
local SAND_CAP = rgb(220, 146, 104)
local BASALT = rgb(58, 54, 60)
local BASALT_LIGHT = rgb(80, 74, 82)
local BASALT_DARK = rgb(40, 37, 43)
local LAVA = rgb(255, 122, 36)
local LAVA_HOT = rgb(255, 178, 76)
local CRUST = rgb(126, 52, 30)
local EMBER = rgb(255, 154, 60)
local DRYGRASS = rgb(196, 178, 122)
local BRONZE = rgb(168, 116, 58)
local LANTERN = rgb(255, 214, 128)
local WALKSTONE = rgb(168, 120, 92)
```

- [ ] **Step 2: Local helpers,** mirroring `SplashwaterBay.luau` so the two files read
  alike. `part` defaults `query` to `solid` so decoration never blocks a sightline ray.

```lua
	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, solid: boolean?, host: Instance?): Part
		return makePart({ name = name, size = size, cf = frame * cf, color = color,
			material = material or BASALT_MAT, collide = solid == true,
			query = solid == true, parent = host or decor })
	end
	local function disc(name: string, diameter: number, height: number, cf: CFrame, color: Color3, material: Enum.Material?, solid: boolean?, host: Instance?): Part
		local p = part(name, V(height, diameter, diameter), cf * CFrame.Angles(0, 0, math.pi / 2), color, material, solid, host)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	local function ring(a: number, r: number): CFrame
		return CFrame.new(math.sin(a) * r, 0, -math.cos(a) * r) * CFrame.Angles(0, -a, 0)
	end
	local function glow(p: Part, brightness: number, range: number)
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		local light = Instance.new("PointLight")
		light.Color = p.Color
		light.Brightness = brightness
		light.Range = range
		light.Shadows = false
		light.Parent = p
	end
```

- [ ] **Step 3:** `Canyon.build` creates `boundary`, `walkways`, `decor`, then returns
  after `parent:SetAttribute("SceneryVersion", 4)`.
- [ ] **Step 4:** `python tools/luau_lint.py src` and `python tools/quote_scan.py src` pass.

---

### Task 3: Field skin, sediment sweeps and embedded stones

The mockup's floor is warm sandy terracotta; the region's existing disc is dark
`rgb(120, 70, 50)` basalt. A skin disc re-reads the field without touching
`Regions.luau` or the functional ground underneath it.

**Placement** — all in `Walkways` except the inert decals, which go in `Landmarks`.

| Name | Type | Size (studs) | Local position | Collision |
|---|---|---|---|---|
| `CanyonFloor` | cylinder disc | d 112, h 0.5 | `(0, 0.35, 0)`, top `y 0.60` | walkable |
| `SedimentSweep` x24 | thin arc slab | `(chord, 0.08, 1.4)` | rings r 20 / 32 / 44, 8 each, top `y 0.65` | none |
| `FieldStone` x7 | flat slab | `(3.2..5.0, 0.4, 2.4..3.6)` | r 26..42, top `y 0.78` | none |

- [ ] **Step 1:** Build `CanyonFloor` with `disc("CanyonFloor", 112, 0.5, CFrame.new(0, 0.35, 0), FIELD, SANDSTONE, true, walkways)`.
  Its bottom is `y 0.10`, buried in the region disc whose top is `0.30` — no coplanar faces.
- [ ] **Step 2:** Sediment sweeps: for `r` in `{20, 32, 44}`, 8 slabs at
  `a = (j + r * 0.07) * math.pi / 4`, chord `2 * r * math.sin(math.pi / 9)`, colour
  `SEDIMENT`, material `SANDSTONE`, `solid = false`, `CastShadow = false`.
- [ ] **Step 3:** Seven `FieldStone` slabs at fixed `(r, degrees)` pairs
  `{26, 41}, {31, 128}, {38, 196}, {29, 243}, {42, 310}, {35, 74}, {24, 165}`,
  each rotated `CFrame.Angles(0, r * 0.17, 0)`, colour `SAND_DARK`, material `Rock`,
  `solid = false`.
- [ ] **Step 4:** Static checks pass.

**Verification:** the tallest thing inside radius 44 is 0.48 studs above the field skin.

---

### Task 4: Perimeter wall — three rock styles and the entrance gap

48 tangential segments, `i = 2..46` (the `i = 47, 0, 1` gap is the 29.3-stud entrance,
`a` within +/-11.25 deg of the hub direction). `length = 2 * 75 * math.tan(math.pi / 48) + 0.5 = 10.33`.

| `i` | `a` (deg) | Style | Height |
|---|---|---|---|
| 2..5 | 15–37.5 | `basaltLow` (front-left) | `9.0 + (i % 3) * 0.8` |
| 6..18 | 45–135 | `sandstone` (left) | `18 + (i % 4) * 1.5` |
| 19..23 | 142.5–172.5 | `sandstone`, arch window | `16` flat |
| 24..38 | 180–285 | `basaltTall` (rear-right, right) | `21 + (i % 3) * 1.7` |
| 39..46 | 292.5–345 | `basaltLow` (front-right) | `9.0 + (i % 3) * 0.8` |

Per-style parts, all parented to `boundary` unless noted:

- `basaltLow`: `Perimeter` `(10.33, h, 3.4)` at `cf * CFrame.new(0, h/2, 0)`;
  two `BasaltFace` `(3.2, h + (j % 2) * 1.2, 1.6)` at `cf * CFrame.new((j - 1.5) * 3.4, h/2, 1.5)`;
  `Coping` `(10.53, 0.9, 3.9)` at `cf * CFrame.new(0, h + 0.3, 0)`.
- `sandstone`: three `Strata` bands, band `j = 1..3` height `h/3`, depth
  `{3.0, 3.7, 3.2}[j]`, colour `{SAND_DARK, SAND_MID, SAND_LIGHT}[j]`, at
  `cf * CFrame.new(0, (j - 0.5) * h/3, 0)`; `Coping` `(10.53, 1.0, 3.6)` `SAND_CAP` at
  `cf * CFrame.new(0, h + 0.35, 0)`; on `i % 3 == 0` an `ErodedFin`
  `(2.2, h * 0.5, 4.4)` at `cf * CFrame.new(3, h * 0.72, 1.2) * CFrame.Angles(0, 0, 0.05)`
  in `decor`.
- `basaltTall`: `Perimeter` `(10.33, h, 3.6)`; three `BasaltColumn`
  `(3.1, h + (j % 3) * 2.2, 1.9)` at `cf * CFrame.new((j - 2) * 3.2, h/2, 1.4) * CFrame.Angles(0.05 * (j - 2), 0, 0)`
  — the tilt is the "slanted dark basalt cliff"; `Coping` `(10.53, 1.0, 4.0)`.
  On `i % 4 == 0` an `EmberSeam` `(0.3, h * 0.45, 0.14)` `LAVA` `NEON` at
  `cf * CFrame.new(0, h * 0.4, 1.9)` in `decor`, `solid = false`.

- [ ] **Step 1:** Write the loop with a `wallStyle(i)` helper returning the style name.
- [ ] **Step 2:** Gate shoulders, both sides, in `boundary`, matching the existing pattern
  so the entrance stays sealed at its edges:
  `from = V(side * 11.5, 5, -80)`, `to = V(side * math.sin(math.pi / 12) * 75, 5, -math.cos(math.pi / 12) * 75)`,
  `GateShoulder` `(3.6, 10, (to - from).Magnitude + 2)` at `CFrame.lookAt((from + to) / 2, to)`,
  `BASALT`, plus `ShoulderCap` `(4.1, 0.8, same length)` 5.4 above it in `BASALT_LIGHT`.
- [ ] **Step 3:** Static checks pass.

**Verification:** every `i` in `2..46` emits at least one solid `Perimeter` part, and the
only ring gap is the entrance.

---

### Task 5: Entrance pillars and lanterns

Replaces the generic `EntryPier`. Two carved sandstone uprights with bronze lanterns,
at `x = +/-13.2, z = -80` — clear of the 9-wide approach road (`|x| <= 4.5`) and of the
sign sightline corridor, which never reaches past `z = -88`.

Per side (`side` in `{-1, 1}`), in `decor` except the three tapers, which are solid and
go in `boundary` so they keep flanking the gate if the art is replaced:

| Name | Size | Local position | Notes |
|---|---|---|---|
| `EntryPillar` (lower) | `(6.2, 6.4, 5.4)` | `(side * 13.2, 3.2, -80)` | `SAND_MID`, solid |
| `EntryPillar` (mid) | `(5.4, 6.0, 4.8)` | `(side * 13.2, 9.4, -80)`, yaw `side * 0.07` | `SAND_LIGHT`, solid |
| `EntryPillar` (upper) | `(4.6, 4.6, 4.2)` | `(side * 13.2, 14.6, -80)`, yaw `-side * 0.05` | `SAND_MID`, solid |
| `PillarCap` | `(5.2, 0.9, 4.8)` | `(side * 13.2, 17.3, -80)` | `SAND_CAP` |
| `PillarGroove` x2 | `(0.32, 6.0, 0.24)` | `(side * 10.6, 9.4, -80 + k * 1.4)`, `k` in `{-1, 1}` | `SAND_DARK` |
| `LanternArm` | `(0.4, 0.4, 1.5)` | `(side * 11.0, 10.6, -80)` | `BRONZE`, `METAL` |
| `LanternCage` | `(1.5, 2.1, 1.5)` | `(side * 9.9, 10.6, -80)` | `BRONZE`, `METAL` |
| `LanternGlass` | `(1.0, 1.4, 1.0)` | `(side * 9.9, 10.6, -80)` | `LANTERN`, `NEON`, `glow(p, 1.1, 15)` |
| `LanternCap` | `(1.8, 0.4, 1.8)` | `(side * 9.9, 11.9, -80)` | `BRONZE`, `METAL` |

- [ ] **Step 1:** Write the two-sided loop.
- [ ] **Step 2:** Static checks pass.

**Verification:** `LanternGlass` is Neon at `z = -80`, outside radius 58 and outside the
field — the no-Neon-inside-58 rule is about the catching field, not the gate.

---

### Task 6: The sandstone arch (rear-left landmark)

Bearing `a = math.rad(152)`, ring radius 73, so the arch mass straddles the wall
(`73 +/- 4.4` against an inner face at 73.4) and reads as one rock body.
`archCF = ring(math.rad(152), 73)`; arch-local `+X` is tangential, `+Z` inward.

The wall at `i = 19..23` is held flat at `h = 16`, so the arch **opening sits entirely
above the barrier**: you see sky and distant mesas through it and rock below it, exactly
as the concept prompt specifies ("sculpted rock walls close all gaps below the elevated arch").

| Name | Size | Arch-local position / rotation |
|---|---|---|
| `ArchLeg` (lower) x2 | `(11.5, 16.0, 9.5)` | `(side * 20.5, 8.0, 0)` |
| `ArchLeg` (upper) x2 | `(10.0, 8.0, 8.6)` | `(side * 20.0, 20.0, 0)`, roll `-side * 0.05` |
| `ArchVoussoir` x7 | `(7.8, 5.4, 8.8)` | ellipse centre `(0, 22)`, `rx 19.5`, `ry 10.5`, `theta = 15 + (k-1) * 25` deg, position `(rx * cos theta, 22 + ry * sin theta)`, roll `theta - 90` deg |
| `ArchButtress` x2 | `(7.0, 9.0, 7.0)` | `(side * 26.0, 4.5, 1.5)`, yaw `side * 0.3` |

Voussoir positions, computed: `(18.83, 24.72)`, `(14.94, 28.75)`, `(8.24, 31.52)`,
`(0.00, 32.50)`, `(-8.24, 31.52)`, `(-14.94, 28.75)`, `(-18.83, 24.72)`.
Apex top `y 35.2`. Opening: 29.5 wide (leg inner faces `+/-14.75`), `y 16` to `y ~27`.

Legs and buttresses are solid and go in `boundary`; voussoirs are `decor` (solid = false,
they are above head height and Codex replaces them with one mesh).

- [ ] **Step 1:** Write the arch block.
- [ ] **Step 2:** Static checks pass.

**Verification:** arch apex 35.2 is the tallest thing in the region and sits rear-left.

---

### Task 7: Lavafall cliff and stepped terraces (rear-right)

Bearing `a = math.rad(228)`, ring radius 73. `fallCF = ring(math.rad(228), 73)`.
Three ribbons from one fissure, landing on ledges at three different heights, draining
into the perimeter lava terrace of Task 8. All in `decor` except the ledge blocks, which
are solid so nobody falls through them.

| Name | Size | Fall-local position |
|---|---|---|
| `FissureMouth` | `(14, 4.0, 2.2)` | `(0, 25, 1.6)`, `BASALT_DARK` |
| `FissureGlow` | `(12.5, 2.2, 0.6)` | `(0, 25, 2.6)`, `LAVA_HOT` `NEON`, `glow(p, 1.4, 26)` |
| `LavaRibbon` x12 | `(2.2, seg, 0.7)` | three runs at `x = -11, 1, 12`, from `y 24` down to `y 14.5 / 6.5 / 10.5` in 3 / 5 / 4 segments, each at `z 2.3`, roll `0.04 * k` |
| `RibbonCrust` x12 | `(3.0, seg, 0.5)` | same, at `z 1.8`, `CRUST` |
| `LavaLedge` x4 | see below | solid, `BASALT` |
| `LedgePool` x4 | ledge size shrunk 3 studs, `h 0.4` | `LAVA` `NEON`, top 0.25 above its ledge |
| `LedgeLip` x4 | `(ledge.X + 1, 1.2, 1.0)` | inward edge of each ledge, `CRUST` |

Ledges (`size` / `position`): `(16, 3, 11)` at `(-11, 13.0, 7)`; `(15, 3, 10)` at
`(12, 9.0, 8)`; `(18, 3, 12)` at `(0, 5.0, 12)`; `(22, 3, 13)` at `(-4, 1.8, 18)`.
The lowest ledge's inward edge is at fall-local `z 24.5`, i.e. ring radius ~48.5 —
**too close to the field**, so it is pulled to `(-4, 1.8, 14)` giving radius ~59. Use
`z 14`.

- [ ] **Step 1:** Write the fissure, the three ribbon runs and the four ledges.
- [ ] **Step 2:** Assert in your head that every ledge's innermost face is at ring radius
  >= 58: radius = `73 - (z + depth/2)`. For `(0, 5, 12)` with depth 12 that is
  `73 - 18 = 55` — **too close**; use `z 10` (`73 - 16 = 57`)… widen the check and pull
  any ledge whose inner face falls inside 58.
- [ ] **Step 3:** Static checks pass.

**Verification:** no ledge, pool or ribbon has a face inside ring radius 58.

---

### Task 8: Perimeter lava terrace and recessed lava channels

**Terrace** along bearings 202–268 deg (under the lavafalls), 10 arc steps, `da = 7.33 deg`.
Recessed: the lava surface sits *below* the surrounding ground, behind a curb.

| Name | Size | Ring radius | Local `y` centre | Top | Host |
|---|---|---|---|---|---|
| `TerraceBed` | `(8.6, 1.0, 14)` | 64 | `-0.40` | `0.10` | `walkways`, solid |
| `TerraceLava` | `(8.2, 0.30, 13)` | 64 | `0.10` | `0.25` | `decor`, no collision |
| `TerraceCurb` | `(7.4, 1.6, 2.4)` | 57.2 | `0.60` | `1.40` | `walkways`, solid |
| `CurbStone` (every 3rd) | `(3.4, 2.2, 2.8)` | 56.6 | `1.10` | — | `decor` |

Lava at `y 0.25` is 0.05 **below** the ground top (0.30) and 1.15 below the curb — it
reads as recessed and cannot be confused with the field.

**Channels** — three short radial runs where nothing else sits: bearings 30, 172 and 290 deg,
each running ring radius 58 to 68 (channel-local `z` along the radius, length 11).

| Name | Size | Channel-local position | Top |
|---|---|---|---|
| `ChannelBed` | `(4.4, 0.9, 11)` | `(0, -0.35, 0)` | `0.10` |
| `ChannelLava` | `(3.0, 0.24, 10.2)` | `(0, 0.00, 0)` | `0.12` |
| `ChannelCurb` x2 | `(1.6, 1.3, 11.4)` | `(+/-2.9, 0.55, 0)` | `1.20` |
| `ChannelStone` x2 | `(2.6, 1.8, 2.2)` | `(+/-3.4, 0.9, +/-3.5)` | — |

- [ ] **Step 1:** Write the terrace arc loop.
- [ ] **Step 2:** Write the three channels from a `{bearing}` table.
- [ ] **Step 3:** Static checks pass.

**Verification:** the innermost lava face is the terrace curb's inner face at ring
radius 55.9 — and that is dark basalt, not lava. Lava itself starts at radius 57.

---

### Task 9: Peripheral walkway, stair and side alcove (left)

**Walkway** at ring radius 62, bearings 50–140 deg, 16 segments (`da = 6 deg`,
chord `2 * 62 * math.sin(math.rad(3)) = 6.49`). Deck top `y 5.50`.
**Segments whose bearing falls in 78–92 deg are skipped** — that is the bridge span.

| Name | Size | Ring radius | `y` centre | Host |
|---|---|---|---|---|
| `WalkwayDeck` | `(6.6, 0.8, 7.5)` | 62 | `5.10` | `walkways`, solid |
| `WalkwaySupport` (every 2nd) | `(3.0, 4.75, 3.0)` | 62 | `2.375` | `walkways`, solid |
| `RailPost` (every 2nd) | `(0.5, 2.5, 0.5)` | 58.9 | `6.75` | `decor` |
| `RailBar` (every 2nd) | `(13.0, 0.35, 0.4)` | 58.9 | `7.80` | `decor`, `METAL`, `BASALT_DARK` |

**Stair** from the field up to the walkway, on a radial frame at bearing 44 deg.
10 steps, `rise 0.49`, `tread 1.15`, running outward from ring radius 52 to 63.5.
Step `k = 1..10`: size `(7.5, 0.7, 1.5)`, position `(0, 0.6 + (k - 1) * 0.49, 52 + (k - 1) * 1.15)`
in a frame whose `+Z` is outward. Two `StairCheek` `(1.0, 6.0, 12.5)` at `x = +/-4.2`.
All in `walkways`, solid.

Rise 0.49 is well under the Roblox 2-stud step limit, so a character walks up without jumping.

**Alcove** at bearing 112 deg — a bulge in the cliff with a recess carved in its inner face,
opening onto the walkway.

| Name | Size | Ring radius | `y` centre | Host |
|---|---|---|---|---|
| `AlcoveMass` | `(20, 17, 12)` | 76 | `8.5` | `boundary`, solid |
| `AlcoveFloor` | `(13, 0.8, 8.5)` | 70 | `5.10` | `walkways`, solid |
| `AlcoveSide` x2 | `(2.4, 9.0, 8.5)` | 70, `x = +/-7.7` | `10.0` | `boundary`, solid |
| `AlcoveHead` x5 | `(3.4, 2.0, 8.0)` | 70 | small arc apex `y 16.2` | `decor` |
| `AlcoveLamp` + cage + cap | as the pillar lantern | 73 | `9.0` | `decor` |

- [ ] **Step 1:** Walkway loop with the bridge gap.
- [ ] **Step 2:** Stair.
- [ ] **Step 3:** Alcove.
- [ ] **Step 4:** Static checks pass.

**Verification:** walkway deck top 5.50 with a 2.5-stud rail; the cliff behind it is 18+
tall, so the walkway does not become a way over the barrier.

---

### Task 10: The curved black-stone bridge

Spans the walkway gap, bearings 78–92 deg at ring radius 62. 9 deck segments,
`t = (k - 1) / 8`, bearing `78 + t * 14` deg, deck top `y = 5.50 + 2.2 * math.sin(math.pi * t)`
(peak 7.70 at mid-span). Deck segments are solid and in `walkways`; everything else is `decor`.

| Name | Size | Placement |
|---|---|---|
| `BridgeDeck` x9 | `(2.8, 0.7, 7.2)` | ring radius 62, top per the arc above |
| `BridgeRib` x7 | `(2.4, 1.6, 6.0)` | 1.5 below each interior deck, `SLATE`, `BASALT_DARK` |
| `BridgeRailPost` x12 | `(0.4, 2.2, 0.4)` | both sides, radius `62 +/- 3.2`, every other segment |
| `BridgeRailBar` x10 | `(3.6, 0.3, 0.35)` | between posts, 1.9 above each deck |
| `BridgeLantern` x2 (arm/cage/glass/cap) | as the pillar lantern | on the two end posts |
| `CreviceWall` x2 | `(3.0, 6.0, 14)` | radius `62 +/- 5`, `y -1.0`, `BASALT_DARK` — the recess the bridge crosses |
| `CreviceGlow` | `(2.0, 0.2, 12)` | radius 62, top `y 0.10`, `LAVA` `NEON`, `glow(p, 0.8, 14)` |

- [ ] **Step 1:** Write the bridge.
- [ ] **Step 2:** Static checks pass.

**Verification:** the deck is continuous from walkway to walkway — no gap wider than
the 0.2-stud joint between segments.

---

### Task 11: Basalt clusters, ember crystals and dry grasses

All `decor`, all `solid = false` except the basalt prisms, which are solid so they read
as real rock when you walk into them.

- **`BasaltCluster` x5** at ring `(radius, bearing deg)`
  `{62, 18}, {66, 300}, {60, 168}, {64, 282}, {61, 340}`. Each is four
  `BasaltPrism` `(2.6, 6 + j * 2.4, 2.6)` at `(x = (j - 2.5) * 2.4, y = (6 + j * 2.4)/2, z = (j % 2) * 1.8)`,
  yaw `j * 0.4`, roll `0.03 * (j - 2)`, colours alternating `BASALT` / `BASALT_LIGHT`, solid.
- **`EmberCrystal` x6 clusters** at `{67, 214}, {65, 246}, {63, 262}, {59, 24}, {68, 196}, {61, 330}`.
  Each is three shards `(1.3, 3.4 + j, 1.3)` yaw `j * 1.1`, roll `0.18 * (j - 2)`, `EMBER`,
  `Enum.Material.Glass`, `Transparency 0.25`; the tallest also gets a
  `CrystalCore` `(0.7, 2.2, 0.7)` `NEON` with `glow(p, 0.7, 12)`.
- **`DryGrass` x12 clumps** at bearings `20 + j * 29` deg, ring radius `57 + (j % 4) * 3`,
  three blades each `(0.14, 1.6 + k * 0.3, 0.4)` yaw `k * 1.2`, roll `0.2`, `DRYGRASS`,
  `Enum.Material.Grass`.
- **Approach dressing** outside the wall: six `ApproachGrass` clumps at
  `z -84 .. -92`, `|x| 16..30`, and two `ApproachBoulder` `(4, 2.6, 3.4)` at
  `(+/-26, 1.3, -86)`. All `solid = false` — therefore `CanQuery = false`, so they cannot
  intrude on the 27 sign sightline rays.

- [ ] **Step 1:** Write the three loops plus the approach dressing.
- [ ] **Step 2:** Static checks pass.

---

### Task 12: Wire it up and version the scenery

**Files:** Modify `src/server/Map/RegionScenery.luau`, `src/server/Systems/TestHarness.luau`

- [ ] **Step 1:** In `RegionScenery.build`, add the Heat delegation beside Wind and Water:

```lua
	elseif def.element == "Heat" then
		require(script.Parent.CinderCanyon).build(parent, frame, radius, makePart)
		return
```

- [ ] **Step 2:** Delete the now-unreachable `if def.element == "Heat" then ... elseif`
  branch of the shared peripheral dressing, and remove `Heat` from `palettes` and from
  the two `def.element == "Heat"` tests inside the perimeter loop. Leave Frost, Storm
  and Cosmic untouched.
- [ ] **Step 3:** In `TestHarness.testRegionAccess`, replace the inline conditional with
  a lookup so a third version does not make the line unreadable:

```lua
	local sceneryVersions: { [string]: number } = { Wind = 3, Water = 3, Heat = 4 }
	...
		local expectedScenery = sceneryVersions[def.element] or 2
```

- [ ] **Step 4:** Static checks pass; `rojo build` succeeds.

---

### Task 13: A live check that the catching field is actually clear

The spec's validation list includes "Central catching space is unobstructed". Nothing
tests that today, so a regression would be invisible.

**Files:** Modify `src/server/Systems/TestHarness.luau`

- [ ] **Step 1:** Add `testRegionFieldClearance` and register it in the live suite beside
  `testRegionSignVisibility`. For each region, `workspace:GetPartBoundsInBox` over a box
  centred `(centre.X, centre.Y + 6, centre.Z)` of size `(2 * 44, 10, 2 * 44)` filtered to
  `Include` the region model, and count parts that are not the ground disc, not the field
  skin, and not `CanCollide == false`.
- [ ] **Step 2:** Run it against **all six** regions first. If a region other than Cinder
  Canyon fails, that is pre-existing: narrow the assertion to `cinder_canyon` rather than
  changing another region's scenery, and record the finding in `RELAY.md`.
- [ ] **Step 3:** Static checks pass.

---

### Task 14: Validate

- [ ] **Step 1:** `python tools/luau_lint.py src` — 0 problems.
- [ ] **Step 2:** `python tools/quote_scan.py src` — 0 problems (the line-initial `if`
  false positive is known; avoid that construct).
- [ ] **Step 3:** `rojo build default.project.json -o build/CinderCanyon.rbxl` succeeds.
- [ ] **Step 4:** Studio, if it can be reached: stop Play, sync, confirm `.Source`, Play.
  Record `[SelfTest]` and `[LiveTest]` pass/fail counts and the map part count.
- [ ] **Step 5:** Walk the checklist from the spec: entrance and approach accessible;
  barriers contain the region; central space unobstructed; creatures spawn and roam on
  usable ground; capture telegraphs visible; walkway and bridge traversable; board
  readable and unobstructed.

---

### Task 15: Documents

- [ ] **Step 1:** Write `docs/art/regions/2026-09-20-concepts/CINDER-CANYON-LAYOUT.md`:
  the coordinate frame, the radial budget, and one table row per unique placeholder with
  name, asset type, studs, local position, rotation, pivot, facing, collision
  (walkable / blocking / none) and module-vs-landmark. Codex must not need the screenshot.
- [ ] **Step 2:** Update `docs/CONTRACTS.md`: the `CinderCanyon.build` signature beside
  Gusty and Splashwater, the `Boundary` / `Walkways` / `Landmarks` split, and
  `SceneryVersion` 4 for Heat.
- [ ] **Step 3:** Prepend a `RELAY.md` checkpoint: feature, files, validation,
  limitations, Studio state, publishing state, next task.

---

## Self-Review

**Spec coverage.** Scope items 1–7 map to Tasks 3 (field), 4+5 (barriers and entrance),
6 (arch), 7 (lavafall terraces), 9+10 (walkway, alcove, bridge), 8 (recessed channels),
5+11 (pillar, basalt and other placeholders). Asset-handoff requirements map to Task 15
Step 1 and the `Boundary` / `Walkways` / `Landmarks` split in Task 2. Integration
constraints map to the Global Constraints and Tasks 12–14. Delivery maps to Task 15.

**Placeholders.** None: every task carries real numbers. Task 7 Step 2 deliberately
carries a correction to catch a ledge that the first pass put inside radius 58.

**Type consistency.** `part`, `disc`, `ring` and `glow` keep one signature throughout;
`boundary` / `walkways` / `decor` are the three host names everywhere; `SceneryVersion`
is 4 in both the module and the harness.

**Known divergences from the render, to state in the handoff doc:**
1. The board is left of the entrance, not right — the real `GateSign` is fixed at
   `(24, h, -90)` and the spec forbids moving it.
2. The arch opening starts above the 16-stud wall, so you see through it but cannot
   walk through it. This is what the concept prompt asks for.
3. Cliff strata are three flat bands, not sculpted erosion; arches are faceted
   voussoirs, not curves. That is the placeholder brief.

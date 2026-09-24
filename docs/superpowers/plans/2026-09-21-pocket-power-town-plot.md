# Pocket Power Town Player Plot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Rebuild the player plot (`src/server/Map/PlotTemplate.luau`) so it matches the
"Pocket Power Town" concept image while every gameplay contract of the plot survives
unchanged, and hand Astra a precise asset request for the custom meshes the concept needs.

**Architecture:** `PlotTemplate.build` keeps its signature and its output contract (part
names, pad positions, folders, the `Plot` record) and rewrites the visuals as slate-blue
paving, framed pads, a coin plaza, a dispatch booth (front, image-left), an owner sign
(front, image-right), a water tower (rear, image-left) and a brick workshop (rear,
image-right). Everything that Astra will replace with a mesh is built as a
`PropSites/<Site>/PlaceholderArt` stand-in with the same site attributes the region kits
use, so `PlotProps.apply` swaps them in exactly the way `ThunderProps.apply` does.
Collision and every functional part (pads, strips, vent button, console, billboard,
collect pad, spawn) are permanent geometry outside the placeholders.

**Tech Stack:** Luau (`--!strict`), Rojo 7.7 (`default.project.json`, serve on port 34872),
Roblox Studio, Lune 0.10.5 for headless measurement
(`C:\Users\rahul\AppData\Local\Temp\lunebin\lune.exe`), Python 3 for the static scans
(`tools/luau_lint.py`, `tools/quote_scan.py`) and image analysis.

**Spec:** `docs/art/plots/2026-09-21-player-plot/CLAUDE_IMPLEMENTATION_PROMPT.md`
**Reference image:** `docs/art/plots/2026-09-21-player-plot/plot-v2-pocket-power-town.png`
**Concept prompt:** `docs/art/plots/2026-09-21-player-plot/PROMPTS.md` (section
"plot-v2-pocket-power-town.png" is the authoritative art description)

---

## Global Constraints

Copied from the spec and from the code the spec must not break.

- **Repository:** `C:\Users\rahul\orca\Catch-a-Catastrophe`, branch `main`. The worktree
  under `orca\workspaces\...` is stale; Rojo serves the main checkout. Preserve the ~22
  modified / many untracked files already in the working tree.
- **Do not publish. Do not commit.** (`AGENTS.md` items 6 and 8.) Where this plan's steps
  would normally say "commit", they say "no commit" instead.
- **Do not hand-patch Studio script `.Source`.** Rojo is the only sync path. Stop Play
  before syncing (this session has no Studio bridge; record what Studio has not verified).
- **Preserve the 60 x 60 footprint** (`Platform` 60 x 1 x 60 at local origin, top y = 0.5) and
  the `Apron` 22 x 1 x 14 at (0, 0, -36): the live test asserts the driveway ends exactly at
  the apron edge (`TestHarness.luau:1230-1253`).
- **Preserve all 24 pads:** `Pads.Pad_<n>` 6 x 0.6 x 6, top y = 1.1, col c at
  x = -20 + 8(c-1), row r at z = -6 + 8(r-1), index (r-1)*6 + c, attributes `PadIndex`,
  `Unlocked`, child `ManagePrompt` (E, range 7, disabled). `padCFrame`, `pairCFrame`,
  `stationCFrame`, `setPadUnlocked` keep their behaviour.
- **Preserve every name other code reads:** `Platform`, `Apron`, `Kerb` (CosmeticsService
  skins recolour by name), `Pads`, `Stations.Station_<n>`, `Machines`, `Booth` with
  `VentButton` (attribute `Prompt = "Vent"`) and `Console` (SurfaceGui `Gui` -> `Text`),
  `CollectPad` (8 x 0.4 x 8 at (0, 0.7, -23), attribute `Touch = "Collect"`, BillboardGui
  `Label` -> `Text`; `CollectionPadService.withinPad` uses its Size), `Billboard`
  (Waypoints anchor; SurfaceGui `Gui` -> `Title`, `Earnings`), `SpawnPoint` at (0, 0.5, -34),
  `VisitorSpot`, `Tier_1..3`, `Rewards`, `Garden`, `Decorations` (cosmetics folder).
- **Station and machine envelopes must stay clear.** A work station is pivoted at
  pad + (0, -0.05, 3.4) and its plinth is up to 3.0 wide x 2.6 deep with its bottom at
  y = 1.05. A circuit machine is pivoted at the midpoint of two adjacent pads, y = 1.05, and
  fits 8 x 6 x 8. Nothing new may rise above y = 1.05 inside those boxes: pad frames top out
  at 0.97, corner brackets at 1.04, strips at 1.005.
- **Circuit rules are gameplay, not art.** No decorative "connection" lines between pads;
  the machine that CircuitService builds is the connection.
- **Decor slots must survive.** `DecorSlots.compute` (lattice x -26..26, z -27..26, spacing 4,
  clearance 3.5) must still return >= 6 slots (live test). Flat ground details are added to
  its `IGNORED` list; the forecourt between the front pad row and the plaza stays open.
- **Z-fighting:** no coplanar overlapping visible faces. Anything resting on the platform
  is buried >= 0.02 or lifted >= 0.02; stacked slabs keep >= 0.04 between tops.
- **Cylinders run along local X.** Vertical cylinder = `Vector3.new(height, d, d)` with
  `CFrame.Angles(0, 0, math.rad(90))`.
- **`Kit.finalize` is never called on the plot** (it welds and clears collision).
- **A Write hook rejects any file containing a dot followed by `format(`.** Use
  `("%d"):format(x)` or concatenation.
- **The Bash tool strips one backslash level inside heredocs.** Write Luau with the Write
  or Edit tools.
- **Lighting blooms white:** avoid pure white surfaces; ivory (214, 204, 186) for large areas,
  cream (238, 224, 198) only for trims. Neon only on strips, lantern glass, the vent button
  and the lit window.
- **Part budget:** aim <= 560 parts per plot including hidden tiers (6 plots in Layout B).
  Record the measured count; mobile cost is unmeasured on this project.

---

## Coordinate frame

Plot-local, applied as `cframe * CFrame.new(...)`. MapBuilder places each plot with
`CFrame.lookAt(polar(140, a), origin)`.

| Axis | Direction |
|---|---|
| `-Z` | the front: the hub, the driveway, the entrance |
| `+Z` | the rear |
| `+X` | **image-left** when standing on the driveway looking into the plot (Right = Look x Up) |
| `-X` | image-right |

So the reference's front-left booth is at **+X**, the front-right owner sign at **-X**, the
rear-left water tower at **+X**, the rear-right workshop at **-X**. (The old module had the
booth at -X; it moves.)

## Palette (all `Color3.fromRGB`)

| Name | RGB | Sampled from |
|---|---|---|
| PAVING | 142, 148, 172 | forecourt slate-blue (150,150,174)/(138,150,174) |
| PAVING_LIGHT | 168, 172, 192 | plaza / apron |
| PAD_INSET | 104, 108, 128 | empty pad (114,114,138)/(102,102,126) |
| PAD_LOCKED | 74, 78, 96 | locked pad, plus 0.55 transparency |
| FRAME | 172, 178, 198 | pad frame (126,138,162) lifted for contrast |
| KERB | 214, 204, 186 | ivory curb |
| CREAM | 238, 224, 198 | booth roof (246,222,198) |
| TEAL | 42, 108, 128 | tower tank (30,90,114)/(66,150,162) |
| TEAL_LIGHT | 66, 146, 160 | tank highlight |
| NAVY | 46, 56, 72 | tower frame, fence rails (30,42,54)/(54,66,78) |
| YELLOW | 244, 196, 72 | corner brackets, trims |
| GOLD | 250, 212, 88 | coin (254,214,86) |
| GOLD_DARK | 206, 156, 58 | coin rim (213,164,59) |
| BRICK | 152, 88, 66 | workshop (150,90,66) |
| ROOF_DARK | 74, 78, 92 | workshop roof |
| GLASS | 150, 196, 210 | windows |
| LAMP | 255, 236, 190 | lantern glow |
| RED | 232, 64, 54 | vent button (246,72,59) |
| LEAF / LEAF_DARK / LEAF_LIGHT | 96,140,72 / 66,108,58 / 128,168,84 | shrubs, trees |
| TRUNK | 110, 84, 60 | tree trunk |
| INK / HAZARD | 46,44,52 / 255,190,50 | existing house style |

## Layout (the measured contract; every number is plot-local)

Heights: platform top **0.5**; pad top **1.1**; kerb top **1.195**; frame top **0.97**;
strip top **1.005**; corner bracket top **1.04**; plaza slab top **0.86**; CollectPad top
**0.9**; coin disc 0.92..1.22.

### Ground and entrance (permanent)

| Part | Size | Centre | Notes |
|---|---|---|---|
| `Platform` | 60 x 1 x 60 | (0, 0, 0) | PAVING, Concrete, collide |
| `Apron` | 22 x 1 x 14 | (0, 0, -36) | PAVING_LIGHT, Concrete, collide (unchanged bounds) |
| `Kerb` rear | 60.8 x 0.75 x 1.4 | (0, 0.82, 29.7) | KERB, collide; buried 0.055 |
| `Kerb` sides x2 | 1.4 x 0.75 x 60.8 | (+-29.7, 0.82, 0) | |
| `Kerb` front x2 | 22.6 x 0.75 x 1.4 | (+-18.7, 0.82, -29.7) | leaves a 14.8 entrance gap, x -7.4..7.4 |
| `Threshold` | 14.6 x 0.32 x 2.2 | (0, 0.64, -29.9) | KERB; covers the Platform/Apron overlap strip z -30..-29 |
| `Stripe` x10 | hazardStrip | origins (+-12.2, 0.95, -30.5), length 8 | on the front kerb faces flanking the entrance |
| `SpawnPoint` | 8 x 1 x 8 | (0, 0.5, -34) | PAVING_LIGHT, opaque, Neutral, Enabled false |
| `VisitorSpot` | 4 x 1 x 4 | (9, 0.5, -34) | Transparency 1 |
| `Plaza` | 11 x 0.3 x 11 | (0, 0.71, -23) | PAVING_LIGHT; bottom 0.56 |
| `CollectPad` | 8 x 0.4 x 8 | (0, 0.7, -23) | GOLD_DARK, Metal, collide false, touch true, `Touch="Collect"`, Label billboard |

### Pads (permanent) and pad frames (art)

For pad n at (x, z): `Pad_n` unchanged; child `Strip` 3.4 x 0.1 x 0.26 at (x, 0.955, z-3.22),
PAD_INSET-dim (90, 96, 120) SmoothPlastic when empty, Neon element colour when occupied,
`CanQuery = false`. Site `PadFrame_n` (asset `PP_Pad_Frame`, size (7, 0.45, 7), GroundCF
`(x, 0.52, z)`, Grounded on `Platform`), placeholder `Frame` 7 x 0.45 x 7 at (x, 0.745, z)
FRAME + four `Corner` 0.55 x 0.1 x 0.55 at (x+-3.225, 0.99, z+-3.225) YELLOW. All art
`CanCollide/CanTouch/CanQuery = false`.

### Booth (front, +X). Model `Booth`

Permanent: `BoothCore` 6.6 x 4.6 x 6.0 at (22.5, 2.9, -23.5) invisible collider;
`Console` 3.2 x 1.5 x 0.3 at (18.85, 3.25, -22.6) rotated `Angles(0, rad(90), 0)` so Front
faces -X (the plot centre), SurfaceGui text; `VentBase` 1.6 x 1.3 x 1.6 at (17.9, 1.15, -27.4)
INK collide; `VentBand` 1.7 x 0.3 x 1.7 at (17.9, 1.5, -27.4) HAZARD; `VentButton` cylinder
(0.5, 1.5, 1.5) vertical at (17.9, 2.05, -27.4) RED Neon, `Prompt = "Vent"`; `DispatchLabel`
4.2 x 0.95 x 0.04 at (22.5, 6.3, -27.05) Transparency 1 carrying the "DISPATCH" SurfaceGui.
Site `DispatchBooth` (asset `PP_Dispatch_Booth`, size (7, 6.6, 6.5), GroundCF
`(22.5, 0.5, -23.5)`): placeholder base 7 x 0.5 x 6.5 NAVY (y 0.52..1.02), body 6.2 x 3.6 x 5.7
TEAL (1.02..4.62), three GLASS window bands 1.6 tall at y 3.4 (front z -26.4; sides x 19.36
and 25.64), CREAM counter (0.9, 0.25, 4.4) at (18.95, 2.3, -23.5), CREAM roof 7.4 x 0.5 x 6.9
(4.65..5.15), CREAM dome Ball 6.4 x 2.2 x 6.0 at y 5.15, YELLOW trim 7.5 x 0.18 x 7.0 at
y 4.62, TEAL sign board 4.4 x 1.1 x 0.25 at (22.5, 6.3, -26.9) on two NAVY posts, four CREAM
corner posts 0.35 x 3.6 x 0.35.

### Owner sign (front, -X)

Permanent: `Billboard` 9.4 x 3.2 x 0.3 at (-22, 3.85, -26.62) CREAM, SurfaceGui `Gui`
(PixelsPerStud 24) with `Title` (scale 0.06..0.64, dark teal 34,88,104) and `Earnings`
(0.66..0.96, GOLD_DARK); `SignCore` 10 x 2.0 x 2.2 at (-22, 1.5, -26.4) invisible collider.
Site `OwnerSign` (asset `PP_Owner_Sign`, size (10, 6.4, 2.2), GroundCF `(-22, 0.5, -26.4)`):
placeholder BRICK base 10 x 1.5 x 2.2 (0.52..2.02), KERB cap 10.4 x 0.2 x 2.6 at y 2.12, TEAL
frame 10 x 3.8 x 0.4 at (-22, 3.85, -26.4), YELLOW trim 10.3 x 4.1 x 0.16 at z -26.28,
TEAL cap Ball 5.0 x 1.6 x 0.5 at y 5.9 with CREAM emblem disc, two NAVY posts 0.45 x 3.6 x 0.45
at x -26.6/-17.4 z -26.0, three LEAF shrubs and three blooms on the deck at z -24.6.

### Water tower (rear, +X)

Permanent: four `TowerLeg` colliders 0.6 x 12 x 0.6 at (15.5+-2.2, 6.5, 26.0+-2.2) invisible;
`Windvane` 1.6 x 0.12 x 0.3 at (15.5, 15.6, 26.0) YELLOW tagged `SceneryMotion` (Spin, speed
1.2) with `VaneAxle`. Site `WaterTower` (asset `PP_Water_Tower`, size (6, 13.5, 6), GroundCF
`(15.5, 0.5, 26.0)`): placeholder four NAVY legs 0.55 x 8.5 x 0.55 (0.5..9.0) with CREAM feet,
eight NAVY braces (rings at y 3.6 and 6.8), TEAL tank cylinder (4.6, 6.4, 6.4) vertical at
y 11.3 (9.0..13.6), two NAVY bands, YELLOW cap Ball 6.6 x 2.6 x 6.6 at y 13.6 and finial,
CREAM cat-emblem disc on the front of the tank, TEAL downpipe (8.6, 0.5, 0.5) vertical at
(15.5, 4.8, 28.4) with a ball elbow feeding the rear pipe run.

### Workshop (rear, -X)

Permanent: `WorkshopCore` 16 x 6.2 x 5.9 at (-11, 3.6, 26.05) invisible collider; two
`WallLampAnchor` 0.2 cubes at (-11+-4.6, 4.2, 23.0) invisible, each with a warm PointLight
(range 12, brightness 0.8); `ChimneyAnchor` 0.2 cube at (-17.2, 9.5, 27.6) with a slow
ParticleEmitter (rate 1.5). Site `UtilityWorkshop` (asset `PP_Utility_Workshop`, size
(16, 8.6, 5.9), GroundCF `(-11, 0.5, 26.05)`): placeholder BRICK walls 16 x 5.6 x 5.9
(0.52..6.12), NAVY plinth, CREAM roofline band, ROOF_DARK roof 16.6 x 0.45 x 6.5 (6.18..6.63),
STEEL roof vent, BRICK chimney 1.5 x 3.2 x 1.5 at (-17.2, 7.6, 27.6) with NAVY cap, TEAL garage
door 4.4 x 3.4 x 0.2 at (-9.5, 2.6, 22.98) in a CREAM frame, NAVY side door at x -15.5 in a
CREAM trim, two windows (one lit Neon LAMP, one GLASS) at x -5 and -13, two wall lamps
(NAVY bracket + Neon LAMP head), CREAM cat plaque.

### Fence, lanterns, banners, pipes, vegetation

- `FencePost` 1.4 x 3.8 x 1.4 BRICK at y 2.4 with `PostCap` 1.7 x 0.3 x 1.7 KERB at y 4.45, on
  the kerb line at: corners (+-29.7, +-29.7); sides (+-29.7, z = -15, 0, 15); rear (x = +-22, 29.7);
  front (x = +-8.2 and +-19.5, -29.7). 16 posts.
- Rails `RailTop`/`RailMid` NAVY 0.18 square at y 2.9 and 1.9 between consecutive posts on each
  edge; on the rear the rail runs corner -> +-22 post -> tower box edge (x 18.5) and
  tower (x 12.5) -> workshop wall (x -3), and workshop (x -19) -> -22 post. Front bays run
  from each corner to +-19.5 and from +-19.5 to +-8.2. The entrance stays open.
- Lanterns (site `Lantern_k`, asset `PP_Lantern`, size (1, 1.5, 1), GroundCF at the cap top
  `(x, 4.6, z)`, Stacked on the post) on the four corners, the two entrance posts and the two
  z = 0 side posts; placeholder NAVY cage 0.9 x 1.1 x 0.9 (transparency 0.35), Neon LAMP glass
  0.55 x 0.7 x 0.55, NAVY cap. The warm PointLight (range 14, brightness 0.7) lives on the
  permanent `PostCap`.
- Banners (permanent): posts 0.4 x 7.5 x 0.4 NAVY at (+-28.2, 4.25, -6) with YELLOW finials,
  CREAM boards 3.2 x 5.2 x 0.2 at (+-27.7, 6.0, -6) facing the centre, TEAL frames behind;
  text "COLLECT POWER / GROW YOUR CITY" (+X) and "TINY DISASTERS / MAKE A BRIGHTER DAY" (-X).
  Rear banner CREAM 5 x 3 x 0.2 at (-25, 4.4, 28.6) facing front, "SMALL CREATURES / BRIGHTER
  TOMORROWS", TEAL frame.
- Pipe runs (site `PipeRun_k`, asset `PP_Pipe_Run`, size (8, 0.8, 0.8), GroundCF at the run's
  bottom centre y 0.7, rotated so the run's X axis follows the run): rear (8.5, 0.7, 28.4) and
  (0.5, 0.7, 28.4); +X side at x 26.0, z = -8, 4, 16; -X side at x -26.0, z = 4, 16. Placeholder
  TEAL cylinder (8, 0.6, 0.6) plus two YELLOW couplings (0.5, 0.8, 0.8) at +-3.0. Elbows (site
  `PipeElbow_k`, asset `PP_Pipe_Elbow`, size (1.2, 1.6, 1.2)) at (26.0, 0.7, -13) and
  (-26.0, 0.7, -1).
- Shrubs (site `Shrub_k`, asset `PP_Shrub_Cluster`, size (2.6, 1.4, 2.0)): sides at x +-27.9,
  z = -22, -8, 8, 22; rear (7.6, 0.5, 26.4) and (-24.6, 0.5, 26.6). Placeholder three LEAF balls.
- Flower beds (site `FlowerBed_k`, asset `PP_Flower_Bed`, size (2.4, 0.9, 1.6)): (+-13, 0.5, -28.0)
  and (9.5, 0.5, 26.6). Placeholder KERB planter, soil, three blooms.
- Trees (site `Tree_k`, asset `PP_Round_Tree`, size (7, 9.5, 7), GroundCF y = 0 on the world
  grass): (35, 0, 33), (-35, 0, 33), (35, 0, -24), (-35, 0, -24). Placeholder TRUNK cylinder
  (4.0, 1.2, 1.2) vertical at y 2.0 and three LEAF canopy balls.

### Milestone decoration spots (`REWARD_SPOTS`)

| Key | CFrame | Why there |
|---|---|---|
| hazard_flags | `CFrame.new(0, 0.5, -17.5) * Angles(0, rad(180), 0)` | bunting across the forecourt; poles at x +-5 |
| smiling_billboard | `CFrame.new(4.5, 0.5, 26.8)` | rear gap between tower (x >= 12.5) and workshop (x <= -3) |
| golden_statue | `CFrame.new(-1.0, 0.5, 26.6)` | same gap, clear of the billboard by 0.6 |
| pipe_fountain | `CFrame.new(13.5, 0.5, -23.5)` | between the booth and the plaza |
| neon_company_sign | `CFrame.new(-12, 0.5, -22.5)` | between the owner sign and the plaza, facing the entrance |

### Decoration tiers (extras beyond the reference; hidden until bought)

- `Tier_1` pipes and machinery: an upper pipe rack on the fence line (x +-29.7, y 3.6) with
  three runs per side at z -8, 4, 16, two RED valve wheels, two wooden crates and a TEAL barrel by
  the workshop side door (x -17.5 / -16.4 / -7.4, z ~21.7).
- `Tier_2` lights: three Neon bulbs per side bay on the top rail (y 3.3), two workshop
  floodlights on the roofline with SpotLights.
- `Tier_3` landmark machinery: a rooftop turbine on the workshop (mast at (-6.5, ., 27.5), three
  blades spinning via `SceneryMotion`), seven bunting flags along the rear rail, an auxiliary
  TEAL tank beside the tower at (21.5, ., 26.0).

Tier parts record `AuthoredTransparency` and `AuthoredCollide` attributes at build time;
`setDecorationTier` restores them when shown and hides them (Transparency 1, no collision,
lights and emitters disabled) otherwise.

---

## File structure

| File | Responsibility |
|---|---|
| `src/server/Map/PlotAssetSpec.luau` (new) | Roblox XYZ bounds for the 11 plot asset names. Consumed by PlotProps, ImportStaging and the tests. |
| `src/server/Map/PlotProps.luau` (new) | `apply(parent: Model, frame: CFrame) -> boolean`: validates `PropSites` against `PlotPropTemplates`, swaps placeholders for native meshes (copy of the ThunderProps contract). |
| `src/server/Map/PlotTemplate.luau` (rewrite) | Geometry, sites, `setPadElement`, generic tiers, re-homed reward spots. |
| `src/server/Map/ImportStaging.luau` (modify) | Recognise `PlotPropsBundle` -> `PlotPropTemplates`, including a first import of the exact 11-mesh kit. |
| `src/server/Systems/CityService.luau` (modify `refreshPad`) | Tint the pad strip with the creature's element colour; clear it when empty. |
| `src/shared/Models/DecorSlots.luau` (modify `IGNORED`) | Ignore the new flat ground details. |
| `src/shared/Config/Cosmetics.luau` (modify `skin_default`) | The free "Company Standard" palette becomes the Pocket Power Town paving. |
| `src/server/Systems/TestHarness.luau` (modify `testPlot`) | Contract checks: names, positions, envelopes, coplanar faces, tiers, sites, props refusal. |
| `docs/CONTRACTS.md` (modify plot section) | New positions, `setPadElement`, `PropSites`, `PlotProps`. |
| `docs/art/plots/2026-09-21-player-plot/POCKET-POWER-TOWN-ASSET-REQUEST.md` (new) | Astra's asset request and the measured site table. |
| `RELAY.md` (prepend entry) | Protocol step 9. |

Headless harness (scratchpad, not committed): `run_plot.luau` (builds the module with a
Config stub and dumps parts), `analyse_plot.py` (coplanar faces, envelopes, aisles, decor
slots, counts, top-down render), `verify_plot_props.luau` (PlotProps.apply behaviour with a
synthetic native library).

---

### Task 1: PlotAssetSpec and PlotProps

**Files:**
- Create: `src/server/Map/PlotAssetSpec.luau`
- Create: `src/server/Map/PlotProps.luau`
- Test: scratchpad `verify_plot_props.luau` (Lune)

**Interfaces:**
- Produces: `PlotAssetSpec: { [assetName]: Vector3 }` with exactly these keys:
  `PP_Water_Tower (5.6, 15, 5.6)`, `PP_Utility_Workshop (16, 8.6, 5.5)`, `PP_Dispatch_Booth
  (7, 6.6, 6.5)`, `PP_Owner_Sign (10, 6.4, 2.2)`, `PP_Coin_Platform (8, 0.55, 8)`,
  `PP_Pad_Frame (7, 0.45, 7)`, `PP_Lantern (1, 1.5, 1)`, `PP_Pipe_Run (8, 0.8, 0.8)`,
  `PP_Pipe_Elbow (1.2, 1.6, 1.2)`, `PP_Shrub_Cluster (2.6, 1.4, 2.0)`, `PP_Flower_Bed
  (2.4, 0.9, 1.6)`, `PP_Round_Tree (7, 9.5, 7)`.
- Produces: `PlotProps.apply(parent: Model, frame: CFrame): boolean`. Reads
  `parent.PropSites` (a Model with attribute `AssetCount`), each child site Model with
  attributes `AssetName`, `AssetSize`, `GroundCF`, `PivotMode = "BottomCenter"`,
  `CollisionRole = "none"`, `PlacementRole in {Grounded, Stacked}`, and a `PlaceholderArt`
  child Model with no colliding parts. Requires `script.Parent.PlotPropTemplates`. Places
  `mesh.CFrame = frame * GroundCF * CFrame.new(0, size.Y/2, 0)` into `parent.BlenderProps`,
  destroys placeholders, sets `AssetPlaced`, `BlenderPropsVersion = 1`, `BlenderPropCount`.
  Returns false and changes nothing when anything is off.

- [x] **Step 1: Write PlotAssetSpec.luau**

```lua
--!strict
-- Roblox XYZ bounds of the Pocket Power Town plot kit. Astra builds to these;
-- PlotTemplate authors its sites to these; PlotProps refuses anything else.
return {
	PP_Water_Tower = Vector3.new(6, 13.5, 6),
	PP_Utility_Workshop = Vector3.new(16, 8.6, 5.9),
	PP_Dispatch_Booth = Vector3.new(7, 6.6, 6.5),
	PP_Owner_Sign = Vector3.new(10, 6.4, 2.2),
	PP_Coin_Platform = Vector3.new(8, 0.55, 8),
	PP_Pad_Frame = Vector3.new(7, 0.45, 7),
	PP_Lantern = Vector3.new(1, 1.5, 1),
	PP_Pipe_Run = Vector3.new(8, 0.8, 0.8),
	PP_Pipe_Elbow = Vector3.new(1.2, 1.6, 1.2),
	PP_Shrub_Cluster = Vector3.new(2.6, 1.4, 2.0),
	PP_Flower_Bed = Vector3.new(2.4, 0.9, 1.6),
	PP_Round_Tree = Vector3.new(7, 9.5, 7),
}
```

- [x] **Step 2: Write PlotProps.luau** as a copy of `ThunderProps.luau` with `sites =
  parent:FindFirstChild("PropSites")`, `library = script.Parent:FindFirstChild("PlotPropTemplates")`,
  `sizes = require(script.Parent.PlotAssetSpec)`, roles `Grounded`/`Stacked` only.

- [x] **Step 3: Write `verify_plot_props.luau`** (after Task 2 exists): build a plot headlessly,
  check `apply` returns false with no library, false with a partial library, false when one
  site's `AssetSize` is scaled 100x, false when a placeholder part collides, true with a full
  synthetic library (MeshParts named per spec with a fake `MeshId`), then: every site has a
  mesh of the right size at `frame * GroundCF * (0, h/2, 0)`, permanent parts unchanged
  (size, CFrame, collision, transparency), lights unchanged, a second `apply` returns false.

- [x] **Step 4: Run** `lune run verify_plot_props.luau` -> all checks pass. No commit.

### Task 2: Rewrite PlotTemplate.luau

**Files:**
- Modify (rewrite): `src/server/Map/PlotTemplate.luau`

**Interfaces:**
- Consumes: `Config.Circuits.grid/maxPads/padCoords`, `Config.Regions.elementColor`,
  `PlotAssetSpec`, `PlotProps.apply`.
- Produces (unchanged): `build(cframe, index): Plot`, `setOwner`, `setPadUnlocked`,
  `setDecorationTier`, `setRewardDecoration`, `padCFrame`, `pairCFrame`, `stationCFrame`,
  `reset`. New: `setPadElement(plot: Plot, pad: number, color: Color3?)`. `Plot` gains
  `propSites: Model` and `padStrips: { [number]: Part }`.

- [x] **Step 1: Helpers.** Keep `part`, `hazardStrip`, `surfaceLabel`; add `cyl(props)` (vertical
  cylinder: `size = Vector3.new(h, d, d)`, `cf * Angles(0,0,rad(90))`), `site(parent, name,
  assetName, groundCF, role, supportPath): (Model, Model)` that creates the site Model with the
  attributes above and returns `(siteModel, placeholderArt)`, `art(props)` = `part` with
  `collide=false, touch=false, query=false`, `textBoard(host, face, lines, size, color)`.

- [x] **Step 2: Build order inside `build`:** ground -> pads (+strips, +frame sites) ->
  plaza/collect -> booth -> owner sign -> water tower -> workshop -> fence + lanterns ->
  banners -> pipes -> vegetation (`Garden`) -> tiers -> `Rewards` -> `PropSites` attribute
  `AssetCount` -> `PlotProps.apply(model, cframe)` in a `pcall` -> parent to `workspace.Plots`.

- [x] **Step 3: `setPadElement`:**

```lua
function PlotTemplate.setPadElement(plot: Plot, pad: number, color: Color3?)
	local strip = plot.padStrips[pad]
	if not strip then
		return
	end
	if color then
		strip.Color = color
		strip.Material = Enum.Material.Neon
	else
		strip.Color = STRIP_IDLE
		strip.Material = Enum.Material.SmoothPlastic
	end
end
```

`reset` calls `setPadElement(plot, pad, nil)` for every pad.

- [x] **Step 4: Generic tiers.** After building each tier, walk descendants: BaseParts get
  `AuthoredTransparency`/`AuthoredCollide` attributes then `Transparency = 1, CanCollide =
  false`; Lights and ParticleEmitters `Enabled = false`. `setDecorationTier(plot, tier)` restores.

- [x] **Step 5: Run headlessly** `lune run run_plot.luau src/server/Map/PlotTemplate.luau after.json`
  and `python analyse_plot.py after.json`: zero coplanar overlaps, zero station/machine envelope
  intrusions, aisles >= 2.4, decor slots >= 6, every site attribute present, part count reported.
  Fix until clean. No commit.

### Task 3: Integration edits

**Files:**
- Modify: `src/server/Systems/CityService.luau:293-354` (`refreshPad`)
- Modify: `src/server/Map/ImportStaging.luau:6-13, 21-44`
- Modify: `src/shared/Models/DecorSlots.luau:36-46`
- Modify: `src/shared/Config/Cosmetics.luau:79`

- [x] **Step 1: CityService.refreshPad.** After clearing the station folder and before
  `if not uid then return end`, add `PlotTemplate.setPadElement(plot, pad, nil)`; after the
  creature model is built (inside the `def` branch) add
  `PlotTemplate.setPadElement(plot, pad, Config.Regions.elementColor(def.element))`. Guard with
  `typeof(PlotTemplate.setPadElement) == "function"`.

- [x] **Step 2: ImportStaging.** Add `PlotPropsBundle = "PlotPropTemplates"` to `LIBRARIES`,
  require `PlotAssetSpec`, and treat a first `PlotPropsBundle` import like the Orbit case
  (exact 12-mesh kit, every name in the spec, no duplicates, non-empty MeshId).

- [x] **Step 3: DecorSlots.IGNORED.** Add `Threshold = true, Plaza = true, Strip = true`.

- [x] **Step 4: Cosmetics skin_default palette** ->
  `{ platform = rgb(142, 148, 172), apron = rgb(168, 172, 192), kerb = rgb(214, 204, 186) }`;
  swatch `color = rgb(142, 148, 172)`; desc "The slate-blue paving the company issued you. Free."

- [x] **Step 5: Static checks** `python tools/luau_lint.py src` and `python tools/quote_scan.py src`
  -> clean. No commit.

### Task 4: TestHarness.testPlot

**Files:**
- Modify: `src/server/Systems/TestHarness.luau:394-418`

- [x] **Step 1: Extend `testPlot`** with checks (each a `check(...)` line):
  - `Platform` 60 x 1 x 60 at local (0,0,0); `Apron` 22 x 1 x 14 at (0,0,-36); >= 4 parts named `Kerb`.
  - every `Pad_n` top at local y 1.1 and at the documented (x, z); every pad has a `Strip` child.
  - `CollectPad` 8 x 0.4 x 8 at (0, 0.7, -23) with `Touch == "Collect"` and a `Label` BillboardGui.
  - `Booth.VentButton` attribute `Prompt == "Vent"`; `plot.booth.console` is a TextLabel under a SurfaceGui named `Gui`.
  - `Billboard` has `Gui.Title` and `Gui.Earnings`; `setOwner(plot, 5, "Astra")` puts "Astra" in Title; `setOwner(plot, 0, "")` restores "Vacant Lot".
  - `SpawnPoint` at (0, 0.5, -34), `Enabled == false`; `VisitorSpot` Transparency 1.
  - no part inside any station envelope (pad + (0, 3.4) box 3.0 x 2.6, y 1.05..5) or machine envelope (midpoint of every adjacent pair, 8 x 8, y 1.05..7) other than pads, strips, frames, corners below 1.05 (a part is "inside" when its AABB intersects the box and its top exceeds 1.05).
  - no two visible axis-aligned parts share a top plane (|dy| < 0.005) with overlapping footprints.
  - `PropSites.AssetCount == #children`, every site has `AssetName` in `PlotAssetSpec`, `AssetSize` equal to the spec, `GroundCF`, `PivotMode`, `CollisionRole`, `PlacementRole`, a non-colliding `PlaceholderArt`; `PlotProps.apply(plot.model, plot.cframe) == false` (no library in the repo yet) and every placeholder still present afterwards.
  - `setPadElement(plot, 1, Color3.new(1,0,0))` makes the strip Neon red; `setPadElement(plot, 1, nil)` makes it SmoothPlastic.
  - `setDecorationTier(plot, 3)`: every tier part has Transparency == AuthoredTransparency; `setDecorationTier(plot, 0)`: all Transparency 1 and no collision.
  - `DecorSlots.compute(plot.model)` returns >= 6 slots.
  - part count of the built plot <= 560 (reported in the detail string).

- [x] **Step 2: Compile check** `python tools/luau_lint.py src` and a `luau.load` compile pass
  of every `.luau` under `src` in Lune. No commit.

### Task 5: Documentation and handoff

**Files:**
- Modify: `docs/CONTRACTS.md:141-169`
- Create: `docs/art/plots/2026-09-21-player-plot/POCKET-POWER-TOWN-ASSET-REQUEST.md`
- Modify: `RELAY.md` (new top entry)

- [x] **Step 1: CONTRACTS.md plot table**: update Booth (+X front), CollectPad (unchanged), Billboard
  (owner sign at (-22, 3.85, -26.62), 9.4 x 3.2), `Pads.Pad_n.Strip`, `PropSites`, `BlenderProps`,
  `setPadElement`, `PlotProps.apply`, `PlotAssetSpec`.
- [x] **Step 2: Asset request** with, per asset: name, count per plot, reference appearance,
  bounds in studs, pivot (bottom-centre) and facing (-Z is the plot front; sites carry
  `GroundCF`), material colours, collision (none; permanent colliders listed), interaction
  constraints (booth console/vent/dispatch label, sign board opening, coin disc over the
  CollectPad), export contract (FBX Y-up, palette atlas, `PlotPropsBundle` with separate
  meshes), and what remains dependent on delivery.
- [x] **Step 3: RELAY.md** entry: feature, files, validation numbers, limitations (no Studio this
  session), Studio state, publishing state (none), next task.
- [x] **Step 4: Build and stamp** `rojo build -o build/PlotPocketPowerTown.rbxl`,
  `python tools/stamp.py`. No commit, no publish.

---

## Self-review

- Spec coverage: layout/proportions/colours (palette + layout tables), water tower rear-left
  and workshop rear-right (+X/-X rear), booth front-left with red vent button (+X front,
  `VentButton`), gold platform centred at the entrance (plaza + coin site), owner sign
  front-right with the real owner's name (`Billboard.Title` via `setOwner`/`refreshLabels`),
  fencing/lamps/pipes/shrubs/trees (fence, lanterns, pipe runs, shrubs, trees), clear walking
  space (aisle check), footprint/pads/indices/adjacency/unlocking/deployment/stations
  (unchanged pad math), collection/venting/ownership/spawning/circuits/progression
  (names preserved; tiers generic), creature models untouched, asset request for Astra,
  verification (headless + Studio owed).
- Types: `setPadElement(plot, pad, color?)` used identically in Tasks 2, 3, 4;
  `PlotProps.apply(parent, frame)` in Tasks 1, 2, 4; site attributes named identically in
  Tasks 1, 2, 4, 5.

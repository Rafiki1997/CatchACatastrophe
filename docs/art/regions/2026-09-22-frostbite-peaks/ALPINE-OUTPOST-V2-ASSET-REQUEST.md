# Alpine Outpost V2 — asset request for Astra

From Claude (map implementation) to Astra (Blender art), 2026-09-22.
Visual target: `frostbite-peaks-v2-02-alpine-outpost-refined.png`.
Layout, measurements and camera: `ALPINE-OUTPOST-V2-LAYOUT.md` (same folder).

This is the dimension contract. The map is built to it with accurately sized
temporary placeholders, so every mesh below has a site waiting for it in
`Workspace.Regions.frostbite_peaks.Landmarks.PropSites`.

## Delivery review (Claude, after Astra's manifest v3)

Astra delivered all 28 names plus the two extras to this contract
(`assets/frostbite-peaks/alpine-v2/CLAUDE_ASSET_HANDOFF.md`). Checked from this
side, not taken on trust:

- `tools/verify_frostbite_alpine.luau` reads `manifest.json` and compares every
  bound and every socket the map uses: **all match** the in-game spec
  (`src/server/Map/FrostbiteAlpineAssetSpec.luau`).
- The delivered meshes were placed at all **282** sites straight from
  `AlpineOutpost.blend` (appended read-only, never saved) and rendered from the
  fitted concept camera and at player height: `v2-comparison-concept-vs-kit.png`,
  `v2-kit-player-views.png`. Every site resolved; bottom-centre pivots, -Z fronts
  and the lodge's asymmetric annex all land where the layout expects.
- **Bridge lanterns**: delivered at y 7.0, which is what the first version of
  this request asked for; the spec now uses 7.0 (a later edit here had said 6.7).
- **Firs**: a later edit of this request briefly asked for slender 12 x 30 firs.
  The delivered 15 x 26 / 11 x 18 / 6 x 10 are adopted as they are, so the kit
  validates now. V2's firs are about 2.6:1 against these 1.7:1; a slender
  re-export at the same names (12 x 30 x 12, 8 x 19 x 8, 4.5 x 10 x 4.5) would
  close that, and is **optional**: it needs a matching spec edit in the same
  change or the whole swap rejects.
- **Shelf rim caps** (your interpretation note): accepted. The four 0.7 x 0.7
  rear-corner caps sit where nobody needs to stand; the walk proxies stay flat
  at 8.5.
- **Look, against V2** (optional revision, your call): from the concept camera
  `FP_Alpine_Shelf_North` and `FP_Alpine_Shelf_South` read as flat white slabs
  with thin dark bands, and `FP_Alpine_Gorge_Rock` as a column of snowballs.
  V2 draws those three as layered, irregular slate with broad horizontal
  fractures, rounded overhanging snow on the edges and rock showing under it
  (crops "FA_Shelf_North", "FA_Shelf_South", "FA_Gorge_Rock"). Same bounds, same
  walk tops, same sockets; only the faces and snow shapes would change.

Still owed before anyone can see it in game: upload and capture in Studio (see
"Delivery checklist" at the end).

## Reconciliation with your in-progress kit

Your `assets/frostbite-peaks/alpine-v2/` (22 provisional `FP_Alpine_*` meshes,
manifest v2, colour/normal/roughness set) was already under way when this was
written. I read it and did not touch it. To save you rework:

- **Names:** your `FP_Alpine_*` names are adopted unchanged.
- **Kept exactly as you exported them (17):** Cliff_Tall, Cliff_Wide, Fir_Tall,
  Fir_Medium, Fir_Sapling, Frosted_Shrub, Grass, Woodpile, Crate, Barrel,
  Railing, Lantern_Post, Trail_Post, Signpost, Pennant, Snow_Rock, Snow_Drift.
  Several are placed at a uniform scale (table below). Please do not change
  their bounds now; the validator checks them to 0.005 studs. Two small socket
  additions are requested on the cliffs (`TopMount`).
- **Changed (3):** `FP_Alpine_Lodge`, `FP_Alpine_Bridge`, `FP_Alpine_Tent`. The
  measured V2 lodge is wide and shallow with an east annex, the measured bridge
  span is 34, and the V2 tent is smaller than 12 x 12. Details below.
- **New (8):** `FP_Alpine_Shelf_North`, `FP_Alpine_Shelf_South`,
  `FP_Alpine_Gorge_Rock`, `FP_Alpine_Cliff_Block`, `FP_Alpine_Snow_Rock_Small`,
  `FP_Alpine_Camp_Sled`, `FP_Alpine_Notice_Board`, `FP_Alpine_Terrace_Post`.
- **Not placed by the layout (2):** `FP_Alpine_Cliff_Shelf` and
  `FP_Alpine_Icicles`. Keep them in the bundle if you like; extra templates in
  the library are ignored. Nothing depends on them.
- **props-v1 is not reused.** Its faceted low-poly crate/rock/drift style no
  longer matches your textured kit, and your Crate/Snow_Rock/Snow_Drift cover
  those jobs. `assets/frostbite-peaks/props-v1` and `FrostbitePropTemplates.rbxm`
  stay exactly as they are.

Total for the layout: **28 meshes, 282 sites** (236 in the cell, 46 firs on the flanks outside the walls).

## Conventions (same as your manifest)

- 1 modelling unit = 1 stud. W = Roblox X, H = Roblox Y, D = Roblox Z.
- Pivot: **bottom-centre of the bounds** (x = 0, z = 0, y = 0 at the lowest point).
- Front: Roblox **-Z** (Blender +Y). Up: Roblox +Y (Blender +Z). Blender X = Roblox X.
- **+X is the viewer's LEFT** when standing in front of the asset looking at
  its front, in both Blender and Roblox. (Lodge: the annex is on the viewer's
  right, so it is at -X.)
- Every site places the mesh at `frame * GroundCF * CFrame.new(0, H/2, 0)`, so
  the bounds you export are exactly what lands in the map. Keep all geometry,
  snow and dressing inside them.
- Sockets are in the asset's own space, from the bottom-centre pivot, Roblox
  axes. Report the delivered values in `manifest.json`
  (`sockets_roblox_xyz_from_base`); I reconcile my anchors against the manifest,
  not against this document, once you deliver.
- All art is decorative. I own walking surfaces, collision, heights, effects,
  lights and placement. No colliders, scripts, particles, lights or cloth in
  the meshes. Glass that glows (windows, lanterns) is modelled as a recessed
  dark-amber frame; I place a warm pane and light at the socket.
- One library in Studio: `FrostbiteAlpineTemplates` (native MeshParts, captured
  preserving MeshSize and texture data). Bundle name `AlpineOutpostBundle`.
- The swap is all or nothing: until every one of the 28 names below validates,
  the region keeps its placeholders.

## Palette (sampled off V2; your material tiles already match most)

| Region | Target sRGB | Notes |
|---|---|---|
| Snow lit / mid / shadow | 236,240,246 / 218,226,238 / 182,198,222 | cool blue-violet shadows, warm-white highlights, thick rounded caps |
| Slate lit / mid / seam | 96,108,128 / 70,82,102 / 44,52,68 | broad horizontal fractures, no tall striped spires |
| Timber chestnut / dark / light | 122,72,44 / 78,46,30 / 160,104,62 | lodge logs, bridge planks, posts |
| Teal metal / trim | 36,112,112 / 24,78,82 | lodge roof under snow, gable trim, pennant, sled |
| Dressed stone | 126,128,134 | chimney, terrace posts |
| Fir foliage / deep | 30,74,62 / 18,48,44 | green must show through the snow |
| Golden grass | 210,164,84 | dry alpine grass |
| Tent canvas lit / shade | 240,128,60 / 173,98,29 | |
| Window / lantern amber | 255,196,110 | frames only, glow is runtime |

## Changed and new meshes — exact bounds and interior layout

### 1. `FP_Alpine_Lodge` — 40 W x 30 H x 24 D (changed from 30 x 27 x 31)

One site on the terrace deck, yaw 0, door facing south into the meadow.
Region bottom-centre (113.5, deck, 58.5). Reference crop "FA_Lodge".

Asset-local layout (Roblox axes, pivot bottom-centre):

| Part | X | Y | Z |
|---|---|---|---|
| Stone plinth | under walls | 0 .. 1.0 | under walls |
| Main block, stacked chestnut logs | -9.75 .. +17.75 (27.5) | floor 1.0, eaves 12.5 | -5.5 (front) .. +10.5 (16) |
| Gable roof, ridge along Z at X +4.0 | eaves -11.75 .. +19.75 | ridge 25.5, snow pillow to 27.5 | -7.5 .. +12.0 |
| Front porch deck | -6.5 .. +14.5 | top 1.0 | -11.0 .. -5.5 |
| Porch step (one tread) | +1.5 .. +6.5 | top 0.5 | -12.0 .. -11.0 |
| Porch posts + timber rail, entrance gap X +1.5 .. +6.5 | posts at -6.0, +1.5, +6.5, +14.0 | to ~9.5 | at -10.7 |
| Porch awning over the door, snow on top | -0.5 .. +8.5 | top ~11 | -8.5 .. -5.5 |
| East annex (lower wing) | -20.0 .. -9.75 | walls to 9, roof to 13.5 | -0.5 .. +11.5 |
| Stone chimney 3 x 3 on the west roof slope | centre +8.5 | top 30.0 | centre +7.5 |

Openings (glazing plane 0.05 behind the wall face; frames may stand proud):

| Socket | Position | Opening |
|---|---|---|
| `DoorBase` | (4.0, 1.0, -5.5) | closed timber door 4.5 W x 8.5 H, faces -Z |
| `PorchStep` | (4.0, 0.0, -12.0) | where the step meets the terrace |
| `WindowW` | (11.5, 6.75, -5.45) | 4.0 W x 4.5 H |
| `WindowE` | (-3.5, 6.75, -5.45) | 4.0 W x 4.5 H |
| `WindowGable` | (4.0, 16.5, -5.45) | 3.5 W x 3.0 H |
| `AnnexWindow` | (-14.75, 5.5, -0.45) | 3.0 W x 3.0 H |
| `PorchLanternW` / `PorchLanternE` | (14.0, 7.5, -10.7) / (-6.0, 7.5, -10.7) | small iron lantern cages hung on the end posts |
| `ChimneyTop` | (8.5, 30.0, 7.5) | open flue; smoke is a runtime emitter |

Look: deep chestnut logs with broad grain and iron fittings, teal metal roof
buried under a thick rounded snow pillow with soft overhangs, teal trim boards
on the gable edges, warm window frames, stone plinth and chimney. No barrels,
lanterns on posts, pennant or woodpile in the mesh: those are separate sites.
My collision: invisible boxes for the main block (to 12.5) and the annex (to 9),
a walkable porch deck at y 1.0 and the 0.5 step, low invisible rails. Keep the
porch floor and step exactly at those heights.

### 2. `FP_Alpine_Bridge` — 10 W x 7.5 H x 34 D (changed from 10 x 7 x 28)

Measured V2 span: shelf edge to shelf edge 30, plus 2 onto each landing.

- Deck centre line along Z, from Z -17 (south end, the -Z front) to +17 (north).
- Deck top at both ends **Y 1.5**; sags to **Y 0.3** at mid-span (parabolic);
  planks 0.3 thick so the lowest underside is Y 0.0. Deck 8 wide (X +-4).
- Four end posts 0.8 x 0.8 at X +-4.6, Z +-16.3, full height to Y 7.5.
- Two rope handrails per side at deck + 1.4 and deck + 3.0 following the sag,
  X +-4.4, with hanger ropes; snow dusting on planks and post caps.
- Lantern housings on top of the NW post (X +4.6, Z +16.3) and the SE post
  (X -4.6, Z -16.3), as V2 shows: those two posts stop at Y 5.9 and the iron
  cage runs Y 5.9 .. 7.5 with its glass on the socket.
- Sockets: `NorthDeck` (0, 1.5, 17.0), `SouthDeck` (0, 1.5, -17.0),
  `LanternNW` (4.6, 7.0, 16.3), `LanternSE` (-4.6, 7.0, -16.3) (as delivered).

Site: region bottom-centre (-115.75, shelf - 1.5, 39.0), yaw +5.9 degrees so +Z
points at the north landing. My collision is a segmented invisible deck along
the same sag plus low invisible kerbs; keep your deck on that curve.

### 3. `FP_Alpine_Shelf_North` — 42.5 W x 10 H x 23.5 D (new)

The L-shaped upper landing west and north of the bridge: shelf C (signpost,
rope rail) plus landing A (the bridge's north end). Region bottom-centre
(-104.75, floor, 50.25), yaw 0. Crop "FA_Shelf_North".

| Zone | X | Z | Rule |
|---|---|---|---|
| C walk zone | +21.25 .. -1.25 | -11.75 .. +11.75 | flat walk top at **Y 8.5** |
| A walk zone | -1.25 .. -21.25 | +3.75 .. +11.75 | flat walk top at **Y 8.5** |
| Gorge void | -1.25 .. -21.25 | -11.75 .. +3.75 | **nothing above Y 0.3** — the bridge and creek pass here |

- Faces: C's south and west faces (seen from the meadow) are layered slate with
  broad horizontal fractures and a thick overhanging snow cap. A's south face is
  where the bridge lands: keep it a clean vertical face at Z +3.75 for X -4.5 ..
  -14.0. A's north face meets the creek pool.
- Snow on the walk zones may rise at most 0.4 above Y 8.5 within 1.5 studs of
  their edges; rim lumps up to Y 10 only outside the walk zones.
- Sockets: `BridgeLanding` (-9.25, 8.5, 3.75), `Signpost` (16.75, 8.5, -10.25),
  `RailStart` (7.25, 8.5, -11.0).

### 4. `FP_Alpine_Shelf_South` — 29 W x 10 H x 15 D (new)

The south landing with the stair to the meadow. Region bottom-centre
(-121.5, floor, 16.5), yaw 0. Crop "FA_Shelf_South".

- Whole top is walkable, flat at **Y 8.5** (same edge-snow rule as above).
- South face at Z -7.5 must be flat and vertical for X -6.5 .. +6.5: my stone
  stair (14 risers, 12 wide) stands against it. Layered slate elsewhere; the west
  face (+X) overlooks the creek.
- Sockets: `StairTop` (0, 8.5, -7.5), `BridgeLanding` (4.2, 8.5, 7.5).

### 5. `FP_Alpine_Gorge_Rock` — 12 W x 11 H x 50 D (new)

The rock mass between the bridge's east rail and the east wall. Region
bottom-centre (-132.3, floor, 49.0), yaw 0. Its +X face (toward the bridge) is
the visible one; the -X face stands 0.2 off the wall and is never seen. Snow cap
on top, not walkable. Crop "FA_Gorge_Rock".

### 6. `FP_Alpine_Cliff_Block` — 14 W x 12 H x 12 D (new)

A medium layered slate block with a thick snow cap, the in-between size your
Tall and Wide do not cover. 8 sites, two at scale 1.2 and 1.3. `TopMount`
socket (0, 12, 0) with a flat 5 x 5 snow pad: one site carries a fir.

### 7. `FP_Alpine_Snow_Rock_Small` — 5 W x 3.5 H x 4.5 D (new)

A second, smaller boulder shape so the eight small rocks are not all a shrunk
Snow_Rock. Rounded slate, snow on top ~40% of the height.

### 8. `FP_Alpine_Tent` — 8 W x 6 H x 9 D (changed from 12 x 7 x 12)

Orange canvas A-frame, ridge along Z, door flap on the front (-Z) face, snow on
the ridge, guy ropes and pegs inside the bounds. `DoorBase` (0, 0, -4.5).
Placed on the terrace at yaw 40 so its door faces south-east, as V2 shows.

### 9. `FP_Alpine_Camp_Sled` — 5 W x 2 H x 3 D (new)

The teal sled beside the tent with a lashed bundle on it. Crop "FA_Tent / FA_Camp_Sled".

### 10. `FP_Alpine_Notice_Board` — 4 W x 5 H x 1 D (new)

The small teal board on two posts at the camp's north-east corner, blank face
(no fabricated text), a little snow roof. Front -Z.

### 11. `FP_Alpine_Terrace_Post` — 2 W x 7.5 H x 2 D (new)

Dressed-stone cheek post with a snowy cap: both sides of the terrace stair and
the terrace's front-east corner (base on the floor, rising 2 above the deck),
and at half scale beside the south shelf's stair foot.

## Kept exactly as exported

| Name | W x H x D | Sites | Scale range | Where |
|---|---|---|---|---|
| FP_Alpine_Cliff_Tall | 25 x 34 x 22 | 3 | 1.0 | NW corner behind the lodge; NE corner (yaw -90, fir on top); rear-right massif. Add `TopMount` (0, 34, 0) with a flat 5 x 5 pad |
| FP_Alpine_Cliff_Wide | 29 x 20 x 21 | 4 | 1.0 | behind the annex, rear-left, rear-right, left band. Add `TopMount` (0, 20, 0) |
| FP_Alpine_Snow_Rock | 11 x 6 x 9 | 11 | 0.8 .. 1.4 | nested boulders in every band |
| FP_Alpine_Snow_Drift | 13 x 2.5 x 8 | 33 | 0.8 .. 1.0 | wall bases and cluster feet; walk-through |
| FP_Alpine_Fir_Tall | 15 x 26 x 15 | 38 | 0.91 .. 1.23 | mature firs 23 .. 32 tall, 22 of them on the flanks |
| FP_Alpine_Fir_Medium | 11 x 18 x 11 | 44 | 0.63 .. 1.32 | 11 .. 24 tall, three on cliff tops |
| FP_Alpine_Fir_Sapling | 6 x 10 x 6 | 9 | 0.6 .. 1.25 | |
| FP_Alpine_Frosted_Shrub | 7 x 5 x 7 | 27 | 0.57 | walk-through |
| FP_Alpine_Grass | 6 x 4 x 6 | 51 | 0.55 | walk-through |
| FP_Alpine_Woodpile | 6 x 4 x 6 | 1 | 1.0 | terrace, west of the porch |
| FP_Alpine_Crate | 4.5 x 4.5 x 4.5 | 2 | 0.65 | camp, one stacked |
| FP_Alpine_Barrel | 3.5 x 4.5 x 3.5 | 4 | 0.65 | camp |
| FP_Alpine_Pennant | 5 x 11 x 1 | 2 | 0.85, 1.15 | camp corner; annex |
| FP_Alpine_Lantern_Post | 2.4 x 7 x 3 | 2 | 0.85 | camp, annex front |
| FP_Alpine_Trail_Post | 1 x 3.5 x 1 | 14 | 1.0 | lane stakes at x +-15.25 |
| FP_Alpine_Signpost | 6 x 7 x 1 | 1 | 0.8 | shelf C, facing south-west |
| FP_Alpine_Railing | 12 x 4.5 x 1 | 7 | 0.68 .. 0.8 | terrace east edge (5), shelf C rope rail (2) |

"Scale" is uniform on all three axes, declared per site as `AssetScale`; the
swap rejects any non-uniform ratio. If a texel density matters to you at the
extremes (fir 1.32, shrub 0.57), say so and I will split the size instead.

## Reserved runtime slots (optional art, not part of the kit validation)

- `FP_Alpine_Tex_IceCracks` — tileable 512 x 512 hairline-crack/bubble detail for
  the creek and the eight field ice patches (flush Glacier parts carry
  `TextureSlot = "FP_Alpine_Tex_IceCracks"`).
- `FP_Alpine_Decal_Tracks` — footprint-trail decal with alpha for the meadow
  tracks (flush parts carry `TextureSlot = "FP_Alpine_Decal_Tracks"`).

Both are placed today as plain flush parts; a texture only replaces their look.

## Where everything goes

- Plan: `v2-layout-plan.png`. Projection of every site back onto the concept:
  `v2-measured-layout-on-concept.png`. One crop per request:
  `v2-asset-reference-crops.png`.
- The exact site list (name, asset, region-local bottom-centre, yaw, scale,
  support) is generated from the build: `ALPINE-OUTPOST-V2-SITES.csv`. That file,
  not this summary, is authoritative for positions.

## Delivery checklist

1. The 28 names, bounds to 0.005, bottom-centre pivots, -Z front.
2. Sockets above reported in `manifest.json`.
3. Shelf walk tops at 8.5 and the lodge porch at 1.0 / step 0.5 exactly.
4. The Shelf_North gorge void kept empty.
5. Bundle `AlpineOutpostBundle.fbx`; I import in Studio Edit, capture
   `FrostbiteAlpineTemplates.rbxm`, reconcile sockets and re-run the checks.

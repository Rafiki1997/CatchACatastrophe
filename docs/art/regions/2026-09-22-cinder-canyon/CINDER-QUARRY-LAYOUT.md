# Cinder Canyon — Cinder Quarry layout

Concept: `cinder-canyon-v1-03-cinder-quarry.png` (option 03, approved 2026-09-22).
Contract: `CINDER-QUARRY-CLAUDE-HANDOFF.md` beside it — that document is the
authority on bounds, sites and division of work; this one records what was
built against it and what was measured out of the build.

Build: `build-refcam.png`, side by side with the concept in
`comparison-concept-vs-build.png`, landmarks in `build-mine-terrace.png`.
Implementation: `src/server/Map/CinderCanyon.luau`,
`src/server/Map/CinderQuarryAssetSpec.luau`, `src/server/Map/CinderQuarryProps.luau`.

**Astra's twelve meshes are not delivered.** Everything visible today is
placeholder geometry standing inside each asset's fixed bounds. Do not call the
region finished on these screenshots.

## How the concept was measured

The concept's four gate piers are engine geometry at known coordinates —
`MapBuilder.gatePier` puts them at x = ±22 on each cell edge, with a 15-stud
teal panel centred 11.5 above the ground on the south face. Fitting those four
panel centroids gives the concept's projection:

| | value |
|---|---|
| horizontal scale | 6.59 px per stud |
| pitch | 30.9° |
| vertical squash | 0.855 (the concept is not a physically consistent camera) |
| ground mapping | `u = 764 − 6.59·x`, `v = 493 − 2.895·z` |

`concept-measured-grid.png` is that fit drawn back over the concept: the z axis
lands on both gate lines exactly (px 203 → z +100.1, px 782 → z −99.9), so
**depth reads 1:1 against MapBuilder's 200-deep cell**.

The discrepancy it exposes is in width. The concept's own side walls sit at
**x = ±103** against MapBuilder's **±140** — the same 37-stud gap Splashwater Bay
found in its concept. Border features are therefore measured *in from the wall*
rather than scaled from the centre, and the extra 74 studs of width land where
the concept wants them: in open floor down the middle. The handoff's site table
already uses that convention (its terrace at X −124…−52 is the concept's
−84…−12 shifted out by 40), which is what made the table and the fit agree.

## Local frame

`RegionScenery` hands the module `CFrame.lookAt(centre, origin)`, so:

| local | world | concept |
|---|---|---|
| `+X` | west (`−X`) | image LEFT, the mine's side |
| `−Z` | south (`+Z`) | the Splashwater threshold, near edge |
| `+Z` | north (`−Z`) | the Frostbite gate, far edge |

Cell 280 × 200: `HALF_W, HALF_D = 140, 100`. Ground top face y = 0.30 and
nothing in this module raises it.

## What is where (local studs)

| feature | X | Z | note |
|---|---|---|---|
| mine (`CC_Quarry_Mine`) | 55 … 119 | 42 … 90 | bottom-centre (87, 0.30, 66), opening faces −Z |
| rail (`CC_Quarry_Rail`) | 81 … 93 | 24 … 50 | `Mine01 × DoorBase × CFrame.new(0, 0.02, −13)` |
| ore cart (`CC_Quarry_Cart`) | 81 … 92 | 27 … 41 | `Mine01 × DoorBase × CFrame.new(0, 1.05, −16)`, sits on the rail |
| terrace (`CC_Quarry_Terrace`) | −124 … −52 | 37 … 93 | bottom-centre (−88, 0.30, 65), four tiers, shelf top at y 25 |
| hoist (`CC_Quarry_Hoist`) | −85 … −65 | 74 … 90 | `Terrace01 × HoistBase`, fully on the shelf |
| lava cascade | −116 … −112 | 32 … 60 | three drops down the tier fronts, pool at (−114, 34) |
| mineral pockets | −104 … −64 | 36 … 53 | six clusters, leaning out of the three step faces |
| side rock band | \|X\| 100 … 138 | full depth | 18 `Mesa_Large`, 34 `Mesa_Low`, 10 of them stacked on a larger rock |
| planting | \|X\| 90 … 128, and both wall feet | — | 22 tall cacti, 20 round, 5 agave, 24 flower patches |
| clear centre lane | −12 … 12 | −100 … 100 | nothing solid, verified at knee height |

Walls, both gate piers, the barrier, the banner and the lamps belong to
`MapBuilder.buildChainWalls` / `buildRegion`, not to this module.

## Provisional sockets

Astra's `manifest.json` has not landed, so four socket frames are this module's
own guesses. Every site derived from one carries `SocketProvisional = true` and
`SocketName`, so they can be found and replaced without reading the source.

| socket | provisional value (asset-local) | what it drives |
|---|---|---|
| `Mine01/DoorBase` | `CFrame.new(0, 0, −16)` | the rail and the cart, per the handoff's table |
| `Terrace01/HoistBase` | `CFrame.new(13, 25, 17)` | the hoist |
| `Terrace01` lava lip | `CFrame.new(−26, 25, −6)` | the channel across the top shelf |
| `Terrace01` lava foot | `CFrame.new(−26, 0, −31)` | the rock-framed pocket |

## Changes outside the region module

| file | change | why |
|---|---|---|
| `Config/Regions.luau` | `cinder_canyon.groundColor` → `rgb(238, 134, 86)` | the concept's floor is warm orange, sampled at (247, 142, 90); the old value was dark brown under a separate raised skin |
| `MapBuilder.luau` | `GROUND_MATERIAL[Heat]` Basalt → Sandstone | a quarry floor, not the old ravine's basalt |
| `MapBuilder.luau` | `OWN_PERIMETER[Heat] = true` | this module lays its own border band; the generic biome shoulders fought it |
| `MapBuilder.luau` | `TRAIL_SAND` generalised to `TRAIL_BLEND`, Heat added at width 24 | the concept draws no road; paving it kerbed the floor with a grey runway |
| `RegionScenery.luau` | the Heat branch now returns the layout | the region reports its own field rectangle and keep-outs |

## Measured out of the headless build

`lune run tools/world_harness.luau <out.json>`, then the scratch scripts
`openfloor.py` and `sightlines.py`; site and swap semantics by
`lune run tools/verify_cinder_placement.luau` (report in
`build/cinder-placement-validation.json`).

- **9,279 parts** in the whole map; the quarry's share is about 1,900.
- **Open dry floor 64.0%** of the raw 280 × 200 cell, **66.6%** of the cell
  inside MapBuilder's own wall and gate footprint, against the handoff's 65%
  target. The playable middle (160 × 140 around the centre) is **92.2%** open.
  The floor the two fixed landmarks take — 64 × 48 and 72 × 56 — is 12.7% of
  the cell on its own.
- **Centre lane:** no obstruction in X −12…12 at knee height over the whole
  200-stud run. The 48 blocked square studs the raster reports are the two
  region barriers standing in the divider plane by design.
- **Gate throats clear** and **nothing crosses the cell wall** — both asserted
  in the verifier against every part's rotated bounding box.
- **Creature homes:** 6,000 `pickHome` samples replayed against the built
  solids. 4,581 survive the keep-outs and **0 land inside solid geometry**.
- **Floor height preserved:** the only geometry standing proud of y = 0.30 in
  the open field is loose rubble under 1.5 studs, walk-through. Cracks and dust
  patches are 0.05 or less. No new ground skin, so the Heat telegraph is drawn
  on the same floor it always was.
- **Asset sites:** 136 across all twelve meshes, every placeholder inside its
  declared bounds to within 0.75 studs, no colliding part under any site, and
  59 separate invisible collision proxies carrying the containment.
- **Swap semantics:** a partial kit, a 100× scale and a solid placeholder are
  each refused with the blockout intact; the complete kit places all 136 at
  their exact bottom frames, leaves every proxy and all 8 effect lights
  untouched, and is idempotent. 1,723 assertions in total.

## Decisions worth keeping

| Decision | Why |
|---|---|
| Placeholder art is authored in each asset's own local space | It lands correctly whatever the site's yaw, and it can be measured against the bounds Astra models to — the check that caught the whole border band being built at the region origin |
| Collision is invisible proxies in `Boundary`, never site art | The handoff requires it, and it means the swap can destroy every placeholder without touching what keeps a player out of a rock |
| Mesa proxies are 0.74 of the asset box | A faceted rock inscribed in those bounds has a footprint well inside them; a proxy at the corners is collision against air *and* open floor the region never gets back — worth 3% of the cell |
| Rocks are stacked, not enlarged | The concept's border rises well above the wall; the kit's two rocks are fixed sizes meant to be reused, so height comes from piling them |
| No stacked rock within ~55 studs of the lava pocket | A 33-stud pile anywhere south of it stands in the sightline and hides the one thing that makes the quarry read as hot. Found by ray-testing the build, not by eye |
| The lava runs down the tier *fronts* | Modelled at the terrace's own centreline it sat inside the rock and was invisible in the first render |
| The foreground fringe is planting, not more rock | A cactus costs no open floor, and the concept's south edge is mostly cactus, agave and flowers anyway |

## Known gaps

- **The twelve meshes do not exist yet.** Every rock, cactus, crate, the mine,
  the terrace, the hoist, the rail and the cart are box-and-ball stand-ins. The
  concept's faceted, rounded rock is the single largest visual difference and it
  closes when `CinderQuarryTemplates` is imported.
- **Four sockets are provisional** (above). The rail and cart hang off
  `DoorBase`, so a delivered socket moves them correctly without further edits;
  the hoist and both lava anchors will need their frames replaced.
- **The lava pool is not visible from avatar height** — it is a flat pool inside
  a rock kerb, so from eye level you see the cascade and the glow but not the
  surface. The concept shows it from an elevated camera. Judge it in Studio
  before changing the kerb.
- **Open floor is 64.0% of the raw cell against a 65% target.** With the two
  landmark footprints fixed by the contract and MapBuilder's wall taking 3.8%,
  closing the last point means a thinner border band than the concept draws.
  66.6% inside the enclosure is the number that reflects the scenery's own cost.
- **Not yet seen in Studio.** Everything above is headless: a Lune build, a
  rasterised render from a fitted camera, and geometric ray tests. The
  in-Studio walk, the live Heat telegraph and both gate states are untested.

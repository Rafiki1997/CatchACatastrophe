# Splashwater Bay — Tropical Tidepools layout

Concept: `concept-tropical-tidepools.png` (option 03, approved 2026-09-21).
Build: `build-refcam.png`, side by side in `comparison-concept-vs-build.png`.
Implementation: `src/server/Map/SplashwaterBay.luau`.

## How the concept was measured

The concept's four gate piers are a known rectangle on the ground — 44 studs
apart (`GATE_W`) at each end of a 200-deep cell — so they fix a ground
homography that reads every flat feature back in studs. `concept-measured-grid.png`
is that fit drawn back over the concept: the z axis lands on both wall bases
exactly.

The one real discrepancy the fit exposed: **the concept draws a ~206-wide cell
against MapBuilder's 280.** Its gate is about 36% wider relative to the region
than the engine's. `CELL_W` is shared with the approved Gusty Gardens and the
other four regions, so the cell wins and the concept's composition is stretched
onto it: measured x is scaled by 140/103, z is taken 1:1. The extra width lands
where the concept wants it — in open sand down the middle.

## Local frame

`RegionScenery` hands the module `CFrame.lookAt(centre, origin)`, so:

| local | world | concept |
|---|---|---|
| `+X` | west (`-X`) | image LEFT, the grotto's side |
| `-Z` | south (`+Z`) | the Gusty Gardens threshold, near edge |
| `+Z` | north (`-Z`) | the Cinder Canyon gate, far edge |

Cell is 280 × 200: `HALF_W, HALF_D = 140, 100`. Ground top face is y = 0.3.

## What is where (local studs)

| feature | x | z | note |
|---|---|---|---|
| west tide pool | +59 … +121 | −18 … +88 | 7 discs, widest at z +52…+64 |
| east tide pool | −53 … −112 | −25 … +83 | 8 discs, widest at z +52 |
| grotto (dome, cave, fall) | +52 … +117 | +42 … +95 | crown 26.6 tall, mouth faces south |
| cascade (3 tiers, 2 drops) | −64 … −124 | +48 … +98 | head 42.2 tall |
| planting band | within 36 of each wall | — | three ranks, gate throats kept clear |
| hero palms | ±74…±82, ±123…±126 | −92, ±36 | either side of the south threshold, and mid-wall |

Walls, piers, both gates, the barrier and the banner sign belong to
`MapBuilder.buildChainWalls` / `buildRegion`, not to this module.

## Measured out of the headless build

`lune run tools/world_harness.luau <out.json>`, then `scratchpad/sb/verify.py`:

- **8,888 parts** in the whole map; 2,274 of them are the bay.
- **Dry, walkable sand: 72.9%** of the cell. Open water 19.8%, solid props 15.5%
  (mostly the perimeter band, which is outside the capture field).
- **Wall crossings below the wall top: 0 from this module.** The 11 reported are
  MapBuilder's own gate assembly standing in the divider plane by design.
- **Creature homes:** 4,000 `pickHome` samples replayed against the built water —
  1.40% land in water, 0.03% inside a solid prop. `clearOf` pushes roamers to the
  keep-out circle edge, which is dry sand in every case.
- **Route:** the 22-wide centre lane and both gate throats carry no solid
  obstruction except the region barriers themselves.

## Decisions worth keeping

| Decision | Why |
|---|---|
| Pools are chains of flat discs | A disc is the one primitive whose cross-section is not clamped to a square, so overlapping circles give the concept's scalloped outline |
| `TRAIL_SAND` matches `groundColor` exactly | The concept shows no change of surface; a paved strip kerbed the beach with a grey runway |
| `OWN_PERIMETER[Water] = true` | This module lays its own planting; the generic biome dunes fought it |
| Water swaps scan the whole region | The bay files boulders under `Shore` and inside the landmark models, not under `Landmarks` |

## Known gaps

- The sand renders paler than the concept's warm tan. Part renderer ambient,
  part `groundColor`; judge it in Studio before changing the colour again.
- The rocks are chunky primitives where the concept has faceted meshes, and the
  grotto's mouth is smaller than the concept's arch. Both close when Astra's kit
  lands — see `SPLASHWATER-ASSET-REQUEST.md`.
- **Not yet seen in Studio.** Everything above is headless.

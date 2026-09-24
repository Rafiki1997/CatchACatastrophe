# Frostbite Peaks — five design options

Status: awaiting selection. Nothing in the game changed: no Luau, no Studio, no Rojo sync, no assets.
Made 2026-09-22 by building each option in Blender 5.1 at the region's real size and rendering it.
They are **not** image-generation paintings like the earlier rounds, so every landmark in them
already has coordinates in the region's own frame.

Overview of all five: `frostbite-peaks-v1-overview.png`

## Options

- **01 / IGLOO HOLLOW** — Closest to the V4 world's Frostbite: two igloo clusters in the rear corners,
  snowy firs behind them, blue ice crystals at the front corners, a fire pit, a sled and a snowman.
  Image: `frostbite-peaks-v1-01-igloo-hollow.png`

- **02 / ALPINE OUTPOST** — The Alpine Expedition identity approved on 2026-09-20, refitted to the
  rectangle: a snow-capped rock ridge along the rear wall, a log expedition hut on a raised terrace
  (rear-left) with a tent, woodpile and flag, and a rope bridge between two rock outcrops on the right.
  Image: `frostbite-peaks-v1-02-alpine-outpost.png`

- **03 / GLACIER FALLS** — Natural ice: a blue glacier cliff in the rear-right corner with a frozen
  waterfall pouring into a frozen pool, a natural ice arch on the left, ice boulders through the bands.
  Image: `frostbite-peaks-v1-03-glacier-falls.png`

- **04 / CRYSTAL GROTTO** — Magical: violet and cyan crystal spires breaking out of indigo slate
  (rear-left), a glowing ice grotto (rear-right), silvery firs, and crystal-tipped posts along the lane.
  Image: `frostbite-peaks-v1-04-crystal-grotto.png`

- **05 / COLDSNOUT'S CROWN** — Lore: a carved statue of King Coldsnout, the region's Legendary mammoth,
  in his glacier crown on a stepped plinth (rear-left); two ivory tusk arches over a frost brazier
  (right); a ring of rune stones in the front-left corner.
  Image: `frostbite-peaks-v1-05-coldsnouts-crown.png`

## What all five share

- **The real cell, not an approximation.** 280 × 200, with MapBuilder's walls, piers, dividers, both
  44-wide gates and their piers, Thunderworks' locked barrier and lock, both banners and the region
  lamps, all at MapBuilder's own coordinates (`buildChainWalls`, `gatePier`, `wall`, `lamp`,
  `buildRegion`). Camera, light and creature spots are identical across the five.
- **The same envelope the rebuilt regions use.** Open field |x| < 92, |y| < 70 (Cinder measured its
  field as 92 × 72 half-extents); a 24-wide lane clear from gate to gate; |x| < 36 kept open in front
  of both gates; landmarks only in the side bands and the rear corners.
- **Measured, not eyeballed.** Every solid object's footprint is rasterised on a 1-stud grid, with firs
  counted by their whole canopy and not just the trunk:

  | Option | Interior clear | Open field clear | Lane cells blocked |
  |---|---|---|---|
  | 01 Igloo Hollow | 79.2% | 99.8% | 0 |
  | 02 Alpine Outpost | 77.8% | 99.9% | 0 |
  | 03 Glacier Falls | 83.1% | 99.9% | 0 |
  | 04 Crystal Grotto | 84.8% | 99.9% | 0 |
  | 05 Coldsnout's Crown | 83.2% | 99.8% | 0 |

  Raw numbers: `src/measurements/option-N.json`.
- **The game's own sign text.** The banners read THUNDERWORKS / 300K COINS (north) and
  FROSTBITE PEAKS / 75K COINS (south), which is what `Format.abbreviate` produces. The captions say
  75,000 to match the earlier rounds.
- The south gate is drawn unlocked with no barrier, as in the earlier rounds.

## Read before choosing: art direction, not decisions

- **Creatures** are placeholders of the four real Frost species (two Flurry Ferrets, a Slush Sloth,
  two Blizzard Bison, King Coldsnout), in the same six spots in every option, **enlarged about 3×** so
  they read at this distance. No change to population or models is implied.
- **Outside the walls** is drawn snowed over with firs. Today that strip is shared grass with the
  ChainFlanks trees; re-skinning it is a separate choice.
- **Snow on the wall caps, piers and lanterns** would be decoration owned by the Frostbite module
  (CanCollide off), not a MapBuilder change.
- **The lane** is packed snow blended into the floor, as Water and Heat already do with `TRAIL_BLEND`.
  Frost currently gets the default paved trail with region-coloured kerbs. Switching is one
  `TRAIL_BLEND` entry if you want it.
- **Ice is slippery in Roblox** (Ice 0.02, Glacier 0.05 friction against Snow's 0.3). The frozen pool
  (03), the frozen creek (02) and every ice landmark are decorative pockets over collision proxies,
  which is how the current `FrostbitePeaks.luau` already treats ice.
- **The low west sun** is there so forms read in the mockup. It is not a proposal to change lighting.
- The option-02 hut terrace (top 6) and outcrops (top 10), and the option-05 plinth (7.2), are
  walkable heights that need stairs and collision in the build. The renders show the stairs.

## New hero assets each option would ask of Astra

Every option reuses the existing `assets/frostbite-peaks/props-v1` kit for its border bands: snow rocks
wide and tall, fir tree and sapling, snow drift, icicle cluster, supply crate, rope coil.

| Option | New pieces |
|---|---|
| 01 | Igloo in three sizes, ice-crystal cluster, snowman, fire pit, sled, ice-block stack |
| 02 | Log expedition hut, rope-bridge section, tent, woodpile, flagpole, railing, trail post, signpost, large strata ridge rocks, rock shelf |
| 03 | Glacier column kit, frozen waterfall, frozen pool with rim, ice arch, ice boulder |
| 04 | Crystal spire clusters (violet and cyan, three sizes), ice grotto shell, crystal post, indigo rock set, silver fir |
| 05 | King Coldsnout statue, stepped plinth, tusk arch, frost brazier, rune stone, lane marker, glacier chunk columns |

## After approval

Write the Claude handoff straight from the chosen option's builder. Coordinates for 01 are in
`src/fb_options.py`; for 02–05 they are in `src/fb_designs.py`. No camera fit is needed, because the
render already works in the cell's own coordinates: +X east, +Y north, which is Roblox −Z. Then
Astra models the new pieces and Claude integrates them, as agreed for the earlier regions.

## Reproduce

```
bash src/render_all.sh            # all five + overview, 256 samples, rendered at 2304 x 1536
bash src/render_all.sh 40 0.5     # quick preview pass
```

Needs Blender 5.1 (it defaults to `C:/Program Files/Blender Foundation/Blender 5.1/blender.exe`;
override with `BLENDER=`) and Python with Pillow for `compose_frostbite.py`. A single option renders
with `blender -b --factory-startup -P src/render_frostbite.py -- --option 3 --out o3.png`. Add
`--camera top` for a straight-down plan of the same scene.

## References

- `C:/Users/rahul/orca/workspaces/Catch-a-Catastrophe/Catch-A-Catastrophe/docs/art/world/2026-09-21-linear-regions/world-v4-lobby-services.png`, the V4 world: Frostbite with igloos, firs and crystals
- `../2026-09-20-concepts/FROSTBITE-ALTERNATIVES.md`, the first Frostbite round (V2 Alpine Expedition approved)
- `../2026-09-22-cinder-canyon/V1_OPTIONS_AND_PROMPTS.md`, the neighbouring round's format and envelope

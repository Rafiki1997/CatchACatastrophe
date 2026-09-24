# Gusty Gardens — meadow kit v1 (hero review)

2026-09-23. Second Gusty restyle batch, after the integrated broadleaf family. It has one hero each for the four families still on blockout art: the perimeter **pine**, the **shrub**, the **moss-rock group** and the **daisy flower bed**. Each is built to the approved broadleaf's standard: modeled leaves and needles, ridged bark, sculpted masses and restrained grain. They share the broadleaf's bark and leaf materials, so they read as one family.

**Status: source art for review.** Not approved, optimized, exported or integrated. Nothing in `src/` has changed.

![Before / after](meadow-kit-before-after.png)

[Lineup beside approved broadleaf A](meadow-kit-lineup.png) · [Player-scale meadow](meadow-kit-player-scale.png) · [Editable source](GustyMeadowKit.blend) · [Geometry report](geometry-report.json)

| Hero | Replaces (GustyGardens.luau) | Sites | Built as | W × H × D studs (blockout envelope) | Source tris | Close-ups |
| --- | --- | ---: | --- | --- | ---: | --- |
| Meadow Pine | `pineTree`: PineTrunk + 6 PineTier + PineCrown | 17 | Powder Fir construction without snow: 7 tiers, 43 boughs, feathered needle sprays over small hidden supports, a brighter upper cover and ridged bark with root flare | 10.5 × 18.2 × 10.9 (11.2 × 18.2 × 11.2) | 224,166 | [3/4](pine-three-quarter.png) · [detail](pine-detail.png) |
| Meadow Shrub | `shrub`: 3 MeadowShrub balls | 31 | The same three lobes, filled with about 1,900 shingled broadleaf leaves in two layers, a dark interior and woody stems | 9.9 × 5.9 × 7.8 (9.4 × 5.2 × 6.9) | 47,868 | [3/4](shrub-three-quarter.png) · [detail](shrub-detail.png) |
| Moss Rock Group | `gardenRock`: 3 GardenStone slabs | 19 | Three chunky boulders at the slab offsets: broad planes, soft edges and two strata. Moss cushions sit only on top faces, with 5 pebbles and 5 grass tufts | 8.4 × 3.7 × 7.4 (≈8.9 × 4.5 × 8.2) | 63,694 | [3/4](rock-three-quarter.png) · [detail](rock-detail.png) |
| Daisy Bed | `flowerBed`: bed ball + 7 stalk/head/eye | 62 | A leafy mound and 7 modeled daisies at the blockout radii and heights: two petal layers, a domed floret centre and stalk leaves. Every sixth daisy is pink, as before | 6.7 × 3.3 × 5.5 (6.7 × 2.75 × 6.7) | 21,102 | [3/4](flower-three-quarter.png) · [detail](flower-detail.png) |

All components are closed meshes, with zero non-manifold edges and zero degenerate faces (`geometry-report.json`). Each asset keeps its root socket at local zero, on the ground at the trunk or group centre. Roblox `(x,y,z)` = Blender `(x,z,-y)`.

## Known limits and open review points

- **Envelope:** the shrub is about 0.5 stud wider and 0.7 taller than its blockout, from its leaf tips. Tilted daisy heads add 0.6 of height. Both stay inside the planting band, but the placement verifier should allow for it or the export should be scaled to fit.
- **The daisy centres are no longer Neon.** The blockout eyes glow; the handoff asks for restrained yellow centres. Say so if you want the glow back.
- **Triangle budget:** source counts are not runtime budgets. The flower bed has 62 sites and will need the heaviest cut; a target of about 6–8k export triangles per bed is planned. Pine and rock sources are also well over the per-component pipeline limit of 20,000 and need splitting or decimation during export.
- **Variants:** only heroes so far. After approval: pine B/C (broad and upright), two further shrub and rock silhouettes, and a daisy-bed variant or two.
- These are offline Blender renders. They are not Studio evidence.

## Reproduce

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.1/blender.exe' -b --python tools/blender/create_gusty_meadow_kit.py -- --rebuild
# --no-render for source only; --only lineup,before,pine,shrub,rock,flower,vignette to re-render a subset
```

The builder appends the approved broadleaf A from `../broadleaf-family-v1/GustyBroadleafFamily.blend` for comparison and never writes to it. `meadow-kit-before-after.png` stacks the `before` and `lineup` renders, cropped identically.

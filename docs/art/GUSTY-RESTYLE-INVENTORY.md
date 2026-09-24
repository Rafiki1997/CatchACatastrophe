# First area restyle — Gusty Gardens

2026-09-23. Scope: first progression region (`gusty_gardens`, Wind, index 1), preserving the current layout and gameplay. Art benchmark: [asset restyle handoff](ASSET-RESTYLE-HANDOFF.md), approved source Powder Firs and their actual lineup/detail/export renders. The approved `.blend` was opened and its nine source meshes inspected in Blender 5.1.2.

**Latest update:** Rahul approved the thinner-leaf tree, then uploaded the bundle. The [three-tree broadleaf family](../../assets/gusty-gardens/broadleaf-family-v1/README.md) is modeled, optimized, exported and **integrated at all35 perimeter sites**. Captured nine native templates with measured100x scale and180-degree mesh yaw correction. Actual Play has105 MeshParts, A12/B12/C11 and35 retained collision proxies; all105 placed mesh preloads succeeded. The ledger below records the original inventory; other families remain unapproved/unreplaced.

## Current evidence and placement contract

- Authority for current geometry: `src/server/Map/GustyGardens.luau`, `GardenBayProps.luau`, `MapBuilder.luau`, and `docs/CONTRACTS.md`. Some descriptive contract prose still describes Gusty's older arbor layout; the current builder has two windmills and a rectangular cell.
- Fresh headless whole-map build: 2,124 parts under `Workspace.Map.Regions.gusty_gardens`. [Full region snapshot](../../assets/gusty-gardens/broadleaf-v2/region-inventory.json) records names, full paths, sizes, world transforms, material, color and collision. Counts below refer to this **source fallback build**. The harness rejected the native Gusty library at `GG_Moss_Rock_Wide`, so these are not evidence of current native mesh counts or asset loading in Studio.
- Studio was read only: Edit mode; no generated `gusty_gardens` Model was present. No Play session was started.
- Cell is 280 × 200, local -Z south/entrance, +Z north/Splashwater, +X world west. Keep the 24-stud center road, gate planting exclusion `abs(x)<21`, open field half extents `(96,56)` and both 28-stud windmill keep-out radii. Creature road exclusion is 17 studs from the centerline.
- Most decorative parts are noncolliding. Preserve the actual colliding trunks, first rock slabs, mill body/plinth/footing/steps, crates and barrel as separate proxies. No new interaction, rig or creature changes are part of this art batch.

## Asset ledger

The broadleaf thinner-leaf treatment is **approved / integrated / awaiting user post-import review**. Other new treatments are **unapproved / not replaced**. Dimensions below use W × H × D in studs at base scale; exact original per-instance transforms are in the snapshot. Counts distinguish assemblies from their generated parts.

| Asset family / source IDs | Current assemblies | Dimensions, frame and anchors | Collision, animation and replacement constraints | Status |
| --- | ---: | --- | --- | --- |
| Broadleaf / `MeadowTreeTrunk`, `MeadowTreeLobe`; `bigTree` | 35 trees, 6 crown lobes each | Root `(0,0,0)` in site frame. Envelope x [-9.8,10.2], y [-0.05,17.98], z [-9.4,9.5]; 20 × 18.03 × 18.9 before site scale. Trunk center `(0,4.2*s,0)`, size `2.6 × 8.5 × 2.6` times s | Trunk solid, non-queryable; crown decorative. Static. Preserve each root and rotation; recover s from trunk size. Current sites have no individual Model | [Hero source/render](../../assets/gusty-gardens/broadleaf-v2/README.md) ready for review |
| Pine / `PineTrunk`, `PineTier`, `PineCrown`; `pineTree` | 17 trees, 6 tiers each | Root site frame. Base envelope 11.2 × 18.2 × 11.2 times s; trunk center y=2.9*s | Solid trunk; static decorative crown. Preserve mixed treeline rhythm; no snow in Gusty | [Hero v1](../../assets/gusty-gardens/meadow-kit-v1/README.md) ready for review |
| Shrub / `MeadowShrub`; `shrub` | 31 groups, 3 lobes each | Base d=6.6*s; positions `(0,.36d,0)`, `(.44d,.30d,.22d)`, `(-.36d,.26d,-.2d)`; sizes `(d,.84d,.96d)`, `(.68d,.62d,.68d)`, `(.56d,.52d,.56d)` | Noncolliding; static current procedural shrubs. Preserve planting band and gate clearance | [Hero v1](../../assets/gusty-gardens/meadow-kit-v1/README.md) ready for review |
| Moss rock group / `GardenStone`; `gardenRock` | 19 groups / 57 slabs | Site root; three scaled/rotated slabs: 5.6×4.4×5, 4.2×3.4×4.6, 3.4×2.8×3.8. Exact offsets/rotations in builder/snapshot | First slab solid, non-queryable. Retain proxy while remodeling the whole group, not each slab as a new giant boulder | [Hero v1](../../assets/gusty-gardens/meadow-kit-v1/README.md) ready for review |
| Flower bed / `FlowerBed`, `FlowerStalk`, `FlowerHead`, `FlowerEye`; `flowerBed` | 62 groups / 434 flowers | Root site frame; bed 4.2×1.8×4 at y=.7. Seven flower centers at radii .9/1.6/2.3 and y=1.7/2.1/2.5; heads diameter 2.1 | Decorative, no collision. Keep white/pink identity and restrained yellow centers. Distinct from legacy Daisy/Bluebell meshes | [Hero v1](../../assets/gusty-gardens/meadow-kit-v1/README.md) ready for review |
| Grass / `GrassTuft`; `tuft` | 9 groups / 27 blades | Three blades size .34×(2.4*s)×.34 with the current tilt and base offsets | Noncolliding, retain sparse meadow distribution and creature visibility | Inventoried |
| Windmill house / `Windmill` and `Mill*`; `windmill` | 2 houses | Roots `(±76,0,18)`; plinth diameter22.4 H1.5; stacked body diameters21.6/20.2/18.8; roof/chimney top36.6. Door front local -Z; door center `(0,7.6,-11.4)`; steps `(0,1.2,-13.4)` / `(0,.55,-16)` | Retain body/support/step collision; no existing door prompt. Keep approach, two 28-radius keep-outs and sightlines. Separate static house from moving rotor | Inventoried |
| Mill rotor / `MillHub*`, `MillSail*` | 2 rotors / 4 sails each | Hub socket `(0,22.6,-12.6)` in mill frame. Spar6.6×18×.7 centered11.6 radially; panels5.3×16.6×.6 | Sail frame/panel/bars use `SceneryMotion`, Spin .2, phase0 around existing hub; keep restricted motion metadata and swept clearance | Inventoried |
| Crate / `MeadowCrate`, `MeadowCrateLid`, `MeadowCrateBand` | 2 | Mill-relative `(-side*17.5,0,-7)` yaw side*.35. Overall5.8×5.575×5.8; root at ground | Body solid; lid and bands decorative. Preserve keep-outs | Inventoried |
| Barrel / `MeadowBarrel`, bands and top | 1 | Root `(110,0,-34)` yaw .4; overall5.1×4.9×5.1 | Body solid. Keep wall-side placement | Inventoried |
| Path flagstone / `PathStone` | 6 | Diameters5.7/6.6/4.8 repeated; H.22, centers y=.5; exact six placements in snapshot | Decorative walking-surface skin; do not obstruct center lane | Inventoried |
| Road shoulder / `PathEdge`, apron / `MillApron` | 34 shoulders / 2 aprons | Road half-width12; shoulders overlap at11.8 spacing; aprons diameter16, mill-relative `(0,.36,-19.5)` | Surface treatment; keep continuous route and floor heights. Prefer textures for fine grass/soil variation | Inventoried |
| Shared chain walls, gate/sign, lanterns, ground | Shared MapBuilder/RegionSign system | Full cell boundary owned by MapBuilder; region has Gate, Entrance, GateSign, sign frame and two lamp posts | Shared across regions; keep text/UI, gating and navigation. Inventory common-source consumers before future remodeling | Deferred shared kit |
| Creatures, wind effects, UI | Separate runtime systems | First-region four-species identities and runtime effects remain authoritative | Separate rig/animation pipeline; functional UI/effects stay in engine | Out of static-art batch |

## Existing mesh kit and known integration mismatch

`assets/gusty-gardens/props-v1` contains eight existing authored meshes: Moss Rock Wide/Tall, Daisy Cluster, Bluebell Cluster, Fern, Meadow Shrub, Windbent Tree, Flower Planter. Their measured source dimensions and triangles remain in its `manifest.json`. Native source library is `src/server/Map/GustyPropTemplates.rbxm`.

`GardenBayProps.apply(...,"Wind")` is the sole placement consumer of these eight names. It validates the entire kit, but scans **only direct children of Landmarks** for `GardenStone` / `FlowerBed` / old tree names. Today's builder parents rock and flower parts under **Boundary** and uses `MeadowTreeTrunk/Lobe`, so that scan cannot replace them. Once its native library passes, it still places five trees, five ferns, four shrubs and two planters at the old fixed coordinates. They are additional legacy placements, not replacements for the 35 current perimeter trees. This also explains why the old contract's 43-mesh Gusty count is not a reliable inventory for today's layout.

The same module also serves Splashwater's separate eight-mesh kit. Future fixes must preserve that consumer. Shared ImportStaging/native-capture tools, test assertions and any library validation also need coordinated updates when adding a new kit; do not rename existing assets opportunistically.

The builder's linked wider Gusty concept path (`docs/art/world/2026-09-21-linear-regions/gusty-gardens/gusty-gardens-v2-wider.png`) is absent in this checkout. This review uses measured current source geometry for placement and the available approved Powder Fir files for quality; it does not claim to have inspected that missing concept.

## Review and next batches

1. Review the actual broadleaf hero and matched Powder Fir comparison. Lock leaf size/density, crown shape and bark treatment.
2. Make meaningful broadleaf siblings and a meadow pine, then optimize/bake and independently round-trip exports. No multiplying this unreviewed design across the map.
3. Rocks and low planting, followed by the crate/barrel timber treatment.
4. Windmill hero with separate animated rotor, then remaining path/shared-boundary art.

Before implementation, introduce explicit site metadata or a verified grouping rule for flat perimeter assemblies, preserve collision proxies, validate the full kit and all sites, and remove legacy interior art only with an agreed replacement plan. Preserve component-center offsets and root sockets. Capture native uploaded meshes and inspect actual Studio placement, content loading, gameplay and performance before claiming integration.

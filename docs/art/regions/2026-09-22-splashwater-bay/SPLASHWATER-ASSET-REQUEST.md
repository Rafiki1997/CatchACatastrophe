# Splashwater Bay — asset request for Astra

Concept: `concept-tropical-tidepools.png`. Built stand-ins: `build-refcam.png`.

Eight new meshes. Everything else in the bay reuses the existing
`SplashwaterPropTemplates` kit (`SB_Coastal_Rock_Wide` / `_Tall`,
`SB_Shell_Cluster`, `SB_Starfish`, `SB_Driftwood`, `SB_Harbor_Barrel`), which is
already wired and needs nothing new.

`SB_Rope_Bollard` and `SB_Marker_Buoy` are now unplaced — the boardwalk and the
moorings they dressed went with the lighthouse concept. They stay in the kit
contract so the bundle still validates; no action needed.

## Shared conventions

- **Pivot:** base centre, sitting on y = 0. The placer adds half the height.
- **Forward:** local `-Z`. Every asset is placed facing the beach.
- **Scale:** authored at the sizes below, in studs. The placer rescales to the
  stand-in's own bounds, so proportions matter more than absolute size.
- **Style:** chunky low-poly, flat-shaded, large facets. Match the faceted grey
  rock and the saturated leaf greens in the concept, not a realistic material.
- **Collision:** supply one simple convex hull per asset. Water surfaces, foam
  and fronds must be separate objects from the stone so they can be
  non-collidable and, later, animated without moving the rock.

## The eight

| # | Name | Bounds (W × D × H) | What it is |
|---|---|---|---|
| 1 | `SB_Tidepool_Grotto` | 65 × 53 × 27 | The rear-west landmark: a hollow dome of faceted grey boulders. A **21 wide × 15 tall** arched mouth in the south face, genuinely recessed — the concept reads the dark interior as depth. A notched sill beside the mouth for the fall to leave from. Crown a little behind centre. |
| 2 | `SB_Cascade_Rocks` | 60 × 50 × 42 | The rear-east landmark: three stepped tiers, each set back from the one below, with the south face cut away so water has something to fall down. A **16-wide ledge** at ~17 studs for the mid pool, and a broader lip at ~32. |
| 3 | `SB_Palm_Tall` | 26 × 26 × 33 | Curved segmented trunk, 7 drums tapering 4.6 → 2.5 diameter, leaning ~0.3 rad over its height. Crown of 9 fronds, each three tapering blades hinged up-out-down; horizontal reach ~13, drop ~6 from the crown. Three coconuts under the boss. |
| 4 | `SB_Palm_Bent` | 26 × 26 × 30 | As above with a stronger lean (~0.5 rad), for the shore and corner positions. |
| 5 | `SB_Palm_Small` | 19 × 19 × 22 | The same tree at roughly 0.75, for the wall-hugging rank. |
| 6 | `SB_Tropical_Leaf_Broad` | 15 × 15 × 7 | The broad spiky clump the concept banks against rock: 7 blades ~3 × 8.4 radiating from a low base, rising 0.6–1.0 rad. |
| 7 | `SB_Tropical_Leaf_Low` | 11 × 11 × 5 | The smaller, denser version for the wall base. |
| 8 | `SB_Hibiscus_Clump` | 6 × 6 × 3 | Low green pad, 6 stalks, pink five-petal blooms ~2.8 across with a yellow centre. The concept's pink accent. |

## Palette in the build

| role | colour |
|---|---|
| rock mid / light / dark | `138,142,152` · `172,176,186` · `104,108,120` |
| cave interior | `58,62,74` |
| palm bark | `150,108,66` / `118,82,50` |
| fronds | `74,158,66` · `48,118,54` · `108,186,80` |
| hibiscus | `244,118,126`, centre `250,208,76` |
| water / deep / pale | `64,214,235` · `36,176,214` · `148,236,244` |

## Wiring on delivery

1. Import the bundle into `ServerStorage.RegionImportStaging` in Edit mode.
2. Capture `src/server/Map/SplashwaterPropTemplates.rbxm`, preserving `MeshSize`.
3. Add the swap entries to the Water branch of `GardenBayProps.apply`. The
   stand-ins are already named for it and carry usable CFrames:
   `GrottoRock` / `GrottoArch` → `SB_Tidepool_Grotto`, `CascadeRock` →
   `SB_Cascade_Rocks`, `PalmTrunk` + `PalmFrond` → the three palms,
   `TropicalLeaf` → the two leaf clumps, `HibiscusBloom` → `SB_Hibiscus_Clump`.
   The barrels, logs and starfish are stacked cylinders whose CFrame carries a
   baked quarter turn — those are retired and re-placed from the coordinate
   lists already in `GardenBayProps`, not swapped in place.
4. Rerun `lune run tools/world_harness.luau` and retake `build-refcam.png`.

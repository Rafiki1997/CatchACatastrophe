# Gusty Gardens — approved thin-leaf broadleaf family

2026-09-23. Rahul accepted the 25%-narrower leaf review with **“Looks good, proceed.”** A is that exact saved source. B and C extend the accepted treatment with distinct branch layouts, independently seeded leaf distributions and crown proportions. No separate user approval of B/C or post-import appearance is claimed.

**Integrated 2026-09-23 after Rahul uploaded the bundle:** all **35 perimeter trees / 105 native MeshParts** are active, A12/B12/C11; 35 original collision proxies retained and zero old crowns. Native library and real IDs/maps are captured. Reviewed actual Studio [close-up](roblox/studio-broadleaf-close.jpg) and [overview](roblox/studio-broadleaf-overview.jpg). See `roblox/integration-status.json` for current evidence and limits; the export-preparation notes below describe the earlier stage.

![Optimized family, actual Blender render](roblox/broadleaf-family-roblox.png)

[Editable family](GustyBroadleafFamily.blend) · [Source render](broadleaf-family-source.png) · [Roblox FBX bundle](roblox/GustyBroadleafBundle.fbx) · [Import instructions](roblox/IMPORT-AND-INTEGRATION.md)

## Delivered

| Variant | Form | Export W × H × D, studs | Source triangles | Export triangles |
| --- | --- | --- | ---: | ---: |
| A / Meadow | Approved rounded canopy, thin leaves | 19.992 × 17.950 × 18.872 | 93,982 | 38,302 |
| B / Spreading | Lower trunk/crown, spreading low boughs, shifted upper groups | 19.740 × 16.800 × 18.752 | 93,982 | 38,302 |
| C / Upright | Nine ascending bough groups, narrower crown, different trunk path | 15.676 × 17.980 × 14.641 | 71,326 | 29,566 |

The source totals **259,290 triangles**. The separate export totals **106,170**, a **59.05% reduction**, with all 9,570 leaves retained. Each leaf becomes a closed eight-triangle folded volume; bark and its ridges are retained. Each tree exports as Wood plus two leaf batches, nine components overall, all below 20,000 triangles. This is a pipeline limit, not a device-performance guarantee. Thirty-five sites will contain 105 MeshParts and about 1.24 million placed triangles before engine LOD; mobile profiling remains required.

`roblox/` includes optimized `.blend`, gallery and nine individual FBXs, external/embedded 2048 color/normal/roughness PNGs, manifest and independent round-trip report. Tube UVs run around/along each woody segment; leaf UVs follow root-to-tip with padding within color tiles. The maps provide restrained grain and a subtle leaf midrib. They are procedural portable maps, not a high-poly bake. Original source scenes remain separate.

All components retain the shared **root socket at local zero**. Roblox `(x,y,z) = Blender (x,z,-y)`. Use manifest component centers for MeshPart CFrames. Gallery x offsets -23/0/+23 are preview only. No nonuniform runtime scaling is applied; source proportions fit the current site envelope. A's optimized top differs by 0.03 stud because the simplified folded leaf removes its intermediate high point.

## Validation and integration state

- Compared the actual source/export family renders. Independent FBX imports pass nine individual files and the whole bundle: exact membership, sizes, component centers, gallery offsets, triangle counts, closed/nondegenerate geometry, finite normals/UVs and all three imported maps.
- Placement verifier: **4,000 checks**, including comparison to 245 measured pre-restyle trunk/crown parts, all 35 anchors, A12/B12/C11, 105 components, containment in original bounds, collision preservation, non-tree preservation, repeated application, missing/partial/distorted/untextured libraries, invalid sites and staging.
- Import staging 42, stray quarantine 15, existing Powder Fir 11,151 checks passed; 134-file structure/quote scans and Rojo build passed. Source hashes read from Studio match all five changed modules.
- Fresh actual Studio Play confirmed **35 visible original trunks, 210 original crown lobes, and 35 solid/non-queryable trunk proxies** while the new library is absent. SelfTest **1004 passed / 16 failed** (two additional passing checks, same recorded failures); LiveTest **63 / 2**, unchanged. Existing failures concern old map/plot/art/route assertions and field clearance, not the new broadleaf checks.
- **Native upload/capture completed after the user imported the FBX.** `src/server/Map/GustyBroadleafTemplates.rbxm` preserves all nine real uploaded meshes/maps; IDs and scale are in `roblox/roblox-import.json`. Measured scale100 and a native 180-degree yaw correction are verified by 180+ uploaded-vertex samples per mesh. Updated placement fixtures pass **4,141 checks**; actual105 placed MeshParts preload successfully. Latest SelfTest **1005/16**, LiveTest **63/2**, same existing failure set. Studio left in Edit; raw gallery anchored in storage. Nothing committed/published. Full mobile/device profiling and user post-import review remain outstanding.

## Reproduce

Run from the repository root with Blender 5.1.2. Existing source/export targets require explicit `--rebuild` to replace them.

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.1/blender.exe' -b --python tools/blender/create_gusty_broadleaf.py -- --variant B --no-render --rebuild
& 'C:/Program Files/Blender Foundation/Blender 5.1/blender.exe' -b --python tools/blender/create_gusty_broadleaf.py -- --variant C --no-render --rebuild
& 'C:/Program Files/Blender Foundation/Blender 5.1/blender.exe' -b --python tools/blender/build_gusty_family.py -- --rebuild
& 'C:/Program Files/Blender Foundation/Blender 5.1/blender.exe' -b --python tools/blender/export_gusty_broadleaf.py -- --rebuild
& 'C:/Program Files/Blender Foundation/Blender 5.1/blender.exe' -b --python tools/blender/verify_gusty_exports.py
python tools/generate_gusty_broadleaf_spec.py
lune run tools/verify_gusty_broadleaf.luau
```

The family assembly reads the approved A from `../broadleaf-v2-thin-leaves/GustyBroadleafThinLeaves.blend`. The B/C builder outputs to `source/B` and `source/C`. Rebuilding their source does not overwrite either prior review model. `source-manifest.json` preserves source counts and bounds; the export manifest is authoritative for runtime sizes and offsets.

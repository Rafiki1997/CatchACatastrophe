# Powder Fir family - native Blender review models

Built for Rahul's selected Powder Fir concept and its Broad / Upright siblings. These actual Blender models are approved by Rahul. Optimized, textured Roblox exports now live in `roblox/`; see `roblox/IMPORT-AND-INTEGRATION.md`. Upload and actual in-game review are still pending.

## Open and review

Open **PowderFirs.blend** in Blender 5.1. It contains all three editable variants, arranged left to right:

| Variant | Collection | Intended dimensions W x H x D | Triangles |
| --- | --- | --- | --- |
| A / Original | PowderFir_A_Original | 15.129 x 26 x 15.463 | 327,232 |
| B / Broad | PowderFir_B_Broad | 17.503 x 23.5 x 16.498 | 302,456 |
| C / Upright | PowderFir_C_Upright | 14.261 x 28.3 x 14.681 | 349,162 |

Each tree has separate **Bark**, **NeedleSprays**, and **Snow** meshes. The PREVIEW_ONLY collection contains the ground, labels, lights and camera. Gallery X offsets (-19.5, 0, +19.5) are display positions, not map placements; each tree's geometry is locally bottom-centered. Modeling Z is up; table dimensions map to Roblox X/Y/Z.

- `powder-firs-lineup.png`: all three at the same scale.
- `powder-fir-a-original.png`: A close view.
- `powder-fir-b-broad.png`: B close view.
- `powder-fir-c-upright.png`: C close view.
- `powder-fir-branch-detail.png`: modeled foliage and snow detail.
- `geometry-report.json`: dimensions, component counts and geometry checks.

## Construction

Independently generated branch arrangements (42 / 36 / 47 primary boughs), thousands of closed needle elements, ridged tapered bark, root flares, and voxel-welded snow mounds with smaller rounded overhangs. Buried needles are filtered before mesh creation. Branch spacing becomes closer toward the crown. The snow uses actual geometric surface variation plus procedural fine bump; all surfaces use native Blender materials.

Source concepts are under `docs/art/regions/2026-09-22-frostbite-peaks/tree-concepts/`: `02-powder-fir.png`, `02b-powder-fir-broad.png`, and `02c-powder-fir-upright.png`.

## Production status

These detailed source models preserve the approved appearance. The separate `roblox/` edition has simpler closed needles, reduced snow topology, preserved bark, portable UV texture maps, a component manifest and validated FBXs. Replacement code uses the original site's bounds and trunk anchor, without changing the old Alpine manifest. Group upload, native template capture, actual Studio visual/performance review and any further LOD work are pending.

Builder: `tools/blender/create_powder_firs.py`. It refuses to overwrite the scene without `-- --rebuild`; `--no-render` skips previews. Renderer: `tools/blender/render_powder_firs.py` reopens the saved scene without rebuilding; accepts `-- --only A`, B, C, lineup or detail, and optional `--samples 32`.

No asset upload, Studio mutation, commit or publication was performed.

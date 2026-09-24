# Gusty Gardens — broadleaf restyle, first review

2026-09-23. **Actual Blender source model; awaiting design review.** No game replacement, upload, optimization or export has occurred.

![Blender three-quarter render](broadleaf-three-quarter.png)

[Approved Powder Fir comparison](broadleaf-powder-comparison.png) · [Front](broadleaf-front.png) · [Side](broadleaf-side.png) · [Detail](broadleaf-detail.png) · [Player scale](broadleaf-player-scale.png)

## Delivered model

`GustyBroadleaf.blend` contains one editable hero in `GG_Broadleaf_A_Meadow`: Bark, BarkRidges, Leaves. A branching warm-brown trunk supports twelve organized crown groups with 3,480 closed, folded leaves. Raised longitudinal ridges and flared roots carry the approved Powder Fir's material treatment into Gusty's leafy meadow palette. This is the first proposed treatment, not an approved family.

The three source meshes total **93,982 triangles**. Geometry checks report zero nonmanifold edges and zero degenerate faces. Individual closed roots/branches/leaves overlap; this is not a Boolean-unioned solid, and these checks do not establish absence of intersections. Source leaves alone contain 83,520 triangles; an optimized export and populated-scene profiling are required before production use.

Dimensions are **19.992 W × 17.980 H × 18.872 D studs**, within the current unscaled perimeter broadleaf envelope. All meshes use the same root-axis frame with bottom at zero. `TrunkBase` is `(0,0,0)`. Component bounds and Roblox center offsets are in `geometry-report.json`. Blender `(x,y,z)` maps to Roblox `(x,z,-y)`. The bounds center is intentionally not the trunk socket.

`PREVIEW_ONLY` contains the ground, lighting, camera, 5-stud gray human marker and an appended copy of the approved source Powder Fir A. The fir stays at its original 26-stud height and is 23 studs to the right. Both trees share lighting and unit scale in the comparison. The saved scene opens on the hero view; the comparison objects are hidden from rendering until that shot is selected by the script. Original Powder Fir files were only read.

## Reproduce

From the repository root:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.1/blender.exe' -b --python tools/blender/create_gusty_broadleaf.py -- --rebuild
```

The deterministic seed is 92326. The script refuses to overwrite an existing scene without `--rebuild`. Add `--no-render` for geometry only. Materials are procedural Blender materials; UVs, portable texture maps, FBXs and native templates are deliberately later production stages after design review.

To render the saved source without rebuilding, use `tools/blender/render_gusty_broadleaf.py`; optional `-- --only player|hero|front|side|detail|comparison` selects one view. An independent reopen passed saved mesh names, triangle counts, geometry, component transforms, overall bounds and the reference fir's unchanged 26-stud height; see `source-validation.json`. The player view uses a perspective camera at 6.5 studs, while the inspection views are orthographic.

## Placement decision

This targets the **35 current `bigTree` perimeter sites**, not the five legacy `GG_Windbent_Tree` placements hardcoded in `GardenBayProps`. Preserve each existing trunk's root CFrame and uniform site scale. Retain its collision proxy. Group the six nearby `MeadowTreeLobe` parts with their site before replacing them; currently the region emits flat sibling parts rather than named asset-site models. Validate all sites before retiring geometry.

Read [the region inventory](../../../docs/art/GUSTY-RESTYLE-INVENTORY.md) for the integration mismatch and the remaining asset families. `region-inventory.json` contains the measured source-generated part snapshot and exact world transforms. It is a **headless fallback build**, not a Studio runtime capture. The headless native-kit check rejects `GG_Moss_Rock_Wide`; no conclusion about live asset loading follows from that.

## Next review and acceptance

Review the hero's crown fullness, leaf size/color and bark treatment before making broad/upright siblings. Then optimize with matched renders, preserve shared component offsets and the root socket, generate portable maps, independently reimport FBXs, and capture real Roblox templates. Runtime visuals, collision/route clearance and device performance remain unverified. No Studio source was edited; Studio was observed in Edit mode with no generated Gusty region present.

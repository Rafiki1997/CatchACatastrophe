# Frostbite Peaks — Alpine Expedition reusable kit

Eight Blender assets for the user-approved V2 region, integrated into Claude's
base layout at all 56 measured prop sites on 2026-09-21.

## Files

- `props.blend`: editable meshes in EXPORT_ASSETS, staging in PREVIEW_ONLY.
- Eight individually exported FBXs at local origin, ground-centre pivot.
- `FrostbitePropsBundle.fbx`: all eight separate meshes, gallery positions,
  full production dimensions. No preview discs, labels, camera or lighting.
- `palette.png`: embedded/packed 32-color atlas; one material and UV layer.
- `manifest.json`: exact intended Roblox XYZ dimensions and triangle counts.
- `validation.json`: fresh Blender FBX round-trip results.
- `preview.png`: actual rendered assets. Tall fir is displayed at 55% only in
  this gallery image to fit its slot. Saved Blender scene and FBXs are full size.

## Contents and use

| Mesh | Placement |
|---|---|
| FP_Snow_Rock_Wide / Tall | Peripheral cliff foot/tree sites; preserve blockout collision beneath art |
| FP_Snow_Fir_Tree / Sapling | Static snowy tree groups outside catching field; scale uniformly |
| FP_Snow_Drift | Low perimeter/terrace snow; not an obstacle inside the field |
| FP_Icicle_Cluster | Under eaves/ledge lips; align top of bounds to mounting height |
| FP_Supply_Crate | Expedition hut porch or side supplies |
| FP_Rope_Coil | On porch/crate/bridge-side staging surfaces |

Total 4,716 triangles for one of each asset. Overlapping closed components are
intentional. No collision meshes, scripts, particle systems or physics supplied.
Use decorative anchored MeshParts over the base layout's collision; keep them
non-colliding/non-queryable/non-touching. Avoid whole-tree sway.

The hut, bridge, mountain cliff/peak pieces, snow cornices, entrance and cascade
are not modeled in this kit. Their fitted production pass uses Claude's measured
`FROSTBITE-PEAKS-LAYOUT.md` when available. The handoff is in
`docs/art/regions/2026-09-20-concepts/FROSTBITE-PEAKS-CLAUDE-HANDOFF.md`.

## Import after the layout handoff

Imported and integrated on 2026-09-21. `Map/FrostbiteProps.luau` places 56 meshes
(50 ground, 6 hanging) from native `Map/FrostbitePropTemplates.rbxm`. The imported
100x Size is normalized while preserving internal MeshSize. Actual asset IDs
are in `roblox-assets.json`; Frost's palette is `122924432155152`.
Missing or incomplete templates still preserve the blockout. Isolated fixture
tests cover unchanged Boundary/Walkways, idempotence and fallback.

`Map/ImportStaging.luau` now recognizes FrostbitePropsBundle against the native
FrostbitePropTemplates library. Existing regions taught us that raw importer
galleries may be unanchored at 100x scale; they must remain outside Workspace.
Use Edit mode for import, normalize Size against the manifest and serialize
native MeshParts with their internal MeshSize intact. Save actual asset IDs.
The existing Cinder/Gusty/Splashwater palettes differ from this Frost palette;
do not reuse their texture ID just because all images are named palette.png.

In Studio Edit, import `FrostbitePropsBundle.fbx` with Upload to Roblox and Insert
into Workspace enabled, keeping eight separate meshes and the embedded texture.
Keep Studio in Edit until native templates are captured, normalized and synced.

## Reproduce and verify

Run Blender 5.1 with `--background --python tools/blender/create_frostbite_props.py`.
It uses geometry/export helpers from create_garden_bay_props.py, which is now
safe to import without rebuilding those other kits. Existing .blend files are
protected by default; `-- --replace-generated` deliberately replaces generated
outputs, so preserve hand edits first.

Then run `--background --python tools/blender/verify_frostbite_props.py`.
Checks: individual mesh count, dimensions, origin, triangles, manifold edges,
positive faces, ground alignment, one material/UV, atlas sample coordinates,
embedded texture, and exact bundle names. Final preview visually inspected.
Fresh Studio Play: 940 SelfTest / 72 LiveTest, zero failures; 56 actual props,
eight variants, zero anchor error, 216 Boundary and 177 Walkways parts retained.
Client preload: all 112 mesh/texture requests succeed. Current ground-level
view inspected under game lighting. Raw bundle retained and anchored in
ServerStorage.RegionImportStaging; no loose or oversized imports in Workspace.
Mobile performance and a full visual tour of every placement remain unmeasured.

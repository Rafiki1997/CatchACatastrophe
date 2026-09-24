# Cinder Quarry — Blender asset delivery

Twelve custom assets for the approved option 03, created by Astra. The shared
implementation contract is
`docs/art/regions/2026-09-22-cinder-canyon/CINDER-QUARRY-CLAUDE-HANDOFF.md`.

Status: models/export complete; Blender verification and preview results are in
`validation.json` and the PNGs. **Roblox upload, native template capture and map
integration are pending.** No new Roblox asset IDs have been assigned.

## Delivered files

- `CinderQuarry.blend`: editable source. `EXPORT_12_ASSETS` contains the full-size meshes; enable that collection to edit them. `PREVIEW_ONLY` contains scaled display copies, platforms, labels, camera and lights.
- `CinderQuarryBundle.fbx`: all twelve separately named visual meshes, packed palette texture, arranged in an import gallery.
- Twelve individual `CC_Quarry_*.fbx` files: one mesh each, at a base-centered local origin.
- `quarry-palette.png`: external copy of the packed/embedded 512 × 16 color atlas.
- `manifest.json`: dimensions, triangle counts and asset-local effect/placement sockets.
- `validation.json`: independent FBX reimport and geometry/material checks.
- `preview-all-assets.png`: actual Blender geometry; display sizes are normalized for legibility, not relative game scale.
- Twelve individual previews: actual geometry inspection images.
- `preview-landmark-assembly.png`: mine/cart/rail and terrace/hoist fit check. Sand, light and lava dressing in this preview are illustrative only; they are not in the exported bundle.

The previous `props-v1` kit remains unchanged and supplies compatible small
basalt, ember and rubble accents. These new models supplement it.

## Fixed dimensions

All dimensions below are Width X × Height Y × Depth Z in intended Roblox studs.

| Name | W × H × D |
| --- | --- |
| CC_Quarry_Mine | 64 × 42 × 48 |
| CC_Quarry_Terrace | 72 × 36 × 56 |
| CC_Quarry_Hoist | 20 × 22 × 16 |
| CC_Quarry_Cart | 11 × 8 × 14 |
| CC_Quarry_Rail | 12 × 1 × 26 |
| CC_Quarry_Mesa_Large | 27 × 22 × 21 |
| CC_Quarry_Mesa_Low | 22 × 11 × 17 |
| CC_Quarry_Cactus_Tall | 9 × 17 × 7 |
| CC_Quarry_Cactus_Round | 7 × 6 × 7 |
| CC_Quarry_Agave | 11 × 7 × 11 |
| CC_Quarry_Flowers | 6 × 4 × 6 |
| CC_Quarry_Crate | 6 × 6 × 6 |

## Import and placement

1. In Studio Edit mode, open the 3D Importer and select `CinderQuarryBundle.fbx`. Preserve twelve separate meshes and their exact names. Include the texture/material and upload under the appropriate game owner.
2. Check imported sizes against the manifest. Previous project imports applied a 100× conversion. Correct the entire bundle uniformly if necessary; do not stretch axes individually.
3. Name the imported Model `CinderQuarryBundle` and place it in `ServerStorage.RegionImportStaging` while preparing integration. The display-grid offsets are not map placements.
4. Save native imported templates as `CinderQuarryTemplates.rbxm`, preserving MeshSize, mesh IDs and material/texture data. Do not replace `CinderPropTemplates.rbxm` or lose its older assets.
5. Claude integrates the twelve types at the explicit asset sites from the shared handoff. Asset geometry is decorative; use deliberate layout collision proxies. Anchor decorations and disable touch/query. Do not make cacti, loose flowers or the hanging crate into unintended obstacles.

Blender +Z exports to Roblox +Y. Asset front is Blender +Y / Roblox -Z. All
individual mesh coordinates are base-centered. A native MeshPart's CFrame uses
its bounds center: add half its height above the desired bottom frame. Avoid
adding this offset twice with imported Model pivots.

Attachment positions in `sockets_roblox_xyz_from_base` are local XYZ offsets
relative to the bottom frame, after final authoring scale. Apply the site's
rotation and any uniform scale to these offsets.

- **Mine:** `DoorBase` anchors the rail. Rail bottom frame is Mine bottom × DoorBase × CFrame.new(0,0.02,-13). Cart bottom is Mine bottom × DoorBase × CFrame.new(0,1.05,-16). This aligns them with the recessed doorway, rather than the outer boulder bounds. `Lantern` is the light anchor.
- **Terrace:** place the hoist at `HoistBase`. The lava channel is on asset local -X, the outer/right side in the current region frame. Use `LavaUpperLip`, `LavaLowerLip` and `LavaFoot` for separate effect surfaces. Use crystal sockets for existing ember art/effects.
- **Hoist:** hanging load and rope are static mesh components. This is scenery, not an interactive crane.
- **Cart:** mineral load is colored geometry. Add limited glow at `OreGlow`; do not set the whole cart to Neon.

The mine has a recessed dark interior for depth, not a new exploration tunnel.
No game mechanics, sources, native libraries or other regions were modified in
this asset delivery. Studio lighting/material appearance still requires review.

## Reproduce and validate

Run Blender 5.1 with `tools/blender/create_quarry_props.py`, then
`tools/blender/verify_quarry_props.py`. Generator refuses to overwrite an existing
source .blend unless passed `-- --rebuild`. Preserve any hand edits before using
that flag. `--no-render` skips previews. `render_quarry_landmarks.py` reproduces
the assembly preview without changing exported assets.

The verifier reimports all twelve FBXs, checks exact sizes/base origins,
closed nondegenerate geometry, per-face palette-center UVs, one textured material,
triangle counts, expected bundle names and forward-axis conversion. The renders
were visually inspected. Actual Studio integration and gameplay verification
remain Claude's next step after import.

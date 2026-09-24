# Tropical Tidepools — Blender delivery

Created for the approved Splashwater Bay option 03 and Claude's
`docs/art/regions/2026-09-22-splashwater-bay/SPLASHWATER-ASSET-REQUEST.md`.
These are actual modeled assets and Blender renders, not image-generated previews.

## Files

- `TropicalTidepools.blend`: editable eight-asset gallery; full-size visual meshes in `EXPORT_EIGHT_ASSETS`.
- `TropicalTidepoolsBundle.fbx`: eight separate named meshes with embedded palette texture. Import this first.
- Eight individual `SB_*.fbx` files: each mesh at a base-centered origin.
- `palette.png`: external copy of the packed 512 × 16 color atlas.
- `manifest.json`: exact sizes, triangle counts and water/animation attachment coordinates.
- `validation.json`: FBX roundtrip, geometry, texture, hull and split-palm checks.
- `preview-all-assets.png` and eight individual previews: renders of delivered geometry.
- `collision/`: eight separate simple bounds hulls. Palm hulls cover trunks only.
- `split-palms/`: optional separate trunk and crown meshes for each palm, all sharing the corresponding full tree's base origin. Use instead of the combined tree when animating the crown independently.

The earlier `props-v1` pack is unchanged. It supplies the existing rocks, barrels,
shells and starfish; this new pack complements it.

## Import into Roblox Studio

1. Stay in Edit mode and use Studio's 3D Importer to select `TropicalTidepoolsBundle.fbx`.
2. Preserve all eight separate mesh names. Import the material/texture, upload the assets under the game's appropriate owner, and insert the model. Do not merge the eight meshes.
3. Check imported sizes against the table below. Previous project FBX imports arrived 100× too large. Normalize the whole bundle uniformly if that occurs; never compensate by distorting individual axes.
4. Name the imported Model `TropicalTidepoolsBundle` and move it to `ServerStorage.RegionImportStaging` while in Edit mode. The model's gallery positions are not region placements.
5. Capture the imported native MeshParts into a new `TidepoolsPropTemplates.rbxm` library, preserving `MeshId`, texture/SurfaceAppearance, `MeshSize`, and imported properties. Merge into the old library only deliberately; do not replace its existing eight assets.
6. Integrate the new placements using `CLAUDE_ASSET_HANDOFF.md`, then compare the actual Studio view against the approved mockup.

No Roblox upload, native template capture, or game integration has been performed in this delivery. No Roblox asset IDs have been invented. The available tools do not provide a local-FBX upload action; Studio import is the remaining external step.

## Exact authored dimensions

| Mesh | Width X | Height Y | Depth Z |
| --- | ---: | ---: | ---: |
| SB_Tidepool_Grotto | 65 | 27 | 53 |
| SB_Cascade_Rocks | 60 | 42 | 50 |
| SB_Palm_Tall | 26 | 33 | 26 |
| SB_Palm_Bent | 26 | 30 | 26 |
| SB_Palm_Small | 19 | 22 | 19 |
| SB_Tropical_Leaf_Broad | 15 | 7 | 15 |
| SB_Tropical_Leaf_Low | 11 | 5 | 11 |
| SB_Hibiscus_Clump | 6 | 3 | 6 |

One Blender modeling unit represents one intended stud. Blender +Z maps to Roblox
+Y, and the assets' visible front is Blender +Y / Roblox -Z. Individual exports
are centered horizontally and based at zero. Native MeshPart CFrame is its bounds
center: position it half its height above the desired bottom frame. Do not add
that offset twice if using an imported Model pivot.

Water, foam and particles are deliberately separate from the rock meshes. Use
the manifest's `sockets_roblox_xyz_from_base` to align existing effects to the new
ledges. These are local offsets, not world positions. Apply placement rotation
and any uniform scale to them.

The grotto has a recessed open mouth and dark stone interior. It is a scenery
asset, not a new cave-exploration mechanic. Its optional convex bounds hull fills
the opening: use existing segmented collision proxies if a player needs to enter.
Foliage should normally have no collision, touch or query; optional hulls are not
instructions to enable collision. Water and gate gameplay remains Claude's code.

## Reproducibility

Generator: `tools/blender/create_tidepools_props.py`.
Validator: `tools/blender/verify_tidepools_props.py`.
Run with Blender 5.1 in background mode. The generator refuses to overwrite the
existing .blend unless explicitly passed `-- --rebuild`; use that only before
manual art edits, or after preserving them. `--no-render` skips previews.

Validation reimports the delivered files, checks all eight dimensions and base
origins, a single palette UV layer and embedded texture, closed positive-area
geometry, triangle counts, the exact bundle names, convex collision hulls, and
the split-palms' reconstructed bounds. Asset appearance was inspected in Blender;
actual Studio material appearance and importer scale still need verification.

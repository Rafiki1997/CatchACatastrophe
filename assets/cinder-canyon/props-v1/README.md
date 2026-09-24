# Cinder Canyon reusable props — first Blender pass

Created alongside Claude's V2 Sculpted Ravine base layout and now integrated.
The main cliff kit, arch, bridge and lavafall terraces still need their fitted
production pass against the completed layout contract.

## Deliverables

Imported into Roblox on 2026-09-20. `roblox-assets.json` records all nine mesh
IDs and the shared palette texture. `src/server/Map/CinderPropTemplates.rbxm`
contains native Studio-serialized templates, including internal mesh bounds.
The importer used a 100x scale; template Size was divided by 100 before saving.
`CinderProps.luau` places 32 instances against Claude's completed blockout.
The cliff walls, arch, bridge and lavafall terraces still use blockout geometry.

`CinderPropsBundle.fbx` groups the nine meshes for one import operation (keep
them separate). `tools/blender/export_cinder_bundle.py` reproduces the bundle.
Do not reconstruct MeshParts from just MeshId and Size: preserve native
serialization, including MeshSize, when updating the template model.

- `cinder-props.blend`: editable Blender 5.1 scene. EXPORT_ASSETS contains nine
  actual meshes; PREVIEW_ONLY contains the gallery, labels, lights and camera.
- Nine individually exported FBX files, each with one mesh and one material.
- `cinder-palette.png`: shared color atlas; also packed in Blender and embedded in FBX.
- `preview.png`: real Blender render of the kit, not AI-generated concept art.
- `manifest.json`: names, Roblox-axis intended dimensions in studs, triangle counts,
  pivot, collision guidance and glow notes.
- `validation.json`: per-file FBX export/import checks.

| Asset | Intended size W × H × D (studs) | Triangles |
|---|---|---|
| Basalt Tall | 4.312 × 5.8 × 3.136 | 336 |
| Basalt Wide | 5.682 × 4 × 3.186 | 392 |
| Basalt Low | 3.816 × 2.2 × 2.866 | 224 |
| Ember Tall | 2.65 × 4.38 × 1.805 | 264 |
| Ember Fan | 2.802 × 3.38 × 1.671 | 302 |
| Ember Small | 2.23 × 1.88 × 1.195 | 226 |
| Sandstone Wide | 5.179 × 2.1 × 3.434 | 280 |
| Sandstone Tall | 3.006 × 3.5 × 2.529 | 280 |
| Sandstone Rubble | 4.344 × 1.25 × 2.83 | 560 |

Total: 2,864 triangles for one of each variant. This is a starting style kit;
colors and faceting should be assessed against the final region lighting.

## Integration handoff

FBXs are exported at local origin with a ground-center pivot. The .blend scene
arranges originals in a preview grid; that grid is not part of the FBX exports.
One modeling unit is intended as one Roblox stud. Verify scale on the first
Studio import using manifest dimensions; do not assume importer unit conversion.

Use decorative meshes over the blockout's collision geometry. Clusters contain
multiple individually closed, overlapping solids; they are not boolean-unioned.
Keep them clear of paths, creature roaming and capture telegraphs. Crystal glow
is optional placement-time lighting/VFX, not baked Blender emission. Do not make
the whole crystal-and-rock mesh Neon unless the dark base is split first.

Roblox supports FBX imports and texture assignment through its importer:
[official Blender import guide](https://create.roblox.com/docs/art/blender).
The user imported the bundle; its asset references are now saved in Rojo.

## Verification

All nine FBXs reimport successfully into a fresh Blender scene. Checked: one mesh,
expected triangle count and dimensions, zero-origin placement, UV map, one material
with image texture, closed topology with no nonmanifold edges. Original meshes
also have positive-area faces and no vertices below the ground plane. The final
preview was visually inspected. Studio overview and close-up confirmed placement;
all nine mesh IDs and the palette texture fetched successfully on the client.
The project passes 922 self-tests and 72 live checks, including imported mesh
bounds/scale, non-colliding decoration, seven flush rubble groups, field clearance,
and sign visibility. Mobile frame time remains unmeasured.

## Reproduction

`tools/blender/create_cinder_props.py` creates the kit with deterministic seeds and
refuses to overwrite an existing .blend. Choose a new version directory for later
iterations. `tools/blender/verify_cinder_props.py` intentionally reexports these
generated files from the .blend at local origins, verifies them and rerenders the
preview; do not use it on hand-edited exports without preserving those changes.

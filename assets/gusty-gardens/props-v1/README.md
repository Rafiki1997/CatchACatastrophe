# Gusty Gardens Blender kit

Eight reusable meshes built for the current windmill/meadow region, with muted
moss greens, warm wood, cream daisies and purple flowers. `preview.png` renders
the actual Blender geometry. The tree is shown at 55% scale for the contact sheet;
the saved .blend and FBXs retain full production dimensions from the manifest.

Deliverables: editable `props.blend`, eight individual FBXs, embedded and external
`palette.png`, a dimension/triangle `manifest.json`, and `validation.json`.
`GustyPropsBundle.fbx` contains all eight separate meshes in a display grid.
Individual FBXs have ground-centre origins; Blender Z-up exports to FBX Y-up.

| Asset | Placement target |
|---|---|
| GG_Moss_Rock_Wide / Tall | GardenStone groups beneath trees; retain tested collision |
| GG_Daisy_Cluster / Bluebell_Cluster | FlowerStem/Petal/FlowerCentre groups on FlowerBed islands |
| GG_Fern | Peripheral meadow detail beside trees and flower beds |
| GG_Meadow_Shrub | Low edge planting, clear of paths and sign sightlines |
| GG_Windbent_Tree | Five LeaningTrunk/TreeBranch/WindCanopy assemblies; fit original footprint |
| GG_Flower_Planter | Windmill or arbor side decoration, clear of the entrance |

This pass leaves the windmill, arbor, fence, sign and barriers intact. Retain the
open catching area. Use non-colliding/non-queryable decorative meshes over the
layout collision; verify tree crown clearance and board sightlines after scaling.
The tree is one static mesh: existing separately swaying WindCanopy parts cannot
be replaced by whole-tree sway without making the trunk move. Keep the mesh
static or create a separate crown export in a later animation pass.

## Import

Imported and integrated on 2026-09-20: all eight variants appear as 43 props.
`roblox-assets.json` records the uploaded IDs. Native templates are saved in
`src/server/Map/GustyPropTemplates.rbxm`; `GardenBayProps.luau` handles placement.
Studio imported at 100x scale, normalized before serialization. Preserve native
MeshSize when updating templates. The bundle excludes all preview staging.
All mesh/texture IDs load successfully on the client. Studio overview and detail
views inspected; 930 self-tests and 72 live checks pass, including field/sign
clearance, finite frames and safe decoration flags. Mobile cost remains unmeasured.

## Rebuild and validation

Use `tools/blender/create_garden_bay_props.py` with Blender 5.1 followed by
`tools/blender/verify_garden_bay_props.py`. Existing .blend files are protected
unless `--replace-generated` is explicitly provided. `--garden-only` rebuilds
only this kit. Preserve hand edits before regenerating.
Validation reimports all FBXs, checking dimensions, ground origins, triangles,
closed topology, positive faces, one material, one consistent palette UV layer,
embedded texture, and the bundle's eight named meshes. Closed components may
overlap; this is a decorative kit, not a collision mesh.

The vertical FlowerStem lookAt issue was fixed with an alternate up vector in
the original builder, so fallback flowers also have finite frames. The Blender
pass replaces all old stems/petals/centres and uses static trees; meadow grass,
mill sails and pinwheels retain their existing animation.

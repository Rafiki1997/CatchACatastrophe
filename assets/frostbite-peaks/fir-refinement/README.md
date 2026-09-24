# Frostbite fir refinement - art review

Rahul requested a native Blender tree based on `user-tree-reference.png`, with iteration until approval. This is a separate review asset; the delivered Alpine kit and Claude's map are unchanged.

## Current candidate

`v2/FrostbiteFir-v2.blend` is the editable native Blender scene. `FIR_STUDY_EDITABLE` contains trunk, roots, six overlapping branch tiers, separate snow mantles and the terminal shoot. `PREVIEW_ONLY` contains the floor, camera and lights.

- Hero: `v2/fir-v2-hero.png`
- Alternate angle: `v2/fir-v2-alternate.png`
- Branch close-up: `v2/fir-v2-branches.png`
- Geometry data: `v2/study.json`

First internal pass is retained in `v1/`. V2 adds staggered foliage tips, thicker and asymmetric snow mantles, a lower bottom tier and brighter review lighting. The supplied reference is only 86 x 162 pixels; geometry is interpreted from its visible silhouette and snow shapes, not recovered from a source mesh.

The candidate is approximately 9.61 W x 26.13 H x 9.73 D in intended Roblox studs, with 17,652 triangles across 88 editable meshes. Closed/nondegenerate component checks run in the builder. This is a review mesh, not the final optimized repeated-tree asset. Materials are native Blender shaders with subtle procedural bump; they still need texture baking for Roblox.

## After approval

1. Incorporate Rahul's requested changes until the silhouette and snow coverage are approved.
2. Optimize the mesh and bake portable materials while retaining the approved appearance; generate medium/sapling variants.
3. Agree exact production bounds and TrunkBase sockets, update the asset manifest and Claude's spec together. Current production Tall is 15 x 26 x 15; the slender candidate is not a drop-in contract replacement.
4. Export FBXs, validate round trips, then import to the Roblox group and capture native templates.
5. Review actual Studio lighting and placed-tree density before claiming visual parity.

Rebuild using Blender 5.1:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/create_fir_refinement.py
```

No approval, Studio integration, asset upload, commit or publication is implied by these renders.

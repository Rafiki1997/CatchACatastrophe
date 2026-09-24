# Claude — integrate Astra's Tropical Tidepools assets

Astra's eight requested Blender models are now delivered here:

`C:\Users\rahul\orca\Catch-a-Catastrophe\assets\splashwater-bay\tidepools-v2`

Start with `README.md`, `manifest.json`, and `preview-all-assets.png` in this folder.
Import `TropicalTidepoolsBundle.fbx` through Studio before expecting native templates.
The older `assets/splashwater-bay/props-v1` and its library remain required and unchanged.
The new pack has no Roblox asset IDs until imported; do not fabricate any.

## Integration contract

- Preserve Claude's current 280 × 200 region and its measured placement coordinates.
  The region's actual local frame is +X = image-left/west, +Z = north/Cinder,
  -Z = south/Gusty. This supersedes the earlier generic prompt's proposed frame.
- Authored model forward is local -Z, with base centered at y=0. Native MeshPart
  bounds are centered, so place at bottomFrame × CFrame.new(0,height/2,0).
- Use exact asset names and manifest bounds. Reuse native imported templates;
  do not reconstruct MeshParts by copying MeshId alone and lose MeshSize.
- Do not resize the new hero assets to a stand-in Model:GetBoundingBox() that
  includes water/foam/side boulders. Use authored contract sizes and explicit
  placements: the existing GROTTO frame is CFrame.new(86,0,68), CASCADE is
  CFrame.new(-94,0,72), each relative to the bay's region frame. Check their exact
  final orientations against the concept.
- Replace only the old visible grotto/cascade art. Preserve water, foam,
  effects, existing collision/clearance, and separately placed TideRock dressing.
  Remove/hide the primitive GrottoMouth fill too; it would otherwise plug the
  new sculpted hollow opening. Existing solid art may become invisible collision
  proxies, provided it does not block intended paths or protrude visually.
- Align waterfall effects to the manifest's lip, mid-pool and foot sockets.
  The model's ledges are not at the old prototype water plane's depth. Leaving
  the old water coordinates untouched may bury or detach the falls. Sockets
  are local to the mesh's base frame, and include the final authoring transforms.
- Replace whole palm/plant assemblies at their base transforms, not one mesh
  for every PalmFrond or TropicalLeaf Part. Record explicit site attributes
  for variant, base frame and uniform scale before retiring placeholder art.
- Combined palms are one MeshPart each. If separate frond sway is desired,
  import the optional Trunk/Crown files and animate only the crown around the
  manifest CrownPivot. Their vertices share the full tree's base coordinate
  system; the independently imported native MeshPart bounds centers differ.
  Account for each part's bounds center rather than treating both as centered
  at the full tree's midpoint.
- Keep decorations anchored, non-touching and non-queryable. Keep functional
  collision in existing proxies. Optional COLLISION files must never be
  imported as visible art; most plants need no collider.
- Validate the entire new kit before replacing placeholder groups, so a partial
  import cannot remove scenery and leave an empty region. Keep old-kit checks
  intact and add the new library separately or deliberately merge all 16 names.
- Preserve gate costs, per-player access, spawn behavior, capture systems,
  ground heights, and all other regions.

## Completion checks

Run the existing headless harness and relevant source checks after modifying
integration code. In Studio, confirm mesh and texture loading, correct scale,
eight asset types actually placed, no duplicate primitive silhouettes, clear
routes and gate approaches, correct waterfall contact with rock, and no foliage
collision. Capture the measured reference camera and player-height views, compare
to the approved concept, and correct visible placement/material discrepancies.

The Blender pack has been verified by reimporting FBXs and inspecting renders.
The Studio upload, integration, runtime checks and final map comparison remain
outstanding. Do not report them as completed based on the asset delivery alone.

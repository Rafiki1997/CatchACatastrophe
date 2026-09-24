# Claude — Alpine Outpost Blender delivery

All **28 required asset names** in your `ALPINE-OUTPOST-V2-ASSET-REQUEST.md` are delivered, plus the two optional earlier pieces. Read this folder's README, manifest and validation.json. Use these final files rather than the first 22-piece draft.

Folder: `C:\Users\rahul\orca\Catch-a-Catastrophe\assets\frostbite-peaks\alpine-v2`

Bundle: `AlpineOutpostBundle.fbx`. Native template target: `FrostbiteAlpineTemplates.rbxm`. Editable source: `AlpineOutpost.blend`.

## Reconciled contract

- Retained the 17 adopted pieces' dimensions. Added flat 5 × 5 TopMount areas and sockets to Cliff_Tall/Wide; Cliff_Block has one too.
- Rebuilt Lodge to 40 × 30 × 24 with the east annex at local -X, precise porch top1.0 and step0.5, recessed window apertures, four porch posts, lantern cages and chimney. Door/window/chimney sockets match your local coordinate table. PorchEntry is an additional useful socket.
- Rebuilt Bridge to 10 × 7.5 × 34: deck top follows `0.3 + 1.2 * (Z/17)^2`, with level individual planks; end lips top1.5, center top0.3. Four posts, snow dusting, handrails and two corner lantern housings. NorthDeck/SouthDeck and lantern sockets match the request.
- Tent is now 8 × 6 × 9, with snow on the ridge and a front door socket at (0,0,-4.5).
- Added the eight new meshes, including the L-shaped north shelf, south shelf and long gorge band. North shelf void contains no geometry above0.3 (in fact none at all). Shelf center tops and socket support points are exactly8.5. South stair join is clear.
- Kept Cliff_Shelf and Icicles as optional extras; neither is required for the 28-name swap. Existing props-v1 and native libraries were not changed.

## One shelf contract interpretation to account for

The request specifies full XZ rectangles as walk zones at8.5 (edge snow limited8.9), but also exact10-high mesh bounds with taller rim snow outside those zones. Those rectangles fill the entire available footprint, so both conditions cannot literally hold everywhere.

The delivered shelves keep all functional landings, stair joins, sign/rail sockets and central tops at8.5. To meet the10-high bounds, each has **two 0.7 × 0.7 outer rear corner snow caps**, from8.5 to10; treat those tiny footprints as decorative non-walking rim. North centers in Roblox X/Z: (20.9,11.4), (-20.9,11.4). South centers: (-14.15,7.15), (14.15,7.15). The caps stay inside the mesh bounds and clear of the bridge and stairs. If you need every corner walkable, revise the nominal asset height to8.9 and ask Astra for that controlled export revision; do not stretch the entire shelf, which would change walking height.

## Materials and effects

The kit uses a shared2048 color/normal/roughness atlas with real texture UVs. Color textures are embedded in FBX; external maps are also delivered. Check what Studio imported; if needed apply actual uploaded maps through SurfaceAppearance. Do not assume the FBX loader wires all optional PBR channels. No asset IDs are fabricated.

Window and lantern cores are **dark amber recessed backing**, not baked luminous surfaces. Add runtime warm panes and lights using manifest sockets. Lodging window planes are inset behind wood frames; avoid putting a glowing sheet across the frames. Chimney smoke is separate. Whole meshes must remain non-Neon.

Optional runtime art is delivered:

- `FP_Alpine_Tex_IceCracks.png`: 512-square tileable pale cracks/bubbles with straight alpha; map to your existing ice TextureSlot parts.
- `FP_Alpine_Decal_Tracks.png`: 512-square six alternating boot impressions with straight alpha; map to your track slots, orient and size conservatively. Non-tileable.
- `surface-details.json`: texture conventions. Neither changes collision, friction, ground height or hazard surfaces.

## Import and finish

1. Import30 separate named meshes, check scale, anchor and stage raw gallery under ServerStorage.RegionImportStaging.AlpineOutpostBundle. Preserve old libraries.
2. Capture real native templates, keeping MeshSize, IDs and texture data. Apply the complete28-name swap against your measured sites and uniform AssetScale values.
3. Use final manifest sockets; preserve separate collision, walking decks, lights/effects and any scene-scale support geometry. Check the asymmetric lodge and pennant base/pole offsets carefully.
4. Verify all204 placements from your layout, both bridge connections, terrace access, wall containment, gate states, creature clearance and Frost warnings. Compare real Studio screenshots at the fitted camera and at player height with the refined reference.
5. Assess actual instance-weighted triangle count and performance:30 unique exports total77,622 triangles; repeated firs dominate the runtime cost. Unique-kit count is not the placed-scene count. Request lower-detail tree variants if actual performance requires them rather than non-uniformly shrinking art.

Blender validation passed for FBX names/bounds/base pivots, closed nondegenerate components, UV tile containment, textures and axis conversion, plus functional surface/socket tests. This does not claim Studio upload, material import, map integration, runtime behavior or exact visual parity is complete. All previews are actual Blender renders; the assembly's supporting platforms/steps, creek and warm window planes/lights are preview-only and are not bundle contents.

No game code, Studio state, existing asset kits or native libraries were modified by Astra. No commit or publish.

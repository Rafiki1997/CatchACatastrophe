# Alpine Outpost V2 — Astra Blender kit

Built for `docs/art/regions/2026-09-22-frostbite-peaks/frostbite-peaks-v2-02-alpine-outpost-refined.png`.

This is real editable Blender geometry and exported textured FBX art, not image-generated model previews. No game code, existing props-v1 library or Studio state was changed by this asset task.

## Current status

Thirty art pieces created: **all 28 required by Claude's measured contract plus two optional extras** (Cliff_Shelf and Icicles), with shared 2048 × 2048 color, normal and roughness atlases. Independent export verification is recorded in `validation.json`: **77,622 unique triangles**. The initial 22-piece draft was reconciled with `ALPINE-OUTPOST-V2-ASSET-REQUEST.md`: lodge/bridge/tent rebuilt, eight pieces added, and cliff TopMount sockets added. Final dimensions below supersede the provisional draft. See the shelf-corner interpretation in `CLAUDE_ASSET_HANDOFF.md`.

Studio upload/native template capture, actual material rendering, final map placement, runtime checks and performance are not part of Blender validation. The concept's lighting and full zone composition are not reproduced merely by importing this bundle.

## Files

- `AlpineOutpost.blend`: editable source; enable `EXPORT_ALPINE_ASSETS` to edit full-size models. `PREVIEW_ONLY` contains display copies, labels, plinths, camera and lights.
- `AlpineOutpostBundle.fbx`: 30 separately named meshes in a spaced import gallery. Gallery coordinates are not map placements.
- `FP_Alpine_*.fbx`: individual bottom-centered exports referencing the shared PNG maps in this folder. Keep the PNGs alongside them; only the bundle embeds textures, avoiding thirty duplicate copies of the atlases.
- `alpine-color.png`, `alpine-normal.png`, `alpine-roughness.png`: shared PBR texture maps. Every mesh has UVs within material-specific atlas tiles. Color is sRGB; normal/roughness are non-color data. No baked lights or shadows in the color map.
- `manifest.json`: exact current dimensions, triangle counts and final normalized socket coordinates.
- `FP_Alpine_Tex_IceCracks.png` and `FP_Alpine_Decal_Tracks.png`: optional 512 × 512 straight-alpha details for Claude's reserved TextureSlot parts; `surface-details.json` records their use. Ice detail tiles seamlessly; tracks are a non-tileable six-footprint strip.
- `preview-surface-details.png`: actual Blender material preview showing these alpha textures over ice and snow colors.
- `preview-all-assets.png`: normalized display scales, not actual relative sizes.
- Individual `*-preview.png`: actual mesh detail renders.
- `preview-landmark-assembly.png`: actual meshes assembled with illustrative support platforms/steps, creek plane and render-only lights. Those preview supports/effects are not exported and are not a replacement for Claude's measured layout.

## Current export sizes

Width × Height × Depth, Roblox studs. These are the generated kit's actual bounds, reconciled with the map contract.

| Asset suffix (all begin FP_Alpine_) | W × H × D |
| --- | --- |
| Lodge | 40 × 30 × 24 |
| Bridge | 10 × 7.5 × 34 |
| Cliff_Tall | 25 × 34 × 22 |
| Cliff_Wide | 29 × 20 × 21 |
| Cliff_Shelf | 28 × 11 × 24 |
| Fir_Tall | 15 × 26 × 15 |
| Fir_Medium | 11 × 18 × 11 |
| Fir_Sapling | 6 × 10 × 6 |
| Tent | 8 × 6 × 9 |
| Woodpile | 6 × 4 × 6 |
| Frosted_Shrub | 7 × 5 × 7 |
| Grass | 6 × 4 × 6 |
| Crate | 4.5 × 4.5 × 4.5 |
| Barrel | 3.5 × 4.5 × 3.5 |
| Railing | 12 × 4.5 × 1 |
| Lantern_Post | 2.4 × 7 × 3 |
| Trail_Post | 1 × 3.5 × 1 |
| Signpost | 6 × 7 × 1 |
| Pennant | 5 × 11 × 1 |
| Snow_Rock | 11 × 6 × 9 |
| Snow_Drift | 13 × 2.5 × 8 |
| Icicles | 8 × 4 × 1.3 |
| Shelf_North | 42.5 × 10 × 23.5 |
| Shelf_South | 29 × 10 × 15 |
| Gorge_Rock | 12 × 11 × 50 |
| Cliff_Block | 14 × 12 × 12 |
| Snow_Rock_Small | 5 × 3.5 × 4.5 |
| Camp_Sled | 5 × 2 × 3 |
| Notice_Board | 4 × 5 × 1 |
| Terrace_Post | 2 × 7.5 × 2 |

## Import/integration

1. Use the current manifest and Claude asset request, not the first draft. Do not non-uniformly resize the assets to stand-in bounds. Preserve manual .blend edits before regeneration.
2. Import the bundle in Studio Edit mode using 3D Importer. Keep separate named meshes; include textures. Validate scale against the manifest (prior project FBX imports used unexpected global conversion factors).
3. Anchor/stage the raw import under `ServerStorage.RegionImportStaging.AlpineOutpostBundle`. No raw display gallery should remain in Workspace during Play.
4. Preserve native MeshSize, actual asset IDs and material data when capturing the new `FrostbiteAlpineTemplates.rbxm` library. Keep the existing `FrostbitePropTemplates.rbxm` intact.
5. Verify material import. If FBX supplies only base color, apply uploaded `alpine-normal.png` and `alpine-roughness.png` with SurfaceAppearance along with the color map. Do not assume the optional maps automatically imported correctly; no uploaded texture IDs are provided by this task.
6. Clone native templates at explicit sites. Decorative meshes are anchored, non-colliding, non-touching and non-queryable. Claude owns ground, stairs, porch/bridge support proxies, creek surface and gameplay.

Authoring axes: Blender +Y front/+Z up → Roblox -Z front/+Y up. Individual mesh coordinates have a bottom-center origin. Native MeshPart CFrame is at bounds center; account for height/2 once when placing against a base frame. Imported model pivots may need separate handling.

Sockets are in `sockets_roblox_xyz_from_base`. Apply the site's rotation and uniform scale:

- Lodge: DoorBase, PorchStep and PorchEntry for walking support; ChimneyTop, WindowW/E/Gable, AnnexWindow and PorchLanternW/E for runtime effects. Porch top is 1.0, step top 0.5. The annex is on local -X (viewer-right).
- Bridge: NorthDeck, SouthDeck and DeckMiddle plus LanternNW/SE. The visual deck top is 1.5 at the ends and 0.3 at its center; place the base 1.5 below the shelf top. Both landings need accessible connections.
- Shelf_North/South: BridgeLanding and sign/rail/stair sockets, with walking top 8.5. The north shelf's L-shaped gorge void is empty.
- Cliff_Tall/Wide/Block: TopMount at exact asset height with a flat 5 × 5 support area.
- Lantern post: Light.
- Fir/pennant: TrunkBase/PoleBase; especially important when asymmetric banner bounds move the bottom-center origin away from the pole.
- Railing: EndLeft/EndRight. Signpost: optional runtime-text placement hints, not prewritten sign content.

No collisions, moving cloth, smoke, window glow, game lighting or bridge physics are baked into the FBX. Glazing is recessed dark amber, as Claude requested; add runtime warm panes/lights at the sockets rather than making the entire lodge Neon. The shared material is nonmetallic by default; hardware has color/roughness separation.

## Reproduction

Use Blender 5.1:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/create_alpine_props.py
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/verify_alpine_props.py
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/render_alpine_landmarks.py
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/render_alpine_previews.py
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/create_alpine_surface_details.py
```

Generator refuses to overwrite an existing .blend unless passed `-- --rebuild`. `--no-render` skips previews. The validator independently reimports every FBX and the bundle, checking required names, bounds, bottom origins, topology, UV tile containment, texture resolution, triangle counts and coordinate conversion. Ray tests also verify porch/step heights, bridge ends and center, shelf tops and empty gorge, and cliff mounting pads. Re-run after geometry/export edits. Render-only changes do not require a geometry revalidation.

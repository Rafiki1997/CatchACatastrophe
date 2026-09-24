# Thunderworks electrical-yard prop kit

Eight reusable Blender meshes, built and validated on 2026-09-21 for the Claude
base-layout handoff. Art direction: chunky graphite/teal electrical equipment,
copper conductors, cream ceramic insulators and restrained yellow accents.

**Integrated 2026-09-21:** eight native mesh types placed at all 33 Thunderworks
sites. Source library: `src/server/Map/ThunderPropTemplates.rbxm`.
`roblox-import.json` records native mesh IDs, sizes and the dedicated texture
`rbxassetid://119095382742673`. The raw import is anchored in
ServerStorage.RegionImportStaging, outside Workspace.

## Files

- `props.blend`: editable production meshes in EXPORT_ASSETS, separate PREVIEW_ONLY
  collection for the gallery, camera, labels and lights.
- `ThunderworksPropsBundle.fbx`: eight separate production meshes in gallery
  positions, with embedded Thunderworks palette. No display plinths or labels.
- Eight individually named FBXs: each at local ground-centre origin.
- `palette.png`: unique packed 512 x 16 palette atlas, one material/UV layer.
- `preview.png`: actual rendered mesh gallery, not an AI concept image.
- `manifest.json`: intended Roblox XYZ dimensions and per-mesh triangle counts.
- `validation.json`: fresh individual/bundle Blender FBX reimport results.

| Mesh | Width x height x depth (studs) | Triangles |
|---|---|---|
| TW_Transformer | 5.8 x 6.2 x 4.6 | 1,716 |
| TW_Ceramic_Insulator | 1.8 x 3.0 x 1.8 | 544 |
| TW_Cable_Reel | 4.0 x 4.4 x 3.0 | 4,420 |
| TW_Capacitor_Bank | 3.4 x 4.8 x 3.4 | 2,008 |
| TW_Switch_Cabinet | 3.2 x 4.6 x 1.8 | 688 |
| TW_Vent_Housing | 4.0 x 2.4 x 3.4 | 440 |
| TW_Conduit_Elbow | 3.0 x 2.5 x 2.2 | 448 |
| TW_Storm_Bollard | 1.2 x 3.0 x 1.2 | 284 |

Total: 10,548 triangles for one of each asset. Use the detailed cable reel
sparingly near paths and landmarks. Overlapping closed components are deliberate;
no mesh is supplied as a collision hull, and there are no active controls or FX.

## Placement contract

All dimensions match the handoff exactly. Ground-centre authoring origin,
Blender +Z up, -Y front; FBX/Roblox +Y up, +Z front (verified export axis transform).
Native MeshParts use bounds-centre CFrame: `frame * GroundCF * CFrame.new(0,h/2,0)`.
Normalize importer Size against manifest, preserving native MeshSize internally.
Keep every placed prop anchored and CanCollide/CanTouch/CanQuery false.

Claude owns the base layout and measured sites; Codex imports and places assets.
Handoff: `docs/art/regions/2026-09-21-thunderworks/THUNDERWORKS-CLAUDE-HANDOFF.md`.
Expected return: `THUNDERWORKS-LAYOUT.md` in that directory. Large lightning
collectors, shed, catwalk, portal and retaining-wall art await measured dimensions;
they are not part of this reusable kit.

## Studio import

ImportStaging now recognizes ThunderworksPropsBundle against the captured
ThunderPropTemplates library. For any future replacement, import in Edit,
with Upload to Roblox and Insert into Workspace, keeping eight separate meshes.
Raw galleries previously arrived unanchored at 100x scale; stage them outside
Workspace after capturing native templates and before entering Play.
Use this kit's new palette; do not reuse the Frost/Gusty/Splashwater texture ID.
Record actual mesh/texture IDs after import. All approach prop footprints must
remain at least two studs beyond roads, including the nearby Crisis spur.

## Reproduce

Run Blender 5.1 background with `--python tools/blender/create_thunderworks_props.py`.
Generation refuses to overwrite an existing props.blend unless explicitly passed
`-- --replace-generated`; preserve manual Blender edits before regenerating.
Then run `--python tools/blender/verify_thunderworks_props.py`.

Validation passed all eight files and the bundle: exact target bounds, ground and
centred origins, closed manifold topology, positive-area faces, finite vertices,
triangle counts, one material/UV, correct atlas samples and embedded image,
eight-object bundle with no preview objects. Final preview visually inspected.
Native import and placement verified with 683 headless checks, 970 Studio
self-tests and 72 live tests, all passing. All 66 mesh/texture preload callbacks
on the 33 placed MeshParts succeeded. Runtime overview and close-up inspected.
Nine visual-only lightning markers rendered above the original yard and floor
details, then cleaned up normally. Mobile frame time remains unmeasured.

The raised yard skin was removed to expose hazard warnings. The original asphalt
Ground now uses the yard colour; decorative seams/scuffs/drains stay below the
warning surface. CableReelSite03/04 stand at y=0.30 on Ground; all other anchors
retain their measured layout positions. The larger built-in landmarks remain.

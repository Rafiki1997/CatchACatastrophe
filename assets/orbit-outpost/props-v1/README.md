# Orbit Outpost — V7 Gravity Garden Blender kit

15 actual Blender meshes built for the user-approved V7 direction on 2026-09-21.
The meshes are uploaded and integrated at Claude's 51 prop sites. Native templates
are saved in `src/server/Map/OrbitPropTemplates.rbxm`; `roblox-import.json` records
the actual mesh IDs, palette texture and preserved native bounds. The raw import
is anchored in ServerStorage.RegionImportStaging, outside the playable map.

## Deliverables

- `props.blend`: editable full-scale production meshes in EXPORT_ASSETS; presentation copies, plinths, labels, camera and lights in PREVIEW_ONLY.
- `OrbitPropsBundle.fbx`: exactly 15 separate production meshes at full scale in gallery positions. No cameras, lights, labels or display plinths.
- Fifteen individually named FBX files, each at bottom-center local origin.
- `palette.png`: dedicated Orbit 512x16 palette atlas, also embedded in FBXs.
- `preview.png`: actual Blender-rendered gallery. Display scales vary; read dimension labels.
- `landmark-preview.png`: actual assembled meshes at relative production scale. No glass, runtime glow or orbit effects are shown.
- `asset-contract.json`: fixed size/role agreement for Claude's layout.
- `manifest.json`: actual bounds and triangle counts.
- `validation.json`: independent reimport and editable-scene verification.

## Fixed sizes

| AssetName | W x H x D studs | Role |
|---|---|---|
| OO_Gravity_Cradle | 16 x 22 x 16 | Three-pronged gravity machine, static structural art |
| OO_Gravity_Meteor | 6 x 11 x 6 | Faceted floating amethyst; bottom origin even while suspended |
| OO_Orbit_Stone | 2.8 x 2.4 x 2.6 | Small suspended moon rock; separate mesh for later motion |
| OO_Lunar_Boulder | 8 x 4 x 6 | Peripheral low lunar rock group |
| OO_Crystal_Cluster | 4 x 5 x 4 | Amethyst sprouts on a rocky base |
| OO_Alien_Mushroom_Tall | 6 x 7 x 5 | Large layered purple mushroom |
| OO_Alien_Mushroom_Cluster | 4 x 3 x 3 | Small companion mushroom cluster |
| OO_Alien_Fern | 4 x 3 x 4 | Purple faceted broad-leaf plant |
| OO_Star_Bloom_Tuft | 3 x 1.2 x 3 | Small cyan flower/groundcover cluster |
| OO_Survey_Drone | 3.2 x 2.8 x 3.2 | Round ivory survey drone with cyan lens |
| OO_Drone_Dock | 5 x 1.5 x 5 | Ground-supported survey drone pad |
| OO_Sample_Pod | 3 x 4 x 3 | Closed research specimen container |
| OO_Cosmic_Beacon | 1.2 x 3 x 1.2 | Small static pathway light housing |
| OO_Field_Lab_Base | 16 x 5 x 16 | Closed ivory laboratory facade with warm window inserts |
| OO_Field_Lab_Dome_Frame | 16 x 6.5 x 16 | Open dome ribs; transparent infill belongs to Claude's blockout |

Total geometry: **12,388 triangles** for one of each asset. Overlapping closed components are intentional; decorative meshes are not collision hulls.

## Coordinate and assembly contract

Blender +Z up, -Y front; supplied FBX exports +Y up and Roblox +Z front.
One modeling unit is one intended stud; Roblox importer can alter scale. Normalize each native MeshPart.Size to manifest dimensions after upload, preserving its native MeshSize.
All objects use bottom-center authoring pivots. Roblox MeshPart.CFrame uses bounds center:
`frame * GroundCF * CFrame.new(0, AssetSize.Y/2, 0)`.
GroundCF is region-local even for a suspended object.

- Cradle bottom is the permanent dais top. Meteor bottom sits 7 studs above cradle bottom; its top is 18 above cradle bottom, within 22-stud-high prongs.
- Stones are separate and intentionally suspended. Initial stone lower bounds sit 10 above cradle bottom. Keep all pieces anchored.
- Lab dome bottom sits exactly 5 above lab base bottom, sharing its XZ center and yaw.
- Drone feet sit at dock top, 1.5 above dock bottom.
- Palette colors do not create Neon, lights, glass or animation. Claude owns separate dome glazing and transparent boundary panels. Codex may add restrained local emissive accents during integration.
- Lab facade is closed. Do not imply there is an accessible interior or working research UI.

Placed art defaults: Anchored=true, CanCollide=false, CanTouch=false, CanQuery=false. Use independent permanent collision in the base layout.

## Import and integration

ImportStaging recognizes the complete fifteen-mesh `OrbitPropsBundle` and the
`OrbitPropTemplates` library. The integration uses native clones rather than
constructing replacement MeshParts from asset IDs.

Import in Edit mode, Upload to Roblox and Insert into Workspace, retaining 15 separate meshes and the unique Orbit palette. The raw gallery may be oversized and unanchored. Capture real native uploaded MeshParts, anchor them, clear assembly velocities, normalize size and move the raw bundle into ServerStorage before any Play session. Avoid opening Explorer windows as an automation workaround.
Do not reuse another region's texture ID or invent asset IDs. Validate imported surface appearance and intended dimensions in Studio.

Place at Claude's exact PropSites and replace ONLY PlaceholderArt. Retain Boundary, Walkways, collision proxies, LabGlazing and support geometry. Check full oriented bounds against capture space, signs, gates and roads, including a two-stud road edge clearance.

## Validation completed

15 individual FBXs and the bundle reimported successfully in Blender 5.1.2:
- intended bounds within 0.005 stud, identity scale, centered X/Y and bottom Z origins;
- finite coordinates and expected triangle counts;
- closed manifold edges and positive-area faces;
- one material, one UV layer, palette cell-center UVs, embedded 512x16 texture;
- exactly 15 meshes in the bundle; no presentation objects;
- editable production blend retains full-scale geometry.

Gallery, assembled mesh previews and actual Studio placements visually inspected.
The imported kit passed 968 self-tests and 72 live tests, including field and road
clearance. An explicit native mesh audit verified all 51 placements, dimensions,
anchoring, palette/native IDs and removal of temporary art. Six scenery lights
were retained (the region also has four sign/gate lights). No commit or publish.
The close-up review identified a visible square lab collision proxy and dome/glass
overlap; the base generator now hides that proxy and insets the glazing.

## Reproduce

Run from `C:\Users\nguye\Documents\repos\catch-a-catastrophe\CatchACatastrophe` using Blender background mode:
- `--python-exit-code 1 --python tools/blender/create_orbit_props.py`
- `--python-exit-code 1 --python tools/blender/verify_orbit_props.py`
- `--python-exit-code 1 --python tools/blender/render_orbit_landmarks.py`

Generator refuses to overwrite an existing props.blend unless `-- --replace-generated` is provided; preserve manual edits before doing so.

Claude handoff: `docs/art/regions/2026-09-21-orbit-outpost/ORBIT-OUTPOST-CLAUDE-HANDOFF.md`.
Expected measured return: `ORBIT-OUTPOST-LAYOUT.md` in that folder.

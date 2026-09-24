# Splashwater Bay Blender kit

Eight reusable meshes built for the existing harbor/lagoon region, using cool
slate, navy paint, warm wood, cream rope and coral accents. `preview.png` is a
render of the actual Blender geometry. No image-generation stand-ins.

Deliverables: editable `props.blend`, eight individual FBXs, embedded and external
`palette.png`, a dimension/triangle `manifest.json`, and `validation.json`.
`SplashwaterPropsBundle.fbx` contains all eight separate meshes in a display grid.
Individual FBXs have ground-centre origins; Blender Z-up exports to FBX Y-up.

| Asset | Placement target |
|---|---|
| SB_Coastal_Rock_Wide / Tall | TideRock ring dressing; retain existing collision proxies |
| SB_Driftwood | Sandy margin beside the skiff, clear of entry and boardwalk |
| SB_Shell_Cluster | SeaShell + ShellRidge groups along the perimeter |
| SB_Starfish | Five StarfishArm assemblies along the perimeter |
| SB_Rope_Bollard | MooringPost + MooringCap assemblies; preserve rope connections |
| SB_Harbor_Barrel | Lighthouse/skiff dressing outside the playable corridor |
| SB_Marker_Buoy | Decorative shallow-lagoon marker |

These props do not replace the lighthouse, skiff, sign, water surfaces, boardwalk
or continuous region barriers. Do not add solid geometry inside the spawn field.
Use decorative MeshParts with CanCollide/CanTouch/CanQuery disabled and preserve
the tested layout collision below them.

## Import

Imported and integrated on 2026-09-20: all eight variants appear as 63 props.
`roblox-assets.json` records the uploaded IDs. Native templates are saved in
`src/server/Map/SplashwaterPropTemplates.rbxm`; `GardenBayProps.luau` places them.
Studio applied a 100x conversion, corrected before saving. Preserve native
MeshSize: assigning only MeshId and Size does not retain imported render bounds.

The bundle contains mesh objects only; preview discs, labels, floor, lighting
and camera are excluded. All mesh/texture IDs load successfully on the client.
Studio overview and shoreline detail inspected; 930 self-tests and 72 live
checks pass, including sign/field clearance and safe decoration flags.
Mobile frame cost is not measured.

## Rebuild and validation

Run `tools/blender/create_garden_bay_props.py` with Blender 5.1, then
`tools/blender/verify_garden_bay_props.py`. Generator refuses existing .blend
files by default. `--replace-generated` overwrites generated outputs and must
not be used after hand editing without first preserving those edits.
Validation reimports every FBX and checks dimensions, triangles, ground origin,
closed topology, positive face areas, one material, one consistent palette UV
layer and the embedded image; it also checks the bundle's eight mesh names.
Overlapping closed components are intentional; these are decorative meshes.

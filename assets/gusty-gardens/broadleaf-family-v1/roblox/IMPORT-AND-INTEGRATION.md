# Gusty Broadleaf — native integration and reimport instructions

## Current state

**Completed 2026-09-23:** the user uploaded the nine meshes and three PBR maps. Captured `GustyBroadleafTemplates.rbxm` (235,263 bytes), recorded actual IDs in `roblox-import.json`, synced it and verified all35 perimeter replacements /105 MeshParts in Play. Original collision proxies are retained; old crowns are gone. See `integration-status.json` and actual Studio screenshots in this folder. Studio is back in Edit; no publication. Instructions below are retained for future reimports, not a request to upload this kit again.

The imported native geometry is **100x scale and rotated180 degrees around Y** relative to export-local vertices. The rotation was checked on 180+ uploaded-mesh vertex samples for each of nine components, with corrected max error below0.000004 studs. Saved samples and report can be rechecked using `tools/blender/verify_gusty_native_orientation.py`. Capture must set library attribute `NativeMeshYawDegrees` to the measured correction; `GustyBroadleafProps` refuses an unverified library. Do not assume this import's scale or orientation for future kits.

## Import the prepared file

1. Keep Studio in **Edit**. Import `GustyBroadleafBundle.fbx` from this directory using the native 3D importer.
2. Preserve the nine separately named meshes and textures. Use the intended asset Creator and upload the meshes to Roblox. Verify destination experience permissions; do not infer ownership from a previous group's upload. Do not publish the place.
3. Keep the root model named `GustyBroadleafBundle`. Anchor the imported art. Avoid leaving an unanchored raw gallery in Workspace or starting Play before capture. Gallery x offsets are for inspection, not tree placement.
4. Confirm Wood + Leaves_1 + Leaves_2 for each of A, B and C, and color/normal/roughness maps. The external PNGs are beside the FBX if the importer needs them.

The bundle's nine names are enumerated in `manifest.json`. Inspect actual native dimensions against that manifest; **do not reuse the Powder Fir import scale**. Any nonuniform distortion is a failed import, not something to compensate for by stretching individual parts.

## Agent pickup after import

1. Read current AGENTS/RELAY and check Studio mode. Inspect the actual uploaded MeshIds, native MeshSize, displayed Size, maps and complete bundle membership.
2. Run `tools/studio/prepare_region_templates.luau` in plugin/command context using the actual bundle, this manifest's `assets` array and `GustyBroadleafTemplates`. It clones native MeshParts, verifies a consistent import ratio, normalizes Size and preserves native geometry/maps. Author RenderFidelity there; runtime only clones it.
3. Verify native vertices against the exports and set library attribute `NativeMeshYawDegrees` (0 or180). Serialize the returned real library to `src/server/Map/GustyBroadleafTemplates.rbxm` using the existing SerializationService/local-capture workflow. Record genuine IDs, maps and measured conversion in `roblox-import.json`. Do not fabricate these files from manifest-only geometry.
4. Stage the anchored raw gallery in `ServerStorage.RegionImportStaging`. `ImportStaging` recognizes all nine exact names and preserves partial/unknown imports; quarantine also recognizes the new library.
5. Rojo sync and read back the native library and script source. Start Play and verify `Workspace.Map.Regions.gusty_gardens.BroadleafTrees`: 35 Models, 105 MeshParts, A12/B12/C11, zero remaining `PlaceholderArt` at the 35 sites, invisible retained trunk collision proxies. Each component uses `worldRootCF * CFrame.new(manifestCenter * siteScale) * nativeRotation` and matching Size, leaving MeshSize intact.
6. Preload all placed mesh/map assets and inspect actual player-distance and close-up appearance under game lighting. Confirm root contact, original routes/fields and animation of unrelated mill parts, then profile representative populated views. Record hardware/settings and actual results.

`GustyBroadleafProps` validates the entire native library and all 35 sites before cloning anything into the region; rejected kits keep the current art. Its baseline does not change the 17 perimeter pines or the older five interior windbent trees from `GardenBayProps`. These are separate later restyle work, as are rocks, flowers, shrubs and windmills.

## Evidence already available

- `validation.json`: independent FBX imports; source/export images in parent/current folders.
- `tools/verify_gusty_broadleaf.luau`: 4,000 checks, including measured original fallback geometry, multipart offsets, bounds, proxies, preservation and rejection cases.
- Actual pre-import Studio smoke test: all 35 original trees remained present and solid proxies intact. SelfTest1004/16, LiveTest63/2, same pre-existing failure set. This is fallback evidence, **not native visual/integration evidence**.

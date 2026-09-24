# Powder Fir import and replacement

**Completed 2026-09-22:** all three variants are imported, captured into `src/server/Map/FrostbitePowderTemplates.rbxm`, synced through Rojo and verified in Play. All 91 Frostbite trees now use the approved models (A31/B30/C30; 425 mesh instances), with zero old tree placeholders. Preload returned 425 successes and zero failures. IDs/maps are recorded in `roblox-import.json`. No further import is needed.

Raw galleries are preserved under ServerStorage.RegionImportStaging. Oversized imported bounds were normalized during native capture. Runtime inherits Automatic RenderFidelity and reads the public ColorMapContent URI.

## Import procedure (reference for future revisions)

1. Stay in Edit mode and open the 3D Importer.
2. Choose `PowderFirsBundle.fbx` in this folder.
3. Enable Upload to Roblox. Choose the intended Creator (the group if these should be group-owned).
4. Keep all **14 named meshes separate**, with textures, and upload/insert the bundle as **PowderFirsBundle**.
5. Tell Astra the import is finished. There is no need to place individual trees manually.

The tree family has 5 components for A, 4 for B, and 5 for C. Each part stays below 20,000 triangles. The bundle embeds the shared 2048 color/normal/roughness maps; verify SurfaceAppearance map wiring after Studio import. Adjacent PNG files are also supplied. `PowderFirsRoblox.blend` is the optimized source; the approved high-detail source remains one folder above.

Studio currently reports Catch a Catastrophe place 88888194204730 as **user-owned** (CreatorId 1445842194), not group-owned. Selecting a group in the importer does not transfer the experience. If group upload requires granting this experience asset usage, verify those permissions before playtesting.

## Capture procedure (completed for this version)

- Inspect exact 14 component names, mesh/texture IDs and uniform import scale.
- Stage the raw gallery safely. Use `tools/studio/prepare_region_templates.luau` with this manifest's `assets` array to clone native MeshParts into `FrostbitePowderTemplates`.
- Serialize the real native library to `src/server/Map/FrostbitePowderTemplates.rbxm` and record IDs in a `roblox-import.json`. Do not reconstruct mesh objects or fabricate IDs.
- Rojo-sync and read back before entering Play. Verify 91 replaced tree sites, 425 mesh instances, 31/30/30 variant distribution and no old visible firs.
- Read SelfTest/LiveTest results, inspect all three variants and cliff-top/flank placements, check texture loading and actual frame time, then leave Studio in Edit.

## Placement contract

The new module operates independently of the large Alpine kit's capture status. It replaces both placeholder firs and native Alpine firs, validating the entire tree kit before removal. It preserves old site metadata, support paths, original trunk anchors, and collision proxies. A uniform scale fits every new crown inside the old site envelope, so the Broad variant can be shorter than neighboring variants. Other regions and non-tree scenery are unchanged.

Three trees together contain about 141k triangles after optimization versus about 979k in the approved source. Every modeled needle is retained with simpler closed geometry; snow topology is reduced and the original bark is preserved. Repeated placement still requires a real runtime performance check. Roblox RenderFidelity is Automatic.

## Validation

- `validation.json`: independent FBX round-trip names, dimensions, component centre offsets, triangle counts, UVs/maps and bundle completeness.
- `lune run tools/verify_powder_firs.luau`: 11,151 checks using native fixtures **in memory only**, including all 91 sites, bounds, trunk anchors, missing/invalid kit rejection, placeholder and native replacement, protected non-tree parts and import staging.
- Existing Alpine layout: 8,694 checks. Source structure/quote scans and Rojo build passed.
- Actual meshes and overview/close-up Studio appearance verified; this experience loaded all placed trees. Full SelfTest still reports 16 failures and LiveTest 2 outside this tree replacement; tree checks pass. Mobile performance and other experiences' asset permissions remain unverified. Studio left in Edit; nothing committed or published.

# Codex account transfer — Catch a Catastrophe

Prepared September 22, 2026. Read this, then `AGENTS.md` and the newest checkpoint in `RELAY.md`. All relative paths below are relative to the active repository.

## Start here

**Active repository:** `C:\Users\nguye\Documents\repos\catch-a-catastrophe\CatchACatastrophe`

The previous conversation's environment sometimes opened the older checkout at `C:\Users\rahul\orca\workspaces\Catch-a-Catastrophe\Catch-A-Catastrophe`. Do not implement or run Rojo there. This project's AGENTS.md requires working in the active repository above.

Rahul is switching Codex accounts. Continue the same project without restarting design exploration. User selected **Cinder Quarry (option 03)**. Astra/Codex creates mockups and custom Blender assets; Claude implements map code and integrates art. Coordinate with Rahul before duplicating work Claude is already doing. The immediate remaining work is getting the completed Cinder and Splashwater kits into Studio and verifying the integrated result.

**Important reconciliation:** Claude has now implemented the Cinder Quarry base. His newest implementation checkpoint says the meshes do not exist yet; that sentence is stale. All twelve custom meshes are delivered and validated. Conversely, Astra's older asset checkpoint says Claude still needs to build the base; that is also stale. Both the base and the Blender kit now exist; native import, socket reconciliation and live verification remain.

## Completed and available

### Cinder Quarry — highest priority

- Approved image: `docs/art/regions/2026-09-22-cinder-canyon/cinder-canyon-v1-03-cinder-quarry.png`.
- Claude implementation contract: `docs/art/regions/2026-09-22-cinder-canyon/CINDER-QUARRY-CLAUDE-HANDOFF.md`.
- Claude's actual layout, measured camera and comparisons: `CINDER-QUARRY-LAYOUT.md`, `concept-measured-grid.png`, `build-refcam.png`, `build-mine-terrace.png`, `comparison-concept-vs-build.png` in that same directory.
- Implemented modules: `src/server/Map/CinderCanyon.luau`, `CinderQuarryAssetSpec.luau`, `CinderQuarryProps.luau`; associated wiring is already in RegionScenery, MapBuilder and Regions config. Do not rewrite the base from scratch.
- Base has 136 explicit asset sites and 59 separate collision proxies. Its replacement module validates the entire `CinderQuarryTemplates` kit before swapping placeholders.
- Delivered art folder: `assets/cinder-canyon/quarry-v2/`.
- Files: `CinderQuarry.blend`, `CinderQuarryBundle.fbx`, twelve individual FBXs, `quarry-palette.png`, `manifest.json`, `validation.json`, `README.md`, `preview-all-assets.png`, `preview-landmark-assembly.png`, twelve detail previews.
- Twelve types: mine, terrace, hoist, cart, rail, large/low mesas, tall/round cacti, agave, flowers, crate. Exact names and dimensions are in the manifest and README.
- Blender reimport verification passed: **16,368 unique triangles**, correct dimensions/base origins, closed geometry, palette UVs/textures and axis conversion. Actual Blender renders were inspected. This does not establish Studio appearance or runtime correctness.
- Claude reports 1,723 passing headless placement assertions, successful structure/quote scans and Rojo build. These are prior recorded results, not freshly rerun during transfer.
- No `src/server/Map/CinderQuarryTemplates.rbxm` exists at transfer time. The older `CinderPropTemplates.rbxm` exists and must be preserved.

### Splashwater Bay — delivered, integration still pending

- Approved design: **option 03, Tropical Tidepools**.
- Reference: `docs/art/regions/2026-09-22-splashwater-bay/concept-tropical-tidepools.png`.
- Base layout and comparisons: `SPLASHWATER-BAY-LAYOUT.md` and `comparison-concept-vs-build.png` in that directory. Claude already rewrote the base in `src/server/Map/SplashwaterBay.luau`.
- Delivered folder: `assets/splashwater-bay/tidepools-v2/`.
- Read `CLAUDE_ASSET_HANDOFF.md`, `README.md`, `manifest.json`, and `validation.json` there.
- Import bundle: `TropicalTidepoolsBundle.fbx`; editable source: `TropicalTidepools.blend`.
- Eight assets: grotto, cascade rocks, three palms, two tropical leaf clumps and hibiscus. **13,656 unique triangles**, Blender validation passed. Includes eight optional simple collision hulls and optional separate trunk/crown meshes.
- Old `assets/splashwater-bay/props-v1/` and `src/server/Map/SplashwaterPropTemplates.rbxm` are still needed; their existence does not mean the new tidepools kit is imported.

## Remaining work, in order

### 1. Verify connection and current work ownership

- Re-read RELAY.md because Claude may have progressed since this document was written.
- Rediscover Studio through available MCP tools; account changes can require reconnecting tools. Do not assume old Studio IDs remain valid.
- At transfer: official MCP sees place **88888194204730**, Studio **Edit mode**, instance `99b13aa3-ba7f-4476-b5d2-5840f635c1bb`.
- A Rojo listener was observed on **127.0.0.1:34872**, PID 24736, running `rojo serve default.project.json --port 34872`. Recheck before launching another server. Listener presence does not prove the Studio plugin is connected or source is current.
- Connect the Rojo plugin to localhost:34872 if necessary, and confirm source read-back before Play. Stop Play before editing scripts. This transfer did not alter Studio or verify live script contents.

### 2. Import and integrate Cinder's completed kit

- In Studio Edit mode, import `assets/cinder-canyon/quarry-v2/CinderQuarryBundle.fbx` through the 3D Importer with twelve separately named meshes and the palette material. Upload under the appropriate game owner. There was no callable local-FBX upload API available in this session; if that remains true, the user must perform the importer step.
- Check exact sizes against the manifest. Earlier project imports arrived **100 times too large**. Correct scale uniformly, preserving native mesh data.
- Stage the raw gallery as `ServerStorage.RegionImportStaging.CinderQuarryBundle`, safely anchored. Gallery offsets are not map placements.
- Capture real native templates to `src/server/Map/CinderQuarryTemplates.rbxm`. Retain MeshSize, actual uploaded mesh IDs and texture data. Never fabricate IDs or use fixture meshes as production art.
- Reconcile `CinderCanyon.luau` with the delivered sockets. It currently contains provisional `MINE_DOOR`, `HOIST_BASE`, `LAVA_LIP`, `LAVA_FOOT`, tier faces and `SocketProvisional` site attributes. Changing only the template library is insufficient.
- Manifest final local offsets from the asset bottom frame include:

| Socket | X, Y, Z |
| --- | --- |
| Mine DoorBase | -0.2121, 0, -19.5395 |
| Terrace HoistBase | 3.9204, 36, 9.501 |
| Terrace LavaUpperLip | -24.0018, 20, -10.4575 |
| Terrace LavaLowerLip | -24.0018, 10, -18.8611 |
| Terrace LavaFoot | -24.0018, 0.5, -26.2142 |

- Read the manifest rather than relying on this copied table if assets change. Derive rails/cart from DoorBase as the handoff specifies; derive hoist and separate lava effects from final terrace sockets. Update support/clearance checks where those positions change.
- The delivered terrace's lava channel is on **local -X, outer/image-right**. The hoist support is at Y=36, not the placeholder's Y=25. Inspect actual geometry and contact points.
- Keep lava, lights and mineral effects separate from mesh art. Assembly-preview sand/lava/lights are illustrative and are not in the FBX. Avoid duplicate effects or effects buried inside rocks. Claude noted that the placeholder lava pool's kerb hides it at player height; resolve that during visual QA.
- Preserve permanent collision proxies, progression and the complete-kit atomic swap. Confirm staging recognizes the new bundle and records native import metadata.

### 3. Integrate Splashwater's completed kit

- Follow its `CLAUDE_ASSET_HANDOFF.md`; import and stage the eight-mesh bundle, then capture native templates as a separate library or deliberately merge all sixteen old/new types.
- Replace entire grotto/cascade and palm/plant assemblies, not each primitive leaf. Remove obsolete visible cave-mouth fill so the new opening remains open.
- Use authored bounds and explicit base frames, not placeholder bounds that include foam or surrounding boulders. Align water drops and pools to the new sockets; retaining old effect coordinates can bury the water in rock.
- Keep old small-prop assets, gameplay and functional collision intact. Optional grotto collision hull encloses the opening, so do not blindly apply it as a walkable cave collider. Split palm crowns are optional, not a required scope expansion.

### 4. Verify integrated regions in the actual game

- Run relevant lint/quote scans, Rojo build and headless harnesses after source changes. Existing commands include `python tools/luau_lint.py src`, `python tools/quote_scan.py src`, `lune run tools/world_harness.luau`, and `lune run tools/verify_cinder_placement.luau`.
- Confirm synced source/native libraries before Play; inspect `[SelfTest]` and `[LiveTest]` output. Preserve ground tops so hazard warnings remain visible.
- Check mesh/texture loading, exact scale, whole-kit replacement, collision, spawn clearance, both gate approaches and per-player locked/unlocked behavior. Cinder entry stays 15K, Frostbite exit 75K; Splashwater entry stays 2.5K.
- Capture matching reference-camera screenshots and player-height views. Compare with the approved images; passing structural tests alone is not visual acceptance. User has repeatedly rejected implementations that looked unlike the mockup.
- Verify Cinder's dry center/24-stud route, mine/cart alignment, hoist support and visible outer-right lava. Prior placeholder analysis gave 64% open raw-cell area / 66.6% inside walls; re-evaluate after integration rather than declaring the target universally met.
- Update RELAY.md with actual checks, screenshots, remaining limitations and Studio state. No commit or game publish unless explicitly requested.

## Other backlog — preserve, do not silently expand current scope

- **Pocket Power Town plot art:** Claude's measured plot and swap code exist, but this repository has no `assets/player-plot/` delivery and no `PlotPropTemplates.rbxm` at transfer. Outstanding twelve-asset request: `docs/art/plots/2026-09-21-player-plot/POCKET-POWER-TOWN-ASSET-REQUEST.md`. Read `PlotAssetSpec.luau` and the approved concept before modeling; check whether another account has since delivered it. Its authoring-front wording differs from the proven region export setup, so verify the transform rather than copying axis signs blindly.
- **Lobby/world:** keep the circular lobby, inward-facing plots with independent paths to the fountain, and City Relaunch/rebirth, Catastrophe Atlas and Upgrade Workshop. Regions extend along a straight northbound unlock chain. Do not revert to regions around the lobby or plot entrances leading through other plots.
- Gusty Gardens was implemented; older Frostbite, Thunderworks and Orbit assets/native libraries already exist. RELAY.md contains their prior integration and runtime checks. Do not rebuild them based on older mockup requests. Further redesign or atmosphere work needs Rahul's direction.

## Geometry and tooling rules worth preserving

- Current region cells are **280 wide by 200 deep**. Region-local **+X is image-left/west**, **+Z north/next region**, **-Z south/previous**. Do not infer left/right from raw world axes.
- Delivered region art: Blender +Y front/+Z up exports to Roblox -Z front/+Y up. Individual meshes use a bottom-center origin. Native MeshPart CFrame is bounds-centered: use bottomFrame times `CFrame.new(0, height/2, 0)` once, accounting for any imported model pivots.
- Clone native templates to preserve MeshSize. Decorative meshes stay anchored and non-touching/non-queryable; deliberate proxies supply collision.
- Blender executable: `C:\Program Files\Blender Foundation\Blender 5.1\blender.exe`.
- Cinder scripts: `tools/blender/create_quarry_props.py`, `verify_quarry_props.py`, `render_quarry_landmarks.py`.
- Bay scripts: `tools/blender/create_tidepools_props.py`, `verify_tidepools_props.py`.
- Generators protect existing .blend files unless explicitly passed `-- --rebuild`. Preserve hand edits before regeneration. Do not regenerate finished kits just to resume the session.
- The repository has substantial uncommitted and untracked work, including source modules and native libraries. Preserve it; no clean/reset/delete sweep. Read `docs/CONTRACTS.md` before changing module interfaces.

## Suggested first message to the next Codex account

> Read `C:\Users\nguye\Documents\repos\catch-a-catastrophe\CatchACatastrophe\CODEX-ACCOUNT-HANDOFF.md`, then AGENTS.md and the latest RELAY.md. Continue from the current files. Cinder Quarry's base and twelve Blender assets are finished; native import, final socket integration and Studio visual/runtime checks remain. Splashwater's eight-asset kit is also delivered and awaiting integration. Check what Claude has completed since this handoff before changing implementation. Preserve all existing work and do not commit or publish.

Transfer verification was read-only except for this document and a RELAY.md checkpoint. No source, assets or Studio state were modified, and no game checks were rerun during the transfer.

# Catch A Catastrophe — Agent Relay State

## Starting-area remodel: bush mockup ready for review — 2026-09-24

- **Request:** remodel the starting area (town island and plots). First, all its trees should match the Gusty Gardens trees, and the bushes should get the same style.
- **Proposed plan, not approved:**
  - Phase 1: reuse the uploaded Gusty broadleaf A/B/C meshes at the 38 island-rim and 24 plot tree sites. A new hub placement module, keeping hidden trunk colliders.
  - Phase 2: a new bush kit for 75 sites (7 hub garden, 2 Atlas planters, 66 plot fences), which needs a user upload.
  - Open decisions: rim trees become broadleaf; `PP_Round_Tree` and `PP_Shrub_Cluster` leave Astra's plot kit (12 -> 10); the bush design.
- **User asked to see the bushes first.** Delivered `assets/hub/bushes-v1/`: `HubBushes.blend` with Garden Bush, Planter Shrub and Border Bush, built with the broadleaf's leaf, bark and materials. Also a before/after lineup, close-ups, and five matched before/after views in the real layout, rendered from a world-harness dump with the broadleaf trees placed too. All components are closed; see the README for sizes, triangles and review points.
- **Tools:**
  - New: `tools/blender/create_hub_bushes.py`, `render_hub_bush_context.py`, `compose_hub_bush_mockup.py`.
  - `world_harness.luau` dumps now carry a `full` ancestry path (additive).
  - `render_region_blender.py` runs `main()` only as `__main__`, so it can be imported.
- **Not done:** no `src/` change, no Studio action, nothing committed or published. **Next:** the user reviews the mockup and the three decisions.

## Kid-friendly UI restyle — 2026-09-23

- **Request:** make the whole client UI read as a bright, colourful kids' game in the style of `docs/art/UIReferences/IconSample.png` (candy colours, glossy chunky tiles, light text with a heavy dark outline), readable on desktop and phones.
- **Spec / plan:** `docs/superpowers/specs/2026-09-23-kid-friendly-ui-design.md`, `docs/superpowers/plans/2026-09-23-kid-friendly-ui.md`. Task briefs, reports, audit JSON and screenshots: `.superpowers/sdd/2026-09-23-kid-friendly-ui/`.
- **Merged:** `main` fast-forwarded to `ae39447`; the branch is deleted.
- **Follow-up refinements on `main`:**
  - `1351985`: the user's playtest asks, each mocked up live in Studio first.
    - Creature cards are 136 px, so the income line is no longer covered by the buttons. Name, income and pad status use outlined Fredoka, and the button row has 12 px gaps.
    - `W.badge` pills are glossy outlined white Fredoka and show plain names.
    - The favourite button is ☆ off and a white ★ on gold when on, with a "can't be sold" tooltip.
    - Sidebar captions are raised 6 px.
  - `726c6c5`: `tools/studio_mcp.py` refuses `play` unless Studio is in Edit, and refuses `stop` unless it started the session (`--force` overrides).
    - Why: `start_stop_play` toggles regardless of `is_start`. A blind `play` ended a user test session at 17:31 UTC, which is how the guard came about.
  - `6869c72`: rarity glyphs are now ● ◆ ★ ❖ ☀ ✿ ◎ ◉, each seen rendering in FredokaOne, GothamMedium and GothamBold. `verify_theme` fails any glyph outside that verified set (440/0 on committed HEAD, 442/0 with the Epic row in the working tree).
    - Only the glyph swaps were committed. The other session's uncommitted tier work in `Rarities.luau` (Epic tier, re-rank, egg tiers) stays uncommitted and now carries the new glyphs.
    - The same applies to `CreaturesPanel.luau`'s uncommitted View button: `1351985` holds only the restyle lines.
  - Live check after these commits: SelfTest 1005/16 and LiveTest 63/2 (baseline). The widened audit shows 0 failures at scale 1; the dark-on-dark favourite buttons are gone. Phone mode shows only Atlas (pre-existing).
  - Screenshots are in `.superpowers/sdd/2026-09-23-kid-friendly-ui/restyle2/`, and the mockups in `mockup/`.
- **Commits (branch `feature/kid-friendly-ui`):** `0bee4ac` tools: StudioMCP stdio client and live UI audit; `a634412` Theme candy palette, per-panel colours and icon slots; `6c2ccbb` Widgets outlined text, gloss, shadows and per-panel colours; `ace809e` viewport preview lighting colours in Theme; `30babd7` icon-tile sidebar grid and the Astra icon request; `1202878` readability fixes from the full Studio pass (`W.label` honours `visible`, which removes an empty navy tooltip pill at the top-left; Relaunch lists and notices in white/yellow; the one text overflow fixed; forecast chips and build/data pills centred). Final-review fixes: `6991e4f` shadows sit strictly below their target, `W.setTileSelected`, and roomier sidebar gutters (gap 14, padding 6/6/12/14); `037c3e9` `accentAlt` (60,200,255) -> (60,206,255) to clear 2:1 on every panel colour; `ae39447` the audit covers every ScreenGui, adds `dark-on-dark` and an `AUDIT_PHONE` simulation, and verify_theme checks the 2:1 bar, the shared isLight expression and exact sizes.
- **Evidence, baseline -> final:** SelfTest **1005/16 -> 1005/16**, LiveTest **63/2 -> 63/2** (all failures are the recorded region/route checks). `tools/ui_audit.luau`: no-outline **132 -> 0**, text-overflow **1 -> 0** (RelaunchPanel "YOU LOSE" list), at scale 1 and at the forced phone scale 0.7; 11/11 panels have their candy colours and a shadow; sidebar is a 2-column grid (7 tiles on the test profile). `lune run tools/verify_theme.luau` 223/0; structure/quote scans and the Rojo build pass. The selected tile's white rim was confirmed live by clicking tiles with StudioMCP `user_mouse_input`.
- **Final-review pass (after `ae39447`):** SelfTest 1005/16, LiveTest 63/2; `verify_theme` 423/0 (up from 223 with the new checks). The widened audit (every ScreenGui) finds 0 no-outline and 0 overflow at scale 1 and in phone mode; the only failures are the 6 CreaturesPanel favourite buttons (`dark-on-dark`, deferred below) and, in phone mode only, AtlasPanel (`phone-offscreen`, deferred below). `AUDIT_PHONE = { width = 844, height = 390 }` gives scale 0.7 and a 1206x557 design space. Every HUD SafeArea child and 10 of 11 panels fit, and the sidebar scrolls (canvas 398 in a 383 frame). Evidence: `final-fix-report.md`, `final2-uiaudit.txt`, `final2-rim-creatures.jpg`, `final2-hud-phone.jpg`.
- **Evidence caveat:** the live Studio evidence (SelfTest/LiveTest, audits, screenshots) ran on the branch plus other sessions' uncommitted edits, because Rojo serves the dirty tree. The committed tree was verified headless on its own: verify_theme, lint, quote scan and rojo build all pass from a clean worktree.
- **Manual check for the user:** Studio → Test → Device Emulator → a landscape phone: open HUD, Creatures, Relaunch, Atlas.
- **Screenshots:** `.superpowers/sdd/2026-09-23-kid-friendly-ui/final-hud.jpg`, `final-hud-phone.jpg`, one `final-<panel>.jpg` per panel (atlas, recipes, cities, relaunch, crisis, settings, supply, premium, creatures, quests, workshop), `final-rim-creatures.jpg`, `final-rim-relaunch.jpg`, `final-tooltip.jpg`, `final-relaunch-phone.jpg`, `final-creatures-phone.jpg`. Before: `baseline-hud.png` (JPEG bytes).
- **Deferred:**
  - Icon art: Astra paints the 10 sidebar icons per `docs/art/UIReferences/ICON-REQUEST.md`; the tiles show emoji glyphs until the uploaded IDs go into `Theme.icons`.
  - ~~CreaturesPanel income line covered; favourite `* -` dark on dark~~ **fixed in `1351985`**.
  - `deferred (pre-existing layout)` AtlasPanel: its fixed 880x600 design size does not fit a landscape phone's 1206x557 design space (y -22..578). This comes from the panel's size, not the restyle.
  - One unreproduced tile click that did not close an open panel (Task 5 triage; the toggle worked on every later try, including this pass).
  - Relaunch warning/blocked labels now share accent yellow (the favourites warning and the "You need ... Coins" blocker are both `Theme.colors.accent`).
  - ~~Mythic / Legendary / Epic rarity glyphs render as tofu~~ **fixed in `6869c72`**.
  - Pre-existing: several panels use 11-12 px body text (Relaunch lists, Recipes rules), under the 13 px style rule and very small at the 0.7 phone scale; a fix needs layout room, not a token swap.
- **Studio:** last seen in **Play**, started by the user or another session, not by this one.
  - **Rojo incident, resolved:** a Qwen Code agent in an orca pane kept running `rojo serve --port 34872` from the stale worktree (`orca/workspaces/.../Catch-A-Catastrophe`, `feature/CAC-1` @ `3ef4ef3`, 2026-09-06).
    - The Studio plugin connected to it and synced six-week-old scripts into the open place.
    - The user closed that session; Rojo now serves the **main checkout** on 34872.
  - **Rule for every agent:** run `rojo serve` only from `C:/Users/nguye/Documents/repos/catch-a-catastrophe/CatchACatastrophe`, never from the orca worktree.
- **Publishing:** nothing published. `docs/CONTRACTS.md` and this entry are uncommitted (other sessions' edits share these files).

## Gusty meadow kit v1: pine, shrub, moss rocks and daisy bed heroes ready for review — 2026-09-23

- **Request:** after an in-game screenshot, Rahul asked to move the remodel on from the broadleaf trees to "the other trees, rocks, etc.". He circled the tiered pines, round shrubs, daisy beds and slate rocks.
- **Completed:** new deterministic builder `tools/blender/create_gusty_meadow_kit.py`, with output in `assets/gusty-gardens/meadow-kit-v1/`: editable `GustyMeadowKit.blend`, geometry report, README, lineup beside the approved broadleaf A, a before/after sheet against the current blockouts, 3/4 and detail close-ups per asset, and a player-scale meadow vignette. Each hero is fitted to its `GustyGardens.luau` blockout envelope and root. Pine: 17 sites, 224k source tris. Shrub: 31 sites, 48k. Rock group: 19 sites, 64k. Daisy bed: 62 sites, 21k. All components are closed, with zero non-manifold edges and zero degenerate faces. Three render/fix passes: the pine and shrub support cores showed through, the shrub leaves read end-on, and the rocks were too pale and their moss looked like decals.
- **Not done:** no approval yet, no variants, optimization, FBX export, upload or integration. No `src/` or Studio change was made; Studio was not touched. Nothing committed or published.
- **Open review points (README):** the shrub is about 0.5/0.7 stud over its blockout W/H, and the daisy heads add 0.6 of height. The daisy centres are no longer Neon. The 62 flower beds need the heaviest export cut.
- **Next:** Rahul reviews `meadow-kit-before-after.png` and the close-ups. On approval: variants (pine B/C, shrub and rock siblings), export as in the broadleaf flow (atlas, component centers, <20k tris/component, round-trip verifier), user upload, native capture and a placement module per family. The rock proxy (first slab) and pine trunk proxies must be kept.

## Gusty thin-leaf broadleaf family integrated after native upload — 2026-09-23

- **Completed:** user reported “uploaded”. Captured the nine actual uploaded meshes into `src/server/Map/GustyBroadleafTemplates.rbxm` (235,263 bytes), recorded real IDs/maps in `assets/gusty-gardens/broadleaf-family-v1/roblox/roblox-import.json`, and verified all 35 replacements in Studio: 105 MeshParts, A12/B12/C11. Original crown placeholders retired; all 35 original hidden solid/non-queryable trunk proxies retained. The 17 perimeter pines and five legacy interior windbent trees remain separate batches.
- **Native import correction:** uploaded sizes were 100x, and native vertex orientation required 180 degrees about Y. Measured 180+ actual EditableMesh vertex samples per component against exported vertices: all nine agree, corrected maximum error below 0.000004 studs. Added required library attribute `NativeMeshYawDegrees` (0 or 180); `GustyBroadleafProps.luau` applies native rotation after each component-center translation. Source socket/manifest offsets stay unchanged. Evidence and reusable verifier: `roblox/native-vertex-samples.json`, `native-orientation-validation.json`, `tools/blender/verify_gusty_native_orientation.py`.
- **Capture/sync:** used `tools/studio/prepare_region_templates.luau` and real Studio serialization. Rojo synced the binary library; read back all nine templates, sizes, IDs/maps and orientation. Runtime Source readback matched 6,514 normalized bytes / djb2 hash2848341664. Raw gallery is safely anchored in `ServerStorage.RegionImportStaging.GustyBroadleafBundle`; temporary local capture bridge stopped and HttpEnabled restored to false.
- **Validation:** broadleaf fixture **4,141 checks**; template capture15, staging42, quarantine15; 134-file structure/quote scans and `build/GustyBroadleafIntegrated.rbxl` Rojo build pass. Fresh Play checked every tree/component transform, dimensions and collision flags. Actual MeshPart-instance preload **105 Success / 0 Failure**. Reviewed actual close-up and overview captures saved as `roblox/studio-broadleaf-close.jpg` and `studio-broadleaf-overview.jpg`.
- **Limits:** initial raw-URI preload probe returned Failure for all12; SurfaceAppearance-only preload returned no callbacks. Actual placed meshes/materials were visible and no mesh/map load errors appeared in Studio console; do not claim independent map preloads passed. SelfTest **1005/16**, LiveTest **63/2**, same recorded existing failures and no new broadleaf failure. A short 180-frame desktop Studio sample had median16.63ms/p95 17.50ms on RTX3080Ti at Automatic quality; it is not a before/after benchmark or mobile acceptance. Full record: `roblox/integration-status.json`.
- **Docs:** updated family README, import/reimport instructions, Gusty inventory and contracts. Narrow-leaf direction remains user-approved; B/C and actual in-game appearance have not received separate user review.
- **Final state:** Studio `6f9cd136-faa6-4b44-b5bc-3f40ee0f50d9` in **Edit**. Nothing committed or published. **Next:** user in-game review and mobile profiling as needed; continue first-area remodeling with perimeter pines.

## Gusty thin-leaf family approved: exports and placement ready, native import pending — 2026-09-23

- **Approval:** Rahul said “Looks good, proceed” to the 25%-narrower-leaf comparison. Recorded that version as approved A/Meadow. Extended the treatment into B/Spreading (lower, rearranged boughs) and C/Upright (nine ascending groups, narrower crown and changed trunk path). No separate B/C or post-import approval claimed.
- **Art delivery:** `assets/gusty-gardens/broadleaf-family-v1/` has editable `GustyBroadleafFamily.blend`, B/C source scenes, source manifest/render, and `roblox/` with optimized `.blend`, gallery render, `GustyBroadleafBundle.fbx`, nine individual FBXs, shared embedded/external 2048 color/normal/roughness maps, bounds/root/component-center manifest and independent FBX validation. All 9,570 leaves retained as closed eight-triangle volumes; wood/ridges retained. Source **259,290 tris → 106,170** (59.05% reduction), three components per tree. A38,302/B38,302/C29,566. Compared source/export images. Source review files and approved Powder art preserved.
- **Tools:** parameterized `create_gusty_broadleaf.py` for independently seeded B/C (default A output still protected); new `build_gusty_family.py`, `export_gusty_broadleaf.py`, `verify_gusty_exports.py`, `generate_gusty_broadleaf_spec.py`, `verify_gusty_broadleaf.luau`. New family README and `roblox/IMPORT-AND-INTEGRATION.md`; updated inventory/approval note.
- **Runtime preparation:** new generated `GustyBroadleafSpec.luau` and `GustyBroadleafProps.luau`. `GustyGardens` now explicitly groups the exact 35 existing broadleaf sites under `Boundary.BroadleafSites`, with root GroundCF/scale, original trunk proxy and six original lobes under PlaceholderArt; placement does not alter their original transforms. Full-kit/site validation and detached cloning precede retiring art. Missing/invalid kits preserve old art. Success will create 35 trees / 105 MeshParts, A12/B12/C11, preserving exact root anchors, uniform scale and component-center offsets; hidden solid/non-queryable trunk proxies retained. ImportStaging now recognizes/quarantines the nine-mesh bundle. Added two fallback-aware SelfTest checks and documented contract. Other assets and GardenBayProps/Water unchanged; legacy five interior windbent trees are not this batch's sites.
- **Verification:** independent FBX imports pass every component plus complete bundle, exact names/bounds/centers/gallery offsets/counts, closed nondegenerate geometry, finite normals/UVs and all three maps. Placement fixture **4,000 checks**, including 245 measured pre-restyle tree parts, all sites/proxies/bounds, non-tree preservation, idempotence, invalid kits/sites and staging. Existing staging42, quarantine15, Powder11,151 pass. **134-file structure/quote scans and Rojo build pass** (`build/GustyBroadleafReview.rbxl`). A formatting-only inline loop confused the structure scanner; expanded it and reran successfully.
- **Studio evidence:** source hash readback matched all five edited/new modules (`GustyGardens`, `GustyBroadleafProps`, `GustyBroadleafSpec`, `ImportStaging`, `TestHarness`). Fresh Play: 35 sites, 210 original crown lobes, 35 visible original trunks and 35 solid/non-queryable proxies, no native kit/replacement yet. SelfTest **1004/16** (+2 passing checks, same recorded failures); LiveTest **63/2**, unchanged. Actual source sync/fallback verified, not new-mesh loading/appearance/performance. Existing impact_generic sound and API-off adapter messages remain.
- **External step:** `manage_open_cloud_assets credential_status` still returns “License required ... Activate Pro license”. Automatic upload unavailable. User must import the concrete `roblox/GustyBroadleafBundle.fbx` in Studio Edit, upload under intended owner and preserve all nine names/maps. Then inspect actual scale/IDs, use `prepare_region_templates.luau` with manifest assets and library `GustyBroadleafTemplates`, serialize real native library to `src/server/Map/GustyBroadleafTemplates.rbxm`, record IDs/scale in `roblox-import.json`, sync/read back and test actual35/105 placements/preloading/visuals. No IDs or native library fabricated. The detailed import handoff is ready.
- **Studio:** `6f9cd136-faa6-4b44-b5bc-3f40ee0f50d9`, place88888194204730, returned to **Edit**. **Publishing:** nothing committed/published. **Next:** native import/capture and actual game visual/gameplay/performance acceptance; then the next first-area asset family. Mobile performance remains unverified.

## Gusty broadleaf: thinner-leaf review variant — 2026-09-23

- User requested a version with slightly thinner leaves. Created `assets/gusty-gardens/broadleaf-v2-thin-leaves/GustyBroadleafThinLeaves.blend`, derived from the saved hero, with leaf cross-sections reduced 25%. Preserved lengths, centerlines, positions, count, materials, trunk/branches and scene scale. Original version untouched.
- New reproducible tool `tools/blender/create_gusty_thin_leaf_review.py`; actual Blender hero/detail renders and side-by-side comparison (original left, thinner right), README and geometry report. Edited leaf mesh passes nonmanifold-edge and degenerate-face checks. Same 3,480 leaves and 93,982 total source triangles.
- Pending: user preference/design review; neither version is approved for map replacement. No export, game source changes, Studio actions, commit or publish in this revision.

## First-area restyle started: Gusty broadleaf hero — 2026-09-23

- **Request:** begin remodeling assets in the first area using `docs/art/ASSET-RESTYLE-HANDOFF.md`. Confirmed Gusty Gardens is progression index 1. Inspected approved Powder Fir lineup/detail/optimized renders and opened the actual source `.blend` in Blender 5.1.2.
- **Delivered for design review:** `assets/gusty-gardens/broadleaf-v2/GustyBroadleaf.blend`, six actual Blender renders (three-quarter, front, side, detail, player-scale and same-scale Powder Fir comparison), geometry report, independent source-readback validation, README and region part inventory JSON. One hero only: substantial root-flared ridged trunk, twelve canopy groups, 3,480 closed folded leaves; three editable source meshes, 93,982 triangles. Fits the current perimeter tree envelope at 19.992 W × 17.980 H × 18.872 D with root socket zero and shared component frame. Appended reference fir remains 26 studs tall; original art files untouched.
- **Tools/docs:** `tools/blender/create_gusty_broadleaf.py` (seeded, overwrite guard), `render_gusty_broadleaf.py` (saved-source rerender), `docs/art/GUSTY-RESTYLE-INVENTORY.md`. Inventory from a fresh source headless build: 35 broadleaf trees, 17 pines, 31 shrubs, 19 rock groups, 62 flower beds, 9 grass tufts, two mills/crates, one barrel, six path stones; 2,124 region parts including infrastructure. Headless fixture rejects native GG_Moss_Rock_Wide, so counts are **fallback geometry**, not live Studio native-art counts.
- **Integration discovery:** current `GustyGardens` puts perimeter rocks/flowers/trees under Boundary, while GardenBayProps scans only direct Landmarks children and still places the older five trees/five ferns/four shrubs/two planters at legacy coordinates. New hero targets the 35 current perimeter broadleaf sites, not those five legacy windbent trees. Fix/group current sites during later approved integration; preserve shared Water consumer and collision. Wider Gusty concept image referenced by builder is absent in this checkout; dimensions came from current source.
- **Validation:** generator completion marker and exit 0; independent reopen confirms exact three meshes, triangle counts, identity transforms, report bounds, zero nonmanifold edges/degenerate faces, and reference height26. Visually inspected all six views; corrected orthographic floor occlusion in the player view using a perspective camera. Geometry overlaps are not Boolean unions. No game source changes or game-test claims.
- **Remaining:** user design review; meaningful siblings, optimization, UV/portable maps, FBXs/round-trip, native import/capture, source integration, actual Studio visual/gameplay and performance checks. No approval, asset IDs or performance result invented.
- **Studio:** inspected read only; Edit, no generated Gusty region present. No Play started or Studio changes. **Publishing:** nothing committed or published. **Next:** review the broadleaf render, adjust if needed, then approved family variants and pine/rocks/low planting before windmill restyle.

## Settings: the tutorial can be switched off — 2026-09-23

- **User request:** a setting to turn off the tutorial, meaning the "STEP x / 13" card and the glowing route to the next target.
- **Done:** a new boolean setting `tutorial`, default **on**, shown in Settings as "Tutorial" under Pop-up messages. Switching it off hides:
  - the tutorial card
  - the route beam
  - the Tutorial row in the Quests panel
  - the server's per-step `Notify` pop-ups (`QuestService.advanceTo` returns before them)
- **Progress still counts while it is off.** `tutorialStep` keeps advancing on the server, so switching the setting back on resumes at the right step. Nothing else reads the tutorial step except `EncounterService.ensureTutorialSpawn`, which is unchanged. The sidebar panel gates come from the snapshot, not the step, so they are unaffected.
- **Files:** `shared/Types.luau`, `server/Systems/Profiles.luau` (type, default, sanitize with default true), `server/Systems/RemoteRouter.luau` (`BOOL_SETTINGS`), `server/Systems/QuestService.luau`, `client/UI/TutorialUI.luau` (`guideEnabled()` gates the card and the beam loop), `client/UI/Panels/SettingsPanel.luau`, `client/UI/Panels/QuestsPanel.luau`, the settings fallbacks in `client/Controllers/CaptureController.luau` and `Effects.luau`, `server/Systems/TestHarness.luau`, `docs/CONTRACTS.md`.
- **Validation:**
  - Static: the 132-file structure and quote scans pass, and the Rojo build passes.
  - New checks in `testTutorialAndGates`: the setting is on for a new player; an old save without the key keeps it on; off survives a save round trip; a switched-off tutorial still advances a step.
  - Studio (via StudioMCP): stopped the Play the prior task had left running. Rojo synced, and a `.Source` readback confirmed all 7 changed scripts. SelfTest was **1002 / 16**, against 998 / 16 before, so the 4 new checks pass and the 16 failures are the same region-art and correction set. LiveTest **63 / 2**, unchanged (route chevrons).
  - Live client: firing `SetSetting("tutorial", false)` hid the card and beam; true brought them back. With it off, teleporting into Gusty Gardens sent `TutorialStep(2)` with no Notify pop-up and the card stayed hidden. Switching it back on showed "STEP 2 / 13".
- **Unexplained, not reproduced:** in the first Play after the sync, one baseline probe (~30 s in, setting still on) found the card hidden at "STEP 1 / 13". The new code cannot cause this, because it only hides the card when `settings.tutorial` is literally false. Two later fresh boots, sampled every 3 s and again at 32/37/47 s, showed the card and beam at step 1 every time.
- **Not done:** the Settings toggle button's On/Off label was not looked at in the open panel. It uses the same `makeToggle` path as the other three toggles.
- **Studio state:** left in **Edit**. **Publishing state:** nothing committed, nothing published.
- **Next:** the user tries the toggle in Play.

## Reusable Blender restyle handoff documented — 2026-09-22

- User wants every existing game asset eventually recreated in the approved Powder Fir style, and requested a reusable document for another session/Claude. Added `docs/art/ASSET-RESTYLE-HANDOFF.md`: illustrated reference hierarchy, art direction/material values, actual tree modeling recipe, source/export differences, translation to other asset families, inventory/review workflow, optimization/texture/export/native capture/placement instructions, runtime permission lessons, acceptance evidence and a copyable receiving-agent prompt.
- Reviewed the approved and optimized Blender lineup renders and selected concept; checked details against the generator/exporter, manifest and integration records. Verified all Markdown image/file links exist and code fences are balanced. This was documentation only: no Blender regeneration, game source edits, Studio changes, commit or publication. Studio state was not queried during this documentation task; see the latest implementation checkpoint for its last observed state.
- Remaining work: inventory and select the next asset family, model a representative piece alongside the approved trees for review, then extend and integrate that family. Cross-family design suggestions in the handoff are recommendations, not user-approved designs. Mobile performance remains unprofiled. Document-only handoff; no new session was created.

## Giant crate falling on the hub fixed — 2026-09-22

- **Reported:** a massive wooden box fell from the sky onto the hub at every start. It was `FP_Alpine_Crate` at raw import size (184 studs, unanchored).
- **Cause:** the Edit Workspace holds a hand-made model `FrostbiteALpineTemplates` (capital L typo): a full 30-mesh raw copy of the Alpine kit, unanchored, parked near y 1955. Its MeshIds are identical to `Workspace.AlpineOutpostBundle`. `ImportStaging.move` only recognizes exact bundle names, so it stayed in Workspace; in Play 29 pieces fell out of the world and the crate landed by the hub. The stray-mesh SelfTest only knew the six props-v1 libraries, so it stayed green.
- **Fix:** new `ImportStaging.quarantine`, called by `MapBuilder.build` after `move`. Any top-level Workspace model or part built only from meshes known from a staged gallery or captured library, and not a placed `BlenderAsset`, is anchored and parked in `ServerStorage.RegionImportStrays`. It is kept apart from `RegionImportStaging` and carries no `NativeTemplateLibrary`. `move`'s own contract is untouched, so every existing verifier's "partial kit left in source" assertion still holds. New TestHarness check `no raw import copies loose in Workspace`. CONTRACTS updated.
- **Validation:** new `tools/verify_import_strays.luau` **15 checks**: the renamed copy, a loose top-level mesh, library-known meshes, idempotence, and mixed/unknown/placed/empty models preserved. It failed before the fix. Staging 42, Powder 11,151, Alpine 8,694, capture 15, plot 709, Orbit 285, Thunder 683, Cinder 2,300 all still pass; 132-file structure and quote scans are clean. Studio (via StudioMCP): Rojo synced all three files. A fresh Play parked `FrostbiteALpineTemplates` (30 parts, all anchored) in RegionImportStrays, with **0** large unanchored parts in Workspace. SelfTest **998 / 16**, LiveTest **63 / 2**; the same 16 and 2 failures as the 10:18 PM run before the change, none import-related. Studio left in Edit.
- **Not done:** the Edit-mode copy is still in Workspace, harmless now. The user can delete it or save the place without it. Nothing committed; `ImportStaging.luau` is still untracked with the rest of the art work.

## Thunderworks: five true-scale mockups and a 26-asset kit — 2026-09-22

- **User request:** "a couple mockups of the thunderworks region along with images of different assets that would fit the theme". Offered four directions; the user picked **Tesla Coil Works** and **Copperline Substation** and asked for "a few that combine a couple of the options above". Thunderworks is the next region to redesign for the 280 x 200 chain cell; `Thunderworks.luau` is still the circular radius-75 yard with props-v1 integrated.
- **Delivered** in `docs/art/regions/2026-09-22-thunderworks/`:
  - five 1536 x 1024 mockups in the Frostbite round's format: 01 Tesla Coil Works, 02 Copperline Substation, 03 Sparkline Substation (01 x 02), 04 Stormcliff Dynamo (01 x the V5 Cliffside Dynamo painting), 05 Copperline Railyard (02 x the V4 Stormrail Depot painting)
  - `thunderworks-v1-overview.png` and `thunderworks-v1-plans.png` (straight-down plans)
  - `thunderworks-asset-kit.png`: 26 new assets, one captioned card each in `assets/`, rendered at stud scale beside a 5-stud avatar, with measured W x D x H and the options that use them
  - `V1_OPTIONS.md`: what each option is, the shared envelope, the art-direction caveats, the asset tables
- **Method:** Blender 5.1, not image generation; the Frostbite pipeline extended. The cell is built at MapBuilder's coordinates: Orbit Outpost's locked barrier and ORBIT OUTPOST / 1M COINS banner at the north gate, THUNDERWORKS / 300K COINS at the south, side piers at 44.44 k - 900. Camera and light match the Frostbite round. `src/tw_kit.py` builds each asset once in studs; the same mesh goes into the mockups and onto its card. Astra's eight props-v1 meshes are appended from `props.blend`; six are placed (24/31/28/10/8 per option), the conduit elbow and storm bollard are not. Reproduce with `bash src/render_all.sh`, about 13 minutes: 3 for the options and plans, 10 for the asset cards.
- **Validation:** every render viewed full-size, with crops of arcs and landmarks. A 1-stud raster of solid footprints, pines by canopy, gives the open field (|x| < 92, |y| < 70) **100.0% clear** in all five, **0** blocked lane cells, and 78.5-81.8% of the interior clear. Two fence runs that crossed into the field (02, 03) and a stair at x 92 (04) were caught by that measure and moved.
- **Defects found and fixed along the way:**
  - props-v1 objects carry gallery offsets in `props.blend`, so baking `matrix_basis` put every prop up to 15 studs off target; now rotation and scale only
  - the arcs rendered pure white and escaped the saturation-gated bloom; a near-white core mask was added
  - 05's catenary wire hung 2.7 studs below the pantograph
- **Art direction, not decisions** (all in `V1_OPTIONS.md`):
  - arcs would be client-side Beams or particles with no collision or damage, kept away from the field
  - the floor stays `groundColor` 78, 84, 99, with nothing yellow on or near the field (the Storm telegraph is pale yellow)
  - the lane is drawn as a 24-wide concrete `TRAIL_BLEND`; today Storm gets the default kerbs in its own yellow
  - the strip outside the walls is drawn as a heath with a pylon line (an `OWN_FLANK` choice)
  - pines fill the bands
  - creatures are the four Storm species at about 3x
- **Studio state:** not touched or inspected this session; the concurrent session's Studio work in the entry below is untouched. **Publishing state:** nothing committed, nothing published.
- **Next:** the user picks an option, revises one, or asks for painted versions. Then write the Claude handoff from that option's builder in `src/tw_designs.py` (+X east, +Y north = Roblox -Z), and give Astra the matching cards. The sizes on the cards are starting contracts measured off the Blender stand-ins, not final.

## Powder Firs integrated and verified in Studio — 2026-09-22 (latest)

- Fixed Rahul's report that Frostbite still showed cylindrical placeholders. Imported PowderFirsBundle existed but its native template library had not been captured. Cloned all 14 uploaded MeshParts through `prepare_region_templates.luau`, normalized Size from uniform 72.544426 import conversion, preserved native mesh geometry/PBR maps, and serialized through Studio SerializationService to `src/server/Map/FrostbitePowderTemplates.rbxm` (286,421 bytes). IDs/maps recorded in `assets/frostbite-peaks/powder-firs-v1/roblox/roblox-import.json`. No reimport needed.
- Fixed two runtime permission errors in `FrostbitePowderProps.luau`: read `SurfaceAppearance.ColorMapContent.Uri` instead of plugin-only ColorMap; inherit Automatic RenderFidelity from captured templates instead of writing its plugin-only property during Play. Rojo sync and Source readback confirmed.
- Actual server/client verification: **91 trees, 425 native MeshParts, A31/B30/C30, zero remaining tree PlaceholderArt**. Preloading the placed trees returned **425 Success, zero failures**. Reviewed Studio overview and close-up screenshots showing sculpted snow, needles and bark. Short local frame sample ~16.77ms median/17.75ms p95 had camera resets; it is not a forest/device benchmark. Mobile performance remains unprofiled.
- Checks: Powder placement fixtures **11,151 pass**; 132-file structure/quote scans pass; Rojo build passes. Actual tree-related SelfTests pass; full suite **997 passed/16 failed**, LiveTest **63/2**. Remaining failures concern plot/older-region art assertions, region correction checks (including Frostbite), route chevrons and Gusty/Cinder field clearance, outside this tree integration. No region-build crash remains. Existing impact_generic sound warning remains.
- Studio **6f9cd136-faa6-4b44-b5bc-3f40ee0f50d9**, place88888194204730, left in **Edit**. Three raw Powder galleries preserved and anchored in ServerStorage.RegionImportStaging. Temporary loopback capture helper stopped; HttpEnabled=false restored. No commit/publication. Next: user reviews trees in Play, then refine other Frostbite props or separately address existing test failures. Alpine non-tree library remains uncaptured.

## Approved Powder Firs: replacement wired; Studio import required — 2026-09-22

- Rahul approved all three Blender models and asked to replace all current Frostbite trees. Prepared `assets/frostbite-peaks/powder-firs-v1/roblox/PowderFirsBundle.fbx`: 14 native components across A/B/C (5/4/5), every needle preserved as a simpler closed volume, reduced snow topology, original bark, shared 2048 color/normal/roughness atlas, optimized .blend, component bounds/centres/root sockets in manifest. Final unique total **140,720 triangles** versus 978,850 source. Components <20k each. Build tools: `export_powder_firs.py`, `verify_powder_exports.py`, `generate_powder_spec.py`. Independent FBX round trips pass all14 plus bundle, including geometry/centres/textures; fixed internal zero-volume two-face snow remnants revealed by the FBX importer. Original source retained.
- New `FrostbitePowderSpec.luau` (generated from manifest) and `FrostbitePowderProps.luau`; FrostbitePeaks applies the tree kit after AlpineProps. Validate full kit and all sites before removing any art; replace placeholders OR old native firs; retain old metadata, supports/proxies and trunk anchors, uniformly fit each crown within its previous oriented envelope. Cyclic sorted-site allocation: **91 trees = 31 A, 30 B, 30 C; 425 MeshParts**, including all cliff and flank firs. Non-tree art and other regions unchanged. Requires real `FrostbitePowderTemplates.rbxm` before it activates. ImportStaging handles PowderFirsBundle; Frost SelfTest handles mixed non-tree art and Powder trees. Contracts and import handoff updated.
- Checks: `verify_powder_firs.luau` **11,151** in-memory fixture checks (both prior-art paths, bounds/root anchors, rejection cases, non-tree preservation, staging); existing Alpine **8,694**, staging42, capture15;132-file structure/quote scans; Rojo build `build/PowderFirs.rbxl`. Read back all new modules and Frostbite/ImportStaging Source through Studio MCP, confirming sync. No claim of uploaded native tree validation yet.
- Studio: official instance **6f9cd136-faa6-4b44-b5bc-3f40ee0f50d9**, Catch a Catastrophe place88888194204730. It was in Play; stopped to Edit before source edits. Game reports **CreatorType.User / CreatorId1445842194**, so group import ownership does not imply a group-owned experience. Existing Workspace.AlpineOutpostBundle is imported (60 descendants) but no FrostbiteAlpineTemplates captured; left other kit integration alone. New Powder assets NOT uploaded, captured or placed yet. WEPPY automatic asset upload unavailable: credential_status returned Pro license required. User must import the ready bundle using Studio (Upload to Roblox, intended Creator, preserve all14 meshes/textures).
- Next after user import: inspect native IDs/scale/maps; stage raw bundle; use `tools/studio/prepare_region_templates.luau` with Powder manifest assets; serialize real library to `src/server/Map/FrostbitePowderTemplates.rbxm`, record IDs; sync/read back; boot and validate all91 replacements, variant distribution, SelfTest/LiveTest, content loading, actual appearance and performance. See `roblox/IMPORT-AND-INTEGRATION.md`. Nothing committed or published. Keep Studio in Edit for import.

## Powder Fir family modeled in Blender — 2026-09-22

- Rahul requested all three selected Powder Fir variants in Blender. Built native editable models in `assets/frostbite-peaks/powder-firs-v1/PowderFirs.blend`: A Original, B Broad, C Upright, arranged in separate collections with separate bark/needle/snow meshes. Actual Blender lineup, individual views and branch detail accompany the scene. These are source models for visual review, not image-generated substitutes or integrated Roblox assets.
- New builder `tools/blender/create_powder_firs.py` and independent preview renderer `tools/blender/render_powder_firs.py`. Individually seeded 42/36/47 branch arrangements, closed modeled needle sprays, ridged bark/root flares, welded and softened scalloped snow volumes. Fixed excessive top gaps and removed needles intersecting snow during internal render review. Cached normals before displacement to avoid repeated recalculation; original slow background build terminated by its verified PID only, interactive Blender left alone.
- Detailed source geometry: A 327,232 triangles, 15.129 x 26 x 15.463; B 302,456, 17.503 x 23.5 x 16.498; C 349,162, 14.261 x 28.3 x 14.681. Intended Roblox W/H/D. All nine component meshes pass manifold-edge and nondegenerate-face checks; full details in `geometry-report.json`. Native material shading and geometric snow detail; no UV/bake/export or gameplay performance claims.
- Pending: Rahul's visual approval/iteration, then optimize/LOD and bake materials, agree bounds/sockets with the runtime spec, export and validate FBXs, group upload and native template capture, Studio visual/performance review. Existing early fir studies, production Alpine library, map source and Studio untouched. Studio state not queried; no commit or publish.

## Powder Fir selected; two sibling concepts — 2026-09-22

- Rahul prefers tree concept 2 (Powder Fir) and requested a couple of slight variations so placed trees differ. Generated two reference-based siblings with built-in imagegen: `02b-powder-fir-broad.png` and `02c-powder-fir-upright.png` under the Frostbite `tree-concepts` folder. Retained original `02-powder-fir.png` as A. Exact prompts and status in `POWDER-FIR-VARIATIONS.md`.
- Reviewed outputs: same dense needle clusters/heavy pillowy snow, varied crown proportions, branch distribution and snow clumps. Original Powder Fir direction selected; new variants await feedback. These are concept art, not modeled assets.
- Next: user review of the family, then build the selected Powder Fir in Blender and iterate against the concept. Existing narrow Blender studies, production kit, source and Studio untouched. No upload, commit or publish; Studio state not queried.

## Frostbite tree concept selection — 2026-09-22

- Rahul redirected tree iteration to first generate three reference images and choose his favorite. Built-in imagegen produced Alpine Spire (slender), Powder Fir (full/heavy snow) and Windward Fir (open/asymmetric).
- Saved all three under `docs/art/regions/2026-09-22-frostbite-peaks/tree-concepts/`, with exact prompts and numbered filename mapping in `PROMPTS.md`. Reviewed all three generated images. These are concept art, not actual Blender mesh renders.
- Await Rahul's choice before further tree modeling. Existing native Blender v1/v2 studies, production assets, source and Studio unchanged. Studio state not queried; no upload, commit or publication.

## Astra slender snow fir review candidate — 2026-09-22

- Rahul says Claude finished the region and requests asset refinement, starting with a tree matching his supplied close-up. Created an actual native Blender study, separate from the delivered kit, for iteration until his approval.
- Current candidate: `assets/frostbite-peaks/fir-refinement/v2/FrostbiteFir-v2.blend`, plus hero, alternate and branch-detail renders. User reference retained beside README. Editable trunk/root geometry, six branch tiers, staggered foliage tips, individual thick snow mantles and snow spire. Initial internal pass remains in v1.
- Builder: `tools/blender/create_fir_refinement.py`. Candidate ~9.61 W x 26.13 H x 9.73 D, 17,652 triangles, 88 editable components. Geometry checks assert manifold edges/nonzero face areas. Native Blender material detail needs baking and mesh optimization after visual approval; no export or Roblox compatibility claim yet.
- Approval pending. Existing 30-asset kit, manifests, source/specs, uploaded assets and Studio untouched. Studio mode not queried for this isolated art task. Nothing committed or published.
- Next: get Rahul's visual feedback and iterate the tree. After approval derive the other sizes, optimize/bake/export and coordinate the slimmer dimensions with Claude's spec before integration.

## Frostbite Peaks rebuilt to Alpine Outpost V2; Astra's kit reconciled — 2026-09-22

- **User request:** implement Frostbite Peaks from `docs/art/regions/2026-09-22-frostbite-peaks/OPUS-ALPINE-OUTPOST-V2-HANDOFF.md`, matching `frostbite-peaks-v2-02-alpine-outpost-refined.png` as closely as possible; write Astra an exact asset request first; build with accurately sized stand-ins; keep the meadow and gate-to-gate route clear; compare against the reference from a matched camera.
- **Measured, not eyeballed.** V2 is not a consistent camera: the V1 camera misses it by 41 px RMS, and the best free pinhole still leaves 11.75 px, because V2 draws the gate at its true width but the rest of the cell ~10% narrower and heights ~20% shorter than its ground plane implies. So: ground homography from the four gate-pier bases, a piecewise x map anchored on the gate piers, both divider piers and the wall face, heights from the gate piers' teal panels x 1.12, every landmark cross-read through the fitted camera (1-2 studs agreement) and projected back onto the concept. Scripts preserved in `docs/art/regions/2026-09-22-frostbite-peaks/src/v2-measure/`.
- **Completed:** `FrostbitePeaks.luau` rewritten (backup of the circular blockout at `build/backup/FrostbitePeaks.circular-2026-09-22.luau`). Stone terrace (deck 5.80) with a nine-riser stair and parapet; lodge site with a walkable porch at 6.80 and a camp; L-shaped north landing and south shelf at 8.80 with a fourteen-riser stair and a 34-stud rope bridge on a segmented walk deck over a decorative frozen creek; layered slate formations, 91 firs (46 on snowed-over flanks outside the walls), boulders, drifts, grass and shrubs composed from the concept; seven lane stakes a side; flush meadow ice, tracks and wind lines; Frost-owned non-colliding snow on the side walls, the north divider's Frost half and pier lanterns. 282 PropSites (spec bounds x uniform AssetScale, bottom-centre, PlaceholderArt only), 121 invisible proxies, 6 PointLights. Returns `field = (80, 0, 64)` with the route and one boulder cluster kept out.
- **New modules:** `FrostbiteAlpineAssetSpec.luau` (28 FP_Alpine_* bounds and the sockets used, exactly Astra's delivered manifest v3) and `FrostbiteAlpineProps.luau` (validate the whole `FrostbiteAlpineTemplates` library and every site, then swap all or nothing; uniform scale enforced). `FrostbiteProps` / props-v1 left in place, no longer called.
- **Shared edits, tight:** `RegionScenery` returns Frost's layout; `MapBuilder` gets `OWN_PERIMETER.Frost`, `TRAIL_BLEND.Frost` (packed snow 190, 206, 228, 24 wide, no kerbs) and `OWN_FLANK.Frost` (the shared treeline skips Frost's cell rows); `Regions.frostbite_peaks.groundColor` 176,198,214 -> 210,219,233; `ImportStaging` recognises `AlpineOutpostBundle` (28 required, two spares tolerated); `TestHarness` Frost block rewritten for the new layout (`SCENERY_VERSION.Frost = 4`). Whole-map dump before/after: **0 parts changed outside Frost's band**; walls, gates, barriers, banners, Cinder and Thunderworks identical.
- **Astra:** wrote `ALPINE-OUTPOST-V2-ASSET-REQUEST.md` (+ `v2-asset-reference-crops.png`, `v2-layout-plan.png`, `v2-measured-layout-on-concept.png`, `ALPINE-OUTPOST-V2-SITES.csv`). Astra was already modelling; the contract adopted their names and 17 provisional sizes, changed lodge/bridge/tent, added eight pieces. Astra then delivered all 28 (+2 extras) in `assets/frostbite-peaks/alpine-v2/`. Reconciled: bridge lanterns at y 7.0 as delivered; firs adopted at the delivered 15 x 26 (V2's are ~2.6:1; slender re-export is an optional follow-up that needs a same-change spec edit). Review note for Astra in the request: the two shelves read as flat white slabs and the gorge rock as a snowball column against V2's layered slate.
- **Validation (all headless):** `tools/luau_lint.py` and `quote_scan.py` clean on 130 files; `rojo build` -> `build/FrostbiteAlpine.rbxl`; new `tools/verify_frostbite_alpine.luau` **8,694 checks pass**: manifest bounds/sockets, site contract, placeholders inside bounds (worst 0.70), collision split, flush meadow, clear 24-stud route and gate throats, nothing across the walls, empty 64-stud spawn circle, 5,615/6,000 creature homes with 0 near a solid, on-foot flood fill from the south gate to the north gate, terrace, porch, shelf B, bridge mid-span, landing A and shelf C, risers 0.611 / 0.607, grounded sites on the floor, all-or-nothing swap (partial, 100x, distorted, non-uniform, solid-placeholder rejected; idempotent; permanent geometry untouched), Alpine bundle staging. Controls still pass: Cinder 2,300, Orbit 285, Thunder 683, plot 709, import staging 42, template capture 15. `verify_splashwater_placement` still fails with the known Lune `Position` quirk (pre-existing).
- **Visual comparison (Blender, not Studio):** new `tools/render_region_blender.py` renders a harness dump from the fitted concept camera or any eye point, and with `--kit-blend`/`--sites` places Astra's real delivered meshes at every site. Six render-and-compare iterations; defects the renders found and fixed: splayed tent panels, pale boxy cliffs/shelves, squat firs, a single sparse flank row, a creek a third as wide as drawn, drifts and caps below their asset floor, two stair-foot posts standing on buried stair cheeks. Results: `v2-comparison-concept-vs-kit.png`, `v2-comparison-concept-vs-build.png`, `v2-kit-player-views.png`, full-context versions. Layout doc: `ALPINE-OUTPOST-V2-LAYOUT.md`.
- **Limitations, honestly:** nothing seen in Studio; the kit is not uploaded or captured, so the game shows stand-ins. From the concept camera Cinder Quarry's 42-stud mine and 36-stud terrace stand in front of Frost's south corners (V2 paints low rocks there) — Cinder left as built. No pinhole reproduces V2 better than 11.75 px, so renders read gates ~10% narrow and heights ~16% tall in pixels. Snow white, ice blue, glow, smoke and bloom can only be judged in Studio. Frost's line-hazard path telegraph is drawn 0.025-0.275 above the creature origin; whether that shows over the 0.30 floor needs a live check (the 3-stud wall is always visible). Pre-existing, not mine: `TestHarness` still expects Heat SceneryVersion 4 and nine props-v1 Cinder meshes, and `tools/verify_frostbite_placement.luau` targets the old 56-site layout.
- **Studio state:** Studio running (pid 38612); Rojo 7.7.0 serving this repository on 34872 (pid 24736). No Studio bridge this session, so Play/Edit mode and whether the plugin synced these edits were not observed. **Publishing:** nothing committed, nothing published.
- **Next:** in Studio Edit: import `assets/frostbite-peaks/alpine-v2/AlpineOutpostBundle.fbx`, stage the gallery, capture `src/server/Map/FrostbiteAlpineTemplates.rbxm` preserving MeshSize/textures; stop Play, sync, confirm `.Source`, boot, read `[SelfTest]`/`[LiveTest]`; walk the routes; capture a Frost hazard in the meadow; retake the concept-camera and player-height shots against V2 (list in the layout doc, section 11). Optional Astra revisions: slender firs, layered shelf/gorge faces.

## Astra Alpine Outpost Blender kit delivered — 2026-09-22

- Rahul asked Astra to build detailed Blender assets while Claude implements the refined V2 zone. Created `assets/frostbite-peaks/alpine-v2/`, preserving props-v1, native libraries and all game code. Claude's dimensioned asset request arrived during modeling; the initial22-piece draft was reconciled to it rather than shipped at guessed sizes.
- **30 exported meshes: all28 required names plus2 optional extras** (Cliff_Shelf and Icicles). Kept17 adopted dimensions; rebuilt Lodge40x30x24 with east annex, porch1.0/step0.5; Bridge10x7.5x34 with exact deck ends1.5/midpoint0.3; Tent8x6x9. Added north/south shelves, gorge band, intermediate cliff, small rock, sled, notice board and terrace post. Added flat cliff TopMount pads. Final manifest is version3.
- Delivery: AlpineOutpost.blend, AlpineOutpostBundle.fbx,30 individual FBXs, shared2048 color/normal/roughness maps, manifest.json, validation.json, README.md, CLAUDE_ASSET_HANDOFF.md, gallery,30 detail PNGs and actual landmark-assembly preview. Individual FBXs reference adjacent maps; bundle embeds them (21.5MB total FBX files instead of506MB duplicated atlases). Optional512 RGBA ice-crack/bubble and boot-track textures plus metadata/material preview satisfy the reserved TextureSlots. No uploaded IDs fabricated.
- New tools under tools/blender: create_alpine_props.py, verify_alpine_props.py, render_alpine_previews.py, render_alpine_landmarks.py, create_alpine_surface_details.py, render_alpine_surface_details.py. Generator protects existing .blend unless explicitly --rebuild. Preview supports/effects are not exported. No image-generated render substitutes.
- **Validation passed on final exports:** 30 FBX roundtrips and bundle names; all28 required names; bounds/base pivots; closed nondegenerate components; real atlas UV containment and loaded textures; coordinate conversion. Ray tests cover porch/step, bridge endpoints/midpoint, shelf tops and empty L-shaped gorge, and cliff mounting pads. **77,622 unique triangles**, not the placed map's triangle count. PNG alpha and periodic ice seams checked; visual gallery/detail/assembly/material renders reviewed. Corrected floating chimney, bulky fir branches, buried bridge lantern cages, overly regular snow patches and plain shelf faces during iteration.
- **Shelf contract interpretation:** requested10-high bounds coexist with walk top8.5 over the full footprint. Two tiny0.7x0.7 outer rear corner snow caps reach10; all functional landings/joins/socket support surfaces remain8.5 and the gorge is empty. Exact corner coordinates and the interpretation are documented in CLAUDE_ASSET_HANDOFF.md for Claude to account for as non-walking rim.
- Outstanding: Studio import/upload, capture FrostbiteAlpineTemplates, runtime glazing/lights/smoke, native material-map verification, actual204-site map placement/performance and comparison to the refined concept at fitted and player cameras. Blender validation does not establish exact in-game visual parity. Existing asset library remains preserved, though Claude's current contract says the new layout does not reuse it.
- Updated `ASTRA-ASSET-WORK-IN-PROGRESS.md` to delivered status. Studio state not queried or changed for this art-only task; no Rojo/game source edits, no game runtime checks claimed, no commit or publish. Next: review kit renders and give Claude the kit handoff for import/integration against his measured layout.

## Frostbite refined Alpine Outpost selected; Opus handoff written — 2026-09-22

- Rahul requested an implementation prompt for the refined V2 image, explicitly assigning Blender assets to Astra and map work to Opus. V2 is now the selected implementation target.
- Saved `docs/art/regions/2026-09-22-frostbite-peaks/OPUS-ALPINE-OUTPOST-V2-HANDOFF.md`: exact image path, art/map ownership, layout and appearance requirements, early dimensioned layout/asset request deliverables, template/site contracts, scope preservation and required reference-camera visual comparison.
- Read current source: Frostbite remains the old circular Alpine Expedition layout. New V2 production meshes and dimensioned asset contract are not yet created. Opus should derive revised envelopes from the reference and V1 builders, then write ALPINE-OUTPOST-V2-LAYOUT.md and ALPINE-OUTPOST-V2-ASSET-REQUEST.md for Astra while implementing the map. Proposed asset families are specified, not falsely finalized dimensions/counts.
- Updated V2 refinement status. Documentation only: no game source, Blender assets, Studio/Rojo or other regions changed; no runtime tests, no commit/publish. Studio not queried for this documentation task. Next: give Opus the handoff; Astra models to the resulting shared asset contract.

## Frostbite Alpine Outpost V2 visual refinement — 2026-09-22

- Rahul prefers Alpine Outpost from Claude's five options and requested better textures, layout and density. Created `docs/art/regions/2026-09-22-frostbite-peaks/frostbite-peaks-v2-02-alpine-outpost-refined.png` with built-in image generation using the original option-02 image as the edit target. Original images and dimensioned Blender builders remain unchanged.
- Refined timber lodge/terrace, layered snow-capped slate, mixed fir clusters and ground planting, bridge details, snow texture/tracks and warm lights. Rectangular overview, centered gates, broad creature field, clear central route and left camp/right bridge identities retained visually. Output inspected; gate labels read THUNDERWORKS / 300K COINS and FROSTBITE PEAKS / 75K COINS.
- `ALPINE-OUTPOST-V2-REFINEMENT.md` beside the image records exact prompt, tool, changes and implementation boundaries. V2 is a proposed art-direction image awaiting review, not measured geometry; do not apply V1's clearance percentages to it. Reconcile updated envelopes and path connections with the real cell after approval.
- Only image/docs changed. No game source, production meshes, Studio or Rojo changes; no runtime tests, no commit or publish. Studio state not queried for this image-only task. Next: Rahul reviews V2; after approval, produce a measured implementation handoff and agreed asset list.

## Frostbite Peaks: five design options for the linear cell — 2026-09-22

- **User request:** "Create 5 different mockups for frostbite peaks". Frostbite is the next region after Cinder to be redesigned for the 280 x 200 chain cell; `FrostbitePeaks.luau` is still the circular radius-75 Alpine Expedition blockout.
- **Completed:** five options in `docs/art/regions/2026-09-22-frostbite-peaks/`: 01 Igloo Hollow (closest to V4), 02 Alpine Outpost (the approved 09-20 V2 identity refitted), 03 Glacier Falls, 04 Crystal Grotto, 05 Coldsnout's Crown. Each is a 1536 x 1024 PNG in the earlier rounds' format, plus `frostbite-peaks-v1-overview.png`. `V1_OPTIONS.md` covers what each option is, the shared envelope, the art-direction caveats and the new assets each would need.
- **Method, and why it differs from the earlier rounds:** no image generation. Each option is built in Blender 5.1 from Python (`src/`) at the cell's real size, using MapBuilder's walls, piers, gates, barrier, banners and lamps at their own coordinates, and rendered in Cycles from one shared camera. So the chosen option's layout is already dimensioned in region coordinates (+X east, +Y north = Roblox -Z). The handoff can be written from `src/fb_options.py` (01) or `src/fb_designs.py` (02-05) with no homography or camera fit.
- **Validation:** every render was viewed full-size and in close-up crops. A 1-stud raster of each solid object's footprint, counting firs by their whole canopy, gives 0 blocked lane cells in all five, 99.8-99.9% of the open field (|x| < 92, |y| < 70) clear, and 77.8-84.8% of the interior clear. Numbers are in `src/measurements/`. The banners carry the game's own text (THUNDERWORKS / 300K COINS, FROSTBITE PEAKS / 75K COINS).
- **Limitations:** these are mockups, not game geometry, and nothing was built in Roblox. The creatures are the four Frost species enlarged about 3x for legibility. The snowed-over flank strip, the wall-cap snow, the blended snow lane (Frost has no `TRAIL_BLEND` entry today) and the low west sun are art direction, not decisions. All ice must stay decorative over collision proxies.
- **Studio state:** not touched or inspected this session. **Publishing state:** nothing committed, nothing published.
- **Next:** the user picks an option. Then write the Claude handoff from that option's builder, and list the new hero assets for Astra (table in `V1_OPTIONS.md`).

## Pickup: quarry art integrated, Studio run written — 2026-09-22

- **Reconciled against live files, not the documents.** Two entries below are stale: the Cinder implementation entry's "the twelve meshes do not exist yet" and the account-transfer entry's "`CinderQuarryTemplates.rbxm` absent". Both are now wrong — `src/server/Map/CinderQuarryTemplates.rbxm` was captured at 13:14 with real ids in `assets/cinder-canyon/quarry-v2/roblox-import.json` (`CC_Quarry_Mine` is `rbxassetid://86863314152937`; native MeshSize carries a uniform 28.4444x conversion).
- **What the other pane did to Claude's quarry code:** `CinderQuarryProps` hardened past the original bounds check — it now also requires uploaded `rbxassetid://` MeshId/TextureID or a SurfaceAppearance ColorMap, `Archivable`, positive MeshSize, and per-axis ratio agreement, so axis distortion is rejected and not just the 100x case. The four provisional sockets are gone: `MINE_DOOR`, `HOIST_BASE` and `LAVA_FOOT` now read from `CinderQuarryAssetSpec.sockets` off the delivered manifest, `LavaUpperLip` / `LavaLowerLip` were added, and sites carry `SocketManifest`. `tools/verify_cinder_placement.luau` was extended to run against the real captured library: **2,300 checks pass** (was 1,723 on fixtures), 136 sites, 61 proxies, field 92 x 72, 0 creature homes in solids.
- **One thing that looks like a failure and is not:** `tools/world_harness.luau` still dumps the blockout with no `BlenderProps`, because its `.rbxm` deserialization does not expose MeshId/MeshSize; `verify_cinder_placement` bridges them and does place all 136. So **no render of the real meshes exists anywhere** — the only way to see Astra's art is Studio.
- **Broken, and left alone because it is the other pane's in-flight work:** `tools/verify_splashwater_placement.luau` errors under Lune — `Failed to get property 'Position' - missing default value` at line 161, in the water-socket check.
- **Written:** `docs/art/regions/2026-09-22-cinder-canyon/STUDIO-VALIDATION-RUN.md` — the five-step Studio run for the region, with Server command-bar snippets whose paths are all verified against source (`S.Workshop.unlockRegion`, `S.Economy.addCoins`, `workspace.Regions.cinder_canyon`, `CaptureHazardTests`), the expected values for each check, and the fallback diagnostic for a rejected library. Nothing else changed.
- **Studio state:** Studio running (pid 25816, since 11:32). Rojo serving this repository on **localhost:34872** (pid 24736). **No Studio bridge in this session** — mode, sync state and screenshots cannot be read from here, so the run needs Rahul to drive it.
- **Publishing state:** nothing committed, nothing published. The quarry modules remain untracked.
- **Next:** run `STUDIO-VALIDATION-RUN.md` and send back Output plus screenshots. After that: the Splashwater verifier error, and committing the quarry pass as one revertable unit.

## Codex account transfer; reconciled art/base status — 2026-09-22

- Rahul is switching Codex accounts. Start with root `CODEX-ACCOUNT-HANDOFF.md` for completed work, exact references, pending integration, socket corrections, validation limits, and remaining plot-art request.
- **Reconciliation of the two Cinder entries below:** Claude's quarry base is implemented AND Astra's twelve-mesh `assets/cinder-canyon/quarry-v2` pack is delivered and Blender-validated. The implementation entry's "meshes do not exist yet" and the asset entry's "Claude implements the selected base" are stale. Neither base construction nor asset generation needs to restart.
- Outstanding: import/upload CinderQuarryBundle, capture real `CinderQuarryTemplates.rbxm` (absent at transfer), replace provisional mine/hoist/lava sockets using manifest.json, integrate effects and native art, then perform actual Studio and visual checks. Splashwater's eight-mesh tidepools-v2 pack likewise remains awaiting native import/integration. Older native libraries do not represent these new kits.
- Transfer checks: read current source/docs and both passed Blender validation records; observed official Studio place 88888194204730 in **Edit**, instance `99b13aa3-ba7f-4476-b5d2-5840f635c1bb`; Rojo listening on 127.0.0.1:34872, PID 24736. Studio source sync/plugin connection not verified. Rediscover IDs/processes after changing accounts.
- Only transfer documentation changed. No game source/assets/Studio mutations, no newly run game tests, no commit or publish. Preserve all uncommitted/untracked files. Next account should read newer checkpoints before duplicating concurrent Claude work.

## Cinder Canyon rebuilt to the Cinder Quarry concept — 2026-09-22

- **User request:** implement the approved Cinder Quarry base against `docs/art/regions/2026-09-22-cinder-canyon/CINDER-QUARRY-CLAUDE-HANDOFF.md` while Astra models the twelve-mesh kit in parallel. The region was still the superseded "Sculpted Ravine": a circular radius-75 blockout with an arch, a stone bridge, a side walkway and a lava terrace ring.
- **Method, as for the bay and the plot:** the concept's four gate piers are engine geometry at known coordinates, so their teal panels fit the concept's projection — 6.59 px/stud, pitch 30.9°, ground mapping `u = 764 − 6.59x`, `v = 493 − 2.895z`. `concept-measured-grid.png` is that fit drawn back over the concept; depth lands on both gate lines exactly, so **z reads 1:1 against the 200-deep cell**. The fit puts the concept's own side walls at **x = ±103 against MapBuilder's ±140** — the same 37-stud gap Splashwater found — so border features are measured in from the wall rather than scaled from the centre. That convention is the one the handoff's own site table already used, which is what made table and fit agree. Six render-and-compare iterations from the fitted camera followed; four found real defects.
- **Defects the renders and ray tests caught, not the structure checks:** the entire border band, the mine, the terrace and every plant were being built at the region origin, because placeholder art was authored in asset-local space but placed with only the region frame; the lava cascade and all eight mineral pockets were modelled *inside* the terrace mass and were invisible; a stacked rock 33 studs tall stood in the sightline to the lava pocket and hid the one thing that makes the quarry read as hot; rotated rock tiers reached past the asset bounds Astra is modelling to, and past the cell wall into the next region.
- **Completed:** `CinderCanyon.luau` rewritten to the quarry. Flat warm orange floor (the region's own ground, not a new skin), a recessed timber mine at the rear-left with a hanging lantern, a nine-sleeper rail and one ore cart hung off the mine's `DoorBase` socket exactly as the handoff's table writes them, a four-tier quarry terrace at the rear-right carrying a timber hoist on its shelf, six amber mineral pockets on its step faces, a three-drop lava cascade down its front with a rock-framed pool, and a border band of 52 stacked sandstone rocks with 71 cacti, agave and flower patches. **136 explicit PropSites** across all twelve meshes, each with `AssetName`, `AssetSize`, a bottom-centre `GroundCF`, `PlacementRole`, `SupportPath` and its stand-in under `PlaceholderArt`; **59 invisible collision proxies** in `Boundary` carry every bit of containment; the lava, the minerals and their eight lights are effect geometry outside any asset's bounds.
- **New modules:** `CinderQuarryAssetSpec.luau` (the twelve fixed envelopes, plus the props-v1 meshes still worth reusing) and `CinderQuarryProps.luau` (validate the complete `CinderQuarryTemplates` library, then swap atomically — a partial kit, a 100× scale or a solid placeholder each leave the blockout untouched). The old `CinderProps` / `CinderPropTemplates` are left in place and are no longer called: their placements were fixed ring bearings from the superseded design.
- **Wiring:** `RegionScenery` now returns Heat's layout (it was dropping it, so the region kept the circular `SPAWN_RADIUS`). `MapBuilder` gains `OWN_PERIMETER[Heat]`, a Sandstone ground material for Heat, and `TRAIL_SAND` generalised to `TRAIL_BLEND` so the quarry's 24-wide lane is the quarry floor rather than a grey runway. `cinder_canyon.groundColor` changed from `120,70,50` to `238,134,86`, sampled off the concept.
- **Preserved, checked not assumed:** no gameplay change. Entry stays 15,000 and the north board stays FROSTBITE PEAKS / 75,000; walls, both gate piers, the barrier, the lock and the banner are still MapBuilder's. Grepped for anything outside the module depending on the deleted arch, bridge, walkway or alcove — nothing did. Region centre, `accessHalf`, `accessRadius`, income, hazard and species untouched. No new mechanic on the decorative lava.
- **Validation, all headless:** `tools/luau_lint.py` and `quote_scan.py` clean on 126 files; `rojo build` succeeds; `lune run tools/world_harness.luau` builds the whole map (9,279 parts). New `tools/verify_cinder_placement.luau` — **1,723 assertions, all passing**: every placeholder inside its declared bounds to 0.75 studs, no colliding site art, lane and both gate throats clear, nothing across the cell wall, floor height preserved, and the full swap-semantics suite. Open dry floor **64.0%** of the raw cell, **66.6%** inside MapBuilder's wall footprint, **92.2%** across the playable middle, against a 65% target. 6,000 `pickHome` samples: 4,581 survive the keep-outs, **0 land inside solid geometry**. Landmark visibility sampled by ray from avatar height at three standing positions.
- **Files:** `src/server/Map/CinderCanyon.luau` (rewritten), new `CinderQuarryAssetSpec.luau` and `CinderQuarryProps.luau`, `src/server/Map/RegionScenery.luau`, `src/server/Map/MapBuilder.luau`, `src/shared/Config/Regions.luau`, new `tools/verify_cinder_placement.luau`, new `docs/art/regions/2026-09-22-cinder-canyon/CINDER-QUARRY-LAYOUT.md` with the measured grid, the build render, the landmark render and the side-by-side comparison, this file.
- **Limitations:** the twelve meshes do not exist yet, so every rock, cactus, crate and landmark is a box-and-ball stand-in — the concept's faceted rounded rock is the largest remaining visual gap and it closes on import. Four sockets (`DoorBase`, `HoistBase`, the lava lip and foot) are provisional guesses and every site derived from one is tagged `SocketProvisional`. The lava pool reads from an elevated camera but not from avatar height, where its own kerb hides the surface. Open floor is one point under target on the raw cell with both landmark footprints fixed by the contract.
- **Studio state:** Roblox Studio is running (pid 25816) but **no Rojo listener was up**, so nothing in this session has reached it. Started Rojo 7.7.0 serving this repository on **localhost:34872** (logs in `build/rojo-34872.log`); the Studio plugin still has to be connected by hand. **Nothing has been seen running in Studio**, and the live Heat telegraph, both gate states and the walk through the region are untested.
- **Publishing state:** nothing committed, nothing published. `src/server/Map/CinderCanyon.luau` and the two new modules are still untracked, as the other region modules are.
- **Next:** connect the Studio plugin to 34872, boot, read `[SelfTest]` / `[LiveTest]`, walk the threshold to the north gate, confirm the Heat telegraph draws on the floor and both gate states fade correctly, and compare the live region to `comparison-concept-vs-build.png`. Then import `CinderQuarryBundle.fbx` when Astra delivers it, capture the native templates as `CinderQuarryTemplates`, replace the four provisional sockets from `manifest.json`, and re-run `verify_cinder_placement.luau` — it already proves the swap is atomic against fixture meshes.

## Cinder Quarry approved; Claude handoff and Astra Blender pack — 2026-09-22

- User selected **Cinder Quarry, option 03** from the three new region concepts. Reference: `docs/art/regions/2026-09-22-cinder-canyon/cinder-canyon-v1-03-cinder-quarry.png`. Selection recorded in V1_OPTIONS_AND_PROMPTS.md.
- Created and linked `CINDER-QUARRY-CLAUDE-HANDOFF.md` **before asset work**, so Claude can implement the base in parallel. Explicit 280 × 200 cell, actual +X=image-left / +Z=north local frame, clear central route, mine/rail/cart and terrace/hoist placements, twelve asset names/dimensions, separate art/gameplay ownership, preserved 15K/75K progression, visual QA and gameplay verification. Initial production placements are identified as proposed targets rather than falsely measured pixels. Final rails/cart use the delivered DoorBase socket instead of the outer rock bounds.
- New Blender pack `assets/cinder-canyon/quarry-v2`: twelve separately named meshes (mine, terrace, hoist, cart, rail, large/low mesas, tall/round cacti, agave, flowers, crate). Fixed contract sizes, recessed dark mine mouth, separate runtime effect/placement sockets, layered sandstone, matte timber/iron and shared embedded/external palette. Terrace channel is on outer/image-right local -X; full geometry and sockets mirrored together. Rails widened to align with cart wheel positions.
- Deliverables: editable CinderQuarry.blend, CinderQuarryBundle.fbx, twelve individual FBXs, quarry-palette.png, manifest.json, validation.json, twelve detail renders, gallery, and actual landmark-assembly preview. Assembly lava/light/sand are preview-only and not exported. Existing Cinder props-v1 remains untouched.
- New scripts: `tools/blender/create_quarry_props.py`, `verify_quarry_props.py`, `render_quarry_landmarks.py`. Generator refuses existing .blend unless explicitly --rebuild. Independent reimport validates twelve names, exact bounds/base pivots, closed nondegenerate geometry, per-face palette UVs, embedded textures, triangle counts and forward-axis mapping. **16,368 unique visible triangles**. Visual QA used actual Blender gallery/detail/assembled geometry; no image-generated stand-ins. Studio import/appearance/runtime checks remain pending.
- Asset README contains import and placement details; shared handoff tells Claude to use a separate CinderQuarryTemplates library, preserving native MeshSize and the existing small-prop library. No IDs fabricated. Import/upload through Studio is still needed before native template capture/integration.
- No game modules, Studio state, existing asset libraries or other regions changed. No game tests claimed, no commit or publish. Next: Claude implements the selected base using the handoff; import CinderQuarryBundle.fbx, stage it safely, integrate native templates, run actual game checks and compare the map to the concept.

## Astra Tropical Tidepools Blender assets delivered — 2026-09-22

- User asked Astra to create the custom assets after Claude completed the base region. Read Claude's exact `SPLASHWATER-ASSET-REQUEST.md` and preserved all game source and previous kits.
- New pack: `assets/splashwater-bay/tidepools-v2/`. Eight requested meshes at exact W/H/D contract sizes: grotto, cascade rocks, tall/bent/small palms, broad/low leaf clumps, hibiscus. Editable `TropicalTidepools.blend`, textured eight-mesh `TropicalTidepoolsBundle.fbx`, individual FBXs, palette, manifest with local water/crown sockets, eight optional convex collision proxies and optional split trunks/crowns for all three palms. Total unique visible geometry **13,656 triangles**. Water/effects are separate integration work, not baked into rocks.
- New generator and verifier: `tools/blender/create_tidepools_props.py`, `tools/blender/verify_tidepools_props.py`. Generation preserves existing .blend by default; explicit `--rebuild` used during this session's authored iterations. Existing props-v1 untouched.
- Validation passed: reimported all eight FBXs, exact dimensions/base origins, closed nondegenerate geometry, one palette UV layer/material and embedded texture, exact bundle mesh names, eight convex 12-triangle hulls, three split-palm reconstructions. Export axis conversion independently confirmed (+Y Blender -> -Z Roblox; +Z -> +Y). Actual Blender gallery and detail renders inspected; initial UV-layer bug fixed before final delivery. `validation.json` records results. Actual Studio imports/materials/performance remain untested.
- Handoff: kit `README.md` and `CLAUDE_ASSET_HANDOFF.md` explain the current reversed region frame (+X image-left, +Z north), explicit hero sizes/frames, whole-assembly replacement, native MeshSize preservation, water socket alignment, safe optional collisions and integration tests. No Roblox IDs fabricated. **Studio local FBX upload and native template capture remain pending**; available tools do not expose local FBX import. User can import `TropicalTidepoolsBundle.fbx` in Edit mode and stage it under `ServerStorage.RegionImportStaging`; integrate as a new library or merge deliberately, retaining old eight bay meshes.
- User reported Rojo connection failure during work: there was no Rojo process/listener. Started hidden Rojo 7.7.0 serving THIS repository on **localhost:34872**, PID 22416, responding at /api/rojo. Logs: `build/rojo-34872.log`, `build/rojo-34872-error.log`. User told to connect via Studio plugin. Latest read-only Studio check still has old bay script (no Tropical Tidepools header), so connection/sync is not yet verified. Studio remains **Edit**, instance b3a75559-3902-419f-bfbb-93da05d43f4e, place 88888194204730.
- No game scripts changed, no runtime tests claimed, no commit or publish. Next: connect Rojo; import and stage the new bundle; capture native templates and integrate using the handoff; run harness/runtime checks and compare the real map to the approved reference.

## Splashwater Bay rebuilt to the Tropical Tidepools concept — 2026-09-22

- **User request:** implement the approved Splashwater Bay concept (option 03, "Tropical Tidepools") so the region looks like the mockup. The bay was still the old circular-radius design — lighthouse, curved boardwalk, beached skiff, four small tide pools — while Gusty Gardens had already moved to the linear chain's 280 x 200 cell.
- **Method, same as the plot:** the concept's four gate piers are a known ground rectangle (44 apart, 200 deep), so they fit a homography that reads every flat feature back in studs; `concept-measured-grid.png` is that fit drawn back over the concept, landing on both wall bases exactly. **The fit exposed a real discrepancy: the concept draws a ~206-wide cell against MapBuilder's 280** — its gate is ~36% wider relative to the region than the engine's. `CELL_W` is shared with the approved Gusty Gardens and four other regions, so the cell wins: measured x is scaled by 140/103, z is taken 1:1, and the extra width lands in open sand down the middle, which is where the concept wants it. Five render/compare iterations from the concept's camera followed; three of the five found real defects (the cave mouth was turned away from the beach, the cascade's falls hung *behind* the rock face, the grotto dome poked 9 studs through the north wall).
- **Completed:** `SplashwaterBay.luau` rewritten. Two irregular tide pools hugging the side walls, each a chain of flat discs (a disc is the one primitive whose cross-section is not clamped square, so overlapping circles give the concept's scalloped outline) layered wet-sand / foam lip / water / deep middle. A hollow grotto over the west pool's head — 22 boulders in an arch, cut down across a 1.9 rad mouth arc that faces south down the beach, a recessed dark interior, and a fall off the sill. A three-tier cascade over the east pool with two glowing drops and a ledge pool between them. A three-rank perimeter band of palms (curved 7-drum trunks, 9 fronds of three hinged tapering blades), broad tropical leaf clumps, shrubs, hibiscus, daisies and boulders. Shells, starfish, pebbles, barrels and driftwood on the open sand.
- **Wiring:** `RegionScenery` now returns Water's layout spec (it was dropping it, so the bay kept the circular `SPAWN_RADIUS`). `MapBuilder` gains `OWN_PERIMETER[Water]` — the generic biome dunes fought the new border — and a `TRAIL_SAND` treatment: the concept shows no change of surface at all, so the lane's colour now matches `groundColor` exactly and only geometry marks the route. The paved 18-wide strip and its coloured kerbs read as a grey runway across a beach. `splashwater_bay.groundColor` warmed from `230,210,150` to `246,214,152`. `GardenBayProps`' Water branch rewritten: it now walks the whole region (the bay files boulders under `Shore` and inside the landmark models, not under `Landmarks`, so the old `Landmarks`-only scan would have swapped nothing) and swaps by the placeholder's own CFrame — `TideRock`, `SeaShell`, `Starfish` — while the barrels and logs, whose stacked-cylinder CFrames carry a baked quarter turn, are retired and re-placed from coordinate lists. `SB_Rope_Bollard` / `SB_Marker_Buoy` are now unplaced: the moorings they dressed went with the lighthouse.
- **Preserved, checked not assumed:** no gameplay change. Walls, piers, both gates, the barrier, the lock and the banner sign are still MapBuilder's; the north barrier still reads CINDER CANYON / 15K and the bay's own still reads SPLASHWATER BAY / 2.5K. Grepped for anything depending on the deleted props (lighthouse, boardwalk, skiff, mooring posts, life ring, lagoon) — **nothing outside the module referenced them**; every other reference to the bay is by region id (quest step 6, the unlock, the save round-trip). Region centre, `accessHalf`, `accessRadius`, unlock cost, income, hazard and species untouched.
- **Files:** `src/server/Map/SplashwaterBay.luau` (rewritten), `src/server/Map/GardenBayProps.luau`, `src/server/Map/RegionScenery.luau`, `src/server/Map/MapBuilder.luau`, `src/shared/Config/Regions.luau`, `tools/world_harness.luau` (now dumps `CanCollide`), new `docs/art/regions/2026-09-22-splashwater-bay/` (concept, measured grid, build render, comparison, layout doc, asset request), this file.
- **Validation, all headless:** 124 files pass the structure and quote scans; `lune run tools/world_harness.luau` builds **8,888 parts** (2,274 of them the bay); Rojo build `build/SplashwaterTidepools.rbxl` succeeds. Measured out of the dump: **dry walkable sand 72.9%** of the cell (water 19.8%, solid props 15.5%, mostly the perimeter band outside the capture field); **zero** wall crossings below the wall top from this module — the 11 reported are MapBuilder's own gate assembly standing in the divider plane by design; **4,000 `pickHome` samples replayed against the built water put 1.40% in water and 0.03% inside a solid prop**, and `clearOf` pushes roamers to a keep-out edge that is dry sand in every case; the 22-wide centre lane and both gate throats carry no solid obstruction but the barriers themselves. Climbing the 42-stud cascade cannot bypass a locked gate: `RegionAccessService` enforces a rectangular volume over the whole cell at every height, not a client-hidden wall.
- **Limitations:** **nothing has been seen in Roblox Studio** this session. Owed: stop Play, sync, boot, read `[SelfTest]` / `[LiveTest]`, walk the south threshold to both pools and through to the Cinder gate, and confirm the unlock still charges once. An eye-level render was attempted and abandoned — `tools/render_parts.py` has no near-plane clipping and fills the frame with the ground slab from a low camera; navigability was checked geometrically instead. The sand renders paler than the concept's warm tan (part renderer ambient, part colour) — judge it in Studio before changing it again. Rocks are chunky primitives where the concept has faceted meshes and the grotto's mouth is smaller than the concept's arch; both close when Astra's kit lands.
- **Care needed:** `src/server/Map/` is almost entirely **untracked** — only `MapBuilder.luau` and `PlotTemplate.luau` are in git. Ten region modules and all the prop kits have no version-control safety net. I deleted `SplashwaterBay.luau` to rewrite it before checking that, and had to restore the original from the session transcript; a copy of the pre-rewrite file is at `scratchpad/SplashwaterBay.luau.orig` for this session only. Worth a `git add src/server/Map` before the next art pass.
- **Studio:** not queried or changed. **No commit, no publish.**
- **Next:** Studio validation as above; then hand `docs/art/regions/2026-09-22-splashwater-bay/SPLASHWATER-ASSET-REQUEST.md` to Astra — eight meshes (grotto, cascade, three palms, two leaf clumps, hibiscus). Cinder Canyon is the next region to bring onto the chain concept.

## Player plot matched to the Pocket Power Town concept, measured not eyeballed - 2026-09-21

- **User request:** implement `docs/art/plots/2026-09-21-player-plot/CLAUDE_IMPLEMENTATION_PROMPT.md`, matching `plot-v2-pocket-power-town.png` exactly. A first pass was rejected: it preserved every contract but looked nothing like the concept. This entry supersedes it.
- **What went wrong first time, and the method that fixed it.** The first pass verified geometry contracts and never rendered the plot from the concept's camera, and its placeholders were deliberately crude. The rebuild starts from measurement: the concept's dark socket panels are detected in the image, a ground homography is fitted through the two unoccluded pad rows (**2.8 px** reprojection error), and a pinhole camera is fitted to the same 12 points (**1.5 px rms**: pitch 39.34, yaw 0.05, distance 85.0, fov 43.76). Every landmark is then read back in plot studs and the build is rendered from that camera for A/B. Two findings changed the layout: **the concept image is cropped** (the front kerb at z -29.3 projects to y 1074, below the 1024 frame, so the concept's plot is about 60 x 51 and its visible bottom grass is at z -22), and the first pass had every front landmark 5 to 8 studs too far forward.
- **Completed:** `PlotTemplate.luau` rebuilt at much higher fidelity. Pads are 5.4 dark sockets in 7.6 pale plates with L-shaped yellow corner brackets, matching the concept's lattice. The coin plaza moved from z -23 to **z -18**: three tiers, an ivory rim, inset warm bars, brick rear piers and stone front piers with lanterns, hazard chevrons down both flanks, two treads. The dispatch kiosk is a **rounded drum** at (20, -19) with a glazed band, cream cap and a domed red vent on a hazard plinth. The owner sign at (-21, -19) is an **arched** board: brick plinth, gold rim following the arch, cream face, crest with the cat mark, planting. The water tower at (11.5, 25.6) has splayed braced legs, a ribbed tank and a domed cap; the brick workshop at (-9.2, 26.4) has a stone parapet, roller door, chimney, wall lanterns and yard clutter. Plus a picketed 17-post fence, 12 lanterns, elevated teal mains with flanges, banners, planting, boulders and trees.
- **Bugs found and fixed along the way, all mine:** the headless renderer mirrored left-right (the camera right vector is forward x up, so plot +X lands on the image LEFT) - the first pass was read flipped; the "octagon" helper built two crossed squares, which is an **eight-pointed star**, so the kiosk is now a true cylinder; and `DecorSlots.compute` measured a rotated part by its unrotated `Size.X`, hiding free ground behind thin panels - it now uses the real rotated footprint.
- **Preserved, checked not assumed:** pad grid, indices and adjacency; `Platform` and `Apron` bounds (the driveway rule); `CollectPad` with its `Touch` attribute; `VentButton` `Prompt = Vent`; `Console` `Gui.Text`; `Billboard` `Gui.Title` / `Earnings`; `SpawnPoint`; `VisitorSpot`; `Tier_1..3`; `Rewards`; `Garden`; `padCFrame` / `pairCFrame` / `stationCFrame`. No creature, circuit, economy or progression change.
- **Files:** `src/server/Map/PlotTemplate.luau`; new `PlotAssetSpec.luau`, `PlotProps.luau`; `ImportStaging.luau`; `src/server/Systems/CityService.luau` (pad strips follow the creature element); `src/server/Systems/TestHarness.luau` (rewritten `testPlot`); `src/shared/Models/DecorSlots.luau`; `src/shared/Config/Cosmetics.luau`; `docs/CONTRACTS.md`; new `tools/verify_plot_props.luau`; `docs/art/plots/2026-09-21-player-plot/` (asset request, `comparison-concept-vs-build.png`, four build renders); `docs/superpowers/plans/2026-09-21-pocket-power-town-plot.md`; this file. Unrelated uncommitted work untouched.
- **Validation:** 124 files pass the structure and quote scans and a Lune compile. Headless build: **921 parts** (266 permanent, 585 placeholder art, 70 hidden tier), 16 lights, 31 GUIs, 24 prompts, **68 asset sites**. **Zero** intrusions into the 24 work-station boxes (3.0 x 2.6 x 4.5 behind each pad) or the 38 circuit-machine boxes (5.2 x 5.2 x 6.2 per adjacent pair); **zero** coplanar visible top faces beyond the Platform/Apron seam the threshold covers; a flood fill from the entrance reaches every pad, the vent, the console and both side aisles; **8 decoration slots**. `lune run tools/verify_plot_props.luau`: **709 checks pass**. Rojo build `build/PlotPocketPowerTown.rbxl` succeeds; stamp refreshed.
- **Limitations:** **nothing has been seen in Roblox Studio** this session (no bridge). Owed: stop Play, sync, boot, read `[SelfTest]` / `[LiveTest]`, take the elevated entrance-facing screenshot against the concept, deploy a creature and watch its pad strip, vent at the booth, collect on the coin. Stand-ins are faceted where the concept is smooth (tank dome, kiosk shell, sign arch, planting) - those four are the biggest wins from Astra's meshes. Per-plot parts rose from 166 to 921; the mesh swap collapses 585 art parts into 68 MeshParts, taking a plot to about 400. Mobile frame time unmeasured.
- **Studio:** not queried or changed; Rojo serves this checkout on **34872**. Stop Play before trusting the sync. **No commit, no publish.**
- **Next:** Studio validation as above, then hand `POCKET-POWER-TOWN-ASSET-REQUEST.md` to Astra; on delivery import `PlotPropsBundle`, capture `src/server/Map/PlotPropTemplates.rbxm`, rerun the harness and retake the comparison render.

## Thunderworks native props integrated; lightning warnings exposed — 2026-09-21

- User uploaded ThunderworksPropsBundle and asked to finish Thunderworks. Captured eight real native MeshParts into `src/server/Map/ThunderPropTemplates.rbxm` (53,202 bytes), preserving MeshSize and palette texture `rbxassetid://119095382742673`. Mesh IDs/native bounds are recorded in `assets/thunderworks/props-v1/roblox-import.json`. Raw gallery arrived 100x oversized; anchored and moved into ServerStorage.RegionImportStaging before Play.
- New `ThunderAssetSpec.luau` and `ThunderProps.luau`: validate the full kit and site contracts before replacing art; 33 exact bottom-centre placements, native clone sizes/IDs/textures, anchored/non-colliding/non-queryable/non-touching. Thunderworks now creates PlaceholderArt holders with explicit pivot/placement attributes and calls apply. Boundary, supports, catwalk, shed, collector towers and six scenery lights retained. ImportStaging recognizes the native bundle; TestHarness covers placements, road/spawn-field clearance and loose imports.
- Fixed buried Storm warnings: removed the 0.42-high YardSkin; the existing Asphalt Ground at 0.30 now carries the yard colour (Regions config). Seams/scuffs/drains have tops 0.302/0.304/0.306, below hazard-disc top 0.31. Two free-standing cable reels now use y=0.30 and SupportPath Ground; other anchors unchanged. No changes to hit detection, timings, economy or progression.
- Validation: **683 headless checks** using actual captured Thunder meshes (`tools/verify_thunder_placement.luau`), including partial-kit/100x-size/solid-placeholder rejection, exact native placement, permanent geometry/light preservation, staging and floor heights. All 122 source files compile and pass structure/quote scans. Rojo build `build/ThunderProps.rbxl` succeeds. Final boot **970 SelfTest / 72 LiveTest, zero failures**, stamp da98f6b* at 2026-09-21 12:33. All 66 instance-based mesh/texture preload callbacks succeeded; passing bare mesh-ID strings had reported Failure (wrong content-loading context), so use MeshPart instances for preload verification.
- Visual QA: overview and transformer/detail screenshots reviewed. Nine synthetic visual-only Storm events/markers through the normal Hazard remote rendered on the actual floor/scuff/drain locations and then all expired; no player teleport, profile change or damage applied. Geometry assertions include the non-queryable marks. Existing impact_generic.mp3 warning remains unrelated.
- Updated docs/CONTRACTS.md, kit README, measured-layout integration override and this relay. Large landmarks remain built-in region geometry; optional custom replacements and atmosphere are future refinements. Mobile performance unmeasured.
- Studio returned to **Edit mode**, official connection 321222ec-97bb-413b-b1bf-becaab817afb, place 88888194204730. Rojo source/native library read-back confirmed before Play; server on 34872. **No commit or publish.** Next: user reviews Thunderworks, then remaining regional atmosphere or broader hazard-floor audit.

## Orbit Outpost native assets integrated and verified — 2026-09-21

- Completed the approved V7 Gravity Garden kit integration: all 15 uploaded asset types placed at Claude's 51 sites, replacing only PlaceholderArt. Real native MeshParts captured in `src/server/Map/OrbitPropTemplates.rbxm` (93,819 bytes); IDs, texture and native bounds recorded in `assets/orbit-outpost/props-v1/roblox-import.json`. Palette texture is `rbxassetid://130269394998125`. Runtime meshes have contract sizes, retained native MeshSize, identity PivotOffset, anchoring, and no collision/touch/query.
- Raw `OrbitPropsBundle` arrived oversized and unanchored. Anchored it, cleared velocities, and moved it into `ServerStorage.RegionImportStaging` before Play. ImportStaging supports this bundle on subsequent runs. Do not put the raw gallery back into Workspace.
- Code: OrbitProps/OrbitAssetSpec, OrbitOutpost integration call, ImportStaging, TestHarness. Lab PointLights retained on attachments. Native placement leaves Boundary/Walkways/supports/glazing intact. Visual inspection caught the square LabCore hiding the round facade; OrbitOutpost now makes that collision proxy invisible (collision retained) and reduces the glass ellipsoid to 15.4 x 12.4 x 15.4 beneath the dome ribs. The ellipsoid uses a cubic Part and SpecialMesh scale; inspect effective dimensions, not Part.Size alone.
- Validation: 285 headless integration checks; 120-file structure/quote scans; successful Rojo build `build/OrbitProps.rbxl`. Actual uploaded kit: **968 SelfTests and 72 LiveTests pass**, including road/spawn-field clearance, native placement and support checks. Separate runtime audit found 51 correctly sized/anchored native placements and zero remaining PlaceholderArt. Six scenery lights retained; four additional sign/gate lights make ten across the entire region. Inspected runtime overview, drones/garden props, cradle and lab close-ups; repeated after lab fixes.
- Documentation: this relay, docs/CONTRACTS.md, asset README, roblox-import.json. Latest stamp `da98f6b*`, 2026-09-21 11:55. Preserve unrelated uncommitted work.
- Studio: connected official Roblox Studio MCP, Catch a Catastrophe place 88888194204730, session 321222ec-97bb-413b-b1bf-becaab817afb. User reconnected Rojo after restart; source and all fifteen templates read back before final Play. Returned to **Edit mode** after validation. Rojo serves active repository on port **34872**.
- Limitations: existing global lighting strongly blooms white surfaces; kit has static anchored meteor/stones, no orbit animation or lab gameplay. Existing `impact_generic.mp3` load warning is unrelated. No asset load errors observed. **No commit or publish.** Next: user visual review of Orbit Outpost; then whichever region/atmosphere refinement they choose.

## Orbit asset integration prepared; Studio import pending — 2026-09-21

- User asked to integrate assets after Claude completed the base. New `Map/OrbitProps.luau` and `OrbitAssetSpec.luau`; OrbitOutpost calls apply after creating its 51 sites. Full-set validation, manifest sizes, bottom-center frames, anchored/non-colliding meshes, and atomic placeholder replacement. The two lab PointLights are retained on attachments; all permanent collision/glazing stays intact.
- ImportStaging now recognizes OrbitPropsBundle, including a complete 15-mesh first upload before templates exist. Existing-library paths still require matching IDs; partial/unrelated bundles are preserved. TestHarness now supports native Orbit placements, includes those meshes in clearance/light checks, and detects loose Orbit meshes when templates exist.
- Headless `tools/verify_orbit_placement.luau`: **285 checks pass**, 51 placements, six lights retained, 30,280 placed triangles. Tests use existing native mesh fixtures ONLY in memory; actual uploaded Orbit geometry is still unavailable. Missing/partial kits, wrong scale, protected collision, preserved glass/lights, idempotence and raw-gallery staging covered.
- All 120 source files compile; structural/quote scans pass; stamp refreshed; Rojo build succeeds at `build/OrbitProps.rbxl`. No runtime visual test yet.
- Studio: WEPPY initially saw Catch a Catastrophe place 88888194204730 running. Its play-stop tool requires Pro. User stopped Play; WEPPY preflight confirmed Edit. Read-back confirmed OrbitProps and ImportStaging synced via Rojo. User then disconnected WEPPY. Built-in Roblox Studio MCP still lists zero studios; it must be enabled via Studio Assistant > ... > Manage MCP Servers > Enable Studio as MCP server.
- User has been asked to import `assets/orbit-outpost/props-v1/OrbitPropsBundle.fbx` in Edit mode with Upload to Roblox + Insert into Workspace and 15 separate meshes. Import not yet confirmed. No OrbitPropTemplates.rbxm, mesh IDs or texture IDs captured. No assets placed, no commits/publishing.
- Next: get built-in MCP connected and the uploaded bundle inserted; capture native templates preserving MeshSize, save source rbxm, stage raw gallery in ServerStorage, sync, run actual runtime and visual/clearance checks. Do not substitute fixture meshes for production.

## Orbit Outpost base region built and validated headlessly — 2026-09-21

- **User request:** build the playable Orbit Outpost base region per
  `docs/art/regions/2026-09-21-orbit-outpost/ORBIT-OUTPOST-CLAUDE-HANDOFF.md`, to the
  approved **V7 Gravity Garden** concept. Codex owns the Blender kit and later
  placement; nothing in `assets/`, `tools/blender/` or the shared Blender helpers was
  touched, and no asset IDs were invented.
- **Completed:** new `src/server/Map/OrbitOutpost.luau`, the sixth and last hand-built
  region, **463 parts** split `Boundary` 73 / `Walkways` 22 / `Landmarks` 368, six
  PointLights, **51 asset sites** using all fifteen kit meshes. A 36-segment ring of
  violet-grey rock terraces 9.5-20.4 tall, each carrying an invisible `BarrierField`
  collision core inside the cyan energy pane above it; two ivory research pillars
  framing a 20-stud entrance with no lintel; a 21 x 16 gravity dais at z 63.5 (top 5.0)
  reached by a tangential eight-tread flight up each flank, carrying the three-pronged
  cradle with the meteor suspended at y 12 inside it and three orbit stones; a closed
  round field laboratory on a pad on local +X with our own `LabGlazing` dome; three
  survey dock pads; a small teal utility nook on local -X.
- **Files:** new `src/server/Map/OrbitOutpost.luau`; new
  `docs/art/regions/2026-09-21-orbit-outpost/ORBIT-OUTPOST-LAYOUT.md` (the measured
  contract, full 51-site and 33-segment tables); edited
  `src/server/Map/RegionScenery.luau`, `src/server/Map/MapBuilder.luau`,
  `src/shared/Config/Regions.luau`, `src/server/Systems/TestHarness.luau`,
  `docs/CONTRACTS.md`, this file. No other region, no `assets/`, no `tools/blender/`,
  and no unrelated uncommitted work touched.
- **THE FINDING THAT MATTERS, and it is not only about Cosmic.** Orbit Outpost
  deliberately lays **no ground skin**, unlike every other hand-built region.
  `CaptureController` draws a circle/pull telegraph as a **0.3-thick disc centred
  `origin.Y + 0.16`**, and `origin.Y` is the creature pivot at the region centre's
  y = 0. The disc therefore spans **y 0.01 .. 0.31** against MapBuilder's ground disc
  top of 0.30 — it clears the floor by one hundredth of a stud. **Any walkable skin
  buries it.** Cosmic's floor is instead the region disc restyled in place:
  `Regions.list` Cosmic `groundColor` 45,40,70 -> **118,109,132** (that field is read in
  exactly one place, `MapBuilder:557`) and `GROUND_MATERIAL.Cosmic` `Metal` -> **`Sand`**.
  Walking height stays 0.30. **Thunderworks has this bug**: its 0.42 asphalt yard skin
  buries the Storm `HazardPatch` discs by the same arithmetic, and the readability claim
  in its entry below was argued from colour values only. Not fixed here — it is a
  separate region and a separate call. Splashwater/Cinder/Frostbite skins should be
  checked the same way.
- **Integration:** `RegionScenery` is now purely a dispatcher; all six elements delegate
  and the generic palette builder is gone. **The other five regions are unchanged,
  checked not assumed:** every element was dumped part for part before and after — name,
  model path, size, material, shape, all four collision flags, colour and the full
  12-component CFrame — and Wind 663 / Water 503 / Heat 589 / Frost 806 / Storm 683 are
  byte-identical. Cosmic goes from 178 parts at SceneryVersion 2 to **463 at version 3**,
  exercised through the real RegionScenery -> OrbitOutpost delegation, not a stub.
  `Cosmic` joins `OWN_ENTRANCE` in MapBuilder so the industrial post/lintel/hazard trim
  no longer fights the pillars. `Gate`, `Entrance`, `UnlockPrompt`, `GateSign`, tags,
  attributes, economy, species, progression and the Gravity Pulse hazard are untouched.
  No new mechanic: the lab is a closed facade, the barrier does nothing but collide, and
  the meteor and stones are anchored static placements.
- **Validation:** 118 files pass the structure and quote scans, `tools/stamp.py` run,
  Rojo build succeeds (`build/OrbitOutpost.rbxl`), and every `.luau` under `src` and
  `tools` compiles. A headless geometry suite runs the module against a faithful copy of
  MapBuilder's `part()` in the real region frame and measures oriented, shape-aware
  bounds — **35 checks, all pass**: part budget 463/650, 6/6 lights, all CFrames finite,
  flags correct, nearest solid footprint r=54.75 (and 47.47 by the live test's own
  cruder AABB rule, against its 44), nothing standing inside 54, approach corridor
  exactly 20.00, zero parts intersecting the board box, **all 27 sign sightlines clear**,
  road clearance >= 2 studs (smallest 3.25), **containment continuous at 0.25-degree
  steps over six heights probed from r 72.3 outward**, **no jump chain from the floor
  reaches containment** (highest reachable 6.80 lab roof, lowest containment 9.50, 2.00
  studs of margin), **zero coplanar top faces** across all 463 parts, every site on the
  kit contract with a `PlaceholderArt` holder, every grounded site exactly on a solid
  surface and not overhanging it, every stacked site landing on the site it names, and
  no two placed meshes intersecting.
- Two containment holes were found and fixed before any Studio run: the side/rear band
  was 15.0-19.4 and the 6.80 lab roof sits 2.25 studs from the wall, leaving only 1.0
  stud over a 7.2 reach (band now 16.0-20.4); and the 10-tall gate shoulders let a probe
  thread the 0.8-stud slot beside the Gate at y 11.5 (shoulder core now 13 tall, its
  field the same 3.4 depth, pillar cores widened to 5.6).
- **Deviations from the brief, recorded not hidden.** The dais is **21 x 16 at z 63.5**,
  not 23 x 19 at z 63: that slab reaches radius 73.4 at its back corners, 0.1 inside the
  rock terrace face at 73.5, and its front face would sit at 53.5 inside the flat field.
  Three sample pods, not four. The utility nook is blockout only and claims **no asset
  site**, because the Thunderworks meshes are not in the Orbit Outpost kit.
- **Limitations.** **Nothing has been seen in Roblox Studio.** No `[SelfTest]`/`[LiveTest]`
  numbers from this session, no visual review under game lighting, no screenshot, no
  top-down capture, and the Gravity Pulse telegraph has not been watched playing over
  this floor. A Rojo server was live on port **34872** and Studio was open the whole
  session, but this session had no bridge to Studio and **could not confirm Play was
  stopped before the source edits synced** — check that first. Everything above is a
  placeholder built to the manifest bounding box, not finished art. Mobile cost of 463
  static parts is unmeasured. Terrace boulders are non-colliding, as in every region.
  The concept's cosmic sky, floating islands, particles and orbit animation are not
  built and global Lighting/Sky was not touched.
- **Studio:** not queried or changed this session. **Publishing:** not published, not
  committed. Next: Studio validation of this blockout (stop Play, sync, boot, read
  `[SelfTest]`/`[LiveTest]`, walk the dais flights and watch a Cosmic capture), then
  Codex's staging and fitted meshes against `ORBIT-OUTPOST-LAYOUT.md`.

## Orbit Outpost V7 approved; Claude handoff and Blender kit ready — 2026-09-21

- User selected **V7 Gravity Garden** and requested assets plus a prompt for Claude to implement the base region.
- Handoff/reference: `docs/art/regions/2026-09-21-orbit-outpost/ORBIT-OUTPOST-CLAUDE-HANDOFF.md` and `orbit-outpost-v7-gravity-garden.png`. Claude owns OrbitOutpost base module, narrow Cosmic delegation, collision/terrain/glazing, exact PropSites and measured `ORBIT-OUTPOST-LAYOUT.md` return. Codex owns imported meshes and later placement.
- Completed 15 Blender meshes in `assets/orbit-outpost/props-v1/`: gravity cradle, meteor, orbit stone, lunar boulder, crystal cluster, two mushroom variants, fern, star blooms, drone, dock, sample pod, beacon, field lab base and dome frame. Includes editable props.blend, OrbitPropsBundle.fbx, 15 individual FBXs, dedicated palette, previews, fixed asset contract, manifest, README and validation.
- New tooling: `tools/blender/create_orbit_props.py`, `verify_orbit_props.py`, `render_orbit_landmarks.py`; shared Blender helpers unchanged.
- Validation: all 15 FBXs and bundle reimport passed exact sizes/pivots, closed manifold topology, positive face areas, finite vertices, identity scale, single material/UV, embedded palette and no preview geometry. Production blend verified. **12,388 triangles** for one of each asset. Actual mesh previews reviewed.
- No game source edited, Studio not queried or changed, no uploads, commits or publishing. Runtime appearance/scale/placement and performance remain unverified.
- Next: Claude builds base against 75-stud radius / 44-stud protected capture radius; return measured site table. Codex then registers safe staging/templates before requesting OrbitPropsBundle import. Current ImportStaging does NOT recognize OrbitPropsBundle. Raw imported galleries must be anchored and stored before Play to prevent previous falling/oversized asset issue.
- Suspended meteor/rocks remain anchored. Bottom-center GroundCF is region-local for all sites. Lab dome glass and permanent collision belong to Claude, separate from PlaceholderArt. Existing themed board and all roads stay clear.

## Thunderworks base region built and validated headlessly — 2026-09-21

- **User request:** build the playable Thunderworks base region per
  `docs/art/regions/2026-09-21-thunderworks/THUNDERWORKS-CLAUDE-HANDOFF.md`, to the
  written "storm-powered industrial yard" direction. Codex owns the Blender kit and
  later placement; nothing in `assets/thunderworks/`, `tools/blender/` or shared
  Blender helpers was touched, and no asset IDs were invented.
- **Completed:** new `src/server/Map/Thunderworks.luau`, the fifth hand-built region,
  **683 parts** split `Boundary` 122 / `Walkways` 112 / `Landmarks` 449, six PointLights.
  A dark asphalt yard skin to radius 73.5; a 48-segment concrete retaining ring in three
  heights (12.5-14.3 at the gate flanks, 17-21 sides, 20-23.6 rear) with full-height
  pilaster pairs, inset steel panels, chain link over the low run and four vent stacks;
  a steel entrance portal straddling the gate; a maintenance catwalk on local +X reached
  by a tangential flight at each end, crossing a closed cable trench 4.92 studs below its
  deck; a facade-only control shed on a service apron on local -X; and two 35.8-stud
  lightning collectors on a generator plinth across the rear carrying a static
  three-phase bus. 33 asset sites using all eight kit assets, each with `AssetName`,
  `AssetSize`, region-local `GroundCF`, `CollisionRole` and `SupportPath`.
- **Files:** new `src/server/Map/Thunderworks.luau`; new
  `docs/art/regions/2026-09-21-thunderworks/THUNDERWORKS-LAYOUT.md` (the measured
  contract, full 33-site and 45-segment tables) and `thunderworks-layout-plan.svg`;
  edited `src/server/Map/RegionScenery.luau`, `src/server/Map/MapBuilder.luau`,
  `src/server/Systems/TestHarness.luau`, `docs/CONTRACTS.md`, `RELAY.md`.
- **Integration:** `RegionScenery` now delegates Storm alongside Wind/Water/Heat/Frost;
  its dead Storm palette entry and the transformer/tesla-mast dressing are gone, leaving
  a Cosmic-only generic builder. **Cosmic output is unchanged, checked not assumed:**
  both elements were dumped part for part before and after the edit — name, model path,
  size, material, shape, all four collision flags, colour and the full 12-component
  CFrame — and the Cosmic dumps are identical, 178 parts at SceneryVersion 2. Storm goes
  from 208 parts at version 2 to 683 at version 3, exercised through the real
  RegionScenery → Thunderworks delegation, not a stub. Storm joins `OWN_ENTRANCE` in
  MapBuilder so the industrial `GatePost`/`GateLintel`/`hazardStrip` trim no longer fights
  the portal. `Gate`, `Entrance`, `UnlockPrompt`, `GateSign`, tags, attributes, economy,
  species, progression and the Lightning hazard are untouched. No new mechanic: the shed
  door, the glyph plates and the bus do nothing.
- **Validation:** 117 files pass structure and quote scans, stamp and Rojo build succeed
  (`build/Thunderworks.rbxl`), and every `.luau` under `src` and `tools` compiles.
  A headless geometry suite runs the module against a faithful copy of MapBuilder's
  `part()` in the real region frame and measures oriented, shape-aware bounds —
  **25 checks, all pass**: part budget 683/700, 6/6 lights, all CFrames finite, flags
  correct, nearest solid standing footprint r=58.50 (spawn field 44 clear), nothing
  standing inside 58, zero parts intersecting the board box, **all 27 sign sightlines
  clear**, road clearance ≥ 2 studs (smallest 2.784, GateShoulder) with the portal
  header measured separately at 15.475 of headroom, **containment continuous at
  0.25-degree steps over four heights**, **no jump chain from the yard reaches
  containment** (highest reachable 7.41, lowest containment 12.50, 2.42 studs of margin),
  **zero coplanar top faces** across all 683 parts, every site on the kit contract, on a
  solid surface, not overhanging it, and no two placed meshes intersecting.
- Two containment holes were found and fixed before any Studio run: the side wall band
  was 15-19 and the catwalk kerb at 7.41 put the coping inside a jump, and the buttresses
  were half-height brackets 1.8 studs from the deck edge — a two-hop ladder onto the wall.
  Sides are now 17-21 and the buttresses are full-height pilasters.
- Also worth recording: **Lune 0.10.5's `CFrame.lookAt` disagrees with Roblox**, negating
  the Z of `(target - position)`. Any headless harness for this project must shim it, or
  every region-frame measurement is silently mirrored.
- **Limitations.** Nothing has been seen in Roblox Studio: no `[SelfTest]`/`[LiveTest]`
  numbers from this session (baseline remains 941/72, zero failures, and the new Storm
  checks are additional), no visual review under game lighting, no screenshot, and the
  Lightning telegraph has not been watched playing over this floor — the readability
  argument is from colour values (yard 78,84,99 vs telegraph 255,235,110), not a capture.
  Mobile cost of 683 static parts is unmeasured. There are deliberately no approach
  decorations outside the gate, so the Crisis-spur risk that caught Frostbite does not
  arise. The large collectors, shed, catwalk, portal and wall panels remain placeholders.
- **Direction conflict to resolve first.** The concurrent entry below records four new
  Thunderworks/Orbit concepts with **no version selected**, and says the written art
  direction this blockout was built to is not an approved concept. The measured contract
  — frame, ring, containment, catwalk route, pads, prop anchors, clearances — survives a
  re-skin; the three landmark silhouettes (collectors, shed roof, portal) are what a V4
  Stormrail Depot or V5 Cliffside Dynamo selection would change.
- Studio: untouched this session, still in Play from the previous one; Rojo serving on
  34872. No commit, no publish. **Next:** user stops Play, resyncs and runs a fresh boot
  for real SelfTest/LiveTest numbers and a visual pass, and picks the Thunderworks
  direction so the landmark art can be fitted.

## Thunderworks / Orbit alternatives revised with actual assets — 2026-09-21 (latest)

- Generated three initial region concepts for each. User disliked them and
  requested more versions incorporating the already-created Blender assets.
- Created four new concepts using the actual Thunderworks props-v1 preview as
  image reference: Thunderworks V4 Stormrail Depot / V5 Cliffside Dynamo;
  Orbit Outpost V4 Starlight Salvage Dock / V5 Nebula Cliff Station. Actual teal
  transformer/cabinet, cream insulators, copper reel/conduit and capacitor kit
  are recognizable in the new images. New large landmarks are proposals, not
  already-built assets. Orbit is exploring kit reuse; no dedicated Orbit kit yet.
- All ten PNGs copied into `docs/art/regions/2026-09-21-alternatives/`;
  CONCEPTS.md records statuses/asset needs, PROMPTS.json records prompts/reference.
  Four new images visually reviewed. **No version selected yet.** Initial V1-V3
  and the earlier written Thunderworks art direction are not approved concepts.
- No source edits, Studio interaction, publishing or commit. Next: user chooses
  each region's direction, then revise handoffs before fitting landmark art.

## Thunderworks Claude handoff and Blender kit ready — 2026-09-21 (latest)

- User requested a local refinement handoff for Claude, followed by asset work
  while Claude builds. Saved and linked
  `docs/art/regions/2026-09-21-thunderworks/THUNDERWORKS-CLAUDE-HANDOFF.md`.
  Written art direction is a storm-powered industrial yard, based on the existing
  region identity, not a user-approved image. Rear collector towers, peripheral
  maintenance catwalk, generator shed, concrete/metal containment and open yard.
- Handoff assigns Claude base geometry/collision/routes/anchors and Codex assets
  and later placement. Includes current Lightning hazard, coordinate/gameplay
  constraints, exact eight-prop envelopes, two-stud road clearance (Crisis spur),
  board checks, source scope, tests, and measured THUNDERWORKS-LAYOUT.md return.
- Built eight props in `assets/thunderworks/props-v1/`: transformer, ceramic
  insulator, cable reel, capacitor bank, switch cabinet, vent housing, conduit
  elbow and storm bollard. Editable props.blend, individual FBXs, eight-mesh
  ThunderworksPropsBundle.fbx, unique palette, manifest, preview, validation,
  README. Front is Roblox +Z (ring inward), Blender -Y; exact envelope sizes.
- New generation and verification scripts under tools/blender. Existing helpers
  imported without changes. All eight individual FBX reimports and the bundle
  pass dimensions/origin/topology/UV/texture checks, total 10,548 triangles.
  Actual Blender preview inspected. Large collector/shed/catwalk/portal/wall
  art awaits Claude's measured return. No uploaded IDs or placement yet.
- No game-source edits, Studio interaction, publishing or commits this turn.
  Last verified game baseline remains 941 SelfTest / 72 LiveTest, zero failures.
  Next: Claude returns measured layout; fit remaining art, register Thunderworks
  import staging, import native meshes, preserve MeshSize/normalize scale, place.

## Gusty Gardens visual atmosphere implemented — 2026-09-21 (latest)

- Added `src/client/Controllers/GustyAtmosphere.luau`, initialized by Main.client.
  18 small drifting leaf shapes and three faint curved gust beams stay on the
  planted rim. A separate subtle warm ColorCorrectionEffect fades in within
  Gusty and returns to neutral outside it. All effects are client-only, anchored,
  non-colliding/non-queryable/non-touching; no global weather or physics changes.
- Uses a fixed 21-part population at 30 Hz, fading out by 180 character studs.
  Reduced motion hides all moving atmosphere, reduced flashing hides beams,
  CaptureState hides beams and dims leaves to 20%. Region replacement/respawn
  gaps and explicit destroy cleanly hide or remove effects and grading.
- GardenBayProps tags 12 flower clusters, five ferns and four shrubs for subtle
  ground-pivot sway. SceneryAnimator supports optional SceneryAmplitude (0.025
  on those 21 meshes, default 0.045 for existing sway). Existing static trees,
  mill/pinwheel spin, ground layout, signs and region access stay intact.
- Updated CONTRACTS; added `tools/verify_gusty_atmosphere.luau` for isolated client
  lifecycle/behavior checks with simulated observers (no player/camera movement).
  Tested 90 simulated seconds: leaf radius 52.50-61.50, finite frames, actual
  movement, capture suppression, both reduced settings, distance/respawn culling,
  warmth fade in/out, idempotent cleanup. Verified 21 tagged plant meshes on
  server and zero server-side GustyAtmosphereFX objects.
- Validation: 116 source files pass structure/quote scans, stamp and Rojo build
  succeed, synced Source compiles. Fresh Play **941 SelfTest / 72 LiveTest, zero
  failures**. Isolated ViewportFrame garden/leaf preview visually inspected and
  removed; actual character/world camera unchanged. Existing sound temp-read
  warning unrelated. No custom audio was added; mobile frame time unmeasured.
- Studio left in Play with Custom camera for user review. No commit/publish.
  Next: user reviews atmosphere in Gusty; remaining region landmark/refinement work.

## Frostbite approach props clear the Crisis road — 2026-09-21 (latest)

- User screenshot identified approach trees/rocks crossing the Crisis spur.
  Moved TreeSite23/25 and RockSite10/12 onto grass beside Frostbite's outer wall
  in `src/server/Map/FrostbitePeaks.luau`; moved local -X approach grass too.
  All 56 props retained. New coordinates also drive the placeholder fallback.
- Added a TestHarness regression checking full oriented footprints of external
  Frost props against every Map.Path, with a two-stud margin. Updated the measured
  layout doc/site table; its old SVG is explicitly marked as predating this fix.
- Validation: structure/quote scans pass (115 files), build and synced Source
  compile pass. Fresh Play **941 SelfTest / 72 LiveTest, zero failures**. Measured
  zero road overlaps across all eight approach meshes and eight grass tufts;
  moved mesh clearances 2.860 / 6.469 / 2.836 / 3.182 studs, grass minimum 1.618.
- Studio left in Play with normal camera; no character/camera teleport. No
  commit or publish. Next: user reviews approach; remaining Frost landmark art.

## Frostbite reusable Blender props integrated — 2026-09-21 (latest)

- User imported FrostbitePropsBundle; captured all eight native MeshParts into
  `src/server/Map/FrostbitePropTemplates.rbxm` (80,074 bytes), preserving internal
  MeshSize and normalizing the importer's 100x Size. Asset IDs and Frost palette
  `122924432155152` saved in `assets/frostbite-peaks/props-v1/roblox-assets.json`.
  Updated kit README and CONTRACTS. Binary transferred in base64 chunks using
  Studio SerializationService; no file picker automation or further upload.
- All 56 sites now use real Blender meshes: 12 tall firs, 13 saplings, six wide
  rocks, six tall rocks, five drifts, six icicle clusters, five crates, three coils.
  All anchored, non-colliding/non-queryable/non-touching, exact ground/top anchors
  (maximum measured position error 0). 216 Boundary and 177 Walkways parts remain.
- Raw FrostbitePropsBundle anchored and moved to ServerStorage.RegionImportStaging
  in Edit, then verified there after a fresh Play transition. Zero loose/oversized
  Frost imports in Workspace. Startup ImportStaging protection is active.
- Validation: 115 source files pass structure/quote scans, stamp and Rojo build
  succeed, synced module Source compiles, native template sizes/textures verified.
  Fresh Play: **940 SelfTest / 72 LiveTest, zero failures**. Client sees all 56
  props and all 112 mesh/texture preload requests succeed. Current ground-level
  screenshot inspected; no character/camera movement performed. Existing impact
  sound temp-read warning and Studio in-memory data adapter are unrelated.
- Studio left in Play with Custom camera for user review. No commit or publish;
  local place-save persistence is not claimed. Source/library integration is on disk.
  Remaining: full placement visual tour/mobile performance; fitted hut, bridge,
  cascade, cliff/peak/cornice/entrance artwork is still separate from this props kit.

## Frostbite prop integration prepared; import pending — 2026-09-21 (latest)

- User requested adding Frostbite assets. Eight props-v1 FBXs are ready, but
  connected Studio Edit contains no FP_ meshes or FrostbitePropsBundle. Native
  templates and Roblox asset IDs still need the user's Studio import. No actual
  Frost meshes have been placed yet; larger landmark art remains a separate pass.
- Added `src/server/Map/FrostbiteProps.luau`, called at the end of FrostbitePeaks.
  Preflights the complete kit and every site before replacing art; uses the 56
  measured anchors (50 grounded, 6 hanging), preserves site metadata, Boundary
  and Walkways, normalizes Size, sets safe decoration flags, and is idempotent.
  Missing/incomplete templates preserve all placeholders.
- Registered FrostbitePropsBundle / FrostbitePropTemplates in ImportStaging.
  Protection requires the native library and matching mesh names/IDs, so keep
  Studio in Edit after import until templates are captured and Rojo-synced.
  Extended live TestHarness mesh checks to Frost when its library is present,
  including every placement anchor and stray/oversized native-mesh detection.
- Updated CONTRACTS and kit README. Added `tools/verify_frostbite_placement.luau`:
  isolated Edit test using existing native mesh fixtures, not actual Frost art.
  Passes all 56 ground/hanging placements, incomplete/missing fallback,
  idempotence, unchanged 393 Boundary/Walkways parts, oversized raw bundle staging.
  115 source files pass structural lint and quote scan; Rojo build passes.
  Synced new modules compile in Studio. Full Play/visual validation awaits import.
- Studio: Catch a Catastrophe, place 88888194204730, Edit mode; no camera/player
  movement, no file picker automation. Rojo serving active project on 34872.
  No commit or publish. Next: user imports
  `assets/frostbite-peaks/props-v1/FrostbitePropsBundle.fbx` as eight separate meshes
  with its Frost palette. Capture native MeshSize-preserving templates, record
  asset IDs, normalize scale, stage originals, sync, then fresh Play and visual QA.

## Frostbite Peaks Alpine-Expedition blockout — 2026-09-20 (latest)

- **User request:** implement the base Frostbite Peaks layout from the approved V2
  "Alpine Expedition" mockup as a playable blockout with clearly named asset placeholders,
  per `docs/art/regions/2026-09-20-concepts/FROSTBITE-PEAKS-CLAUDE-HANDOFF.md`. Codex builds
  and places the Blender art afterwards. Codex's props-v1 kit and its relay entry below were
  written concurrently and are untouched.
- **Completed:** new `src/server/Map/FrostbitePeaks.luau` (806 parts), the fourth hand-built
  region. A blue-grey snow skin over the ground disc; a 48-segment terraced cliff ring in
  three zones (low knolls at the entrance flanks, 17-21 stud sides, a 23-26 stud ridge base
  across the rear), each segment a core wall plus a snow-capped bench and a thick cornice;
  a timber expedition arch at the gate; on local +X two tangential stair flights onto a ledge
  walkway with a nine-plank rope bridge sagging 1.15 studs over a frozen cascade and gorge
  between them, so the bridge is a route through and not a dead end; on local -X a third
  flight up to a hut terrace carrying a facade-only
  expedition hut with a teal gabled roof, warm windows, chimney and porch; five rear peaks
  to y 44.5 with linking saddles, outside the ring; 56 named Codex asset sites.
- **Structure:** like Cinder Canyon it splits output three ways — `Boundary` (216 parts,
  containment), `Walkways` (177, functional walking surfaces), `Landmarks` (413, replaceable
  placeholders). Every asset site is its own Model carrying `AssetName`, `AssetSize`,
  `GroundCF` (region-local, ground-centre; top-of-bounds for `hanging` icicles) and
  `CollisionRole`, so Codex places meshes without inferring anything by nearest neighbour.
- **Integration:** `RegionScenery` now delegates Frost alongside Wind, Water and Heat; its
  dead Frost palette entry, the glacier-crystal/pillar/arch dressing and the two conditionals
  Frost was the only false case of are gone. Storm and Cosmic output is unchanged, checked
  rather than assumed: the pre-edit builder was reconstructed and both elements dumped through
  the harness, and the two dumps are identical part for part — Storm 208, Cosmic 178, matching
  on name, host, size, full CFrame, colour, material and the collide/query flags. Frost joins
  Wind and Water in MapBuilder's new `OWN_ENTRANCE` set, so the industrial `GatePost`/
  `GateLintel`/`hazardStrip` trim no longer fights the timber arch. `SceneryVersion` 3 for
  Frost via `SCENERY_VERSION` in `TestHarness`. `Gate`, `UnlockPrompt`, `Entrance`,
  `GateSign`, tags, attributes, economy, species, encounters and the Ice Wave hazard are
  untouched. No new mechanic: the hut door, the arch plaque and the cascade do nothing.
- **Files:** new `src/server/Map/FrostbitePeaks.luau`; new
  `docs/art/regions/2026-09-20-concepts/FROSTBITE-PEAKS-LAYOUT.md` (the measured asset
  contract, with the full 66-site table) and `frostbite-peaks-layout-plan.svg`; new
  `docs/superpowers/plans/2026-09-20-frostbite-peaks-blockout.md`; edited
  `src/server/Map/RegionScenery.luau`, `src/server/Map/MapBuilder.luau`,
  `src/server/Systems/TestHarness.luau`, `docs/CONTRACTS.md`, this file. No other region,
  no `assets/`, no `tools/blender/`, and no unrelated uncommitted work touched.
- **Validation:** 114 files pass the structure and quote scans; `tools/stamp.py` run; Rojo
  build succeeds at `build/FrostbitePeaks.rbxl`. Beyond that the module was **executed
  headless** under Lune 0.10.5 with a Roblox datatype shim and every part measured in the
  region's own frame, with Gusty Gardens, Splashwater Bay and Cinder Canyon run through the
  same harness as controls (which reproduced their recorded 663 / 503 / 589 part counts
  exactly). Results, Frostbite first: **0 solid parts inside radius 44**, innermost solid
  59.00 true / 55.35 by the harness's AABB rule (Cinder 50.30, Gusty 53.68, Splashwater
  46.89); **0 parts over 0.95 studs tall inside radius 58** (Cinder 51, Gusty 356,
  Splashwater 33); **0 Neon inside 58**; **0 coplanar overlapping top faces** by exact SAT
  (Cinder 7, Splashwater 68, Gusty 208); one boundary opening 14.75 degrees wide, identical
  to Gusty's; 0 parts intersect the board box and **0 of 27 board sightlines blocked**; all
  transforms finite. Walkable route: **177 of 177 surfaces reachable on foot**, largest
  horizontal gap **0.000**, largest riser **0.546** against the brief's 0.70 target, largest
  step 0.440 (the bridge sag). All 56 asset sites reproduce their manifest bounding box to
  within **0.0007 studs** and rest on a real surface to within 0.06. An exhaustive prop
  overlap sweep drove the final site schedule: it caught props standing inside the terrace
  stair and a fir left floating 3.8 studs by a late cliff-height change, and now reports zero
  overlaps beyond one deliberate stacked crate and four bench firs whose canopies tuck into
  the rock behind them.
- **Finding, measured not fixed:** a default Humanoid can chain jumps onto the containment
  ring in **every** region — Gusty in 1 hop, Frostbite 3, Cinder 4, Splashwater 4 at a 7.2
  reach. Tuning the cliff zone heights moved Frostbite from 2 hops to 3 and put `PeakBase`
  out of reach, which is as far as it goes without flattening the approved terraced cliff.
  It is not an unlock bypass: `RegionAccessService` re-checks a 78-stud cylinder every 0.2 s
  at every height, which is exactly the case it was written for. Worth the user's ruling.
- **Limitations:** placeholder geometry, not finished art. 806 parts is the highest of the
  four hand-built regions (Gusty 663, Cinder 589, Splashwater 503); the cheapest trims are
  listed in the layout doc. Seven PointLights. The render's distant mountain range and the
  cave mouth in its left cliff are not built; the board stays left of the entrance where
  `GateSign` fixes it, so the arch's hanging plaque is decorative. Mobile cost unmeasured.
- **Not verified in Studio.** No Roblox bridge in this session, so the 935 SelfTest / 72
  LiveTest baseline, the new `SceneryVersion` 3 assertion, the live sign rays, spawning,
  roaming, walking the stairs and bridge, and whether the cyan Ice Wave telegraph reads
  against `rgb(191, 207, 220)` snow have not been seen running. That is the next thing to do.
- **Studio:** not queried or changed this session. **Publishing:** not published, not
  committed. Next: Studio validation of the blockout, then Codex's fitted hut, bridge,
  cascade, cliff and peak meshes against `FROSTBITE-PEAKS-LAYOUT.md`.


## Frostbite V2 approved; Claude handoff and Blender kit ready — 2026-09-20

- User selected V2 Alpine Expedition and requested a local Markdown handoff for
  Claude to implement the base while Codex creates Blender assets.
- Handoff: `docs/art/regions/2026-09-20-concepts/FROSTBITE-PEAKS-CLAUDE-HANDOFF.md`.
  Includes approved image, gameplay clearances, module boundaries, named prop
  placeholders, validation requirements and measured layout return document.
  Claude owns the base layout; Codex owns custom art/import/placement.
- Built eight props in `assets/frostbite-peaks/props-v1/`: two snow rocks, two
  snowy firs, snow drift, icicle cluster, supply crate and rope coil. Includes
  editable `props.blend`, individual FBXs, `FrostbitePropsBundle.fbx`, a new
  palette texture, manifest, preview, validation report and import README.
- Validation: final preview visually reviewed; fresh Blender FBX reimport passes
  all eight meshes and bundle (4,716 triangles total). Checks dimensions, ground
  origins, closed geometry, UVs, embedded palette and exact bundle membership.
- New Frost generation/verification scripts under `tools/blender/`; shared
  garden/bay generator now has a main guard so helpers can be imported without
  regenerating existing kits. No game-source edits or Studio interaction this
  turn; no uploads, publishing or commits. Existing game test baseline below.
- Next: Claude returns `FROSTBITE-PEAKS-LAYOUT.md` with measured anchors; fit hut,
  bridge and mountain art to it, then import/integrate. Register the Frost raw
  bundle with ImportStaging before live import; preserve native MeshSize and
  normalize import scale. Frost palette differs from the garden/bay texture.

## Frostbite Peaks concepts created — 2026-09-20

- User requested several Frostbite Peaks mockups. Generated and visually reviewed
  three separate landscape concepts using the imagegen skill: V1 Glacier Gateway
  (ice arch/frozen waterfall), V2 Alpine Expedition (mountain ridge/hut/rope bridge),
  V3 Frozen Crystal Basin (crystal skyline/ice grotto/overlook).
- Images saved as frostbite-peaks-v1-glacier-gateway.png,
  frostbite-peaks-v2-alpine-expedition.png and
  frostbite-peaks-v3-frozen-crystal-basin.png under
  `docs/art/regions/2026-09-20-concepts/`. FROSTBITE-ALTERNATIVES.md records the
  comparison, custom Blender asset needs and gameplay constraints;
  FROSTBITE-PROMPTS.json preserves the generation prompts.
- All concepts retain a broad open snow field with scenery around the edge and
  a contained entrance. V2 recommended for alpine identity; **no user selection
  yet**. Concepts are not implemented assets. Existing board position/access/
  collision rules take precedence over decorative details in the render.
- No game source changes, Studio interaction, publishing or commits this turn.
  Last verified Studio state remains Play with the falling-import fix below.
  Next: user selects a direction, then prepare its blockout and Blender asset kit.

## Giant falling import assets fixed — 2026-09-20

- **Reported:** enormous daisies/rocks fell from the sky after Gusty/Splashwater
  integration. Diagnosis confirmed two raw FBX bundles still in Edit Workspace,
  each with eight unanchored meshes at 100x scale. In Play most fell below the
  world, leaving a giant daisy cluster and coastal rock resting on the map.
  Placed region meshes and native templates were correctly scaled/anchored.
- **Correction to prior checkpoint:** previous claimed staging cleanup did not
  persist across Play. Do not assume MCP Edit reparent/destroy alone permanently
  removes imported place content; verify after a fresh Play transition.
- **Fix:** new `Map/ImportStaging.luau`, called first by MapBuilder.build. Exact
  raw bundle names plus matching native template mesh names/IDs identify staging
  imports. They are anchored, velocity cleared, and preserved under
  ServerStorage.RegionImportStaging before map construction. Already placed
  props and unrelated models are excluded. Applied in Edit too, then tested
  through fresh Play. Updated TestHarness and CONTRACTS.
- **Validation:** 113 Luau source files pass structure/quote scans; Rojo build
  and synced Source compile checks pass. Fresh Play: **935 SelfTest / 72 LiveTest,
  zero failures**. Five new regression checks exercise raw oversized unanchored
  imports, preservation, idempotence, unrelated-model exclusion, and world-wide
  stray asset detection. Server confirms 16 anchored imports in storage, zero
  raw imports in Workspace. Client confirms all 138 legitimate region props,
  zero unanchored/oversized/untagged kit meshes. Existing sound temp-read warning
  is unrelated. No character/camera teleport.
- **State:** left Studio in Play with normal Custom camera for review. No
  publishing or commit. Raw imports are retained in storage; local place save
  state is not claimed. Source startup protection handles residual bundles.

## Splashwater + Gusty Blender assets integrated — 2026-09-20

- **Completed:** all 16 uploaded assets connected to Rojo and placed. Gusty has
  43 meshes: 15 moss rocks, 12 flower clusters, five trees, five ferns, four
  shrubs and two planters. Splashwater has 63: 28 tide rocks, 15 shell clusters,
  nine rope bollards, five starfish, two driftwood, two barrels and two buoys.
- **Files:** new `src/server/Map/GardenBayProps.luau`, `GustyPropTemplates.rbxm`
  and `SplashwaterPropTemplates.rbxm`; both region builders call Props.apply.
  Asset IDs recorded in each kit's roblox-assets.json; shared texture is
  106126534995097. Updated TestHarness, CONTRACTS and both kit READMEs.
- **Import:** initial Workspace was empty and inventory search found no models.
  User then inserted both bundles. Serialized native MeshParts preserving
  internal MeshSize; normalized their 100x import scale. Gusty serialization
  exceeds MCP's single-result limit, so transferred in 24k base64 chunks. Do not
  replace native templates with MeshId+Size-only XML. No UI automation used.
- **Preserved:** original solid rock proxies (hidden), continuous region
  boundaries, boardwalk, skiff, windmill, lighthouse, signs and access logic.
  New props are anchored and non-colliding/non-queryable/non-touching. Whole-mesh
  trees are static; grass, mill sails, pinwheels and harbor pennant still animate.
- **Fix:** Gusty's beam helper supplies an alternate up vector for vertical
  segments, fixing NaN FlowerStem frames even when the mesh kit is unavailable.
- **Validation:** 112 source files pass structure/quote scans; Rojo build passes.
  Synced source compiled and confirmed before Play. Isolated Studio overviews
  and ground-level detail inspected. Fresh startup passes **930 SelfTest / 72
  LiveTest, zero failures**, including eight new checks for all variants, valid
  mesh bounds/scale, decoration flags and finite scenery frames. Existing field
  and sign clearance checks pass. Client confirms all 106 props replicated, all
  16 mesh IDs and the shared texture fetched successfully.
- **Cleanup/state:** removed isolated preview models, imported staging bundles
  and serialization buffers after saving templates. Studio left in Play with
  normal Custom player camera; no character teleport. Existing impact_generic.mp3
  temp-read warning persists. Mobile performance unmeasured. No publish/commit.
- **Next:** user reviews Gusty/Splashwater prop pass in game; refine sizes,
  density or fitted landmarks based on that review.

## Splashwater + Gusty Blender kits created — 2026-09-20

- User approved Cinder in game and requested custom assets for Splashwater Bay
  and Gusty Gardens. Created eight reusable props per region (16 total), using
  their existing source layouts as placement references. No game source edited.
- Splashwater: wide/tall coastal rocks, driftwood, scallop-shell cluster,
  starfish, rope bollard, harbor barrel, marker buoy. 3,796 triangles total.
- Gusty: wide/tall moss rocks, daisy cluster, bluebell cluster, fern, meadow
  shrub, wind-bent tree, flower planter. 7,212 triangles total. Tree is a static
  one-mesh prop; do not apply old canopy sway to the whole trunk when integrating.
- Deliverables in `assets/splashwater-bay/props-v1` and
  `assets/gusty-gardens/props-v1`: editable props.blend, individual FBXs,
  SplashwaterPropsBundle.fbx / GustyPropsBundle.fbx (eight separate meshes each),
  packed palette.png, actual Blender preview.png renders, manifests, validation
  results and READMEs with placement mappings/import guidance.
- Reproduction: `tools/blender/create_garden_bay_props.py` and
  `tools/blender/verify_garden_bay_props.py`. Refuses existing .blend by default;
  --replace-generated deliberately overwrites generated files, --garden-only
  limits rebuilding to Gusty. Preserve any hand edits before regeneration.
- Validation: all 16 FBXs independently reimported into fresh Blender scenes;
  dimensions, zero origins, triangles, closed topology, positive face areas,
  one material/UV layer, palette UV centres and embedded images all pass.
  Both bundles contain exactly their eight named assets. Both final renders
  inspected. Corrected mismatched UV names between primitives/custom geometry
  before delivery; refined moss cover and inset planter soil after visual review.
- **Not yet imported or placed in Roblox.** No runtime/lighting/mobile checks.
  No changes to windmill, lighthouse, boats, boards or barriers. Asset creation
  requested this turn; next step is manual Studio bundle import, then native
  serialization into Rojo and placement. Cinder import lessons below still apply;
  do not use file-picker automation. Normalize import scale against manifests.
- Studio was queried in Play and left untouched. No upload, publish or commit.

## Cinder Blender props integrated — 2026-09-20

- **Completed:** placed all nine existing Blender prop variants as 32 MeshParts
  in Cinder Canyon: five basalt spire clusters, six ember groups, four curb rocks,
  six channel rocks, two approach boulders, seven flattened field-rubble groups,
  and two sandstone accents. Original solid placeholder collision proxies are
  hidden but retained; Boundary (216 parts) and Walkways (92) remain intact.
- **Files:** new `src/server/Map/CinderProps.luau` and native serialized
  `CinderPropTemplates.rbxm`; CinderCanyon calls Props.apply after its blockout.
  SceneryVersion remains 4; BlenderPropsVersion is 1. Four regression checks added
  to TestHarness for imported geometry bounds/scale, all nine variants, and flush
  rubble. Updated CONTRACTS and the props README. Asset IDs recorded in
  `assets/cinder-canyon/props-v1/roblox-assets.json`. Added bundle FBX and its
  exporter `tools/blender/export_cinder_bundle.py`.
- **Import:** automated connector required a Pro license; native CreateAssetAsync
  was unavailable. UI automation repeatedly opened the file picker, which bothered
  the user. Stopped it and removed the helper. User manually imported the bundle.
  Do not repeat desktop automation. Import used 100x scale, corrected in templates.
  Native SerializationService preserves MeshSize/internal mesh bounds; a handmade
  MeshId+Size-only XML rendered enormous geometry and was discarded. Keep the
  `.rbxm` templates when updating these assets. Imported workspace bundle and
  isolated preview were removed after saving persistent source templates.
- **Validation:** 111 Luau files pass structure/quote scans, Rojo build passes,
  synced Source confirmed before Play. Studio overview and mesh close-up inspected.
  Fresh Play automatically passes **922 SelfTest / 72 LiveTest, zero failures**.
  All nine mesh IDs and palette texture report client AssetFetchStatus.Success;
  all 32 props replicated. Field clearance and 27 sign rays pass. An extra manual
  harness.run via MCP used a separate require cache and reported a missing service;
  this was a probe-context issue. Clean Play rerun passed normal startup suites.
- **Limitations:** existing small props integrated only. Large cliff kit, arch,
  bridge and lavafall terraces remain Claude's blockout geometry. Mobile frame
  time unmeasured. Existing impact_generic.mp3 temp-read warning still appears.
- **Studio:** left in Play, normal Custom player camera, no character teleport.
  **Publishing:** no experience publish and no commit. Mesh upload was performed
  by the user through Studio. Next: user reviews this prop pass, then fitted hero
  landmark/cliff assets against CINDER-CANYON-LAYOUT.md.

## Cinder Canyon Sculpted-Ravine blockout — 2026-09-20

- **User request:** implement the base Cinder Canyon layout from the V2 "Sculpted Ravine"
  mockup as a playable blockout with clearly named asset placeholders, as a coordinated
  handoff: Codex builds and places the Blender assets afterwards.
- **Completed:** new `src/server/Map/CinderCanyon.luau` (589 parts), the third hand-built
  region after Gusty and Splashwater. A terracotta field skin with swept sediment over the
  existing ground disc; a 48-segment ring in three rock styles (low columnar basalt either
  side of the entrance, three-band terracotta strata left and rear, slanted splayed basalt
  rear-right and right); a sandstone arch at ring bearing 152 whose opening sits above a
  level 16-stud wall; a fissure at bearing 228 feeding three lava ribbons onto four stepped
  ledges; a recessed perimeter lava terrace and three recessed lava channels, all behind
  dark curbs; a ledge walkway with an eight-riser stair, a curved black-stone bridge over a
  lit crevice, and a side alcove; carved entrance pillars with bronze lanterns; basalt
  spires, ember crystals and dry grasses.
- **Structure:** unlike the other two modules it splits output three ways — `Boundary`
  (216 parts, containment), `Walkways` (92, functional walking surfaces), `Landmarks`
  (281, replaceable placeholders) — so an art pass cannot take the floor or the barrier
  with it. `RegionScenery` now delegates Heat alongside Wind and Water; its dead Heat
  palette, ember-seam branch, volcano dressing and the then-unused `ROCK` local are gone.
  `SceneryVersion` 4 for Heat via a new `SCENERY_VERSION` table in `TestHarness`.
- **New test:** `region field clearance` in the live suite. For every region, no solid part
  narrower than `SpawnRadius` may come within `SpawnRadius` of the centre, measured from
  the nearest point of its ground footprint. Nothing tested the catching field before.
- **Files:** new `src/server/Map/CinderCanyon.luau`; new
  `docs/art/regions/2026-09-20-concepts/CINDER-CANYON-LAYOUT.md` (the asset handoff
  contract) and the v2 PNG, which the brief cited but was missing from the repo;
  `cinder-canyon-layout-plan.svg`, a measured top-down plan of the blockout; new
  `docs/superpowers/plans/2026-09-20-cinder-canyon-blockout.md`; edited
  `src/server/Map/RegionScenery.luau`, `src/server/Systems/TestHarness.luau`,
  `docs/CONTRACTS.md`, this file. No other region and no unrelated uncommitted work touched.
- **For Codex:** `CINDER-CANYON-LAYOUT.md` is the dimensioned contract you were waiting on
  — coordinate frame, radial budget, every placeholder's name/size/frame/collision, and a
  section 5b mapping your nine `props-v1` meshes onto the placeholder groups with cluster
  sites as ring bearings. Two notes from that mapping: the basalt spires run 9.0-18.6 studs
  tall so `CC_Basalt_Tall` at 5.80 needs a taller variant, and `CC_Sandstone_Rubble` at
  1.25 tall is 3x too tall for `FieldStone`, which sits inside the catching field and must
  stay under half a stud proud. Your props are ground-centre pivoted; placeholders here are
  centre-pivoted, so place meshes at `top - size.Y`.
- **Validation:** 110 files pass the structure and quote scans; Rojo build succeeds at
  `build/CinderCanyon.rbxl`. Beyond that the module was **executed headless** under Lune
  0.10.5 with a Roblox datatype shim and every part measured in the region's own frame,
  with Gusty Gardens and Splashwater Bay run through the same harness as controls:
  0 solid parts inside radius 44 (innermost solid scenery is the stair at 50.4, against
  Splashwater's shipped TideShelf at 46.9); innermost Neon 57.9; 0 of the 27 board
  sightlines obstructed; boundary ring opening identical to both shipped regions; no solid
  part in the 13.5-stud approach corridor; walkway + bridge + alcove is 24 surfaces with a
  largest horizontal gap of 0.00 and a largest step of 0.84; stair risers 0.618; arch apex
  35.6 over a 17.2 wall top. An exact SAT pass on coplanar overlapping top faces found 7,
  all intentional flush joints, against 74 in Splashwater and 394 in Gusty; five real
  z-fighting pairs found this way were fixed before finishing.
- **Caution for anyone reusing that harness:** Lune 0.10.5's `CFrame.lookAt` returns the
  negated Z of Roblox's — `lookAt(origin, +Z).LookVector` is `(0,0,-1)`. The harness
  patches it by mirroring the target. `CFrame.Angles` is correct.
- **Incidental finding, not fixed (out of scope):** `GustyGardens.luau` builds 36
  `FlowerStem` parts with a NaN CFrame, from a `beam()` whose endpoints differ only in Y —
  `CFrame.lookAt` with a vertical look direction and the default up vector is degenerate in
  real Roblox too. Worth a look when Gusty is next touched.
- **Not verified in Studio.** No Roblox bridge in this session, so SelfTest, LiveTest, the
  new clearance check, spawning, roaming, telegraph readability and actually walking the
  bridge have not been seen running. That is the next thing to do.
- **Limitations:** placeholder geometry, not finished art — flat strata bands, faceted
  voussoirs, no sculpted erosion. The board sits left of the entrance where the render puts
  it right, because `GateSign` is fixed and the brief says to preserve it. The arch opening
  starts above the barrier, deliberately. Seven PointLights added. 589 parts, between
  Splashwater's 503 and Gusty's 663, so the map total rises by roughly 530 once the old
  Heat dressing is gone; mobile cost still unmeasured.
- **Studio:** not queried or changed this session. **Publishing:** not published, not
  committed. Next: Studio validation of the blockout, then Codex's fitted
  cliff/arch/bridge/lavafall meshes against `CINDER-CANYON-LAYOUT.md`.


## Cinder reusable Blender props started during Claude blockout — 2026-09-20

- **Coordination:** user leans toward V2 Sculpted Ravine, has handed the region
  base layout to Claude, and asked whether assets can start concurrently. Began
  independent reusable props; fitted cliffs/arch/bridge await Claude's dimensions.
- **Completed:** nine actual Blender meshes: three basalt clusters, three ember
  crystal clusters, three sandstone rock groups. Shared palette texture, editable
  Blender 5.1 scene, individual FBXs, preview render, dimensional manifest and README
  under assets/cinder-canyon/props-v1. Reproducible scripts in tools/blender.
- **Validation:** 224–560 triangles per asset; 2,864 total. All nine FBXs round-trip
  through Blender with dimensions, zero origins, triangle counts, UVs, image material
  and closed topology verified. Corrected export axis baking during validation.
  Final actual Blender preview visually reviewed; validation.json records results.
- **Limitations:** first style pass, not final detailed landmark kit. Studio import
  scale/materials, mobile performance and placement await map handoff. No Roblox
  asset upload. Crystal glow is a later placement effect; texture is flat palette.
- **Files/scope:** asset directory and two Blender tools only, plus this checkpoint;
  no game scripts or Studio edits. No commit/publish. Claude can continue base layout.
- **Next:** review prop style, receive Claude's asset placeholders/dimensions,
  build fitted cliff/arch/bridge/lavafall meshes, then integrate and place assets.

## Two alternative Cinder Canyon concepts — 2026-09-20

- **Completed:** user's requested couple of different mockups: Sculpted Ravine
  (v2: natural sandstone arch, side walkway, tiered lavafalls) and Obsidian Caldera
  (v3: split crater crown, dark walls, lava tubes, ember crystals). Both explicitly
  design around custom Blender assets and a clear central catching field.
- **Files:** v2/v3 named PNGs plus CINDER-ALTERNATIVES.md under
  docs/art/regions/2026-09-20-concepts; exact prompts and built-in image tool provenance.
- **Validation:** visually checked both generated images, region name, open entrance,
  clear central floor and distinct silhouettes. Saved finals; originals retained.
- **Limitations:** concepts only, geometry/collision/performance not yet validated.
  No Blender assets or code implemented; existing board design remains authoritative.
- **Studio/publishing:** unchanged; no commit or publish. Next: user's preferred
  Cinder direction, followed by refinement or remaining region concepts.

## Cinder Canyon environment concept; Blender assets available — 2026-09-20

- **User request:** region environment mockups, starting with Cinder Canyon.
  Explicit steering: account for custom Blender assets to improve each region.
  Do not constrain upcoming environment designs to procedural primitive parts.
- **Completed:** first Cinder overview concept: continuous layered red-rock cliffs,
  rear volcano/lavafall, peripheral lava channels/basalt clusters, a side footbridge,
  amber crystals and vents, wide clear catching field and entrance.
- **Files:** docs/art/regions/2026-09-20-concepts/cinder-canyon-v1.png and
  CINDER-CANYON.md (exact prompt, built-in image tool provenance, Blender asset brief).
- **Validation:** visually reviewed composition, enclosing barriers, clear central
  play space and entrance; saved image and kept original generation output.
- **Limitations:** concept only, no region code changes or Blender assets built.
  Board in the image is illustrative; retain the existing implemented board/live text.
- **Studio/publishing:** unchanged from previous checkpoint; no publish or commit.
- **Next:** user reviews Cinder direction; remaining environment concepts are
  Frostbite Peaks, Thunderworks and Orbit Outpost, with custom Blender kits in scope.

## Monster label readability and placement — 2026-09-20

- **User request:** fix monster labels; screenshot showed awkward wrapped difficulty
  symbols, a missing Legendary glyph, and labels floating well above Water creatures.
- **Completed:** separate cream Fredoka name, rarity-coloured metadata, plain
  Difficulty N/5, and optional claim-status rows. A supported diamond marker plus
  explicit rarity name replaces ornate missing glyphs in these world labels.
  Wild labels anchor to PrimaryPart at Height + 0.7, with the bottom of the label
  above the creature. Camera-depth scaling caps width at 250 px and shrinks to 55%.
  World occlusion retained; wild labels tracked within 90 character studs, camera
  MaxDistance 150 so normal zoom does not hide a nearby creature's label.
- **City labels:** use the same layout/height anchor and local distance scaling;
  metadata preserves rarity and variant (or element), Title preserves favorite marker,
  Detail shows live Coins/s. Economy updates only Detail, preserving other rows.
- **Files:** new src/shared/Util/CreatureLabel.luau; CaptureController, CityService,
  docs/CONTRACTS.md. Existing unrelated edits preserved. Capture mechanics unchanged.
- **Validation:** 109 files pass structure/quote checks; Rojo build at
  build/MonsterLabelsReview.rbxl; all three changed modules compile from synced Source.
  Preview compares Duck/Pug/Toad plus a Prismatic Boltjaw worker and claim status;
  416 text-fit checks across all 26 species at four camera depths pass. Preview removed.
  Fresh Play: map 4,797 parts, SelfTest 912/0, LiveTest 72/0. All six deployed
  labels fit and their income matches the real client snapshot. These suites also
  exercise the latest six board sightline checks. Existing stock sound warning remains.
- **Limitations:** no phone/controller visual pass or crowded-label collision system.
  The bottom target card's existing star notation is outside this world-label pass.
  Wild visuals reviewed in an isolated Edit lineup; user should judge normal gameplay.
- **Studio:** correct Catch a Catastrophe place 88888194204730, left in Play with
  normal player camera. No character teleport or ownership/purchase changes by probes.
  Rojo synced, build stamp 2026-09-20 20:20.
- **Publishing:** not published or committed. Next: user reviews monster labels,
  then Cinder Canyon scenery refinement. All six boards are implemented.

## Final four region boards built from the concepts — 2026-09-20

- **User request:** implement Cinder Canyon, Frostbite Peaks, Thunderworks and Orbit
  Outpost from the mockups, matching them the way Gusty Gardens was matched.
- **Completed:** all six regions now wear a board built from concept art. Four new
  builders in `RegionSign`: `cinder`, `frostbite`, `thunderworks`, `orbit`.
  Heat — charcoal-basalt frame with ember cracks on its outer edges, copper corner
  brackets and rivets, red stone posts, tapered basalt footings, a stepped volcano
  crest with a lava vent, ember shards at the feet (244 parts, height 10.6).
  Frost — blue-grey stone uprights under snow-capped heads, a faceted frosted-ice
  frame, an undulating snow cap, a hexagonal snowflake medallion, corner icicles,
  ice gems set in the posts, four-tier snowed plinths (255 parts, height 9.4).
  Storm — weathered steel with chamfered armoured corners and orderly bolts, a
  hazard-striped outer cap rail split either side of the crest, a lightning badge in
  a round housing, ceramic insulators with routed cables, amber pilot lamps, concrete
  plinths (242 parts, height 9.9). Cosmic — four concentric chamfered silver rings
  with a violet trim line, lavender indicator strips in the side rails, star studs at
  the panel corners, a ringed-planet medallion, short graphite drum legs with glowing
  collars on rounded footings (174 parts, height 10.0). 915 new parts in total.
- **Structure:** `dress` and the new `RegionSign.height(element)` now read one
  `DESIGNS` table keyed by element, replacing the branch chain, so a board's panel,
  lettering, builder and ground plane cannot drift apart. MapBuilder reads
  `RegionSign.height` when placing `signCF` instead of its own Water special case.
- **Row hierarchy generalised:** the taller five-row layout Splashwater introduced now
  covers all five designed non-Wind boards via `BOARD_HIERARCHY` in MapBuilder, which
  is also what turns `Forecast.RichText` on. `RegionGates` now branches on that
  RichText flag rather than on `regionId == "splashwater_bay"`, so the server alone
  decides which boards get the 27/16 px surge footer and there is no second list of
  region ids to keep in step. Wind keeps its original even rows, as approved.
- **Files:** `src/server/Map/RegionSign.luau` (326 -> 1213 lines),
  `src/server/Map/MapBuilder.luau`, `src/client/Controllers/RegionGates.luau`,
  `docs/CONTRACTS.md`.
- **Validation:** 108 files pass the structure and quote scans; Rojo build succeeds at
  `build/RegionBoardsAll.rbxl`. Clearances were computed against the taller layout,
  whose widest row is Title at x +/- 8.28 and whose outermost rows reach y 4.55 and
  -4.60: every board's rails sit at y 4.7 / -4.7 and the narrowest side member is
  Cosmic's inner rail at |x| 8.9. Every solid piece has its inner face outside |x| 8.7,
  clear of the |x| 7.2 / |y| 4.0 window `testRegionSignVisibility` samples; all
  decoration is CanQuery false. No piece passes |x| 11.0.
- **Not verified in Studio.** No Studio connection this session. SelfTest, LiveTest,
  the 27-sightline suite per sign, the text fit and the four silhouettes have not been
  seen running. This is the next thing to do.
- **Uneven review depth — read this before trusting the four equally.** Each builder
  was written against the mockup and a written geometry contract, then handed to an
  adversarial reviewer that recomputed every bound. Frost and Storm completed that
  pass and both were corrected (Storm also lost a part, 241 -> 242 after repair).
  Heat and Cosmic were still in review when the run was stopped, so their numbers are
  the author's own arithmetic only. Give Cinder Canyon and Orbit Outpost the closer
  look in Studio.
- **Also changed by hand after assembly:** one wrapped `if/then/else` expression in
  `orbit` was reflowed into a local because the structure linter reads a line-initial
  `if` as a statement; and Thunderworks' part names were re-prefixed `Works*` from a
  generic `Sign*` that collided with the plain stand's and Gusty's names.
- **Limitations:** procedural recreations, not pixel-identical to the renders. Sign
  dressing across six regions is now roughly 1,600 static parts; mobile performance
  still unmeasured. Gusty's pinwheel remains static.
- **Studio:** not queried or changed this session; the previous task left it in Play.
  Stop Play before syncing, per the handoff protocol.
- **Publishing:** not published and not committed. Next: Studio validation of all six
  boards, then the deferred monster labels.

## Remaining region board concepts — 2026-09-20

- **Completed:** generated four board mockups after finishing Splashwater's sign:
  Cinder Canyon (basalt/embers/copper), Frostbite Peaks (ice/snow/stone),
  Thunderworks (steel/insulators/hazard stripes), Orbit Outpost (silver/violet/planet crest).
- **Files:** four named PNGs and REMAINING-PROMPTS.md in
  docs/art/region-boards/2026-09-20-mockups. Exact prompts and built-in image tool
  provenance are recorded; original generated files retained.
- **Validation:** visually inspected all four images: correct region/element names,
  readable OPEN and surge text, complete board silhouettes, no clipped lettering.
  No source changes or additional code tests for this artwork-only follow-up.
- **Limitations:** concepts only; four remaining boards are not implemented.
  Render textures/lighting are illustrative; eventual status/countdowns must remain live.
- **Studio:** unchanged from Splashwater checkpoint below (Play, Rojo port 34872).
- **Publishing:** not published or committed. Next: user reviews the four concepts
  and the implemented Splashwater board before choosing the next implementation.
  Monster labels remain deferred.

## Splashwater Bay board built from the mockup — 2026-09-20

- **User request:** implement only the Splashwater Bay concept board, matching
  the supplied image exactly. Existing Gusty implementation found in RegionSign
  and preserved. This pass changes only Water's design/layout and its surge styling.
- **Completed:** whitewashed timber uprights/header/sill on exposed driftwood posts
  and slate footings, navy cap and plank seams, iron bolts, deterministic weathered
  grain, ten rope turns formed from intertwined strands, open cream/red life ring
  with backing rope, and viewer-right scallop/starfish/spiral-shell cluster.
  Panel is dark navy, lettering pale aqua. Title/status hierarchy follows the
  mockup; live OPEN/unlock and countdowns remain functional. Water's board center
  is raised from 7.5 to 8.6 so timber legs show above the footings. X/Z unchanged.
- **Files:** RegionSign, MapBuilder, Controllers/RegionGates, docs/CONTRACTS.md.
  Splashwater's surge footer uses 27/16 px RichText; normal forecasts restore
  TextScaled. Other regions retain their existing appearance and text layout.
- **Validation:** 108 files pass structure/quote scans, Rojo build at
  build/SplashwaterBoardReview.rbxl, changed Source synced and compiled in Edit.
  Final boot: 3,914 map parts, 117 ms; **SelfTest 912/0, LiveTest 72/0**.
  All entrance sightline checks pass, structural frame/footing boxes do not
  intersect the Bay gate or scenery. Live text fits in all four rows. Verified
  surge rich text and reset to ordinary scaled forecast via client controller.
- **Visual QA:** compared isolated and in-map Edit views to the supplied concept;
  corrected shell corner orientation, rope/ring materials and exposed post height.
  Checked OPEN/SURGE and Unlock: 2.5K Coins/forecast states. Previews removed.
- **Limitations:** close procedural 3D recreation, not pixel-identical to generated
  artwork: native Roblox material grain and lighting differ from the render.
  Sign dressing has 694 static parts, mostly rope/ring geometry; mobile performance
  has not been measured. Existing impact_generic.mp3 warning remains unrelated.
- **Studio:** CatchACatastrophe.rbxl, PlaceId 0, left in Play, normal player camera;
  no character teleport, purchase or ownership changes. Rojo remains connected to
  C:\Users\nguye\Documents\repos\catch-a-catastrophe\CatchACatastrophe on 34872. Build stamp 2026-09-20 12:04.
- **Publishing:** not published or committed. Next: user's visual review of the
  Splashwater board, then Cinder Canyon; monster labels remain deferred.

## Gusty Gardens entrance board built from the concept — 2026-09-20

- **User decision:** implement the Gusty Gardens mockup only, matching it closely.
  Splashwater Bay stays concept-only for now.
- **Completed:** new `Map.RegionSign` owns every region board's dressing; MapBuilder
  keeps the board part and its live text rows. Gusty Gardens now wears honey timber
  posts capped and set on two-course stone footings, an arched crown stepped over 21
  segments (shoulder 5.7 to apex 7.7, max step 0.38), a carved wind swirl with a
  trailing gust either side of a cream pinwheel crest, and leaf-and-daisy clusters in
  both lower corners, over a deeper forest-green panel with cream lettering. The other
  five regions keep the plain metal trim, unchanged.
- **Deliberately untouched:** the 18 x 10 board face, its SurfaceGui, the four row
  rectangles and every colour the client drives. `RegionGates` already painted OPEN
  mint, the unlock price gold and SURGE gold — exactly what the concept shows — so no
  client file changed. Only the static Title and Element colours moved, to cream.
- **Files:** new `src/server/Map/RegionSign.luau`; `src/server/Map/MapBuilder.luau`
  (22 lines of inline stand construction replaced by one `RegionSign.dress` call);
  `docs/CONTRACTS.md`.
- **Validation:** 108 files pass the structure and quote scans; Rojo build succeeds at
  `build/GustyBoardReview.rbxl`. Frame clearances checked arithmetically against the
  text rows and against the face window `testRegionSignVisibility` samples: crown
  underside 4.7 vs the Element row's 4.5, bottom rail top -4.7 vs the Forecast row's
  -4.5, post inner faces 8.3 vs the rows' 8.1, and every queryable piece at |x| >= 7.75
  against the window's 7.2. All decoration is CanQuery false, so it cannot absorb a
  sightline ray at all.
- **Not yet verified in Studio.** No Studio connection was available this session, so
  the 27-sightline suite, the text fit and the board's actual silhouette have not been
  seen running. Run SelfTest and look at the Gusty approach before trusting it.
- **Known deviation:** the post caps and stone footings reach sign-local |x| 10.1 and
  10.35, past the 9.8 the frame proper honours, putting their near edge at gate-local
  13.65 instead of 14.2. They sit entirely above (y 6.6 to 7.4) and below (y -7.5 to
  -5.3) the board face, and Gusty's arbor is about 7.5 studs away in Z, so nothing is
  crowded — but a concentric cap that overhangs the post cannot also clear the text
  rows and stay inside 9.8, so this was chosen over a cap too narrow to read.
- **Limitations:** the pinwheel is static; the region's `SceneryMotion` spin is
  available and would suit it. Splashwater Bay's board is designed but not built.
- **Studio:** not queried or changed this session; the previous task left it in Play.
  Stop Play before syncing these files, per the handoff protocol.
- **Publishing:** not published and not committed. Next: look at the Gusty board in
  Studio, then decide between spinning the pinwheel, building the Splashwater board,
  and moving on to Cinder Canyon.

## Regional board concept mockups — 2026-09-20

- User approved the sign placement/readability fix and requested themed board
  mockups for Gusty Gardens and Splashwater Bay before more region work.
- Generated two concepts using built-in image_gen; saved PNGs and exact prompts
  under docs/art/region-boards/2026-09-20-mockups/. Gusty uses warm timber, a green
  panel, wind/pinwheel carving and daisies. Splashwater uses whitewashed wood,
  navy panel, rope, life ring and shells. Text is accurate and unobstructed.
- Concept art only: no game scripts, Studio objects or publishing state changed.
  Studio was left in Play by the previous sign-fix task; not queried this turn.
  Not committed or published. Next: user feedback on the concepts before building
  themed frames. Keep live status/forecast text separate from decorative assets.

## All six region entrance signs fixed — 2026-09-20

- **Problem:** region sign boards intersected the entrance posts/shoulders, and the
  Element label overlapped the title. User supplied a Splashwater Bay screenshot
  and requested the fix across every region before proceeding to Cinder Canyon.
- **Completed:** all six GateSigns are freestanding 18 x 10 boards at gate-ground
  offset (24, 7.5, -10), facing the hub, forward of the entrance scenery and beside
  the approach road. Added two rear supports, feet and edge trim. Element, region
  name, OPEN/unlock price and forecast occupy separate rows with padding. Active
  surge copy is two lines: SURGE! countdown / Perfect catches can be Overcharged.
  All existing region ownership, gate prompts and forecast updates remain wired.
- **Files:** MapBuilder, Controllers/RegionGates, TestHarness, docs/CONTRACTS.md.
  New regression checks cast 27 sightlines per sign from three approach positions
  and check board/scenery intersections, covering all six generated entrances.
- **Validation:** 107 files pass structure/quote scans; Rojo build succeeds at
  build/RegionSignsReview.rbxl; changed Source synced and compiled in Edit.
  Full boot: 3,165 map parts, 106 ms; **SelfTest 912/0, LiveTest 72/0**.
  All 162 approach sightlines pass and no sign intersects entrance scenery.
  Edit previews confirmed Splashwater OPEN + SURGE and Frost locked + SURGE;
  all six signs' text fits and rows are separated. Live client confirms OPEN,
  all five unlock prices and ticking forecasts still display without overlap.
- **Rendering lesson:** do not set ClipsDescendants on these SurfaceGui text rows;
  it made their text invisible in the Studio render despite TextFits being true.
  Explicit, separated row rectangles plus TextWrapped on Forecast work correctly.
- **Studio:** preview map removed; left in Play in CatchACatastrophe.rbxl, PlaceId 0,
  normal player camera. Rojo remains on 34872 for the active root repo. Build stamp
  2026-09-20 11:16. No character teleport or ownership changes used for probes.
- **Publishing:** not published or committed. Existing built-in sound warning remains.
  Next: user review of signs, then Cinder Canyon. Monster-label fixes and further
  Gusty Gardens polish remain deferred as requested.

## Splashwater Bay coastal refinement — 2026-09-20

- **User decisions:** Gusty Gardens looks good for now; further refinement can wait.
  User also wants monster labels fixed later; exact label changes are deferred.
  Proceeded to the next region, Splashwater Bay, using the same procedural approach.
- **Completed:** new SplashwaterBay builder provides a striped blue/cream lighthouse
  with balcony, framed windows, glass lantern room, steady warm lamp and swaying
  pennant; curved timber boardwalk with rope rails; beached rowing skiff with seats
  and oar; rock-ringed tide pools linked on one side by a shallow decorative lagoon;
  slate cliff cores/outcrops, sandy banks, beach grass, shells and starfish.
  A blue timber harbor entrance with life ring replaces the industrial gate frame.
  The 2.5K unlock prompt, gate, sign, entrance target and access rules are retained.
- **Files:** new src/server/Map/SplashwaterBay.luau; RegionScenery delegates Water
  to it and removes the old Water branch. Targeted edits to MapBuilder, TestHarness
  and docs/CONTRACTS.md. Wind/Water use SceneryVersion 3, other regions remain 2.
  Existing SceneryAnimator handles 61 additional non-colliding decorative parts;
  Gusty's accepted scenery and earlier uncommitted work are preserved.
- **Validation:** 107 files pass structure/quote scans, Rojo build at
  build/SplashwaterBayReview.rbxl, synced Source confirmed and changed modules
  compiled in Edit. Final boot: 3,117 map parts, 106 ms; **SelfTest 900/0,
  LiveTest 72/0**. Live radial rays at 5-degree intervals found no side gaps;
  a 2-stud grid found no queryable scenery inside the radius-44 capture field.
  Wild roaming endpoints stay in bounds; all 61 moving Bay parts are anchored,
  non-colliding and non-queryable. Beach-grass movement observed on the client.
  Unlock prompt still reads Splashwater Bay / 2.5K Coins; gate sign faces the hub.
- **Visual review:** Edit previews inspected from above, at player height and beside
  the shore. Added cliff-foot rocks and corrected the lagoon's footprint with a
  scaled built-in sphere mesh; primitive balls/cylinders clamp unequal axes here.
  All temporary previews removed before Play. No imported assets used.
- **Limitations:** pools/lagoon are decorative over solid ground, not swimmable
  Terrain water. User art review, touch and multiplayer/performance testing remain.
  The existing impact_generic.mp3 warning persists.
- **Studio:** CatchACatastrophe.rbxl, PlaceId 0, left in Play with normal player
  camera; no character teleport probes. Rojo remains connected on 34872 to
  C:\Users\nguye\Documents\repos\catch-a-catastrophe\CatchACatastrophe. Final stamp: 2026-09-20 11:00.
- **Publishing:** not published or committed. Next: user review of Splashwater Bay,
  then Cinder Canyon. Keep monster labels and further Gusty polish on the backlog.

## Gusty Gardens meadow refinement — 2026-09-20

- **Direction:** user reviewed the hub/region remodels and approved refining Gusty
  Gardens with procedural scenery first, with custom Blender assets considered after
  the layout and style review. Other regions retain their first-pass scenery.
- **Completed:** dedicated GustyGardens builder replaces the repeated planters and
  simple mill with a taller brick/timber windmill, framed windows, gabled teal roof,
  rotating canvas sails and stepping stones. Rounded hedge crowns and grassy banks,
  leaning trees, short cream timber fences, daisies/lilac flowers, meadow tufts and
  spinning pinwheels frame the open lawn. Timber arbor replaces the industrial gate
  frame; gate sign, tutorial entrance and access logic remain functional.
- **Animation:** new client SceneryAnimator drives 92 anchored, non-colliding,
  non-queryable decorative parts at 30 Hz, culled beyond 260 studs. Reduced Motion
  restores authored poses. Tags/attributes tolerate late replication. No external
  asset dependencies; no changes to creature models or balance.
- **Files:** new src/server/Map/GustyGardens.luau and
  src/client/Controllers/SceneryAnimator.luau; RegionScenery, MapBuilder,
  Main.client, TestHarness and docs/CONTRACTS.md updated. SceneryVersion is 3 for
  Gusty and 2 elsewhere; the existing version assertion now reflects that contract.
  All earlier uncommitted work preserved.
- **Validation:** 106 Luau files pass structure/quote scans; Rojo build succeeds at
  build/GustyGardensReview.rbxl. Changed modules compiled in Edit after confirming
  synced Source. Final Play boot: 2,743 map parts, 93 ms; **SelfTest 900/0,
  LiveTest 72/0**. Raycasts every 5 degrees found no side boundary gaps; a 4-stud
  grid found no queryable scenery within the radius-44 capture field, and all wild
  roaming endpoints remained in bounds. All 92 animated parts are anchored with
  collision/query disabled. Canvas moved 1.16 studs over 0.5 s normally, then 0 with
  Reduced Motion, exactly matching its authored pose; original setting restored.
- **Visual review:** inspected isolated Edit previews from above, at player height,
  and beside the mill; filled the roof gables and softened oversized grass tufts.
  All preview models removed before Play. User review of the final area is next.
- **Limitations:** procedural geometry remains deliberately simple; mobile and
  multiplayer performance not measured. Existing impact_generic.mp3 warning persists.
- **Studio:** CatchACatastrophe.rbxl, PlaceId 0, left in Play with normal player
  camera; no character teleport probes used. Rojo restarted hidden on port 34872;
  user connected and applied sync. Source is C:\Users\nguye\Documents\repos\catch-a-catastrophe\CatchACatastrophe,
  NOT the stale orca/workspaces checkout. Final build stamp: 2026-09-20 10:50.
- **Publishing:** not published or committed. Next: user feedback on Gusty's layout,
  foliage and mill; refine those or choose selective custom assets before moving
  on to Splashwater Bay.

## Atlas, region scenery and locked-area entry — 2026-09-20

- **Completed:** Atlas remodeled as a hub-facing research pavilion with brick archive
  wall, open bookshelves, six-element specimen desk, standing-seam canopy, warm light,
  planted entrance and open-book console. Real E interaction still opens Atlas.
- **Regions, first art pass:** continuous themed boundaries and entry piers replace
  short disconnected fences. Peripheral landmarks: Gusty Gardens windmill/flower beds;
  Splashwater Bay lighthouse/tide pools; Cinder Canyon basalt volcano/lava channels;
  Frostbite Peaks glacier arch/crystals; Thunderworks Tesla masts/transformers;
  Orbit Outpost observatory/sample plinths. Gate signs now face the hub.
  These are built-in materials and procedural parts, not imported mesh/texture assets.
- **Side-entry fix:** new RegionAccessService checks server-side XZ volumes at 5 Hz.
  Locked entrants from any direction/height return to the gate approach with velocity
  cleared and a throttled unlock notice. Ownership is read live, including after
  relaunch. Quest entry polling also requires ownership. Creature spawn and roaming
  targets stay within radius 44, clear of the new peripheral props.
- **Files:** HubLandmarks, new Map/RegionScenery and Systems/RegionAccessService,
  MapBuilder, Main.server, EncounterService, QuestService, TestHarness, CONTRACTS.
  Prior unrelated uncommitted work remains; the old regionProps implementation was
  replaced by RegionScenery. Frost's subdued blue palette remains in the new art.
- **Validation:** 104 files pass structure/quote scans; Rojo build succeeds at
  build/AtlasRegionsReview.rbxl. Rojo-synced sources compiled in Studio before Play.
  Boot: 2,265 map parts, 88 ms; **SelfTest 900/0, LiveTest 72/0**.
  New checks cover sides, height, unlocked access, relaunch revocation, return position,
  unloaded/dead profiles and roaming bounds. Actual player side-entry into locked
  Splashwater Bay returned to 92 studs from its center, outside the gate; starter
  region entry remains allowed. Live boundary rays every 5 degrees found no side gaps
  in any region; all wild PathFrom/PathTo endpoints stayed inside the open field.
  Atlas and six region previews visually inspected in Edit and removed. Atlas books
  verified visible by raycast after replacing the solid cabinet with open shelving.
- **Limitations:** this is a first region art pass; landmarks use simple procedural
  geometry and need user review at player scale before more detailed area-by-area
  polish. Existing impact_generic.mp3 warning remains unrelated. No multiplayer
  client session was run. Prior Play screenshot limitation remains; Edit previews work.
- **Studio:** CatchACatastrophe, PlaceId 0, in-memory test adapter; left in Play at the
  Atlas entrance with its panel closed and normal player camera. Rojo serves this repo
  on port 34872. **Source is C:\Users\nguye\Documents\repos\catch-a-catastrophe\CatchACatastrophe**, not the older
  orca/workspaces checkout named in the thread environment.
- **Publishing:** not published or committed. Next: user review of Atlas and region
  silhouettes, then refine individual regions at player scale, starting with Gusty.

## Hub Workshop and Relaunch art pass — 2026-09-20

- **Source location correction:** the active game matches `C:\Users\nguye\Documents\repos\catch-a-catastrophe\CatchACatastrophe`,
  not the older `orca\workspaces\Catch-a-Catastrophe\Catch-A-Catastrophe` checkout.
  Earlier summaries from that checkout understated progress (7-step versus 13-step tutorial).
- **Completed:** Workshop and City Relaunch now face the plaza center via a shared local -Z
  convention. Their signs, terminals, entrances and road endpoints align. Workshop is an
  open industrial garage with brick/concrete walls, standing-seam roof, canopy, windows,
  louvres, workbench, cabinets, tool board, gear emblem, roof vent and warm task lights.
  Relaunch is a twin-gantry energy tower with containment rings, cyan power accents and
  a readable front sign. Built-in materials supply the surface detail; no uploaded assets.
- **Files:** new `src/server/Map/HubLandmarks.luau`; targeted edits to `MapBuilder.luau`
  and `docs/CONTRACTS.md`. Existing uncommitted Frostbite and other feature edits preserved.
- **Validation:** 102 Luau files pass structure/quote scans; Rojo build succeeds at
  `build/HubLandmarksReview.rbxl`; new module compiles in Studio. Both models visually
  inspected in an isolated Edit preview, then preview removed. Both terminal and sign
  forward vectors align with the hub center (dot product 1); approach rays reach console
  screens unobstructed. Main game synced through Rojo with `.Source` confirmed.
  Full boot: 1,935 map parts, 82 ms; **SelfTest 803/0; LiveTest 72/0**.
  Real E-key interactions open both Workshop and Relaunch panels in Play.
- **Limitation:** Output includes a failed built-in `impact_generic.mp3` sound load,
  unrelated to this map change. Play-mode screenshot captures rendered UI over a blank
  background during this check; Edit-mode model screenshots worked. Final user review of
  the complete hub in Play is still needed, especially material brightness and sign scale.
- **Studio:** `CatchACatastrophe.rbxl`, local PlaceId 0; left in Play, camera restored to
  player control, player at the hub. Rojo serves this repository on port 34872.
- **Publishing:** not published or committed. `Shared/Build.luau` refreshed with stamp.py.
- **Next:** user review of Workshop/Relaunch, then continue map polish from this active repo.

## Collection pad and tutorial indicators — CLOSED 2026-09-07 evening

A checkpoint written earlier today opened this file with "ACTIVE INTERRUPTED
WORK ... PARTIAL and UNVERIFIED" for the automatic collection pad and the
tutorial direction indicators. Both were finished later the same day and
validated by the user in Studio, so that block was stale and has been replaced
with what is actually true. Nothing was lost; the work it described is done.

- **Automatic collection: done and validated.** `CollectionPadService` owns
  occupancy and payout, `EconomyService.collect` takes the `quiet` flag, the
  service is wired in `Main.server`, `CollectionPadUI` draws the billboard and
  progress, and `testCollectionPad` covers the timer rule. Stepping on the pad
  pays the whole bank at once (`collectHoldSeconds` is 0), toasts
  "N Coins collected!", and **pays once per visit**: the latch clears only when
  the player leaves the pad footprint, and the billboard says
  "Collected. Step off and back on to collect again" meanwhile.
- **Tutorial indicators: done and validated.** The guide is no longer one thin
  straight beam. It follows the road graph (up to 20 segments, Dijkstra over
  every `Path` part with the hub plaza fully connected), is more than twice as
  wide (1.4), and draws as evenly spaced dots on every segment: `TextureMode`
  is `Wrap` with a 3-stud repeat, because Stretch spread a fixed number of
  sparkles per beam and so read as a line on long legs and dots on short ones.
  Short hops and real detours fall back to a straight line.
- **Still true from that note:** nothing is published, and Studio state should
  always be queried rather than assumed.


- **Updated:** 2026-09-07 morning (Claude Code). Codex reached its weekly limit; Claude owns
  this repo until told otherwise, and took over Codex's unfinished collection pad indicator.
- **Repo:** `C:\Users\nguye\Documents\repos\catch-a-catastrophe\CatchACatastrophe` — Rojo 7.7, branch `main`
- **Working tree: CLEAN** apart from this file when it is being written. Everything is committed.
- **Studio:** "Catch a Catastrophe (placeId 88888194204730)". Instance ids change on every
  relaunch; call `list_roblox_studios`. Left in **Play** for the user to look at the route lights.
- **Rojo:** `rojo serve default.project.json --port 34872` must be started by hand after a Studio
  relaunch, and the Rojo plugin's **Connect** button pressed in Studio. Neither survives a restart.
  A Weppy sync plugin also attaches to this place on launch and writes `weppy-project-sync/`
  into the repo root; it is gitignored and not used. Rojo is the source of truth.
- **Not published.** PlaceVersion was 28 this morning (4 the night before), so the user has been
  saving to the cloud and may have published. The user publishes; agents do not.

> `/pickup` still points at Munch It! relay files. Ignore them for this project.

---

## Landed 2026-09-07, newest first

| Commit | What |
|---|---|
| `2aca2d4` | **Sign names desaturation guard** (`Waypoints.signColor`): every floating name is the destination colour at >= 0.55 saturation, <= 0.92 value; Frostbite Peaks read as white glare. Region colours elsewhere untouched. **Concurrent session warning (2026-09-08 00:05):** another agent was editing `CaptureController` (range ring dimmed to Neon 0.86, muted colours), `MapBuilder` (Frostbite snow/ice/ambience darker) and `Config/Regions` (Frostbite groundColor) uncommitted while this landed; this session layered a SmoothPlastic 0.78 ring on top in the working tree but did **not** commit it. Whoever commits `CaptureController` next: the two ring edits are both in the file, reconcile on purpose. |
| `92198ee` | **Auras** (cosmetics family 1): 9 auras, 6 earned one per region, 3 prestige that cannot be bought. Store gains a **Style** tab, now the first tab. Worn aura published as the Player attribute `Aura`; client renderer dims it during captures, obeys reduced motion/flashing, culls by distance. SelfTest 643, LiveTest 49. |
| `9b1fcc1` | **Store panel** (Passes / Coins / Boosts / Eggs), sidebar button, HUD boost chip, Robux button on the Remote Collector row. Everything reads "Coming soon" until the dashboard ids exist. |
| `4e422ba` | **Store remotes**: `PromptPurchase`, `HatchEgg`, `TestGrant` (Studio only) + `HatchResult`, rate-limit buckets, `Snapshot.store`. `Remotes.serverToClient` is now the one list of remote direction. |
| `9562354` | Monetisation **Phase A** (see the block below). Store catalogue, PurchaseService, save schema, three chase tiers, egg roster, boosts wired, 127 new self-tests + 13 live checks. SelfTest 578, LiveTest 46. |
| `44c3986` | **Zone labels scale harder**: user's feel test said every sign past 200 studs was one size and legible from the far edge. `Waypoints` now clamps depth 30..420 and raises the depth ratio to 1.25 (`REF` 60, `EXAGGERATE`); gold Unlock line hides under a 14 px title. Live: 11 px at 259 studs (was 21), 90 px at 49. Open question to the user: keep the 28-stud vanish, fade it, or drop it. |
| `d6e5b11` | **Zone labels as outlined names that scale with distance** (`Controllers/Waypoints`): the 11 signs (6 gates, 4 hub, Your City) are the name alone in the destination's colour, FredokaOne, ink `UIStroke`, no card. Sized every frame from camera depth as a 44x7.6-stud sign would be, depth clamped 35..200 studs; locked gates keep a gold "Unlock X Coins" line; distance readout and element word removed. Live: title 36.2 px at depth 116 vs 36.8 modelled, 121 px at depth 7 (near clamp). User approved the plan; awaiting his feel check. |
| `bd9ab36` | **Rarity shrinks the capture circle and grows the shove** (`rarityRangeMult` 1/.9/.8/.7, `rarityKnockbackMult` 1/1.1/1.2/1.35); circle stored on the capture and sent in CaptureState; ring on screen matches. Gusty Gardens pass; tune region by region next. **Unvalidated by the user.** |
| `459e933` | **Difficulty by zone and rarity**: `Config.Capture.zoneTuning` (warning 100%..60%, +0..+2 patches, penalty 1..2.25 s, knockback 32..40) x rarity (+15% size, -10% warning per rank). Stored on the capture at start; boss arena untouched. SelfTest 467. **Unvalidated by the user.** |
| `01d28de` | **Atlas** 880x600, cards 200x224: tabs and descriptions no longer truncate. |
| `53a8e71` | CAUGHT card: **Store** instead of Nice, with a tooltip. |
| `40e20b9` | **Variant tooltips**: `Variants.describe`; Creatures panel badge, pad picker badge and CAUGHT card explain Overcharged / Prismatic on hover. |
| `c174b63` | **Forecast row wraps** (was a 300 px strip: only 3 of 6 regions showed); chips have hover text explaining SURGE and the Legendary countdown. |
| `675f4d2` | Wheel fallback on `W.scroll`/`W.scrollGrid` (acts only when nothing consumed the wheel). User report: Workshop list scrolls by bar, not wheel; not reproduced with injected wheel (300 px native). Awaiting re-test. |
| `2313f29` | Creatures panel: stored creatures read "N/s when deployed" (`potentialCps`); they showed 0/s. |
| `fabcba0` | **Remote Collector** upgrade (20,000 Coins, 60 s cooldown): `CollectBank` now runs `Economy.collectRemote` (gated + cooldown; the open remote is closed); HUD Collect button for owners with countdown. SelfTest 457. |
| `dc00d2c` | **Live build stamp**: `tools/stamp.py` writes gitignored `Shared/Build.luau` (hash, dirty, times); HUD pill, Settings footer and boot log show it; post-commit hook refreshes it. Run `python tools/stamp.py` before every sync. LiveTest 33. |
| `d847050` | CircuitEditor pad picker adds the GUI inset before its ray (same 58 px mismatch). |
| `ce8858e` | **Click picker in viewport space** (`GetMouseLocation`): clicks were 58 px (topbar inset) above the projection; hidden up close, fatal at the 60-stud zoom cap. Measured with an injected click. |
| `489ac60` | **Click target floor 24 px, click ray 1000 studs** (CaptureController). |
| `dcf1f81` | **Zoom cap 60** via `Config.CameraMaxZoomDistance`, applied at join and on every character spawn (a join-only set read back 400; StarterPlayer properties do not sync through Rojo here). LiveTest 32. |
| `1340b56` | **Target box removed** (SelectionBox on the aimed creature); the floating name label is the marker. |
| `c7f582b` | **CAUGHT card**: PERFECT is a 92x22 gold pill in the name row (y 214), name label 100 px narrower; the old ribbon straddled the picture edge. |
| `e9489ec` | **Layout B chosen**: `Config.MapLayout` = B, six cities between straight region roads, `MaxPlayers` 6, arena moved to polar(262, 300) with a spur off the Frostbite road, scenery under it cleared at build. A kept behind the switch. **Place setting Players.MaxPlayers still 60: set to 6 in Game Settings.** |
| `8a5543f` | **Region roads dog-leg (option A)**: 30/150/210/330 through the 45-degree gaps, Frostbite (270) via the 315 gap around the arena, connectors at r=186 in 15-degree chords. Live checks: no road crosses a city platform/apron or the arena disc. 36 roads, LiveTest 31. |
| `9d5b301` | Studio-only click diagnostics removed (user confirmed the click works). |
| `bbd662e` | **Tutorial guide follows the roads**: chain of beams over the road graph (Path parts + plaza links), straight for short hops/detours. |
| `9f70cfb` | **CameraGuard**: a camera left Scriptable/detached is handed back to the Humanoid within 1 s. Probes: set Camera attribute `ScriptedCamera=true` while framing, clear after. |
| `5e54b2b` | **Knockback 16 -> 28** ("the wall barely moves me"). Self-test pins <= 30. |
| `418a649` | **Pad toast** "N Coins collected!" and **one payout per visit** (was every 0.2 s while standing). |
| `d3d8217` | **StudioTester**: every Studio profile gets a Prismatic Big Whoops (5,120 Coins/s) after the live suite (`LiveTestDone` attribute). Studio bank numbers are inflated by it on purpose. |
| `992aeb8` | **Camera never cached** in CaptureController / CircuitEditor; **Studio-only click diagnostics** on PlayerGui (`ClickDiagCount/Last/Nearest`). Click-to-capture PROVEN with an injected click: picker found the creature, claim accepted, card shown. |
| `1449a52` | **HUD Collect button removed** (it collected from anywhere); readout pops when the bank fills. "Remote Collector" Workshop upgrade approved for later. |
| `c7ed59f` | **Roads stop at destinations**: plot driveways end at the apron (were 30 studs inside the lot, over the pads), kiosk spokes stop at base discs, region route = hub-gate + 30-stud stub, arena floor road removed. Neon edge lines, bigger chevrons. LiveTest 29. |
| `deb77ee` | **Unlocked gate pane dissolves** (0.8 s) and stays invisible. User confirmed live. |
| `eb5b5d9` | **Collection pad pays the moment you step on** (`Config.Economy.collectHoldSeconds = 0`, shared by server and indicator). Codex's 1 s hold read as broken. |
| `b74234b` | **Route markings sunk into the slab**: 388 of 388 were 0.005-0.015 studs above the asphalt and shimmered; now 0. Left: 15 junction slab overlaps and the plot Platform/Apron seam. |
| `281b0a5` | **Creatures no longer teleport** (legs continue from the last leg's end), Gust/Ice Wave walls are 3 studs and jumpable, hitPenalty 2 -> 1, knockback 38 -> 16. A standing-still probe caught a Common in 10.7 s; it never finished before. SelfTest 451. |
| `f5c1bb9` | Neon route chevrons with a marching light toward the destination (`Controllers/RouteLights`); always-on-top waypoint signs over gates, hub destinations and your own city (`Controllers/Waypoints`). LiveTest 22 → 27. |
| `7e78ecf` | Codex's on-pad collection indicator, finished and verified: bank, status, progress bar, driven by the server's Collection* player attributes. Tutorial step 4 text updated. |
| `44880b1` | Pointing at a creature is judged **on screen** (projected body radius), not by raycast. See trap below. |
| `0d88ea2` | Capture hint per device ("Press E or click" / "Tap Capture" / "Press X"); left-click on a creature starts the tether. |
| `5af5dbb` | **Creatures were frozen statues on every client.** Root cause and fix below. Almost certainly the whole "catching is buggy" report. |
| `37b71f4` `4c2b34d` | Codex's overnight work as checkpoints: server-side stand-to-collect cycle; text sidebar, wider dark roads, tutorial shake fix. |
| `3541904` `eb71109` | gitignore: Weppy runtime folder, review screenshots in `build/`. |

Earlier (09-06): gate unlock at the gate + nudge loop, walk speed x1.5, pad picker, 44px toast close.

---

## Verified live today

| Check | Result |
|---|---|
| Creature beside player, camera near, nothing initialised by probe | moved **8.24** studs in 2 s (roam is 4/s); was **0.00** before `5af5dbb` |
| Client-vs-server creature position gap | **< 0.1** studs; was 8–17 |
| Screen-space pick at 20 studs | body is a 106 px target; belly click inside, 1.5 bodies away outside |
| Route chevrons | 338 of 338 Neon across 25 routes; lit block advanced toward higher Index over 0.45 s |
| Waypoint signs | 11 (6 gates, 4 hub, 1 city); title height within 1 px of `5 studs * (k / 60) * (60 / clamp(depth, 30, 420)) ^ 1.25` on every on-screen sign (82.2 vs 82.3 at 53, 31.6 vs 31.6 at 115, 11.2 vs 11.4 at 259); gold line hidden at 13 px (Frostbite, locked); only locked gates show the gold "Unlock X Coins" line |
| Collection indicator | "Stand here" → "Stay on the pad / Collecting…" → "Collected +12 Coins", bank 8.77 → 0, cycle repeated (+8) |
| Roaming legs | 2 boundaries in 11 s, both continuous; max single-tick move 1.08 studs (was 13-19) |
| Beginner capture | stand 4 studs away, never dodge: Common **caught in 10.7 s** (never finished before) |
| Road markings | 0 of 388 in z-fight range of a road top (was 388); tops proud 0.077 |
| Collection pad | step on with 8.83 banked: paid +12 after 0.5 s, then +4 as it refilled |
| Suites | SelfTest **451** / 0 · LiveTest **27** / 0 |
| Client errors | none from game code (one stock `rbxasset://` sound, pre-existing) |

**Click-to-capture is verified** with real injected mouse input and **confirmed by the user**
("The click works now"; their earlier miss was 216 studs from the nearest creature). Diagnostics
removed. New report 2026-09-07 evening: clicks stop working once the camera is zoomed out past a
point. The 34-stud range is measured from the character, not the camera, so the suspects are the
300-stud raycast limit and the pixel radius shrinking with depth (default max zoom is 400 studs).
Fix direction: cap `CameraMaxZoomDistance` (the user asked for a zoom cap) and floor the click
radius at ~24 px.

**Probe lessons from that hunt:** the assistant's probes do NOT receive UserInputService input
(plugin context), so a probe-side InputBegan recorder sees nothing; only game scripts or
`user_mouse_input` count. And aim at where the creature IS at click time: they roam 4 studs/s, and
the seconds between framing and clicking made every early injected click a clean miss.

---

## Root causes found today (do not re-diagnose)

**Frozen creatures.** A model replicated from the server reaches the client BEFORE its parts:
at the instant `CollectionService`'s added-signal fires for it, it has no PrimaryPart, no Root
and zero children (reproduced with a server-spawned tagged model; parts landed 0.5 s later).
`Animate.track` found no root and returned silently; `WorldAnimator.track` had already marked
the model tracked and never retried. Fix: `Animate.track` returns a boolean, `WorldAnimator`
retries one frame after each `ChildAdded` / `PrimaryPart` change until it registers. Self-test
suite `animate` covers it.

**Clicks passed through creatures.** Every client-built body part is `CanQuery = false` by
`ModelKit` convention (so the camera does not pop against creatures and they never block pad
clicks); only the invisible 1-stud Root at the pivot can be hit by a ray. Do not flip CanQuery.
`CaptureController.wildAtScreenPoint` projects nearby wild models and tests the point against
the body's projected radius (height/2 + 0.75 studs), Root raycast still winning when it lands.

**"Tap Capture" on a keyboard.** The hint was touch wording shown to every device; the touch
button it named is hidden when a keyboard exists; there was no mouse binding for capture at all
(only the Containment Tether tool's Activated, and the tool is never equipped).

---

## Monetisation Phase A (2026-09-07, built; ids still 0)

Server and data only. **No client Store panel yet** and **no remotes yet**: those are Phase B/C, and nothing is buyable until the place is published and real ids are pasted into `Config/Store.luau`.

- **Catalogue** `src/shared/Config/Store.luau`: 4 passes (79/99/149/299), 4 coin bundles at the region unlock costs, Double Income 30 min / 2 h, Quick Tether 30 min, Cosmic Egg x1/10/50/100 (49/399/1499/2499). Every `assetId = 0`; the asset-id indexes only contain live entries, so a 0 can never resolve a receipt.
- **Chase tiers** Mythic / Celestial / Astral (ranks 5-7, `weight = 0`, income mult 50/150/400) plus six egg-only species in `Species.eggList` that reuse existing builders. `Species.list` stays 24, so the Atlas denominator, the spawner and Relaunch are untouched.
- **Pity**: three independent counters per egg (Mythic 50, Celestial 200, Astral 500). A hatch of tier T zeroes every counter at or below T.
- **Save schema**: `data.purchases` (ledger, passes, cosmetics, counters), `data.boosts`, `data.eggs`. Sanitize drops unknown ids and expired/oversized boosts; serialize deep-copies. Runtime profiles gain `passes` and `eggAllowed`.
- **The rule the service is built on**: never pay and get nothing. Every uncertain path returns NotProcessedYet; every granted PurchaseId goes in the ledger and a repeat is acknowledged without granting again (the duplicate check sits in `settle`, next to the ledger). Order is apply -> record -> save -> acknowledge, with rollback if the save fails.
- **Boosts** extend rather than stack, capped at 4 banked hours. Income boosts lift payout but never `totalNormal`, so the bank cap and offline award cannot inflate. Quick Tether is capped WITH the upgrade at `Store.tetherSpeedCap` 2.0 and leaves telegraphs alone.
- **Studio testing**: `S.Purchase.testGrant(profile, id)` grants with no Robux and no asset id (Studio + test adapter only). The live suite uses it on the real profile and forces a pity Astral.

**Phases B and C are built** (`4e422ba`, `9b1fcc1`): remotes, rate limits, `Snapshot.store`, the Store panel with the odds and pity disclosure and a ten-cell hatch reveal, the sidebar button, the HUD boost chip and the Workshop Robux row. SelfTest 581, LiveTest 46.

**What is left is the owner's:** publish the place, enable API Services, set Max Players to 6, create 4 passes and 11 developer products on the Creator Dashboard, and paste the ids into `Config/Store.luau`. Every row says "Coming soon" until then, and no receipt can resolve to a zero id by construction.

**Testing without ids:** `game.ReplicatedStorage.Remotes.TestGrant:FireServer("<product id>")` from a Studio server context grants any product with no Robux (test-adapter profiles only), e.g. `egg_cosmic_100`, `boost_income_30m`, `coins_m`.

## Cosmetics (2026-09-07, built)

- `Config/Cosmetics.luau` is the catalogue for every family (auras now; decorations and plot skins reuse the shape). Each item carries a `source` and an `unlock` rule, and `Cosmetics.requirement(item, regionName)` turns that into the words on a locked row.
- **Ownership is stored, never recomputed**: `data.cosmetics.owned`. A relaunch resets `data.regions`, so recomputing would take earned auras away. `CosmeticsService.refresh` only adds.
- **The worn item is a Player attribute (`Aura`)**, not a remote: it replicates to every client for free, including late joiners. `AuraController` watches it on all players.
- Free-vs-paid balance is deliberate: 6 region auras + 3 prestige are free, and prestige is asserted unbuyable by a self-test. Event auras are the paid ones, and are not built yet.

## Traps for probes (execute_luau)

- **A probe's `require` returns its own copy of a module**, with its own empty state: `Profiles.all()` in a probe is always empty even with a player in game. Test live server state from inside the server (the `runLive` suite) rather than from a probe.

- **Never move the user's character.** A probe that stood him on the collection pad for a second (to fund a test) was reported as "randomly got teleported back to my city" mid-capture. Fund tests through remotes (UnlockRegion, BuyUpgrade) only when the wallet already allows it, or ask him.
- **Which build is running?** Read the HUD pill (`BuildPill`) or the boot line `[Catch a Catastrophe!] Build <hash>`; a `*` means uncommitted changes were stamped in. Run `python tools/stamp.py` after editing and before syncing, or the pill lies.
- **Coordinate spaces.** `InputObject.Position` and `user_mouse_input` are screen space (GUI inset removed). `UserInputService:GetMouseLocation()`, `WorldToViewportPoint` and `ViewportPointToRay` are viewport space. They differ by `GuiService:GetGuiInset()` = 58 px with the current topbar. Never compare across the two without converting.
- **CameraGuard** resets a Scriptable or re-subjected camera within a second. Before a positioned `screen_capture` or a scripted frame, `workspace.CurrentCamera:SetAttribute("ScriptedCamera", true)`; clear it after. And do not do it in the user's session at all between sets.
- **StudioTester** gives every Studio profile 5,120 Coins/s a few seconds after the live suite. Bank and wallet numbers in Studio include it; a teleport onto the collection pad pays hundreds of thousands.
- A probe that teleports the character mid-capture makes the game toast "You left the creature behind." It happened to the user once today. Ask, or wait for a fresh session.
- **`BillboardGui.DistanceLowerLimit` / `DistanceUpperLimit` / `DistanceStep` do nothing here.** Measured 2026-09-07: an invisible probe billboard straight ahead of the camera at 20..500 studs gave identical `AbsoluteSize` with limits 35/200 and with none, for Scale sizing, Offset sizing, `AlwaysOnTop` on and off. A stud-sized billboard measures exactly `studs * k / depth` with `k = (ViewportSize.Y / 2) / tan(FieldOfView / 2)`; clamp that yourself (`Waypoints.resize`).
- **Bash heredocs with apostrophes fail** in this harness ("unexpected EOF while looking for matching"). Write Python scripts to the scratchpad with the Write tool and run them.

- **Own module cache, both datamodels, and stale across probes in Edit.** A `require` in a
  probe returns the module as first cached by an earlier probe. After editing a module, an
  Edit-mode `require` still returns the OLD one. Verify through the instance tree, remotes
  (`Net.invoke("GetState")` from a client probe), or a fresh Play session. Cloning the
  ModuleScript before requiring also works for pure modules.
- **The Studio assistant parks the camera.** Probes have found `CameraType = Scriptable` with the
  camera 200+ studs from the character. `WorldAnimator` culls by camera distance (220), so
  creatures look frozen in that state for a reason that is not a game bug. Pin
  `CameraType = Custom`, `CameraSubject = humanoid` before measuring anything visual.
- **A probe-side `WorldAnimator.init()` keeps running** after the probe ends and will animate
  models, contaminating the next measurement. Restart Play for a clean read.
- **Capturing a creature from a probe:** teleport to the server's path-interpolated position
  (`PathFrom:Lerp(PathTo, (GetServerTimeNow()-PathStart)/PathDuration)`), never the model pivot;
  `Net.fire("StartCapture", uid)` ~0.6 s later; orbit at 8 studs, 15°/tick, so the gust's aim line
  is stale when it arrives; keep each probe under ~13 s; the claim survives gaps; a vanished model
  means captured OR expired, confirm with `GetState`. A Common lands in one ~10 s window.
- **`VirtualInputManager` is unavailable** to probes (no RobloxScript capability). Mouse clicks
  and key presses cannot be faked; a human has to do them.
- **The structural linter** (`tools/luau_lint.py`) flags multi-line `if … then … else` expressions
  passed as call arguments as unclosed blocks. Hoist them into locals.
- **Do not `require` `Notifications` from a probe:** it rebuilds its stack inside the live gui.

---

## Still open

| # | Playtest item | State |
|---|---|---|
| 1 | Travel via plane/portals | Parked by the user |
| 2 | UI declutter / routes faint | Routes: **done** (lights, signs, Neon edges, roads end at destinations). Sidebar: Codex rebuilt it. Progression-gated panels: not started |
| 3 | Movement speed | Done (`4e50529`) |
| 4 | Change creatures at the pad | Done (`2c152fe`) |
| 5 | Plot rework so creatures stand out | Parked ("maybe") |
| 6 | "Catching is buggy af" | Frozen creatures (`5af5dbb`), teleporting legs, unjumpable wall, 2 s penalty, knockback 38 -> 16 -> **28**: all fixed today. User: capture finishes faster; the wall must feel like a shove (28 unvalidated) |
| 7 | Can't open a new area | Done (`d8634e7`) |
| 8 | Notification loop | Done (`d8634e7`) |

### Capture balance (applied, `281b0a5`; zone tuning `459e933`; rarity circle/shove `bd9ab36`)

Base times 8/10/13/16 s unchanged. Zone 1 Common: `hitPenalty` 1, `knockback` 32, circle 18, `wallHeight` 3. Zones per `Config.Capture.zoneTuning` (warning to 60%, up to +2 patches, penalty to 2.25 s, knockback to 40); rarity adds 15% hazard size, cuts 10% warning, shrinks the circle to 70% and multiplies knockback to 1.35 at Legendary. Region-by-region pass in progress: Gusty Gardens done, the user validates before the next region.
`capture balance` self-test suite pins the rules (penalty below every attack interval, knockback
below tether range, wall lower than a jump, legs continuous). Legendary still needs ~14% dodging
within the 45 s claim. **Next lever if it still feels off:** per-rarity `attackInterval`, not base
seconds. Re-test with the friends first.

### Other

- **Live build stamp** — deferred by the user; small; now unblocked.
- **Relaunch curve** — `100,000 × 3^R` vs additive `1 + 0.25R`; Crisis reward cap 150K. User's call.
- **Z-fighting left over:** 15 road-slab overlaps at junctions (both tops at 0.525) and each plot's
  Platform/Apron one-stud seam. Small patches; alternate slab heights or trim at the junction.
- **Mobile pass** — nothing today was checked on touch.

## Approved but not built

- **Portals** (fast travel between hub, gates and your city, gated to unlocked regions). User: future idea.
- Widen the animator's 220-stud camera cull if far creatures snapping into place still reads as teleporting.

## Next set from the user (2026-09-07 evening)

All eight items built. Then: live build stamp (done), Remote Collector (done). **Next: difficulty tuning per zone and per rarity** (user: Cinder Canyon is easier than Gusty Gardens; a Legendary there feels like a Common). Hazards do not scale by zone; rarity scales only attackInterval/hazardSpeed/captureSeconds. Bring numbers for approval first.

1. Zoomed-out clicks: **done** (`489ac60` click floor, `dcf1f81` zoom cap, `ce8858e` coordinate fix: the real cause), awaiting validation.
2. Region roads: **done, layout B chosen** (`e9489ec`) after comparing with A (`8a5543f`). Six cities per server now. Open: set the place Players.MaxPlayers to 6; hub rim lamps follow the six cities; CitiesPanel Visit list follows MaxPlayers.
3. Pad toast: **done** (`418a649`), awaiting validation.
4. More knockback in Gusty Gardens: **done at 28** (`5e54b2b`), awaiting validation.
5. Zoom cap: **done at 60** (`dcf1f81`), awaiting validation.
6. HUD Collectible vs billboard Bank 0: **traced live, they match to the coin every second**. Cause was the old pad draining the bank 5x/s while standing on it; fixed by one payout per visit. No code change; user to validate.
7. CAUGHT card: **done** (`c7f582b`), awaiting validation.
8. Target box: **done, removed** (`1340b56`), awaiting validation.

Then: live build stamp; progression-gated sidebar.

## House rules

Stop Play before editing; Rojo syncs into Edit only. Confirm by reading `.Source`, then Play.
Verify by running. Read `docs/CONTRACTS.md` before changing an interface. Commit other agents'
work as its own checkpoint, attributed, before building on it.

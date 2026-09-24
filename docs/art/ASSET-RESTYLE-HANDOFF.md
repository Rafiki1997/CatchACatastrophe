# Catch a Catastrophe — Blender asset style and recreation handoff

Prepared 2026-09-22. This is a reusable art direction and implementation guide for another Codex session, Claude, or a human artist. It does not require the original conversation.

## 1. The assignment

Recreate the game's existing assets in Blender with the same visual quality and design language as Rahul's approved **Powder Fir A / Original, B / Broad, and C / Upright** trees. The long-term scope is all existing game assets. Work through an inventory in reviewed batches; this document is not a claim that the restyle has already happened.

**Style summary:** a polished, stylized 3D miniature world, with substantial rounded forms, carefully shaped silhouettes, layered sculpted detail, restrained surface texture, and readable material contrast. Objects should feel deliberately modeled and tactile. Keep the friendly game proportions and readability while adding depth, craftsmanship, and believable material behavior.

Match the trees' modeling quality and treatment of forms across the game. Snow, evergreen foliage, and winter colors belong to Frostbite; they are not mandatory features of every asset. Preserve the identity of each region and the function of each object.

Rahul selected the Powder Fir concept, requested sibling variations, approved the actual three Blender models, and authorized their placement throughout Frostbite. That establishes the art benchmark. New asset designs still need review against it. Do not interpret a good render as approval of an entire region's replacement kit.

## 2. Workspace and pickup

- Work in **`C:\Users\rahul\orca\Catch-a-Catastrophe`**. This is the source checkout. The older `orca\workspaces\Catch-a-Catastrophe\Catch-A-Catastrophe` checkout is not the implementation target.
- Read root `AGENTS.md`, the newest `RELAY.md` checkpoint, and relevant `docs/CONTRACTS.md` sections before implementation. Other sessions may have advanced the project since this document.
- At authoring, branch was `main`, HEAD `da98f6b4272ce34a46443d6df0905e60aa2fda8c`, with substantial uncommitted art and map work. These identify the starting state, not a requirement to reset to that commit. Preserve subsequent and unrelated changes.
- Communicate in English. Be concrete about what is modeled, exported, imported, and verified. Proceed with the requested work; ask about decisions that actually affect its scope or design.
- Do not commit or publish unless explicitly requested. Stop Studio Play before editing game scripts; synchronize through Rojo and read back `.Source` before restarting Play.
- Blender used for the trees: **5.1.2**, executable `C:\Program Files\Blender Foundation\Blender 5.1\blender.exe`. Recheck availability in another environment.

**First action in the receiving session:** open the two Blender lineup images below, inspect the source `.blend`, then inventory the next asset family and its placement/interaction constraints. If the reference files are unavailable, report that limitation; do not quietly substitute a generic cartoon style.

## 3. Reference hierarchy — open the images, not just their filenames

Use this order when references disagree:

1. **Approved modeled forms:** `assets/frostbite-peaks/powder-firs-v1/PowderFirs.blend` and its actual Blender renders.
2. **Implemented export quality:** `assets/frostbite-peaks/powder-firs-v1/roblox/PowderFirsRoblox.blend`, the optimized preview, captured native templates, and actual Studio inspection.
3. **Concept intent:** selected Powder Fir concept and two sibling concepts. These guide softness, density and character; they are not a geometrically exact specification.
4. **Existing map source/specifications:** authoritative for placement, dimensions, paths, interactions and supports, but existing placeholder geometry is not the target finish.

### Approved Blender family

![Approved Blender Powder Fir family](../../assets/frostbite-peaks/powder-firs-v1/powder-firs-lineup.png)

[Branch detail](../../assets/frostbite-peaks/powder-firs-v1/powder-fir-branch-detail.png) · [A Original](../../assets/frostbite-peaks/powder-firs-v1/powder-fir-a-original.png) · [B Broad](../../assets/frostbite-peaks/powder-firs-v1/powder-fir-b-broad.png) · [C Upright](../../assets/frostbite-peaks/powder-firs-v1/powder-fir-c-upright.png)

### Optimized Blender export preview

![Optimized Powder Fir export preview — a Blender render, not a Studio screenshot](../../assets/frostbite-peaks/powder-firs-v1/roblox/powder-firs-roblox-preview.png)

### Selected concept

![Selected Powder Fir concept — concept art, not a modeled asset](regions/2026-09-22-frostbite-peaks/tree-concepts/02-powder-fir.png)

[Broad concept](regions/2026-09-22-frostbite-peaks/tree-concepts/02b-powder-fir-broad.png) · [Upright concept](regions/2026-09-22-frostbite-peaks/tree-concepts/02c-powder-fir-upright.png)

When handing this document to an AI outside the checkout, also provide the approved lineup, branch-detail image and optimized preview. Markdown paths alone do not give an external session access to images. Include the source `.blend` and scripts when that session will build assets.

## 4. Visual rules

| Element | Target established by the trees | Apply to other assets |
| --- | --- | --- |
| Main shape | Clear tapered crown and substantial boughs | A strong readable silhouette before surface detail |
| Large surfaces | Soft, joined snow masses with rounded scalloped overhangs | Beveled edges, shaped masses and intentional transitions appropriate to the material |
| Secondary detail | Branch skirts, root flares, winding bark ridges | Thick beams, roof courses, rock strata, pipe collars, inset panels and substantial trim |
| Small detail | Modeled needle sprays plus subtle grain | Use geometry where a feature changes silhouette; textures for fine surface variation |
| Density | Rich branching inside a simple overall silhouette | Add detail in organized groups; retain quiet surfaces and negative space |
| Irregularity | Rotated tiers, varied bough lengths and independent seeds | Controlled variation with coherent construction; avoid random distortion everywhere |
| Material separation | Pale snow, dark green foliage and warm brown bark | A limited palette with distinct light/dark masses and material-specific roughness |
| Finish | Mostly matte, softly lit, lightly textured | Avoid universal gloss, noisy photo textures and strong baked directional shadows |
| Variants | Broad, original and upright proportions | Change structure and silhouette, not merely rotation, tint or uniform scale |

The approved result is stylized rather than botanical or photographic realism. It is also more developed than a primitive blockout: stacked cylinders/cones with white caps did not meet the tree target. Visible bevels, shaped edges, layered forms and material treatment are part of the asset, not something lighting alone should provide.

Detail must read at player distance. For each object, identify three levels: the main silhouette, the material/construction features that explain it, and close-up surface detail. Do not spend the entire budget on tiny noise while leaving the outline generic.

### Material and color anchor

The following are the **actual source Blender linear RGB values**, not display-space hex colors. Use them to understand the Frostbite benchmark, not to recolor every region.

| Source material | Linear RGB | Source roughness | Treatment |
| --- | --- | --- | --- |
| Powder snow | `(0.85, 0.91, 0.97)` | 0.90 | Cool near-white, slight grain, rounded volumes |
| Warm ridged bark | `(0.20, 0.105, 0.047)` | 0.94 | Real longitudinal ridges and fine bump |
| Needles | Six greens from `(0.022, 0.069, 0.041)` to `(0.080, 0.152, 0.067)` | 0.91 | Dark inner foliage, modest color variation between sprays |

Other exact greens are in `tools/blender/create_powder_firs.py`. Source bump strengths are snow 0.22, bark 0.45 and foliage 0.14, with bump distance 0.045. These are scale-dependent settings used for these trees, not universal presets.

The production tree atlas uses roughness 0.91 throughout. Future kits should use roughness appropriate to each material: wood and stone generally diffuse; exposed metal can have tighter highlights. Keep metallic, wet and emissive surfaces localized so their contrast remains useful. New regional palettes and numeric settings are proposals until reviewed.

## 5. How the trees were actually built

The reproducible builder is [create_powder_firs.py](../../tools/blender/create_powder_firs.py). Read its functions before adapting them. It makes editable mesh geometry in Blender rather than placing a rendered image on cards.

1. **Separate variants and materials.** Each variant has its own collection and three source mesh objects: Bark, NeedleSprays, Snow. That is **nine source mesh objects total**. Ground, labels, lights and camera live in `PREVIEW_ONLY`.
2. **Build the woody structure.** A tapered, slightly irregular trunk uses longitudinal rings, flared roots, additional raised bark ribs and supporting branches. Bark detail affects real geometry and catches highlights.
3. **Shape the crown.** A/B/C use 8/7/9 tiers, with tier spacing tighter toward the crown. Independently seeded branch arrangements contain 42/36/47 main boughs. Tier rotation and modest length/angle variation prevent perfectly repeated rings.
4. **Fill and articulate foliage.** Dark inner volumes support the crown. Feathered sub-branches carry thousands of individual closed needle elements. Visible tips hang beyond the snow, giving a detailed silhouette. Needles intersecting the modeled snow are culled so they do not poke through its upper surface.
5. **Sculpt the snow.** Overlapping ellipsoidal mounds and smaller edge fingers form a connected, scalloped mantle. The builder voxel-remeshes them at 0.092, smooths four iterations at factor 1.05, adds subtle geometric variation of about 0.045, then reduces topology. These values correspond to trees roughly 23–28 units high; adapt them to asset scale.
6. **Finish the crown and root contact.** A small irregular leader continues the branching rhythm; localized snow collects near the root flare. Avoid a large smooth frosting cone or uniform stacked discs.
7. **Normalize and inspect.** Geometry is normalized to the intended proportions and a local bottom-center frame. It is checked for manifold edges and degenerate faces, saved as a native `.blend`, then rendered as a lineup and close-ups.

The source contains **978,850 triangles across three trees**. It is the art source, not the runtime budget. Preserve it separately from the optimized export.

### Meaningful family variation

| Variant | Identity | Source target height | Export dimensions W × H × D, intended studs |
| --- | --- | --- | --- |
| A | Balanced original | 26 | 15.129 × 25.955 × 15.463 |
| B | Lower, broader crown | 23.5 | 17.503 × 23.430 × 16.498 |
| C | Taller, narrower crown | 28.3 | 14.261 × 28.231 × 14.681 |

Use the manifest for exact production bounds. Small differences from source heights come from optimization. For other repeatable props, choose similarly readable structural variations while retaining common material treatment and craftsmanship.

## 6. Translate the style into the rest of the game

These are **recommended translations of the approved tree style**, not already approved replacement designs. Inventory all assets, including generated Part assemblies, before deciding which kits to rebuild.

| Family | Modeling direction | Constraints to preserve |
| --- | --- | --- |
| Rocks and cliffs | Chunky irregular masses, broad planes, softened/chipped edges, a few intentional strata; sculpt snow or moss as separate deposits where appropriate | Walkable ledges, support heights, region boundaries and field clearance |
| Crates, fences and signs | Thick shaped boards, visible joinery, softened corners, restrained grain, readable larger hardware | Sign text, interaction targets, fence gaps and collision proxies |
| Buildings and workshops | Substantial beams and masonry, layered roofs, dimensional trim, inset doors/windows and controlled wear | Doorways, stairs, floor levels, service positions and camera sightlines |
| Garden and tropical vegetation | Full organized clusters, shaped leaves, tapered branches, distinct trunk/crown variants | Planting envelopes, path widths and creature visibility |
| Cinder quarry assets | Warm stone masses, readable fracture planes, stout timber/metal supports, selective soot and contained hot accents | Quarry layout, mine openings, collision and gameplay zones |
| Frostbite props | Snow following gravity and support, rounded overhangs, cool rock/ice with warm timber accents | Existing Alpine sockets, bounds, terrace supports and access |
| Thunderworks equipment | Beveled housings, thick cables/pipes, layered coils and ceramic components, localized emissive elements | Machine clearances, landmarks, prompts and region progression |
| Orbit equipment | Rounded housings, layered panel geometry, legible rings/thrusters, selective emissive details | Existing function, sockets and navigation cues |
| Lobby, plots and services | Cohesive stonework, shaped trim, vegetation and readable service silhouettes | Plot entrances facing the fountain, placement slots, collection pads, City Relaunch, Catastrophe Atlas and Upgrade Workshop functions |
| Creatures and animated assets | Carry over shaped silhouettes, controlled detail and clear materials while preserving each creature's identity | Rig, bones, animation clips, attachments, scale, hitboxes and readable rarity cues; inspect their pipeline separately |

Replacing static art does not automatically authorize a new layout, progression system or creature design. Keep functional geometry and behavior until a specific change is agreed. Water, particles, UI text and runtime effects may remain engine systems; rebuild their associated 3D props in Blender and harmonize their visuals through the appropriate pipeline. Do not replace functional UI with decorative meshes.

Suggested first batch: a small Frostbite rock group, crate and fence section beside the approved trees. This tests transfer to stone and timber before expanding to large landmarks. The next asset family is not yet selected by the user.

## 7. Repeatable production workflow

### A. Inventory and lock the placement contract

Create a ledger with asset ID/name, region, source generator/library, instances used, intended dimensions, origin/pivot, anchor sockets, collision role, interaction/animation requirements, references, approval state and replacement status. Distinguish unique source assets from repeated instances. Record all consumers of shared assets.

Read the existing `*AssetSpec.luau`, placement module and `docs/CONTRACTS.md`. For multipart assets, record each component's bounds center relative to the shared asset frame. For bridges/buildings/interactive props, record useful attachment points such as door thresholds, path ends and prompt positions.

Do not infer dimensions from a perspective concept image when the map already has measured specifications. Do not shrink an important landmark solely to force it into an old envelope; propose the necessary placement revision for review.

### B. Model, review, then make variants

Build one representative hero asset to establish the material and form treatment for its family. Compare it beside the Powder Fir at the same scene scale. Supply a neutral three-quarter render, front/side view, detail crop and player-scale view. Present actual Blender renders clearly labeled as such.

Match the reference's silhouette, proportions, material divisions, edge softness and detail distribution. If using concept generation first, preserve the selected concept and label it separately. Obtain design approval before multiplying a new treatment throughout the map. If the current session already has approval for that design, continue without requesting it again.

Use deterministic seeds for procedural variation. Keep each variant structurally distinct and retain the same artistic rules. Save editable source meshes and any generation script so the family can be revised consistently.

### C. Build a separate game export

Study [export_powder_firs.py](../../tools/blender/export_powder_firs.py) as a worked example; its needle-specific assumptions are not a generic decimator for arbitrary objects.

The tree export preserves every remaining source needle but converts each to a closed six-triangle volume. Snow is reduced toward 6,500 triangles per variant; bark is retained. Needles are batched around 17,400 triangles, with a simplified inner foliage core joined to the first batch. Final result: **140,720 triangles total**, approximately 85.6% below source, split into **14 export mesh objects: A5/B4/C5**. Nine objects in the source Blender scene and fourteen in the export are both correct.

The current tree exporter enforces **fewer than 20,000 triangles per component**. Treat this as the established pipeline guardrail; check current importer requirements before changing it. It is not a recommended budget for every object. Splitting a mesh helps component limits but does not reduce the scene's total geometry or draw cost. Ninety-one detailed trees still need device profiling.

Allocate geometry first to silhouette and larger material features. Bake fine grain where appropriate. Inspect the optimized mesh against the source from matched views before accepting it. Keep source files intact; use a versioned export folder for new revisions.

### D. Portable materials

Blender procedural shader nodes do not by themselves reproduce the material in Roblox. The tree export creates a shared **2048 × 2048 color, tangent-space normal and roughness atlas**, with eight regions for snow, bark and six foliage tones. Color values are converted from linear to sRGB; normal and roughness data use non-color interpretation. UVs stay inside their material tile with padding. The example creates procedural texture maps; it is **not a full high-poly-to-low-poly bake**.

This simple material-tile projection works for the tree's restrained textures. Use deliberate unwraps and appropriate bake workflows for directional timber, panel seams or unique landmark details; do not blindly stretch a whole grain tile across each face. Keep texel density consistent. Supply PNG maps separately as well as embedded FBX textures, and verify the resulting SurfaceAppearance in Studio.

### E. Export and independent round trip

Preserve a shared asset-local coordinate frame across components. The existing pipeline converts Blender coordinates `(x, y, z)` to Roblox `(x, z, -y)`. Dimensions convert to `(width, height, depth)` separately; a size vector does not take a negative depth. Gallery offsets are only for viewing.

The tree FBX exporter uses mesh-only selection, `axis_forward='-Z'`, `axis_up='Y'`, `global_scale=1`, `apply_unit_scale=False`, `apply_scale_options='FBX_SCALE_NONE'`, applied mesh modifiers, triangulation, copied/embedded textures and no animation. Preserve a separate rigged export route for animated assets.

Write a manifest containing library and bundle names, unit convention, pivot, textures, asset/variant dimensions, anchor sockets, component filenames, **component center offsets**, triangle counts and variant membership. Reimport every FBX into a fresh Blender scene. Check exact names, expected dimensions/centers, finite UVs, texture presence, normals, nondegenerate geometry and complete bundle membership. See [verify_powder_exports.py](../../tools/blender/verify_powder_exports.py).

The tree verifier found tiny internal two-face remnants after snow decimation; removing those was necessary for a clean FBX round trip. A successful export call alone did not prove valid geometry. Inspect logs for the completion marker as well as process exit status.

### F. Native import, capture and Rojo integration

1. Import in Studio Edit mode with the intended asset owner and separate named components. Anchor imported art. Verify actual dimensions, maps and all required names before connecting it to production.
2. Inspect scale numerically. The tree preview initially showed a 100× unit problem; the captured import ultimately had a uniform ratio of about **72.544426** after importer scaling. Never apply a remembered 0.01 correction blindly to every new kit. Compare each axis and part with the manifest, reject distortion, and normalize displayed `Size` consistently.
3. Use [prepare_region_templates.luau](../../tools/studio/prepare_region_templates.luau) from the Studio plugin/command context as the native capture pattern. Clone the uploaded MeshParts, preserve MeshSize and SurfaceAppearance, normalize Size, and serialize the real library into `src/server/Map/<LibraryName>.rbxm`. Save actual IDs/maps and the conversion ratio in `roblox-import.json`.
4. Do not reconstruct native meshes by writing invented IDs into new parts. Do not confuse importing a gallery into Workspace with activating the map's replacement library. The Powder trees remained cylinders until the captured library was connected.
5. Stage raw galleries outside Workspace. Use the current `ImportStaging` contract and stray-import quarantine; never leave huge unanchored imports to fall into the level. Preserve raw imports without treating incomplete or typo-named galleries as verified libraries.
6. Validate the complete kit and all target sites before removing existing art. Clone templates at the original placement sites, retain gameplay metadata and separate collision proxies, and make replacement safe to repeat. Missing/invalid kits should leave the previous art intact and produce a useful diagnostic.
7. Read back synchronized library contents and script `.Source`, then test Play. A source file on disk is not evidence that the active Studio place received it.

The project was user-owned at tree capture; importing assets under a group does not transfer ownership of the experience. Verify actual asset loading in the destination experience rather than assuming ownership implies permission everywhere.

#### Multipart placement: the easily missed part

Roblox MeshPart CFrames locate native mesh bounds centers. The asset's base/pivot is a separate frame. Each tree component is placed using:

```lua
part.Size = component.size * uniformScale
part.CFrame = worldBaseCF * CFrame.new(component.center * uniformScale)
```

Do not give every component the same center or lift each by half its own height. That separates bark, snow and foliage. Apply the same scale to all component offsets and sizes; leave native MeshSize unchanged.

For the current trees, `FrostbitePowderProps.placement` preserves the old TrunkBase socket and fits the new crown into the old oriented envelope. It accounts for the new trunk's offset from the bounds center. This is more precise than centering the silhouette on the old trunk, and it protects nearby paths/supports. Other asset families need their own socket-aware fitting rules.

#### Runtime property lessons from actual integration

- Read SurfaceAppearance texture identity through `ColorMapContent.Uri` in game scripts. The legacy `ColorMap` property caused a plugin-permission error during the real tree build.
- Set restricted authoring properties in Edit/plugin context. Runtime cannot write MeshPart `RenderFidelity`; clone its authored value. All captured tree templates use Automatic.
- Keep these property checks in actual Studio validation. The headless fixtures passed while these runtime permission errors still existed.

## 8. Acceptance gates and evidence

| Gate | Required evidence |
| --- | --- |
| Style | Matched views beside the approved tree; clear silhouette, modeled secondary forms, restrained textures, material separation and controlled variation |
| Design approval | Record which actual model/version the user accepted; distinguish it from concept selection |
| Source delivery | Editable `.blend`, generation script if used, named collections, materials, dimensions and sockets |
| Optimization | Source/export comparison, measured triangle totals, no important silhouette loss, suitable batch/instance cost |
| Export integrity | Independent FBX round-trip names/bounds/offsets/UV/maps/geometry checks |
| Integration | Captured native `.rbxm`, real upload IDs, verified scale, synchronized source and library |
| Gameplay | Correct placement, grounding, route and field clearance, preserved prompts/rigs/collision, no raw import copies loose in Workspace |
| Runtime visuals | Actual Studio close-up and player-distance views under game lighting; successful loading of placed instances |
| Performance | Representative populated views and target-device testing; report hardware/settings and limitations rather than promising mobile readiness |

Measure the optimized asset in game. Blender uses different shading and lighting, so do not promise pixel-identical reproduction from an offline concept render. Preserve the approved design and iterate on observed differences. Record any remaining seam, shading, scale or detail issue honestly.

### Verified tree baseline and limits

The tree integration was verified in Studio: **91 sites, 425 MeshParts, variants A31/B30/C30, zero remaining old tree PlaceholderArt models**, and **425 successful preload results with zero failures**. Actual overview and close-up appearance were reviewed. Native library: `src/server/Map/FrostbitePowderTemplates.rbxm`. ID record: `assets/frostbite-peaks/powder-firs-v1/roblox/roblox-import.json`.

The tree placement verifier passed **11,151** checks. Structure/quote scans and Rojo build passed. That did not make the whole game test suite green: unrelated map/plot/route checks remained failing. Read the newest relay for current totals. A short desktop frame sample was not a reliable forest benchmark because the camera reset; **mobile performance remains unverified**. Approval of the Blender forms is documented; final post-import user approval should not be invented.

Some older tree README/geometry-report text still says upload or optimization is pending. Those describe earlier production stages. Use the captured native library, import record and newest relay to establish integration state; use source geometry reports for their actual measurements.

## 9. Files and commands to reuse

All paths below are relative to the source checkout.

| Purpose | File |
| --- | --- |
| Editable approved art | `assets/frostbite-peaks/powder-firs-v1/PowderFirs.blend` |
| Source generator / preview renderer | `tools/blender/create_powder_firs.py`, `tools/blender/render_powder_firs.py` |
| Optimized art / bundle | `assets/frostbite-peaks/powder-firs-v1/roblox/PowderFirsRoblox.blend`, `PowderFirsBundle.fbx` in the same folder |
| Export / round-trip verification | `tools/blender/export_powder_firs.py`, `tools/blender/verify_powder_exports.py` |
| Export measurements / evidence | `assets/frostbite-peaks/powder-firs-v1/roblox/manifest.json`, `validation.json`, `roblox-import.json` |
| Runtime spec generation | `tools/generate_powder_spec.py` |
| Placement reference | `src/server/Map/FrostbitePowderSpec.luau`, `FrostbitePowderProps.luau`, `FrostbitePeaks.luau` |
| Native library capture | `tools/studio/prepare_region_templates.luau` |
| Existing site/socket reference | `src/server/Map/FrostbiteAlpineAssetSpec.luau` |
| Validation | `tools/verify_powder_firs.luau`, `tools/verify_frostbite_alpine.luau`, `tools/verify_region_template_capture.luau`, `tools/verify_import_strays.luau` |

Useful checks from the repository root:

```powershell
lune run tools/verify_powder_firs.luau
python tools/luau_lint.py src
python tools/quote_scan.py
rojo build -o build/AssetRestyleReview.rbxl
```

Use family-specific placement/export tests as new kits are added. These commands do not replace actual Studio runtime checks. Rebuilding an approved asset is a separate operation: the source tree generator requires `-- --rebuild` to overwrite its saved scene. Do not run it just to open or inspect the approved art. For new work, copy/adapt the workflow into new versioned files and output directories.

Each completed kit should include source `.blend`, optimized `.blend`, preview PNGs, FBXs, portable texture PNGs, a manifest with sockets/centers, validation report, native library and import metadata after upload, plus a concise implementation/status note. Record remaining limitations and update the root relay.

## 10. Copyable starter prompt for the next AI

> Read `docs/art/ASSET-RESTYLE-HANDOFF.md` in `C:\Users\rahul\orca\Catch-a-Catastrophe`, then inspect its approved Powder Fir lineup, branch-detail image, optimized preview and source Blender scene. These trees establish the style and quality target for recreating all existing game assets in Blender. Read AGENTS.md, the newest RELAY.md and relevant CONTRACTS.md sections before editing.
>
> Start by inventorying the next asset family and its exact map bounds, pivots, sockets, interactions and collision requirements. Preserve each region's theme and existing gameplay. Build one representative asset in the same sculpted, detailed, softly textured style as the approved trees, and render it beside them at matching scale for review. Extend an approved design into meaningful variants, then optimize and export without losing its important forms. Keep editable source and game exports separate.
>
> Carry approved assets through independent FBX validation, native Roblox import/capture, Rojo integration and actual Studio visual/gameplay checks. Preserve component-center offsets and original anchors. Validate the full replacement before removing old art. Do not mistake an imported gallery or an offline render for completed integration. Report evidence and remaining limitations; do not invent asset IDs, approval or performance results. Do not publish or commit. If the next family is unspecified, propose a small representative batch after inspecting the current inventory rather than rebuilding the entire game at once.

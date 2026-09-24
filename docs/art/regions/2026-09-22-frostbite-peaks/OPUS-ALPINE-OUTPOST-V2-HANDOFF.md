# Opus implementation prompt — Frostbite Peaks, refined Alpine Outpost

Implement the approved refined Alpine Outpost design in Catch a Catastrophe. The objective is to reproduce the reference image as faithfully as possible in the playable map: composition, landmark proportions, placement, density, colors, materials, snow coverage and paths. Do not reinterpret it into another alpine design or settle for a generic snowy region.

## Repository and authoritative image

Work in `C:\Users\rahul\orca\Catch-a-Catastrophe`. Read AGENTS.md, the latest RELAY.md and relevant contracts first. Preserve other agents' work.

Open and visually inspect this exact image before implementing:

`C:\Users\rahul\orca\Catch-a-Catastrophe\docs\art\regions\2026-09-22-frostbite-peaks\frostbite-peaks-v2-02-alpine-outpost-refined.png`

This V2 image is the visual target. The original V1 option and the September 20 Alpine Expedition design are not the final target. Read `ALPINE-OUTPOST-V2-REFINEMENT.md` for context. The white caption/footer is presentation, not in-game signage.

## Division of work: Astra creates the art; you implement the map

**Astra, the other Codex agent, will create the custom art in Blender**, including the lodge, layered snow-covered cliffs/shelves, rope bridge, improved snowy trees and supporting camp/vegetation props, plus the exported materials/textures needed for that art. You must not generate replacement Blender models, AI meshes, custom texture images or substitute production art yourself. Do not write or modify Astra's Blender generators or overwrite existing asset deliveries.

Your job is the actual map: measured layout, ground treatment using available materials, terrain/platform heights, paths, functional stairs and bridge collision, asset placement sites, lighting/effect anchors, integration scaffolding and gameplay preservation. Simple accurately sized temporary placeholders and collision proxies are appropriate while Astra models the assets. Label these as temporary; do not report the final visual match as complete while custom art is missing.

Use existing Frostbite assets where they match the reference; preserve `assets/frostbite-peaks/props-v1` and `FrostbitePropTemplates.rbxm`. The new kit should have its own library, suggested `FrostbiteAlpineTemplates`, rather than silently replacing the existing one.

## First deliverable: dimension the map and give Astra the asset contract

Use the V1 option-02 builders in `docs/art/regions/2026-09-22-frostbite-peaks/src/` as a starting point. They contain a real 280-by-200 cell, gate geometry and camera. V2 was refined with image generation: its revised proportions are not automatically identical to V1, and V1 clearance measurements do not validate V2.

Fit the reference camera against the known walls/gate piers, compare V1 to V2, and document revised landmark footprints and heights in studs. Distinguish measured constraints from estimates. Read the actual RegionScenery CFrame and explicitly convert Blender/world/region-local axes; do not copy the old hut/bridge bearings, which can put them on the wrong sides.

Write these files early, then continue building without waiting for finished assets:

- `docs/art/regions/2026-09-22-frostbite-peaks/ALPINE-OUTPOST-V2-LAYOUT.md`: coordinates, rotations, heights, walkable connections, camera, palette, density/clearance plan and comparison images.
- `docs/art/regions/2026-09-22-frostbite-peaks/ALPINE-OUTPOST-V2-ASSET-REQUEST.md`: exact asset names, W/H/D bounds, base pivots, front direction, placements/counts, reuse decisions and required sockets/material regions. Include crops or clearly identified image features for each request.

Proposed Astra-owned asset families: timber lodge with porch/roof/chimney; broad layered cliff modules and shelf facades; bridge with posts/ropes/planks; mature/medium/sapling snow firs; rounded snow boulders/drifts; frosted shrub and alpine grass clumps; orange expedition tent; woodpile; camp crate/barrel dressing; railings, trail markers, signpost and pennant. Reuse matching existing pieces and combine modules sensibly. These are proposed families, not an invented finalized mesh count or dimension contract. If ground tracks/ice/snow require new artwork, request it from Astra and reserve their placements rather than generating that artwork yourself.

## Reproduce these visible features

1. **Overall layout:** preserve the 280-by-200 rectangular chain cell and centered gates. South is the entry from Cinder; north exits toward Thunderworks. A broad snowy creature meadow occupies the middle. Keep a continuous straight, flat 24-stud clear route between gates and generous gate aprons. No circular arena, winding main route, mountains across the exit, or redesigned map dimensions.
2. **Image-left camp:** a substantial chestnut timber lodge on a low stone terrace near the rear-left side. Teal roof under thick rounded snow, warm amber windows, front-facing porch/door, stone chimney and restrained smoke. Short wide stairs connect the terrace to the meadow. Orange tent, teal pennant, firewood and supplies form the compact adjacent camp. It must remain approachable and correctly scaled, not a tiny hut lost behind trees.
3. **Image-right bridge:** a timber rope bridge between two layered slate shelves over a narrow blue frozen creek. Both ends reach actual walkable landings; stairs connect the side route to the meadow. Add the pictured lantern/signpost accents. Keep this an optional side route. Do not add a major waterfall or turn the center into a river crossing.
4. **Edges and rear corners:** broad irregular slate formations with horizontal fractures and thick snow caps, not the old tall striped spires. Mixed fir heights, saplings, nested boulders, frosted shrubs and small golden grasses create dense composed clusters. Preserve gaps around gates, landmarks and stairs. Match the reference's asymmetry; do not scatter props randomly or repeat one tree at equal intervals.
5. **Snow and surface detail:** soft white powder, cool blue shadows, shallow drift transitions, subtle footprints/wind lines and muted blue ice patches. The central field should have visual texture without becoming cluttered with raised obstacles. Blend the route into the snow; no gray paved strip or colored kerbs down the center. Ice markings are visual, not a new slippery-ground mechanic.
6. **Walls and light:** preserve the cream/teal/gold map language. Add region-owned non-colliding snow caps where shown. Keep warm window/lantern accents against bright cool alpine snow, restrained bloom and readable shadows. Do not globally change Lighting to fix one zone and alter every other region. Snow on adjacent flanks must be bounded to Frostbite; preserve the orange Cinder transition in front.
7. **Signs and creatures:** retain FROSTBITE PEAKS / 75K COINS at entry and THUNDERWORKS / 300K COINS at exit, with real per-player gate state. The reference illustrates south unlocked/north locked, not hard-coded gate behavior. Keep existing species, population and scale; do not recreate the illustrative creatures as scenery.

## Implementation requirements

- Inspect `FrostbitePeaks.luau`, `FrostbiteProps.luau`, RegionScenery, MapBuilder, Regions config and existing placement tests. The current Frostbite module is the obsolete circular blockout; adapt it to the chain layout rather than retaining its radius-based placements and field skin.
- Where required, return Frostbite's layout through RegionScenery, give Frost its own perimeter dressing and a snow `TRAIL_BLEND` treatment. Scope shared-module edits tightly.
- Preserve actual ground/hazard alignment. Do not bury Frost warning effects under a newly raised snow slab. Use deliberate walking proxies for stairs, shelves and bridge; decorative art must not create unintended collision or query obstructions.
- Every asset site needs a stable name, AssetName, AssetSize, bottom-center GroundCF, support/collision role and a separately removable PlaceholderArt child. Reserve sockets for door/porch access, bridge endpoints, lights, smoke, flags and effects.
- Make placements data-driven. New native templates must be validated as a complete kit before replacing its temporary art. Preserve native MeshSize, texture data and bottom-frame/center-frame offsets; reject missing assets, incorrect scale or axis distortion. No fabricated asset IDs.
- Keep functional collision, walkways, effects and gameplay outside replaceable art. Once Astra delivers the manifest, reconcile final sockets and footprints rather than leaving guessed anchors in place.
- Preserve access volumes, unlock costs, creature spawning/navigation, capture/hazards, saves, economy and all other regions. No lodge gameplay, quests or new progression.

## Visual acceptance is required

Render/capture from a camera matched to the V2 reference at comparable framing. Produce a side-by-side comparison and check the actual image: lodge size and position, terrace height/stairs, bridge span and connectivity, cliff silhouettes, forest density, open-field balance, ground detail, snow coverage and light/color relationships. Correct visible differences iteratively. Include player-height views of the lodge approach, bridge and gate-to-gate route.

Passing tests alone does not establish that the map matches. If a renderer cannot display the real imported meshes, identify that limitation and use Studio captures instead of presenting placeholder renders as the finished result. Separate layout completion from asset delivery/import and final visual verification. Do not claim pixel-perfect equivalence from an unmeasured concept or a mismatched camera.

Run relevant lint/quote/build, placement/clearance and runtime checks. Validate connected walking routes, gate approaches, creature home/roaming clearance and visible Frost warnings. Confirm Rojo source read-back before Play and follow AGENTS.md. If Studio access is unavailable, finish the authorized map work and leave precise live checks outstanding.

Deliver the implemented map, measured layout, Astra asset request, comparison screenshots, test results and remaining asset/import requirements. Update RELAY.md. Do not commit or publish without an explicit request. Begin by inspecting the refined image and current code, then produce the asset contract and build the map.

# Alpine Outpost V2 — refined concept

Status: Rahul requested the Opus implementation prompt for this refined version. V2 is now the selected implementation target; see `OPUS-ALPINE-OUTPOST-V2-HANDOFF.md`. Production meshes and final dimensioned layout are still outstanding.

User prefers Claude's Alpine Outpost option and requested higher quality textures, layout and density. Created with the built-in image generation tool, editing `frostbite-peaks-v1-02-alpine-outpost.png`. Original V1 image and measured Blender sources remain unchanged.

## Files

- Refined image: `frostbite-peaks-v2-02-alpine-outpost-refined.png`.
- Original comparison: `frostbite-peaks-v1-02-alpine-outpost.png`.

## Changes to review

- More substantial timber expedition lodge with warm windows, porch, deep snow roof, stone terrace and connected stairs; compact tent/supplies remain grouped beside it.
- Broad layered slate cliffs replace the striped pointed rocks; varied snowy firs, shrubs, alpine grasses and nested boulders build density at the borders.
- Rope bridge has more readable timber anchors, handrails, planks, snow and accessible steps beside a blue frozen creek.
- Snow has powder caps, shallow drift shapes, tracks and subtle ice variation; warm lamps contrast against cool shadows.
- Both centered gates, the rectangular cell, open creature meadow and straight central route remain visually legible. Existing creatures are illustration scale cues, not a request for new creature assets.

## Implementation boundary

This is an image-generated art-direction refinement, not a newly measured Blender layout. V1 coordinates are a useful starting point but do not exactly describe the revised image. V1's numerical clearance percentages must not be attributed to V2. Reconcile revised landmark envelopes, stairs and bridge connectivity with the 280-by-200 cell before writing the final implementation contract. Confirm coordinate conversions from the actual source; do not infer region axes from camera directions.

Ground ice markings are a visual treatment, not an instruction to change walk friction, collision, hazard surface height or creature navigation. Snow on walls/flanks must remain scoped to Frostbite and lighting must preserve the rest of the game. No Luau, Blender asset library, Rojo, Studio or gameplay changes were made in the concept/handoff work. Opus must dimension the revised layout and write Astra's asset contract; Astra owns the Blender art.

## Exact generation prompt

Tool: built-in `image_gen.imagegen` (not CLI).

```text
Use case: style-transfer / stylized-concept refinement.
Asset type: polished Roblox environment concept for Frostbite Peaks, Alpine Outpost V2.
Input image 1 is the EDIT TARGET: Claude's Alpine Outpost mockup. Improve this specific scene substantially, retaining its recognizable layout and continuous rectangular game region. Produce one beautiful, high-resolution landscape image, preferably 2304 x 1536 or larger, crisp detailed professional stylized 3D game environment art, suitable as an implementation reference.

COMPOSITION AND INVARIANTS:
Keep the same elevated south-facing-north overview camera, full wide rectangular 280-by-200 region, front and back gates centered and aligned, cream stone perimeter walls with teal-and-gold posts/lanterns. Same general feature placement: expedition lodge on accessible rear-left terrace; narrow rope bridge linking two accessible snow-covered rock shelves in the right band; a shallow frozen creek underneath that bridge; cliff and fir dressing along rear corners and side edges; broad playable snowy meadow in the center. North gate is a locked blue barrier, south entrance is open. Retain a small visible warm rust-orange Cinder terrain transition outside the front wall. Do not turn the rectangle into an island or round arena, do not add a mountain backdrop that obscures the next gate, do not make the central path wind.
Maintain an unobstructed roughly 24-stud-wide, flat packed-snow route straight through both gates, with wide clear gate aprons. The majority (roughly two thirds) of the interior remains open and walkable; increase richness through ground materials and edge composition, not obstacles filling the creature field.

MATERIALS AND QUALITY:
Premium handcrafted stylized 3D, rounded beveled edges, precise clean silhouettes, rich readable material separation, subtle physically based surfaces but still playful and buildable in Roblox. Fine granular powder snow with thick soft overhanging caps, wind-sculpted shallow drifts, muted blue-violet self shadows and gentle sunlit warm-white highlights. Ground has understated shallow footprints, swept wind lines, thin patches of compacted snow and pale blue ice staining without becoming a grid, tiled stripes, noisy texture or deeply rutted road. Layered slate/blue-gray cliffs with natural horizontal fractures and broad snow-covered ledges instead of the original tall striped crystal-like spikes. Timber has visible broad grain, iron fittings, rope has readable twists, low stonework has individual beveled blocks. Ice in the SIDE creek shows clear blue depth, subtle trapped bubbles and a few hairline cracks, not bright glowing cyan everywhere.

LANDMARK IMPROVEMENTS:
Rear-left lodge should be a clear, appealing hero landmark, somewhat more substantial than the original tiny hut but contained in its side band: deep chestnut stacked timber, stone base, thick snow over teal metal roof, cozy amber window light, sheltered front porch facing into the meadow with visible front door and a well-connected wide short stairway from the meadow. A small teal expedition pennant, neatly stacked firewood, two supply crates, a compact orange canvas expedition tent alongside, and lantern posts form one purposeful camp cluster. A chimney has a restrained curl of smoke. All of these fit the existing terrace rather than expanding into the central lane. Low timber rails where needed, no inaccessible sealed platform.
Right side: a visibly crafted short rope-and-plank bridge across a shallow blue frozen creek between two layered rock outcrops, snow dust on planks, sturdy timber anchor posts and double rope handrails. Both ends connect to a walkable overlook, with short readable steps from the meadow; it is a rewarding optional side route, not a required crossing on the gate-to-gate route. A lantern and small expedition wayfinding sign provide warmth. Do not add waterfall, igloos, crystal palace, ski lift, towers or new main buildings.
Replace repetitive single-row edge firs with composed clusters of mature snow-laden firs, medium firs and saplings, including some inside the walls along the side bands. Stagger their heights and spacing, with deep green foliage peeking through thick sculpted snow. Nestle slate boulders, low frosted shrubs, dried golden alpine grasses and compact snowbanks around their bases. More density at corners, lighter gaps beside landmarks and paths. Keep side walls and all entrances legible; no continuous high forest wall inside the playable field.

CREATURES:
Preserve the original six sparse creature placements as small cute stylized Frost creatures with ground contact, without enlarging them or adding population: two pale icy ferrets, one pale blue sloth, two woolly brown/cream bison and one tiny blue-gray crowned mammoth. They are secondary scale cues, not the main focal points. Keep them off the clear center route.

LIGHT AND PRESENTATION:
Bright crisp alpine late-morning light, soft global illumination, readable blue shadows, warm amber lamp/window accents, restrained glow, no haze hiding detail, no depth-of-field blur, no photorealistic gritty survival-game aesthetic, no heavily overexposed snow. Visually inviting cozy expedition outpost.
Exact readable gate text: north 'THUNDERWORKS' and '300K COINS'; south 'FROSTBITE PEAKS' and '75K COINS'. A narrow clean ivory footer beneath the complete scene reads 'ALPINE OUTPOST' with smaller 'FROSTBITE PEAKS · REFINED CONCEPT'. No additional labels, annotations, interface, watermark or fake asset callouts.
This is an art-direction refinement of the supplied image, not an unrelated new map.
```

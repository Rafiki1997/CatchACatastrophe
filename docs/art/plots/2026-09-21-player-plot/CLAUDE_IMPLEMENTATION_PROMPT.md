# Pocket Power Town — Claude implementation prompt

Update the player plot in Catch a Catastrophe to match the “Pocket Power Town” reference image as closely as possible.

Reference image:
C:\Users\nguye\Documents\repos\catch-a-catastrophe\CatchACatastrophe\docs\art\plots\2026-09-21-player-plot\plot-v2-pocket-power-town.png

Project:
C:\Users\nguye\Documents\repos\catch-a-catastrophe\CatchACatastrophe

Treat the screenshot as the visual specification, not loose inspiration. Match its layout, proportions, colors, materials, architecture, and decoration placement.

## Responsibilities

You (Claude) handle plot code, layout, assembly, asset placement, gameplay integration, and verification.
Astra handles creating any missing custom 3D assets. Do not model or generate those assets yourself.

Inspect existing assets first. If custom assets are missing, prepare a precise asset request for Astra with names, reference appearance, dimensions in Roblox studs, intended placement, pivot/orientation, material colors, and any collision or interaction requirements. Continue work that does not depend on those assets. Do not replace missing assets with generic shapes and call the design finished.

Likely assets Astra may need to create:

- Teal water tower with yellow domed cap, support frame, and pipes.
- Brick utility workshop with cream roof trim, door, chimney, and wall lights.
- Rounded teal-and-cream dispatch booth with windows, counter, and sign.
- Teal-and-cream owner-sign frame with yellow trim.
- Gold coin collection platform.
- Modular creature-pad frames with yellow corner accents and illuminated strips.
- Brick fence pillars, metal railings, and warm lanterns.
- Teal pipes, elbows, and yellow couplings.
- Matching low-poly vegetation if existing assets are unsuitable.

## Visual requirements

- Slate-blue paved courtyard with ivory curbs.
- Regular grid of dark inset creature pads.
- Water tower at the rear-left and brick workshop at the rear-right.
- Dispatch booth at the front-left, with a functional red vent button.
- Gold collection platform centered at the entrance.
- Owner sign at the front-right.
- Perimeter fencing, warm lamps, teal pipes, shrubs, and trees matching the reference.
- Clear walking space and unobstructed views of creatures.
- Bright, friendly lighting, restrained glow, and polished low-poly forms.

## Implementation requirements

Inspect src/server/Map/PlotTemplate.luau, CityService, CircuitService, and the station builders before editing.

Preserve:

- The existing 60×60-stud plot footprint.
- All 24 pads in the existing 6-column × 4-row grid.
- Pad indices, adjacency, unlocking, deployment, and station placement.
- Collection, venting, ownership, spawning, circuits, and progression.
- Existing creature models.

The reference is concept art: pad details and glowing connections are illustrative. Keep the actual gameplay rules, including valid adjacent circuit pairs. Display the actual owner’s name on the sign.

Keep repeated plot construction efficient and modular. Avoid unrelated game changes.

## Verification

Inspect the implemented plot in Roblox Studio from an elevated entrance-facing camera matching the reference. Compare screenshots and refine differences in layout, scale, palette, and silhouette. Verify the existing plot interactions still work.

Proceed with implementation. If Astra’s assets are needed to finish, provide the exact asset handoff and clearly state what remains dependent on delivery. Once supplied, integrate them and complete the visual comparison.


# Claude handoff — Orbit Outpost / V7 Gravity Garden

The user approved V7 Gravity Garden. Implement the playable base region while Codex builds the custom Blender kit below. Codex will later import, normalize, and place the real meshes. Proceed now using replaceable placeholders at these exact dimensions.

## Workspace and ownership

Work in `C:\Users\rahul\orca\Catch-a-Catastrophe`, the checkout containing the latest Gusty, Splashwater, Cinder, Frostbite and Thunderworks region modules. The older `orca\workspaces\Catch-a-Catastrophe\Catch-A-Catastrophe` checkout lacks these refinements: do not implement there. Read this repository's AGENTS.md, newest RELAY.md and docs/CONTRACTS.md first. Preserve concurrent edits.

- Claude owns `src/server/Map/OrbitOutpost.luau`, narrow Cosmic delegation/entrance/floor changes, collision, walkable terrain, transparent energy/glass panels, asset-site placeholders, and relevant validation.
- Codex owns `assets/orbit-outpost/`, `tools/blender/create_orbit_props.py`, `tools/blender/verify_orbit_props.py`, and later mesh-template/placement integration. Do not edit these or shared Blender helpers.
- No commits or publishing. Preserve all other regions, existing signs, paths, gates, economy, creatures, capture and local atmosphere behavior.
- Reread RELAY/CONTRACTS before targeted edits to retain simultaneous work.

## Approved reference

Open `docs/art/regions/2026-09-21-orbit-outpost/orbit-outpost-v7-gravity-garden.png`.
Match its identity and broad composition, adapting it to the real 150-stud diameter region. The mockup is art direction, not a measured map or authorization to change the whole game's sky.

- Violet-gray lunar soil, asymmetric perimeter rock terraces, small amethyst clusters and purple alien plants, pale research equipment, cyan translucent barrier panels, warm windows.
- Rear centerpiece: a three-pronged ivory gravity cradle surrounding a suspended amethyst meteor; small orbit stones nearby. Build the supporting dais and terraces; reserve exact mesh sites.
- Image left/local +X: compact round field laboratory with a glass dome. A closed facade only; no shop, interior system or interactive controls.
- Side terraces: survey drones on docks and a few specimen pods. Reuse the prior teal utility kit only in a small maintenance nook if it fits; it must not dominate the garden.
- Broad central catching field. Place plant/rock clusters at the edge, not everywhere the mockup scatters them. Keep cosmic warning circles readable.
- One main entry between two stout research pillars, existing functional board beside it. Do not copy the simplified mockup board over our themed live board.
- Cosmic sky, floating distant islands, particles and orbit animation are later atmosphere work. Do not change global Lighting/Sky or introduce new gravity/damage mechanics.

## Existing coordinate/gameplay contract — verify before editing

Region ID `orbit_outpost`, element `Cosmic`, index 6, unlock 1,000,000 coins.
MapBuilder uses angle `90 + 60*(index-1)` = 390 degrees, centre `polar(280,390)` approximately (242.487,0,140). Read current source instead of hard-coding the world position.
Radius 75; SpawnRadius 44; AccessRadius 78; ground top y=0.30.
RegionScenery builds with `frame=CFrame.lookAt(centre, Vector3.new(0,centre.Y,0))`.
Local -Z faces the entrance/hub, +Z is rear, +X is image left when entering, -X image right. Apply the region frame ONCE.
Gate is local z=-80, 20x12x2. Keep Gate, Entrance, UnlockPrompt, Wild, RegionId, Element, Centre, tags and access behavior.
Board frame is near local (24, RegionSign.height("Cosmic"), -90); inspect actual dressed bounds and retain all live labels.
Current generic Cosmic SceneryVersion is 2. Introduce a dedicated version 3 build and update only relevant test expectations.
Preserve Gravity Pulse hazard and its telegraphs, pull mechanics, timers and radii from Config.Capture.

## Layout and safety constraints

1. Keep radius 44 entirely free of solid scenery, with an open flat catching field extending roughly to radius 53. Major decor starts beyond radius 54; check whole oriented footprints, including tilted/rotated corners.
2. Keep the approach corridor at least 20 studs wide, aligned through the existing gate. No prop, beam, grass cluster or boulder obstructs the board, gate or nearby roads.
3. Continuous containment around radius 75 with overlapping collision cores and gate shoulders. Energy panes alone must not leave gaps; use deliberate invisible collision proxies or solid cores independent of replaceable art. Make decorative energy panes CanQuery=false so capture rays stay predictable.
4. Separate Boundary, Walkways and Landmarks. Permanent floor, ramps, terraces, barriers and safety rails must remain intact when placeholders are removed. Avoid ground voids, unjumpable lips, z-fighting and accidental routes over locked gates.
5. Aim for no more than 650 base parts and 6 PointLights; measure actual totals. Reserve most visual detail for meshes. Use broad low-poly shapes, not hundreds of wedges to imitate the final plants.
6. All decorative placeholders anchored, CanCollide=false, CanTouch=false, CanQuery=false. Collision proxies are separately named and documented.
7. Test complete oriented prop/placeholder bounds against all relevant Workspace.Map.Path segments with at least 2 studs edge clearance, including the Crisis arena spur. Do not rely on center checks or raycasts that miss non-queryable decor.
8. Preserve the board's actual bounds and visibility rays. Reuse existing board tests rather than disabling them.
9. No camera/character movement without an existing playtest need; stop Play before editing source, Rojo-sync and verify Source before runtime testing.
10. Use a muted lunar ground material/color scoped ONLY to Cosmic; the ground skin must preserve known collision height and hazard readability.

## Proposed layout anchors

These are region-local planning centers, not world positions. Adjust only if measured safety/support requires it and record the final result.

- Gravity dais centered (0, surfaceY, 63), about 23 wide x 19 deep, top about y=5. Its nearest substantial footprint stays beyond the protected field. Access, if provided, runs tangentially around the back perimeter rather than down through the capture field.
- Cradle at dais center, base bottom y=5. Meteor aligned over the cradle with its bottom y=12 (7 above cradle bottom); final top y=23, safely within cradle top y=27. Orbit stones at roughly x=+/-5.5, y=15, z=63, avoiding prongs.
- Lab center approximately (56, surfaceY, 25), bottom around y=2 on a permanent pad. Base and dome share exact XZ center and yaw. Dome bottom is base bottom+5. Match the 16-stud diameter shell to a permanent floor/blocked interior.
- Survey docks around (-57, surfaceY, 15), (54, surfaceY, -23), (-42, surfaceY, 46); adjust terrace footprints to keep radius 44 clear.
- A modest utility nook around (-53, surfaceY, -35), only if all bounds fit. The existing Thunderworks meshes are optional future placements, not part of the OO kit.
- Sparse crystal/mushroom/fern groups between r=55 and r=70, with tall growth clustered near terrace backs. No mushrooms outside the entrance on shared roads.

## Exact Codex asset envelopes

**Kit status:** all 15 meshes are now built and FBX reimport-validated in `assets/orbit-outpost/props-v1/` (12,388 triangles total). Read `manifest.json`, `preview.png` and README there. Dimensions below are final. No meshes have been uploaded or integrated yet; proceed with the base and placeholders now.

All are one static mesh per asset, one palette material. Dimensions below are Roblox X/Y/Z = width/height/depth in studs, at scale 1. Front is local +Z after FBX import. Every mesh uses a bottom-center authoring pivot, including floating assets. No animation, light, transparency or collision is assumed to transfer through FBX.

| AssetName | W x H x D | Role |
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

Target 35–55 deliberate sites, with only one cradle, meteor, lab base and lab frame; 3–4 docks/drones; a few suspended rocks; remaining garden dressing. The center stays spacious. Do not scatter to fill a quota.

The dome frame is open ribs, not a glass mesh: Claude owns a modest set of transparent glass panels or hemisphere for the base layout, independently named LabGlazing and kept during art replacement. Keep it visually compatible with a radius-8 dome rising 6.5 above the base. The lab is closed, so a nonwalkable interior is acceptable. Make glass non-queryable and avoid overlapping opaque dummy dome geometry.

Cradle geometry and meteor are separate meshes. Their suspended appearance is intentional static placement; never unanchor them. Future local orbit animation is Codex's later scope.

## Required asset sites and replacement contract

Under Landmarks create `PropSites`, containing a Model per site named uniquely (GravityCradle01, GravityMeteor01, etc.). Each has:
- `AssetName`: exact name above.
- `AssetSize`: Vector3 with exact table dimensions.
- `GroundCF`: REGION-LOCAL CFrame at the bottom center of intended mesh bounds; even a floating meteor uses its suspended lower extent here.
- `PivotMode = "BottomCenter"`.
- `CollisionRole = "none"`.
- `PlacementRole = "Grounded"`, `"Stacked"` or `"Suspended"`.
- `SupportPath`: actual permanent supporting part/model path for grounded/stacked assets, or a documented landmark anchor for suspended assets.
- Optional `StackOnSite` for lab dome/drone alignment.

Any visible stand-in goes ONLY inside each site's `PlaceholderArt` Model. Never place permanent collision or glass inside PlaceholderArt. Sites themselves remain when art is replaced. Set PropSites.AssetCount to actual count.

Placement for a native MeshPart with bounds-center CFrame is:
`mesh.CFrame = frame * site.GroundCF * CFrame.new(0, site.AssetSize.Y/2, 0)`.
Do not move the site to world coordinates or apply frame twice. Do not invent IDs or import/upload anything.
For lab/dock stacking, use measured support top heights, not bounding-box guesses on irregular geometry.

## Source and verification

Implement `OrbitOutpost.build(parent, frame, radius, makePart)` and delegate Cosmic from RegionScenery. Preserve its public interface and all existing region branches. Remove only the now-dead generic Cosmic builder once behavior is replaced. Add Cosmic to MapBuilder OWN_ENTRANCE only after your pillars fully replace the old trim.
Run current available lint, quote scan, stamp/build and relevant map tests; inspect tool commands before invoking. Validate containment, gate/sign clearance, full prop footprints/support, stack heights, finite CFrames, ground height, counts, protected capture radius and all road clearance. Validate existing capture hazards still work.
If Studio is unavailable, finish local/headless checks and explicitly list missing runtime/visual checks. Do not claim a game review or passing baseline without fresh results.

## Return deliverables

Save `docs/art/regions/2026-09-21-orbit-outpost/ORBIT-OUTPOST-LAYOUT.md` with:
- exact files changed and current Studio/sync state;
- actual local frames, support heights, dimensions, terrain/terrace/ramp data;
- full site table including AssetName, AssetSize, GroundCF (position AND yaw), PlacementRole and SupportPath;
- explicit permanent geometry vs replaceable art ownership;
- measured clearance/count results, test results and unresolved limitations;
- screenshot/top-down plan if available.

Update RELAY with fresh results while preserving concurrent asset notes.
Codex will then capture uploaded native meshes, normalize their dimensions using manifest.json, preserve MeshSize, configure import staging, replace only PlaceholderArt and place anchored meshes. Raw FBX galleries must never be left in Workspace during Play: earlier imports arrived oversized and unanchored. Wait for Codex's staging step before importing.

Proceed with the base region now.

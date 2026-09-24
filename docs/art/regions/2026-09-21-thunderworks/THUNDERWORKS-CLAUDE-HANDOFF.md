# Claude handoff: Thunderworks refinement

Build the playable base region now; Codex is building its reusable Blender props
in parallel and will import and place them after your measured layout is ready.
Do not wait for imported assets or implement their upload/placement yourself.

## Workspace and ownership

Work only in `C:\Users\nguye\Documents\repos\catch-a-catastrophe\CatchACatastrophe`, not the old
`orca\workspaces\Catch-a-Catastrophe` checkout. Read `AGENTS.md`, the newest
`RELAY.md`, and `docs/CONTRACTS.md`. Preserve unrelated dirty work.

- Claude owns `src/server/Map/Thunderworks.luau`, the narrow Storm delegation in
  RegionScenery, blockout collision/walking surfaces, matching tests, and the
  measured return document. Keep existing module interfaces.
- Codex owns `assets/thunderworks/`, `tools/blender/create_thunderworks_props.py`,
  `tools/blender/verify_thunderworks_props.py`, mesh templates and later placement.
  Do not modify these or shared Blender helpers. Do not insert fake asset IDs.
- Preserve Gusty atmosphere and all prior region assets, boards, access logic,
  cosmetics, purchases and other unrelated changes. No commits or publishing.
- Before writing RELAY/CONTRACTS, reread their current versions and make targeted
  edits so concurrent asset notes are retained.

## Art direction: storm-powered industrial yard

This is a written direction based on Thunderworks' existing identity: "An old
power yard where storm critters charge everything they touch." There is no
user-approved Thunderworks image yet. Do not claim a mockup was approved.

Make a chunky, weathered electrical works with a clear open asphalt catching
yard. Deep blue-gray concrete and graphite machinery frame copper coils, pale
ceramic insulators, muted teal cabinets and small worn yellow equipment accents.
Broad industrial silhouettes should read at a distance; detailed props belong
near the edge. Avoid turning the region into another rocky canyon or snow basin.

- Rear: a hero pair of lightning-collector towers, roughly 28-36 studs tall,
  on a substantial generator plinth. Broad copper ring silhouettes, porcelain
  necks and a static overhead bus identify the region. No actual lightning FX,
  flashing arcs, electrical damage or interaction is required in this pass.
- Image left/local +X: a short raised maintenance catwalk over a shallow, closed
  cable/service trench, connected to peripheral stairs at both ends. It should
  be a continuous optional walking route, not a dead-end platform.
- Image right/local -X: a small generator/control shed facade on a low service
  apron, with vent panels, sloped roof and a few warm windows. Closed facade
  only: no new shop, NPC, machine UI, usable controls or interior system.
- Boundary: continuous solid concrete retaining wall with grouped buttresses,
  inset metal panels and an uneven industrial skyline. Chain-link mesh alone
  cannot provide containment. Keep the main entrance as the only ground opening.
- Entrance: a stout steel portal tied to the existing gate, modest conduit and
  insulator details, no oversized beam obscuring the freestanding region board.
- Dressing: a few transformer groups, cable reels, insulators, cabinets, vents
  and capacitor units clustered at service pads. Keep the lawn/yard open.

Keep the atmosphere bright enough to read gameplay. No global Lighting edits,
black fog, bright yellow floor stripes across the capture field, animated lasers,
spark storms or signs that compete with the existing functional board.

## Existing gameplay and coordinate contract

- Region ID `thunderworks`, element `Storm`, index 5, unlock cost 300,000.
  Preserve all economy/species/progression and the current Lightning hazard.
- Current region angle is 330 degrees, centre `polar(280,330)`, approximately
  `(242.487,0,-140)`; verify against MapBuilder rather than hard-code world values.
- Radius 75, SpawnRadius 44, AccessRadius 78, authored ground top y=0.30.
- RegionScenery supplies `frame = CFrame.lookAt(centre, Vector3.new(0,centre.Y,0))`.
  Build in this local frame and multiply through it once. Local -Z is the entrance
  toward the hub; +Z is rear; +X is image left when entering; -X image right.
- Main Gate sits at local z=-80, size 20 x 12 x 2. Preserve Gate, Entrance,
  UnlockPrompt, RegionId/Element/Centre attributes, tags and board text behavior.
- Board frame is near local `(24, RegionSign.height("Storm"), -90)`; read the
  actual board dimensions/height. Preserve the board and its stand exactly.
- Ring frame: `CFrame.new(sin(a)*r,0,-cos(a)*r) * CFrame.Angles(0,-a,0)`.
  Bearing 0 entrance, 90 image left, 180 rear, 270 image right; ring +Z is inward.
- Current Storm hazard: yellow circular Lightning warnings, telegraph 1.1 s,
  active 0.35 s, radius 3.5, base count 2, spawnRadius 10. Difficulty modifiers
  may add patches. Read Config.Capture and preserve actual behavior.

## Layout constraints

1. No solid scenery inside radius 44, measured using whole rotated footprints.
   Keep a broad matte flat field to about radius 56; normal props start beyond
   radius 58. Never place beams, wires or decorative silhouettes through the
   central aiming/capture space. Flat subtle scuff detail is acceptable.
2. Lightning's yellow warning circles must remain conspicuous against the floor.
   Do not decorate the field with yellow circles, neon seams or warning stripes.
3. Keep Boundary collision and Walkways separate from replaceable art. Preserve
   continuous overlapping wall/shoulder cores. Functional decks, stairs and
   rails must remain safe even when placeholder decoration is removed.
4. Catwalk target: 6-8 studs usable width, roughly 5-7 studs above ground, steps
   <=0.7 studs, continuous end connections and no gaps hidden by decorative art.
   Keep its full footprint outside the catching field. No new fall mechanic.
5. Contain landmark footprints within this region; do not reach into neighboring
   roads, cities, Frostbite or the relocated Crisis arena. Keep background masses
   modest; tower height does not authorize broad world expansion.
6. IMPORTANT: the Crisis arena is between Frostbite and Thunderworks. Frost's
   approach props previously landed on its spur. Test ALL approach decorations,
   including non-queryable meshes/grass and placeholder footprints, against
   every relevant `Workspace.Map.Path` with at least TWO studs of edge clearance.
   Test oriented bounds, not only centres or CanQuery raycasts. Leave nearby
   path edges, bollards, arena walls and the functional gate unobstructed.
7. Preserve board clearance: zero overlap with its actual box and all 27 existing
   sign visibility rays clear. Entrance beams must leave generous headroom.
8. Decoration defaults to anchored, CanCollide/CanTouch/CanQuery false. Collision
   proxies remain explicit and documented. Avoid coplanar top surfaces/z-fighting.
9. Target <=700 blockout parts, <=6 PointLights and restrained geometry density.
   Measure actual totals. Use a small number of broad forms, not hundreds of bolts.
10. Do not add ambient effects or change Gusty's local atmosphere. The later
    Thunderworks atmosphere pass can address machinery/wind/audio separately.

## Reusable Blender kit being built by Codex

**Kit status, 2026-09-21:** all eight props are now built and reimport-validated in
`assets/thunderworks/props-v1/`. Read `preview.png`, `manifest.json` and README
there. Final exported bounds match the table below exactly; proceed with these
placeholders. Assets have not yet been uploaded to Roblox.

The following names and final target dimensions are the shared contract. Codex
will normalize the exported mesh bounds to these envelopes. Use these sizes now;
verify against `assets/thunderworks/props-v1/manifest.json` once it appears.
All assets are static, textured, ground-centre origin, one MeshPart per asset.
Facing front in Roblox is local +Z (inward when placed in the ring frame).
No scripts, prompts, lights or physics in FBX.

| AssetName | W x H x D studs | Use |
|---|---|---|
| TW_Transformer | 5.8 x 6.2 x 4.6 | Peripheral transformer equipment pads |
| TW_Ceramic_Insulator | 1.8 x 3.0 x 1.8 | On equipment plinths/portal ledges |
| TW_Cable_Reel | 4.0 x 4.4 x 3.0 | Service yard/shed/catwalk ends |
| TW_Capacitor_Bank | 3.4 x 4.8 x 3.4 | Rear generator supports |
| TW_Switch_Cabinet | 3.2 x 4.6 x 1.8 | Against service shed/wall, facade only |
| TW_Vent_Housing | 4.0 x 2.4 x 3.4 | Low service pad/roof equipment |
| TW_Conduit_Elbow | 3.0 x 2.5 x 2.2 | Low utility pad dressing, not a walkway |
| TW_Storm_Bollard | 1.2 x 3.0 x 1.2 | Sparse pad-edge accents, keep roads clear |

Aim for about 24-36 deliberate placements using all eight assets; do not fill
space simply to reach that count. Keep props on measured surfaces. Avoid stacking
until support heights are known. These are decorative equipment models: no new
gameplay controls or promises of usable buttons. The large collectors, shed,
catwalk, portal and boundary panels are a fitted-art pass AFTER your layout.

## Required replacement structure

Create `Boundary`, `Walkways`, and `Landmarks` under the region. Inside Landmarks
use `PropSites` with one Model per reusable prop, e.g. `TransformerSite01`.
Each site needs:

- `AssetName` string matching the table exactly.
- `AssetSize` Vector3 matching its full intended bounds.
- `GroundCF` CFrame in REGION-LOCAL space at the bottom centre of its support.
- `CollisionRole = "none"` for this ground-supported kit.
- Optional `SupportPath` identifying a permanent supporting surface.

Set PropSites.AssetCount to the exact site count. Art placement is
`frame * GroundCF * CFrame.new(0, AssetSize.Y/2, 0)`. Give any vertical/hanging
future landmark a separate documented pivot convention; do not mix conventions.

Every larger landmark needs its own named submodel, local frame, target bounds,
and explicit replaceable art vs permanent collision list. Record tower bases,
roof pitch, catwalk endpoints/deck heights/width, stair tops, portal opening,
wall segment frames, and bus/conduit attachment points. No nearest-neighbour
guessing should be necessary when Codex returns with fitted meshes.

## Source changes and validation

- Add `Thunderworks.build(parent, frame, radius, makePart)` and delegate Storm
  from RegionScenery. Remove only dead Storm branches/palette data. Preserve
  Cosmic output exactly and do not rewrite other regions.
- Read MapBuilder's OWN_ENTRANCE logic; include Storm only if the new portal fully
  replaces its old industrial trim. Keep gate/sign/access objects intact.
- Storm currently has SceneryVersion 2; stamp the new layout 3 and update the
  Storm expectation in TestHarness. Do not disable existing checks.
- Stop Studio Play before source edits, then Rojo-sync and read back Source.
  No Studio-only Source patches. Do not move the user's character/live camera.
- Run `python tools/luau_lint.py src`, `python tools/quote_scan.py`,
  `python tools/stamp.py`, `rojo build -o build/Thunderworks.rbxl`.
- Current baseline: 941 SelfTest / 72 LiveTest, zero failures. Run fresh startup
  if Studio is available; report actual results, including any tests added.
- Measure containment continuity, solid field intrusion, board box/rays, road
  clearance, reachable stairs/decks, prop support, finite CFrames, part/light
  counts and unchanged Cosmic output. Check Lightning warning readability.
- If Studio is unavailable, finish local/headless checks and state precisely
  what remains unverified. Do not claim an in-game review you could not perform.

## Return to Codex

Save `docs/art/regions/2026-09-21-thunderworks/THUNDERWORKS-LAYOUT.md` with measured
built dimensions, heights, local frames, complete asset-site table, collision
ownership, road/board clearances, landmark contracts, and validation results.
Include a simple top-down plan and screenshots if available. Update RELAY with
files changed, exact test results, limitations, Studio state and publishing state.

Codex will then capture real uploaded native meshes, preserve MeshSize, normalize
import scale, register ThunderworksPropsBundle with ImportStaging, and place the
assets. Keep the layout functional and visually coherent while those assets are
still placeholders.

# Claude handoff — Frostbite Peaks V2: Alpine Expedition

**User-approved direction:** V2 Alpine Expedition, selected 2026-09-20.
**Your task:** implement the playable base region and clearly named asset
placeholders. Codex is building the Blender art and will import and place it
after your layout is finished. Do not wait for those assets to build the base.

## Project and reference

Work only in `C:\Users\rahul\orca\Catch-a-Catastrophe`.
Do not use the older `orca\workspaces\Catch-a-Catastrophe` checkout.
Read root `AGENTS.md`, newest `RELAY.md`, and `docs/CONTRACTS.md` first.

Approved image, open and inspect it:

`C:\Users\rahul\orca\Catch-a-Catastrophe\docs\art\regions\2026-09-20-concepts\frostbite-peaks-v2-alpine-expedition.png`

The image shows a broad snow field within sculpted snowy mountain walls, a
jagged rear mountain ridge, a short rope bridge over a frozen cascade on the
image's left, and a cozy timber expedition hut on the image's right. The hut
has a teal roof, thick snow cap and warm windows. Snowy firs, trail fences,
lanterns and supplies dress the perimeter. A timber entrance arch connects
the green shared overworld to the snow field.

Treat the image as an art direction, not exact dimensions. Distant mountains
are backdrop inspiration, not a request for a giant terrain expansion.
Do not introduce V1's giant ice arch or V3's crystal/aurora theme.

## Split of responsibilities and concurrent work

**Claude owns:** Frostbite base layout, collision, walkable routes, simple
placeholder landmarks, integration into RegionScenery, relevant tests, and the
measured layout handoff. You may make the narrow MapBuilder gate-frame change
needed to replace Frost's industrial trim with the timber entrance.

**Codex owns:** `assets/frostbite-peaks/`, Frost-specific Blender scripts,
custom meshes/textures, later Roblox import/templates and asset placement.
Do not edit those asset files or the shared Blender generators while Codex works.
Do not add mesh IDs, fake imported assets, or upload code to the blockout.
Do not modify Gusty/Splashwater/Cinder assets or their placement modules.

Codex has built and validated eight independent reusable props. The local kit
is in `assets/frostbite-peaks/props-v1/`; see `preview.png` for appearance and
`manifest.json` for exact exported dimensions. They are not imported into Roblox
yet. The table below gives the initial planning envelopes; use the manifest
when exact clearance matters.

| Planned mesh name | Approximate starting envelope (W x H x D studs) | Your placeholder role |
|---|---|---|
| FP_Snow_Rock_Wide | 5 x 2.5 x 3.5 | SnowRockWide |
| FP_Snow_Rock_Tall | 3.5 x 4.5 x 3 | SnowRockTall |
| FP_Snow_Fir_Tree | 5 x 9 x 5 | SnowFirTall |
| FP_Snow_Fir_Sapling | 3 x 5 x 3 | SnowFirSmall |
| FP_Snow_Drift | 5 x 1.1 x 3 | SnowDrift |
| FP_Icicle_Cluster | 3.5 x 2 x 0.8 | IcicleCluster (hung under ledges/eaves) |
| FP_Supply_Crate | 2.5 x 2.5 x 2.5 | SupplyCrate |
| FP_Rope_Coil | 2.4 x 0.5 x 2.4 | RopeCoil |

These dimensions are a starting art budget; the generated asset manifest will
record exact dimensions. Use sensible uniform scale for trees, crates and rope;
do not force narrow distorted silhouettes just to hit an arbitrary box.
Meshes have ground-centre authoring origins; imported MeshParts use box-centre
CFrames. Hanging icicles need top-of-bounds alignment when placed.

**Fitted production art comes after your measured layout:** modular mountain
cliff faces/snow cornices, peak silhouette, hut shell/roof, timber entrance,
bridge rail/deck dressing, stairs and frozen cascade. Build convincing simple
placeholders for these now; record exact dimensions and anchors for Codex.

## Existing code and coordinate contract

- New module: `src/server/Map/FrostbitePeaks.luau`.
- Follow `CinderCanyon.build(parent, frame, radius, makePart)` and its grouping
  approach. Keep the RegionScenery public interface unchanged.
- Add a Frost delegation in `src/server/Map/RegionScenery.luau`; remove only dead
  Frost branches/palette entries from that generic builder. Preserve Storm/Cosmic.
- Existing region ID `frostbite_peaks`, element `Frost`, unlock cost **75,000**.
  Do not change economy, species, encounters, progression or hazard behavior.
- Radius **75**, SpawnRadius **44**, AccessRadius **78**. Centre is
  `polar(280,270)`, approximately `(0,0,-280)` in current layout.
- Frame supplied by RegionScenery:
  `CFrame.lookAt(centre, Vector3.new(0, centre.Y, 0))`.
- Local `-Z` points toward the hub/entrance; `+Z` is rear. When looking into the
  region from the gate, local `+X` is image LEFT, local `-X` is image RIGHT.
- Gate is local `z=-80`. Existing board is local `x=24,z=-90`, with Y from
  `RegionSign.height("Frost")`. Keep its placement and live text intact.
- Current ground top is local **y=0.30**: MapBuilder's disc helper receives a
  top position and subtracts half thickness internally. Verify this in source;
  do not treat the supplied disc position as its centre.

For perimeter placement, use/document a consistent ring frame:

```lua
local function bearing(deg, r)
    local a = math.rad(deg)
    return CFrame.new(math.sin(a)*r, 0, -math.cos(a)*r)
        * CFrame.Angles(0, -a, 0)
end
```

Bearing 0 is entrance, 90 image-left, 180 rear, 270 image-right. Within this
ring frame +Z points inward. Convert through the region frame only once.

## Gameplay and layout requirements

1. Maintain a continuous solid perimeter and gate shoulders, with the existing
   main entrance as the only ground-level opening. A pretty cliff face is not
   a replacement for collision containment. Preserve server-side region access.
2. Keep radius **44 completely free of obstacles**, including scenery footprint
   corners, and keep a broad flat matte field to about radius **56**. Put normal
   props and landmark bases outside radius **58**. Any necessary stair exception
   must stay outside the spawn field and be explicitly measured/documented.
3. Central snow should be softly blue-gray/off-white, not emissive or blinding.
   No cracks, slippery physics, open lakes, glowing patterns or solid drifts in
   the catching field. Low-contrast, non-queryable flush detail is acceptable.
4. Frost's Ice Wave is a moving line: length 11, width 2, travel 30 studs,
   telegraph 1.2s, active 1.8s. Keep its cyan warning/attack readable against the
   snow. Do not copy Cinder's eruption-specific radial assumptions or change the
   hazard to fit the art. Verify current capture configuration and behavior.
5. Rear ridge should create the main silhouette, with layered low-poly peaks,
   slate faces and thick irregular snow caps. Use a modest number of broad
   masses; roughly 30–45 stud peaks are a reasonable starting scale. Fit their
   footprints to this region and keep adjacent region routes clear.
6. Image-left: a short functional timber rope bridge connecting peripheral
   ledges over a shallow frozen cascade/crevice. Use walkable anchored deck
   collision and accessible stairs at both ends. Suggested bearing sector
   85–145; choose final positions to fit the footprint. Bridge visual ropes and
   posts are replaceable art. No new falling/damage/swimming mechanic.
7. Image-right: a small expedition hut on a peripheral terrace, with a short
   approach stair, tiny porch, warm windows and teal roof. Suggested bearing
   sector 220–255. A starting hut envelope around 16–20 wide by 14–18 high by
   12–16 deep is appropriate; keep terrace footprint out of the field. Facade
   dressing only: no shop, NPC, quest or interior system required. The closed
   door must not promise a new usable interaction.
8. Include a safe peripheral walking route/overlook, not a second elevated
   arena. Treads should have small predictable risers (target <=0.7 studs),
   continuous surfaces and enough width for a player. Check transitions and
   overlapping faces; do not bridge gaps only with non-colliding art.
9. Build the timber entrance arch at the existing gate. Keep Gate, UnlockPrompt,
   Entrance, tags and region attributes untouched. Exclude Frost from the old
   industrial gate trim in MapBuilder if necessary. Ensure generous headroom.
   The mockup's hanging name plaque is decorative; the existing freestanding
   functional board stays beside the gate, clear of posts, snow and branches.
10. Sparse snow fir groups and small expedition props should frame landmarks,
    with deliberate open space. Place lanterns near hut/entrance/bridge only;
    avoid dense lights/particles or global lighting changes. Reuse current region
    ambience. No changes to neighboring regions or the hub.

## Structure and replacement anchors

Create three clearly named children of the region:

- `Boundary`: continuous containment, shoulder cores and permanent solid bases.
- `Walkways`: floor skin if needed, stairs, terrace slabs, bridge collision deck.
- `Landmarks`: replaceable visible meshes/placeholder art. Solid decorative rock
  proxies may remain here only if marked/documented to be retained beneath art.

Use coherent per-landmark submodels with unique names/indices, for example
`AlpineHut`, `HutTerrace`, `RopeBridge`, `FrozenCascade`, `RearPeak01`,
`TreeSite01`, `SnowRockSite01`. Each asset site should expose a stable local
placement CFrame (attribute or Attachment), target dimensions and collision role.
Name the removable art distinctly from permanent collision. Document any nested
structure so Codex need not infer grouping by nearest-neighbor matching.

At minimum provide named sites for all eight props above, plus hut, bridge,
cascade, peak, gate and reusable cliff/snow-cap segments. Assets should sit on
surfaces, not float or sink through them. Use anchored parts throughout.
Decoration should normally be CanCollide/CanTouch/CanQuery false; collision cores
should match intended movement. Avoid degenerate CFrame.lookAt for vertical
beams: provide a nonparallel up vector as in the corrected Gusty helper.

## Scope, workflow and required checks

- Preserve all unrelated uncommitted work; no commits or experience publishing.
- Stop Studio Play before changing scripts if a Studio connection is available.
  Rojo-sync and read back Source before Play. Never patch Source only in Studio.
- Keep the imported-asset protection in `Map/ImportStaging.luau` intact. Raw FBX
  galleries were previously unanchored at 100x scale and fell onto the map.
  Claude should not import assets. Codex will later register the Frost bundle
  with this protection before any import/placement work.
- Give Frost a new SceneryVersion (3 is unused for this region at handoff) and
  update its expected version in TestHarness. Do not disable safety assertions.
- Run `python tools/luau_lint.py src`, `python tools/quote_scan.py`,
  `python tools/stamp.py`, and `rojo build -o build/FrostbitePeaks.rbxl`.
- In Studio, run normal startup tests; the handoff baseline is **935 SelfTest
  and 72 LiveTest**. Report actual results and any tests added. Avoid invoking
  harness.run from an isolated MCP require cache without initialized services;
  that previously produced a spurious missing-service failure.
- Inspect the full region and ground-level entrance/bridge/hut approaches.
  Check board rays, zero solid intrusion into SpawnRadius, continuous barrier,
  actual stairs/bridge continuity, finite transforms, and ice-wave visibility.
  Do not teleport the user's player or hijack their live camera; use an isolated
  Edit preview or test fixture where appropriate.
- If Studio is unavailable, complete local/headless validation and explicitly
  identify unverified runtime checks. Do not claim an in-game review occurred.

## What to deliver back to Codex

1. Working source blockout and narrow integration changes described above.
2. **Measured** layout document saved as
   `docs/art/regions/2026-09-20-concepts/FROSTBITE-PEAKS-LAYOUT.md`.
   Include coordinate frame, actual floor/terrace heights, landmark local
   CFrames, footprints and bounds, bridge endpoints, deck top/width/span,
   stair dimensions, hut facade/door/roof envelopes, cliff segment dimensions,
   placeholder paths/counts, tree/prop site tables, and which collision survives
   asset replacement. Read values from built geometry when possible.
3. A simple top-down plan and screenshots if available. Include a list of any
   visual compromises or deviations from the approved V2 reference.
4. Test results, part/light counts, unresolved risks, Studio state and publishing
   state in a new RELAY.md checkpoint. Preserve concurrent/newer asset notes.

The blockout should already look recognizably like Alpine Expedition using
simple Roblox geometry. Codex's next pass replaces and dresses those forms with
the custom Blender kit; it should not have to redesign your gameplay layout.

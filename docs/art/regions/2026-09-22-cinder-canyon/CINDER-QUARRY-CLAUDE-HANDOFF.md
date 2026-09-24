# Claude handoff — approved Cinder Quarry

The user approved **option 03 / Cinder Quarry**. Implement the base region while Astra creates the custom Blender assets specified below. Keep this document as the shared placement/asset contract.

## Authoritative files

- Reference image: `C:\Users\nguye\Documents\repos\catch-a-catastrophe\CatchACatastrophe\docs\art\regions\2026-09-22-cinder-canyon\cinder-canyon-v1-03-cinder-quarry.png`
- This handoff: `C:\Users\nguye\Documents\repos\catch-a-catastrophe\CatchACatastrophe\docs\art\regions\2026-09-22-cinder-canyon\CINDER-QUARRY-CLAUDE-HANDOFF.md`
- Asset delivery folder: `C:\Users\nguye\Documents\repos\catch-a-catastrophe\CatchACatastrophe\assets\cinder-canyon\quarry-v2`
- Expected bundle: `CinderQuarryBundle.fbx`. Check the folder's README/manifest for delivery status; file names in this contract do not imply an upload or Roblox asset ID.

Work in the current main repository above. Inspect existing source and live Studio before editing; do not overwrite newer work with stale source from a separate checkout. Respect AGENTS.md and use Rojo.

## Division of work

**Claude:** base floor, boundaries, existing gate connections, layout/site metadata, safe collision proxies, lava/light effects, spawning/capture integration and visual comparison.
**Astra:** the twelve custom Blender models below, palette texture, exports, attachment coordinates, previews and validation.

Do not create custom decorative replacement models or fetch substitutes. Reuse suitable existing assets and implement independent map work now. Make reserved asset sites invisible metadata holders with explicit bounds/base transforms, and identify missing art honestly. Do not call the scene visually complete until the custom pack is imported and placed.

Keep source changes out of Astra's assets/ folder and Blender scripts. Astra will not rewrite Claude's gameplay or base-map modules during parallel work.

## Scope and visual result

Rebuild Cinder Canyon only, preserving finished Gusty Gardens and Splashwater Bay, lobby/plots, Frostbite Peaks and all other gameplay. The previous Sculpted Ravine concept is superseded for this region.

Match the reference: flat warm orange canyon floor; a recessed timber mine entrance at rear-left; a short side rail and one ore cart; terraced quarry rock at rear-right with a small wooden hoist, crates, amber mineral pockets and a narrow lava cascade. Layered red sandstone and cacti frame the border. Most of the center and foreground remain open.

The mine, hoist, rails, cart and minerals are scenery. Do not add mining, cart riding, cave exploration or new progression. The arch, bridge and circular ravine route from the old design are not part of the selected design. Preserve any existing functional interaction while moving it to an appropriate position.

## Coordinate and layout contract

Retain the existing **280 wide × 200 deep** linear-chain cell. Use the actual RegionScenery local frame:
- +X = world west = image LEFT.
- +Z = north = Frostbite gate at the far edge.
- -Z = south = Splashwater entrance at the near edge.
- +Y up; current ground top is about 0.30, confirm before placing.

This local frame differs from ordinary east/north diagrams. All following values use it.

These are explicit initial production targets derived from the composition, **not claimed pixel measurements**. Fit the reference camera and compare the real render before adjusting them. Preserve the fixed asset bounds; if a placement must change, update the site table instead of stretching the mesh.

| Site | Asset | Bottom position X,Y,Z | Yaw |
| --- | --- | --- | --- |
| Mine01 | CC_Quarry_Mine | (87,0.30,66) | 0 |
| Rail01 | CC_Quarry_Rail | Mine01 × DoorBase socket × CFrame.new(0,0.02,-13) | 0 relative |
| Cart01 | CC_Quarry_Cart | Mine01 × DoorBase socket × CFrame.new(0,1.05,-16) | 0 relative |
| Terrace01 | CC_Quarry_Terrace | (-88,0.30,65) | 0 |
| Hoist01 | CC_Quarry_Hoist | Terrace01 × manifest HoistBase socket | 0 relative |
| Side rocks | CC_Quarry_Mesa_Large / Low | Border pockets, principally abs(X)=105–124 | Varied |
| Plants / crates | Corresponding meshes | Border and landmark forecourts | Varied |

Keep a **minimum 24-wide clear center lane**, X=-12..12, through Z=-100..100, with no rails, lava, plant collision, decoration or terrain steps. Respect existing gate openings, which may be wider. Blend the route into the same orange floor rather than drawing a separate paved road.

Target at least 65% open dry floor. Keep new solid props outside existing capture/hazard clearance envelopes; derive and test the actual spawn/hazard layout for the rectangular region rather than retaining an obsolete circular radius.

The mine footprint fits X=55..119 and Z=42..90. Its recessed front opening faces -Z. Rail runs southward from the delivered DoorBase socket; the cart sits ON that rail. Use that socket rather than the outer rock bounds so the rail actually meets the doorway. No rail across the centerline.

The quarry terrace fits X=-124..-52 and Z=37..93. Lava runs down its front/side notch and into a small rock-framed edge pocket. Position crystals at exposed rock faces. Keep the hoist fully on the shelf and its hanging load outside walking routes.

## Fixed asset interface — twelve meshes

Bounds are **Width X × Height Y × Depth Z**, in intended studs. Every asset has a horizontally centered base origin; forward is local -Z. All meshes are separate reusable assets.

| Name | W × H × D | Contents |
| --- | --- | --- |
| CC_Quarry_Mine | 64 × 42 × 48 | Layered sandstone butte, genuinely recessed opening, timber posts/header/braces, lantern housing. Rails/cart separate. |
| CC_Quarry_Terrace | 72 × 36 × 56 | Asymmetric stepped sandstone quarry with flat hoist shelf and lava channel. Hoist/crystals/lava separate. |
| CC_Quarry_Hoist | 20 × 22 × 16 | Small timber hoist, crossbeam, dark pulley/rope and hanging crate. Static decoration. |
| CC_Quarry_Cart | 11 × 8 × 14 | Rust-brown metal cart, four wheels and bright mineral load. |
| CC_Quarry_Rail | 12 × 1 × 26 | Short pair of dark rails on timber sleepers. |
| CC_Quarry_Mesa_Large | 27 × 22 × 21 | Layered polygonal sandstone stack for side/rear pockets. |
| CC_Quarry_Mesa_Low | 22 × 11 × 17 | Lower sandstone shelf for foreground borders. |
| CC_Quarry_Cactus_Tall | 9 × 17 × 7 | Ribbed branching cactus with small warm flower accents. |
| CC_Quarry_Cactus_Round | 7 × 6 × 7 | Round ribbed cactus cluster with flower accents. |
| CC_Quarry_Agave | 11 × 7 × 11 | Broad pointed blue-green succulent leaves. |
| CC_Quarry_Flowers | 6 × 4 × 6 | Small orange/yellow desert flower and foliage patch. |
| CC_Quarry_Crate | 6 × 6 × 6 | Reusable weathered timber shipping crate with braces. |

Use `manifest.json` sockets when delivered for HoistBase, lava lips/foot, lantern and any effect anchors. Sockets use asset-local XYZ coordinates from the base frame, after final authoring transforms. Do not infer them from rendered screenshot pixels.

Existing `assets/cinder-canyon/props-v1` and `CinderPropTemplates` include basalt rocks, ember crystals and small sandstone rubble. Reuse if they match the new art; old fixed circular placements must not leak into the new layout. Reuse existing barrel assets where suitable. Do not remove the old library simply to introduce the new one.

Palette: warm red/orange layered rock, lighter caps and darker horizontal seams, charcoal near lava, weathered medium-brown wood and dark iron, restrained amber/orange light, green cacti and blue-green agave. Bright readable daylight; no global lighting changes to hide mismatched geometry.

## Sites and integration

Create explicit asset-site records/holders with AssetName, bottom CFrame, target size or uniform scale, and optional protected collision/effect children. Keep placeholder art separate from functional boundaries/walkways. Do not use a whole Model bounding box that includes water/effects as the placement size.

After Studio import, preserve native MeshSize, MeshId, texture and SurfaceAppearance. New library name: `CinderQuarryTemplates`. Keep the old small-prop library alongside it. Validate the complete new library before atomically replacing art.

Native MeshPart CFrame is its bounds center, so use bottomFrame × CFrame.new(0,height/2,0) for base-centered meshes at their intended size. Do not double-apply the offset when using imported Model pivots. Import conversion can introduce a 100× scale; verify against the table.

Visible decorative meshes should be anchored with CanTouch/CanQuery disabled. Keep walking containment in deliberate collision proxies. Do not make the full mine/terrace/ore cart Neon to light a mineral or lantern. Use separate Roblox effect geometry/lights at supplied sockets, and animate lava separately from rock.

## Gates, gameplay and surfaces

Cinder entry remains **15,000 coins**. North destination is **FROSTBITE PEAKS / 75,000 COINS**. Use existing per-player, server-authoritative persistent unlock logic. Fade/open only for the eligible player; prevent border bypass.

Keep actual Heat creatures, population, income, capture behavior and hazard timings. Decorative lava does not authorize a new damage mechanic.

Preserve walkable floor height and ensure capture warnings render visibly above it. Do not lay a new thick ground skin over hazard telegraphs. Keep decorative cracks matte and shallow in playable areas; glow belongs to edge lava/minerals.

The image's white background/title is not game geometry. Snow above the north gate and water below the south threshold represent neighboring regions, not extra areas to build.

## Verification and completion

1. Fit a comparable elevated camera from south looking north using the gate piers/cell as known geometry; check the reference crop.
2. Capture the actual Studio region and compare side by side: mine/cart/rail alignment, terrace/hoist scale, rock strata silhouettes, cactus density, open-floor ratio, gate style and color palette.
3. Iterate on visible differences. Test at avatar height too.
4. Run relevant source checks/build/harness and test route clearance, creature spawning/capture, visible Heat telegraphs and both gate states. Explicitly report anything untested.
5. Deliver screenshots, changed files and remaining asset gaps. Running code and correct object names alone do not establish visual fidelity.

Astra is building the kit in parallel. Asset delivery and upload status will be recorded in the asset folder README; do not wait to implement independent layout/gameplay work, and do not fabricate missing IDs.

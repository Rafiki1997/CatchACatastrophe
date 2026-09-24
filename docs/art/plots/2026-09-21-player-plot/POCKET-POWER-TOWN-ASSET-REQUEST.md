# Pocket Power Town plot: measured layout, and the asset request for Astra

The player plot is rebuilt to the approved **Pocket Power Town** concept
(`plot-v2-pocket-power-town.png` beside this file). The layout was not
eyeballed: the concept's pad grid was detected in the image, a ground-plane
homography was fitted to it, and every landmark was measured back into plot
studs. Put `comparison-concept-vs-build.png` next to the concept to judge it.

Everything gameplay needs is finished in `src/server/Map/PlotTemplate.luau`.
Everything that should be sculpted art is a **named placeholder** built from
parts under `Plot_<n>.PropSites.<Site>.PlaceholderArt`, authored to the bounds
in `src/server/Map/PlotAssetSpec.luau`. When the kit is imported,
`src/server/Map/PlotProps.luau` swaps every placeholder for the native mesh,
all or nothing.

## 1. How the concept was measured, and how to reproduce it

The concept's four pad rows give 24 known ground points. Detecting the dark
socket panels and fitting a homography through the two unoccluded rows
reproduces the grid to **2.8 px**, and fitting a pinhole camera to the same
points converges to **1.5 px rms**:

| | |
|---|---|
| Camera | pitch **39.34 deg**, yaw **0.05 deg**, distance **85.0** studs, fov **43.76 deg**, aimed at the plot centre at eye height 0 |
| Frame | 1536 x 1024, matching the concept |
| Image left | plot local **+X** (the camera's right vector is forward x up, so +X lands left) |

**The concept image is cropped.** At that camera the plot's front kerb
(z = -29.3) projects to image y = 1074, below the 1024-pixel frame, and the
grass strip visible at the bottom of the concept sits at about z = -22. The
concept's plot is roughly 60 x 51; ours must stay 60 x 60, so the extra ~8
studs became the entrance strip in front of the plaza, built in the concept's
language (threshold bands, hazard chevrons, lantern posts).

## 2. Coordinate frame, pivot, facing

| | |
|---|---|
| Plot | 60 x 60 studs, `Platform` top at local **y = 0.5**; world grass at y = 0 |
| Local `-Z` | the front: the hub, the driveway, the entrance |
| Local `+X` | **image-left** walking in (dispatch booth, water tower) |
| Local `-X` | image-right (owner sign, workshop) |
| Pivot | **bottom-centre** of the bounds, at the site's `GroundCF` |
| Facing | the asset's front (door, counter, sign face) faces the site frame's **-Z** |
| Placement | `mesh.CFrame = plotCFrame * GroundCF * CFrame.new(0, AssetSize.Y / 2, 0)` |
| Collision | **none** on every mesh. Invisible colliders already stand where players must not walk |
| Rotated sites | a `GroundCF` yaw of 90 turns the asset's +X along the plot's +Z (side pipe runs and side planting) |

Export as the other kits do: Blender Z-up, -Y front, FBX Y-up, separate meshes
named exactly as below, one palette atlas, ground-centre origins, closed
manifold geometry. Deliver `PlotPropsBundle.fbx` (all twelve, gallery-spaced,
no plinths or labels) plus twelve individual FBXs under
`assets/player-plot/props-v1/` with `manifest.json`, `palette.png`,
`preview.png` and `validation.json`. `ImportStaging` already recognises a raw
`PlotPropsBundle` of exactly these twelve and anchors it into
`ServerStorage.RegionImportStaging`.

## 3. Palette (Color3.fromRGB, sampled from the concept)

| Name | RGB | Used on |
|---|---|---|
| PAVING | 146, 152, 176 | courtyard paving (built-in) |
| PAVING_LIGHT | 170, 174, 194 | apron, spawn landing (built-in) |
| PLAZA / PLAZA_LIGHT | 182,179,178 / 199,195,190 | coin plaza tiers |
| PAD_INSET | 104, 108, 128 | pad socket panels (built-in) |
| FRAME / FRAME_DARK | 176,180,198 / 150,155,176 | pad plate and its inner rebate |
| KERB | 214, 204, 186 | kerbs, post caps, planters |
| CREAM / SIGNFACE | 238,226,202 / 246,241,228 | booth cap, trims / sign face |
| TEAL / TEAL_LIGHT / TEAL_DARK | 42,108,128 / 70,150,166 / 30,80,98 | tank, kiosk, pipes, sign frame |
| NAVY | 46, 56, 72 | tower frame, railings, kiosk plinth |
| YELLOW / GOLD / GOLD_DARK | 244,196,72 / 250,212,88 / 206,156,58 | brackets and trims / coin |
| BRICK / BRICK_DARK | 152,88,66 / 124,70,54 | workshop, fence posts, sign plinth |
| ROOF_DARK / STONE / STEEL | 74,78,92 / 196,192,186 / 150,156,168 | roof, parapet, fittings |
| GLASS / LAMP / RED | 150,196,210 / 255,236,190 / 232,64,54 | windows / lantern glow / vent button |
| LEAF / LEAF_DARK / LEAF_LIGHT / TRUNK | 96,140,72 / 66,108,58 / 128,168,84 / 110,84,60 | planting |

Keep surfaces matte and mid-value: the game's bloom makes pure white glare.
Glow belongs only to the built-in strips, lanterns and vent button.

## 4. The twelve assets

Bounds are Roblox XYZ in studs, exactly the values in `PlotAssetSpec.luau`; the
importer rejects anything more than 0.005 off.

| Asset | Per plot | Bounds | Reference appearance | Constraints |
|---|---|---|---|---|
| `PP_Water_Tower` | 1 | 6.0 x 14.8 x 6.0 | Teal ribbed tank (dia 5.3, y 7.7..12.1) on four splayed navy legs with two brace rings and X bracing, yellow domed cap to 14.0 with a finial, cream cat mark on the front of the tank, teal downpipe down the rear into a stub | Legs must stay inside the invisible `TowerLeg` colliders at (+-1.5, +-1.5) from the pivot, 0.9 square, 7.6 tall. Leave the crown clear: the built-in `Windvane` spins at y 15.45 on the tower axis |
| `PP_Utility_Workshop` | 1 | 16.4 x 9.5 x 6.4 | Brick box (walls to 5.6) on a navy plinth with three darker courses, a stone end block on the -X third, stone parapet and cream lip to 6.45, dark flat roof with a steel unit, brick chimney at local (-6.5, +1.4) to 9.4, teal roller door at local x +2.2 in a cream surround, navy side door, one warm and one glazed window, cat plaque, two wall lanterns, and yard clutter (crates, blue toolbox, yellow bollard) | The front face must sit at local z = -2.75; the collider `WorkshopCore` is 15.4 x 5.8 x 5.5. Wall lanterns are lit by built-in PointLights at local (+0.2, 4.12, -3.23) and (+7.0, ...): model the heads there. Chimney smoke comes from a built-in emitter at local (-6.5, 9.9, +1.4) |
| `PP_Dispatch_Booth` | 1 | 10.8 x 6.9 x 9.4 | A rounded teal drum: navy plinth, teal sill to 2.55, a glazed band (y 2.6..4.5) of eight bays with cream mullions, cream head trim, cream brim / step / low dome to 6.4 with a yellow finial, a teal DISPATCH board over the front of the brim, a cream counter on the plaza side, a grey utility cabinet | The built-in `Console` screen is mounted on the -X face at local (-4.35, 3.05, 0), reading outward: keep that bay flat and glazed. The built-in `DispatchLabel` renders the word at local (0, 5.9, -4.52): make the board a plain teal face. The collider `BoothCore` is a cylinder dia 8.0, 4.4 tall. The vent pedestal is separate, outside the drum |
| `PP_Owner_Sign` | 1 | 12.4 x 7.8 x 4.2 | Brick plinth with a darker course and an ivory cap, stone end blocks, a teal board 11.0 x 3.4 crowned by a shallow arch rising 2.1, a gold rim following board and arch, gold corner posts with ball scrolls, a teal crest with a gold rim and a cream cat mark at the crown, hedges and blooms along the base | The frame is a **surround**: the built-in cream `Billboard` face (10.2 x 2.9, centre local (0, 3.35, -0.52)) carries the owner's name and income, and the arch's cream inserts continue it. Leave that opening clear. Collider `SignCore` 12.2 x 2.2 x 2.6 covers the plinth |
| `PP_Coin_Platform` | 1 | 7.4 x 0.9 x 7.4 | A gold coin: pale step dia 7.2, gold rim dia 6.5, coin dia 6.1, lighter face dia 5.2, a pressed cat mark on the top face | Stands on the functional `CollectPad` (8.4 x 0.34 x 8.4, top y 1.22), whose pale square reads as the inner tier |
| `PP_Pad_Frame` | 24 | 7.6 x 0.62 x 7.6 | A pale socket plate with a darker inner rebate and four **L-shaped** yellow corner brackets hugging the opening | The pad (5.4 x 0.6 x 5.4, top y 1.1) rises through the opening. The plate top must stay at **0.97** and the brackets at or below **1.04**: a work station's plinth sits at y 1.05 directly behind each pad. The built-in element `Strip` lies on the plate's front border at local z -3.22 |
| `PP_Lantern` | 12 | 1.1 x 1.25 x 1.1 | A warm glowing pane in a navy base and cap | Stands on a fence `PostCap` or a plaza pier cap. The PointLight is on the cap, not the mesh, so keep the glass the outermost piece |
| `PP_Pipe_Run` | 6 | 10.0 x 2.6 x 1.4 | A chunky teal main (dia 1.05, centreline 1.9 above the pivot) with two yellow flanges at +-3.4 and a navy stand and saddle | Rear runs thread the gaps between tower, workshop and corners; side runs are rotated 90 |
| `PP_Pipe_Elbow` | 3 | 1.4 x 2.9 x 1.4 | Teal ball joint on a riser with a yellow flange and a navy stand | Terminates a run |
| `PP_Shrub_Cluster` | 11 | 2.6 x 1.3 x 2.0 | Three rounded shrubs, two greens and a lighter one | |
| `PP_Flower_Bed` | 3 | 2.8 x 1.25 x 1.9 | Ivory planter with a stone lip, dark soil, pink / yellow / white blooms over foliage | |
| `PP_Round_Tree` | 4 | 8.2 x 10.2 x 8.2 | Chunky trunk (dia 1.3, 4.2 tall) with four overlapping rounded canopies | Stands on the world grass outside the plot (`GroundCF` y = -0.5) |

The region kits were checked first: `GG_Windbent_Tree`, `GG_Meadow_Shrub`,
`GG_Flower_Planter`, `TW_Conduit_Elbow`, `SB_Harbor_Barrel` and
`FP_Supply_Crate` belong to their biomes' palettes and silhouettes and do not
read as this teal-cream-brick town, so nothing was reused.

## 5. Measured site table

Positions are plot-local; yaw is about Y in degrees. Every site carries
`PivotMode = BottomCenter`, `CollisionRole = none`, a `PlacementRole` and a
`SupportPath`. `PropSites.AssetCount` is **68**.

| Site | Asset | GroundCF position | Yaw | Role | Support |
|---|---|---|---|---|---|
| `WaterTower` | `PP_Water_Tower` | (11.5, 0.5, 25.6) | 0 | Grounded | `Platform` |
| `UtilityWorkshop` | `PP_Utility_Workshop` | (-9.2, 0.5, 26.4) | 0 | Grounded | `Platform` |
| `DispatchBooth` | `PP_Dispatch_Booth` | (20.0, 0.5, -19.0) | 0 | Grounded | `Platform` |
| `OwnerSign` | `PP_Owner_Sign` | (-21.0, 0.5, -19.0) | 0 | Grounded | `Platform` |
| `CoinPlatform` | `PP_Coin_Platform` | (0, 1.20, -18.0) | 0 | Stacked | `CollectPad` |
| `PadFrame_1..24` | `PP_Pad_Frame` | (x, 0.52, z): x = -20 + 8(c-1), z = -6 + 8(r-1), index (r-1)*6 + c | 0 | Grounded | `Platform` |
| `Lantern_1..2` | `PP_Lantern` | (+-6.9, 3.80, -13.4) plaza rear piers | 0 | Stacked | `PlazaPierCap` |
| `Lantern_3..4` | `PP_Lantern` | (+-6.9, 2.96, -23.0) plaza front piers | 0 | Stacked | `PlazaPostCap` |
| `Lantern_5..12` | `PP_Lantern` | (+-29.3, 4.42, +-29.3) corners, (+-29.3, 4.42, 0) sides, (+-11, 4.42, -29.3) entrance | 0 | Stacked | `Fence/PostCap` |
| `PipeRun_1..3` | `PP_Pipe_Run` | (20.0 / 3.6 / -22.6, 0.5, 27.6) | 0 | Grounded | `Platform` |
| `PipeRun_4..6` | `PP_Pipe_Run` | (27.2, 0.5, 6.0), (27.2, 0.5, 16.2), (-27.2, 0.5, 16.2) | 90 | Grounded | `Platform` |
| `PipeElbow_1..3` | `PP_Pipe_Elbow` | (25.4, 0.5, 27.6), (27.2, 0.5, 0.4), (-27.2, 0.5, 10.6) | 0 | Grounded | `Platform` |
| `Shrub_1..8` | `PP_Shrub_Cluster` | (+-27.0, 0.5, z) along both side fences | 0 | Grounded | `Platform` |
| `Shrub_9..11` | `PP_Shrub_Cluster` | (16.2, 0.5, 26.6), (-19.4, 0.5, 26.6), (0.2, 0.5, 22.6) | 0 | Grounded | `Platform` |
| `FlowerBed_1..2` | `PP_Flower_Bed` | (26.9, 0.5, -10.0), (-26.9, 0.5, -15.0) | 90 | Grounded | `Platform` |
| `FlowerBed_3` | `PP_Flower_Bed` | (8.2, 0.5, 22.6) | 0 | Grounded | `Platform` |
| `Tree_1..4` | `PP_Round_Tree` | (+-37, -0.5, 30), (+-38, -0.5, -16) | 0 | Grounded | `Map/Ground` |

## 6. What the plot already is (permanent geometry)

| Element | Where |
|---|---|
| Kerb line | 29.3 on all four sides, ivory, top 1.25; entrance gap x -10.6..10.6 with flush threshold bands and hazard chevrons on the flanking kerbs |
| Pads | 24 on the documented grid, tops 1.1, dark slate, each with a front `Strip` that glows in the creature's element colour when occupied |
| Fence | 17 brick posts with ivory caps, navy top and middle rails and pickets between them |
| Coin plaza | three tiers at (0, ., -18) with an ivory rim, the `CollectPad`, four inset warm bars and four corner dots, brick rear piers and stone front piers with lanterns, hazard chevrons down both flanks, two treads down at the front |
| Vent | red domed button on a hazard-striped plinth at (16.4, ., -23.1), reachable from the forecourt |
| Banners | cream boards on navy posts at (+-27.6, 5.5, -4) facing the pads; rear board at (-23.2, 4.7, 26.4) |
| Lights | 12 lantern PointLights, 2 workshop wall lamps, plus 2 tier-2 SpotLights |
| Decoration tiers | hidden until bought: 1 upper pipe rack, valves, crates, barrels; 2 strung lights, workshop floodlights; 3 rooftop turbine, entrance bunting, auxiliary tank |
| Milestone rewards | bunting over the forecourt (0, ., -10.5); smiling billboard (3.0, ., 21.0) and golden statue (-2.2, ., 27.2) in the rear strip; pipe fountain (14.0, ., -12.0); neon sign (-14.0, ., -12.0) |

## 7. Measured on the built model

Headless, `PlotTemplate.build` at the identity frame:

| | |
|---|---|
| Parts per plot | **921** (266 permanent, 585 placeholder art, 70 hidden tier parts) |
| Lights / GUIs / prompts / emitters / sites | 16 / 31 / 24 / 1 / 68 |
| Intrusions into the 24 work-station boxes and 38 circuit-machine boxes | **0** |
| Visible parts sharing a top plane (z-fighting) | **0** beyond the Platform/Apron seam, which the threshold covers |
| Decoration slots (`DecorSlots.compute`) | **8** |
| `tools/verify_plot_props.luau` | **709 checks pass** |

## 8. What remains dependent on delivery

- The stand-ins hold the silhouette but are faceted: the tank's dome, the
  kiosk's shell, the sign's arch, and all planting are stepped where the
  concept is smooth. Those four are the biggest wins from real meshes.
- The mesh swap also collapses **585 placeholder parts per plot into 68
  MeshParts**, taking a plot from 921 parts to about 400. At six plots that is
  the difference between ~5,500 and ~2,400 parts, so the kit is the part-budget
  fix as much as the fidelity fix. Mobile frame time is unmeasured either way.
- After import: capture native templates to
  `src/server/Map/PlotPropTemplates.rbxm` (preserve `MeshSize`), record IDs in
  `assets/player-plot/props-v1/roblox-import.json`, stage the raw gallery, boot,
  read `[SelfTest]`, and retake the comparison render.

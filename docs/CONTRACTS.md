# Catch a Catastrophe! — Module Contracts

This file is the single source of truth for every interface between modules.
Implementers of one module read THIS, not the other modules' source.

Project: Rojo (`default.project.json`). `src/shared` → `ReplicatedStorage.Shared`,
`src/server` → `ServerScriptService.Server`, `src/client` → `StarterPlayer.StarterPlayerScripts.Client`.
Files are `.luau`, `--!strict` at the top, tabs for indentation, Roblox Luau.

Spec: `docs/superpowers/specs/2026-09-06-catch-a-catastrophe-spec.md` (the binding authority).
Plan: `docs/superpowers/plans/2026-09-06-catch-a-catastrophe.md`.

Vocabulary: **creature** (a caught disaster), **species** (one of 24), **wild** / **encounter**
(a roaming, catchable creature), **pad** (work pad on a city plot, 1..24), **plot** (a player's city),
**pair / circuit** (two connected adjacent pads), **relaunch** (rebirth), **surge** (region's forecasted
Legendary window), **crisis** (the hub event).

---

## 1. Shared configuration (`ReplicatedStorage.Shared.Config`) — DONE

```lua
local Config = require(ReplicatedStorage.Shared.Config)
Config.Regions.list / .byId[id] / .byElement[element] -- { id, name, element, index, baseIncome, unlockCost, color, groundColor, desc, hazard }
Config.Regions.elements, .legendaryInterval (480), .surgeDuration (90), .populationCap (6), .respawnDelay {min,max}, .elementColor(element)
Config.Rarities.order / .info[r] = { rank, label, icon, color, weight, mult, captureSeconds, hazardSpeed, attackInterval, sellSeconds, glow, broadcast }
Config.Rarities.rank(r), .color(r), .label(r) -- "★ Rare"
Config.Species.list / .byId / .byRegion[regionId] / .byElement[element] -- { id, name, region, element, rarity, desc, silhouette, palette{primary,secondary,accent}, anim, animSpeed, height, job, difficulty }
Config.Species.count (24), .tutorialSpecies ("breeze_bean"), .find(regionId, rarity), .baseIncome(id)  -- regionBase x rarityMult
Config.Variants.order / .info[v] = { mult, label, icon, color, material?, tint?, tintAmount, particles?, rainbow, glow }; .prismatic {circuitMinutes=30, perfectCaptures=3}; .mult(v); .isValid(v)
Config.Circuits.list / .byId / .recipe(elemA, elemB) -> CircuitDef? -- { id, name, elements, desc, hint, color, machine }
Config.Circuits.baseBonus (0.25), .upgradedBonus (0.40), .upgradeCostSeconds (120), .upgradeMinCost (500), .overdrive {activeSeconds=20, cooldownSeconds=15, multiplier=2, ventHoldSeconds}
Config.Circuits.grid {cols=6, rows=4}, .maxPads (24), .padCoords(pad) -> col,row, .areAdjacent(a,b), .pairKey(a,b) -> "3-4", .parsePairKey(key)
Config.Capture.tetherRange (18), .tetherRangeCap (30), .outOfRangeGrace (1), .hitPenalty (1, must stay below every rarity's attackInterval / hazardSpeed), .knockback (16, below tetherRange), .wallHeight (3, feet above clear Gust / Ice Wave), .encounterLifetime (45), .wildLifetime, .tick (0.1), .captureSecondsCap (16), .knockback, .hitStun, .roamRadius, .roamSpeed, .arenaRadius, .claimRange
Config.Capture.hazards[element] = { element, name, warning, shape ("line"|"ring"|"circles"|"pull"), telegraph, active, radius, count, spawnRadius, length, width, travel, pullStrength, color }
Config.Economy.startingCoins (150), .maxCoins, .income {tickInterval, stateSyncInterval, bankCapSeconds, bankCapPerLevel}, .offline {efficiency, capSeconds, minAwaySeconds}, .storage {base, max}, .deploy {startingPads, hardCap}, .sellMin
Config.Economy.upgrades / .upgradeById[id] = { id, name, desc, icon, maxLevel, baseCost, costMult, perLevel, cap? }; .upgradeCost(id, currentLevel)
   ids: tether_speed tether_range move_speed habitat_capacity circuit_efficiency bank_capacity storage decoration
Config.Relaunch.maxLevel (10), .cost(R), .speciesRequired(R), .incomeMultiplier(level), .startingPads(level), .anchorSlots(level), .resetCoins, .resets {strings}, .keeps {strings}
Config.Quests.tutorial[1..7] = { step, title, body, target, info }, .tutorialDoneStep (8), .repeatable / .repeatableById, .dailyPool / .dailyById, .dailyCount (3), .dailyNeedsCircuit, .producerSeconds, .producerMin, .dayKey(unix), .secondsUntilReset(unix)
Config.Events.crisis = { interval, warning, duration, pylons, pylonBaseWork, pylonWorkPerExtraPlayer, holdRate, qualifyWork, bossScale, bossHazardSpeed, bossAttackInterval, rewardSeconds, rewardMin, rewardMax, fallbackBoss }
Config.Milestones.list / .byCount[n] = { count, decoration, decorationName, title }
Config.Sounds.ids[name], .volume[name] -- click tether_start tether_tick capture hit warn break_ deploy collect purchase circuit overdrive relaunch crisis error quest
Config.GameName, .CompanyName, .MapLayout ("A" | "B", chosen B 2026-09-07), .MaxPlayers (follows the layout: B = 6, A = 8), .CameraMaxZoomDistance (60; PlayerService applies it at join and on every character spawn), .DataVersion, .DataStoreName, .TestNamespace
```

Utilities: `Shared.Util.Format` (`abbreviate(n)` → "1.5K", `commas`, `clock(sec)` → "1:05", `duration(sec)` → "1m 5s", `coins`, `cps`, `percent(frac)`, `date(unix)`), `Shared.Util.Weighted` (`pick(weights)`, `pickIndex(items, getWeight)`, `pickChance(entries)`).

## 2. Model building (`Shared.Models`)

### ModelKit — DONE
```lua
local model, root = Kit.newModel("Name")           -- root: invisible 1x1x1 at origin, model.PrimaryPart
Kit.part(model, { name?, shape? ("Block"|"Ball"|"Cylinder"|"Wedge"|"CornerWedge"), size: Vector3, cf: CFrame (relative to root),
                  color?, material?, transparency?, reflectance?, mesh? ("Sphere"|"Head"|"Cylinder"|"Brick"|"Wedge"), meshScale?, role? ("primary"|"secondary"|"accent"|"fixed"), castShadow? })
Kit.blob(model, size, cf, color, role?, material?)   -- ellipsoid
Kit.eye(model, cf, radius, irisColor?) / Kit.eyes(model, centreCF, spacing, radius, irisColor?)  -- eyes look along -Z of cf
Kit.legs(model, bodyCF, spread: Vector2(x,z), length, thickness, color, role?)
Kit.light(part, color, brightness?, range?)
Kit.particles(part, preset, color?)  -- presets: sparkle fire smoke stars motes glint confetti aura lightning rain
Kit.setAnim(model, style, speed?, amp?) -- style: bob waddle hop flutter sway spin hover orbit pulse flicker drift shift
Kit.orbiter(model, part, radius, speed, phase?, tilt?, height?)   -- part revolves around root (client animates)
Kit.flickerPart(part, minT?, maxT?)      -- transparency pulse
Kit.shiftGroup(part, groupIndex)         -- "shift" style: one group visible at a time
Kit.blend(a,b,t) Kit.darken(c,amt) Kit.lighten(c,amt)
Kit.bounds(model) -> centre, size
Kit.finalize(model)                      -- called by the dispatcher, NOT by builders
```
Conventions: feet at y = 0, +Y up, **face on -Z**. Use `role = "fixed"` for eyes/teeth/glass so variants do not tint them. Cylinders are long along X — rotate with `CFrame.Angles(0, 0, math.rad(90))` to stand them up. 14–45 parts per creature; ≤ 2 PointLights and ≤ 3 ParticleEmitters. Total height should match `def.height` (±20%).

`Shared.Models.ToyFace` provides `eyes(model, centreCF, spacing, radius)`,
`smile(model, centreCF, width)`, `cheeks(model, centreCF, spacing, size, color)`,
and `ink: Color3`. It uses the approved creature face style with fixed colours.
`ModelKit.applyVariant` and `applyRarityGlow` add effects only within the remaining
two-light/three-emitter budget; builder-specific effects take priority.

### CreatureModels — DONE (`Shared.Models.CreatureModels`)
`CreatureModels.build(speciesId, variant?, silhouette?, scale?) -> Model` merges every module under `CreatureBuilders/`.
`CreatureModels.hasBuilder(id)`, `.builderIds()`.
Model attributes: `SpeciesId, Rarity, Element, Variant, AnimStyle, AnimSpeed, Height, Width`.

### Builder modules — TO WRITE
`Shared.Models.CreatureBuilders.<Name>.luau` (three files: `WindWater.luau`, `HeatFrost.luau`, `StormCosmic.luau`) each return
`{ [speciesId] = function(model: Model, root: BasePart, palette: {primary, secondary, accent}, def: SpeciesDef) end }` for its 8 species.

`Shared.Models.MachineryBuilders.luau` — TO WRITE — returns:
```lua
M.buildWorkStation(job: string, elementColor: Color3) -> Model   -- job: windmill | waterwheel | furnace | freezer | coil | dish; the prop that sits behind a pad's creature and animates while working
M.buildMachine(circuitId: string) -> Model                        -- one of the six circuit machines, spans the gap between two pads (fits in 8 x 6 x 8 studs)
M.buildPylon() -> Model                                            -- crisis containment pylon (~10 studs tall, ProximityPrompt added by the server)
M.buildDecoration(key: string) -> Model                            -- hazard_flags | smiling_billboard | pipe_fountain | neon_company_sign | golden_statue
```
Work stations and machines animate client-side through the same attributes as creatures: give the moving part `Kit.orbiter` or the model `Kit.setAnim("spin"|"pulse"|...)`; set attribute `Working` (bool) on the model — the client WorldAnimator only animates when `Working == true`. Machines additionally get `Overdrive` (bool) for the x2 look and `Cooling` (bool) for the dark look.

### Animate — DONE (`Shared.Models.Animate`, client-only)
`Animate.track(model) -> boolean` (true when animating now or already; **false when the model has no PrimaryPart/Root yet** — a replicated model arrives before its parts, so callers retry when children land), `Animate.isTracked(model) -> boolean`, `Animate.untrack(model)`, `Animate.step(now, cameraPos)`. Reads attributes described in the file header. The server writes `BasePivot` (CFrame attribute) for placed models and `PathFrom/PathTo/PathStart/PathDuration` for roaming wild creatures.

## 3. Remotes — DONE (`Shared.Remotes`)
Names and argument lists are in `src/shared/Remotes.luau`. Client uses `client/Net.luau`:
`Net.fire(name, ...)`, `Net.on(name, cb)`, `Net.invoke("GetState")`, `Net.invoke("GetCityInfo", plotIndex)`.

## 4. Snapshot — DONE (`Shared.Types.Snapshot`)
The server sends the whole `Snapshot` on the `State` remote (≤ 4×/sec, only when dirty). Client keeps it in `client/State.luau`:
`State.get()`, `State.onChanged(cb)`, `State.now()` (server time), `State.until_(serverTime)`.
Also in Types: `CaptureState`, `HazardEvent`, `CrisisState`, `LeaderRow`, `CityInfo`, `CircuitEntry`, `CreatureEntry`.

## 5. World layout (server builds, client reads)

Ground top surface is y = 0. Angles are in the XZ plane: `pos(r, a) = Vector3.new(r*cos a, 0, r*sin a)`.

```
Workspace.Map                        -- everything MapBuilder creates that is not listed below (ground, paths, props, signs, lamps)
Workspace.Hub                        -- Model. Radius 70 around the origin.
   .Spawn                            -- SpawnLocation 12 x 1 x 12 at (0, 0.5, -20), Neutral
   .Workshop                         -- Model at (-42, 0, 22), local -Z faces plaza center; open garage, entrance apron reaches local z=-16; child Part `Terminal` with ProximityPrompt, attribute OpensPanel = "Workshop"
   .Beacon                           -- Model at (42, 0, 22), local -Z faces plaza center; twin-gantry energy tower, apron reaches local z=-15.5; child Part `Terminal`, OpensPanel = "Relaunch"
   .AtlasKiosk                       -- Research pavilion at (0, 0, 48), local -Z toward hub; apron ends at z=-13.5; child Part `Terminal`, OpensPanel = "Atlas"
   .Board                            -- Part 20 x 9 x 1 at (0, 8, 62) facing -Z with SurfaceGui `Gui` -> TextLabel `Text` (server leaderboard / earnings text)
Workspace.Arena                      -- Model, event area. Floor disc radius 30 centred (0, 0, -105); stage at (0, 0, -128)
   .Pylons.Pylon_<1..3>              -- Models from MachineryBuilders.buildPylon at radius 20, angles 90 / 210 / 330 deg around the arena centre; each has attribute PylonIndex; server adds the ProximityPrompt
   .BossSpot                         -- Part (invisible) at arena centre y = 0 where the boss model is pivoted
   .Screen                           -- Part 18 x 8 x 1 at (0, 12, -134) facing +Z with SurfaceGui `Gui` -> TextLabel `Text`
Workspace.Plots.Plot_<1..MaxPlayers>  -- Model per city plot (PlotTemplate). Ring radius 140, front (local -Z) facing the origin. Layout B: six at (60 + 60*(n-1)) deg, each centred between two region roads. Layout A: eight at (22.5 + 45*(n-1)) deg.
                                        Attributes: OwnerUserId (0 = free), OwnerName, PlotIndex
Workspace.Regions.<regionId>         -- Model per region. Centre at radius 280, angle (90 + 60*(index-1)) deg. Area ~150 x 150.
   .Wild                             -- Folder: wild creature models are parented here by EncounterService
   .Gate                             -- Part (the barrier, 20 wide x 12 tall x 2), at radius 200 on the region's angle, CanCollide true; CollectionService tag "RegionGate"; attribute RegionId
   .GateSign                         -- Freestanding 18 x 10 board: gate ground-frame offset (24, h, -10) where h = `RegionSign.height(element)` (Wind 7.5, Water 8.6, Frost 9.4, Storm 9.9, Cosmic 10.0, Heat 10.6, each exposing its concept's length of leg); facing the hub and clear of piers/shoulders. SurfaceGui `Gui` has separate Element / Title / Cost / Forecast rows. Client updates OPEN/unlock cost and forecast/surge countdown; surge text wraps over two lines.
   .GateSignStand                    -- Frame, supports and decoration built by `Map.RegionSign.dress`; every non-structural piece is CanQuery false, so it never absorbs the approach sightlines. Leaves the central approach road clear
   .Entrance                         -- Part (invisible) just inside the gate; tutorial arrow / VisitCity target
   .Boundary / .Landmarks             -- Continuous themed perimeter with a gate opening; scenery at the edge of the capture field
   .Walkways                          -- Frostbite Peaks (and Thunderworks, Orbit): the functional walking surfaces kept apart from replaceable art; for Frost the visible stone terrace, parapet and both stairs, and the invisible shelf tops, porch and bridge deck (parts carry WalkSurface; invisible ones also CollisionProxy)
   .Landmarks.PropSites               -- Frostbite Peaks (Alpine Outpost): one Model per FP_Alpine_* mesh site, attributes AssetName, AssetSize (the spec bounds times AssetScale on all three axes), AssetScale (number, uniform), AssetLibrary ("FrostbiteAlpineTemplates"), GroundCF (region-local bottom-centre), PivotMode "BottomCenter", SizeLock "Uniform", CollisionRole "none", PlacementRole ("Grounded" / "Stacked"), SupportPath, optional OutsideCell (flank firs beyond the side walls); stand-in art only under a PlaceholderArt child. The PropSites Model carries AssetKit, AssetOrigin, AssetLibrary and AssetCount
   .Landmarks.PropSites               -- Orbit Outpost adds PivotMode ("BottomCenter"), PlacementRole ("Grounded" / "Stacked" / "Suspended"), SupportPath (the permanent part under it, or the landmark a suspended asset hangs against) and optional StackOnSite; its stand-in art is confined to a PlaceholderArt child Model. A Suspended GroundCF is the mesh's intended LOWER EXTENT, not a surface
   attributes: RegionId, Element, Centre (Vector3), SpawnRadius (44), AccessRadius (78), SceneryVersion (4 Cinder Canyon; 3 every other region; `SCENERY_VERSION` in TestHarness)
Workspace.Effects                    -- Folder for temporary parts (hazard telegraph visuals are CLIENT-side and go in the client's own folder; server never spawns telegraph geometry)
```

Wild creature model (in `Regions.<id>.Wild`): built with `CreatureModels.build(id)`, attributes `EncounterUid, SpeciesId, Rarity, Element, RegionId, Difficulty, ClaimedBy (userId, 0 = free), ExpiresAt (server time, 0 = unclaimed), Legendary (bool)` plus `PathFrom/PathTo/PathStart/PathDuration` for roaming and `BasePivot`. CollectionService tags: `"Animated"`, `"Wild"`. The client draws the label (name, rarity marker+text, element, Difficulty N/5, optional claim status) from these attributes; the server adds no BillboardGui. `Shared.Util.CreatureLabel` supplies separate Title/Metadata/Detail/Status rows, root-relative height + 0.7 with bottom anchoring, and camera-depth scaling (250 px maximum width, 55% minimum). Wild labels are tracked within 90 studs of the character; MaxDistance 150 accommodates the zoomed-out camera. Labels respect world occlusion.

### Plot local frame (front = local -Z, toward the hub; local +X is image-LEFT for a player walking in from the driveway). `PlotTemplate.build(cframe, index)` builds the "Pocket Power Town" plot (concept `docs/art/plots/2026-09-21-player-plot/plot-v2-pocket-power-town.png`, measured layout and Astra asset request in `POCKET-POWER-TOWN-ASSET-REQUEST.md` beside it):

| Element | Local offset / size |
|---|---|
| `Platform` | 60 x 1 x 60 at (0, 0, 0); top y = 0.5; slate-blue paving. `Apron` 22 x 1 x 14 at (0, 0, -36) (the driveway ends at its front edge, z = -43). Ivory `Kerb` parts on the platform edge (centre line 29.3, top 1.195) with a 14.8-stud entrance gap; `Threshold` 14.8 x 0.32 x 2.2 at (0, 0.64, -29.9); hazard `Stripe` runs on the front kerb faces. CosmeticsService skins recolour `Platform` / `Apron` / `Kerb` by name. |
| `Pads.Pad_<1..24>` | 5.4 x 0.6 x 5.4 Parts, top y = 1.1; col c (1..6) at x = -20 + 8*(c-1); row r (1..4) at z = -6 + 8*(r-1). Index = (r-1)*6 + c. Attributes `PadIndex`, `Unlocked` (bool). Locked pads are dark + 0.55 transparent. Child `ManagePrompt` (ProximityPrompt, E, range 7, `Enabled = false`): the owner's client enables and labels it (`Controllers.PadPrompts`); the server never reads it. Child `Strip` 3.4 x 0.12 x 0.3 on the pad's front edge (top y 1.02, `CanQuery = false`): dim until `setPadElement` lights it in the deployed creature's element colour. Each pad has a `PropSites.PadFrame_<n>` socket plate with L-shaped yellow corner brackets (art, tops 0.97 / 1.04). |
| `Stations.Station_<pad>` | Folder slot; CityService parents the MachineryBuilders work station here at pad position + (0, -0.05, 3.4) (behind the creature, toward +Z). Nothing the plot builds rises above y 1.05 inside the 3.0 x 2.6 station box. |
| `Machines` | Folder; circuit machine models go here (CircuitService), pivoted at the midpoint of the two pads, y = 1.05. Nothing the plot builds rises above y 1.05 inside the 8 x 8 machine box of any adjacent pair. |
| `Booth` | Model: the rounded dispatch kiosk at the front on local +X (image-left), centred (20, 0, -19). Invisible cylinder collider `BoothCore` dia 8.0 x 4.4 at (20, 2.7, -19); Part `VentButton` (red dome at (16.4, 1.86, -23.1), attribute `Prompt = "Vent"`; server adds the ProximityPrompt) on a hazard-striped `VentBase`; Part `Console` 0.26 x 1.7 x 3.4 at (15.65, 3.55, -19) reading on its **Left** (-X) face (SurfaceGui `Gui`, 44 px/stud -> TextLabel `Text`: overdrive status); `DispatchLabel`, an invisible part carrying the DISPATCH lettering. The kiosk shell is `PropSites.DispatchBooth` art. |
| `CollectPad` | Part 8.4 x 0.34 x 8.4 at (0, 1.05, -18), pale stone: the coin plaza inner tier, with `PropSites.CoinPlatform` art (the gold coin) on top; attribute `Touch = "Collect"`; BillboardGui `Label` -> TextLabel `Text` ("Bank: 1.2K" / "BANK FULL"). Three `Plaza` tiers (13.6 / 12.4 / 10.2 wide) at (0, ., -18), four `PlazaLight` Neon bars and four corner dots, brick `PlazaPier` + `PlazaPierCap` at (+-6.9, ., -13.4), stone `PlazaPost` + `PlazaPostCap` at (+-6.9, ., -23), hazard `Stripe` chevrons down both flanks, and two `PlazaStep` treads at z -25.2 / -26.4. |
| `Billboard` | Part 10.2 x 2.9 x 0.22 at (-21, 3.85, -19.52) facing -Z: the cream face of the arched owner sign at the front on local -X (image-right); SurfaceGui `Gui` (44 px/stud) -> TextLabels `Title` (owner + title) and `Earnings` ("152/s"). Invisible collider `SignCore` 12.2 x 2.2 x 2.6 at (-21, 1.6, -19); plinth, arch, gold rim, crest and planting are `PropSites.OwnerSign` art. Waypoints anchor here. |
| `SpawnPoint` | SpawnLocation 8 x 1 x 8 at (0, 0.5, -34) on the apron, opaque light paving, `Enabled = false` (server sets `player.RespawnLocation`) |
| `VisitorSpot` | Part (Transparency 1) 4 x 1 x 4 at (9, 0.5, -34) |
| `TowerLeg` x4, `VaneAxle`, `Windvane` | Water tower at the rear on local +X: invisible leg colliders 0.9 x 7.6 x 0.9 at (11.5 +- 1.5, 4.3, 25.6 +- 1.5); the vane at y 15.45 spins via the `SceneryMotion` tag. Tank, cap, braced legs and downpipe are `PropSites.WaterTower` art (bounds 6.0 x 14.8 x 6.0, bottom-centre (11.5, 0.5, 25.6)). |
| `WorkshopCore`, `WallLampAnchor` x2, `ChimneyAnchor` | Brick workshop at the rear on local -X: invisible collider 15.4 x 5.8 x 5.5 at (-9.2, 3.4, 26.4); the wall lamps' PointLights and the chimney's ParticleEmitter live on invisible anchors so they survive the art swap. Walls, parapet, roof, doors, chimney and yard clutter are `PropSites.UtilityWorkshop` art (bounds 16.4 x 9.5 x 6.4, bottom-centre (-9.2, 0.5, 26.4)). |
| `Fence` | Model: 17 brick `FencePost` 1.5 x 3.6 x 1.5 on the kerb line (4 corners; z = -10 / 0 / 10 on both sides; x = +-16 and 0 at the rear; x = +-11 and +-21 at the front) each with a `FencePostCourse` and a `PostCap`, and `RailTop` / `RailMid` bars (y 3.3 / 1.18) with `Picket` infill between neighbours. Eight caps (corners, entrance, side middles) carry a warm PointLight under a `PropSites.Lantern_<k>` art site; four more lanterns stand on the plaza piers. |
| `Garden` | Model: the two side banners at (+-27.6, 5.5, -4) facing the centre, the rear banner at (-23.2, 4.7, 26.4), and four `Boulder` rocks on the grass outside: cream boards with SurfaceGui slogans in teal frames. |
| `PropSites` | Model (attributes `AssetKit`, `AssetOrigin`, `AssetCount` = 68): one Model per Astra asset site with `AssetName` (a `Map.PlotAssetSpec` key), `AssetSize` (the spec bounds), plot-local `GroundCF` (bottom-centre; the asset's front faces the site's local -Z), `PivotMode = "BottomCenter"`, `CollisionRole = "none"`, `PlacementRole` (`Grounded` / `Stacked`), `SupportPath`, and a `PlaceholderArt` child Model whose parts never collide, touch or answer raycasts. Sites: 24 `PadFrame_<n>`, `CoinPlatform`, `DispatchBooth`, `OwnerSign`, `WaterTower`, `UtilityWorkshop`, 12 `Lantern_<k>`, 6 `PipeRun_<k>`, 3 `PipeElbow_<k>`, 11 `Shrub_<k>`, 3 `FlowerBed_<k>`, 4 `Tree_<k>`. `Map.PlotProps.apply(model, cframe)` replaces every placeholder with a native MeshPart from `Map.PlotPropTemplates` (all or nothing) into `BlenderProps`; the plot attribute `PlotArt` reads `"native"` or `"placeholder"`. |
| `Tier_<1..3>` | Models, hidden until the decoration upgrade tier is bought (`PlotTemplate.setDecorationTier`): 1 = upper pipe rack, valves, crates; 2 = string lights, floodlights; 3 = rooftop turbine, bunting, auxiliary tank. Parts carry `AuthoredTransparency` / `AuthoredCollide`. |
| `Rewards.<decorationKey>` | Folder slots for milestone decorations (`PlotTemplate.setRewardDecoration`): bunting over the forecourt (0, 1, -10.5), the rear strip (3.0, 1, 21.0) and (-2.2, 1, 27.2), the forecourt corners (14.0, 1, -12.0) and (-14.0, 1, -12.0) |
| `Decorations` | Model created by CosmeticsService for placed cosmetics; `DecorSlots.compute` measures each part's ROTATED footprint, ignores flush ground (`Threshold`, `Plaza`, `PlazaStep`, `PlazaLight`, `Strip`) and fence infill (`Picket`, `RailTop`, `RailMid`, `Flag`), spans z -29..26 and asks 2.75 studs of clearance |

```lua
local PlotTemplate = require(script.Parent.Map.PlotTemplate)
local plot = PlotTemplate.build(cframe: CFrame, index: number)
-- plot = { model, cframe, pads = { [1..24] = Part }, padStrips = { [1..24] = Part }, stations = { [1..24] = Folder }, machines: Folder,
--          booth = { model, ventButton: Part, console: TextLabel }, collectPad: Part, collectLabel: TextLabel, billboardTitle: TextLabel,
--          billboardEarnings: TextLabel, spawnPoint: SpawnLocation, visitorSpot: Part, decorTiers, rewards: Folder, garden: Model, propSites: Model }
PlotTemplate.setOwner(plot, userId: number, name: string)
PlotTemplate.setPadUnlocked(plot, pad, unlocked: boolean)
PlotTemplate.setPadElement(plot, pad, color: Color3?)             -- light the pad strip in an element colour; nil dims it (CityService.refreshPad)
PlotTemplate.setDecorationTier(plot, tier: number)              -- 0..3
PlotTemplate.setRewardDecoration(plot, key: string, shown: boolean)
PlotTemplate.padCFrame(plot, pad) -> CFrame                       -- world, top surface centre, facing -Z
PlotTemplate.pairCFrame(plot, padA, padB) -> CFrame               -- midpoint for a circuit machine
PlotTemplate.stationCFrame(plot, pad) -> CFrame                   -- behind the pad, toward +Z
PlotTemplate.reset(plot)                                          -- clear stations, machines, labels, strips (owner left)

local PlotProps = require(script.Parent.Map.PlotProps)
PlotProps.apply(plotModel: Model, cframe: CFrame) -> boolean       -- swap PropSites placeholders for Map.PlotPropTemplates meshes; false = nothing changed
require(script.Parent.Map.PlotAssetSpec)                          -- { PP_Water_Tower = Vector3.new(6, 14.8, 6), ... }: the 12 plot asset bounds
```

## 6. Server map contract (`ServerScriptService.Server.Map`)

`HubLandmarks.luau` builds Workshop, Beacon and Atlas from a supplied inward-facing `CFrame`
and the map's part factory (so geometry remains included in the map part count).
`buildWorkshop(parent, frame, makePart)` / `buildBeacon(parent, frame, makePart)` / `buildAtlas(parent, frame, makePart)`
return the interaction `Terminal`. They retain `OpensPanel` and `Waypoint` attributes/tags;
MapBuilder still returns the same hub references. All doors, consoles and front signs
share local -Z; paths terminate at the entrance aprons instead of running under buildings.
Materials use built-in Concrete, Brick, Metal, DiamondPlate, WoodPlanks and Glass;
Neon is confined to task lights and the relaunch power elements. No external textures.

Before map construction, `ImportStaging.move(workspace,
ServerStorage)` moves recognized raw Cinder/Gusty/Splashwater/Frostbite/Orbit/Thunderworks FBX bundle models
into `ServerStorage.RegionImportStaging` and anchors their parts. A first Orbit import,
before OrbitPropTemplates exists, is recognized only by the exact OrbitPropsBundle
model name and all 15 unique OO mesh names from OrbitAssetSpec with nonempty MeshIds.
Partial or unrelated same-name bundles are left unchanged. Otherwise recognition
requires the exact bundle name and matching template mesh names/IDs, and excludes
already placed props. This keeps 100x unanchored import galleries out of physics
without deleting editable assets or moving unrelated models.

`ImportStaging.quarantine(workspace, ServerStorage)` runs straight after `move` and
catches copies under any name: a top-level Workspace model or part whose every
BasePart is a MeshPart sharing a MeshId with a staged gallery or a captured
template library, none tagged `BlenderAsset`, is anchored and moved to
`ServerStorage.RegionImportStrays`, apart from the native galleries and without
`NativeTemplateLibrary`. Anything holding other parts, unknown meshes or placed
props is left alone. TestHarness fails `no raw import copies loose in Workspace`
if a staged gallery mesh appears in Workspace outside a placed prop.

`RegionScenery.build(parent, def, centre, radius, makePart)` builds each region's
themed perimeter, entrance piers and peripheral landmarks using the same part factory.
All six elements now delegate to their own module and `RegionScenery` is purely
the dispatcher: it works out the region frame once and hands it on. The generic
palette builder that used to stand in for the unbuilt regions went with the last
of them, Cosmic. Wind, Water, Heat, Frost and Storm output is unchanged by that
narrowing, checked rather than assumed: all five were dumped part for part before
and after on name, host, size, material, shape, all four collision flags, colour
and the full 12-component CFrame, and the dumps are identical (663 / 503 / 589 /
806 / 683 parts).
Wind delegates to `GustyGardens.build(parent, frame, radius, makePart)`: continuous
hedge cores, rounded planted banks, timber arbor, trees, flowers and a windmill.
The arbor replaces the Wind gate's industrial frame; `Gate`, `GateSign` and entry
references remain unchanged. Water delegates to
`SplashwaterBay.build(parent, frame, radius, makePart)`: continuous slate boundaries,
sandy banks, lagoon/tide pools, curved boardwalk, lighthouse and beached skiff.
Its harbor entrance replaces the Water gate's industrial frame, retaining the
unlock prompt, gate sign and server access checks. Pools are decorative surfaces
over solid ground, not swimmable Terrain water. Beach grass and the lighthouse
pennant reuse `SceneryMotion`.
`MapBuilder` publishes a region's own shape when its scenery module returns one:
`OWN_PERIMETER` (Wind, Water, Heat, Frost) suppresses the generic biome shoulders for
modules that lay their own border, `GROUND_MATERIAL` gives Heat Sandstone for the
quarry floor, and `TRAIL_BLEND` (Water, Heat, Frost) lays the centre lane in the region's
own ground colour and material at the width the concept draws, because paving those
kerbed a beach, a quarry floor and a snow meadow with a grey runway. Frost's lane is
packed snow (190, 206, 228), 24 wide. `OWN_FLANK` (Frost) makes the shared
`ChainFlanks` treeline skip every row inside that region's cell, where the region
module snows over the flank strip and plants its own firs. A returned `field` becomes
the region's `FieldHalf` attribute and `spawnRadius`; a returned `keepOut` list
reaches `EncounterService.pickHome` / `clearOf` unchanged.
`GardenBayProps.apply(parent, frame, element) -> boolean` places imported Wind
and Water kits from native `GustyPropTemplates.rbxm` and
`SplashwaterPropTemplates.rbxm`. It creates 43/63 decorative MeshParts in
`BlenderProps`, respectively, with `BlenderPropsVersion = 1`. Rock collision
proxies, region boundaries, walking surfaces, gates and boards remain in place.
Missing/incomplete templates leave the original geometry intact. Replacement
trees are static; grass, pinwheels, mill sails and pennants retain their animation.
Gusty's 12 flower clusters, five ferns and four shrubs also use SceneryMotion at
their ground pivot, with SceneryAmplitude 0.025 radians. SceneryAnimator defaults
to 0.045 radians for legacy sway and restores the authored pose for reduced motion.
Gusty's vertical beam helper uses an alternate up vector to keep flower stems
finite even when the original geometry is built as a fallback.

Gusty's current rectangular layout also has `Boundary.BroadleafSites`: 35
`Broadleaf_01..35` Models with region-local `GroundCF`, positive uniform
`AssetScale`, `PivotMode="TrunkBase"`, and `SizeLock="Uniform"`. Each keeps the
original solid/non-queryable `MeadowTreeTrunk` and a `PlaceholderArt` Model with
six noncolliding `MeadowTreeLobe` parts. Grouping does not change their transforms.
`GustyBroadleafProps.apply(parent, frame)` validates all sites and every native
`GustyBroadleafTemplates` component before preparing a detached replacement.
An absent/invalid library leaves the old art intact. Success creates
`BroadleafTrees/<site name>` with A/B/C distribution 12/12/11 and three components
per site (105 MeshParts). Component sizes and center offsets use the same site
scale; `MeshSize` and authored RenderFidelity stay untouched. Root socket is zero,
and the native library must carry a verified `NativeMeshYawDegrees` (0 or 180).
The captured Gusty import is 100x with a 180-degree vertex orientation correction,
measured against the export using native EditableMesh vertices. Placement applies
this rotation **after** the component-center translation, about each native mesh
center; it does not rotate the source socket or its manifest offsets.
Every variant fits the old unscaled envelope x[-9.8,10.2], y[-.05,17.98],
z[-9.4,9.5]. Old crown art is retired; the trunk becomes an invisible collision
proxy. The region records `BroadleafVersion=1`, `BroadleafCount=35` and
`BroadleafPartCount=105`. This is separate from `GardenBayProps` and its older
fixed-position decorative kit; pines, flowers, legacy kit placements and the
Water consumer are unchanged. `ImportStaging` recognizes the complete nine-mesh
`GustyBroadleafBundle` before a native library is captured.

Heat delegates to `CinderCanyon.build(parent, frame, radius, makePart)`, rebuilt
to the approved "Cinder Quarry" concept and returning a layout spec like Wind and
Water. The superseded "Sculpted Ravine" ring, its arch, bridge, ledge walkway and
perimeter lava terrace are gone. The cell is now MapBuilder's 280 x 200 rectangle:
the region's own ground is the quarry floor (nothing raises it, because the Heat
telegraph is drawn flat at the creature's feet), a recessed timber mine stands at
X 55..119 / Z 42..90, a short rail and one ore cart hang off the mine's DoorBase
socket, a four-tier quarry terrace stands at X -124..-52 / Z 37..93 with a hoist on
its shelf, and a band of stacked sandstone and cacti runs round the border. It
reports `field = (92, 0, 72)` and four keep-out zones: the two landmarks at radius
48, the lava pocket at 18 and the 34-wide centre lane. Output splits three ways:
`Boundary` holds nothing but invisible collision proxies, `Landmarks/PropSites`
holds one metadata site per intended mesh with its stand-in under `PlaceholderArt`,
and `Landmarks/Effects` and `Landmarks/FloorDetail` hold the lava, the minerals,
their lights and the shallow floor dressing. Its lava is a coloured surface only -
no damage, hazard, reward or traversal mechanic. The dimensioned contract is
`docs/art/regions/2026-09-22-cinder-canyon/CINDER-QUARRY-CLAUDE-HANDOFF.md` and
the build is recorded in `CINDER-QUARRY-LAYOUT.md` beside it.
Frost delegates to `FrostbitePeaks.build(parent, frame, radius, makePart)`, rebuilt
to the approved "Alpine Outpost V2" concept for the 280 x 200 chain cell and
returning a layout spec like Wind, Water and Heat. The circular Alpine Expedition
blockout, its cliff ring, timber arch, ledge route, cascade and rear peaks are gone.
Local +X is world west (the concept's left). A stone terrace (x 84.5 .. 138.4,
z 28.5 .. 77, deck 5.80) reached by a nine-riser stair carries the lodge site
(bottom-centre (113.5, 5.80, 58.5), door south) with a walkable porch at 6.80 and a
camp in front; two bridge shelves at 8.80 (C + A north landing, B south landing with
a fourteen-riser stair) carry a 34-stud rope bridge over a decorative frozen creek on
local -X; layered slate formations, firs, boulders, drifts and planting fill the rear
corners and side bands; the flank strip outside both side walls is snowed over and
planted within the cell's z span; non-colliding snow caps sit on this cell's stretch
of the side walls, the north divider's Frost half and their pier lanterns. It reports
`field = (80, 0, 64)` and two keep-outs: the rear-left boulder cluster at radius 12
and the 34-wide route. Output splits as the quarry's does: `Boundary` holds only
invisible collision proxies (including containment above the side-wall coping behind
the terrace and the south shelf), `Walkways` holds the functional walking surfaces
(visible stone terrace, parapet and both stairs; invisible shelf tops, porch and a
segmented bridge deck with kerbs), `Landmarks/PropSites` the 282 asset sites,
`Landmarks/Effects` window and lantern glow, six PointLights, chimney smoke and the
creek ice, `Landmarks/FloorDetail` flush meadow ice, tracks and wind lines (at most
0.06 above the 0.30 floor), `Landmarks/WallSnow` and `Landmarks/Flanks`. Ice is
CanCollide false decoration; nothing raises the meadow. The lodge door, notice
board and signpost carry no interaction. Measured layout and build record:
`docs/art/regions/2026-09-22-frostbite-peaks/ALPINE-OUTPOST-V2-LAYOUT.md`; the
asset contract is `ALPINE-OUTPOST-V2-ASSET-REQUEST.md` and every site is listed in
`ALPINE-OUTPOST-V2-SITES.csv` beside it.
`FrostbiteAlpineAssetSpec` fixes the 28 FP_Alpine_* bounds and the sockets the map
uses, exactly as Astra's `assets/frostbite-peaks/alpine-v2/manifest.json` (version 3)
delivers them; `tools/verify_frostbite_alpine.luau` re-reads the manifest and fails on
drift. `FrostbiteAlpineProps.apply(parent, frame) -> boolean` validates the complete
`FrostbiteAlpineTemplates` library (every name once, Size equal to the spec, positive
MeshSize with a uniform ratio to it, uploaded MeshId and a texture) and every site
(spec times a uniform AssetScale between 0.25 and 2, the metadata above, no colliding
or queryable placeholder) before replacing any PlaceholderArt; a partial kit, a 100x
scale, a distorted mesh or a non-uniform site leaves the blockout untouched, and a
second call is a no-op. Placed meshes land in `BlenderProps` with
`BlenderPropsVersion = 1` and `BlenderPropCount`; Boundary, Walkways and Effects are
never touched. `ImportStaging` quarantines an `AlpineOutpostBundle` carrying all 28
names (the two spare meshes are tolerated). The superseded `FrostbiteProps` and the
props-v1 `FrostbitePropTemplates` stay in place and are no longer called.

`FrostbitePowderProps.apply(parent, frame) -> boolean` runs after the Alpine swap
and replaces only the 91 existing fir sites (including cliff tops and flanks).
The approved Powder Fir A/B/C family has a separate `FrostbitePowderTemplates`
library of 14 native mesh components, fixed by `FrostbitePowderSpec` and
`assets/frostbite-peaks/powder-firs-v1/roblox/manifest.json`. The full library and
every tree site must validate before any old art is removed; missing/invalid
imports leave existing trees intact. It works with either Alpine placeholders or
already placed native Alpine firs. Non-tree props and all collision proxies stay
unchanged. Tree sites keep their original Alpine metadata and gain
`PowderFirVariant` plus `AssetPlaced`. Sorted site names select A/B/C cyclically
(31/30/30). Uniform scaling fits each complete crown inside its original oriented
site bounds while preserving the existing TrunkBase anchor. Components use the
manifest's tree-local bounds centres, preserving native MeshSize and textures.
`PowderFirs/<site name>` holds each component Model; the region carries
`PowderFirVersion = 1`, `PowderFirCount = 91`, `PowderFirPartCount = 425`. Any
remaining `BlenderPropCount` describes the non-tree native Alpine meshes (191).
`ImportStaging` recognizes complete `PowderFirsBundle` galleries. The native
library is captured; IDs/maps are in the kit's `roblox-import.json`. Runtime
reads `ColorMapContent.Uri` and inherits RenderFidelity from native templates;
legacy ColorMap access and RenderFidelity writes require plugin security.
Studio verified all 91 trees, 425 components, successful content loading and
no remaining old tree art. Mobile performance remains unprofiled.

Storm delegates to `Thunderworks.build(parent, frame, radius, makePart)`, the
"storm-powered industrial yard" blockout: one dark asphalt yard skin out to
radius 73.5, a 48-segment concrete retaining ring in three heights (12.5-14.3 at
the entrance flanks, 17-21 on the sides, 20-23.6 across the rear) with
full-height pilaster pairs, inset steel panels, chain link over the low run and
four vent stacks; a steel entrance portal replacing the industrial gate trim; a
maintenance catwalk on local +X, reached by a tangential flight at each end and
crossing a closed cable trench 4.92 studs below its deck; a facade-only control
shed on a low service apron on local -X; and a pair of 35.8-stud lightning
collectors on a generator plinth across the rear, carrying a static three-phase
bus. It splits its output three ways like Cinder Canyon and Frostbite Peaks:
683 parts as `Boundary` 122, `Walkways` 112, `Landmarks` 449, with six
PointLights. Nothing in it arcs, flashes, damages or can be interacted with; the
shed door, the glyph plates and the bus are geometry. The floor is deliberately
dark and carries no yellow, so Storm's pale yellow Lightning telegraph stays the
brightest thing on it. The dimensioned contract for the Blender pass, with all
33 asset sites, is
`docs/art/regions/2026-09-21-thunderworks/THUNDERWORKS-LAYOUT.md`.
`Landmarks/PropSites` carries `AssetCount`, `AssetKit` and `AssetOrigin`; each
child Model carries `AssetName`, `AssetSize`, region-local `GroundCF`,
`CollisionRole = "none"` and `SupportPath`. Every Thunderworks site is
ground-supported, so art goes at `frame * GroundCF * CFrame.new(0, AssetSize.Y / 2, 0)`;
there is no hanging convention in this region.
Cosmic delegates to `OrbitOutpost.build(parent, frame, radius, makePart)`, the
approved "V7 Gravity Garden" blockout: a 36-segment ring of violet-grey rock
terraces 9.5 to 20.4 studs tall, each carrying an invisible `BarrierField`
collision core inside the cyan energy pane above it, so the barrier reads as
glass and still closes the ring when the pane is replaced; two ivory research
pillars framing a 20-stud entrance with no lintel; a 21 x 16 gravity dais at the
rear reached by a tangential flight up each flank, carrying the three-pronged
cradle with the meteor suspended inside it and three orbit stones; a closed
round field laboratory on a pad on local +X, whose glass dome (`LabGlazing`) is
this module's and is kept through the art pass; three survey dock pads; and a
small teal utility nook on local -X. It splits its output three ways like Cinder
Canyon, Frostbite Peaks and Thunderworks: 463 parts as `Boundary` 73,
`Walkways` 22, `Landmarks` 368, with six PointLights. Nothing in it moves,
damages or can be interacted with, and the suspended meteor and stones are
anchored static placements.

**Orbit Outpost lays no floor of its own.** The Gravity Pulse telegraph is a
0.3-thick disc drawn 0.16 above the creature, spanning y 0.01 to 0.31 against
the region ground disc's 0.30 top, so any walkable skin would bury it. The lunar
floor is that disc restyled in place instead: `Regions.list` Cosmic
`groundColor` is 118/109/132 and `MapBuilder`'s `GROUND_MATERIAL.Cosmic` is
`Sand`. The walking height stays 0.30. The dimensioned contract for the Blender
pass, with all 51 asset sites, is
`docs/art/regions/2026-09-21-orbit-outpost/ORBIT-OUTPOST-LAYOUT.md`.

`ThunderProps.apply(parent, frame) -> boolean` validates all sites and templates
before replacing their PlaceholderArt. It uses ThunderAssetSpec sizes and clones
eight native mesh types from ThunderPropTemplates.rbxm into 33 anchored,
non-colliding/non-touching/non-queryable placements. GroundCF is region-local,
BottomCenter; all sites are Grounded. Missing/invalid kits retain the blockout;
repeated placement is a no-op. Boundary, Walkways and six lights remain intact.
Uploaded IDs are in assets/thunderworks/props-v1/roblox-import.json.

Thunderworks uses its original Asphalt Ground at y=0.30. The old YardSkin at
0.42 is removed because lightning discs top out at y=0.31. Seams/scuffs/drains
top out at 0.302/0.304/0.306 and are decorative. The two free-standing cable reels
now stand at y=0.30 with SupportPath="Ground"; other site heights are unchanged.

`OrbitProps.apply(parent, frame) -> boolean` validates the full site/mesh set before
replacing only each site's PlaceholderArt. It uses `OrbitAssetSpec` final sizes,
requires BottomCenter local GroundCF and decorative collision roles, clones native
MeshParts from `OrbitPropTemplates`, anchors them and normalizes Size/PivotOffset.
The 51 placements include stacked and suspended assets, all with positive half-height
offset. Existing lab PointLights retain their world positions using attachments;
Boundary, Walkways and LabGlazing are untouched. Missing/partial templates retain
the blockout, and repeated application is a no-op. Imported art lives in BlenderProps
with BlenderPropsVersion=1 and BlenderPropCount=51. Native Orbit templates are
saved in OrbitPropTemplates.rbxm; uploaded IDs and native sizes are recorded in
assets/orbit-outpost/props-v1/roblox-import.json. OrbitOutpost creates an invisible
LabCore collision proxy and insets LabGlazing beneath the native dome ribs.

Every element except Heat is excluded from MapBuilder's industrial
`GatePost`/`GateLintel`/`hazardStrip` gate frame (`OWN_ENTRANCE` in `buildRegion`)
because their scenery modules build their own entrance; `Gate`, `UnlockPrompt`,
`Entrance`, `GateSign` and the region attributes are untouched in every case.
`CinderQuarryAssetSpec` fixes the twelve Cinder Quarry envelopes (Width X x
Height Y x Depth Z) exactly as the approved handoff writes them, and names the
props-v1 meshes still worth reusing under the new art.
`CinderQuarryProps.apply(parent, frame) -> boolean` validates the whole
`CinderQuarryTemplates` library against that spec before replacing any
`PlaceholderArt`: it requires a BottomCenter local `GroundCF`, `SizeLock = "Fixed"`,
`CollisionRole = "none"`, a known `PlacementRole`, a mesh with a MeshId, a TextureID
and a positive MeshSize, and bounds matching the spec to 0.005 studs -- which is the
check that catches an FBX conversion's 100x scale. A partial kit, a wrong scale or a
colliding placeholder each leave the blockout entirely intact, and repeated
application is a no-op. Imported art lands in `BlenderProps` with
`BlenderPropsVersion = 1` and `BlenderPropCount`; `Boundary`'s collision proxies and
`Landmarks/Effects` are never touched, because containment and lighting are
deliberately outside every asset's bounds.
`CinderProps.apply(parent, frame) -> boolean` belongs to the superseded Sculpted
Ravine layout -- its placements are fixed ring bearings that no longer exist -- so
`CinderCanyon` no longer calls it. The module and its library stay in place for the
props-v1 meshes the quarry still reuses (basalt, ember crystals, sandstone rubble),
which the quarry tags with a `ReusableAsset` attribute rather than an asset site.
It replaces small prop placeholders
using nine imported MeshPart templates in `Map/CinderPropTemplates.rbxm`.
It creates 32 non-colliding, non-queryable meshes in `BlenderProps`, preserves
solid placeholder collision proxies and all Boundary/Walkways geometry, and
stamps `BlenderPropsVersion = 1`. Missing templates leave the blockout intact.
Field rubble remains 0.4 studs tall. Mesh and palette asset IDs are recorded in
`assets/cinder-canyon/props-v1/roblox-assets.json`; native MeshSize must survive
serialization, or uploaded geometry renders at the wrong scale.
Decorative moving parts are anchored, non-colliding,
non-queryable and tagged `SceneryMotion`, with attributes `SceneryPivot` (world
CFrame), `SceneryOffset` (local CFrame), `SceneryMode` (`Spin`/`Sway`),
`ScenerySpeed` and `SceneryPhase` (numbers). `Controllers/SceneryAnimator` retries
incomplete replication naturally, animates locally at 30 Hz within 260 studs,
and restores authored poses when Reduced Motion is enabled.
The field stays open; creatures spawn within radius 44 and
`EncounterService.clampToField(position, centre, radius)` keeps roaming endpoints
inside that field while preserving height.

`Map.RegionSign.dress(board, stand, signCF, def, makePart) -> { title, element }`
colours the `GateSign` board, fills `GateSignStand`, and returns the colours
MapBuilder gives the two static text rows; `Cost` and `Forecast` stay the client's.
`Map.RegionSign.height(element) -> number` gives the board centre above ground and
MapBuilder reads it when placing `signCF`, so the builder and the footings cannot
disagree about the ground plane. Both read one `DESIGNS` table, keyed by element.

All six regions are now built from concept art in
`docs/art/region-boards/2026-09-20-mockups`; `plain()` remains only as the fallback
for an element with no design.

| Element | Board | Height | Panel |
|---|---|---|---|
| Wind | honey timber posts on stone footings, 21-segment arched crown, carved wind swirls, cream pinwheel crest, corner daisies | 7.5 | forest green |
| Water | whitewashed timber on driftwood posts, navy cap and planked panel, iron bolts, twisted rope lashings, open life ring, shell/starfish cluster | 8.6 | dark navy |
| Heat | charcoal-basalt frame with ember cracks on its outer edges, copper corner brackets and rivets, red stone posts, tapered basalt footings, stepped volcano crest with a lava vent, ember shards at the feet | 10.6 | near-black charcoal |
| Frost | blue-grey stone uprights under snow-capped heads, faceted frosted-ice frame, undulating snow cap, hexagonal snowflake medallion, corner icicles, ice gems set in the posts, four-tier snowed plinths | 9.4 | midnight navy |
| Storm | weathered steel frame with chamfered armoured corners and orderly bolts, hazard-striped outer cap rail split either side of the crest, lightning badge in a round housing, ceramic insulators with routed cables, amber pilot lamps, concrete plinths | 9.9 | near-black steel |
| Cosmic | four concentric chamfered silver rings with a violet trim line, lavender indicator strips in the side rails, star studs at the panel corners, ringed-planet medallion, short graphite drum legs with glowing collars on rounded footings | 10.0 | midnight purple |

Live text is never baked in: every board shows the same `Element / Title / Cost /
Forecast` rows, and the client still drives OPEN, the unlock price and the surge
countdown. `BOARD_HIERARCHY` in MapBuilder lists the elements using the taller
five-row layout (a small element line, a large name, a large status, and a
two-size surge footer) and turns `Forecast.RichText` on for them; Wind keeps the
original even rows. `RegionGates` branches on `Forecast.RichText`, not on a region
id, so the server alone decides which boards get the 27/16 px surge footer.

Under that layout the widest row is `Title` at x +/- 8.28 and the outermost rows
reach y 4.55 and -4.60, so a frame member crossing the face must clear those. Every
board's rails sit at y 4.7 and -4.7, and the narrowest side member is Cosmic's inner
rail at |x| 8.9. Decoration is CanQuery false and cannot absorb a sightline ray at
all; only posts, caps and footings are solid, and each of those has its inner face
outside |x| 8.7, well beyond the |x| 7.2 / |y| 4.0 face window `testRegionSignVisibility`
samples. No piece passes |x| 11.0, the extent Splashwater's footings established as
clear of the approach road.

The live suite also runs `region field clearance`: for every region, no solid part
whose footprint is narrower than `SpawnRadius` may come within `SpawnRadius` of the
region centre, measured from the nearest point of its ground footprint. Region floors
are excluded by being at least as wide as the field. This is what stops a scenery pass
from quietly filling the space creatures roam in and hazards are telegraphed on.

`RegionAccessService` registers as `S.RegionAccess`. `init(refs)` runs after
`Capture.init()`, checking loaded, living players every 0.2 seconds against each
region's XZ access radius, regardless of height. `findLocked(position, unlocked)`
returns the locked region id and refs (or nil); `enforce(profile, now)` cancels any
capture and returns unauthorized entrants 12 studs in front of the gate with velocity
cleared. Purchases and relaunch resets take effect from the current profile on the next
check. Notices are limited to one per five seconds per player. Starter regions remain
open. Quest region-entry polling also requires ownership.

```lua
local MapBuilder = require(script.Parent.Map.MapBuilder)
local refs = MapBuilder.build()
-- refs = {
--   spawn: SpawnLocation,
--   plots = { [1..8] = CFrame },                            -- plot centre, ground level, LookVector toward origin
--   regions = { [regionId] = { model: Model, centre: Vector3, spawnRadius: number, accessRadius: number, gate: Part, gateSign = { title: TextLabel, cost: TextLabel, forecast: TextLabel }, entrance: Part, wild: Folder } },
--   hub = { workshop: Part, beacon: Part, atlas: Part, board: TextLabel },
--   arena = { centre: Vector3, pylons = { [1..3] = { model: Model, prompt: ProximityPrompt? } }, bossSpot: Part, screen: TextLabel },
-- }
```

Wayfinding the client reads off the built map:

- Roads end at the **edge** of what they lead to, never its centre: plot driveways stop at the front apron (radius 97), kiosk spokes stop at the base disc, the region route is hub → gate plus a 30-stud stub onto the region ground, and nothing crosses the arena floor. The live suite asserts the plot and arena cases.
- `TutorialUI` draws its guide as a chain of beams along the **road graph** (every `Path` part is an edge, its ends are nodes): player → nearest road → shortest road route → nearest road to the target → target. A straight line only when neither end is near a road.
- **Map layout** (`Config.MapLayout`). Six region roads at 60-degree spacing cannot pass between eight cities at 45-degree spacing without clipping a corner, and the crisis arena sat on the Frostbite (270) road line. Layout **B (chosen)**: six cities seated between the straight region roads, the arena moved to polar(262, 300) between the Frostbite and Thunderworks regions with its front on a 101-stud spur off the Frostbite road at radius 182, and scenery whose footprint comes within 40 studs of the arena centre removed at build. Layout A (kept behind the switch): eight cities, roads dog-leg through the 45-degree gaps with connectors at radius 186. Live checks: no road centre line inside a city Platform/Apron (quarter-stud tolerance) or the arena floor disc.
- Every `path()` call is one route. Its chevrons are **Neon** parts tagged `"RouteChevron"` with attributes `RouteId` (string, unique per route), `Index` (1..`Count`, increasing toward the destination) and `Count`. `Controllers.RouteLights` runs a light along them.
- Hub destinations (`workshopTerminal`, `beaconTerminal`, `atlasTerminal`, the arena `bossSpot`) are tagged `"Waypoint"` with `WaypointName` (string), `WaypointColor` (Color3) and `WaypointHeight` (studs above the part). `Controllers.Waypoints` hangs a sign on each; gates need no tag because `RegionGate` + `RegionId` already say everything.

## 7. Server systems (`ServerScriptService.Server.Systems`)

Registry: `local S = require(script.Parent.Services)`; each module ends with `S.<Name> = <Module>`. Reach other systems only through `S.` at call time (avoids circular requires). Direct requires are fine for `Profiles`, `Stats`, `Notify`, `RateLimiter`, `Services`.

Every mutating function takes `profile` first and returns `(ok: boolean, message: string?)`; on failure the caller (RemoteRouter) sends the message with `Notify.player(player, "error", msg)`. Systems set `profile.dirty = true` after any state change (Sync pushes it). Never trust remote arguments; the router already type-checks them, systems re-check ownership, ranges and state.

Server time is `workspace:GetServerTimeNow()`; persisted timestamps are `os.time()` (unix).

| Module | Exports | Notes |
|---|---|---|
| `Profiles` — DONE | `defaultData() sanitize(raw) create(player, data, dataSafe, testAdapter) remove get getByUserId all newUid(profile) countCreatures markDirty` | Schema in the file. |
| `Stats` — DONE | `compute(profile) -> Computed`, `maxUpgradeLevel`, `padOccupant`, `padMap`, `deployedCount`, `normalCps(profile, entry)`, `potentialCps`, `pairBonus(profile, key)`, `checkPair(profile, a, b, ignoreExisting?) -> ok, reason, recipe`, `activePairs(profile) -> byKey, padToKey`, `overdriveFactor(profile, key, now)`, `income(profile, now) -> Income {perCreature, perCreatureNormal, total, totalNormal, pairs, padToKey}`, `bankCap`, `sellValue`, `circuitUpgradeCost(profile, a, b)`, `scaledReward(profile, seconds, min, max)`, `discoveredCount`, `storageUsed`, `storageFull`, `title`, `canBuildAnyCircuit` | All formulas. |
| `Notify` — DONE | `player(player, kind, text, duration?) broadcast(text, color?) all(kind, text) floating(player, text, pos, color?) effect(kind, pos, extra?) effectFor(player, kind, pos, extra?) tutorial(player, step, done) captureState(player, state?) hazard(playersOrNil, hazardEvent) knockback(player, dir, strength) captureResult(player, result) forecast(playerOrNil, table) crisis(stateOrNil) leaderboard(boards) nameOf(userId)` | Thin wrappers over remotes. |
| `RateLimiter` — DONE | `allow(player, action) clear(player)` | Token buckets per remote name. |
| `DataService` | `init()`, `load(player) -> data, dataSafe, usingTest`, `save(profile, reason) -> bool`, `isAvailable()`, `usingTestAdapter()`, `releaseSession(profile)`, `roundTrip(data)` | UpdateAsync with session ownership (`data.sessionId/sessionAt`, 90 s stale takeover), retries with bounded backoff, autosave 90 s, leave + BindToClose saves, never saves when `dataSafe == false`. In Studio without API access: **in-memory test adapter** keyed `Config.TestNamespace .. userId`, `profile.testAdapter = true`, survives Play-session restarts only while the server instance lives. |
| `Sync` | `init()`, `build(profile) -> Snapshot`, `push(profile)`, `markAllDirty()` | Only sender of `State`. |
| `PlayerService` | `onJoin(player)`, `onLeave(player)` | load → profile → `S.City.assign` → offline calc (`S.Economy.computeOffline`) → `S.Quests.ensureDaily` → tutorial send → first push; leave: `S.Capture.cancel`, `S.City.release`, save, cleanup. Sets `player.RespawnLocation` to the plot spawn, applies walk speed from `Stats.compute(profile).walkSpeed` on every CharacterAdded and when upgrades change (`S.Player.applyCharacter(profile)`). |
| `EconomyService` | `init()`, `tick()` (internal 1 s loop: bank += income.total x dt, clamped to `Stats.bankCap`; accrues `mastery[species].circuitSeconds` for creatures in active pairs; bumps quest stat `earned`), `collect(profile) -> ok, msg` (bank → coins, floor at payout, `stats.collects`, quest `collects`, FloatingText), `spend(profile, amount) -> bool` (atomic check + deduct, rejects non-finite), `addCoins(profile, amount, reason?)`, `computeOffline(profile)` (called once at load: `elapsed = now - lastOnlineAt`, if elapsed ≥ minAwaySeconds then `offlinePending = totalNormal x min(elapsed, capSeconds) x efficiency`; guards negative/zero; uses production computed from the SAVED layout), `claimOffline(profile) -> ok, msg` (once-only; zeroes pending before adding). Overdrive never counts offline. | Coins never increase from a client-reported number. |
| `CityService` | `init(refs, PlotTemplate)`, `assign(profile) -> plot?`, `release(profile)`, `plotOf(index) -> plot?`, `grantCreature(profile, speciesId, variant, perfect) -> uid?, msg` (refuses when `Stats.storageFull`), `deploy(profile, uid, pad)`, `store(profile, uid)`, `move(profile, uid, pad)` (swap if occupied), `sell(profile, uid)` (refuses favorites and anchored; pays `Stats.sellValue`), `setFavorite(profile, uid, bool)`, `refreshPad(profile, pad)` (creature model + station + per-pad BillboardGui via `Shared.Util.CreatureLabel` (Title=name/favorite, Metadata=rarity + variant or element, Detail=live Coins/s); income ticks update Detail only), `refreshAll(profile)`, `refreshLabels(profile)` (collect pad bank text, billboard earnings; called by Economy every tick at most 1/s), `applyUpgrades(profile)` (pad unlock visuals from `Stats.compute().padsTotal`, decoration tier, reward decorations) | After deploy/store/move/sell call `S.Circuits.recalculate(profile)`. Pad creature models are tagged `"Animated"`, attribute `Working = true`. |
| `CircuitService` | `init()`, `connect(profile, padA, padB)`, `disconnect(profile, pad)`, `upgrade(profile, padA, padB)`, `startOverdrive(profile, padA, padB)`, `vent(profile)` (booth prompt; succeeds only while some pair is in the active phase and not yet vented), `recalculate(profile)` (prunes invalid `data.circuits` pairs, rebuilds machine models under `plot.machines`, updates `Working/Overdrive/Cooling` attributes, records recipes in the Atlas on first activation via `S.Atlas.recordRecipe`, bumps quest `connects` on connect), `tick()` (advances overdrive phases active → cooldown/idle; sets `profile.dirty`) | Overdrive state is keyed by pair key in `profile.overdrives` and is NOT reset by disconnect/reconnect/replace while a phase runs; `startOverdrive` is refused during active or cooldown. Circuit upgrades are keyed by pair key for the current run (`data.circuitUpgrades`). |
| `EncounterService` | `init(refs)`, `tick()` loop (per region: keep `populationCap` wild creatures, respawn after `respawnDelay`, roam legs via Path* attributes, expire claims at `ExpiresAt`, recycle unclaimed after `wildLifetime`, Legendary guarantee + forecast), `get(uid) -> Encounter?`, `claim(profile, uid) -> Encounter?, msg` (region unlocked, within `claimRange`, unclaimed, storage not full), `release(uid)`, `consume(uid)` (captured: destroy model, schedule respawn), `isSurge(regionId) -> bool`, `forecast() -> { [regionId] = { nextLegendaryAt, surgeUntil } }` (server time), `ensureTutorialSpawn(profile)` (guarantees a Breeze Bean exists while a player is on tutorial step ≤ 2), `bossEncounter(...)` hooks for Crisis (see Crisis). Encounter = `{ uid, speciesId, regionId, rarity, element, model, root, claimedBy: number?, expiresAt, spawnedAt, legendary, position() }` | Broadcast Legendary spawns (`Rarities.info.broadcast`). |
| `CollectionPadService` | 10 Hz heartbeat. Standing on your own city's collection pad with `bank >= 1` pays once (`collectHoldSeconds` 0), sets `CollectionLastAmount/At`, toasts "N Coins collected!", pushes a snapshot. **One payout per visit**: the latch clears only when the root leaves the pad footprint (a jump or a moment in the air does not re-arm it). | `testCollectionPad` (timer rule) |
| `CosmeticsService` (`S.Cosmetics`) | `refresh(profile, quiet?)` grants everything the player has earned and **only ever adds** (progress moves backwards: a relaunch shuts every region). `grant`, `equip(profile, family, id)` (`""` unequips; refuses anything unowned or of the wrong family), `apply(profile)` publishes the worn aura as the **Player attribute `Aura`**, which is what every client's `AuraController` draws from. `onJoin` (quiet), `onProgress` (region unlock, relaunch, crisis win). | `cosmetics` suite + live block |
| `PurchaseService` (`S.Purchase`, `Main.server` calls `init()` before the router) | `init()` sets `MarketplaceService.ProcessReceipt` and listens for finished pass prompts. `processReceipt(receipt)` returns **NotProcessedYet for every uncertain case** (no player, no profile, save offline, unknown asset id, profile busy, egg blocked by policy) so Roblox re-offers it, and **PurchaseGranted for a PurchaseId already in the ledger**. `settle(profile, product, receipt, save?)` is apply -> record -> save -> acknowledge, rolling the grant back if the save fails; it refuses a duplicate itself. `prompt(profile, kind, id)` refuses `assetId == 0` with "coming soon". `hatch(profile, eggId, count)` (1 or 10) checks storage up front, rolls pity first, grants via `City.grantCreature`. `refreshPasses` / `applyPassPerks` (**must re-run after a relaunch wipes `data.upgrades`**). `testGrant(profile, id)` is Studio + test-adapter only. | `purchases` suite + live block |
| `StudioTester` (Studio only, `Main.server` installs it) | `init()` — once per session, hands each test-adapter profile a Prismatic Rochebreaker deployed on its first free pad so income, banking and the pad can be validated without a capture. Never runs outside Studio or for real data. | n/a |
| `CaptureService` | `init()`, `start(profile, encounterUid) -> ok, msg`, `cancel(profile, reason: string?)`, `isCapturing(profile) -> bool`, `onCharacterRemoved(profile)`, `tick()` (Heartbeat at `Capture.tick`: distance check, progress accumulation `dt x tetherSpeedMult`, grace/break, hazard scheduling every `attackInterval / hazardSpeed`, hazard resolution using the hazard geometry against the catcher's HumanoidRootPart position, hit → `progress -= hitPenalty`, `Notify.knockback`, `perfect = false`; completion → `S.Encounters.consume`, variant via `S.Variants.rollVariant`, `S.City.grantCreature`, `S.Atlas.recordCapture`, quest bumps `captures / perfect / rare_captures / region_captures`, `Notify.captureResult`, tutorial event `capture`) | State in `profile.capture = { uid, encounter, progress, required, outOfRange, perfect, hits, startedAt, nextAttackAt, hazards = {...}, surge }`. Sends `CaptureState` ≤ 10×/s. Only one player per encounter; another player's `start` on a claimed encounter is refused with "Someone is already catching that one." Encounter expiry after 45 s cancels with reason. Death/leave/region-exit/cancel all release the claim. |
| `WorkshopService` | `buyUpgrade(profile, id)`, `unlockRegion(profile, regionId)`, `canAccess(profile, regionId) -> bool` | After purchase: `S.City.applyUpgrades`, `S.Player.applyCharacter`, tutorial events `upgrade` / `unlock:<regionId>`. Refuses beyond `Stats.maxUpgradeLevel`. |
| `AtlasService` | `recordCapture(profile, speciesId, variant, perfect)`, `recordVariant(profile, speciesId, variant)`, `recordRecipe(profile, circuitId)`, `claimMilestone(profile, count)` | Milestone claim once → `S.City.applyUpgrades` shows the decoration; title from `Stats.title`. |
| `VariantService` | `rollVariant(profile, regionId, perfect) -> variant` ("Overcharged" iff perfect and `S.Encounters.isSurge(regionId)`, else "Normal"), `canPrismatic(profile, speciesId) -> bool, reason`, `prismaticUpgrade(profile, uid)` (transforms that one instance, resets the species' `circuitSeconds` and `perfect` counters, `claims += 1`, refuses if already Prismatic; favorites are allowed because the client confirmed explicitly — the server only requires the uid be owned) | |
| `QuestService` | `init()`, `bump(profile, stat, amount, regionId?)`, `claimRepeatable(profile, id)`, `claimDaily(profile, index)`, `ensureDaily(profile)` (rerolls when `dayKey` changed; only regions in `data.regions`; skips `dailyNeedsCircuit` ids unless `Stats.canBuildAnyCircuit`), `tutorialEvent(profile, key)` (keys: `enter_region:<id>`, `capture`, `deploy`, `collect`, `upgrade`, `unlock:<id>`; advances the step whose completion matches), `tutorialAdvance(profile, step)` (info steps only), `sendTutorial(profile)`; a step change sends no `Notify` pop-up while `settings.tutorial == false` | Region entry detection: `QuestService` polls player positions vs region centres every 1 s (cheap, 8 players). Rewards: `Stats.scaledReward`. |
| `RelaunchService` | `perform(profile, anchorUids) -> ok, msg`, `canRelaunch(profile) -> ok, reason` | Refuses during capture, `profile.busy`, `dataState ~= "loaded"`, insufficient coins/species, too many anchors (`Stats.compute().anchorSlots`), unknown uids. Applies the reset as one function, sets `busy` during, saves immediately after. Anchored creatures keep `anchored = true` in data until the next relaunch selection replaces it. |
| `CrisisService` | `init(refs)`, `state() -> CrisisState?`, `onPylonHold(profile, pylonIndex, dt)` | Loop: every `interval`, `warning` s banner → `duration` s active: boss model (`CreatureModels.build(id, "Normal", false, bossScale)` at `refs.arena.bossSpot`, labelled "CRISIS BOSS"), boss hazards use `CaptureService` hazard geometry helpers against every player inside the arena radius (hit = knockback only), pylon prompts hold to add work; success when all pylons done → reward once per qualified participant (`profile.crisisRewarded`), `stats.crisisWins`; timeout → failed. Cleans up boss + resets `profile.crisisWork/Rewarded`. Boss creature is a Legendary from the highest region any online player has unlocked, else `fallbackBoss`. |
| `LeaderboardService` | `init()` | Every 15 s: top rows for `income` (normalCps), `collection` (discovered), `relaunches`; `Notify.leaderboard`; writes `refs.hub.board` text. |
| `VisitService` | `visit(profile, plotIndex)`, `home(profile)`, `cityInfo(plotIndex) -> CityInfo?` | Teleports the character to `VisitorSpot` / own `SpawnPoint`; sets `profile.visiting`. Visitors cannot mutate: CityService/CircuitService check `profile.plotIndex == plot.index` on every action, and the Collect pad ignores non-owners. |
| `RemoteRouter` | `init()` | Binds every client remote: rate limit → type/finite checks → `Profiles.get` → handler → `Notify.player(error)` on failure. Also binds ProximityPrompt triggers (`Prompt` attribute: "Vent", pylons via `PylonIndex`) and `CollectPad` touches. |
| `TestHarness` | `run() -> passed, failed, failures` | Studio-only self tests (`[SelfTest]` lines): config integrity, all 24 builders, machinery builders, data round-trip + sanitize, Stats income math (single factors, circuit once, overdrive x2/0), pair validation (diagonal, overlap), storage full blocks grant, sell refuses favorite, relaunch reset/keep, offline calc bounds, double-claim guards. |

`Main.server.luau` boot order: `Remotes.init()` → `MapBuilder.build()` → plots (`PlotTemplate.build` x8 via CityService.init) → require every system → `DataService.init()`, `Sync.init()`, `Economy.init()`, `Encounters.init(refs)`, `Capture.init()`, `Circuits.init()`, `Quests.init()`, `Crisis.init(refs)`, `Leaderboard.init()`, `Router.init()` → `PlayerService` hooks (existing players too) → `TestHarness.run()` in Studio after 3 s.

## 8. Client modules

`Controllers.GustyAtmosphere.init()` runs the local Gusty visual ambience at 30 Hz:
18 small leaf shapes and three faint curved breeze beams outside the capture
field, plus a subtle warm ColorCorrectionEffect that fades inside the region.
Effects fade out by 180 studs from the character, stop for reduced motion and
respawn gaps, and rebuild when the region Model changes. Reduced flashing disables
beams; CaptureState disables beams and reduces leaves to 20% visibility. No global
Atmosphere, physics forces or camera transforms change. `create(region)` provides
an owned effect with `step(dt, observer?, settings, capturing)` and `destroy()`;
the top-level `destroy()` disconnects its heartbeat/remote and removes local FX.
This pass is visual; no new audio asset is required or supplied.

All UI lives in ONE ScreenGui per module family created with `W.screenGui(name, displayOrder)`. `Widgets` (`client/UI/Widgets.luau`, DONE) provides: `frame label button iconButton badge progress scroll scrollGrid screenGui attachScale tween pop panel registerPanel getPanel openPanel closePanels togglePanel currentPanel onPanelChanged confirm viewport divider card tabs corner stroke padding list grid setButtonColor setEnabled outline gloss shadow iconTile setTileSelected`. `Theme` (DONE) has `colors` (including `colors.disabled`), `elements`, `panels` + `panelColors(name)`, `icons`, `gloss`, `viewport`, `fonts`, `sizes`.

Every module exports `init()` and, where relevant, `update(snap: Snapshot)` (cheap; skip work when hidden). Panels register with `W.panel(gui, "<Name>", "<Title>", size)` and set `panel.refresh = function() update(State.get()) end`.

Panel names (exact strings): `"Creatures"`, `"Atlas"`, `"Recipes"`, `"Workshop"`, `"Quests"`, `"Relaunch"`, `"Settings"`, `"Cities"`, `"Crisis"`.

| Module | Exports | Owner |
|---|---|---|
| `client/UI/HUD.luau` | `init()`, `update(snap)` — top-left: wallet (abbrev + commas tooltip), "City income" cps, bank ("Collectible: 1.2K", red "BANK FULL - step on your collection pad" state; a **Collect** button `Net.fire("CollectBank")` appears only for owners of the Remote Collector upgrade and shows the cooldown seconds while recharging); top-centre: crisis / broadcast banner slot; top-right: forecast strip (one chip per unlocked region: element icon, "Legendary 3:20" / "SURGE"); left sidebar icon buttons in this order: Creatures, Atlas, Recipes, Workshop, Quests, Cities, Relaunch, Settings; bottom-right: data status pill ("Saving..." / "Not saving" when `dataSafe == false` / "Test data" when `testAdapter`); offline claim card when `snap.offline` (`Net.fire("ClaimOffline")`); "Visiting <name> — Go home" chip when `snap.visiting` (`Net.fire("VisitCity", 0)`); title under the player name | UI-A |
| `client/UI/CaptureHUD.luau` | `init()`, `setState(state: CaptureState?)`, `setHazardWarning(text?, color?)`, `setTarget(info?)` (`info.hint` is the per-device control text, decided by CaptureController: "Press E or click" / "Tap Capture" / "Press X") — centre-bottom ring/bar for progress `progress/required`, range indicator (green "In range" / red "Out of range 0.6s"), status line, perfect badge, surge badge, **Cancel** button (`Net.fire("CancelCapture")`); when not capturing but a target is highlighted shows the encounter card (name, rarity icon+label, element, difficulty stars, "Press E / tap Capture") with a big **Capture** button (touch toggle) | UI-A |
| `client/UI/CaptureReveal.luau` | `init()`, `show(result)` — centred card with `W.viewport` of `CreatureModels.build(speciesId, variant)`, rarity + variant line, gold PERFECT pill at the right end of the name row (never over the picture), income line, Close / "Deploy now" (opens Creatures) | UI-A |
| `client/UI/TutorialUI.luau` | `init()`, `setStep(step, done)` — card bottom-right with title/body, "Got it" for info steps (`Net.fire("TutorialAdvance", step)`), Beam from the character to the target (section 9); card and beam both hidden while `snap.settings.tutorial == false` | UI-A |
| `client/UI/Notifications.luau` — DONE | `init()`, `push(kind, text, duration?)`, `broadcast(text, color?)` | — |
| `client/UI/FloatingText.luau` — DONE | `init()`, `show(text, worldPos, color?)` | — |
| `client/UI/CircuitEditorUI.luau` | `init()`, `showSelection(padA: number?, padB: number?, preview: Preview?)`, `hide()`, `showCircuitCard(entry: CircuitEntry, screenPos)` — floating editor: "Select a second pad" prompt, partner highlight legend, preview (recipe name or "No recipe", "+25% each: 12.5/s → 15.6/s"), **Connect** (`Net.fire("ConnectCircuit", a, b)`) / **Disconnect** (`Net.fire("DisconnectCircuit", pad)`), and for an active pair: **Upgrade (cost)** (`UpgradeCircuit`), **Overdrive** with full explanation text (x2 for 20 s, then 15 s off unless you vent at the booth; disabled during active/cooldown with countdown) (`StartOverdrive`) | UI-A |
| `client/UI/CreaturePicker.luau` | `init()`, `open(pad: number)`, `close()` — overlay behind a pad's `ManagePrompt`: title "Pad n"; when occupied, an "On this pad" card with **Send to storage** (`StoreCreature uid`); a scrolling list of stored creatures (name, rarity badge, variant badge, normal cps) sorted by income with **Put here** (`DeployCreature uid pad`) on an empty pad or **Swap in** (`MoveCreature uid pad`, the server sends the occupant to storage) on an occupied one; "Nothing in storage" when empty; Escape / B / tap outside closes. Display estimates only. | Play |
| `client/Controllers/CircuitEditor.luau` | `init()` — click/tap on own plot pads (raycast from screen point against `Workspace.Plots.Plot_n.Pads`; ClickDetector fallback) selects; computes preview client-side from `snap` + `Config.Circuits.recipe` + `Config.Circuits.baseBonus` (display only); highlights valid partners (SelectionBox / neon overlay); gamepad: D-pad cycles pads when standing on the plot. Own plot: `Workspace.Plots` child whose `OwnerUserId == LocalPlayer.UserId`. | UI-A |
| `client/Controllers/CaptureController.luau` | `init()` — target selection: nearest wild creature within 30 studs in front of the camera (mouse hover raycast wins on desktop; gamepad: nearest); E / gamepad ButtonX / touch **Capture** button toggles `StartCapture` / `CancelCapture`; on mouse, left-click on the pointed-at creature also starts (never cancels; skipped while the Containment Tether is equipped, whose own Activated already toggles); renders encounter labels (BillboardGui per nearby wild model, culled > 90 character studs) from attributes; scales wild and deployed PadLabel rows each frame via `Shared.Util.CreatureLabel.resize`, discovering labels at 4 Hz; range ring on the ground around the creature (radius = `snap.derived.tetherRange`); tether Beam from the character to the creature while capturing; hazard telegraphs from `Hazard` events (line: moving translucent wall; ring: expanding torus made of a Cylinder; circles: ground discs that fill; pull: zone disc + gentle pull force on the local HRP while telegraphed) in `workspace.CurrentCamera`-independent folder `Workspace.ClientFX` (client-only); knockback via `Knockback` (`hrp:ApplyImpulse` / `AssemblyLinearVelocity`); respects `reducedMotion` (no shake) and `reducedFlashing` (no strobing). Feeds `CaptureHUD`. | Play |
| `client/Controllers/WorldAnimator.luau` | `init()` — tracks `"Animated"` tagged models via `Animate`; a model whose parts have not replicated yet is retried one frame after each `ChildAdded` / `PrimaryPart` change until it registers (otherwise every wild creature stays a frozen statue while the server roams it), honours `Working == false` (freeze stations/machines), `Overdrive` (speed x2, warm tint pulse), `Cooling` (dim). | Play |
| `client/Controllers/Effects.luau` | `init()`, `play(kind, pos, extra?)`, `sound(name, pos?)` — sounds from `Config.Sounds` (pcall, volume x `snap.settings.sfx`), particle bursts per kind: capture deploy collect circuit overdrive relaunch hit purchase pylon | Play |
| `client/Controllers/RegionGates.luau` | `init()` — for every `"RegionGate"` tagged part: `CanCollide = not snap.regions[RegionId]`, transparency 0.55 when open; writes gate `Forecast` label from `Forecast` events | Play |
| `client/Controllers/PadPrompts.luau` | `init(CreaturePicker)` — on every snapshot, for each `Plots.*.Pads.Pad_n.ManagePrompt`: `Enabled` when the plot's `OwnerUserId` is the local player, `snap.visiting` is nil and `n <= snap.pads.total`, else disabled; `ActionText`/`ObjectText` = "Deploy" / "Pad n" when empty, "Swap" / species name when occupied. `PromptTriggered` on an own-plot `ManagePrompt` opens `CreaturePicker.open(n)`. Click on the pad is unchanged (CircuitEditor). | Play |
| `client/Controllers/RouteLights.luau` | `init()`, `count()` — groups `"RouteChevron"` tagged Neon parts by `RouteId`, ordered by `Index` (1..`Count`), and every 0.08 s runs a bright head with a 3-chevron fading tail along each route toward its destination (higher Index); routes over 320 studs from the camera stay dim; `settings.reducedFlashing` holds every chevron steadily lit with no motion. | Play |
| `client/Controllers/Waypoints.luau` | `init()`, `count()`, `titleHeights()` — one BillboardGui in `PlayerGui` over every `"RegionGate"`, every `"Waypoint"` tagged part (`WaypointName` / `WaypointColor` / `WaypointHeight`) and the player's own plot ("Your City"): the name in the destination's colour pushed to at least 0.55 saturation and at most 0.92 value (`signColor`; pale Frostbite read as white glare), `Theme.fonts.title`, ink `UIStroke` (Contextual), sized in pixels every frame (`RenderStepped`) as 44 x 7.6 studs (title 5, detail 2.6) would be at depth 60, times `(60 / depth) ^ 1.25` with depth clamped to 30..420 studs, so distance tells more than real perspective and a sign never balloons or vanishes (`DistanceLowerLimit` / `DistanceUpperLimit` do nothing, see RELAY traps); `AlwaysOnTop`, `MaxDistance` 900, hidden within 28 studs of the character. A locked gate adds a gold "Unlock X Coins" line while the title is at least 14 px tall; nothing else carries a second line. The outline thickness follows the letter height each frame, 7%, 1-4.5 px. | Play |
| `client/Controllers/CameraGuard.luau` | `init()` — every second, on respawn and when `CurrentCamera` is replaced: if the camera is not `Custom` or its subject is not the live Humanoid, put it back. Stands down while the Camera has a truthy `ScriptedCamera` attribute (tools that borrow the camera set and clear it). The game itself never scripts the camera. | Play |
| `client/Controllers/Input.luau` | `init()`, `onAction(name, cb)`, `isTouch()`, `isGamepad()` — ContextActionService bindings: `Capture` (E / ButtonX / touch button), `Cancel` (Q / ButtonB), `Interact` handled by ProximityPrompts; provides the mobile action buttons container | Play |
| `client/UI/Panels/CreaturesPanel.luau` ("Creatures") | tabs Deployed / Stored / All; sort dropdown (Income, Rarity, Region, Newest, Favorites); rows: viewport, name, rarity icon+label, variant badge, cps, pad number or "Stored"; buttons Deploy (pick a free unlocked pad from a 6x4 mini-grid) `DeployCreature`, Store `StoreCreature`, Move (mini-grid) `MoveCreature`, ★ favorite `SetFavorite`, Sell (`W.confirm`, shows value; disabled for favorites/anchored) `SellCreature`, **Prismatic** button when `snap.mastery[id]` meets `Config.Variants.prismatic` (`W.confirm` mentioning favorites) `PrismaticUpgrade`; header "Storage 12 / 60 · Pads 4 / 6" and a full-storage warning with the fix ("Sell or relaunch to make room") | UI-B |
| `client/UI/Panels/AtlasPanel.luau` ("Atlas") | region tabs; 4 cards per region: viewport (silhouette when undiscovered, `CreatureModels.build(id, "Normal", true)`), name or "???", rarity, income, discovered date, variant badges seen (Normal/⚡/◈), perfect count, owned count from `snap.creatures`; header "Discovered X / 24", region completion "3/4"; milestone row (4/8/12/18/24) with decoration + title and **Claim** (`ClaimMilestone`) / Claimed / Locked | UI-B |
| `client/UI/Panels/RecipeBookPanel.luau` ("Recipes") | 6 recipe cards: discovered → name, elements, visible result, bonus text, count of active pairs; undiscovered → "???" + hint; footer explains adjacency, one pair per creature, upgrade and Overdrive | UI-B |
| `client/UI/Panels/WorkshopPanel.luau` ("Workshop") | tabs Upgrades / Regions; upgrade cards: icon, name, level `x / max`, effect now → next, cost, **Buy** (`BuyUpgrade`) disabled when maxed/unaffordable with the reason; region cards: name, element, base income, cost, **Unlock** (`UnlockRegion`) / Unlocked | UI-B |
| `client/UI/Panels/QuestsPanel.luau` ("Quests") | sections Tutorial (current step; hidden when done or `settings.tutorial == false`), Daily (3 items, progress bars, reward, **Claim** `ClaimDaily index`, "Resets in 4:12:05" from `daily.resetsAt`), Repeatable (progress, cycle count, **Claim** `ClaimQuest id`) | UI-B |
| `client/UI/Panels/RelaunchPanel.luau` ("Relaunch") | current level, multiplier, next: cost vs coins, species vs required (progress bars); two lists "What resets" / "What you keep" from `Config.Relaunch`; anchor picker (choose up to `derived.anchorSlots` owned creatures, viewport + name); list of favorites that would be lost with a mandatory checkbox "I understand"; **Relaunch** → `W.confirm` → `Net.fire("DoRelaunch", uids)`; disabled with reason while capturing / at max | UI-B |
| `client/UI/Panels/SettingsPanel.luau` ("Settings") | sliders Music / Effects (0..1, `SetSetting key value`), toggles Reduced motion / Reduced flashing / Notifications / Tutorial (`tutorial`, default on; off hides the tutorial card, route beam, Quests tutorial row and the server's step pop-ups, while `tutorialStep` keeps advancing so switching it on resumes in place); data status line; controls guide text (mouse / touch / controller) | UI-B |
| `client/UI/Panels/CitiesPanel.luau` ("Cities") | tabs Leaderboards (income / collection / relaunches from `Leaderboard` events) and Visit (one row per plot, `Config.MaxPlayers`: owner name or "Empty", **Visit** `VisitCity n`, **Inspect** → `Net.invoke("GetCityInfo", n)` shows creatures + recipes) | UI-B |
| `client/UI/Panels/CrisisPanel.luau` ("Crisis") + banner | `init()`, `update(snap)`, `setCrisis(state?)` — banner (phase, timer, boss name, pylon progress x3, "Your work: 3.2 / 4 ✓") and the panel with rules and reward range | UI-B |

`Main.client.luau` (lead) wires remotes → modules, init order, panel prompts (`OpensPanel` attribute), Escape closes panels, applies `snap.settings` to `W.sfxEnabled`.

## 9. Tutorial arrow targets (client resolves `Config.Quests.tutorial[step].target`)

| Key | Target |
|---|---|
| `region:<id>` | `Workspace.Regions.<id>.Entrance` |
| `species:<id>` | nearest model in any `Regions.*.Wild` with `SpeciesId == id`, else `Regions.gusty_gardens.Entrance` |
| `plot:pad1` | own plot `Pads.Pad_1` |
| `plot:collect` | own plot `CollectPad` |
| `hub:workshop` | `Workspace.Hub.Workshop.Terminal` |
| `none` | no beam |

## 10. Style rules
- Toy-like, chunky: every visible frame has a rounded corner and a dark stroke (`W.frame{ radius=…, stroke=Theme.colors.ink }`).
- Kid-friendly candy style: each panel has its own colours (Theme.panels); light text always carries a dark outline (W.outline, default on); buttons, headers and tiles are glossy (W.gloss); panels and dialogs drop a shadow (W.shadow). Check with lune run tools/verify_theme.luau and tools/ui_audit.luau.
- Text ≥ 13 px. Buttons ≥ 44 px tall (touch). Don't use TextScaled for body text.
- Numbers through `Format.abbreviate`; times through `Format.clock` / `Format.duration`.
- Rarity is always named in text; colour is secondary. Plain text uses `Config.Rarities.label` (icon + name). `W.badge` pills use the plain name (`Config.Rarities.info[r].label`), to keep pills uniform. Rarity and variant glyphs must draw in every Theme font (Gotham shows a box for a missing glyph; Fredoka drops it): the current set is ● ◆ ★ ❖ ☀ ✿ ◎ ◉ (Common → Astral) and ◈ ⚡ for variants. `tools/verify_theme.luau` fails any glyph outside its Studio-verified safe list.
- No em-dashes in game copy; short strings for 6–12 year olds. No cash shop, no eggs, no random paid rolls.
- Never derive cost/rate/ownership/capture results on the client; render `snap` only (the circuit preview is a display estimate the server re-validates).
- Server: never trust remote arguments; typecheck every argument; use `RateLimiter`; reject non-finite numbers.
- Popups never cover the centre of the screen during capture; hazard warnings stay readable.

### Creature label presentation

`Shared.Util.CreatureLabel.create(model, name) -> BillboardGui`,
`setIdentity(gui, speciesId, variant?, favorite?)`, `setDetail(gui, detail, status?)`,
`resize(gui, camera)`. Label Adornee is the creature PrimaryPart, not the model
bounding-box center. create/setIdentity/setDetail run on either side; resize is
client presentation only and tolerates partially replicated city labels. Labels
use a supported diamond marker and explicit rarity text; difficulty uses N/5.

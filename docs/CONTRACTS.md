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
   .Workshop                         -- Model (building) at (-42, 0, 22); child Part `Terminal` with ProximityPrompt, attribute OpensPanel = "Workshop"
   .Beacon                           -- Model (Relaunch Beacon) at (42, 0, 22); child Part `Terminal`, OpensPanel = "Relaunch"
   .AtlasKiosk                       -- Model at (0, 0, 48); child Part `Terminal`, OpensPanel = "Atlas"
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
   .GateSign                         -- Part with SurfaceGui `Gui` -> TextLabels `Title` ("Splashwater Bay"), `Cost` ("Unlock: 2,500 Coins" / "OPEN"), `Forecast` (client writes "Legendary in 3:20" / "SURGE!")
   .Entrance                         -- Part (invisible) just inside the gate; tutorial arrow / VisitCity target
   attributes: RegionId, Element, Centre (Vector3), SpawnRadius (number, 55)
Workspace.Effects                    -- Folder for temporary parts (hazard telegraph visuals are CLIENT-side and go in the client's own folder; server never spawns telegraph geometry)
```

Wild creature model (in `Regions.<id>.Wild`): built with `CreatureModels.build(id)`, attributes `EncounterUid, SpeciesId, Rarity, Element, RegionId, Difficulty, ClaimedBy (userId, 0 = free), ExpiresAt (server time, 0 = unclaimed), Legendary (bool)` plus `PathFrom/PathTo/PathStart/PathDuration` for roaming and `BasePivot`. CollectionService tags: `"Animated"`, `"Wild"`. The client draws the label (name, rarity icon+text, element, difficulty stars, "Claimed by X") from these attributes; the server adds no BillboardGui.

### Plot local frame (front = local -Z, toward the hub). `PlotTemplate.build(cframe, index)` creates:

| Element | Local offset / size |
|---|---|
| Platform | 60 x 1 x 60 at (0, 0, 0); top y = 0.5, hazard-stripe kerb |
| `Pads.Pad_<1..24>` | 6 x 0.6 x 6 Parts, top y = 1.1; col c (1..6) at x = -20 + 8*(c-1); row r (1..4) at z = -6 + 8*(r-1). Index = (r-1)*6 + c. Attributes `PadIndex`, `Unlocked` (bool). Locked pads are dark + 0.5 transparent. Child `ManagePrompt` (ProximityPrompt, E, range 7, `Enabled = false`): the owner's client enables and labels it (`Controllers.PadPrompts`); the server never reads it. |
| `Stations.Station_<pad>` | Folder slot; PlotTemplate parents the MachineryBuilders work station here at pad position + (0, 0, 3.2) (behind the creature, toward +Z) when a creature is deployed. Server (CityService) owns this. |
| `Machines` | Folder; circuit machine models go here (CircuitService), pivoted at the midpoint of the two pads, y = 1.1 |
| `Booth` | Model at (-24, 0, -22): control booth. Child Part `VentButton` with attribute `Prompt = "Vent"` (server adds ProximityPrompt), child Part `Console` (SurfaceGui `Gui` -> TextLabel `Text`: overdrive status) |
| `CollectPad` | Part 8 x 0.4 x 8 at (0, 0.7, -23), Neon coin colour; attribute `Touch = "Collect"`; BillboardGui `Label` -> TextLabel `Text` ("Bank: 1.2K" / "BANK FULL") |
| `Billboard` | Part 16 x 8 x 1 at (22, 9, -27) facing -Z, SurfaceGui `Gui` -> TextLabels `Title` (owner + title) and `Earnings` ("152/s") |
| `SpawnPoint` | SpawnLocation at (0, 0.5, -34) outside the front kerb, `Enabled = false` (server sets `player.RespawnLocation`) |
| `VisitorSpot` | Part (invisible) at (8, 0, -34) |
| `Decor.Tier_<1..3>` | Models, hidden until the decoration upgrade tier is bought (`PlotTemplate.setDecorationTier`) |
| `Rewards.<decorationKey>` | Folder slots for milestone decorations (`PlotTemplate.setRewardDecoration`) around the platform edge |
| `Garden` | Model: the "expanding industrial garden" — pipes and planters that grow with tier |

```lua
local PlotTemplate = require(script.Parent.Map.PlotTemplate)
local plot = PlotTemplate.build(cframe: CFrame, index: number)
-- plot = { model, cframe, pads = { [1..24] = Part }, stations = { [1..24] = Folder }, machines: Folder, booth = { model, ventButton: Part, console: TextLabel },
--          collectPad: Part, collectLabel: TextLabel, billboardTitle: TextLabel, billboardEarnings: TextLabel, spawnPoint: SpawnLocation, visitorSpot: Part }
PlotTemplate.setOwner(plot, userId: number, name: string)
PlotTemplate.setPadUnlocked(plot, pad, unlocked: boolean)
PlotTemplate.setDecorationTier(plot, tier: number)              -- 0..3
PlotTemplate.setRewardDecoration(plot, key: string, shown: boolean)
PlotTemplate.padCFrame(plot, pad) -> CFrame                       -- world, top surface centre, facing -Z
PlotTemplate.pairCFrame(plot, padA, padB) -> CFrame               -- midpoint for a circuit machine
PlotTemplate.reset(plot)                                          -- clear stations, machines, labels (owner left)
```

## 6. Server map contract (`ServerScriptService.Server.Map`)

```lua
local MapBuilder = require(script.Parent.Map.MapBuilder)
local refs = MapBuilder.build()
-- refs = {
--   spawn: SpawnLocation,
--   plots = { [1..8] = CFrame },                            -- plot centre, ground level, LookVector toward origin
--   regions = { [regionId] = { model: Model, centre: Vector3, spawnRadius: number, gate: Part, gateSign = { title: TextLabel, cost: TextLabel, forecast: TextLabel }, entrance: Part, wild: Folder } },
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
| `CityService` | `init(refs, PlotTemplate)`, `assign(profile) -> plot?`, `release(profile)`, `plotOf(index) -> plot?`, `grantCreature(profile, speciesId, variant, perfect) -> uid?, msg` (refuses when `Stats.storageFull`), `deploy(profile, uid, pad)`, `store(profile, uid)`, `move(profile, uid, pad)` (swap if occupied), `sell(profile, uid)` (refuses favorites and anchored; pays `Stats.sellValue`), `setFavorite(profile, uid, bool)`, `refreshPad(profile, pad)` (creature model + station + per-pad BillboardGui label "Name · ★ Rare · ⚡ Overcharged · 12.5/s"), `refreshAll(profile)`, `refreshLabels(profile)` (collect pad bank text, billboard earnings; called by Economy every tick at most 1/s), `applyUpgrades(profile)` (pad unlock visuals from `Stats.compute().padsTotal`, decoration tier, reward decorations) | After deploy/store/move/sell call `S.Circuits.recalculate(profile)`. Pad creature models are tagged `"Animated"`, attribute `Working = true`. |
| `CircuitService` | `init()`, `connect(profile, padA, padB)`, `disconnect(profile, pad)`, `upgrade(profile, padA, padB)`, `startOverdrive(profile, padA, padB)`, `vent(profile)` (booth prompt; succeeds only while some pair is in the active phase and not yet vented), `recalculate(profile)` (prunes invalid `data.circuits` pairs, rebuilds machine models under `plot.machines`, updates `Working/Overdrive/Cooling` attributes, records recipes in the Atlas on first activation via `S.Atlas.recordRecipe`, bumps quest `connects` on connect), `tick()` (advances overdrive phases active → cooldown/idle; sets `profile.dirty`) | Overdrive state is keyed by pair key in `profile.overdrives` and is NOT reset by disconnect/reconnect/replace while a phase runs; `startOverdrive` is refused during active or cooldown. Circuit upgrades are keyed by pair key for the current run (`data.circuitUpgrades`). |
| `EncounterService` | `init(refs)`, `tick()` loop (per region: keep `populationCap` wild creatures, respawn after `respawnDelay`, roam legs via Path* attributes, expire claims at `ExpiresAt`, recycle unclaimed after `wildLifetime`, Legendary guarantee + forecast), `get(uid) -> Encounter?`, `claim(profile, uid) -> Encounter?, msg` (region unlocked, within `claimRange`, unclaimed, storage not full), `release(uid)`, `consume(uid)` (captured: destroy model, schedule respawn), `isSurge(regionId) -> bool`, `forecast() -> { [regionId] = { nextLegendaryAt, surgeUntil } }` (server time), `ensureTutorialSpawn(profile)` (guarantees a Breeze Bean exists while a player is on tutorial step ≤ 2), `bossEncounter(...)` hooks for Crisis (see Crisis). Encounter = `{ uid, speciesId, regionId, rarity, element, model, root, claimedBy: number?, expiresAt, spawnedAt, legendary, position() }` | Broadcast Legendary spawns (`Rarities.info.broadcast`). |
| `CollectionPadService` | 10 Hz heartbeat. Standing on your own city's collection pad with `bank >= 1` pays once (`collectHoldSeconds` 0), sets `CollectionLastAmount/At`, toasts "N Coins collected!", pushes a snapshot. **One payout per visit**: the latch clears only when the root leaves the pad footprint (a jump or a moment in the air does not re-arm it). | `testCollectionPad` (timer rule) |
| `StudioTester` (Studio only, `Main.server` installs it) | `init()` — once per session, hands each test-adapter profile a Prismatic Big Whoops deployed on its first free pad (5,120 Coins/s) so income, banking and the pad can be validated without a capture. Never runs outside Studio or for real data. | n/a |
| `CaptureService` | `init()`, `start(profile, encounterUid) -> ok, msg`, `cancel(profile, reason: string?)`, `isCapturing(profile) -> bool`, `onCharacterRemoved(profile)`, `tick()` (Heartbeat at `Capture.tick`: distance check, progress accumulation `dt x tetherSpeedMult`, grace/break, hazard scheduling every `attackInterval / hazardSpeed`, hazard resolution using the hazard geometry against the catcher's HumanoidRootPart position, hit → `progress -= hitPenalty`, `Notify.knockback`, `perfect = false`; completion → `S.Encounters.consume`, variant via `S.Variants.rollVariant`, `S.City.grantCreature`, `S.Atlas.recordCapture`, quest bumps `captures / perfect / rare_captures / region_captures`, `Notify.captureResult`, tutorial event `capture`) | State in `profile.capture = { uid, encounter, progress, required, outOfRange, perfect, hits, startedAt, nextAttackAt, hazards = {...}, surge }`. Sends `CaptureState` ≤ 10×/s. Only one player per encounter; another player's `start` on a claimed encounter is refused with "Someone is already catching that one." Encounter expiry after 45 s cancels with reason. Death/leave/region-exit/cancel all release the claim. |
| `WorkshopService` | `buyUpgrade(profile, id)`, `unlockRegion(profile, regionId)`, `canAccess(profile, regionId) -> bool` | After purchase: `S.City.applyUpgrades`, `S.Player.applyCharacter`, tutorial events `upgrade` / `unlock:<regionId>`. Refuses beyond `Stats.maxUpgradeLevel`. |
| `AtlasService` | `recordCapture(profile, speciesId, variant, perfect)`, `recordVariant(profile, speciesId, variant)`, `recordRecipe(profile, circuitId)`, `claimMilestone(profile, count)` | Milestone claim once → `S.City.applyUpgrades` shows the decoration; title from `Stats.title`. |
| `VariantService` | `rollVariant(profile, regionId, perfect) -> variant` ("Overcharged" iff perfect and `S.Encounters.isSurge(regionId)`, else "Normal"), `canPrismatic(profile, speciesId) -> bool, reason`, `prismaticUpgrade(profile, uid)` (transforms that one instance, resets the species' `circuitSeconds` and `perfect` counters, `claims += 1`, refuses if already Prismatic; favorites are allowed because the client confirmed explicitly — the server only requires the uid be owned) | |
| `QuestService` | `init()`, `bump(profile, stat, amount, regionId?)`, `claimRepeatable(profile, id)`, `claimDaily(profile, index)`, `ensureDaily(profile)` (rerolls when `dayKey` changed; only regions in `data.regions`; skips `dailyNeedsCircuit` ids unless `Stats.canBuildAnyCircuit`), `tutorialEvent(profile, key)` (keys: `enter_region:<id>`, `capture`, `deploy`, `collect`, `upgrade`, `unlock:<id>`; advances the step whose completion matches), `tutorialAdvance(profile, step)` (info steps only), `sendTutorial(profile)` | Region entry detection: `QuestService` polls player positions vs region centres every 1 s (cheap, 8 players). Rewards: `Stats.scaledReward`. |
| `RelaunchService` | `perform(profile, anchorUids) -> ok, msg`, `canRelaunch(profile) -> ok, reason` | Refuses during capture, `profile.busy`, `dataState ~= "loaded"`, insufficient coins/species, too many anchors (`Stats.compute().anchorSlots`), unknown uids. Applies the reset as one function, sets `busy` during, saves immediately after. Anchored creatures keep `anchored = true` in data until the next relaunch selection replaces it. |
| `CrisisService` | `init(refs)`, `state() -> CrisisState?`, `onPylonHold(profile, pylonIndex, dt)` | Loop: every `interval`, `warning` s banner → `duration` s active: boss model (`CreatureModels.build(id, "Normal", false, bossScale)` at `refs.arena.bossSpot`, labelled "CRISIS BOSS"), boss hazards use `CaptureService` hazard geometry helpers against every player inside the arena radius (hit = knockback only), pylon prompts hold to add work; success when all pylons done → reward once per qualified participant (`profile.crisisRewarded`), `stats.crisisWins`; timeout → failed. Cleans up boss + resets `profile.crisisWork/Rewarded`. Boss creature is a Legendary from the highest region any online player has unlocked, else `fallbackBoss`. |
| `LeaderboardService` | `init()` | Every 15 s: top rows for `income` (normalCps), `collection` (discovered), `relaunches`; `Notify.leaderboard`; writes `refs.hub.board` text. |
| `VisitService` | `visit(profile, plotIndex)`, `home(profile)`, `cityInfo(plotIndex) -> CityInfo?` | Teleports the character to `VisitorSpot` / own `SpawnPoint`; sets `profile.visiting`. Visitors cannot mutate: CityService/CircuitService check `profile.plotIndex == plot.index` on every action, and the Collect pad ignores non-owners. |
| `RemoteRouter` | `init()` | Binds every client remote: rate limit → type/finite checks → `Profiles.get` → handler → `Notify.player(error)` on failure. Also binds ProximityPrompt triggers (`Prompt` attribute: "Vent", pylons via `PylonIndex`) and `CollectPad` touches. |
| `TestHarness` | `run() -> passed, failed, failures` | Studio-only self tests (`[SelfTest]` lines): config integrity, all 24 builders, machinery builders, data round-trip + sanitize, Stats income math (single factors, circuit once, overdrive x2/0), pair validation (diagonal, overlap), storage full blocks grant, sell refuses favorite, relaunch reset/keep, offline calc bounds, double-claim guards. |

`Main.server.luau` boot order: `Remotes.init()` → `MapBuilder.build()` → plots (`PlotTemplate.build` x8 via CityService.init) → require every system → `DataService.init()`, `Sync.init()`, `Economy.init()`, `Encounters.init(refs)`, `Capture.init()`, `Circuits.init()`, `Quests.init()`, `Crisis.init(refs)`, `Leaderboard.init()`, `Router.init()` → `PlayerService` hooks (existing players too) → `TestHarness.run()` in Studio after 3 s.

## 8. Client modules

All UI lives in ONE ScreenGui per module family created with `W.screenGui(name, displayOrder)`. `Widgets` (`client/UI/Widgets.luau`, DONE) provides: `frame label button iconButton badge progress scroll scrollGrid screenGui attachScale tween pop panel registerPanel getPanel openPanel closePanels togglePanel currentPanel onPanelChanged confirm viewport divider card tabs corner stroke padding list grid setButtonColor setEnabled`. `Theme` (DONE) has `colors`, `elements`, `fonts`, `sizes`.

Every module exports `init()` and, where relevant, `update(snap: Snapshot)` (cheap; skip work when hidden). Panels register with `W.panel(gui, "<Name>", "<Title>", size)` and set `panel.refresh = function() update(State.get()) end`.

Panel names (exact strings): `"Creatures"`, `"Atlas"`, `"Recipes"`, `"Workshop"`, `"Quests"`, `"Relaunch"`, `"Settings"`, `"Cities"`, `"Crisis"`.

| Module | Exports | Owner |
|---|---|---|
| `client/UI/HUD.luau` | `init()`, `update(snap)` — top-left: wallet (abbrev + commas tooltip), "City income" cps, bank ("Collectible: 1.2K" + **Collect** button `Net.fire("CollectBank")`, red "BANK FULL" state); top-centre: crisis / broadcast banner slot; top-right: forecast strip (one chip per unlocked region: element icon, "Legendary 3:20" / "SURGE"); left sidebar icon buttons in this order: Creatures, Atlas, Recipes, Workshop, Quests, Cities, Relaunch, Settings; bottom-right: data status pill ("Saving..." / "Not saving" when `dataSafe == false` / "Test data" when `testAdapter`); offline claim card when `snap.offline` (`Net.fire("ClaimOffline")`); "Visiting <name> — Go home" chip when `snap.visiting` (`Net.fire("VisitCity", 0)`); title under the player name | UI-A |
| `client/UI/CaptureHUD.luau` | `init()`, `setState(state: CaptureState?)`, `setHazardWarning(text?, color?)`, `setTarget(info?)` (`info.hint` is the per-device control text, decided by CaptureController: "Press E or click" / "Tap Capture" / "Press X") — centre-bottom ring/bar for progress `progress/required`, range indicator (green "In range" / red "Out of range 0.6s"), status line, perfect badge, surge badge, **Cancel** button (`Net.fire("CancelCapture")`); when not capturing but a target is highlighted shows the encounter card (name, rarity icon+label, element, difficulty stars, "Press E / tap Capture") with a big **Capture** button (touch toggle) | UI-A |
| `client/UI/CaptureReveal.luau` | `init()`, `show(result)` — centred card with `W.viewport` of `CreatureModels.build(speciesId, variant)`, rarity + variant line, gold PERFECT pill at the right end of the name row (never over the picture), income line, Close / "Deploy now" (opens Creatures) | UI-A |
| `client/UI/TutorialUI.luau` | `init()`, `setStep(step, done)` — card bottom-right with title/body, "Got it" for info steps (`Net.fire("TutorialAdvance", step)`), Beam from the character to the target (section 9) | UI-A |
| `client/UI/Notifications.luau` — DONE | `init()`, `push(kind, text, duration?)`, `broadcast(text, color?)` | — |
| `client/UI/FloatingText.luau` — DONE | `init()`, `show(text, worldPos, color?)` | — |
| `client/UI/CircuitEditorUI.luau` | `init()`, `showSelection(padA: number?, padB: number?, preview: Preview?)`, `hide()`, `showCircuitCard(entry: CircuitEntry, screenPos)` — floating editor: "Select a second pad" prompt, partner highlight legend, preview (recipe name or "No recipe", "+25% each: 12.5/s → 15.6/s"), **Connect** (`Net.fire("ConnectCircuit", a, b)`) / **Disconnect** (`Net.fire("DisconnectCircuit", pad)`), and for an active pair: **Upgrade (cost)** (`UpgradeCircuit`), **Overdrive** with full explanation text (x2 for 20 s, then 15 s off unless you vent at the booth; disabled during active/cooldown with countdown) (`StartOverdrive`) | UI-A |
| `client/UI/CreaturePicker.luau` | `init()`, `open(pad: number)`, `close()` — overlay behind a pad's `ManagePrompt`: title "Pad n"; when occupied, an "On this pad" card with **Send to storage** (`StoreCreature uid`); a scrolling list of stored creatures (name, rarity badge, variant badge, normal cps) sorted by income with **Put here** (`DeployCreature uid pad`) on an empty pad or **Swap in** (`MoveCreature uid pad`, the server sends the occupant to storage) on an occupied one; "Nothing in storage" when empty; Escape / B / tap outside closes. Display estimates only. | Play |
| `client/Controllers/CircuitEditor.luau` | `init()` — click/tap on own plot pads (raycast from screen point against `Workspace.Plots.Plot_n.Pads`; ClickDetector fallback) selects; computes preview client-side from `snap` + `Config.Circuits.recipe` + `Config.Circuits.baseBonus` (display only); highlights valid partners (SelectionBox / neon overlay); gamepad: D-pad cycles pads when standing on the plot. Own plot: `Workspace.Plots` child whose `OwnerUserId == LocalPlayer.UserId`. | UI-A |
| `client/Controllers/CaptureController.luau` | `init()` — target selection: nearest wild creature within 30 studs in front of the camera (mouse hover raycast wins on desktop; gamepad: nearest); E / gamepad ButtonX / touch **Capture** button toggles `StartCapture` / `CancelCapture`; on mouse, left-click on the pointed-at creature also starts (never cancels; skipped while the Containment Tether is equipped, whose own Activated already toggles); renders encounter labels (BillboardGui per nearby wild model, culled > 90 studs) from attributes; range ring on the ground around the creature (radius = `snap.derived.tetherRange`); tether Beam from the character to the creature while capturing; hazard telegraphs from `Hazard` events (line: moving translucent wall; ring: expanding torus made of a Cylinder; circles: ground discs that fill; pull: zone disc + gentle pull force on the local HRP while telegraphed) in `workspace.CurrentCamera`-independent folder `Workspace.ClientFX` (client-only); knockback via `Knockback` (`hrp:ApplyImpulse` / `AssemblyLinearVelocity`); respects `reducedMotion` (no shake) and `reducedFlashing` (no strobing). Feeds `CaptureHUD`. | Play |
| `client/Controllers/WorldAnimator.luau` | `init()` — tracks `"Animated"` tagged models via `Animate`; a model whose parts have not replicated yet is retried one frame after each `ChildAdded` / `PrimaryPart` change until it registers (otherwise every wild creature stays a frozen statue while the server roams it), honours `Working == false` (freeze stations/machines), `Overdrive` (speed x2, warm tint pulse), `Cooling` (dim). | Play |
| `client/Controllers/Effects.luau` | `init()`, `play(kind, pos, extra?)`, `sound(name, pos?)` — sounds from `Config.Sounds` (pcall, volume x `snap.settings.sfx`), particle bursts per kind: capture deploy collect circuit overdrive relaunch hit purchase pylon | Play |
| `client/Controllers/RegionGates.luau` | `init()` — for every `"RegionGate"` tagged part: `CanCollide = not snap.regions[RegionId]`, transparency 0.55 when open; writes gate `Forecast` label from `Forecast` events | Play |
| `client/Controllers/PadPrompts.luau` | `init(CreaturePicker)` — on every snapshot, for each `Plots.*.Pads.Pad_n.ManagePrompt`: `Enabled` when the plot's `OwnerUserId` is the local player, `snap.visiting` is nil and `n <= snap.pads.total`, else disabled; `ActionText`/`ObjectText` = "Deploy" / "Pad n" when empty, "Swap" / species name when occupied. `PromptTriggered` on an own-plot `ManagePrompt` opens `CreaturePicker.open(n)`. Click on the pad is unchanged (CircuitEditor). | Play |
| `client/Controllers/RouteLights.luau` | `init()`, `count()` — groups `"RouteChevron"` tagged Neon parts by `RouteId`, ordered by `Index` (1..`Count`), and every 0.08 s runs a bright head with a 3-chevron fading tail along each route toward its destination (higher Index); routes over 320 studs from the camera stay dim; `settings.reducedFlashing` holds every chevron steadily lit with no motion. | Play |
| `client/Controllers/Waypoints.luau` | `init()`, `count()` — an always-on-top BillboardGui (250x62 px, `MaxDistance` 900) over every `"RegionGate"` (name, region colour bar, "Element · N away" or "Unlock X Coins · N away" when locked), every `"Waypoint"` tagged part (`WaypointName` / `WaypointColor` / `WaypointHeight`), and the player's own plot ("Your City"); hidden within 28 studs. Distance refreshes every 0.25 s. | Play |
| `client/Controllers/CameraGuard.luau` | `init()` — every second, on respawn and when `CurrentCamera` is replaced: if the camera is not `Custom` or its subject is not the live Humanoid, put it back. Stands down while the Camera has a truthy `ScriptedCamera` attribute (tools that borrow the camera set and clear it). The game itself never scripts the camera. | Play |
| `client/Controllers/Input.luau` | `init()`, `onAction(name, cb)`, `isTouch()`, `isGamepad()` — ContextActionService bindings: `Capture` (E / ButtonX / touch button), `Cancel` (Q / ButtonB), `Interact` handled by ProximityPrompts; provides the mobile action buttons container | Play |
| `client/UI/Panels/CreaturesPanel.luau` ("Creatures") | tabs Deployed / Stored / All; sort dropdown (Income, Rarity, Region, Newest, Favorites); rows: viewport, name, rarity icon+label, variant badge, cps, pad number or "Stored"; buttons Deploy (pick a free unlocked pad from a 6x4 mini-grid) `DeployCreature`, Store `StoreCreature`, Move (mini-grid) `MoveCreature`, ★ favorite `SetFavorite`, Sell (`W.confirm`, shows value; disabled for favorites/anchored) `SellCreature`, **Prismatic** button when `snap.mastery[id]` meets `Config.Variants.prismatic` (`W.confirm` mentioning favorites) `PrismaticUpgrade`; header "Storage 12 / 60 · Pads 4 / 6" and a full-storage warning with the fix ("Sell or relaunch to make room") | UI-B |
| `client/UI/Panels/AtlasPanel.luau` ("Atlas") | region tabs; 4 cards per region: viewport (silhouette when undiscovered, `CreatureModels.build(id, "Normal", true)`), name or "???", rarity, income, discovered date, variant badges seen (Normal/⚡/◈), perfect count, owned count from `snap.creatures`; header "Discovered X / 24", region completion "3/4"; milestone row (4/8/12/18/24) with decoration + title and **Claim** (`ClaimMilestone`) / Claimed / Locked | UI-B |
| `client/UI/Panels/RecipeBookPanel.luau` ("Recipes") | 6 recipe cards: discovered → name, elements, visible result, bonus text, count of active pairs; undiscovered → "???" + hint; footer explains adjacency, one pair per creature, upgrade and Overdrive | UI-B |
| `client/UI/Panels/WorkshopPanel.luau` ("Workshop") | tabs Upgrades / Regions; upgrade cards: icon, name, level `x / max`, effect now → next, cost, **Buy** (`BuyUpgrade`) disabled when maxed/unaffordable with the reason; region cards: name, element, base income, cost, **Unlock** (`UnlockRegion`) / Unlocked | UI-B |
| `client/UI/Panels/QuestsPanel.luau` ("Quests") | sections Tutorial (current step), Daily (3 items, progress bars, reward, **Claim** `ClaimDaily index`, "Resets in 4:12:05" from `daily.resetsAt`), Repeatable (progress, cycle count, **Claim** `ClaimQuest id`) | UI-B |
| `client/UI/Panels/RelaunchPanel.luau` ("Relaunch") | current level, multiplier, next: cost vs coins, species vs required (progress bars); two lists "What resets" / "What you keep" from `Config.Relaunch`; anchor picker (choose up to `derived.anchorSlots` owned creatures, viewport + name); list of favorites that would be lost with a mandatory checkbox "I understand"; **Relaunch** → `W.confirm` → `Net.fire("DoRelaunch", uids)`; disabled with reason while capturing / at max | UI-B |
| `client/UI/Panels/SettingsPanel.luau` ("Settings") | sliders Music / Effects (0..1, `SetSetting key value`), toggles Reduced motion / Reduced flashing / Notifications; data status line; controls guide text (mouse / touch / controller) | UI-B |
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
- Text ≥ 13 px. Buttons ≥ 44 px tall (touch). Don't use TextScaled for body text.
- Numbers through `Format.abbreviate`; times through `Format.clock` / `Format.duration`.
- Rarity always as icon + text (`Config.Rarities.label`), colour is secondary.
- No em-dashes in game copy; short strings for 6–12 year olds. No cash shop, no eggs, no random paid rolls.
- Never derive cost/rate/ownership/capture results on the client; render `snap` only (the circuit preview is a display estimate the server re-validates).
- Server: never trust remote arguments; typecheck every argument; use `RateLimiter`; reject non-finite numbers.
- Popups never cover the centre of the screen during capture; hazard warnings stay readable.

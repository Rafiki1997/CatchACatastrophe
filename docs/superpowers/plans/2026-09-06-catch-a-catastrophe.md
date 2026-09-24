# Catch a Catastrophe! Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A complete, playable 8-player Roblox simulation/tycoon game built as a Rojo project that compiles to one place file: capture living disasters in six regions, put them to work on a city plot, connect Disaster Circuits, collect, upgrade, relaunch.

**Architecture:** Shared data-driven Config (all balance numbers) + procedural part-built models (ModelKit) used by both server and client. Server owns every rule (captures, hazards, economy, circuits, upgrades, quests, relaunch, persistence). Client renders a `Snapshot` the server pushes, animates world models locally from attributes, renders hazard telegraphs from server events, and sends intent via a fixed remote list. Map is generated at runtime from code.

**Tech Stack:** Roblox Luau (strict), Rojo 7.7, DataStoreService (+ in-memory Studio test adapter), ProximityPrompts, ViewportFrames, Beams, Studio for playtesting via MCP.

**Spec:** `docs/superpowers/specs/2026-09-06-catch-a-catastrophe-spec.md`
**Contracts:** `docs/CONTRACTS.md` (interfaces between every module; the binding reference for implementers)

## Global Constraints

- Max 8 players (`Config.MaxPlayers = 8`). Everything original; only `rbxasset://` sounds; no invented asset ids.
- No eggs, hatching, stealing, breeding, paid random rolls, cash shop.
- Server owns captures, encounter claims, currencies, rewards, inventory, pads, circuits, upgrades, offline, relaunch. Clients send intent only. Every remote argument type-checked, finite, ownership/range/state validated, rate-limited.
- Exactly 24 species (`Config.Species`), 6 regions with base rates 4/8/16/32/64/128, rarity multipliers 1/2.5/7/20, spawn weights 60/28/10/2, region unlock costs 0/2.5K/15K/75K/300K/1M.
- Capture: tether within 18 studs, 8 s contact base (rarity 8/10/13/16, cap 16), leaving range > 1 s or a hit removes 2 s (clamp 0), encounter expires at 45 s, one claimant per encounter, perfect = no hit and no break.
- Circuits: orthogonal adjacency only, one pair per creature, six recipes, +25% each member, upgraded +40%, Overdrive x2 for 20 s then 0 for 15 s unless vented, cannot restart during either phase, reconnect/replace never resets it.
- Income factors applied exactly once: region base x rarity x variant x relaunch x circuit state. Fractional internally, round for display.
- Storage 60 → 120; only deployed creatures produce; full storage blocks encounters with an explanation. Bank caps at one hour of normal production; offline 25% capped 4 h, once-only claim.
- Variants: Normal 1x, Overcharged 1.5x (perfect capture during surge), Prismatic 2x (30 circuit minutes + 3 perfect captures of the species, transforms one instance, counters reset).
- Relaunch: cost ceil(100000 x 3^R), species min(6 + 2R, 24), +25% per level, 6 + R pads, anchors 1/2/3 at levels 0/3/6, hard cap 24 deployed; explicit reset/keep lists; select anchors before confirming; favorites that would be lost listed and acknowledged.
- Crisis every 8 min, 90 s, 3 pylons, work scaled to participants, once-only reward clamp(cps x 120, 300, 150000), meaningful participation only.
- UI: phone + controller usable, rarity = icon + text + colour, music/effects sliders, reduced motion, reduced flashing, no constant popups, loading/saving states shown.
- Versioned saves, UpdateAsync, session ownership, bounded retries, autosave/leave/shutdown saves, never save a default over a failed load, test adapter separate from production keys.

## Task map (files → owner)

| # | Task | Files | Owner |
|---|---|---|---|
| 0 | Scaffold, Config, Util, Remotes, Types, ModelKit, Animate, CreatureModels, Theme, Widgets, Net, State, Notifications, FloatingText, Profiles, Stats, Notify, CONTRACTS | done | lead |
| 1 | Creature builders Wind + Water (8) | `src/shared/Models/CreatureBuilders/WindWater.luau` | agent |
| 2 | Creature builders Heat + Frost (8) | `src/shared/Models/CreatureBuilders/HeatFrost.luau` | agent |
| 3 | Creature builders Storm + Cosmic (8) | `src/shared/Models/CreatureBuilders/StormCosmic.luau` | agent |
| 4 | Machinery builders (6 work stations, 6 circuit machines, pylon, 5 decorations) | `src/shared/Models/MachineryBuilders.luau` | agent |
| 5 | Map + plot template | `src/server/Map/MapBuilder.luau`, `src/server/Map/PlotTemplate.luau` | agent |
| 6 | Client UI-A: HUD, CaptureHUD, CaptureReveal, TutorialUI, CircuitEditorUI, CircuitEditor controller | `src/client/UI/HUD.luau`, `CaptureHUD.luau`, `CaptureReveal.luau`, `TutorialUI.luau`, `CircuitEditorUI.luau`, `src/client/Controllers/CircuitEditor.luau` | agent |
| 7 | Client UI-B: nine panels | `src/client/UI/Panels/*.luau` | agent |
| 8 | Client play controllers: CaptureController, WorldAnimator, Effects, RegionGates, Input | `src/client/Controllers/CaptureController.luau`, `WorldAnimator.luau`, `Effects.luau`, `RegionGates.luau`, `Input.luau` | agent |
| 9 | Server core: DataService, Sync, PlayerService, RemoteRouter, VisitService, LeaderboardService, Main.server | `src/server/Systems/DataService.luau`, `Sync.luau`, `PlayerService.luau`, `RemoteRouter.luau`, `VisitService.luau`, `LeaderboardService.luau`, `src/server/Main.server.luau` | agent |
| 10 | Server city: EconomyService, CityService, CircuitService | `src/server/Systems/EconomyService.luau`, `CityService.luau`, `CircuitService.luau` | agent |
| 11 | Server capture: EncounterService, CaptureService, CrisisService | `src/server/Systems/EncounterService.luau`, `CaptureService.luau`, `CrisisService.luau` | agent |
| 12 | Server progression: WorkshopService, AtlasService, VariantService, QuestService, RelaunchService | `src/server/Systems/WorkshopService.luau`, `AtlasService.luau`, `VariantService.luau`, `QuestService.luau`, `RelaunchService.luau` | agent |
| 13 | Client Main bootstrap + integration build, TestHarness | `src/client/Main.client.luau`, `src/server/Systems/TestHarness.luau` | lead / agent |
| 14 | Build, open in Studio, live playtest checklist, fix | — | lead |
| 15 | README, controls guide, balance notes, relay update | `README.md`, relay files | lead |

Each agent task is verified by: (a) `rojo build` succeeds and the file loads in Studio without syntax errors, (b) a review of the contract surface against `docs/CONTRACTS.md`, (c) live check during Task 14.

## Rulings made while planning

- **Where the game lives:** a new Rojo repo at `C:\Users\nguye\Documents\repos\catch-a-catastrophe\CatchACatastrophe`, not the Munch It! Studio place (the only connected Studio place is Munch It!, an unrelated game; the spec forbids overwriting it). Cost if wrong: the user must open the built `.rbxl` themselves.
- **Parallel implementers on disjoint files.** The SDD skill says one implementer at a time; here every task owns distinct files and the sibling project shipped the same way. Agents do NOT commit; the lead commits each task's files when its report arrives, so there is one writer to git. Cost if wrong: an agent edits a shared file — caught at review.
- **Surge definition:** the surge is the 90 s window that opens when a region's Legendary forecast reaches zero (the guaranteed Legendary spawns at that moment). Perfect capture of ANY species in that region during the window yields Overcharged. Cost if wrong: Overcharged is a little easier than intended; tune `surgeDuration`.
- **Storage counts every owned creature** (deployed + stored) against 60/120. Cost if wrong: players hit the cap sooner; raise `Config.Economy.storage`.
- **First possible circuit is Water + Heat** (regions 2 + 3) because Wind (region 1) only pairs with Storm/Cosmic. Tutorial step 6 therefore unlocks Splashwater Bay and step 7 is an info step about recipes. Cost if wrong: circuits arrive ~15K Coins in; acceptable per spec targets (first capture < 60 s, first upgrade < 3 min still hold).
- **Circuit upgrade cost** = 120 s of the pair's combined normal income, min 500 (spec: "costs Coins"). Payback about 13 minutes.
- **Sell value** = rarity seconds (20/25/30/40) x normal income, min 5. Never pays back a capture's opportunity cost; it is a storage-relief valve, not a faucet.
- **Hazard hits are resolved server-side against the catcher's HumanoidRootPart position** (the replicated character position); knockback is applied client-side because the client owns its character physics. Cost if wrong: a lagging client sees the hit slightly late; capture integrity is unaffected.
- **Music:** there is no shipped `rbxasset://` music, so the Music slider controls an ambient channel that is empty at launch (documented limitation). Effects slider is fully wired.
- **Region entry detection** is a 1 s server poll of player positions against region centres (8 players, cheap) rather than touch parts.
- **Daily objectives** roll at UTC midnight from regions in `data.regions`; "connect"/"overdrive" objectives only when two circuit-compatible regions are unlocked.
- **Anchored creatures** stay in storage after relaunch (spec: "stored anchors remain owned and can be deployed immediately; their work functions even before repurchasing their home region") — deployment never requires the region.

---

## Task 1: Creature builders, Wind + Water

**Files:** `src/shared/Models/CreatureBuilders/WindWater.luau` (new)

Return `{ [speciesId] = function(model, root, palette, def) end }` for exactly these eight ids from `Config.Species`: `breeze_bean, gust_bunny, twister_terrier, sir_spins_a_lot, drizzle_duck, puddle_pug, monsoon_manta, tsunami_toad`.

- [ ] Read `docs/CONTRACTS.md` §2 and the header of `src/shared/Models/ModelKit.luau`; read each species' `desc`, `silhouette`, `palette`, `anim`, `height` in `src/shared/Config/Species.luau`.
- [ ] Build each creature from 14–45 parts with a recognisable silhouette matching its description (Breeze Bean: floating bean + leaf ears; Gust Bunny: rabbit on two cyclone feet; Twister Terrier: spiral body + goggles; Sir Spins-a-Lot: tornado knight, sneakers, weather-vane lance; Drizzle Duck: duck + tiny raincloud hat; Puddle Pug: glossy puddle dog + splash paws; Monsoon Manta: hovering manta + trailing rain particles; Tsunami Toad: crowned toad on a curling wave). Every creature has eyes (`Kit.eyes`, role fixed) and a readable face on -Z.
- [ ] Use `palette.primary/secondary/accent` for tintable parts; `role = "fixed"` for eyes, teeth, goggles glass, crowns' gems.
- [ ] Call `Kit.setAnim(model, def.anim, def.animSpeed)` (or a better style) and `Kit.orbiter` for orbiting bits (cyclone feet, satellite parts, wave spray). ≤ 2 lights, ≤ 3 emitters per model. Height within ±20% of `def.height`.
- [ ] Do NOT call `Kit.finalize`, `applyVariant`, `applyRarityGlow`.
- [ ] Verify: `rojo build -o build/CatchACatastrophe.rbxl` succeeds; in Studio Edit mode (if reachable) `require` the module via the MCP `execute_luau` and build all 8 through `CreatureModels.build(id)`, checking `Height` attribute vs `def.height`. If Studio is not reachable, state so.

## Task 2: Creature builders, Heat + Frost

**Files:** `src/shared/Models/CreatureBuilders/HeatFrost.luau` (new)

Same contract as Task 1 for: `cinder_chick, sizzle_salamander, magma_muncher, mount_chomp, flurry_ferret, slush_sloth, blizzard_bison, king_coldsnout`.

- [ ] Cinder Chick: charcoal chick, ember crest (Neon accent + light); Sizzle Salamander: low lizard, glowing back vents (`Kit.flickerPart`); Magma Muncher: squat lava monster with huge furnace jaws (fire particles inside the mouth); Mount Chomp: giant tortoise with a volcano cone on the shell (smoke particles, lava streaks); Flurry Ferret: long slim ferret, big snowflake tail (six-arm star from thin parts); Slush Sloth: sloth hanging under an ice arch (arch is part of the model, `role = "secondary"`); Blizzard Bison: shaggy bison, icicle horns; King Coldsnout: mammoth with tusks and a glacier crown.
- [ ] All other steps identical to Task 1.

## Task 3: Creature builders, Storm + Cosmic

**Files:** `src/shared/Models/CreatureBuilders/StormCosmic.luau` (new)

Same contract as Task 1 for: `static_sprout, zap_raccoon, thunder_thumper, boltjaw_behemoth, orbit_orb, comet_cat, gravity_gobbler, the_big_whoops`.

- [ ] Static Sprout: sprout with spiky standing electric hair (Neon accent); Zap Raccoon: raccoon with lightning-striped tail (alternating colour bands); Thunder Thumper: gorilla with cloud fists (white puffy blobs); Boltjaw Behemoth: four-legged storm beast with jagged lightning antlers; Orbit Orb: small moon with feet and a satellite ring (`Kit.orbiter` for a tiny satellite); Comet Cat: cat with a luminous comet tail (Neon, sparkle particles); Gravity Gobbler: round body with 3–4 orbiting stones (`Kit.orbiter`) and a starry mouth; The Big Whoops: dark sphere with two white gloves and an orbiting yellow warning sign (triangle from wedges).
- [ ] All other steps identical to Task 1.

## Task 4: Machinery builders

**Files:** `src/shared/Models/MachineryBuilders.luau` (new)

Return a module `M` with `buildWorkStation(job, elementColor)`, `buildMachine(circuitId)`, `buildPylon()`, `buildDecoration(key)` exactly as in `docs/CONTRACTS.md` §2 "MachineryBuilders".

- [ ] Work stations (one per job, ≤ 25 parts, footprint ≤ 5 x 6 x 3, base at y = 0): `windmill` (tower + 4 blades on an orbiting hub: use `Kit.setAnim(model, "spin")` on a blade sub-model or `Kit.orbiter` for each blade), `waterwheel` (wheel with paddles, trough), `furnace` (brick box, chimney, fire particles, flicker glow), `freezer` (cabinet with two spinning fans, frost particles), `coil` (tesla coil: rings + Neon sphere, lightning particles, flicker), `dish` (satellite dish that slowly rotates, blinking light).
- [ ] Circuit machines (fit within 8 x 6 x 8, base at y = 0, visibly themed): `thunder_turbine` (big turbine + lamp posts), `steamworks` (boiler + piston + smoke particles), `ice_cream_emergency` (machine + three oversized cones), `thermal_foundry` (forge with hot/cold sides + stamped blocks), `orbital_express` (two towers + 3 orbiting pods via `Kit.orbiter` with a large radius), `neon_grid` (neon signs + arcade cabinets, flicker parts).
- [ ] Every station/machine: `Kit.setAnim`/`Kit.orbiter` for motion, attribute `Working = false` by default (the server sets it), machines also `Overdrive = false`, `Cooling = false`.
- [ ] Pylon: ~10 studs tall, hazard-striped base, Neon crystal top, light; attribute `Charge = 0` (server writes 0..1; client can tint from it).
- [ ] Decorations: `hazard_flags` (bunting line), `smiling_billboard` (board with a smiling monster face made of parts), `pipe_fountain`, `neon_company_sign` ("CCC" from Neon blocks), `golden_statue` (a gold Breeze Bean-shaped statue on a plinth). Each ≤ 40 parts.
- [ ] Verify via `rojo build` and, if Studio is reachable, build every station/machine/decoration once with `pcall` and report any error.

## Task 5: Map + plot template

**Files:** `src/server/Map/MapBuilder.luau`, `src/server/Map/PlotTemplate.luau` (new)

Implement `docs/CONTRACTS.md` §5 and §6 exactly (names, attributes, positions, return shapes).

- [ ] Ground 900 x 4 x 900 centred (0, -2, 0) (Grass), paths (Slate strips) from the hub to each plot and each gate, lamps along paths.
- [ ] Hub: plaza disc radius 70, Spawn, Workshop building (chunky machinery look, hazard stripes), Relaunch Beacon (tall pillar with rotating Neon ring via `Kit.orbiter`), Atlas kiosk, Board with SurfaceGui. Terminals carry `OpensPanel` attributes.
- [ ] Arena: floor disc radius 30 at (0, 0, -105), stage, 3 pylons from `MachineryBuilders.buildPylon()` at the contract positions with `PylonIndex`, BossSpot, Screen with SurfaceGui.
- [ ] Regions: for each `Config.Regions.list` entry, a 150 x 150 themed area at radius 280 on angle (90 + 60 x (index - 1)) deg: coloured ground patch (`groundColor`), 12–25 themed props (Wind: tall grass tufts + windmill; Water: shallow water parts + rocks + dock; Heat: red rocks + lava cracks (Neon) + smoke; Frost: snow mounds + ice arches; Storm: pylons + wires + Neon panels; Cosmic: platform in space colours + antennas + floating rocks via `Kit.orbiter`), boundary fence/low wall with the gate opening on the hub side, `Gate` (tagged `RegionGate`, attribute `RegionId`), `GateSign` (Title/Cost/Forecast labels; Cost text from `unlockCost` formatted with `Format.abbreviate`, "OPEN" for 0), `Entrance`, `Wild` folder, attributes `RegionId, Element, Centre, SpawnRadius = 55`. Signs on the path naming the region and element.
- [ ] `PlotTemplate.build` / `setOwner` / `setPadUnlocked` / `setDecorationTier` / `setRewardDecoration` / `padCFrame` / `pairCFrame` / `reset` per §5. Pads: hazard-stripe border, number label (SurfaceGui) on each pad. Booth: small hut with console and VentButton. CollectPad Neon with BillboardGui. Billboard. Decor tiers: tier 1 adds pipes + planters, tier 2 adds turbines + lights, tier 3 adds a crane and neon trims. Reward decoration slots around the edge (use `MachineryBuilders.buildDecoration(key)`, parented into `Rewards.<key>`, hidden until shown).
- [ ] Keep total map part count under ~3,500. Use `Kit.part` where convenient (anchored, CanCollide as appropriate: floors/walls collide, decor mostly not).
- [ ] Return `refs` exactly as §6.
- [ ] Verify via `rojo build`; if Studio is reachable, run `MapBuilder.build()` + one `PlotTemplate.build` in Edit via `execute_luau` and report part counts.

## Task 6: Client UI-A

**Files:** `src/client/UI/HUD.luau`, `src/client/UI/CaptureHUD.luau`, `src/client/UI/CaptureReveal.luau`, `src/client/UI/TutorialUI.luau`, `src/client/UI/CircuitEditorUI.luau`, `src/client/Controllers/CircuitEditor.luau` (new)

- [ ] Implement each module per `docs/CONTRACTS.md` §8 (exports, remotes fired, panel names) and §9 (tutorial targets), using `Widgets`, `Theme`, `Format`, `State`, `Net`, `Config`.
- [ ] HUD numbers: `Format.abbreviate`; income "x/s"; bank with Collect and BANK FULL state; forecast chips per unlocked region from the `Forecast` remote (`Net.on("Forecast")`) and `State.until_`; sidebar order Creatures, Atlas, Recipes, Workshop, Quests, Cities, Relaunch, Settings (`W.iconButton` → `W.togglePanel(name)`); data status pill; offline claim card; visiting chip; title.
- [ ] CaptureHUD per §8 including the touch-friendly Capture toggle button (≥ 56 px) and Cancel; hazard warning line large and high-contrast; never covers the screen centre.
- [ ] CaptureReveal per §8. TutorialUI per §8/§9 (Beam with an `Attachment` in the character's HumanoidRootPart and one in a client-only part at the target; update target every 0.5 s).
- [ ] CircuitEditor controller + CircuitEditorUI per §8: selection by click/tap raycast on own plot pads, valid-partner highlighting (SelectionBox on adjacent occupied pads whose element forms a recipe), preview computed from `snap.creatures` (find occupants by pad) + `Config.Circuits.recipe` + `Config.Circuits.baseBonus` + `snap.derived.circuitBonusExtra`; Connect/Disconnect/Upgrade/Overdrive buttons with exact spec wording ("x2 for 20 s, then 15 s of no output for this pair unless you vent at your control booth. Stay nearby for the best return."). Gamepad support: D-pad cycles pads on the own plot.
- [ ] Respect `snap.settings.reducedMotion` (skip `W.pop` tweens) where the module animates.
- [ ] Verify via `rojo build`; if Studio is reachable, run the built place and confirm the HUD renders with a mocked snapshot; otherwise state what was not live-checked.

## Task 7: Client UI-B (panels)

**Files:** `src/client/UI/Panels/CreaturesPanel.luau`, `AtlasPanel.luau`, `RecipeBookPanel.luau`, `WorkshopPanel.luau`, `QuestsPanel.luau`, `RelaunchPanel.luau`, `SettingsPanel.luau`, `CitiesPanel.luau`, `CrisisPanel.luau` (new)

- [ ] Implement each panel per `docs/CONTRACTS.md` §8 table (exact panel names, buttons, remotes). Each exports `init()` and `update(snap)`; CrisisPanel also `setCrisis(state?)`; CitiesPanel also `setLeaderboard(boards)`.
- [ ] Creatures: sort options, Deploy/Move pad picker (6 x 4 mini-grid; locked pads greyed, occupied pads show the occupant's name), Store, Favorite, Sell with `W.confirm` showing `Format.coins(value)` where value comes from the snapshot? — the snapshot does not carry sell values: show "Sell for about N" computed as `Config.Rarities.info[rarity].sellSeconds x entry.normalCps` (display estimate; the server pays its own number). Disabled for favorites/anchored. Prismatic button per contract with mastery progress text ("18 / 30 min · 2 / 3 perfect").
- [ ] Atlas: silhouettes via `CreatureModels.build(id, "Normal", true)` in `W.viewport`; discovered cards show the normal model; milestone claim row.
- [ ] Recipes, Workshop (upgrade effect text now → next using `Config.Economy.upgradeById[id].perLevel` and `desc`; region cards), Quests (daily reset countdown via `State.until_(daily.resetsAt)`), Relaunch (anchor picker limited to `derived.anchorSlots`, favorites-lost acknowledgement checkbox, `W.confirm`, disabled reasons), Settings (sliders: implement a simple draggable slider widget locally), Cities (leaderboards + visit/inspect), Crisis (rules + live pylon progress).
- [ ] Every panel fits 640 x 440 and scales via `W.attachScale`; text ≥ 13 px; buttons ≥ 44 px.
- [ ] Verify via `rojo build`; if Studio is reachable, open the built place and confirm every panel opens with a mocked snapshot; otherwise state what was not live-checked.

## Task 8: Client play controllers

**Files:** `src/client/Controllers/CaptureController.luau`, `WorldAnimator.luau`, `Effects.luau`, `RegionGates.luau`, `Input.luau` (new)

- [ ] Implement per `docs/CONTRACTS.md` §8 rows Play. The sibling project's `C:\Users\rahul\orca\Snatch-the-Oddities\src\client\Controllers\WorldAnimator.luau` and `Effects.luau` are good starting points (adapt; drop Blackout/walker code; add `Working/Overdrive/Cooling` handling).
- [ ] CaptureController: target selection (mouse hover raycast on desktop, nearest-in-front for gamepad/touch), highlight (SelectionBox + label), Capture/Cancel through `Input` actions, `Net.fire("StartCapture", uid)` / `CancelCapture`, encounter labels from attributes (name, `Config.Rarities.label`, element, difficulty stars "★★☆☆☆", "Claimed by <name>" when `ClaimedBy ~= 0`), range ring, tether Beam, hazard telegraph rendering for all four shapes with telegraph → active colour change, client pull for `pull` hazards (`hrp.AssemblyLinearVelocity` blend toward the zone during the telegraph, capped), `Knockback` handling, and forwarding `CaptureState`/warnings to `CaptureHUD` (`require(script.Parent.Parent.UI.CaptureHUD)`). Honour `reducedMotion`/`reducedFlashing`.
- [ ] Input: ContextActionService bindings + a mobile button container (bottom-right, ≥ 56 px buttons) for Capture/Cancel; `isTouch()`/`isGamepad()` from `UserInputService`.
- [ ] RegionGates per contract; also shows a toast via `Notifications.push` when the player bumps a locked gate ("Unlock Cinder Canyon for 15K Coins at the gate sign or in the Workshop") at most once per 5 s.
- [ ] Verify via `rojo build`; if Studio is reachable, run and confirm no client errors on join; otherwise state what was not live-checked.

## Task 9: Server core

**Files:** `src/server/Systems/DataService.luau`, `Sync.luau`, `PlayerService.luau`, `RemoteRouter.luau`, `VisitService.luau`, `LeaderboardService.luau`, `src/server/Main.server.luau` (new)

- [ ] Implement per `docs/CONTRACTS.md` §7 rows DataService, Sync, PlayerService, RemoteRouter, VisitService, LeaderboardService and the `Main.server.luau` boot order. The sibling project's `C:\Users\rahul\orca\Snatch-the-Oddities\src\server\Systems\{DataService,Sync,PlayerService,RemoteRouter}.luau` and `Main.server.luau` are good starting points; adapt to this schema and remote list. Register `S.Data`, `S.Sync`, `S.Player`, `S.Visit`, `S.Leaderboard`.
- [ ] DataService: session ownership (`sessionId = game.JobId .. ":" .. HttpService:GenerateGUID(false)` per server; a load whose stored `sessionId` differs and `sessionAt` is < 90 s old waits up to 3 retries then loads read-only with `dataSafe = false` and a "Your data is open on another server" message; otherwise claims it), bounded exponential backoff, autosave 90 s, leave saves, `BindToClose`, `releaseSession` on leave (clears sessionId inside the same UpdateAsync). In-memory test adapter when `RunService:IsStudio()` and the first DataStore call fails with "StudioAccessToApisNotAllowed" (or when `game.PlaceId == 0`): a module-level table keyed by `Config.TestNamespace .. userId`; `usingTestAdapter()` true; profiles get `testAdapter = true`, `dataSafe = true`, `dataState = "loaded"`. Test helpers never grant production rewards (there are none; do not add any).
- [ ] Sync: build `Types.Snapshot` exactly (every field in `src/shared/Types.luau`), using `Stats.income`, `Stats.compute`, `S.Encounters`/`S.Capture` for `capturing`, `profile.overdrives` for circuit entries (`until_` → snapshot field `until_`), `S.Quests` for resolved daily items (`S.Quests.snapshotQuests(profile)` — coordinate: Task 12 provides it; if absent at review time, build from `data.quests` directly with `Config.Quests` lookups), offline pending, `dataState`. Push ≤ 4x/s when dirty; `GetState` function.
- [ ] PlayerService: join/leave flow per contract, `applyCharacter(profile)` (WalkSpeed from Stats, RespawnLocation to the plot spawn), character death → `S.Capture.onCharacterRemoved`.
- [ ] RemoteRouter: bind every client → server remote in `Remotes.eventNames` with validators (`isId`, `isInt`, `isFinite`, `isPad` 1..24, `isBool`) and rate limits (extend `RateLimiter.LIMITS` with the new names: StartCapture 4/2, CancelCapture 4/2, DeployCreature 6/3, StoreCreature 6/3, MoveCreature 6/3, SellCreature 3/1, SetFavorite 8/4, ConnectCircuit 6/3, DisconnectCircuit 6/3, UpgradeCircuit 3/1, StartOverdrive 3/1, CollectBank 3/1, ClaimOffline 2/0.5, BuyUpgrade 6/3, UnlockRegion 3/1, DoRelaunch 1/0.2, ClaimMilestone 3/1, ClaimQuest 3/1, ClaimDaily 3/1, PrismaticUpgrade 2/0.5, SetSetting 8/4, TutorialAdvance 4/1, VisitCity 2/0.5, RequestState 2/0.5, GetState 3/0.5, GetCityInfo 3/1, Prompt 8/4). Route to `S.Capture.start/cancel`, `S.City.deploy/store/move/sell/setFavorite`, `S.Circuits.connect/disconnect/upgrade/startOverdrive`, `S.Economy.collect/claimOffline`, `S.Workshop.buyUpgrade/unlockRegion`, `S.Relaunch.perform`, `S.Atlas.claimMilestone`, `S.Quests.claimRepeatable/claimDaily/tutorialAdvance`, `S.Variants.prismaticUpgrade`, settings (validate keys music/sfx numbers 0..1, booleans for the rest), `S.Visit.visit/home`, `Sync.push`. Also `ProximityPromptService.PromptTriggered` → `Prompt` attribute "Vent" → `S.Circuits.vent`; `PromptButtonHoldBegan/Ended` on pylon prompts (`PylonIndex`) → `S.Crisis.onPylonHold` accumulation via a per-player holding loop; `CollectPad` `Touched` (attribute `Touch == "Collect"`, owner only, debounce 1 s) → `S.Economy.collect`.
- [ ] VisitService + LeaderboardService per contract.
- [ ] Main.server per contract boot order with pcall around `MapBuilder.build` and a fallback ground so the server still runs when the map fails; prints `[Catch a Catastrophe!] Server ready in N ms`. Studio: `task.delay(3, TestHarness.run)` guarded by `FindFirstChild`.
- [ ] Verify via `rojo build`; if Studio is reachable, run the place, join, and confirm the snapshot arrives and no server errors print; otherwise state what was not live-checked.

## Task 10: Server city (economy, pads, circuits)

**Files:** `src/server/Systems/EconomyService.luau`, `CityService.luau`, `CircuitService.luau` (new)

- [ ] Implement per `docs/CONTRACTS.md` §7 rows EconomyService, CityService, CircuitService. Register `S.Economy`, `S.City`, `S.Circuits`.
- [ ] Economy tick (1 s, one loop for all profiles): `bank = min(bank + income.total x dt, Stats.bankCap)`, `lifetimeCoins` unchanged until collect; mastery accrual for creatures in active pairs (`data.mastery[speciesId].circuitSeconds += dt`); quest `earned` bump with the accrued amount; refresh labels ≤ 1/s; mark dirty only when displayed values change by ≥ 1 Coin or every 2 s.
- [ ] `collect`: payout = floor(bank), bank -= payout, coins += payout, lifetime += payout, `stats.collects += 1`, quest `collects`, tutorial event `collect`, FloatingText + effect. `spend` atomic; `computeOffline`/`claimOffline` per contract with negative/zero/duplicate guards (pending is zeroed BEFORE coins are added and the profile is marked dirty; a second claim returns "Nothing to claim").
- [ ] City: plot assignment (lowest free index; `PlotTemplate.setOwner`; `player.RespawnLocation`), `grantCreature` (storage check → uid → data entry → dirty; message "Storage full (60/60). Sell a creature or relaunch to make room." on refuse), deploy/store/move/sell/favorite with full validation (owned uid, pad 1..padsTotal, not visiting, pad free or swap, favorites/anchored cannot be sold), pad visuals: creature model (`CreatureModels.build(id, variant)` pivoted to `PlotTemplate.padCFrame`, `Working = true`, tag `Animated`), station (`MachineryBuilders.buildWorkStation(def.job, elementColor)`, `Working = true`), BillboardGui label "Name · ★ Rare · ⚡ Overcharged · 12.5/s" (server writes text; keep one BillboardGui per occupied pad), `refreshLabels` (collect pad "Bank: 1.2K" / "BANK FULL", billboard earnings "152/s"), `applyUpgrades` (pad unlock visuals, decoration tier, milestone decorations from `data.atlas.claimed`).
- [ ] Circuits: connect/disconnect/upgrade/startOverdrive/vent/recalculate/tick per contract. Upgrade purchases belong to the pad pair for the run (`data.circuitUpgrades[key]`); `upgrade` refuses when already upgraded. Overdrive per pair in `profile.overdrives[key] = { phase, until_, vented }`; `tick` every 0.25 s advances active → (`vented` and idle or cooldown) → idle and sets `Overdrive/Cooling` attributes on the machine model; `vent` requires the player's character within 12 studs of `plot.booth.ventButton`. Machinery: `MachineryBuilders.buildMachine(circuitId)` at `PlotTemplate.pairCFrame`, `Working = true`, tag `Animated`, per-pair BillboardGui "Thunder Turbine +25%". First activation of a recipe → `S.Atlas.recordRecipe`; connect → `stats.connects`, quest `connects`; overdrive → `stats.overdrives`, quest `overdrives`.
- [ ] Verify via `rojo build`; write a small Studio-run check (or describe one for the TestHarness owner): deploy two compatible creatures, connect, assert each member's cps = normal x 1.25 and the pair recalculates on store.

## Task 11: Server capture (encounters, capture loop, crisis)

**Files:** `src/server/Systems/EncounterService.luau`, `CaptureService.luau`, `CrisisService.luau` (new)

- [ ] Implement per `docs/CONTRACTS.md` §7 rows EncounterService, CaptureService, CrisisService. Register `S.Encounters`, `S.Capture`, `S.Crisis`.
- [ ] Encounters: one loop (0.5 s) for all regions; wild population to `populationCap`; rarity roll via `Weighted.pick` over `Config.Rarities.info[r].weight`; Legendary guarantee per region every `legendaryInterval` (spawns a Legendary and opens the surge for `surgeDuration`; forecast pushed on change and to joining players); roam legs: pick a point within `roamRadius` of the spawn, write `PathFrom/PathTo/PathStart/PathDuration` (duration = distance / roamSpeed) and `BasePivot`; wild models built with `CreatureModels.build`, pivoted at ground, tagged `Animated` + `Wild`, attributes per §5; claims (`ClaimedBy`, `ExpiresAt = now + encounterLifetime`), release, consume (destroy + respawn timer), recycle unclaimed after `wildLifetime`; `ensureTutorialSpawn` keeps at least one `breeze_bean` in Gusty Gardens while any online player is on tutorial step ≤ 2. Broadcast Legendary spawns with the region name.
- [ ] Capture per contract: `start` validation (not already capturing, region unlocked via `S.Workshop.canAccess`, distance ≤ `claimRange`, storage not full with the explanation message, encounter free) → claim; Heartbeat tick every `Capture.tick`: `required = min(captureSeconds, cap) / tetherSpeedMult`, in-range check against the creature's current pivot, progress accrual, grace, break (−2 s, `perfect = false`, status), hazard scheduling (every `attackInterval / hazardSpeed` s: build a `HazardEvent` from `Config.Capture.hazards[element]` with geometry chosen server-side — line direction toward the catcher's current position offset by a random ±20°, ring centred on the creature, circles with the first patch at the catcher's position, pull zone 8 studs from the creature toward the catcher — send with `Notify.hazard({player}, ev)`), hazard resolution when `now ≥ telegraphEndsAt` and `< activeEndsAt` each tick (line: distance from the HRP to the moving segment ≤ width + 1.5; ring: |dist − r(t)| ≤ radius + 1; circles: within radius + 1 of any patch; pull: within radius at the pulse instant), one hit per hazard, hit → `progress = max(0, progress − hitPenalty)`, `hits += 1`, `perfect = false`, `Notify.knockback(player, dirAwayFromHazard, Capture.knockback)`, status "Hit! -2 s"; expiry at `encounterLifetime` → cancel with "The creature got away"; completion → consume, variant, grant (if grant fails because storage filled meanwhile, refund nothing, notify), Atlas, quests, `Notify.captureResult`, tutorial `capture`, effect. Death/leave/cancel release the claim and send `CaptureState(nil)`. A player who moves > 90 studs from the creature is treated as leaving the region → cancel.
- [ ] Expose `CaptureService.hazardGeometry` helpers (`buildHazard(def, origin, targetPos, now, speed, boss) -> HazardEvent`, `hazardHits(ev, pos, now) -> boolean`) so CrisisService reuses them.
- [ ] Crisis per contract: schedule loop; warning banner; boss model (`CreatureModels.build(id, "Normal", false, bossScale)`, name label "CRISIS BOSS: <name>"), boss hazards every `bossAttackInterval` against every player within 32 studs of the arena centre (hit = knockback + "Crisis boss hit you!"; no capture involvement), pylon work via `onPylonHold(profile, index, dt)` (only during active phase; per-pylon `need = pylonBaseWork + pylonWorkPerExtraPlayer x (participants − 1)` where participants = players within the arena at activation, min 1; `Charge` attribute on the pylon model), success/timeout, once-only reward per qualified participant, `stats.crisisWins`, `Notify.crisis` on every change (≤ 4x/s), cleanup.
- [ ] Verify via `rojo build`; if Studio is reachable, run and observe wild creatures roaming and one capture completing; otherwise state what was not live-checked.

## Task 12: Server progression

**Files:** `src/server/Systems/WorkshopService.luau`, `AtlasService.luau`, `VariantService.luau`, `QuestService.luau`, `RelaunchService.luau` (new)

- [ ] Implement per `docs/CONTRACTS.md` §7 rows WorkshopService, AtlasService, VariantService, QuestService, RelaunchService. Register `S.Workshop`, `S.Atlas`, `S.Variants`, `S.Quests`, `S.Relaunch`.
- [ ] Workshop: `buyUpgrade` (level < `Stats.maxUpgradeLevel`, `S.Economy.spend(cost)`, level += 1, `S.City.applyUpgrades`, `S.Player.applyCharacter`, tutorial `upgrade`), `unlockRegion` (not unlocked, spend `unlockCost`, tutorial `unlock:<id>`, effect), `canAccess`.
- [ ] Atlas: record capture (first discovery → `firstAt`, `caught += 1`, `perfect += 1`, `variants[variant] = true`), record variant (Prismatic upgrade), record recipe, claim milestone (count in `Config.Milestones.byCount`, `discovered ≥ count`, not claimed → claimed, `S.City.applyUpgrades`, success toast naming the decoration and title).
- [ ] Variants per contract, including `S.Atlas.recordVariant` on Prismatic; refuse when `mastery` insufficient with a message showing progress; the transformed creature keeps pad/favorite/anchored; `S.City.refreshPad` when deployed; `S.Circuits.recalculate`.
- [ ] Quests: counters live in `data.quests.repeatable[id].progress` and `data.quests.daily.items[i].progress`; `bump(profile, stat, amount, regionId?)` increments matching repeatable + daily items (`region_captures` only when `regionId` matches the item's `regionId`; `rare_captures` when rarity rank ≥ 3 — the caller passes the stat); `claimRepeatable` (progress ≥ target → reward `Stats.scaledReward`, `cycle += 1`, progress −= target (carry-over), notify), `claimDaily` (index 1..3, progress ≥ target, not claimed), `ensureDaily` (roll 3 distinct pool ids with the rules in the contract; region-scoped picks a random unlocked region; store `dayKey`), `snapshotQuests(profile) -> Snapshot.quests` (resolved targets, descs with region names, rewards via `Stats.scaledReward`, `resetsAt` as server time), tutorial events/advance/send per contract, region-entry poll (1 s) firing `enter_region:<id>` and `S.Encounters.ensureTutorialSpawn` hooks.
- [ ] Relaunch per contract: `canRelaunch` reasons in player language; `perform`: validate anchors (owned, count ≤ slots), set `busy`, reset per `Config.Relaunch.resets` (coins = resetCoins, bank = 0, offlinePending = 0, upgrades = {}, regions = { gusty_gardens }, circuits = {}, circuitUpgrades = {}, all creatures except anchors removed, anchors get `pad = nil`, `anchored = true`), `relaunch += 1`, `stats.relaunches += 1`, keep everything in `Config.Relaunch.keeps`, `S.City.refreshAll`, `S.Circuits.recalculate`, `S.City.applyUpgrades`, `S.Player.applyCharacter`, `S.Data.save(profile, "relaunch")`, `busy = false`, effect + broadcast.
- [ ] Verify via `rojo build`; describe (or run in Studio if reachable) a relaunch on a mocked profile asserting kept/reset fields.

## Task 13: Client Main + TestHarness

**Files:** `src/client/Main.client.luau`, `src/server/Systems/TestHarness.luau` (new)

- [ ] Main.client per `docs/CONTRACTS.md` §8 last paragraph: safeRequire every module, init order (Notifications, FloatingText, HUD, panels, CaptureHUD, CaptureReveal, TutorialUI, CircuitEditorUI, Effects, WorldAnimator, RegionGates, Input, CaptureController, CircuitEditor), wire `State`, `Notify`, `Broadcast`, `FloatingText`, `Effect`, `TutorialStep`, `CaptureState`, `Hazard`, `Knockback`, `CaptureResult`, `Forecast`, `CrisisState`, `Leaderboard`; `OpensPanel` prompts; Escape closes panels; `W.sfxEnabled = snap.settings.sfx > 0`.
- [ ] TestHarness per §7 row TestHarness with mock profiles (no real Player needed for Stats/Profiles/relaunch/offline tests; use `Profiles.create` with a fake player table cast to `any` where a Player is required and skip systems that need a character).
- [ ] Verify via `rojo build` and a Studio run showing `[SelfTest] passed N failed 0`.

## Task 14: Live playtest + fixes (lead)

- [ ] `rojo build`, open in Studio (launch `RobloxStudioBeta.exe build/CatchACatastrophe.rbxl`), Play, read Output; fix errors.
- [ ] Walk the spec's verification list: fresh player tutorial → capture → deploy → earn → collect → upgrade; all 24 builders; six hazards; circuits once; overdrive; double-claim guards; relaunch; rejoin; two clients.
- [ ] Balance: measure time-to-first-capture, first upgrade, first relaunch; tune Config and record changes.

## Task 15: Docs (lead)

- [ ] README: layout, build/run, systems table, roster table, balance tables, data schema, controls guide, test results (automated vs live), known limitations.
- [ ] Update `C:\Users\rahul\orca\Munch-It-\RELAY.md` and `C:\Users\rahul\PycharmProjects\python\RELAY.md` (if present) with a Catch a Catastrophe entry; update `docs/CONTRACTS.md` DONE markers.

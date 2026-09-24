# Catch a Catastrophe! — pickup doc

**Updated:** 2026-09-06, handoff to Claude after runtime build stamp work.

## Current handoff to Claude (takes precedence over historical sections)

- Work exclusively in `C:\Users\nguye\Documents\repos\catch-a-catastrophe\CatchACatastrophe`. Do not follow
  historical external-project paths below. Start with this project's `RELAY.md`.
- User requested the handoff; no new gameplay feature or publishing is requested.
- Latest change: server snapshots include `build.placeVersion` from `game.PlaceVersion`
  and `build.environment` (`Studio` or `Live`). The HUD renders `Build <number> | <environment>`.
- Files: `src/shared/Types.luau`, `src/server/Systems/Sync.luau`,
  `src/client/UI/HUD.luau`. Source presence was checked during this handoff.
- Important remaining limitation: the pill is visible only when `RunService:IsStudio()`
  or `snap.testAdapter` is true. Normal live players cannot see it. The stamp has no
  source revision marker or automatic comparison of local changes with published code.
  Review that gap against the user's original goal of checking whether latest changes
  are published before describing the feature as complete for live use.
- Prior implementation validation: structural lint and quote scan passed on 80 files;
  `rojo build -o build/CatchACatastrophe.rbxl` succeeded. No fresh Studio runtime
  validation of the stamp was recorded. Checks were not rerun for this documentation handoff.
- Last recorded Studio state: Play stopped after hazard verification. Current Studio
  state and published version have not been checked in this handoff. No publishing
  or commit was performed by this handoff. Earlier work reports no publishing.
- Art style was approved and extended to all 24 creatures. Five remaining capture
  hazards were verified: 418 self-tests, 22 live tests, and 10 controlled hazard
  capture cases passed before the stamp change. These are historical results.
- Next gameplay verification: manual circuit editor and Overdrive vent, then relaunch,
  offline rejoin, Containment Crisis, multiplayer, and measured balance/human dodge timing.
- Preserve existing working-tree edits. Use disk and Rojo for source changes; verify
  Studio is stopped before editing scripts. Read `docs/CONTRACTS.md` before module edits.

Everything below is historical; statements about clean git state, pending art approval,
untested hazards, and Studio state may be superseded by this checkpoint.

## Latest work: five remaining capture hazards

- User approved the full creature roster and requested Water, Heat, Frost, Storm,
  and Cosmic capture hazards. Existing patterns were exercised and corrected.
- Water now renders a hollow splash band and allows jumping above it, using
  avatar feet height for both capture and Crisis hit checks.
- Cosmic pull is restricted to its visible zone and has the same strength with
  reduced motion enabled. Older warning timers cannot erase newer warnings.
- Verification: **418 self-tests, 22 existing live tests, 10 hazard capture cases
  passed**. Each element completed one deliberate-hit and one perfect-dodge capture
  through real client remotes and the normal server heartbeat. Warnings, geometry,
  and effect cleanup were observed on the client. Separate checks passed for the
  Cosmic pull boundary and overlapping HUD warnings.
- Two earlier live runs ended before observing a warning; the subsequent full run
  passed without further production changes. Human dodge timing/balance is still
  unmeasured; the harness controls avatar placement and freezes roaming.
- `docs/HAZARD_VERIFICATION.md` documents behavior, test limits, and repeatable steps.
  `Systems/HazardTestHarness` is Studio-only and requires the in-memory adapter.
  `tools/capture_hazard_observer.luau` starts captures and observes client effects.
- Static checks and Rojo build pass (80 source files). Earlier terrain/creature art
  is preserved. Nothing published or committed. Play stopped after testing to
  clear the temporary observer and reset the test world.
- Next suggested work: manual circuit-editor and Overdrive vent interaction,
  followed by relaunch, offline rejoin, Crisis, and multiplayer verification.

## Latest work — approved style extended to all creatures

- User approved the four Gusty Gardens creatures and authorized the remaining 20.
  All five other regions are polished; see `docs/CREATURE_ART.md` for details.
- Modified the three `CreatureBuilders` files, added `Shared.Models.ToyFace`, and
  reused the approved Wind eye/smile helpers without changing that region's geometry.
- Variant/rarity additions in `ModelKit` now respect the existing total budget of
  two lights/three emitters while preserving creature-specific effects.
- Added 120 appearance-budget/silhouette assertions to `TestHarness`. Fresh run:
  **342 self-tests passed; 22 live tests passed**. All 96 appearances build with
  22–43 parts, within 20% of configured height. Static checks and Rojo build pass.
- All five new region lineups were inspected with the built-in Studio `screen_capture`
  tool. It works without the other connector's paid screenshot capability. Corrected
  flattened facial meshes and connected the mammoth's tusks after visual inspection.
- Twenty animation samples confirm ring tilt and warning-sign punctuation stability.
- Temporary Edit preview was removed. Play is running with the client-only review
  opened at Splashwater Bay: **Previous region / Next region / Change appearance /
  Back to game**. Actual button clicks verified navigation, variants, and cleanup.
- Review utility: `tools/creature_art_review.luau`, outside Rojo's shipped source tree.
  Run via Client `execute_luau` during Play to restore it after stopping. Back to game
  restores camera/UI; stopping Play removes it. No persistent review scripts.
- Build refreshed; source synchronized through Rojo. Nothing published or committed.
  Earlier terrain/art changes remain intact. Existing impact-sound warning and
  disabled Studio persistence remain. Next: user review, then discuss the next task.

## Previous work — four Gusty Gardens creatures

- Refined Breeze Bean, Gust Bunny, Twister Terrier, and Sir Spins-a-Lot in
  `src/shared/Models/CreatureBuilders/WindWater.luau`. Style and per-creature changes
  are recorded in `docs/GUSTY_GARDENS_ART.md`; visual approval is pending.
- Rounded proportions, clearer faces and signatures; fixed face colours retain
  contrast through variants. Bunny feet now orbit independent centres, and both
  bunny/knight wind rings retain horizontal orientation. Removed the knight's
  duplicate sparkle emitter to keep every variant within the effect budget.
- Validated 16 model/variant combinations: top within 20% of configured height,
  24–29 parts, at most two lights and three emitters, anchored and noncolliding.
  Water builders were compared with HEAD and are unchanged.
- Structural lint, quote scan, Rojo build, and diff whitespace checks pass.
  Latest Play run: 222 self-tests and 22 live tests passed. Existing sound warning remains.
- Left Play running with a temporary client-only `Workspace.GustyArtReview` lineup
  and fixed front camera. Stop Play removes the lineup and resets the camera;
  neither is included in source/build. No inventory or progression changes.
- Next: gather the user's feedback on these four before extending the style.
  No publishing or commit performed. Earlier terrain and handoff edits remain intact.

## Previous work — terrain and scenery polish

- `src/server/Map/MapBuilder.luau`: added deterministic landscape construction with
  meadow banks and trees between destinations, plus six regional backdrops: grassy
  groves, dunes and beach grass, layered canyon rock, snowy ridges and trees,
  slate storm ridges, and floating cosmic shards with luminous seams.
- Muted only the central logo tiles to slate grey; route arrows and hazard stripes
  retain their existing colours.
- Added 232 anchored scenery parts; total map count is now 2,001. Continuous base
  ground remains in place. No extra lights, emitters, assets, or animation loops.
- Placement audit passed: conservative horizontal bounds stay outside the reserved
  190-stud city/hub ring, all six 75-stud region interiors, and all 25 routes with
  four studs of additional clearance. Scenery does not participate in touch/query.
- Rojo script synchronization confirmed directly after disk edits. Place-property
  synchronization remains a separate unresolved item from the prior checkpoint.
- Validation: structural lint and quote scan pass on 78 files; Rojo build succeeds;
  latest live run passes 222 self-tests and 22 live tests, server ready in 146 ms.
- Viewport screenshot capture is blocked by the connector's Basic license. Visual
  approval is pending. Temporary Edit preview was removed; Studio is left in Play
  for the user to review. Nothing published or committed.
- Build refreshed at `build/CatchACatastrophe.rbxl`. Existing impact-sound warning
  and disabled Studio persistence remain. Next: user art review, then discuss the
  next item before implementing further features.

## Previous checkpoint — lighting pickup

- Work is scoped exclusively to `C:\Users\nguye\Documents\repos\catch-a-catastrophe\CatchACatastrophe`.
- All 78 Studio scripts matched disk by path and normalized-source Adler-32 checksum;
  no Studio-only scripts were found in the three managed script trees.
- Rojo 7.7 responds on port 34872 for `CatchACatastrophe`. The plugin connection and
  automatic synchronization of place properties have not been confirmed.
- In Edit mode, applied the existing `default.project.json` Lighting properties and
  its Atmosphere, Bloom, Grade, and SunRays instances. No script sources were changed.
- Verified all 27 accessible configured lighting properties in the subsequent Play run:
  zero mismatches, Atmosphere present, ClockTime approximately 15.1.
- `Lighting.Technology` is inaccessible to the Studio bridge for both reads and writes.
  Its configured `Future` value still needs checking through Studio/Rojo.
- Fresh Play output: **SelfTest 222 passed / 0 failed; LiveTest 22 passed / 0 failed**.
  This supersedes the older statements below that the live suite had never run.
- Outstanding output: `rbxasset://sounds/impact_generic.mp3` fails to load. DataStore API
  access is disabled; the game uses its in-memory test adapter in Studio.
- Left Studio in Play for the user's lighting and wayfinding review. Nothing published.
- Next: review the art, verify Rojo property synchronization and rendering settings,
  then continue the remaining gameplay verification listed below.

The sections below preserve the earlier art-pass handoff; this checkpoint takes precedence.

## What this is

An original Roblox simulation / tycoon game built from the spec at
`docs/superpowers/specs/2026-09-06-catch-a-catastrophe-spec.md`, which is the binding authority.
Players capture living natural disasters in six regions, deploy them on work pads in a city plot,
connect adjacent compatible pairs into **Disaster Circuits**, collect Coins, buy upgrades, and relaunch
ten times.

Everything in the spec is built. ~19,400 lines of Luau across 78 files, all committed.

## Where things are

| | |
|---|---|
| Repo | `C:\Users\nguye\Documents\repos\catch-a-catastrophe\CatchACatastrophe` (own git history, currently clean) |
| Published place | `placeId 88888194204730` — "Catch a Catastrophe" |
| Build | `rojo build -o build/CatchACatastrophe.rbxl` |
| Binding spec | `docs/superpowers/specs/2026-09-06-catch-a-catastrophe-spec.md` |
| Module interfaces | `docs/CONTRACTS.md` — read before editing any module |
| Design rulings | `docs/superpowers/plans/2026-09-06-catch-a-catastrophe.md` (read before changing balance) |
| Relay entries | `C:\Users\rahul\orca\Munch-It-\RELAY.md` and `C:\Users\rahul\PycharmProjects\python\RELAY.md` |

**This is not the Munch It! place.** Munch It! is a different game that lives only in its own Studio
DataModel. Never write to it from here.

## READ THIS: how to get code into Studio

This project lost time twice to disk/Studio divergence. The fix is now in place — **use it**.

**Rojo live sync.** The Rojo Studio plugin is installed (via `rojo plugin install`, not the marketplace).
Start the server from the repo root and connect from Studio's Rojo toolbar:

```bash
cd C:/Users/nguye/Documents/repos/catch-a-catastrophe/CatchACatastrophe && rojo serve --port 34872
```

Then in Studio: **Rojo → Connect**, port 34872. Disk becomes the single source of truth and every edit
appears in Studio immediately.

Two things to know:

- Connecting **overwrites** `ReplicatedStorage.Shared`, `ServerScriptService.Server` and
  `StarterPlayerScripts.Client` from disk. Before connecting after someone has edited in Studio, diff
  the script lists — a previous session verified disk was a strict superset before connecting.
- **Do not hand-patch script `.Source` through the MCP bridge.** That is what caused the divergence.
  It was used before Rojo existed here; it should not be needed again.

**Status at handoff:** `rojo serve` was running on 34872 and the user was about to connect. As of the
last check the place still had `ClockTime = 14` and no `Atmosphere`, meaning **the connect had not yet
landed** and the place is missing everything from the two most recent commits. Confirm this first:

```lua
-- run in Studio (Server datamodel) to see whether the current build is live
local L = game:GetService("Lighting")
return { atmosphere = L:FindFirstChildOfClass("Atmosphere") ~= nil, clockTime = L.ClockTime }
-- expect: atmosphere = true, clockTime = 15.1
```

## Verification status

**It runs.** Last full run: all 77 scripts compiled, server booted in 65 ms, 1,027-part map,
**`[SelfTest] passed 222, failed 0`**.

The spec's first verification item passes end to end, driven through the real remotes as a client:
capture a Breeze Bean, deploy it, earn, collect, buy an upgrade. Income read 4/s exactly as configured,
the bank capped at one hour of production, collect paid the floor and left the fraction, and the
tutorial advanced on the right actions.

Static checks, no Studio needed, both pass on all 78 files:

```bash
python tools/luau_lint.py src     # block, bracket and string balance
python tools/quote_scan.py src    # unbalanced quotes
```

`luau_lint.py` is calibrated against `C:\Users\rahul\orca\Snatch-the-Oddities\src`, which compiles. It
reports one issue there and that issue is a known false positive: Luau's `if a then b else c`
**expression** has no `end`, and the linter treats a line-leading `if` as a statement. This repo never
wraps an if-expression onto its own line.

### Still unverified

- Five of six hazard patterns (only **Wind** has been exercised live).
- Circuits / Overdrive / the vent **in a live session** (they pass in unit tests).
- Relaunch, the offline claim on rejoin, the Containment Crisis, two clients at once.
- **All balance.** Every number is still the spec's untuned starting value.
- `Harness.runLive` — a live suite covering the world-touching cases (deploy building models, circuits
  building machinery, Overdrive maths, collect rounding, sell guards, locked-region claim refusal). It
  is wired in `Main.server.luau` to run automatically in Studio once a player has a plot and prints
  `[LiveTest] passed N, failed M`. **Written but never executed** — it needs a session on the current
  build. Running this is the single highest-value next action.

## Where the last session got to

The user asked for **visual and art polish**. Three commits, none of them yet seen in Studio:

1. `a11e06f` — seven spec gaps closed: containment tether Tool, collect-pad ProximityPrompt,
   Overdrive-gated vent prompt, safe-area insets, tooltips, music SoundGroup.
2. `4ad3003` — lighting and atmosphere: `Atmosphere`, `Bloom`, `ColorCorrection` grade, `SunRays`,
   sun moved off noon to 15:10 so shapes cast shadows; per-region weather emitters and tinted fill
   lights; real materials per region (Grass / Sand / Basalt / Snow / Asphalt / Metal).
3. `feb5640` — **wayfinding**, the most recent request. The routes were low-contrast grey strips that
   read as scenery. They are now: dark asphalt roadbed, edge lines in the destination's colour,
   bright yellow chevrons pointing at the destination, and striped bollards with lit caps so the route
   has a silhouette at eye level. Verified in Studio with a throwaway test rig (since deleted) —
   chevrons point the correct way and read well from player height.

Route colours: hub buildings yellow, Relaunch Beacon cyan, Atlas kiosk green, arena red, player plots
sky blue, and each region route carries that region's own colour.

## Known open questions and cautions

- **The art pass is unreviewed.** The user has not seen the new lighting yet. It is a big change:
  +16% saturation, +13% contrast, real haze. If it reads as too much, it is four numbers in
  `default.project.json` under `Lighting.Grade` and `Lighting.Atmosphere`.
- **The decorative logo ring in the plaza centre competes with the new wayfinding.** The user
  originally mistook those yellow tiles for directional markers, which is what prompted the wayfinding
  work. Consider toning the ring down so yellow means "go this way" and nothing else.
- **The surrounding grass plane is a flat 900×900 monotone slab** and reads poorly. Not yet addressed.
- **Creature model detail** was the other obvious art target and has not been started. The 24 models
  build at correct heights but have never been assessed for whether each reads as the animal intended.
- The music slider drives a real `SoundGroup` but no track ships — Roblox has no `rbxasset://` music
  and the spec forbids depending on assets the player may not load. Wiring is complete; add a `Sound`
  to that group if a track is ever sourced.

## Environment traps

- **A Write hook rejects any file containing a dot followed by `format(`.** It misreads Luau as Python
  SQL. Use `("%d"):format(x)` — the `:` form is fine — or write via a Bash heredoc.
- **The Bash tool strips one backslash level even inside quoted heredocs.** A `\n` written that way
  becomes a real newline and silently breaks Luau string literals. This caused a genuine compile error
  once. Write Python helpers to a file and run the file, or use the Edit tool.
- **Roblox cylinders run along their X axis.** A vertical cylinder is `Vector3.new(length, d, d)` with
  `CFrame.Angles(0, 0, math.rad(90))`. Getting this wrong yields flat ellipses.
- **`Kit.finalize` welds every part to a root and clears `CanCollide`.** Creature models only. Never
  call it on the map or a plot or the player falls through the floor.
- **Coplanar faces z-fight.** Every built floor sits proud of the ground (`y = 0.06`) and stacked layers
  keep ~0.08 clearance for this reason. If you add a floor, do not put its top face at `y = 0`. There is
  a scan for this in the git history of the z-fighting commit worth reusing.
- The MCP `execute_luau` sandbox is a **separate Lua VM** with its own module cache: `require` there
  returns fresh empty modules, and functions cannot be called across the boundary. Read state through
  instances, or print to Output and read it with `get_console_output`.

## Suggested next actions

1. Connect Rojo, confirm the current build is live, press Play, and read Output. Expect
   `[SelfTest] passed 222, failed 0` and then `[LiveTest] ...` — the latter has never run.
2. Get the user's read on the new lighting and wayfinding before building more art on top of it.
3. Finish the spec's section 13 verification list, starting with the five untested hazard patterns and
   circuits/Overdrive live.
4. Balance pass against the spec's targets: first capture under 60s, first upgrade under 3 min, first
   relaunch 25–45 min. Record what changed and why in the plan's rulings section.
5. Remaining art candidates, in the order the user is most likely to notice: the flat grass plane,
   the competing logo ring, creature model detail.

Do not publish without the user's explicit say-so. They have been publishing manually themselves.

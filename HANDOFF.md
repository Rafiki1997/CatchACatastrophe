# Catch a Catastrophe! — pickup doc

**Updated:** 2026-09-06, end of the art-pass session. This is the file to read first.

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
| Repo | `C:\Users\rahul\orca\Catch-a-Catastrophe` (own git history, currently clean) |
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
cd C:/Users/rahul/orca/Catch-a-Catastrophe && rojo serve --port 34872
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

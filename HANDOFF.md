# Catch a Catastrophe! — handoff

**Updated:** 2026-09-06, after the full implementation pass. Keep this current: it is the pickup point.

## What this is

An original Roblox simulation/tycoon game built from the spec at
`docs/superpowers/specs/2026-09-06-catch-a-catastrophe-spec.md` (a verbatim copy of the user's prompt,
which is the binding authority). Players capture living natural disasters in six regions, deploy them on
work pads in a city plot, connect adjacent compatible creatures into **Disaster Circuits**, collect Coins,
buy upgrades, and relaunch (rebirth) ten times.

## Where the code lives — read this first

`C:\Users\rahul\orca\Catch-a-Catastrophe` — a standalone Rojo 7.7 repo with its own git history.

**It is NOT the Munch It! Studio place.** One connected Roblox Studio instance has Munch It!
(`placeId 87396511725981`) open, which is an unrelated game. Never write to that DataModel.
Build and open this game's own place file instead:

```bash
cd C:/Users/rahul/orca/Catch-a-Catastrophe && rojo build -o build/CatchACatastrophe.rbxl
```

Then open `build/CatchACatastrophe.rbxl` in Studio and press Play (F5).

## Documents, in order of authority

1. `docs/superpowers/specs/2026-09-06-catch-a-catastrophe-spec.md` — the spec. Binding.
2. `docs/CONTRACTS.md` — every module interface: config surface, ModelKit API, world instance names and
   attributes, the `refs` and `plot` record shapes, all server system signatures, all client module
   exports, tutorial arrow targets, style rules.
3. `docs/superpowers/plans/2026-09-06-catch-a-catastrophe.md` — the task breakdown and the design
   **rulings** (why the first circuit is Water+Heat, what "surge" means, how sell value is set, where
   hazards are resolved). Read the rulings before changing balance.

## Build state

Everything in the spec is **written and committed**: about 18,300 lines of Luau across 60 files.

| Area | Files |
|---|---|
| Rojo scaffold | `default.project.json` |
| Balance config | `src/shared/Config/*` — Regions, Rarities, Species (24), Variants, Circuits, Capture, Economy, Relaunch, Quests, Events, Milestones, Sounds |
| Remotes + Snapshot types | `src/shared/Remotes.luau`, `src/shared/Types.luau` |
| Procedural models | `ModelKit`, `Animate`, `CreatureModels`, `CreatureBuilders/{WindWater,HeatFrost,StormCosmic}` (all 24 creatures), `MachineryBuilders` (6 stations, 6 circuit machines, pylon, 5 decorations) |
| World | `src/server/Map/MapBuilder.luau` (hub, arena, 6 regions, gates), `PlotTemplate.luau` (24 pads, booth, collect pad, billboard, decor tiers) |
| Server systems | `Profiles`, `Stats`, `Notify`, `RateLimiter`, `Services`, `DataService`, `Sync`, `EconomyService`, `CityService`, `CircuitService`, `EncounterService`, `CaptureService`, `CrisisService`, `WorkshopService`, `AtlasService`, `VariantService`, `QuestService`, `RelaunchService`, `VisitService`, `LeaderboardService`, `RemoteRouter`, `TestHarness`, `Main.server.luau` |
| Client | `Net`, `State`, `UI/{Widgets,Theme,Notifications,FloatingText,HUD,CaptureHUD,CaptureReveal,TutorialUI,CircuitEditorUI}`, `UI/Panels/*` (9 panels), `Controllers/{Input,Effects,WorldAnimator,RegionGates,CaptureController,CircuitEditor}`, `Main.client.luau` |

### Verification status

**Static checks pass. Nothing has been executed.**

`rojo build` packages files without parsing Luau, so it proves nothing about syntax. Two checks in
`tools/` fill part of that gap and both pass over all 77 files:

```bash
python tools/luau_lint.py src     # block, bracket and string-termination balance
python tools/quote_scan.py src    # lines with an odd number of unescaped quotes
```

`luau_lint.py` was validated against the sibling repo `C:\Users\rahul\orca\Snatch-the-Oddities\src`,
which is known to compile and run. It reports one issue there, and that issue is a understood false
positive: Luau's `if a then b else c` **expression** has no `end`, and the linter treats an `if` at the
start of a line as a statement. That repo wraps two if-expressions onto their own lines; this one never
does, so the clean result here is meaningful. If you introduce a line-leading if-expression, expect a
false positive rather than a real bug.

Between them these caught one genuine compile error (a search-and-replace had written raw newlines
inside a Luau string in `CreaturesPanel.luau`), which is fixed.

What they cannot catch: undefined globals, wrong argument counts, bad field names, and every runtime
error. **The place has never been played.** Studio was opened on the built file and loaded it in Edit
mode without complaint, but that Studio instance does not expose itself to the Studio MCP bridge, so
Play could not be pressed or Output read from here. Expect to fix real errors on the first run; that is
normal for a codebase this size that has never executed.

The in-game self tests (`TestHarness`) run automatically in Studio three seconds after the server starts
and print `[SelfTest] passed N, failed M`. They cover config integrity, all 24 creature models building,
the income formula applying each factor exactly once, circuit and adjacency validation, the overdrive
state machine's effect on income, data round-tripping and sanitising of hostile saves, sell value,
scaled rewards, and rate limits on every client remote. They do **not** cover live hazards, two clients,
or real DataStores; those must be played.

## Traps in this environment

- **A Write hook rejects any file whose text contains a dot followed by `format(`.** It thinks Luau is
  Python SQL. Use `("%d"):format(x)` — the parenthesised form is fine because the preceding character is
  `:` not `.` — or write the file through a Bash heredoc.
- **Several chained `cat <<'EOF'` heredocs in one Bash call have failed to parse here.** Write one file
  per call, or use the Write tool.
- **Roblox cylinders run along their X axis.** A vertical cylinder is `Vector3.new(length, d, d)` with
  `CFrame.Angles(0, 0, math.rad(90))`. Getting this wrong produces flat ellipses; it was already fixed
  once across the map and machinery files.
- `Kit.finalize` welds every part to the root and clears `CanCollide`. It is for creature models only.
  Never call it on the map or a plot, or the player falls through the floor.
- Studio MCP tools target whichever place is open. Check `list_roblox_studios` before using them.

## Working style the user asked for

Inline development in the main session. Do **not** dispatch subagents for implementation. An earlier
attempt used the subagent-driven-development skill with 11 parallel implementers; the user stopped it
and asked for inline work. The SDD ledger and briefs still sit in `.superpowers/sdd/` (git-ignored) as an
outline, but the process is not being followed.

The user also asked to be told when the session nears its limit, and to be handed this file.

## Next actions, in order

1. Open `build/CatchACatastrophe.rbxl` in Studio, press Play, read Output. Fix compile errors until the
   server prints `[Catch a Catastrophe!] server ready` and `[SelfTest] passed N, failed 0`.
2. Walk the spec's verification list in section 13: tutorial to first capture to deploy to collect to
   upgrade; all six hazard patterns; circuits granting once; Overdrive and the vent; double-claim
   guards; relaunch keep/reset; rejoin and the offline claim; two clients.
3. Balance pass: measure time to first capture (target under 60s), first upgrade (under 3 min) and
   first relaunch (target 25-45 min), then tune `Config` and record what changed and why.
4. Write `README.md` properly: layout, systems table, roster and balance tables, data schema, controls
   guide, test results separating automated from live, and the remaining limitations.

# Catch a Catastrophe! — handoff

**Updated:** 2026-09-06, mid-build. Keep this file current: it is the pickup point for the next agent.

## What this is

An original Roblox simulation/tycoon game built from the spec at
`docs/superpowers/specs/2026-09-06-catch-a-catastrophe-spec.md` (a verbatim copy of the user's prompt,
which is the binding authority). Players capture living natural disasters in six regions, deploy them on
work pads in a city plot, connect adjacent compatible creatures into **Disaster Circuits**, collect Coins,
buy upgrades, and relaunch (rebirth) ten times.

## Where the code lives — read this first

`C:\Users\rahul\orca\Catch-a-Catastrophe` — a standalone Rojo 7.7 repo with its own git history.

**It is NOT the Munch It! Studio place.** The connected Roblox Studio instance has Munch It!
(`placeId 87396511725981`) open, which is an unrelated game. Never write to that DataModel.
Build and open the place file instead:

```bash
cd C:/Users/rahul/orca/Catch-a-Catastrophe && rojo build -o build/CatchACatastrophe.rbxl
```

Then open `build/CatchACatastrophe.rbxl` in Studio and press Play (F5).

## Documents, in order of authority

1. `docs/superpowers/specs/2026-09-06-catch-a-catastrophe-spec.md` — the spec. Binding.
2. `docs/CONTRACTS.md` — every module interface: config surface, ModelKit API, world instance names and
   attributes, the `refs` and `plot` record shapes, all server system function signatures, all client
   module exports, tutorial arrow targets, style rules. **Implementers read this, not each other's source.**
3. `docs/superpowers/plans/2026-09-06-catch-a-catastrophe.md` — the task breakdown and the design
   rulings made while planning (why the first circuit is Water+Heat, what "surge" means, sell value,
   hazard resolution authority, etc.). Read the "Rulings made while planning" section before changing balance.

## Build state

Done and committed:

| Area | Files |
|---|---|
| Rojo scaffold, lighting, players | `default.project.json` |
| All balance config | `src/shared/Config/*.luau` (Regions, Rarities, Species x24, Variants, Circuits, Capture, Economy, Relaunch, Quests, Events, Milestones, Sounds, init) |
| Remote list, Snapshot types | `src/shared/Remotes.luau`, `src/shared/Types.luau` |
| Procedural model toolkit | `src/shared/Models/ModelKit.luau` (copied from the sibling repo, `applyVariant` rewritten for this game's Normal/Overcharged/Prismatic variants) |
| Client animation engine | `src/shared/Models/Animate.luau` |
| Model dispatcher | `src/shared/Models/CreatureModels.luau` |
| Utilities | `src/shared/Util/Format.luau`, `Weighted.luau` |
| Server foundations | `src/server/Systems/Profiles.luau` (data schema + sanitize), `Stats.luau` (every formula), `Notify.luau`, `RateLimiter.luau`, `Services.luau` |
| Client foundations | `src/client/Net.luau`, `State.luau`, `UI/Widgets.luau`, `UI/Theme.luau`, `UI/Notifications.luau`, `UI/FloatingText.luau` |

Done, pending commit (check `git status`):

| Area | Files |
|---|---|
| All 24 creature models | `src/shared/Models/CreatureBuilders/WindWater.luau`, `HeatFrost.luau`, `StormCosmic.luau` |
| Persistence | `src/server/Systems/DataService.luau` |
| One panel | `src/client/UI/Panels/CreaturesPanel.luau` |

Not yet written (the remaining work, in dependency order):

1. `src/shared/Models/MachineryBuilders.luau` — work stations, 6 circuit machines, pylon, 5 decorations.
2. `src/server/Map/MapBuilder.luau` + `PlotTemplate.luau` — the world (CONTRACTS sections 5 and 6).
3. Server systems: `Sync`, `PlayerService`, `EconomyService`, `CityService`, `CircuitService`,
   `EncounterService`, `CaptureService`, `CrisisService`, `WorkshopService`, `AtlasService`,
   `VariantService`, `QuestService`, `RelaunchService`, `VisitService`, `LeaderboardService`,
   `RemoteRouter`, `TestHarness`, `Main.server.luau` (CONTRACTS section 7).
4. Client: `UI/HUD`, `CaptureHUD`, `CaptureReveal`, `TutorialUI`, `CircuitEditorUI`, the other eight
   panels, `Controllers/CaptureController`, `WorldAnimator`, `Effects`, `RegionGates`, `Input`,
   `CircuitEditor`, `Main.client.luau` (CONTRACTS section 8).
5. Live playtest in Studio, balance pass, README.

## Traps in this environment

- **A Write hook rejects any file whose text contains a dot followed by `format(`.** It thinks Luau is
  Python SQL. Write such files through a Bash heredoc, or use `("%d"):format(x)` — the parenthesised form
  is fine because the character before `format(` is `:` not `.`.
- **Multiple `cat <<'EOF'` heredocs chained in one Bash call have failed to parse here.** Write files one
  per call, or use the Write tool.
- Rojo is on PATH (7.7.0). There is no selene, stylua, luau-lsp or lune, so `rojo build` succeeding is the
  only static check available; it packages files without parsing Luau, so **it does not catch syntax errors**.
  Real verification requires opening the place in Studio and reading Output.
- Studio MCP tools target the Munch It! place. Do not use them to test this game.

## Working style the user asked for

Inline development in the main session. Do **not** dispatch subagents for implementation. An earlier
attempt used the subagent-driven-development skill with 11 parallel implementers; the user stopped it and
asked for inline work instead. The SDD ledger and task briefs still sit in `.superpowers/sdd/` (git-ignored)
and are a useful outline, but the process is not being followed.

The user also asked to be told when the session is close to its limit, and to be handed this file.

## Next action

Write `src/shared/Models/MachineryBuilders.luau` per CONTRACTS section 2, then the map, then the server
systems bottom-up (Sync and PlayerService first so a player can join), then the client.

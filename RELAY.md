# Catch A Catastrophe — Agent Relay State

- **Updated:** 2026-09-07 morning (Claude Code). Codex reached its weekly limit; Claude owns
  this repo until told otherwise, and took over Codex's unfinished collection pad indicator.
- **Repo:** `C:\Users\rahul\orca\Catch-a-Catastrophe` — Rojo 7.7, branch `main`
- **Working tree: CLEAN** apart from this file when it is being written. Everything is committed.
- **Studio:** "Catch a Catastrophe (placeId 88888194204730)". Instance ids change on every
  relaunch; call `list_roblox_studios`. Left in **Play** for the user to look at the route lights.
- **Rojo:** `rojo serve default.project.json --port 34872` must be started by hand after a Studio
  relaunch, and the Rojo plugin's **Connect** button pressed in Studio. Neither survives a restart.
  A Weppy sync plugin also attaches to this place on launch and writes `weppy-project-sync/`
  into the repo root; it is gitignored and not used. Rojo is the source of truth.
- **Not published.** PlaceVersion was 28 this morning (4 the night before), so the user has been
  saving to the cloud and may have published. The user publishes; agents do not.

> `/pickup` still points at Munch It! relay files. Ignore them for this project.

---

## Landed 2026-09-07, newest first

| Commit | What |
|---|---|
| `992aeb8` | **Camera never cached** in CaptureController / CircuitEditor; **Studio-only click diagnostics** on PlayerGui (`ClickDiagCount/Last/Nearest`). Click-to-capture PROVEN with an injected click: picker found the creature, claim accepted, card shown. |
| `1449a52` | **HUD Collect button removed** (it collected from anywhere); readout pops when the bank fills. "Remote Collector" Workshop upgrade approved for later. |
| `c7ed59f` | **Roads stop at destinations**: plot driveways end at the apron (were 30 studs inside the lot, over the pads), kiosk spokes stop at base discs, region route = hub-gate + 30-stud stub, arena floor road removed. Neon edge lines, bigger chevrons. LiveTest 29. |
| `deb77ee` | **Unlocked gate pane dissolves** (0.8 s) and stays invisible. User confirmed live. |
| `eb5b5d9` | **Collection pad pays the moment you step on** (`Config.Economy.collectHoldSeconds = 0`, shared by server and indicator). Codex's 1 s hold read as broken. |
| `b74234b` | **Route markings sunk into the slab**: 388 of 388 were 0.005-0.015 studs above the asphalt and shimmered; now 0. Left: 15 junction slab overlaps and the plot Platform/Apron seam. |
| `281b0a5` | **Creatures no longer teleport** (legs continue from the last leg's end), Gust/Ice Wave walls are 3 studs and jumpable, hitPenalty 2 -> 1, knockback 38 -> 16. A standing-still probe caught a Common in 10.7 s; it never finished before. SelfTest 451. |
| `f5c1bb9` | Neon route chevrons with a marching light toward the destination (`Controllers/RouteLights`); always-on-top waypoint signs over gates, hub destinations and your own city (`Controllers/Waypoints`). LiveTest 22 → 27. |
| `7e78ecf` | Codex's on-pad collection indicator, finished and verified: bank, status, progress bar, driven by the server's Collection* player attributes. Tutorial step 4 text updated. |
| `44880b1` | Pointing at a creature is judged **on screen** (projected body radius), not by raycast. See trap below. |
| `0d88ea2` | Capture hint per device ("Press E or click" / "Tap Capture" / "Press X"); left-click on a creature starts the tether. |
| `5af5dbb` | **Creatures were frozen statues on every client.** Root cause and fix below. Almost certainly the whole "catching is buggy" report. |
| `37b71f4` `4c2b34d` | Codex's overnight work as checkpoints: server-side stand-to-collect cycle; text sidebar, wider dark roads, tutorial shake fix. |
| `3541904` `eb71109` | gitignore: Weppy runtime folder, review screenshots in `build/`. |

Earlier (09-06): gate unlock at the gate + nudge loop, walk speed x1.5, pad picker, 44px toast close.

---

## Verified live today

| Check | Result |
|---|---|
| Creature beside player, camera near, nothing initialised by probe | moved **8.24** studs in 2 s (roam is 4/s); was **0.00** before `5af5dbb` |
| Client-vs-server creature position gap | **< 0.1** studs; was 8–17 |
| Screen-space pick at 20 studs | body is a 106 px target; belly click inside, 1.5 bodies away outside |
| Route chevrons | 338 of 338 Neon across 25 routes; lit block advanced toward higher Index over 0.45 s |
| Waypoint signs | 11 (6 gates, 4 hub, 1 city); locked gates show "Unlock X Coins · N away"; "Your City" hidden at spawn |
| Collection indicator | "Stand here" → "Stay on the pad / Collecting…" → "Collected +12 Coins", bank 8.77 → 0, cycle repeated (+8) |
| Roaming legs | 2 boundaries in 11 s, both continuous; max single-tick move 1.08 studs (was 13-19) |
| Beginner capture | stand 4 studs away, never dodge: Common **caught in 10.7 s** (never finished before) |
| Road markings | 0 of 388 in z-fight range of a road top (was 388); tops proud 0.077 |
| Collection pad | step on with 8.83 banked: paid +12 after 0.5 s, then +4 as it refilled |
| Suites | SelfTest **451** / 0 · LiveTest **27** / 0 |
| Client errors | none from game code (one stock `rbxasset://` sound, pre-existing) |

**Click-to-capture is verified** with real injected mouse input (`user_mouse_input`): with a
camera tracking a creature so it sits at the screen centre, one left click made the game's own
handler log `creatureUnderPoint=breeze_bean`, the server accepted the claim, the capture card
showed. The user still reports clicks doing nothing; the Studio-only diagnostics in
CaptureController record their clicks. Read PlayerGui attributes `ClickDiagLast` and
`ClickDiagNearest` after they click. Remove the diagnostics once explained.

**Probe lessons from that hunt:** the assistant's probes do NOT receive UserInputService input
(plugin context), so a probe-side InputBegan recorder sees nothing; only game scripts or
`user_mouse_input` count. And aim at where the creature IS at click time: they roam 4 studs/s, and
the seconds between framing and clicking made every early injected click a clean miss.

---

## Root causes found today (do not re-diagnose)

**Frozen creatures.** A model replicated from the server reaches the client BEFORE its parts:
at the instant `CollectionService`'s added-signal fires for it, it has no PrimaryPart, no Root
and zero children (reproduced with a server-spawned tagged model; parts landed 0.5 s later).
`Animate.track` found no root and returned silently; `WorldAnimator.track` had already marked
the model tracked and never retried. Fix: `Animate.track` returns a boolean, `WorldAnimator`
retries one frame after each `ChildAdded` / `PrimaryPart` change until it registers. Self-test
suite `animate` covers it.

**Clicks passed through creatures.** Every client-built body part is `CanQuery = false` by
`ModelKit` convention (so the camera does not pop against creatures and they never block pad
clicks); only the invisible 1-stud Root at the pivot can be hit by a ray. Do not flip CanQuery.
`CaptureController.wildAtScreenPoint` projects nearby wild models and tests the point against
the body's projected radius (height/2 + 0.75 studs), Root raycast still winning when it lands.

**"Tap Capture" on a keyboard.** The hint was touch wording shown to every device; the touch
button it named is hidden when a keyboard exists; there was no mouse binding for capture at all
(only the Containment Tether tool's Activated, and the tool is never equipped).

---

## Traps for probes (execute_luau)

- **Own module cache, both datamodels, and stale across probes in Edit.** A `require` in a
  probe returns the module as first cached by an earlier probe. After editing a module, an
  Edit-mode `require` still returns the OLD one. Verify through the instance tree, remotes
  (`Net.invoke("GetState")` from a client probe), or a fresh Play session. Cloning the
  ModuleScript before requiring also works for pure modules.
- **The Studio assistant parks the camera.** Probes have found `CameraType = Scriptable` with the
  camera 200+ studs from the character. `WorldAnimator` culls by camera distance (220), so
  creatures look frozen in that state for a reason that is not a game bug. Pin
  `CameraType = Custom`, `CameraSubject = humanoid` before measuring anything visual.
- **A probe-side `WorldAnimator.init()` keeps running** after the probe ends and will animate
  models, contaminating the next measurement. Restart Play for a clean read.
- **Capturing a creature from a probe:** teleport to the server's path-interpolated position
  (`PathFrom:Lerp(PathTo, (GetServerTimeNow()-PathStart)/PathDuration)`), never the model pivot;
  `Net.fire("StartCapture", uid)` ~0.6 s later; orbit at 8 studs, 15°/tick, so the gust's aim line
  is stale when it arrives; keep each probe under ~13 s; the claim survives gaps; a vanished model
  means captured OR expired, confirm with `GetState`. A Common lands in one ~10 s window.
- **`VirtualInputManager` is unavailable** to probes (no RobloxScript capability). Mouse clicks
  and key presses cannot be faked; a human has to do them.
- **The structural linter** (`tools/luau_lint.py`) flags multi-line `if … then … else` expressions
  passed as call arguments as unclosed blocks. Hoist them into locals.
- **Do not `require` `Notifications` from a probe:** it rebuilds its stack inside the live gui.

---

## Still open

| # | Playtest item | State |
|---|---|---|
| 1 | Travel via plane/portals | Parked by the user |
| 2 | UI declutter / routes faint | Routes: **done** (lights, signs, Neon edges, roads end at destinations). Sidebar: Codex rebuilt it. Progression-gated panels: not started |
| 3 | Movement speed | Done (`4e50529`) |
| 4 | Change creatures at the pad | Done (`2c152fe`) |
| 5 | Plot rework so creatures stand out | Parked ("maybe") |
| 6 | "Catching is buggy af" | Frozen creatures (`5af5dbb`), teleporting legs, unjumpable wall, 2 s penalty + eject knockback: all fixed today. **Re-test with the friends** |
| 7 | Can't open a new area | Done (`d8634e7`) |
| 8 | Notification loop | Done (`d8634e7`) |

### Capture balance (applied, `281b0a5`)

Base times 8/10/13/16 s unchanged. `hitPenalty` 1, `knockback` 16, `wallHeight` 3. The
`capture balance` self-test suite pins the rules (penalty below every attack interval, knockback
below tether range, wall lower than a jump, legs continuous). Legendary still needs ~14% dodging
within the 45 s claim. **Next lever if it still feels off:** per-rarity `attackInterval`, not base
seconds. Re-test with the friends first.

### Other

- **Live build stamp** — deferred by the user; small; now unblocked.
- **Relaunch curve** — `100,000 × 3^R` vs additive `1 + 0.25R`; Crisis reward cap 150K. User's call.
- **Z-fighting left over:** 15 road-slab overlaps at junctions (both tops at 0.525) and each plot's
  Platform/Apron one-stud seam. Small patches; alternate slab heights or trim at the junction.
- **Mobile pass** — nothing today was checked on touch.

## Approved but not built

- **Remote Collector** Workshop upgrade: paid convenience that restores collecting from anywhere.
- **Portals** (fast travel between hub, gates and your city, gated to unlocked regions). User: future idea.
- Widen the animator's 220-stud camera cull if far creatures snapping into place still reads as teleporting.
- **Region roads clip four plot corners** (angles 30/150/210/330 vs plots at 22.5+45k, radius 140). Needs a dog-leg through the gap between plots, or a different plot ring.

## Suggested next task

1. Ask the user whether the creature click works now; that is the only unconfirmed piece.
2. Re-test catching with the friends. If it still feels wrong, `hitPenalty` 2 → 1.
3. Live build stamp.
4. Progression-gated sidebar (hide Relaunch / Cities / Recipes until they matter).

## House rules

Stop Play before editing; Rojo syncs into Edit only. Confirm by reading `.Source`, then Play.
Verify by running. Read `docs/CONTRACTS.md` before changing an interface. Commit other agents'
work as its own checkpoint, attributed, before building on it.

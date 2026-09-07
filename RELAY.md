# Catch A Catastrophe — Agent Relay State

- **Updated:** 2026-09-06 (Claude Code, picking up from session "CaC Pickup #1")
- **Repo:** `C:\Users\rahul\orca\Catch-a-Catastrophe` — Rojo 7.7, branch `main`
- **Working tree: CLEAN.** Everything below is committed.
- **Studio:** "Catch a Catastrophe (placeId 88888194204730)", left **stopped in Edit**.
  Rojo serving on port 34872, Studio connected. Call `list_roblox_studios` for the
  instance id — it changes per session, do not hardcode it.
- **Not published.** The user publishes manually. Do not publish without being asked.

> Work only in this repo. The `/pickup` skill still points at `PycharmProjects\python\RELAY.md`
> and `orca\Munch-It-\RELAY.md`; both are **Munch It!** state and are the wrong project.

---

## Landed this session

The working tree had been carrying 17 modified + 8 untracked files from several
agents with no checkpoint between them. That is now four commits of prior work
(art, hazards, build stamp + HUD fix, docs) plus the two below.

### Playtest blockers 7 and 8 — they were one chain

The tutorial pointed the arrow at the blue gate, but the only region-unlock path
in the codebase was the Workshop panel's Unlock button. The game sent players to
a wall they could not open from where it sent them. And the "go to the Workshop"
nudge had a **5s cooldown against a 5s toast**, so it re-armed exactly as it faded
and never cleared while you stood there.

- `MapBuilder` puts an `UnlockPrompt` on every gate whose `unlockCost` is above zero.
- `RegionGates` handles the prompt: a confirm showing region, price and balance,
  then the existing `UnlockRegion` remote. **The server still authorises the spend**
  (`WorkshopService.unlockRegion`), so nothing new is trusted from the client, and
  the `unlock:<id>` tutorial event fires as it always did — the tutorial step needed
  no change, which is why charging at the gate was the right call.
- `applyGate` retires the prompt once a region is open, per player, the same way it
  already clears `CanCollide`.
- Nudge is now a 15s cooldown against a 4s toast, and it points at the prompt.
- **Toasts have a close button**, so no future self-re-arming toast can trap anyone.

### Playtest feedback 3 — movement speed

Base walk speed 16 to **24** (the user asked for 1.5x). Raising only the base would
have killed the upgrade, because 24 was also the old cap, so the whole ladder is
scaled by the same 1.5x: Running Shoes is **+1.5 per level to a cap of 36**, still
reached exactly at `maxLevel` 8.

`WorkshopPanel.effectText` recomputes these numbers itself instead of reading the
computed stat, so it holds a duplicate of the base and the cap. It was updated too.
**If you change walk speed again, change it in three places:** `Stats.luau:57`,
the `move_speed` entry in `Economy.luau`, and `WorkshopPanel.luau:42`.

---

## Verified live, 2026-09-06

Fresh Play session, Studio stopped afterwards:

| Check | Result |
|---|---|
| Gates carrying `UnlockPrompt` | 5 of 6 — the sixth is the free starting region, correct |
| Triggering a gate prompt | opens "Open Splashwater Bay?" with cost, balance, affordability warning |
| 13s stood at a locked gate | **1** toast, peak 1 on screen (was an unbroken stream) |
| Toast close button | present at `Toasts.Toast.Inner.Close`, label width leaves room for it |
| `applyGate` on an unlocked region | probe gate had `CanCollide` and prompt `Enabled` both cleared |
| Live `Humanoid.WalkSpeed` on spawn | **24** |
| Test suites | SelfTest passed 418 failed 0 · LiveTest passed 22 failed 0 |
| Client errors | none from game code (one unrelated stock-sound load failure) |
| HUD build pill | still renders the build stamp — the earlier HUD fix holds |

**Not verified:** a *successful* paid unlock end to end. The test player had 1.76K
coins against a 2.5K gate at 0 per second income, so reaching the price needs real
play. The confirm dialog, the remote it calls and the server handler are each
verified separately; only the three of them in one continuous motion is untested.

---

## Trap: probe scripts do not share the game's module cache

`execute_luau` runs with its **own require cache**, in both `Server` and `Client`.
`Profiles.all()` came back empty and the `Services` registry had 2 keys instead of
the real set. A fresh `require` gives you a fresh module, not the running one.

**Only two things cross the boundary: the instance tree, and RemoteEvents.**
Verify through `workspace`, `PlayerGui`, `CollectionService`, or by firing a real
remote. Requiring a module to read live state will quietly lie to you.

Corollary: requiring `Notifications` from a probe rebuilt its stack inside the
existing ScreenGui, giving it two `Toasts` frames. Harmless, gone when Play stops,
but do not mistake it for a bug.

---

## Still open

**Playtest feedback, from the user's friends. Their "pets" means the game's creatures.**

| # | Item | State |
|---|---|---|
| 1 | Travel to worlds via plane/portals | Parked by the user — "later" |
| 2 | UI declutter / revamp | **Not investigated.** Needs its own pass |
| 3 | More movement speed at the start | **Done** this session |
| 4 | Change creatures at the pad, not just in UI | Open. Same insight as 5: attention is on the pads |
| 5 | Plot rework so creatures stand out | Parked by the user — "maybe" |
| 6 | "Catching is buggy af" | **Open, vague, do not guess** — see below |
| 7 | Can't open a new area | **Done** this session |
| 8 | Notification keeps popping up, can't close | **Done** this session |

### Item 6 — three candidates, none confirmed (`src/shared/Config/Capture.luau`)

1. `knockback` 38 against `tetherRange` 18 — a hit throws you outside your own
   tether, so you eat a 2s penalty for the hit and 2s again for the break.
   See `CaptureService.luau` lines 374-413. A prior read described the knockback as
   *cosmetic and client-applied*, which would weaken this one — check before acting.
2. `claimRange` 22 against `tetherRange` 18 — a 4-stud band where the claim succeeds
   but the tether immediately reads out of range.
3. `targetPlayerFirstPatch` true — Heat and Storm spawn a patch under your feet on a
   1.4s and 1.1s telegraph. At walk speed 24 rather than 16 this is now *easier* than
   when the complaint was made, so re-test before changing anything.

**Ask the user what they actually saw, or watch a capture attempt.** Guessing here
changes game feel for everyone. `superpowers:systematic-debugging` is the right tool.

### Balance defects found by reading the numbers (no code changed)

1. **The relaunch curve is broken.** Cost is 100,000 times 3^R, exponential, against
   income of 1 plus 0.25R, which is **additive**. Relaunch 0 to 1 costs 100K; 8 to 9
   costs 656M, so 6,561 times the cost for 3 times the power. Pads do not compensate:
   `Stats.luau:52` caps at 24 and `habitat_capacity` maxLevel 18 means R=0 already
   reaches the cap, so relaunch pads are a head start, not permanent power. It is also
   inverted early: relaunch 1 costs 300K while unlocking all six regions costs 1.39M,
   so the optimal early play is to relaunch immediately and skip the content.
   *Suggested:* `costGrowth` 3 to about 1.7, income multiplier to a multiplicative
   1.25^R, and pre-unlock regions at higher R.
2. **The Crisis reward is capped at 150,000** in `Config/Events.luau` while quests use
   the same coins-per-second times seconds formula capped at 2e9 to 5e9. Past roughly
   1,250 coins per second the marquee co-op event pays less than a daily quest,
   permanently. Raising the reward maximum fixes it.
3. **Relaunch destroys the collection** — 1 to 3 anchors kept out of up to 120
   creatures, ten times over. This fights the Atlas and Prismatic mastery fantasy.
   A design call for the user, not a bug.

Worth preserving, do not refactor away: variants are skill-earned with no hidden
rolls; hazards are fully server-authoritative; the Crisis scales down to solo play.

### Deferred by the user

The build pill is gated on Studio or the test adapter, so live players never see it,
and there is no source-revision stamp — it cannot yet answer "are my latest changes
published?". The user said to handle live visibility after the P0 fixes. That is now.

---

## Suggested next task

1. **Feedback item 6.** Ask the user what "buggy af" looked like before touching
   capture feel. Three candidates are listed above and none is confirmed.
2. **Live build visibility** — the deferred item above, now unblocked.
3. **Feedback item 2, UI declutter** — needs its own investigation pass.
4. **The relaunch curve** — the largest balance defect, and a design decision the
   user owns rather than one to make for them.

## House rules

- Stop Play before editing. Rojo only syncs into the **Edit** datamodel, so a Play
  session that started before your edits is running stale code. Stop, let Rojo push,
  confirm by reading the script `Source`, then Play. This bit this session.
- Studio has been observed entering Play on its own. Re-check `get_studio_state`
  rather than trusting an earlier result.
- `load` and `loadstring` are **not** available in this Edit datamodel. The Munch It!
  `CLAUDE.md` claims they work; that note is about a different Studio setup.
- Read `docs/CONTRACTS.md` and the specs under `docs/superpowers/` before changing
  an interface.
- Verify by running, not by reading. This repo's specific failure mode is marking
  work done without a Play run — that is exactly how the HUD crash shipped.

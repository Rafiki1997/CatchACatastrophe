# Catch A Catastrophe — Agent Relay State

- **Updated:** 2026-09-06, late evening (Claude Code)
- **Repo:** `C:\Users\rahul\orca\Catch-a-Catastrophe` — Rojo 7.7, branch `main`
- **Working tree: CLEAN.** Everything below is committed.
- **Studio:** "Catch a Catastrophe (placeId 88888194204730)", left **stopped in Edit**.
  Rojo serving on port 34872, Studio connected. Call `list_roblox_studios` for the
  instance id — it changes per session, do not hardcode it.
- **Not published.** The user publishes manually. Do not publish without being asked.

> Work only in this repo. The `/pickup` skill still points at `PycharmProjects\python\RELAY.md`
> and `orca\Munch-It-\RELAY.md`; both are **Munch It!** state and are the wrong project.

---

## Landed today, newest first

### Manage creatures at the pad (playtest item 4)

Attention is on the pads, but the only way to change what was on one was the
Creatures panel: pick a creature, then pick a pad from a grid. Now every pad has
two verbs: **click** it to wire a circuit (unchanged), **E** at it to deploy, swap
or store.

- `PlotTemplate` adds a `ManagePrompt` (E, range 7) to every pad, **disabled**.
  Pads sit 8 studs apart so only the one you stand at can show it.
- `Controllers/PadPrompts` enables prompts **per player** on their own plot for
  unlocked pads when not visiting, and labels them from the snapshot: "Deploy /
  Pad n" empty, "Swap / <species>" occupied. Triggering one opens the picker.
  The server never reads the prompt.
- `UI/CreaturePicker` lists stored creatures by **estimated** income (region base x
  rarity x variant x relaunch — stored creatures report 0 in the snapshot) with
  a 44px "Put here" / "Swap in" button; an occupied pad also shows "On this pad"
  with "Send to storage". Escape, B, the X and the backdrop close it.
- **No new remotes, no new trust.** `DeployCreature`, `MoveCreature`, `StoreCreature`
  already validate ownership, unlock and being at home; `MoveCreature` from storage
  onto an occupied pad was already a swap (the occupant takes the mover's old
  place, which for a stored creature is storage).
- Self-test `plot`: every pad on a built plot carries the prompt, disabled, range
  under the pad spacing. SelfTest is now 421.

### Toast close button is a real touch target

The 18px close button from the gate-nudge fix broke the game's own 44px rule. It is
now a 44x44 invisible hit area on the toast's right edge with only the glyph
visible; the label makes room via the card's right padding (40).

### Earlier today (see git log)

Gate unlock at the gate + nudge loop fix (`d8634e7`), walk speed x1.5 (`4e50529`),
and four checkpoint commits of prior agents' art, hazard, build-stamp and docs work.

---

## Verified live, 2026-09-06

Two Play sessions for the pad picker, one for everything else; Studio stopped after.

| Check | Result |
|---|---|
| Pads carrying `ManagePrompt` | 192 of 192, **0 enabled on the server** |
| Own plot, fresh city | 6 enabled, 18 disabled; **0 enabled on other plots** |
| Labels | "Deploy / Pad 1" empty; "Swap / Breeze Bean" after deploy; followed the creature to pad 2 |
| Picker, empty storage | title, X, "Put on this pad from storage", empty-state line, hint, backdrop dismiss |
| Picker, stored row | "Breeze Bean · ● Common · **4/s** · Put here" (the estimate; snapshot says 0) |
| Picker, occupied pad | "On this pad / Breeze Bean · 4/s / Send to storage", then the stored row with "Swap in" |
| Deploy / Store / Swap remotes | each landed; after swap the stored one held pad 2 and the old occupant was in storage |
| Toast close | 44x44 (46.75 after UIScale), transparent, parented to the toast, padding right 40 |
| Test suites | SelfTest **421** / 0 · LiveTest 22 / 0 |
| Client errors | none from game code (one stock `rbxasset://` sound load failure, pre-existing) |

**Not verified:** pressing the picker's buttons with a real pointer (probes cannot
fire `Activated`; each button's remote was fired directly instead — identical
one-liners), Escape closing the picker (probes cannot send key events; the handler
mirrors Main.client's panel Escape), and gamepad. A human tap-through is worth one
minute.

---

## Traps

### Probe scripts do not share the game's module cache

`execute_luau` gets its **own require cache** in both `Server` and `Client`.
`Profiles.all()` comes back empty, `Services` has only what you required. **Only the
instance tree and RemoteEvents cross the boundary.** Read state with
`Net.invoke("GetState")` from a client probe; drive the game by firing the real
remotes; verify through `workspace` / `PlayerGui` / attributes.

### Capturing a creature from a probe (needed whenever a test wants a creature)

The Studio test adapter is **in-memory**: every Play session starts with 0
creatures, so any deploy/swap test has to catch one first. What works:

1. **Teleport to the server's idea of the creature's position, not the model's
   pivot.** The server lerps `PathFrom -> PathTo` by `(GetServerTimeNow() - PathStart)
   / PathDuration`; the client model can be 10+ studs away from that. Claim range is
   22, so teleporting to the pivot fails silently ("Get closer" toast, gone in 4 s).
2. `Net.fire("StartCapture", EncounterUid)` ~0.6 s after the teleport.
3. **Orbit** the server position at 8 studs, 15 degrees per 0.25 s tick. The gust
   aims at where you stood when it telegraphed and sweeps at 20 studs/s; standing
   still 2 studs away means every gust hits (2 s lost each) and an 8 s Common takes
   20+ s, which then hits the 45 s encounter lifetime.
4. Keep each probe under ~13 s (bridge limit). The claim survives the gap between
   probes; the model vanishing means captured **or** expired — confirm with `GetState`.

A Common Breeze Bean lands in one ~10 s orbit window. Uncommons (10 s) usually need two.

### Others

- Rojo only syncs into the **Edit** datamodel. Stop Play, confirm by reading
  `.Source`, then Play. Studio has entered Play on its own; re-check state.
- `load`/`loadstring` are not available in this Edit datamodel.
- `VirtualInputManager` is not available to probes (no RobloxScript capability).
- Requiring `Notifications` from a probe rebuilds its stack inside the live
  ScreenGui (two `Toasts` frames). Harmless, gone on stop, not a bug.
- If walk speed changes again it lives in three places: `Stats.luau:57`,
  `Economy.luau` `move_speed`, `WorkshopPanel.luau:42`.

---

## Still open

| # | Playtest item | State |
|---|---|---|
| 1 | Travel via plane/portals | Parked by the user |
| 2 | UI declutter / revamp | **Not investigated.** Needs its own pass |
| 3 | More movement speed | Done (`4e50529`) |
| 4 | Change creatures at the pad | **Done** (this session) |
| 5 | Plot rework so creatures stand out | Parked by the user ("maybe") |
| 6 | "Catching is buggy af" | **Open, vague, do not guess.** Three candidates below |
| 7 | Can't open a new area | Done (`d8634e7`) |
| 8 | Notification loop, can't close | Done (`d8634e7`) |

### Item 6 candidates (`src/shared/Config/Capture.luau`)

1. `knockback` 38 vs `tetherRange` 18 — but the knockback is **client-side cosmetic**
   (`Capture.luau:4`, `:33`), so the server's range check may not see it. Check first.
2. `claimRange` 22 vs `tetherRange` 18 — a 4-stud band where the claim succeeds but
   the tether reads out of range immediately.
3. Heat/Storm first patch under your feet on a 1.4 s / 1.1 s telegraph.

One more observation from this session's probes, relevant to how it *feels*: standing
next to a Wind creature without moving, every gust connects, and a Common that should
take 8 s stretched past 20 s. A player who does not move sideways will read that as
"buggy". Worth asking the testers whether they were moving.

### Balance defects (numbers only, nothing changed)

Relaunch cost is `100,000 x 3^R` against additive `1 + 0.25R` income (8->9 costs 6,561x
for 3x power; relaunch 1 is cheaper than unlocking the regions). Crisis reward capped at
150K while quests scale to 2e9+. Relaunch keeps 1–3 anchors of up to 120 creatures.
Design calls for the user; suggestions are in the git log for `9df1870`.

### Deferred by the user

Live build visibility: the HUD pill is Studio/test-adapter only and there is no
source-revision stamp. Now unblocked.

---

## Suggested next task

1. **Item 6** — get the testers' description (the checklist artifact asks for it).
2. **Live build stamp** — deferred, now unblocked, small.
3. **Item 2, UI declutter** — a progression-gated sidebar is the obvious first cut.
4. **The relaunch curve** — the largest balance defect; the user's decision.

## House rules

Stop Play before editing. Verify by running, not by reading — that is how the HUD
crash shipped. Read `docs/CONTRACTS.md` before changing an interface; both new
modules are documented there.

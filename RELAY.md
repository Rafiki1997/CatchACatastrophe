# Catch A Catastrophe — handoff to Claude

Updated: 2026-09-06.

Work only in `C:\Users\rahul\orca\Catch-a-Catastrophe`.
Read the **Current handoff to Claude** section at the top of `HANDOFF.md` first.
It supersedes the older checkpoints in that file. Do not follow historical paths
to other projects. Preserve all existing uncommitted work.

## Latest task

User wanted to see which game version is running and whether latest changes are
published. Added snapshot build metadata and a HUD stamp in:

- `src/shared/Types.luau`
- `src/server/Systems/Sync.luau`
- `src/client/UI/HUD.luau`

The stamp displays `Build <game.PlaceVersion> | Studio/Live`. Source was inspected
during handoff. It currently only displays in Studio or test-adapter sessions;
normal live players cannot see it. There is no source revision stamp or automatic
published-versus-local comparison. This limitation should be addressed before
claiming the original live-version visibility goal is fully satisfied.

Prior static lint and quote checks passed on 80 source files; Rojo build succeeded.
No runtime validation of this latest HUD change is recorded. No checks rerun during
the documentation-only handoff. No publishing or commit performed in this handoff;
published state remains unverified. Last recorded Studio state was Play stopped.

## Earlier completed work and next steps

Terrain/scenery polished; approved creature style extended to all 24 creatures.
Water, Heat, Frost, Storm, and Cosmic capture hazards verified. Prior runtime
results: 418 self-tests, 22 live tests, 10 controlled hazard cases passed.
See `docs/CREATURE_ART.md` and `docs/HAZARD_VERIFICATION.md`.

After resolving version-display expectations, next suggested gameplay work is
manual circuit-editor/Overdrive vent verification, then relaunch, offline rejoin,
Crisis, multiplayer, and balance testing. No new feature is authorized by the
handoff request itself.

Use Rojo for source sync. Confirm Studio is stopped before script edits. Read
`docs/CONTRACTS.md` and the binding spec under `docs/superpowers/specs/` before
changing interfaces or gameplay. The user has handled publishing manually;
do not publish without explicit authorization.

# Catch A Catastrophe agent instructions

Work only inside this repository: `C:\Users\rahul\orca\Catch-a-Catastrophe`.
Do not read relay or handoff files from other projects, or infer missing state
from another repository.

## Pickup protocol

When the user says `pickup`, `pick up`, or `/pickup`, follow this protocol:

1. Read the root `RELAY.md` before inspecting or changing source files.
2. Treat the newest dated checkpoint in `RELAY.md` as authoritative over older notes.
3. Summarize the last completed work, current unfinished work, validation results,
   Roblox Studio state, and publishing state.
4. Check the connected Roblox Studio state before editing. Do not edit scripts while
   Studio is in Play mode; stop Play first.
5. Stop Play mode before changing scripts, then Rojo-sync and confirm by reading
   `.Source` before re-entering Play.
6. Preserve existing uncommitted changes. Do not publish or commit unless the user
   explicitly asks.
7. Work only in this repository.
8. Never publish or commit unless explicitly asked.
9. After completing work, update `RELAY.md` with:
   - feature completed
   - files changed
   - tests and validation
   - remaining limitations
   - Studio state
   - publishing state
   - recommended next task

## Registration

This protocol is also registered as a `pickup` skill at
`.opencode/skills/pickup/SKILL.md` (opencode) and
`.claude/skills/pickup/SKILL.md` (Claude Code). When the skill trigger is
used, it must behave exactly as the numbered protocol above, starting with
reading the root `RELAY.md`.

The relay file is the cross-model memory for this project.

## Source workflow

Use the project source as the source of truth and Rojo for Studio synchronization.
Read `docs/CONTRACTS.md` before changing a module interface. Run the relevant lint,
quote scan, build, and Studio checks before claiming a change is complete.

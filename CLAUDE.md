# Catch A Catastrophe handoff instructions

This repository is the only project in scope. Work in
`C:\Users\nguye\Documents\repos\catch-a-catastrophe\CatchACatastrophe`. Do not read relay or handoff files
from other projects, or infer missing state from another repository.

When the user says `pickup`, `/pickup`, or `pick up`, follow this protocol:

1. Read the root `RELAY.md` first, before inspecting source files.
2. Treat the newest dated checkpoint in `RELAY.md` as authoritative.
3. Summarize completed work, unfinished work, validation results, Roblox Studio
   state, and publishing state.
4. Check the connected Roblox Studio state before editing; do not edit scripts
   while Studio is in Play mode.
5. Stop Play mode before changing scripts, then Rojo-sync and confirm by reading
   `.Source` before re-entering Play.
6. Preserve existing uncommitted changes.
7. Work only in this repository.
8. Never publish or commit unless explicitly asked.
9. After completing work, update `RELAY.md` with: feature completed, files
   changed, tests and validation, remaining limitations, Studio state,
   publishing state, and recommended next task.

This protocol is also registered as a `pickup` skill at any of `.opencode/skills/pickup/SKILL.md`
or `.claude/skills/pickup/SKILL.md`.

Use Rojo and the repository source as the source of truth. Read
`docs/CONTRACTS.md` before changing interfaces. Validate changes with the relevant
static checks, Rojo build, and Studio runtime checks.

## Current state

Two regions are now built to their approved concepts on the linear chain:
Gusty Gardens, and Splashwater Bay ("Tropical Tidepools", 2026-09-22). The
player plot is rebuilt to "Pocket Power Town". None of it has been seen in
Studio and none of the sculpted meshes are made. Detail is the top of `RELAY.md`.

**`src/server/Map/` is almost entirely untracked** - only `MapBuilder.luau` and
`PlotTemplate.luau` are in git. Ten region modules and every prop kit have no
version-control safety net; check before deleting or rewriting one.

## Matching a reference image

Contract checks answer "did I break anything", never "does it look like the
reference". When the task is to match a picture:

1. Detect a regular feature in the reference (the plot used its 6x4 pad grid),
   fit a ground homography, read every landmark back in world studs.
2. Fit the camera too, render the build from it, and compare side by side every
   iteration. The plot's camera fitted to 1.5 px rms.
3. Check whether the reference is cropped. The plot concept hides the front ~8
   studs, which silently shifts every measurement taken from it.

Traps that cost time: a software renderer mirrors left/right unless camera
right = forward x up (so plot local +X lands on image LEFT); two crossed squares
make an eight-pointed star, not an octagon (use a cylinder); `luau_lint.py`
false-positives on a line-initial `if` expression, so assign it to a local first.

## Decisions worth keeping

| Decision | Why |
|---|---|
| Measure the concept, never eyeball it | A first pass passed every check and still looked nothing like the reference |
| Placeholder art is built to full fidelity | "Placeholder" is only right when a blockout was asked for |
| Plots use the region asset pipeline | `PropSites` + `PlotProps.apply` swap stand-ins for meshes all or nothing, as the six regions do |

## Plot files

| File | Role |
|---|---|
| `src/server/Map/PlotAssetSpec.luau` | The 12 plot asset names and their exact bounds |
| `src/server/Map/PlotProps.luau` | Swaps `PropSites` placeholders for `PlotPropTemplates` meshes |
| `tools/verify_plot_props.luau` | Headless Lune harness; `lune run` it from the repo root |
| `docs/art/plots/2026-09-21-player-plot/` | Concept, Astra asset request, `comparison-concept-vs-build.png` |

## Next

1. Stop Play, Rojo-sync, boot, read `[SelfTest]` and `[LiveTest]`.
2. Walk Splashwater Bay: south threshold to both pools, on to the Cinder gate.
   Retake the elevated shots and compare with each concept.
3. Hand the two asset requests to Astra -
   `docs/art/plots/2026-09-21-player-plot/POCKET-POWER-TOWN-ASSET-REQUEST.md` and
   `docs/art/regions/2026-09-22-splashwater-bay/SPLASHWATER-ASSET-REQUEST.md`.
4. On delivery: import the bundle in Edit mode, capture the matching
   `*PropTemplates.rbxm` preserving `MeshSize`, rerun the harness, retake the
   comparison.
5. Cinder Canyon is the next region to bring onto the chain concept.

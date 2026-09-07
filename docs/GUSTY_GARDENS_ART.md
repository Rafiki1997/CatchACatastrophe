# Gusty Gardens creature style — approved

Status: approved by the user and extended to the rest of the roster. Shared eyes,
smiles, and cheek details live in `src/shared/Models/ToyFace.luau`. See
`docs/CREATURE_ART.md` for the full rollout and current review controls.

## Shared direction

Rounded collectible-toy proportions with large readable faces and a distinct
silhouette for each creature. Use broad colour areas and a few purposeful details
that survive normal gameplay distance. Dark eyes and small white glints are fixed
colours so variant tints preserve facial contrast. Reserve glow for wind effects
and the knight's visor; goggles use opaque blue lenses with visible pupils.

## The four models

- Breeze Bean: thicker leaf ears, raised veins, cream face patch, peach cheeks,
  small side nubs, wider eye spacing, and a two-piece smile.
- Gust Bunny: rounder head and body, broader ears with pink insets, belly patch,
  cream muzzle and tooth. Two separate wind funnels widen toward the body and
  rotate around their own foot centres while remaining flat.
- Twister Terrier: larger head, broader cream muzzle, floppy ears, smiling mouth,
  and oversized goggles with pupils, glints, and a connecting bridge.
- Sir Spins-a-Lot: soft stacked funnel rings that remain flat while rotating,
  larger helmet, paired visor eyes, gold rivets and crest, swept plume, and
  breastplate badge. Existing lance and sneakers retain the character concept.

## Validation and review

All four build as Normal, Overcharged, Prismatic, and silhouette models. Each has
24–29 parts, at most two lights and three emitters, and a visual top within 20%
of its configured height. All 222 self-tests and 22 live tests pass. Water builders
in the same source file are unchanged. Structural lint, quote scan, and Rojo build pass.

The original four-creature lineup has been replaced by the region/appearance
review utility in `tools/creature_art_review.luau`. It is outside the Rojo source
tree. The built-in Studio `screen_capture` tool supports visual inspection;
the separate connector's licensed screenshot action is not required.

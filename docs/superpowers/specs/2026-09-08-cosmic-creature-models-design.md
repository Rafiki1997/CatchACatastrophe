# Cosmic creature model replacement design

## Goal

Replace the current Orbit Outpost creature examples with six concept-first
procedural Roblox models that satisfy `docs/CreateACatastropheCreatureCreation.md`.
The models must remain readable as flat-colored geometry, use the existing
`ModelKit` conventions, and be easy to inspect in the temporary Studio art
review.

## Roster

The four wild entries keep their existing gameplay slots. Two egg-only entries
provide the higher showcase tiers without changing the wild roster of the other
five regions.

| Tier | ID | Concept | Geometry anchor |
| --- | --- | --- | --- |
| Common | `rubble_runt` | asteroid fragment cluster | asymmetrical faceted rock body with magnetic feet |
| Uncommon | `lagrange_loper` | Lagrange-point orbital mechanics | two lobes joined by a gravity bridge and two stable-point moons |
| Rare | `pulsar_prickle` | neutron star / pulsar | flattened dense star body with physical magnetic poles and beam fins |
| Legendary | `rochebreaker` | Roche-limit tidal disruption | stretched core with a visible solid fragment stream |
| Epic | `nebula_noodle` | nebula filament | chunky curled gas filament surrounding a dark void core |
| Mythic | `universe_seed` | pocket universe | seed-shaped shell with orbital bands and a controlled opening animation |

`Epic` will be added as an egg-only rarity tier. The existing wild rarity
selection remains Common, Uncommon, Rare, and Legendary, so other regions do
not gain a new species slot.

## Implementation

1. Replace the four Orbit Outpost entries in `src/shared/Config/Species.luau`
   with the four wild IDs above.
2. Replace the current Cosmic Egg entries with `nebula_noodle` and
   `universe_seed`; preserve `eggOnly = true` so they do not enter wild
   encounter selection.
3. Add the `Epic` rarity definition and include it in the egg-tier metadata,
   keeping Mythic as the final showcase tier for this roster.
4. Replace the four Cosmic builders in
   `src/shared/Models/CreatureBuilders/StormCosmic.luau` and add two new
   builders. Each builder will use `Kit.part`, `Kit.blob`, `Kit.orbiter`,
   `Kit.particles`, and `Kit.setAnim` only through the established builder
   contract; `CreatureModels` remains responsible for variants, rarity glow,
   silhouette mode, scaling, and finalization.
5. Extend `tools/creature_art_review.luau` so Orbit Outpost shows the four wild
   entries followed by the two egg-only entries, with labels for rarity. The
   tool remains temporary and outside the Rojo source tree.

## Visual and effect constraints

- Common and Uncommon use solid geometry with no or minimal emitters.
- Rare uses one restrained animated cosmic detail.
- Legendary uses a clean fragment-stream effect and one aura/light treatment.
- Epic uses a small number of orbiting filament pieces and controlled motes.
- Mythic uses the shell, orbital bands, void opening animation, and a limited
  aura; it must not become a particle-covered blob.
- Face elements remain fixed-role so variants do not recolor eyes, pupils, or
  other readability-critical parts.
- Keep each model within the established visual budget: readable silhouette,
  anchored root, no collision, and no more than the existing light/emitter
  limits.

## Data flow and compatibility

`Species` supplies the ID, rarity, palette, animation, height, and egg-only
status. `CreatureModels.build` resolves the builder, applies variants and
rarity effects, handles silhouette mode, scales the finished model, and
finalizes it. Encounter systems continue to read only `Species.byRegion` for
wild creatures; Cosmic Egg systems can address the two egg-only IDs through
`Species.byId` and `Species.eggList`.

## Validation

- Run the Luau lint, quote scan, and Rojo build.
- Run the creature self-tests and verify every new ID resolves to a builder.
- Verify normal, Overcharged, Prismatic, and Silhouette builds for all six
  Cosmic entries, including anchoring, collision state, measured height, and
  effect budgets.
- Run the temporary art review in Studio, inspect the six silhouettes and
  labels, and confirm cleanup after closing the review.

## Known limitation

The preview is intended to make the six examples visible in Studio. It does not
turn Epic into a wild-spawn rarity; Epic remains egg-only for this replacement
so the established six-region gameplay contract stays intact.

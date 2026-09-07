# Creature art rollout

The user approved the Gusty Gardens style and requested it across the remaining
20 creatures. The full roster now uses rounded proportions, readable expressions,
fixed dark pupils and glints, and broad signature features rather than tiny details.
Slush Sloth retains closed sleepy eyes; the knight retains its visor expression.

| Region | Creature | Refinement |
| --- | --- | --- |
| Water | Drizzle Duck | Fuller head, cream belly, wider eyes, warm cheeks |
| Water | Puddle Pug | Larger face and muzzle, smile, small tongue |
| Water | Monsoon Manta | Fuller central body, wide eyes, smile, wing markings |
| Water | Tsunami Toad | Raised eye sockets, readable pupils and cheeks, retained crown/wave |
| Heat | Cinder Chick | Larger head, wide eyes, ember-coloured cheeks |
| Heat | Sizzle Salamander | Broad head, pale lower jaw, playful smile |
| Heat | Magma Muncher | Broad eyes and fewer, larger blunt furnace teeth |
| Heat | Mount Chomp | Larger tortoise face, smile, consolidated crater smoke |
| Frost | Flurry Ferret | Fuller head, rounded mask, wider eyes and smile |
| Frost | Slush Sloth | Cream face, angled sleepy lids, cheeks and smile |
| Frost | Blizzard Bison | Broader muzzle, larger eyes, smile and raised snow cap |
| Frost | King Coldsnout | Large eyes, fewer broader fur tufts, crown jewel, connected curved tusks |
| Storm | Static Sprout | Fuller bud, cream face patch and smile |
| Storm | Zap Raccoon | Fuller head, rounded dark mask and smile |
| Storm | Thunder Thumper | Fuller head, rounded brow, broad eyes and grin |
| Storm | Boltjaw Behemoth | Broader head/muzzle, dark nostrils and wider eyes |
| Cosmic | Orbit Orb | Larger eyes, smile, coherent tilted satellite ring |
| Cosmic | Comet Cat | Larger head, cream muzzle, wider eyes and smile |
| Cosmic | Gravity Gobbler | Readable recessed starry mouth, rounded lip, broad eyes |
| Cosmic | The Big Whoops | Larger eyes, coherent disc, orbiting round caution sign with attached punctuation |

`ModelKit` preserves creature-specific effects first. Variant and rarity additions
use the remaining slots up to two lights and three emitters. Colour treatments
still apply when no extra effect slot remains. This avoids duplicate decorations
overpowering silhouettes or exceeding the established rendering budget.

## Verification

- All 96 species/appearance combinations build: Normal, Overcharged, Prismatic,
  and collection silhouette. 22–43 parts, at most two lights and three emitters.
- All model tops remain within 20% of configured height; gameplay values unchanged.
- 342 self-tests and 22 live tests pass. The additional 120 self-test assertions
  check finished appearance budgets, anchoring/collision, and effect-free silhouettes.
- Structural and quote checks pass for 79 source files; Rojo build succeeds.
- Studio screenshots inspected for all five new region lineups. Flat facial
  meshes and the mammoth's connected tusks were corrected after visual inspection.
- Twenty animation samples across bunny/knight funnels and cosmic rings/sign
  confirm stable configured tilt and sign punctuation spacing.

## Review in Studio

During Play, run `tools/creature_art_review.luau` through the bridge's Client
datamodel. A temporary client-only lineup opens at Splashwater Bay with controls
for Previous region, Next region, Change appearance, and Back to game. All models
are shown at normal scale, facing the camera, Common through Legendary left to right.

The preview uses static poses to compare silhouettes. Normal gameplay continues
to use the existing animation controller. Back to game restores the prior camera
and enabled game interfaces. Stop Play also removes the review. The utility lives
outside `src`, creates no persistent scripts, and is not part of the saved build.

Region navigation, appearance switching, and cleanup were verified with actual
mouse input. The utility is open for the user's final review. Nothing published.

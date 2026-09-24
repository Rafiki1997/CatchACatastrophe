# Creature art rollout

The user approved the Gusty Gardens style and requested it across the remaining
20 creatures. The full roster now uses rounded proportions, readable expressions,
fixed dark pupils and glints, and broad signature features rather than tiny details.
Slush Sloth retains closed sleepy eyes; the knight retains its visor expression.
The Cosmic region now uses six concept-first models: four wild creatures and two
Cosmic Egg showcases. Each keeps a readable silhouette when rendered as a flat
colour block.

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
| Cosmic | Rubble Runt | Asymmetric asteroid cluster, magnetic feet, pebble satellites |
| Cosmic | Lagrange Loper | Unequal lobes, gravity bridge, stable-point moons |
| Cosmic | Pulsar Prickle | Flattened pulsar body, polar caps, beam fins |
| Cosmic | Rochebreaker | Stretched core, tidal fragment stream, warm breakup glow |
| Cosmic Egg | Nebula Noodle | Curled nebula filament wrapped around a dark void core |
| Cosmic Egg | Universe Seed | Faceted seed shell, seam, orbital bands, inner star |

`ModelKit` preserves creature-specific effects first. Variant and rarity additions
use the remaining slots up to two lights and three emitters. Colour treatments
still apply when no extra effect slot remains. This avoids duplicate decorations
overpowering silhouettes or exceeding the established rendering budget.

## Cosmic verification

- The four wild Cosmic models are Common, Uncommon, Rare, and Legendary.
- The Cosmic Egg contains exactly two egg-only tiers: Epic and Mythic.
- All six concepts have dedicated procedural model builders and collection silhouettes.

## Verification

- Static structure and quote checks pass; the Rojo build succeeds.
- Studio runtime and art-review validation must be rerun after the updated source
  is synchronized into the connected place.
- Animation samples should confirm stable bob, drift, pulse, sway, and hover poses
  for the replacement Cosmic builders.

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

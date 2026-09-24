# Cosmic Creature Models Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Orbit Outpost creature examples with six original procedural Roblox models spanning Common, Uncommon, Rare, Legendary, Epic, and Mythic.

**Architecture:** Keep the four existing wild slots and replace their species/builders with four new Cosmic concepts. Use two egg-only species for Epic and Mythic, add Epic to the rarity and egg configuration, and extend the temporary Studio art review to display all six. Reuse the existing `ModelKit`/`CreatureModels` contract so variants, silhouettes, rarity glow, animation, scaling, anchoring, and collision behavior remain centralized.

**Tech Stack:** Luau, Roblox Instances, `ModelKit`, Rojo, Studio self-tests, Python structural/quote checks.

**Spec:** `docs/superpowers/specs/2026-09-08-cosmic-creature-models-design.md`

## Global Constraints

- Work only inside `C:\Users\rahul\orca\Catch-a-Catastrophe`.
- Preserve the concept-first and flat-color requirements in `docs/CreateACatastropheCreatureCreation.md`.
- Keep wild rarity selection Common, Uncommon, Rare, and Legendary for all regions.
- Keep Epic and Mythic egg-only for this showcase replacement.
- Builders must face -Z, place feet at y = 0, and leave finalization/variants/rarity effects to `CreatureModels`.
- Do not commit or publish; the repository instructions require explicit user approval for either action.

## Files and responsibilities

- `src/shared/Config/Rarities.luau`: add the Epic rarity and mark Epic/Mythic as the active Cosmic Egg tiers.
- `src/shared/Config/Store.luau`: make Cosmic Egg odds and pity counters match the two active egg tiers.
- `src/shared/Config/Species.luau`: replace four wild and six egg-only Cosmic definitions with the six approved IDs.
- `src/shared/Models/CreatureBuilders/StormCosmic.luau`: implement six standalone concept-first builders.
- `tools/creature_art_review.luau`: show wild and egg-only Cosmic entries together and label rarity.
- `src/server/Systems/StudioTester.luau`: gift the new Legendary and two showcase species during Studio testing.
- `src/server/Systems/TestHarness.luau`: assert the new roster, rarity tiers, builders, finished model budgets, and egg behavior.
- `docs/CREATURE_ART.md`: record the new Cosmic lineup and validation results after Studio review.

### Task 1: Add failing roster and model-contract checks

**Files:**
- Modify: `src/server/Systems/TestHarness.luau` in `testConfig`, `testModels`, and egg tests around the existing Cosmic Egg assertions.

**Interfaces:**
- Consumes: `Config.Rarities`, `Config.Species`, `CreatureModels.build`, and `Kit.bounds`.
- Produces: self-test coverage that requires the six approved IDs and rejects missing builders, invalid egg tiers, unsafe parts, and over-budget effects.

- [ ] **Step 1: Add roster assertions before production changes**

Add a Cosmic roster check in `testConfig` that asserts the wild IDs are exactly `rubble_runt`, `lagrange_loper`, `pulsar_prickle`, and `rochebreaker`, and the egg IDs are exactly `nebula_noodle` and `universe_seed`. Assert `Config.Rarities.info.Epic` exists and `Config.Rarities.eggTiers` is exactly `{ "Epic", "Mythic" }`.

- [ ] **Step 2: Expand model checks to include egg-only Cosmic species**

Keep the existing 24-wild-species loop. Add a second loop over `Config.Species.eggList` using the same build, height, builder, anchor, collision, light, and emitter checks. The expected Cosmic showcase build count is `#Config.Species.list + #Config.Species.eggList`, and each of the six approved IDs must build in Normal, Overcharged, Prismatic, and Silhouette appearances.

- [ ] **Step 3: Update egg assertions for two tiers**

Change the egg test expectations from three chase tiers to two: every active tier must have an egg species, the fresh pity result must contain two entries, and the live hatch probe must seed `{ Epic = 49, Mythic = 199 }` and verify that Mythic is forced and resets both counters.

- [ ] **Step 4: Run the Studio self-test to confirm the new checks fail**

Run the existing Studio self-test after syncing the test-only changes. Expected result: the new roster and Epic checks fail because production config still has the old Cosmic IDs and no Epic definition. Do not proceed if unrelated suites fail before the expected new failures appear.

### Task 2: Replace Cosmic configuration and egg progression

**Files:**
- Modify: `src/shared/Config/Rarities.luau`
- Modify: `src/shared/Config/Store.luau`
- Modify: `src/shared/Config/Species.luau`

**Interfaces:**
- Consumes: existing rarity, store, region, and species schemas.
- Produces: six addressable Cosmic species with four wild entries and two egg-only entries; `Species.find("orbit_outpost", rarity)` continues to work for each wild tier.

- [ ] **Step 1: Add Epic without changing other regions’ wild slots**

Insert `Epic` into `Rarities.order` after `Legendary`, give it rank `5`, weight `0`, multiplier `30`, Legendary-compatible capture timing, a distinct Epic icon/color, glow tier `2`, and `broadcast = true`. Keep `Legendary` rank `4`, renumber `Mythic` to rank `6`, `Celestial` to rank `7`, and `Astral` to rank `8`; retain the latter three definitions as reserved tiers but remove `Celestial` and `Astral` from `Rarities.eggTiers`. Set `Rarities.eggTiers = { "Epic", "Mythic" }`.

- [ ] **Step 2: Update the Cosmic Egg data**

Change the Cosmic Egg description to mention Epic and Mythic. Keep the ordinary egg odds at Common `40`, Uncommon `30`, Rare `18`, and Legendary `9`; set Epic to `2.5` and Mythic to `0.5` so the total remains `100`. Set pity to `{ Epic = 50, Mythic = 200 }` and update nearby comments so they describe two counters.

- [ ] **Step 3: Replace the four wild species definitions**

Replace the Orbit Outpost entries with `rubble_runt` as Common, `lagrange_loper` as Uncommon, `pulsar_prickle` as Rare, and `rochebreaker` as Legendary. Each entry must provide a distinct palette, description, silhouette, animation style, and height matching its builder.

- [ ] **Step 4: Replace the egg-only species definitions**

Replace all six old egg-only entries with `nebula_noodle` as Epic and `universe_seed` as Mythic. Set both entries to use their own builder IDs, keep them out of `byRegion`/`byElement`, and set their configured heights and palettes to match the new models.

- [ ] **Step 5: Run config lint checks**

Run `python tools/luau_lint.py .` and `python tools/quote_scan.py src`. Expected result: structural and quote checks pass; the model checks remain failing only because the six new builders are not implemented yet.

### Task 3: Implement the six procedural builders

**Files:**
- Modify: `src/shared/Models/CreatureBuilders/StormCosmic.luau`

**Interfaces:**
- Consumes: `(model: Model, root: BasePart, palette, def)` from `CreatureModels` and the `ModelKit`/`ToyFace` helpers.
- Produces: builders registered under `rubble_runt`, `lagrange_loper`, `pulsar_prickle`, `rochebreaker`, `nebula_noodle`, and `universe_seed`.

- [ ] **Step 1: Implement `rubble_runt`**

Build a low asymmetric asteroid cluster from three to five faceted rock pieces, with visible crater discs, two magnetic horseshoe feet, a small face set into the front rock, and a gentle `bob` animation. Use solid rock materials and no emitter; the silhouette must read as a lopsided asteroid rather than a recolored animal.

- [ ] **Step 2: Implement `lagrange_loper`**

Build two unequal solid lobes connected by a narrow bridge, give it four short stepping feet under the lower lobe, and place two small moon pieces at opposite stable points with `Kit.orbiter`. Use a slow `orbit` or `drift` animation and at most one subtle mote emitter. Keep the face on the larger lobe so the model still reads as a pet.

- [ ] **Step 3: Implement `pulsar_prickle`**

Build a visibly flattened dense star body, two contrasting physical magnetic caps on its poles, and four or six blunt beam fins aligned around the body. Add a compact recessed face and one restrained pulse or sparkle effect. Use `pulse` animation; the poles and beam fins must remain recognizable in Silhouette mode.

- [ ] **Step 4: Implement `rochebreaker`**

Build an elongated central core pulled into a teardrop shape, a separated secondary fragment mass, and a short curved stream of solid fragments between/behind them. Give it a confident face on the core, one clean fragment/mote emitter, one light at most, and `sway` animation. The tidal split must be geometry, not a texture or particle-only effect.

- [ ] **Step 5: Implement `nebula_noodle`**

Build a chunky curled chain of three-dimensional gas segments around a dark void core, with a face on the front bend and a playful `drift` animation. Add a small orbiting filament group and controlled motes; keep the cloud pieces opaque enough for a clear flat-color silhouette.

- [ ] **Step 6: Implement `universe_seed`**

Build a seed-shaped faceted shell split by a visible seam, a dark pocket-universe core inside the opening, and two or three clean orbital bands. Add a limited aura/light and a controlled `hover` animation; the special animation will be represented by the existing animation attributes and orbiters rather than a new runtime system.

- [ ] **Step 7: Run structural checks and the model self-tests**

Run `python tools/luau_lint.py .` and `python tools/quote_scan.py src`, then run Studio self-tests. Expected result: all six IDs build in all appearances, every part is anchored/non-collidable after finalize, silhouettes contain no lights/emitters, and each finished model remains between 14 and 45 parts with no more than two lights and three emitters.

### Task 4: Update Studio showcase paths

**Files:**
- Modify: `tools/creature_art_review.luau`
- Modify: `src/server/Systems/StudioTester.luau`

**Interfaces:**
- Consumes: `Config.Species.byRegion`, `Config.Species.eggList`, and the new species IDs.
- Produces: a six-model Orbit Outpost review lineup and a Studio starter loadout using the new Legendary, Epic, and Mythic models.

- [ ] **Step 1: Combine wild and egg-only definitions only for Orbit Outpost**

In `show`, build a local `defs` list from `Config.Species.byRegion[region.id]`. When `region.id == "orbit_outpost"`, append `Config.Species.eggList`. Use the dynamic list length for x positions, reduce plinth width/spacing enough for six models, and label each model as `def.name .. " / " .. def.rarity`.

- [ ] **Step 2: Replace hard-coded Studio tester IDs**

Set the gifted primary creature to `rochebreaker`, set the showcase list to `{ "nebula_noodle", "universe_seed" }`, and update the notification text to name the new Legendary, Epic, and Mythic examples.

- [ ] **Step 3: Run the temporary review in Studio**

Rojo-sync the source, start Play, run `tools/creature_art_review.luau` through the connected Studio bridge, select Orbit Outpost, and inspect Normal plus Silhouette. Verify all six labels are visible, the lineup is centered, and closing the review restores the game UI and camera.

### Task 5: Final documentation and verification

**Files:**
- Modify: `docs/CREATURE_ART.md`

**Interfaces:**
- Consumes: the final six model IDs, Studio observations, self-test output, and build/lint results.
- Produces: a concise record of the completed Cosmic replacement and remaining limitations.

- [ ] **Step 1: Record the final Cosmic lineup**

Add a table for the six new species, their concept anchors, effect level, and Studio review status. Note that Epic/Mythic remain egg-only and Celestial/Astral are reserved rarity definitions, if still present.

- [ ] **Step 2: Run the complete validation set**

Run:

```powershell
python tools/luau_lint.py .
python tools/quote_scan.py src
rojo build default.project.json -o build.rbxlx
```

Then run the Studio self-test and the six-model art review. Expected result: all commands succeed, the self-test reports zero failures, Rojo produces `build.rbxlx`, and Studio shows six distinct flat-color-readable Cosmic silhouettes.

- [ ] **Step 3: Report state without committing or publishing**

Summarize changed files, validation results, any visual limitations, current Studio state, and publishing state. Leave all changes uncommitted and unpublished unless the user separately requests otherwise.

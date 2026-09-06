# Catch a Catastrophe! — implementation prompt

Paste the prompt below into Claude Code in the Roblox project you want to build.

---

You are my senior Roblox gameplay engineer, systems designer, environment artist, and QA engineer. Build a complete, playable Roblox Simulation / Tycoon game called **Catch a Catastrophe!**

This is an implementation request. Deliver the actual game, including its world, models, server logic, client UI, economy, progression, persistence, and validation. Work through implementation milestones until the requirements are complete. Make routine design decisions yourself and document them. Do not stop after a design document, a scaffold, or a single working demo mechanic. Report genuine tool or environment blockers accurately.

## 1. The concept and signature twist

Natural disasters have become mischievous collectible creatures. Players capture them in the wild and put them to work powering a miniature city: a tornado runs wind turbines, a volcano heats a forge, and a thundercloud charges an arcade.

The signature mechanic is **Disaster Circuits**. Players connect compatible creatures on their city grid to create useful chain reactions. Rain plus frost produces an ice factory. Water plus volcanic heat produces steam power. Capture skill determines the creature's condition, and city layout determines how productive the collection becomes.

The player fantasy is: **"I caught a walking natural disaster, built it a job, and turned my collection into a ridiculous working city."**

There are no eggs, hatching, stealing, or treadmill training. Build an original identity with original characters, scenery, sounds where available, and UI. Genre inspiration should come from understandable income progression, visible base expansion, collecting unusual variants, and meaningful rebirths.

## 2. The complete gameplay loop

1. Start with a free containment tool, 150 Coins, and a small city plot with six usable pads.
2. Follow a short tutorial into Gusty Gardens and capture a guaranteed Breeze Bean.
3. Return to the city and assign it to a compatible work pad. Its windmill visibly starts turning and producing Coins.
4. Collect earnings, buy upgrades, unlock another region, and capture more creatures.
5. Connect compatible creatures to activate Disaster Circuits and improve production.
6. Find rarer species, master difficult captures, obtain variants, and complete the Catastrophe Atlas.
7. Rebirth into a larger, more productive city while retaining permanent discoveries and selected favorite creatures.

The first capture should take under 60 seconds, the first productive creature under two minutes, and the first affordable upgrade under three minutes. The whole loop must work in an otherwise empty server. Multiplayer adds shared events and visiting other cities.

## 3. Active capture gameplay

Wild creatures visibly roam their home regions. Every encounter has a readable species name, rarity, element, and difficulty. Players see what they are trying to catch before starting.

Use one consistent capture system with six hazard variations:

- Activate the containment tether within 18 studs. A successful capture requires eight accumulated seconds of tether contact.
- The player can move while tethering and must dodge clearly telegraphed attacks.
- Leaving range for over one second or being hit interrupts the tether and removes two seconds of progress, clamped at zero.
- Higher rarities have faster hazard patterns and longer capture requirements, capped at 16 seconds before upgrades.
- Wind sends a moving gust across the arena; Water launches expanding splash rings; Heat marks patches before they erupt; Frost sends a visible sliding ice wave; Storm marks lightning strike locations; Cosmic pulls toward a visible gravity zone before releasing a pulse.
- Hazard checks and capture completion are controlled by the server. A normal hit knocks the player back and briefly interrupts capture without removing owned creatures or money.
- Encounters expire after 45 seconds without a completed capture. Death, disconnect, leaving the region, or cancellation cleans up ownership and effects.
- Claim one encounter to one player at a time. Other players cannot steal the capture, damage the catcher, or receive that same creature. Release abandoned claims promptly.
- Display capture progress, range status, hazard warnings, and the reason for an interruption.
- A perfect capture means completing the encounter without a hazard hit or tether break. Track it for quests and mastery.

Mouse, touch, and controller must all support aiming or selecting a nearby target, starting the tether, moving, and cancelling. Give touch users a toggle instead of requiring simultaneous held buttons. Do not make mobile users complete precision mouse gestures.

## 4. Launch roster: 24 distinct models

Create all 24 creatures with recognizable silhouettes, faces, idle animation, capture feedback, and working habitat animation. Use well-built Roblox Parts and meshes available in the environment; complete procedural models are acceptable. These must be actual assembled characters, not identical spheres with different colors or names.

Each region contains four species, ordered Common, Uncommon, Rare, Legendary:

| Region / element | Common | Uncommon | Rare | Legendary |
|---|---|---|---|---|
| Gusty Gardens / Wind | Breeze Bean — floating bean with leaf ears | Gust Bunny — rabbit with cyclone feet | Twister Terrier — spiral-bodied dog with goggles | Sir Spins-a-Lot — tornado knight with sneakers and a weather-vane lance |
| Splashwater Bay / Water | Drizzle Duck — duck wearing a tiny raincloud | Puddle Pug — glossy puddle dog with splash paws | Monsoon Manta — hovering manta with trailing rain | Tsunami Toad — crowned toad riding a curling wave |
| Cinder Canyon / Heat | Cinder Chick — charcoal chick with an ember crest | Sizzle Salamander — salamander with glowing back vents | Magma Muncher — squat lava monster with furnace jaws | Mount Chomp — giant tortoise with a volcano shell |
| Frostbite Peaks / Frost | Flurry Ferret — snow ferret with a snowflake tail | Slush Sloth — sleepy sloth hanging from an ice arch | Blizzard Bison — shaggy bison with icicle horns | King Coldsnout — royal mammoth with a glacier crown |
| Thunderworks / Storm | Static Sprout — sprout creature with electric hair | Zap Raccoon — raccoon with a lightning-striped tail | Thunder Thumper — gorilla with cloud fists | Boltjaw Behemoth — quadruped storm beast with lightning antlers |
| Orbit Outpost / Cosmic | Orbit Orb — tiny moon with feet and a satellite ring | Comet Cat — cat with a luminous comet tail | Gravity Gobbler — round creature with orbiting stones and a starry mouth | The Big Whoops — miniature black-hole creature with gloves and an orbiting warning sign |

Give each species a stable ID, element, rarity, base income, capture difficulty, model builder, and Atlas entry in centralized configuration.

Starting normal spawn weights per region: 60% Common, 28% Uncommon, 10% Rare, 2% Legendary. These are visible encounter spawns, not hidden purchased rewards. Guarantee one Legendary spawn per region every eight minutes, with a visible regional forecast. Keep population capped and respawn consumed encounters. Players cannot enter locked regions to claim their creatures.

## 5. World and presentation

Support eight players with eight assigned city plots around a readable central hub. Include the six distinct regions, Upgrade Workshop, Rebirth Beacon, Atlas kiosk, and event area. Use clear landmarks, paths, signs, lighting, and region transitions. Region gates explain the exact unlock cost.

Theme the city as a playful disaster-management company: hazard stripes, chunky machinery, animated pipes, colorful turbines, smiling monsters, and billboards showing city earnings. Give the player a small control booth and an expanding industrial garden. A populated city should look substantially different from the starting plot.

Creatures visibly perform their jobs. Connected circuits light up their pipes, run machinery, and show an understandable output effect. Put a readable name, rarity label, variant, and Coins/second on each occupied pad. UI effects should stay restrained enough that capture warnings remain readable.

Create all necessary models, region props, tools, pads, buildings, and interface assets. Do not invent asset IDs or depend on an asset the player cannot access. Any unavailable audio must have a clean functional fallback.

## 6. Disaster Circuits: the core differentiator

Players select two orthogonally adjacent occupied pads and connect them. Each creature can participate in only one active pair. Connections are bidirectional; calculate each pair once. Diagonal pads do not connect.

Implement these six recipes:

| Element pair | Circuit | Visible result |
|---|---|---|
| Wind + Storm | Thunder Turbine | Turbine spins and lights nearby buildings |
| Water + Heat | Steamworks | Boiler puffs steam and drives a piston |
| Water + Frost | Ice Cream Emergency | Machine fills absurdly oversized ice-cream cones |
| Heat + Frost | Thermal Foundry | Forge alternates hot and cold to stamp metal blocks |
| Wind + Cosmic | Orbital Express | Tiny delivery pods orbit between the pads |
| Storm + Cosmic | Neon Grid | Floating neon signs and arcade machines activate |

A normal active circuit grants each member +25% income. Upgrading a circuit once costs Coins and raises its bonus to +40%. Disconnecting, storing, selling, or moving a member immediately recalculates the affected pair. Upgrade purchases belong to the connection's pad pair for the current rebirth; changing occupants does not charge again.

Offer an optional **Overdrive** button for each active circuit: earn double its normal circuit output for 20 seconds, followed by 15 seconds of zero output while that pair cools. Other creatures continue working. Show the full benefit and cooldown before activation. Overdrive cannot restart during either phase, and reconnecting or replacing creatures cannot reset its state.

During Overdrive, one optional vent interaction appears at the city control booth. Completing it prevents the cooldown; ignoring it only triggers the stated cooldown. No permanent destruction or creature loss. This gives active players a short management choice while idle play remains productive. Explain that choosing Overdrive means staying nearby if they want its best return.

The editor must preview valid partners, the recipe, and income before confirming a connection. A Recipe Book records every discovered circuit and provides hints for undiscovered ones.

## 7. Money, upgrades, and balance

Use Coins as the only spendable launch currency. Show wallet balance, city income/second, and collectible earnings separately.

Initial species income = regional base rate multiplied by rarity multiplier. Regional base rates, in the region order above, are 4, 8, 16, 32, 64, and 128 Coins/second. Rarity multipliers are 1, 2.5, 7, and 20. Final income also applies one variant multiplier, rebirth multiplier, and the applicable circuit state exactly once. Maintain fractional amounts internally and round only for presentation or defined payout boundaries.

Initial region unlock costs are 0; 2,500; 15,000; 75,000; 300,000; and 1,000,000 Coins. These are starting balance values; simulate and tune them if actual progression misses the targets. Explain any changed values.

Earnings accumulate in a city bank and are claimed by stepping on a collection pad or pressing its nearby interaction. The online bank caps at one hour of current normal production, with a visible full indicator. Never increase wallet money from a client-reported amount.

Implement useful cash upgrades: tether speed, tether range with a sensible cap, movement speed with a sensible cap, habitat capacity, circuit efficiency, bank capacity, and city decoration tiers. Keep all costs and limits in configuration. Do not require an expensive upgrade to obtain the income needed to buy that same upgrade.

Storage begins at 60 creatures and can expand to 120. Only deployed creatures produce income. Provide sorting, equip/store, favorite locking, and sell confirmation. Block new encounters when storage is full and clearly explain how to make room. Selling or rebirthing must respect favorites and explicit confirmations.

Offline earnings use saved normal deployed production at 25% efficiency, capped at four hours, with a once-only claim on return. Overdrive cannot earn offline. Keep the offline award separate from the online bank and guard against duplicated claims or negative elapsed time.

## 8. Collection, variants, and quests

The **Catastrophe Atlas** tracks permanent species discoveries, currently owned counts, each discovered variant, perfect captures, region completion, and circuit recipes. Discovered species remain recorded after selling or rebirth. Use model previews and clear silhouettes for undiscovered creatures.

Implement three mutually exclusive appearances per species:

- Normal: 1x income.
- Overcharged: 1.5x income, electric accents and glowing markings. Earn it through a perfect capture during that region's forecasted surge.
- Prismatic: 2x income, a coherent multicolor material treatment and subtle particles. Earn a species-bound upgrade after that species has produced in an active circuit for 30 cumulative online minutes and the player has made three perfect captures of that species. The upgrade transforms one selected owned instance, never duplicates it. Persist progress; allow the recipe again after its production and capture counters reset. Favorites require explicit confirmation before transformation.

This gives players routes to rare forms through skill and city management. Do not add eggs, breeding, paid random rolls, or hidden variant odds.

Collection milestones at 4, 8, 12, 18, and 24 species award clearly listed, permanent cosmetic city decorations and titles. Track each reward claim once. Include a seven-step tutorial, repeatable capture/production/circuit quests, and three rotating daily objectives. Show exact objectives, progress, rewards, and reset time. Generate daily objectives only from regions the player can access, and persist claim state.

## 9. Rebirths with clear consequences

Call rebirth **City Relaunch**. Implement ten relaunch levels.

Starting cost formula: ceil(100000 * 3^R), where R is the player's current relaunch count. Require min(6 + 2*R, 24) permanently discovered species. Tune costs against measured progression; target the first relaunch around 25–45 minutes of ordinary active play.

Each relaunch grants an additive +25% permanent income bonus and one additional starting habitat pad. Six starting pads therefore grow to 16 by relaunch ten. Allow current-run purchases to expand further, with a hard cap of 24 deployed creatures. At levels 3 and 6, unlock additional permanent creature anchor slots, increasing from one to two to three.

The confirmation screen must show exactly what resets and what survives. Reset Coins to 150, the bank, unclaimed offline money, run upgrades, region purchases, deployed layout, circuit upgrades, and unanchored owned creatures. Preserve Atlas discoveries, mastery progress, claimed collection rewards, cosmetics, completed tutorial, daily claim records, relaunch count, permanent bonuses, and the selected anchored creatures. Stored anchors remain owned and can be deployed immediately; their work functions even before repurchasing their home region.

Require the player to select their anchor creatures before confirming. Explicitly list favorites that would be lost and require acknowledgement; never silently delete them. Block relaunch during capture, pending purchases, or unresolved saves. Apply the relaunch as one authoritative profile transition and prevent double execution.

## 10. Multiplayer and shared events

Players can visit cities, inspect creatures and circuit recipes, and view server leaderboards for income, collection count, and relaunches. Visitors cannot move, sell, collect money from, or activate machinery in someone else's city.

Every eight minutes, run a 90-second **Containment Crisis** in the hub. Reuse an enlarged roster creature as a clearly labeled event boss. Players cooperate to activate three containment pylons while dodging hazards. Scale required interaction work to participants so one player can succeed. Record meaningful participation on the server and grant each qualifying participant a once-only cash reward scaled to their normal production with configured minimum and maximum bounds. Clean up on success or timeout. Do not award full participation merely for being nearby.

This event is additional content, never a requirement for the first capture, normal production, or rebirth.

## 11. Roblox engineering and persistence

Inspect the connected Studio DataModel, available tools, project instructions, and existing code before editing. Establish which place is the intended build target. Do not overwrite an unrelated existing game merely because Studio happens to be connected to it. If this workspace requires exactly GameConfig, MainServer, and ClientMain, respect that organization and keep systems separated into clear tables and functions inside those scripts. Otherwise use focused ModuleScripts with explicit client/server boundaries.

Use current Roblox APIs and verify unfamiliar APIs against official Creator Hub documentation. The server owns captures, encounter claims, currencies, rewards, creature inventory, habitat assignment, circuits, upgrades, offline calculations, and rebirths. Validate remote types, finite numeric values, distances, cooldowns, ownership, capacity, price, and current state. Reject impossible or repeated requests. Clients provide intent, never trusted payouts or capture completion.

Use stable unique creature instance IDs and versioned save data. Persist the wallet, bank, inventory, layout, unlocks, upgrades, Atlas, mastery, quests, claim records, relaunch data, and relevant timestamps. Use UpdateAsync-compatible conflict handling, a session ownership strategy, retries with bounded backoff, autosaves, leave saves, and shutdown saves. Prevent an old server session from overwriting newer data. Never save a blank default profile over a failed load. Distinguish loading, loaded, temporarily unavailable, and saving states in the UI.

Support Studio testing without DataStore access through an explicitly labeled in-memory test adapter. Keep production persistence enabled in production. Separate the test namespace from real player data and never let test helpers grant production rewards.

Avoid full-world scans every frame, one permanent loop per creature, and server-driven cosmetic animation every frame. Use capped spawns, a shared economy scheduler, event-driven state changes, and client-side visual animation. Clean up connections, encounter claims, models, and tasks on despawn or player departure.

## 12. UI and accessibility

Build a complete HUD and working panels for Inventory, Atlas, Recipe Book, Workshop, Quests, City Relaunch, Settings, and the event. Include actionable error messages, loading states, save status, tooltips, confirmation dialogs, and success feedback.

Support phone layouts and controller navigation, respect safe areas, and use comfortably sized controls. Rarity must use text and an icon as well as color. Provide separate music/effect volume, reduced motion, and reduced flashing. Do not cover the play area with constant popups or add a cash shop for this release.

## 13. Build sequence, verification, and delivery

Implement in this order:

1. World, plot assignment, starter creature model, tutorial capture, deployment, and money collection.
2. Complete roster and regions, capture hazards, inventory, and upgrades.
3. Disaster Circuits, editor, Overdrive, and their visual machinery.
4. Atlas, variants, quests, rebirths, and persistence.
5. Multiplayer event, responsive UI, performance checks, and balance adjustments.

Keep a milestone checklist and continue through all milestones. A passing milestone is not permission to omit the remaining scope.

Verify with actual tools where available:

- A fresh player can complete the tutorial, capture, deploy, earn, collect, and purchase an upgrade.
- All 24 model builders instantiate successfully and every species is obtainable through its intended region.
- All six capture patterns work; interruption, cancellation, simultaneous attempts, full inventory, death, and disconnect clean up correctly.
- Each circuit grants the specified income once; invalid or overlapping connections are rejected; moving a member recalculates production.
- Overdrive output, vent success, cooldown, and reconnect abuse prevention behave as specified.
- Purchases and claims cannot be doubled by rapid requests. Invalid ownership, currency values, IDs, and remote payloads are rejected.
- Quest, variant, and collection rewards are earned and claimed exactly once per applicable cycle.
- Rebirth preserves and resets the specified fields and protects chosen anchors.
- Rejoining restores progress and offline money claims once. Failed data loading cannot overwrite good data.
- Two clients have isolated inventories, money, plots, and encounters, and can complete the cooperative event.
- Phone and controller interactions are usable, and the Output window has no unresolved runtime errors during tested flows.

Use focused automated checks for economy arithmetic, state transitions, and persistence behavior, plus live playtests for interactions and visuals. Use Studio-only time acceleration or fixtures for long timers; do not alter production saves. Do not describe static inspection as a successful live multiplayer or persistence test.

If Studio integration is available, build and test in the intended DataModel. If it is unavailable, produce the complete importable project, exact installation steps, and runnable validation helpers; state precisely what could not be live-tested. Do not claim a fully validated live game without running it.

Deliver the working project, a short controls guide, final balance configuration, system/file map, test results distinguishing automated and live checks, and any concrete remaining blockers. Update applicable project relay files with completed features, modified scripts/functions, live validation results, and the next recommended step. Do not publish the experience publicly unless I authorize publication.

Begin by inspecting the project, briefly state the implementation order, and start building.

---

## Research behind this prompt

The reference games informed progression patterns, not this original theme or its circuit mechanics. These are description-based findings; they do not represent a hands-on playtest.

- [Steal An Egg — official Roblox page](https://www.roblox.com/games/107778070777162/Steal-An-Egg): stealing eggs from pets and players, collecting hatched pets, pet income, base/treadmill upgrades, speed training, sizes, and mutations.
- [Steal a Brainrot — official Roblox page](https://www.roblox.com/games/109983668079237/Steal-a-Brainrot): buying and stealing collectible characters, generating money, rebirths, and purchasable disruptive gear.
- [Grow a Garden — official Roblox page](https://www.roblox.com/games/126884695634066/Grow-a-Garden): restocking seed shops, planting, timed growth, harvesting profits, and offline growth.

All names, creature designs, circuits, prices, timing targets, variant rules, and progression formulas in this prompt are proposed original design specifications, not claims about those reference games.

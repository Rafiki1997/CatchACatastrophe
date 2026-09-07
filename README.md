# Catch a Catastrophe!

Natural disasters have become mischievous collectible creatures. Catch them in the wild, put them to
work powering a miniature city, and wire compatible ones together into **Disaster Circuits**: rain plus
frost makes an ice-cream factory, water plus volcanic heat makes steam power, storm plus cosmic lights
up an arcade.

An original 8-player Roblox simulation / tycoon game. Every creature, name, model, map, sound and piece
of interface is original; the only audio is Roblox's own built-in `rbxasset://` set. No eggs, no
hatching, no stealing, no paid random rolls, no cash shop.

## Build and run

Rojo 7.7 is on PATH.

```bash
cd C:/Users/rahul/orca/Catch-a-Catastrophe && rojo build -o build/CatchACatastrophe.rbxl
```

Open `build/CatchACatastrophe.rbxl` in Roblox Studio and press **Play** (F5). For two-player tests use
**Test → Clients and Servers → 2 players**.

Studio Output should show `[Catch a Catastrophe!] map built: N parts`, then
`[Catch a Catastrophe!] server ready in N ms`, then `[SelfTest] passed N, failed 0` about three seconds
later.

To publish: File → Publish to Roblox, then turn on **API Services** in Game Settings so DataStores work.
Without it the game runs and says so, but never saves.

## The loop

1. Spawn in the hub with 150 Coins, a city plot on the ring, and six work pads.
2. Follow the tutorial beam to **Gusty Gardens** and tether a **Breeze Bean**.
3. Deploy it on a work pad. Its windmill starts turning and Coins start filling your bank.
4. Step on the **Collection Pad** to bank them, buy an upgrade at the **Upgrade Workshop**.
5. Unlock more regions, catch rarer creatures, and connect adjacent compatible pairs into circuits.
6. Chase perfect captures and Prismatic mastery, finish the Atlas, then **relaunch** the city.

## Controls

| | Capture / cancel tether | Circuit editor | Close panel |
|---|---|---|---|
| **Mouse + keyboard** | Point at a creature, **E**. **Q** cancels. | Click a work pad in your own city | **Escape** |
| **Touch** | Tap a creature, then the **Capture** button. Tap again to cancel. | Tap a work pad | Close button |
| **Controller** | **X** toggles the tether, **B** cancels | **D-pad** steps through pads, **A** picks | **B** |

Touch never needs two fingers at once or a precision drag. Every button is at least 44 px tall.

## Capture

Tether a creature from within 18 studs and hold contact for the required seconds while dodging its
element's hazard. Leaving range for more than a second, or taking a hit, costs 2 seconds of progress
and ends your perfect run. An encounter is yours alone for 45 seconds; nobody can steal it, hit you, or
receive that creature.

| Element | Hazard | What it does |
|---|---|---|
| Wind | Gust | A wall sweeps across the arena |
| Water | Splash Ring | A ring expands outward from the creature |
| Heat | Eruption | Three patches are marked, then erupt |
| Frost | Ice Wave | A wide wall slides through, slower and thicker |
| Storm | Lightning | Two spots are marked, then struck |
| Cosmic | Gravity Pulse | A well pulls you in, then pulses |

The server owns all of it: it picks the geometry, sends the telegraph, and decides what hit you. The
client only draws it and pushes your own character around.

## The roster

Six regions, four species each, ordered Common / Uncommon / Rare / Legendary.

| Region | Element | Base | Common | Uncommon | Rare | Legendary |
|---|---|---|---|---|---|---|
| Gusty Gardens | Wind | 4/s | Breeze Bean | Gust Bunny | Twister Terrier | Sir Spins-a-Lot |
| Splashwater Bay | Water | 8/s | Drizzle Duck | Puddle Pug | Monsoon Manta | Tsunami Toad |
| Cinder Canyon | Heat | 16/s | Cinder Chick | Sizzle Salamander | Magma Muncher | Mount Chomp |
| Frostbite Peaks | Frost | 32/s | Flurry Ferret | Slush Sloth | Blizzard Bison | King Coldsnout |
| Thunderworks | Storm | 64/s | Static Sprout | Zap Raccoon | Thunder Thumper | Boltjaw Behemoth |
| Orbit Outpost | Cosmic | 128/s | Orbit Orb | Comet Cat | Gravity Gobbler | The Big Whoops |

Every creature is built from Roblox Parts at runtime with a recognisable silhouette, a face, and idle
animation. There are no asset IDs anywhere in the project.

## Balance

| | |
|---|---|
| Rarity multipliers | Common 1, Uncommon 2.5, Rare 7, Legendary 20 |
| Spawn weights | 60 / 28 / 10 / 2 (they sum to 100, so a weight is a percentage) |
| Capture seconds | 8 / 10 / 13 / 16, divided by the Tether Speed upgrade |
| Region unlock costs | 0, 2.5K, 15K, 75K, 300K, 1M |
| Legendary guarantee | one per region every 8 minutes, with a visible forecast on the gate |
| Surge | the 90 s window that opens with each guaranteed Legendary |
| Variants | Normal 1x, Overcharged 1.5x, Prismatic 2x |
| Circuit bonus | +25% each member, +40% upgraded, plus Circuit Efficiency |
| Overdrive | x2 for 20 s, then 0 for 15 s unless you vent at the control booth |
| Bank cap | one hour of normal production, raised by Bigger Bank |
| Offline | 25% efficiency, capped at 4 hours, claimed once |
| Storage | 60 creatures, up to 120 |
| Work pads | 6 + relaunch level, up to a hard cap of 24 |
| Relaunch cost | `ceil(100000 * 3^R)` |
| Relaunch requirement | `min(6 + 2R, 24)` discovered species |
| Relaunch reward | +25% permanent income and one more starting pad, per level |
| Anchors | 1, then 2 at relaunch 3, then 3 at relaunch 6 |
| Crisis | every 8 minutes, 90 seconds, 3 pylons, once-only scaled reward |

Income is `region base x rarity x variant x relaunch`, then the circuit bonus, then the Overdrive
factor. Each applies exactly once, and the self tests assert that.

**These are the spec's proposed starting values, unchanged.** They have not been tuned against measured
play, because the game has not been played yet. See "Status" below.

## Variants, and why they are not a lottery

- **Overcharged** (1.5x) comes from a *perfect* capture made while that region is surging. The surge is
  announced and shown on the gate sign, so it is a skill window with a visible timer.
- **Prismatic** (2x) is a species-bound upgrade: 30 cumulative online minutes of that species producing
  inside an active circuit, plus 3 perfect captures of it. It transforms one creature you pick, never
  duplicates it, and resets both counters so it can be earned again.

There are no hidden odds because there are no rolls.

## Systems

| System | File | Owns |
|---|---|---|
| Profiles | `server/Systems/Profiles.luau` | the save schema and hostile-input sanitising |
| Stats | `Stats.luau` | every formula: income, caps, pair validity, sell value, rewards |
| DataService | `DataService.luau` | versioned saves, session ownership, retries, the Studio test adapter |
| Sync | `Sync.luau` | builds the Snapshot and pushes it (the only sender of `State`) |
| PlayerService | `PlayerService.luau` | join and leave, walk speed, respawn point |
| EconomyService | `EconomyService.luau` | the income tick, the bank, collect, spend, offline |
| CityService | `CityService.luau` | plots, inventory, pads, the creature and station models, labels |
| CircuitService | `CircuitService.luau` | connect, upgrade, Overdrive, the vent, machine models |
| EncounterService | `EncounterService.luau` | wild spawns, roaming, claims, the Legendary forecast |
| CaptureService | `CaptureService.luau` | the tether loop and all six hazard geometries |
| CrisisService | `CrisisService.luau` | the cooperative hub event |
| Workshop / Atlas / Variant / Quest / Relaunch | `*Service.luau` | progression |
| Visit / Leaderboard | `*Service.luau` | other players' cities and the server boards |
| RemoteRouter | `RemoteRouter.luau` | every client message: rate limit, type check, dispatch |
| TestHarness | `TestHarness.luau` | the Studio self tests |

Client modules mirror this under `src/client`: `HUD`, `CaptureHUD`, `CaptureReveal`, `TutorialUI`,
`CircuitEditorUI`, nine panels, and the `Input` / `Effects` / `WorldAnimator` / `RegionGates` /
`CaptureController` / `CircuitEditor` controllers.

`docs/CONTRACTS.md` is the binding interface reference between all of them.

## Security model

The client sends intent and nothing else. It never supplies a price, a payout, a capture result, or a
hazard outcome. Every remote is rate-limited with its own token bucket, type-checked, checked for finite
numbers, and re-validated against the profile before anything changes. Visitors to another city cannot
move, sell, collect from, or overdrive anything in it.

Saves are versioned, written with `UpdateAsync`, and guarded by a per-server session claim so an old
server cannot overwrite newer data. A load that fails after its retries marks the session unsafe: the
player is told, plays normally, and nothing is ever written, so an outage cannot wipe a collection. In
Studio without API access an explicitly labelled in-memory adapter takes over, keyed in its own
namespace, and the HUD says "Studio test data".

## Status

The implementation covers the spec across 80 Luau source files. The current art
pass is documented in [docs/CREATURE_ART.md](docs/CREATURE_ART.md).

### Verified in a running Studio session

- **Structural/quote checks and Rojo build pass** across all 80 source files.
- **The server boots**: 2,001-part map, all systems up, ready in 259 ms in the latest run.
- **Unit self-tests: 418 passed, 0 failed.** Hazard geometry/timing, config integrity, all 24 creature models building at
  sensible heights, the income formula applying each factor exactly once, circuit and adjacency
  validation, the Overdrive state machine, save round-tripping and sanitising of hostile input, sell
  value, scaled rewards, and a rate limit on every client remote.
- **All 96 creature appearances meet render budgets**, including effect-free collection silhouettes.
- **Live tests: 22 passed, 0 failed**, covering deploy, circuit machinery, Overdrive calculations,
  collection rounding, sell guards, and locked-region claim refusal.
- **World builds correctly**: hub, arena with 3 prompted pylons, all six regions populated with the
  right species, plot assigned with 6 unlocked pads, vent prompt wired.
- **A capture completes end to end, driven through the real remotes as a client**: tether accrues,
  range is enforced, hazards telegraph and land, a hit clears the perfect flag and deducts progress,
  and the creature is granted and recorded in the Atlas.
- **The spec's first verification item passes in full**: a fresh player captures, deploys, earns,
  collects and buys an upgrade. Income read 4/s for a Common Wind creature exactly as configured; the
  bank capped at one hour; collect paid the floor and left the fraction; the tutorial advanced through
  steps 3, 4, 5 and 6 on the right actions; the creature and its windmill both appeared on the pad.

### Not yet verified

- Human dodge difficulty for the five remaining patterns. All ten controlled live capture
  cases pass (hit and perfect dodge per element); see [hazard verification](docs/HAZARD_VERIFICATION.md).
- Manual circuit-editor and vent interaction still need a playthrough; the automated live suite
  passes. Building a circuit needs two unlocked regions.
- Relaunch, offline claim on rejoin, the Containment Crisis, and two clients at once.
- Balance against measured play. Every number is still the spec's proposed starting value.

Static checks also run without Studio:

```bash
python tools/luau_lint.py src     # block, bracket and string balance
python tools/quote_scan.py src    # unbalanced quotes
```

See `HANDOFF.md` for where to pick up.

## Known limitations

- There is no shipped `rbxasset://` music track, so the Music slider controls an ambient channel that is
  currently silent. The Effects slider is fully wired.
- Region entry for the tutorial is detected by a 1 s server poll of player positions, not touch parts.
- Leaderboards are per-server, not global.
- Models are part-built. There are no meshes or textures, by design, so nothing depends on an asset the
  player might not be able to load.

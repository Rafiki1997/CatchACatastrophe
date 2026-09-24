# Thunderworks — five design options and an asset kit

Status: awaiting selection. Nothing in the game changed: no Luau, no Studio, no Rojo sync, no committed
assets. Made 2026-09-22 by building each option in Blender 5.1 at the region's real size and rendering it,
the same way as the Frostbite Peaks round you picked Alpine Outpost from. They are **not** image-generation
paintings, so every landmark already has coordinates in the region's own frame.

You asked for Tesla Coil Works and Copperline Substation, plus a few options that each combine two of the
four directions offered. So 01 and 02 are your picks, and 03–05 are the combinations.

- Overview of all five: `thunderworks-v1-overview.png`
- Straight-down plans of all five: `thunderworks-v1-plans.png`
- Asset kit, every new piece on one sheet: `thunderworks-asset-kit.png`, one card each in `assets/`

## Options

- **01 / TESLA COIL WORKS** (your pick). A lightning lab.
  - Two giant Tesla coils (58 and 52 studs) stand in the rear corners. Each throws arcs at a copper-ringed catch mast beside it.
  - A 62-stud brick dynamo hall runs down the west band. It has tall arched windows lit warm, a clerestory, a verdigris cupola and a 36-stud chimney.
  - Down the east band are rows of Leyden jars with lightning glowing inside, a storm bell jar, two spark gaps and a barrel-roof workshop.
  - Image: `thunderworks-v1-01-tesla-coil-works.png`

- **02 / COPPERLINE SUBSTATION** (your pick). A working power yard.
  - The transmission line on the heath outside the wall drops into a fenced switchyard across the rear-left: three lattice gantries, breakers, a copper bus on post insulators.
  - Two lightning collector masts and an accumulator bank hold the rear-right.
  - A brick switch house, a second bank and a maintenance shed sit down the west band.
  - Three transformer bays stand between firewalls behind a DANGER fence down the east band.
  - It uses the most of Astra's existing Thunderworks kit: 31 props-v1 placements (see Assets).
  - Image: `thunderworks-v1-02-copperline-substation.png`

- **03 / SPARKLINE SUBSTATION** (01 × 02). A substation that feeds one colossal coil.
  - The switchyard, two transformer bays and the switch house fill the west side.
  - A single 60-stud Tesla coil dominates the rear-right. Two collector masts catch its bolts.
  - Bottled lightning, a storm jar and an accumulator bank line the east band. A copper feeder on ceramic posts runs along the east wall to the coil.
  - Image: `thunderworks-v1-03-sparkline-substation.png`

- **04 / STORMCLIFF DYNAMO** (01 × Cliffside Dynamo, the V5 painting).
  - A layered slate cliff with wooded ledges wraps both rear corners, and the gate stays open.
  - The giant copper dynamo sits in a lamp-lit cut in the west cliff, with a steel stair and copper pipes beside it.
  - On a flat mesa in the east corner, two Tesla coils bridge a spark between their toroids.
  - Barrel-roof workshops and a spark gap line the east band.
  - Image: `thunderworks-v1-04-stormcliff-dynamo.png`

- **05 / COPPERLINE RAILYARD** (02 × Stormrail Depot, the V4 painting). An electric depot and the substation that powers it.
  - A teal Stormrail engine stands half out of its barrel-vaulted shed on the west track, under catenary.
  - A siding carries a flatcar with a giant cable reel, beside a loading platform.
  - Two transformer bays, a gantry and a breaker sit behind a fence on the east side, with the switch house and the bolt water tower in the rear-right.
  - Image: `thunderworks-v1-05-copperline-railyard.png`

## What all five share

- **The real cell, not an approximation.** 280 × 200, with MapBuilder's walls, piers, dividers, both
  44-wide gates and their piers at MapBuilder's own coordinates (`buildChainWalls`, `gatePier`, `wall`,
  `lamp`, `buildRegion`). The north gate carries Orbit Outpost's locked barrier, lock and banner. The
  side-wall piers fall where the 1,200-stud chain puts them in this cell (44.44 k − 900). Camera, light
  and creature spots are identical across the five, and match the Frostbite round.
- **The same envelope the rebuilt regions use.** The open field (|x| < 92, |y| < 70) stays clear. So do
  a 24-wide lane from gate to gate and |x| < 36 in front of both gates. Landmarks go only in the side
  bands and the rear corners. The front band carries only low props and small pines towards its corners.
- **Measured, not eyeballed.** Every solid object's footprint is rasterised on a 1-stud grid, pines by
  their whole canopy:

  | Option | Interior clear | Open field clear | Lane cells blocked | Solid objects |
  |---|---|---|---|---|
  | 01 Tesla Coil Works | 79.4% | 100.0% | 0 | 244 |
  | 02 Copperline Substation | 81.8% | 100.0% | 0 | 268 |
  | 03 Sparkline Substation | 81.7% | 100.0% | 0 | 255 |
  | 04 Stormcliff Dynamo | 78.5% | 100.0% | 0 | 242 |
  | 05 Copperline Railyard | 81.1% | 100.0% | 0 | 227 |

  Raw numbers: `src/measurements/option-N.json`. The same measure gave Frostbite's five 77.8–84.8%
  interior and 99.8–99.9% field. For play, the field and lane columns are the ones that matter.
- **The floor stays the region's own dark blue-grey** (`groundColor` 78, 84, 99). Nothing yellow is
  painted on or near the catching field, because the Storm hazard draws pale yellow warning circles there
  (the rule `Thunderworks.luau` already follows). Worn yellow appears only on machinery.
- **The game's own sign text.** The banners read ORBIT OUTPOST / 1M COINS (north) and THUNDERWORKS /
  300K COINS (south), which is what `Format.abbreviate` produces. The south gate is drawn open with no
  barrier, as in the earlier rounds.

## Read before choosing: art direction, not decisions

- **Today's `Thunderworks.luau` is still the circular radius-75 yard** (with props-v1 integrated), like
  Frostbite and Cinder before their rebuilds. Any option here means a rebuild for the chain cell.
- **Creatures** are placeholders of the four real Storm species, in the same six spots in every option,
  enlarged about 3× so they read at this distance: two Static Sprouts, two Zap Raccoons, a Thunder
  Thumper and the Boltjaw Behemoth. No change to population or models is implied.
- **The arcs are effects, not geometry.**
  - In Roblox they would be client-side Beams or ParticleEmitters: no collision, no damage, nothing to do with the hazard.
  - They stay in the rear corners and bands, well away from the field telegraph.
  - The Leyden jar filaments and the storm jar's cloud glow would be small Neon parts.
- **The lane** is drawn as a 24-wide pale concrete service road with cross joints and no kerbs.
  - That is a proposed `TRAIL_BLEND` entry for Storm, as Water, Heat and Frost already have.
  - Today Storm gets the default 18-wide paved trail with kerbs in its own colour, (255, 230, 90). That is the hazard's yellow family, a reason to switch anyway.
- **Outside the walls** is drawn as a storm heath: dark firs, grey rock and a transmission line on pylons.
  - Today that strip is shared grass with the ChainFlanks trees. Re-skinning it is a separate choice, the same `OWN_FLANK` mechanism Frostbite now uses.
  - In 02 and 03 the switchyard is fed from that line, so its conductors cross the west wall. Wires are decoration and never collide.
- **Pines inside the bands** are how these mockups fill the space between landmarks, as the Frostbite
  round used firs. The old yard has grown over at its edges. They can be thinned in the build.
- **Walkable heights that need stairs and collision in a build:**
  - 04's coil mesa (top 17), with its steel stair drawn.
  - The stair beside the dynamo cut (to 15).
  - 05's loading platform (1.1).
  - 04's cliff itself is scenery: its blocks run 9–24 studs with a second tier above. It would stand on
    collision proxies like the other rebuilt regions' rock, not be a walkable surface.
- **The low west sun** is there so forms read in the mockup. It is not a proposal to change lighting.

## Assets

**Astra's existing kit is reused.** The `assets/thunderworks/props-v1` meshes are appended from
`props.blend` at their delivered sizes. Six of the eight appear. The conduit elbow and the storm
bollard are not placed in any option. Placements, counted off each built scene:

| Option | props-v1 placed | Which |
|---|---|---|
| 01 | 24 | transformer 5, cable reel 8, capacitor bank 8, switch cabinet 3 |
| 02 | 31 | transformer 1, ceramic insulator 14, cable reel 7, capacitor bank 4, switch cabinet 3, vent housing 2 |
| 03 | 28 | ceramic insulator 13, cable reel 4, capacitor bank 8, switch cabinet 3 |
| 04 | 10 | transformer 1, cable reel 3, capacitor bank 4, switch cabinet 2 |
| 05 | 8 | cable reel 5, capacitor bank 2, vent housing 1 |

**New pieces.** The 26 below are the ones the five options ask for. Each has a card in `assets/`, rendered at stud
scale beside a 5-stud avatar. The sizes are measured off the Blender stand-ins, so they are a starting
contract for Astra, not final.

| # | Asset | W x D x H (studs) | Placed in the mockups | What it is | Options |
|---|---|---|---|---|---|
| 01 | Giant Tesla Coil | 16.6 x 16.6 x 40 | h 52-58 (01), 60 (03), 32 on the mesa (04) | Stepped plinth, copper primary, ceramic column, wound secondary, polished toroid. | 01, 03, 04 |
| 02 | Dynamo Hall | 64.5 x 30.4 x 36.8 | as shown (01) | Pilastered brick hall with arched lit windows, clerestory, verdigris cupola and chimney. | 01 |
| 03 | Leyden Jar Rack | 15.9 x 4.6 x 8.2 | 1.3x | Five glass jars with copper foil and ball electrodes on a bus bar. | 01, 03 |
| 04 | Spark Gap | 13.4 x 5.8 x 12.7 | 1.3-1.4x | Two ceramic columns with copper spheres; an arc jumps the gap. | 01, 04 |
| 05 | Storm Bell Jar | 11.2 x 11.2 x 15 | 2.2x (01), 1.75x (03) | A caught thundercloud under a copper-ribbed glass dome. | 01, 03 |
| 06 | Accumulator Bank | 16.4 x 6 x 10.8 | 1.3-1.35x | Giant teal cells with copper terminals and charge meters. | 02, 03, 05 |
| 07 | Lightning Collector Mast | 14.2 x 14.2 x 35.6 | h 24-26 (01), 34-40 (02), 32-34 (03) | Today's collector reworked: lattice mast, copper rings, crown ball. | 01, 02, 03 |
| 08 | Substation Gantry | 27 x 3 x 21.6 | span 26 h 22 (02, 03), span 22 h 18 (05) | Lattice portal with box-truss beam, earth-wire peaks and insulator strings. | 02, 03, 05 |
| 09 | Power Transformer | 13 x 10 x 14.2 | 1.35x | Teal tank, radiator banks, conservator and tall HV bushings on a gravel pit. | 02, 03, 05 |
| 10 | Circuit Breaker | 7.4 x 1.9 x 9.9 | 1.3x | Three ceramic poles with copper heads on a steel frame. | 02, 03, 05 |
| 11 | Switch House | 24.2 x 16.5 x 20.5 | 1.55x (02), 1.3x (03), 1.2x (05) | Brick control building, lit windows, teal door, roof plant and radio mast. | 02, 03, 05 |
| 12 | Giant Dynamo Drum | 19.7 x 24.7 x 18.9 | as shown | Wound copper drum on teal cradles with slotted end plates and ceramic bushings. | 04 |
| 13 | Barrel-Roof Workshop | 13.8 x 17.2 x 9.5 | 1.15-1.3x | Corrugated walls under a teal barrel roof, roller door, lit window. | 01, 02, 04 |
| 14 | Stormrail Engine | 5.7 x 25.1 x 13.6 | as shown | Box-cab electric locomotive with pantograph and roof insulators. | 05 |
| 15 | Engine Shed | 19.6 x 42 x 15.9 | as shown | Steel columns under a teal barrel vault with a skylight, masonry back wall. | 05 |
| 16 | Track and Buffer Stop | 7.6 x 41.5 x 3.2 | 172 and 80 long | Rails on sleepers and ballast, red-and-white buffer stop. | 05 |
| 17 | Catenary Mast | 5.9 x 1.8 x 13 | h 19.2, reach 11 | H-column with cantilever, stay and insulators over the track. | 05 |
| 18 | Bolt Water Tower | 9.4 x 9.4 x 27.4 | 1.25x | Braced timber tower, stave tank with hoops, painted bolt. | 05 |
| 19 | Transmission Pylon | 16.6 x 8.6 x 42.1 | as shown | Tapered lattice tower for the heath outside the walls; carries the lines. | all |
| 20 | Floodlight Mast | 3.6 x 2.5 x 16.4 | as shown | Tapered pole with a five-lamp head. | all |
| 21 | Cable Tray | 12.9 x 2.2 x 2.7 | as shown | T-stands carrying a bundle of heavy cables. | 01, 04 |
| 22 | Utility Pole | 6 x 2.6 x 16 | as shown | Timber pole, crossarm, pin insulators and a pot transformer. | 02, 05 |
| 23 | Chain-Link Fence | 16.9 x 1.1 x 7.9 | runs of any length | Galvanised run with barbed top and DANGER plates; fences every compound. | 02, 03, 05 |
| 24 | Cable Flatcar | 5.5 x 18.6 x 11.3 | as shown | Four-axle flatcar with a giant cable drum chocked on the deck. | 05 |
| 25 | Road Barrier | 6 x 2 x 1.8 | as shown | Red-and-white concrete barrier for the band edges. | 02, 03, 05 |
| 26 | Yard Clutter | 8.5 x 2.9 x 2.6 | as shown | Drum stack, crates on a pallet, cable spool. | all |

What each option would ask Astra to model new:

| Option | New pieces |
|---|---|
| 01 | Giant Tesla coil, dynamo hall, Leyden jar rack, spark gap, storm bell jar, collector mast (catch mast), barrel-roof workshop, cable tray |
| 02 | Substation gantry, power transformer, circuit breaker, switch house, collector mast, accumulator bank, barrel-roof workshop, utility pole, chain-link fence, road barrier |
| 03 | Giant Tesla coil, collector mast, gantry, power transformer, circuit breaker, switch house, Leyden jar rack, storm bell jar, accumulator bank, chain-link fence, road barrier |
| 04 | Giant Tesla coil, giant dynamo drum, spark gap, barrel-roof workshop, cable tray, and a strata cliff and mesa kit (with stairs) |
| 05 | Stormrail engine, engine shed, track and buffer stop, catenary mast, cable flatcar, power transformer, gantry, circuit breaker, switch house, bolt water tower, accumulator bank, utility pole, chain-link fence, road barrier |
| all | Transmission pylon (heath), floodlight mast, yard clutter |

## After selection

Write the Claude handoff straight from the chosen option's builder in `src/tw_designs.py`. Every
coordinate is already in the cell's frame: +X east, +Y north, which is Roblox −Z. No camera fit is
needed. Then Astra models the new pieces from the cards, and Claude integrates them, as agreed for the
earlier regions.

## Reproduce

```
bash src/render_all.sh            # five options, plans, sheets, asset cards (256 samples, 2304 x 1536)
bash src/render_all.sh 40 0.5     # quick preview pass
ASSETS=0 bash src/render_all.sh   # skip the asset cards
```

Needs Blender 5.1 (it defaults to `C:/Program Files/Blender Foundation/Blender 5.1/blender.exe`;
override with `BLENDER=`) and Python with Pillow for the compose scripts.

A single option renders with
`blender -b --factory-startup -P src/render_thunderworks.py -- --option 3 --out o3.png`, and `--camera top`
gives its plan. One asset renders with
`blender -b --factory-startup -P src/render_asset.py -- --out DIR --only tesla_coil`.

What each file does:

- `src/tw_lib.py`: the Frostbite round's `fb_lib.py`, unchanged.
- `src/tw_geo.py`: lattices, tori, cables, arcs and industrial materials.
- `src/tw_kit.py`: the asset builders.
- `src/tw_base.py`: the cell, the neighbours, the heath, the Storm creatures and the measurement.
- `src/tw_designs.py`: the five options.

## References

- `../2026-09-21-alternatives/CONCEPTS.md`: the painted V1–V5 round. V5 Cliffside Dynamo feeds 04, V4
  Stormrail Depot feeds 05.
- `../2026-09-21-thunderworks/THUNDERWORKS-LAYOUT.md`: today's circular build and its measured contract.
- `../2026-09-22-frostbite-peaks/V1_OPTIONS.md`: the neighbouring round's format, camera and envelope.

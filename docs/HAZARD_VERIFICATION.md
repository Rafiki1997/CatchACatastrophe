# Capture hazards

The five remaining elemental patterns use the existing server-authoritative tether loop.

| Element | Attack | Response |
| --- | --- | --- |
| Water | Expanding splash band | Jump over the low ring |
| Heat | Three marked eruption patches | Move off the marked ground |
| Frost | Travelling ice wall | Sidestep the indicated path |
| Storm | Two lightning patches | Leave the marked spots |
| Cosmic | Charging gravity well followed by a pulse | Escape the marked zone before activation |

## Changes

- Water's hit check now accounts for avatar feet height, including R6 and R15 offsets.
  Feet above the 0.8-stud band clear it. The visual is a segmented hollow band with
  a final-radius warning outline, matching the safe interior of the server geometry.
- Cosmic's charging pull stops outside the marked radius. Reduced motion no longer
  changes its strength.
- Warning cleanup uses a generation counter so an older attack cannot erase the
  text for a newer attack.
- The shared Water hit check also applies to Crisis hazards.

## Repeatable verification

Validated in Studio on 2026-09-06: **418 self-tests, 22 existing live tests, and
10 hazard capture cases passed**. All five elements produced their expected client
geometry and warning text, and expired effects left zero parts. Two attacks emitted
on the capture-completion tick were cleared before the observer's delayed sample,
as expected. Two earlier runs ended before observing a warning; a complete rerun
passed all ten cases without further production changes.

A separate client physics check measured inward velocity inside the Cosmic radius
and zero added velocity outside it. An overlapping-warning check confirmed Storm's
text survived the preceding Heat warning's cleanup timer. Human movement and latency
balancing remain open.

The normal `TestHarness` includes 76 additional geometry/timing assertions: warning,
active and expired phases; normal and faster rarity timings; safe positions; targeted
patch counts; and jumping above Water's band.

For live captures, `HazardTestHarness` installs only in Studio and refuses to run
unless the player uses the in-memory save adapter and has no active capture.

1. Start Play with Rojo connected.
2. Execute `tools/capture_hazard_observer.luau` in the Client datamodel.
3. In the Server datamodel, set `workspace.CaptureHazardTests`'s `Request` attribute
   to a new number.
4. Inspect its `Status`, `Stage`, `Passed`, and JSON `Results` attributes.
5. Inspect `Players.LocalPlayer.PlayerGui.HazardTestObserver` for rendered warning
   text, part counts, cleanup counts, and capture results.

Each element gets a deliberate-hit capture and a no-hit capture through the real
StartCapture remote and server heartbeat. Tests check the two-second progress
penalty, stun, no duplicate hit from the same attack, perfect-capture accounting,
inventory grant, encounter consumption, and unchanged health. The suite restores
the in-memory profile and avatar position afterward. It consumes test encounters;
normal encounter spawning replenishes the world.

Avatar placement is controlled and encounters are held stationary. These checks
verify mechanics; they do not measure human dodge difficulty or multiplayer latency.
Stop Play to remove the test observer and restore a fresh test world.

# Frostbite Peaks — three concept directions

Generated 2026-09-20. These are art mockups, not Studio screenshots or implemented
models. User selected **V2 Alpine Expedition**. Prompt specifications are preserved
in FROSTBITE-PROMPTS.json. No game code or Studio state changed.

All three show an open flat snow catching field, peripheral scenery, continuous
snow/rock containment and one foreground entrance. Background mountain ranges
are atmospheric concept scenery, not an instruction to build another huge map.
Fit the chosen design to the current radius-75 region and preserve its gate,
sign, unlock cost, region bounds, collision and hazard/roaming clearances.

| Version | Visual identity | Custom Blender assets |
|---|---|---|
| V1 Glacier Gateway | Blue glacier arch, frozen waterfall, stone side bridge | Modular glacier cliffs, sectional ice arch, frozen cascade, bridge trim, snow caps, icicles, fir trees, ice clusters |
| V2 Alpine Expedition | Snowy mountain ridge, cozy timber expedition hut, rope bridge | Faceted peak/cliff modules, snow caps, fir variants, timber hut kit, rope bridge sections, steps, trail posts, lanterns and supplies |
| V3 Frozen Crystal Basin | Violet/cyan crystal skyline, curled ice grotto, stone overlook | Crystal clusters at several scales, curled glacier/grotto mesh, snowy slate cliffs, overlook pillars, icicles, fir trees |

V2 is approved for its alpine identity and modular cliff/pine/timber asset kit.
Claude base-layout instructions are in FROSTBITE-PEAKS-CLAUDE-HANDOFF.md.
V1 emphasizes a glacial landmark; V3 emphasizes magical ice formations.

Implementation notes:

- Keep reflective ice, crystal glow and detailed props at the perimeter; leave
  the center matte and visually quiet for creature silhouettes and telegraphs.
- The V2 render places a decorative name plaque over the gate. Retain the actual
  functional region board beside the entrance, with the existing visibility fix.
- V3's aurora is optional sky art, not a reason to change lighting globally for
  all other regions. Any localized lighting/VFX needs a separate implementation.
- Keep scenic arch/grotto openings backed by continuous containment geometry.
- Build reusable props and fitted landmark meshes separately. Preserve tested
  collision cores under decorative meshes and use the import-staging protection.

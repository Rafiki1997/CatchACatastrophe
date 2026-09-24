# Starting area — bushes v1 (mockup for review)

2026-09-24. The first batch of the town-island remodel. Rahul asked for the starting area's trees to match the Gusty Gardens trees, with the same style applied to the bushes, and wanted to see the bushes before approving. These three bushes are built with the approved Gusty broadleaf's leaf construction, bark and leaf materials: the same code path as the Gusty meadow shrub hero, fitted to the sites they would replace.

**Status: mockup source for review.** Not approved, optimized, exported, uploaded or integrated. Nothing in `src/` has changed. The Phase 1 trees in the "after" renders are the Gusty broadleaf family from its source `.blend`, placed the way the proposed hub placement would place them. They are a preview, not integrated work.

![Before / after](bushes-before-after.png)

In the real layout, at matched cameras (before left, after right):

- [Hub garden from the spawn pad](context-garden.png) · [Hub garden quadrant](context-garden-high.png)
- [Plot 1, border bushes on the fence line](context-plot.png) · [Inside plot 1, down the left fence](context-plot-fence.png)
- [Atlas pavilion planters](context-atlas.png)

Close-ups: [garden](garden-three-quarter.png) · [planter](planter-three-quarter.png) · [border](border-three-quarter.png) · [Editable source](HubBushes.blend) · [Geometry report](geometry-report.json)

| Bush | Replaces | Sites | Built as | W × H × D studs (site today) | Leaves | Source tris |
| --- | --- | ---: | --- | --- | ---: | ---: |
| Garden Bush | `MapBuilder` `GardenShrub` (collidable Ball) | 7 | The meadow shrub's three-lobe plan at d = 5, broadleaf-sized leaves (0.6–0.98) | 7.8 × 4.7 × 6.1 at the 8-wide site; 6- and 10-wide sites scale it 0.85 / 1.15 (a 4.4 sphere) | 1,356 | 33,708 |
| Planter Shrub | `HubLandmarks` Atlas `Shrub` (Ball on a planter) | 2 | A fuller round mound with a lifted top lobe, spilling a little over the 3 × 3 planter; rooted on its top face | 3.7 × 3.2 × 3.7 (a 2.4 sphere) | 828 | 20,904 |
| Border Bush | `PlotTemplate` `PP_Shrub_Cluster` (3 Balls) | 66 | The placeholder's three lobes at their offsets, with larger leaves for its size (0.32–0.5) so it reads at 2.6 studs | 2.95 × 1.6 × 2.1 (envelope 2.6 × 1.3 × 2.0) | 470 | 12,180 |

Every component is closed, with zero non-manifold edges and zero degenerate faces (`geometry-report.json`). Each root socket is at local zero, on the ground at the group centre. Roblox `(x,y,z)` = Blender `(x,z,-y)`.

## Review points

- **The garden bushes grow.** A `Ball` part is drawn as a sphere of its smallest Size axis, so today's garden bushes show as 4.4 spheres even though `MapBuilder` sizes them 6/8/10 × 4.4 × 5.6. The mockup uses those intended sizes, so the new bushes are wider and lower. Say if they should stay at today's footprint instead.
- **The border bush is over its envelope** by 0.35 W and 0.3 H from its leaf tips. It still clears the fence (its half-width is 1.5, and the fence line is 2.3 from its centre). `PP_Shrub_Cluster` would leave Astra's plot kit either way (decision 2 of the plan).
- **Triangles:** the source leaf is 24 triangles. The broadleaf export kept every leaf as an 8-triangle volume, which would put these at roughly 11k / 7k / 4k each, about 355k for all 75 sites. That is an estimate, not a measured export.
- **Not in this batch:** the four small shrubs in each plot's owner-sign planting (part of `PP_Owner_Sign`), and the old-style treeline outside the region chain walls.
- These are Blender renders under Blender light, drawn from a headless map dump. Judge form, scale and density here, not final colour. The headless build also draws Gusty Gardens with its fallback art, because the Lune harness rejects the native broadleaf library. That is a known harness limit, not a game fault.

## Reproduce

```powershell
lune run tools/world_harness.luau <scratch>/hub_dump.json
& 'C:/Program Files/Blender Foundation/Blender 5.1/blender.exe' -b --factory-startup --python tools/blender/create_hub_bushes.py -- --rebuild
& 'C:/Program Files/Blender Foundation/Blender 5.1/blender.exe' -b --factory-startup -P tools/blender/render_hub_bush_context.py -- --dump <scratch>/hub_dump.json
python tools/blender/compose_hub_bush_mockup.py
```

The bush builder appends the Gusty meadow shrub hero for comparison, and the context renderer appends the broadleaf family. Neither ever writes to those files. `world_harness.luau` now also writes each part's `full` ancestry path, which is how the renderer tells a plot fence shrub from the owner sign's.

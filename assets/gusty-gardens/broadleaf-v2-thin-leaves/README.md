# Gusty broadleaf — thinner leaf review

**Approved 2026-09-23:** Rahul responded “Looks good, proceed.” Continued as the A/Meadow source in the [broadleaf family](../broadleaf-family-v1/README.md).

Requested 2026-09-23. Derived from the saved `broadleaf-v2/GustyBroadleaf.blend` with **25% narrower leaf cross-sections**, including their small thickness. Leaf lengths, centerlines, positions, count (3,480), colors and the trunk/branch geometry are retained. The canopy receives no rescaling. Original source and renders are preserved.

![Thinner leaves, actual Blender render](thin-leaves-three-quarter.png)

[Side-by-side: original left, thinner right](leaf-width-comparison.png) · [Detail](thin-leaves-detail.png) · [Editable source](GustyBroadleafThinLeaves.blend)

The comparison contains both actual meshes under the same lights, at identical scales and rotations. The saved source contains only the thinner hero plus the existing preview/reference objects; comparison offsets are render-only.

`tools/blender/create_gusty_thin_leaf_review.py` reproduces the source and three images. Existing output is protected unless `-- --rebuild` is supplied. Geometry validation reports zero nonmanifold edges and degenerate faces in the edited leaf mesh. Source triangle count remains 93,982 overall. This is a design variation for review; optimization, export and Roblox integration remain pending.

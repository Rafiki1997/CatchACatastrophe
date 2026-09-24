# Options 02-05 and the registry of all five. Option 01 and the shared frost
# props (igloo, snowman, fire pit, sled, ice blocks, groves) live in
# fb_options.
import bpy
import bmesh
import math
import random
from mathutils import Vector

import fb_lib as L
import fb_base as B
from fb_lib import rgb, TAU
from fb_options import (make_pines, grove, sled, crystal_mats, drift_ring,  # noqa: F401
                        option_igloo_hollow)


# ------------------------------------------------------------------ shared landforms
def terrace(k, c, x0, x1, y0, y1, top, seed, rock=None, snow=None, name="Terrace", cuts=4, wob=1.2, solid=True):
    """A flat-topped rock shelf: bumpy sides, a level snow walking surface."""
    rng = random.Random(seed)
    bm = L.new_bm()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cuts, use_grid_fill=True)
    sx, sy = x1 - x0, y1 - y0
    for v in bm.verts:
        v.co.x *= sx
        v.co.y *= sy
        v.co.z = (v.co.z + 0.5) * top
        on_top = v.co.z > top - 1e-3
        edge = abs(abs(v.co.x) - sx / 2) < 1e-3 or abs(abs(v.co.y) - sy / 2) < 1e-3
        if not on_top and v.co.z > 1e-3:
            v.co.x += rng.uniform(-wob, wob)
            v.co.y += rng.uniform(-wob, wob)
        elif on_top and edge:
            v.co.x += rng.uniform(-wob, wob) * 0.5
            v.co.y += rng.uniform(-wob, wob) * 0.5
    lay = L.jit_layer(bm)
    bm.normal_update()
    for f in bm.faces:
        f[lay] = rng.uniform(-1, 1)
        f.material_index = 1 if f.normal.z > 0.8 else 0
    return L.obj_from_bm(name, bm, [rock or k.rock, snow or k.snow], c, loc=((x0 + x1) / 2, (y0 + y1) / 2, 0), solid=solid)


def skirt(k, c, rng, x0, x1, y0, y1, top, rock, sides="ESWN", gaps=(), every=7.0, over=1.15):
    """Rocks straddling a shelf's edges, a little taller than the shelf, so
    it reads as an outcrop rather than a box. `gaps` are (x, y, r) circles
    left open for stairs and bridge landings."""
    edges = {
        "S": [((x0 + (x1 - x0) * t), y0) for t in _steps(x1 - x0, every)],
        "N": [((x0 + (x1 - x0) * t), y1) for t in _steps(x1 - x0, every)],
        "W": [(x0, (y0 + (y1 - y0) * t)) for t in _steps(y1 - y0, every)],
        "E": [(x1, (y0 + (y1 - y0) * t)) for t in _steps(y1 - y0, every)],
    }
    for side in sides:
        for x, y in edges[side]:
            if any((x - gx) ** 2 + (y - gy) ** 2 < gr * gr for gx, gy, gr in gaps):
                continue
            if abs(x) > B.IN_X - 1.5:
                continue
            h = top * rng.uniform(0.85, over + 0.25)
            w = rng.uniform(5.5, 9.0)
            L.rock_obj(k, "ShelfRock", (w, w * rng.uniform(0.75, 1.0), h / 0.72), (x + rng.uniform(-1, 1), y + rng.uniform(-1, 1), 0),
                       rng.randrange(1 << 30), c, rock=rock, thresh=0.7, lump=0.22)


def _steps(length, every):
    n = max(1, int(length / every))
    return [(i + 0.5) / n for i in range(n)]


def stairs(k, c, x, y_edge, width, top, steps, depth, direction=-1, stone=None):
    """Solid stone steps down from a shelf edge along Y, each tread dusted with snow."""
    stone = stone or k.rock
    for i in range(1, steps):
        h = top * (steps - i) / steps
        a0 = y_edge + direction * (i - 1) * depth
        a1 = y_edge + direction * i * depth
        am = (a0 + a1) / 2
        L.box_obj("Step", (width, depth + 0.02, h), (x, am, h / 2), stone, c, bevel=0.12)
        L.box_obj("StepSnow", (width - 0.6, depth - 0.5, 0.22), (x, am + direction * 0.1, h + 0.1), k.snow, c, bevel=0.08, solid=False)


def ridge(k, c, rng, pts, rock, snow, depth=(14, 20), width=(14, 22), thresh=0.55, subdiv=2, lump=0.17, name="Ridge"):
    """Big snow-capped rock masses along a list of (x, y, visible height)."""
    for x, y, h in pts:
        w = rng.uniform(*width)
        d = rng.uniform(*depth)
        L.rock_obj(k, name, (w, d, h / 0.72), (x, y, 0), rng.randrange(1 << 30), c, rock=rock, snow=snow, thresh=thresh,
                   subdiv=subdiv, lump=lump)


def point_light(c, name, loc, energy, color, size=1.0):
    ld = bpy.data.lights.new(name, 'POINT')
    ld.energy = energy
    ld.color = color
    ld.shadow_soft_size = size
    lo = bpy.data.objects.new(name, ld)
    lo.location = loc
    c.objects.link(lo)
    return lo


def trail_post(k, c, loc, yaw=0.0):
    bm = L.new_bm()
    L.add_box(bm, (0.6, 0.6, 3.2), (0, 0, 1.6), mi=0, bevel=0.06)
    L.add_box(bm, (0.85, 0.85, 0.28), (0, 0, 3.32), mi=1, bevel=0.1)
    L.add_box(bm, (0.46, 0.1, 0.62), (0, -0.33, 2.55), mi=2)
    refl = L.mat("reflector", rgb(255, 140, 50), emit=2.5, emit_color=rgb(255, 130, 40))
    return L.obj_from_bm("TrailPost", bm, [k.timber_dark, k.snow, refl], c, loc=loc, rot=(0, 0, yaw))


def signpost(k, c, loc, yaw=0.0):
    bm = L.new_bm()
    cream = L.mat("sign_cream", rgb(238, 228, 206), rough=0.6)
    L.add_box(bm, (0.5, 0.5, 6.0), (0, 0, 3.0), mi=0, bevel=0.05)
    for z, a, col in ((5.0, 0.35, 1), (4.0, -2.6, 2)):
        L.add_box(bm, (3.4, 0.22, 0.85), (math.cos(a) * 1.5, math.sin(a) * 1.5, z), rot=(0, 0, a), mi=col, bevel=0.05)
    L.add_box(bm, (0.7, 0.7, 0.22), (0, 0, 6.1), mi=3, bevel=0.08)
    return L.obj_from_bm("Signpost", bm, [k.timber_dark, k.teal, cream, k.snow], c, loc=loc, rot=(0, 0, yaw))


def woodpile(k, c, loc, yaw=0.0, length=4.0):
    bm = L.new_bm()
    r = 0.42
    for row, n in enumerate((4, 3, 2)):
        for j in range(n):
            y = (j - (n - 1) / 2) * 2 * r
            L.add_cyl(bm, r, r, length, (0, y, r + row * 1.7 * r), rot=(0, math.pi / 2, 0), segs=8, mi=0)
    L.add_box(bm, (length * 0.95, 2.4, 0.3), (0, 0, r + 2 * 1.7 * r + 0.45), mi=1, bevel=0.12)
    return L.obj_from_bm("Woodpile", bm, [k.timber, k.snow], c, loc=loc, rot=(0, 0, yaw))


def tent(k, c, loc, yaw, ln=6.4, w=5.2, h=4.4):
    bm = L.new_bm()
    pts = [(-ln / 2, -w / 2, 0), (ln / 2, -w / 2, 0), (ln / 2, w / 2, 0), (-ln / 2, w / 2, 0), (-ln / 2, 0, h), (ln / 2, 0, h)]
    vs = [bm.verts.new(p) for p in pts]
    for f in ((0, 1, 5, 4), (2, 3, 4, 5), (1, 2, 5), (3, 0, 4), (0, 3, 2, 1)):
        bm.faces.new([vs[i] for i in f])
    d = [bm.verts.new(p) for p in ((ln / 2 + 0.05, -w * 0.28, 0.05), (ln / 2 + 0.05, w * 0.28, 0.05), (ln / 2 + 0.05, 0, h * 0.62))]
    fd = bm.faces.new(d)
    fd.material_index = 1
    L.add_box(bm, (ln * 1.02, 0.9, 0.3), (0, 0, h - 0.05), mi=2, bevel=0.1)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    canvas = L.mat("tent_orange", rgb(236, 118, 46), rough=0.7)
    return L.obj_from_bm("Tent", bm, [canvas, L.mat("tent_dark", rgb(60, 40, 34), rough=0.9), k.snow], c, loc=loc, rot=(0, 0, yaw))


def flagpole(k, c, loc, h=13.0):
    bm = L.new_bm()
    L.add_cyl(bm, 0.16, 0.12, h, (0, 0, h / 2), segs=8, mi=0)
    L.add_sphere(bm, 0.38, (0, 0, h + 0.2), segs=10, rings=6, mi=1)
    pts = [(0.15, 0, h - 0.3), (3.6, 0.3, h - 1.1), (0.15, 0, h - 2.2)]
    vs = [bm.verts.new(p) for p in pts]
    vs2 = [bm.verts.new((p[0], p[1] + 0.12, p[2])) for p in pts]
    fs = [bm.faces.new(vs), bm.faces.new(vs2[::-1])]
    for a in range(3):
        b = (a + 1) % 3
        fs.append(bm.faces.new((vs[a], vs[b], vs2[b], vs2[a])))
    for f in fs:
        f.material_index = 2
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return L.obj_from_bm("Flagpole", bm, [k.iron, k.gold, k.teal], c, loc=loc)


def railing(k, c, p0, p1, z=0.0, h=2.4, every=3.0):
    bm = L.new_bm()
    P0, P1 = Vector(p0), Vector(p1)
    d = P1 - P0
    n = max(1, int(d.length / every))
    yaw = math.atan2(d.y, d.x)
    for i in range(n + 1):
        q = P0 + d * (i / n)
        L.add_box(bm, (0.4, 0.4, h), (q.x, q.y, z + h / 2), mi=0, bevel=0.04)
        L.add_box(bm, (0.55, 0.55, 0.18), (q.x, q.y, z + h + 0.09), mi=1, bevel=0.05)
    m = (P0 + P1) / 2
    for zz in (h * 0.55, h - 0.2):
        L.add_box(bm, (d.length, 0.25, 0.25), (m.x, m.y, z + zz), rot=(0, 0, yaw), mi=0)
    L.add_box(bm, (d.length, 0.4, 0.14), (m.x, m.y, z + h + 0.02), rot=(0, 0, yaw), mi=1, bevel=0.05)
    return L.obj_from_bm("Railing", bm, [k.timber_dark, k.snow], c)


# ================================================================== 02
def timber_hut(k, c, loc, yaw, W=16.0, D=13.0, wall_h=6.4, rise=6.4, seed=5):
    """A snowed-in log cabin: stone footing, log walls, board gables, a teal
    roof under a thick snow pillow, warm windows, a porch and a chimney.
    Built with its door on the -Y gable."""
    rng = random.Random(seed)
    bm = L.new_bm()
    stone = L.mat("hut_stone", rgb(118, 126, 140), rough=0.85, jitter=0.14)
    boards = L.plank_mat("boards_v", rgb(146, 100, 62), board=0.8, axis='X')
    glow = L.mat("window_glow", rgb(255, 206, 130), emit=5.0, emit_color=rgb(255, 196, 110))
    smoke = L.mat("smoke", rgb(236, 240, 246), rough=1.0, alpha=0.55)
    mats = [k.timber, k.timber_dark, k.teal, k.snow, glow, stone, boards, k.iron, k.ice, smoke]
    LOG, DARK, ROOF, SNOW, GLOW, STONE, BOARD, IRON, ICE, SMOKE = range(10)
    z0 = 1.2
    L.add_box(bm, (W + 1.4, D + 1.4, z0), (0, 0, z0 / 2), mi=STONE, bevel=0.2, rng=rng, jit=True)
    r = 0.42
    n = int(wall_h / (2 * r))
    for i in range(n):
        z = z0 + r + i * 2 * r
        for s in (-1, 1):
            L.add_cyl(bm, r, r, D + 1.6, (s * W / 2, 0, z), rot=(math.pi / 2, 0, 0), segs=8, mi=LOG)
            if i < n - 1:
                L.add_cyl(bm, r, r, W + 1.6, (0, s * D / 2, z + r), rot=(0, math.pi / 2, 0), segs=8, mi=LOG)
    top = z0 + n * 2 * r
    for s in (-1, 1):
        y0, y1 = s * D / 2 - 0.3, s * D / 2 + 0.3
        pts = [(-W / 2 - 0.1, top - 0.4), (W / 2 + 0.1, top - 0.4), (0, top + rise)]
        v0 = [bm.verts.new((px, y0, pz)) for px, pz in pts]
        v1 = [bm.verts.new((px, y1, pz)) for px, pz in pts]
        fs = [bm.faces.new(v0), bm.faces.new(v1[::-1])]
        for a in range(3):
            b = (a + 1) % 3
            fs.append(bm.faces.new((v0[a], v0[b], v1[b], v1[a])))
        for f in fs:
            f.material_index = BOARD
    oh, ohg, t = 1.5, 1.4, 0.6
    a = math.atan2(rise, W / 2)
    Lr = (W / 2 + oh) / math.cos(a)
    zr = top + rise + 0.3
    for s in (-1, 1):
        nx, nz = s * math.sin(a), math.cos(a)
        cx = s * (Lr / 2) * math.cos(a) + nx * t / 2
        cz = zr - (Lr / 2) * math.sin(a) + nz * t / 2
        L.add_box(bm, (Lr, D + 2 * ohg, t), (cx, 0, cz), rot=(0, s * a, 0), mi=ROOF, bevel=0.08)
        o = t / 2 + 0.5
        L.add_box(bm, (Lr * 0.96, D + 2 * ohg - 0.2, 1.0), (cx + nx * o - s * 0.15, 0, cz + nz * o), rot=(0, s * a, 0), mi=SNOW,
                  bevel=0.42, seg=2)
        ze = zr - Lr * math.sin(a)
        L.icicles(bm, -D / 2 - ohg + 0.4, D / 2 + ohg - 0.4, s * (W / 2 + oh - 0.3), ze + 0.1, rng, ICE, axis='Y',
                  length=(0.6, 1.8), radius=(0.14, 0.3))
    L.add_cyl(bm, 0.75, 0.75, D + 2 * ohg - 0.1, (0, 0, zr + 0.55), rot=(math.pi / 2, 0, 0), segs=8, mi=SNOW)
    cxh, cyh = -W / 4, D / 4
    zc = zr - (W / 4) * math.tan(a)
    L.add_box(bm, (2.0, 2.0, 6.0), (cxh, cyh, zc + 1.6), mi=STONE, bevel=0.1, rng=rng, jit=True)
    L.add_box(bm, (2.4, 2.4, 0.5), (cxh, cyh, zc + 4.85), mi=SNOW, bevel=0.2)
    for j, (dz, rr) in enumerate(((6.4, 0.9), (8.0, 1.2), (9.9, 1.5))):
        L.add_sphere(bm, rr, (cxh + 0.5 * j, cyh + 0.3 * j, zc + dz), segs=10, rings=8, mi=SMOKE)
    yf = -D / 2 - 0.45
    L.add_box(bm, (2.8, 0.5, 4.4), (0, yf, z0 + 2.2), mi=DARK, bevel=0.05)
    L.add_box(bm, (3.4, 0.4, 0.4), (0, yf - 0.05, z0 + 4.6), mi=LOG)
    L.add_sphere(bm, 0.14, (0.9, yf - 0.3, z0 + 2.1), segs=6, rings=4, mi=IRON)
    for s in (-1, 1):
        wx = s * 4.6
        L.add_box(bm, (2.1, 0.3, 1.9), (wx, yf, z0 + 3.4), mi=GLOW)
        for dz in (-1.1, 1.1):
            L.add_box(bm, (2.7, 0.38, 0.3), (wx, yf - 0.05, z0 + 3.4 + dz), mi=DARK)
        for dx in (-1.2, 0, 1.2):
            L.add_box(bm, (0.26 if dx else 0.16, 0.38, 2.3), (wx + dx, yf - 0.05, z0 + 3.4), mi=DARK)
        for dx in (-1.85, 1.85):
            L.add_box(bm, (1.0, 0.25, 2.2), (wx + dx, yf - 0.1, z0 + 3.4), mi=ROOF)
        L.add_box(bm, (2.6, 0.9, 0.35), (wx, yf - 0.35, z0 + 2.3), mi=SNOW, bevel=0.12)
    L.add_cyl(bm, 1.0, 1.0, 0.3, (0, yf, top + rise * 0.42), rot=(math.pi / 2, 0, 0), segs=16, mi=GLOW)
    L.add_cyl(bm, 1.25, 1.25, 0.25, (0, yf + 0.08, top + rise * 0.42), rot=(math.pi / 2, 0, 0), segs=16, mi=DARK)
    for yy in (-2.8, 2.8):
        L.add_box(bm, (0.3, 2.1, 1.9), (W / 2 + 0.55, yy, z0 + 3.4), mi=GLOW)
        L.add_box(bm, (0.38, 2.7, 0.3), (W / 2 + 0.6, yy, z0 + 4.45), mi=DARK)
        L.add_box(bm, (0.38, 2.7, 0.3), (W / 2 + 0.6, yy, z0 + 2.35), mi=DARK)
        L.add_box(bm, (0.9, 2.6, 0.35), (W / 2 + 0.9, yy, z0 + 2.2), mi=SNOW, bevel=0.12)
    pr = -0.2
    L.add_box(bm, (6.4, 3.4, 0.35), (0, yf - 1.7, z0 + 5.3), rot=(pr, 0, 0), mi=ROOF, bevel=0.05)
    L.add_box(bm, (6.2, 3.1, 0.6), (0, yf - 1.7, z0 + 5.72), rot=(pr, 0, 0), mi=SNOW, bevel=0.26, seg=2)
    for s in (-1, 1):
        L.add_box(bm, (0.45, 0.45, 5.1), (s * 2.9, yf - 3.1, z0 + 2.55), mi=DARK, bevel=0.04)
    L.add_box(bm, (6.8, 3.8, 0.3), (0, yf - 1.8, z0 - 0.1), mi=LOG, bevel=0.04)
    L.add_box(bm, (0.7, 0.7, 0.9), (2.0, yf - 0.55, z0 + 3.9), mi=GLOW)
    L.add_box(bm, (0.95, 0.95, 0.22), (2.0, yf - 0.55, z0 + 4.45), mi=IRON)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return L.obj_from_bm("ExpeditionHut", bm, mats, c, loc=loc, rot=(0, 0, yaw))


def rope_bridge(k, c, p0, p1, width=5.0, sag=1.3, n=20, post_h=3.4, rail_h=2.8):
    bm = L.new_bm()
    P0, P1 = Vector(p0), Vector(p1)
    d = P1 - P0
    Lb = d.length
    dv = d.normalized()
    yaw = math.atan2(dv.y, dv.x)
    side = Vector((-dv.y, dv.x, 0))

    def at(t, h=0.0, sg=sag):
        p = P0 + d * t
        p.z += h - sg * 4 * t * (1 - t)
        return p
    for i in range(n):
        q = at((i + 0.5) / n)
        L.add_box(bm, (Lb / n * 0.8, width, 0.3), tuple(q), rot=(0, 0, yaw), mi=0, bevel=0.03)
    for s in (-1, 1):
        rail = [tuple(at(i / 12, rail_h, sag * 0.7) + side * s * width / 2) for i in range(13)]
        L.add_tube(bm, rail, [0.13] * 13, segs=6, mi=1)
        low = [tuple(at(i / 12, 0.12) + side * s * (width / 2 - 0.1)) for i in range(13)]
        L.add_tube(bm, low, [0.1] * 13, segs=6, mi=1)
        for i in range(1, 12):
            a_ = at(i / 12, 0.12) + side * s * width / 2
            b_ = at(i / 12, rail_h, sag * 0.7) + side * s * width / 2
            L.add_tube(bm, [tuple(a_), tuple(b_)], [0.06, 0.06], segs=4, mi=1)
        for P in (P0, P1):
            q = P + side * s * (width / 2 + 0.25)
            L.add_box(bm, (0.65, 0.65, post_h + 0.6), (q.x, q.y, q.z + post_h / 2 - 0.3), mi=2, bevel=0.05)
            L.add_box(bm, (0.85, 0.85, 0.26), (q.x, q.y, q.z + post_h + 0.12), mi=3, bevel=0.08)
    return L.obj_from_bm("RopeBridge", bm, [k.timber, k.rope, k.timber_dark, k.snow], c)


def option_alpine_outpost(k, c, rng):
    """02 ALPINE OUTPOST - the approved Alpine Expedition identity refitted
    to the rectangle: a snow-capped strata ridge along the rear wall, a log
    expedition hut on a raised terrace at the rear-left, and a rope bridge
    between two rock outcrops on the right."""
    pines = make_pines(k, 202)
    strata = L.strata_mat("alpine_strata", rgb(92, 104, 126), rgb(116, 128, 148), band=3.2)
    extra = []
    back, front = [], []
    for s in (-1, 1):
        for i, x in enumerate([129, 114, 100, 87, 74, 61, 49]):
            h = [44, 37, 31, 25, 20, 15, 12][i] * rng.uniform(0.85, 1.15)
            back.append((s * x + rng.uniform(-2.5, 2.5), 92 + rng.uniform(-1.5, 1.5), h))
        for i, x in enumerate([121, 93]):
            front.append((s * x + rng.uniform(-3, 3), 81 + rng.uniform(-1.5, 1.5), [20, 13][i] * rng.uniform(0.85, 1.15)))
    for y, h in ((74, 28), (62, 19)):
        back.append((-130, y, h))
    ridge(k, c, rng, back, strata, k.snow, depth=(12, 15), width=(13, 24), subdiv=1, lump=0.24, thresh=0.6)
    ridge(k, c, rng, front, strata, k.snow, depth=(9, 12), width=(10, 16), subdiv=1, lump=0.24, thresh=0.62)
    extra += [('r', -140, 78, -36, 100), ('r', 36, 78, 140, 100), ('r', -140, 56, -118, 100)]
    TX0, TX1, TY0, TY1, TOP = -137.0, -96.0, 28.0, 84.0, 6.0
    terrace(k, c, TX0, TX1, TY0, TY1, TOP, 21, rock=strata)
    skirt(k, c, rng, TX0, TX1, TY0, TY1, TOP, strata, sides="SE", gaps=((-114.0, TY0, 9.5), (TX1, 80.0, 4.0)), over=0.9)
    stairs(k, c, -114.0, TY0, 13.0, TOP, 4, 2.8, direction=-1, stone=strata)
    extra.append(('r', TX0 - 3, TY0 - 12, TX1 + 4, TY1 + 2))
    timber_hut(k, c, (-118.0, 62.0, TOP), 0.0, W=21.0, D=17.0, wall_h=7.6, rise=8.2)
    tent(k, c, (-103.5, 42.0, TOP), math.radians(-70), ln=7.4, w=6.0, h=5.0)
    woodpile(k, c, (-132.0, 50.0, TOP), math.radians(90), length=6.0)
    flagpole(k, c, (-99.0, 80.0, TOP), h=15.0)
    railing(k, c, (-96.8, 36.0), (-96.8, 80.0), z=TOP)
    for x, y in ((-101.5, 60.0), (-100.6, 64.4), (-103.4, 67.0)):
        L.crate_obj(k, "Crate", (2.8, 2.8, 2.6), (x, y, TOP), c, rot_z=rng.uniform(-0.3, 0.3))
    L.crate_obj(k, "Crate", (2.4, 2.4, 2.2), (-101.5, 60.0, TOP + 2.6), c, rot_z=0.4)
    L.barrel_obj(k, "Barrel", 1.1, 2.6, (-105.5, 74.0, TOP), c)
    L.barrel_obj(k, "Barrel", 1.1, 2.6, (-103.0, 75.4, TOP), c)
    sled(k, "Sled", (-110.0, 39.5, TOP), math.radians(15), c, deck=k.teal)
    for x, y in ((-105.0, 31.5), (-123.0, 31.5)):
        L.lantern_post(k, "TerraceLantern", (x, y, TOP), c, height=5.0)
    OA = (104.0, 134.0, 56.0, 78.0)
    OB = (106.0, 132.0, 14.0, 34.0)
    OT = 10.0
    terrace(k, c, *OA, OT, 22, rock=strata, wob=1.6)
    terrace(k, c, *OB, OT, 23, rock=strata, wob=1.6)
    skirt(k, c, rng, *OA, OT, strata, sides="SW", gaps=((119.0, OA[2], 6.0),), over=1.3)
    skirt(k, c, rng, *OB, OT, strata, sides="NWS", gaps=((119.0, OB[3], 6.0), (116.0, OB[2], 7.5)), over=1.3)
    for (px, py) in ((127.0, 70.0), (110.0, 72.0), (128.0, 20.0)):
        L.place(pines[rng.randrange(len(pines))], "OutcropPine", c, (px, py, OT), rot_z=rng.uniform(0, TAU), scale=0.8)
    rope_bridge(k, c, (119.0, 56.5, OT), (119.0, 33.5, OT), width=6.0, sag=1.4, n=18)
    stairs(k, c, 116.0, OB[2], 10.0, OT, 5, 2.2, direction=-1, stone=strata)
    L.lantern_post(k, "OutcropLantern", (110.0, 30.0, OT), c, height=4.6)
    L.lantern_post(k, "OutcropLantern", (110.0, 60.0, OT), c, height=4.6)
    frozen = L.mat("creek_ice", rgb(150, 206, 236), rough=0.06, coat=1.0, spec=0.8)
    L.box_obj("FrozenCreek", (22.0, 18.0, 0.2), (121.0, 45.0, 0.1), frozen, c, bevel=0.1, solid=False)
    for i in range(8):
        L.rock_obj(k, "CreekStone", (rng.uniform(2, 3.5), rng.uniform(2, 3), rng.uniform(1.2, 2.2)),
                   (rng.choice((108.5, 133.0)) + rng.uniform(-1, 1), rng.uniform(37, 53), 0), rng.randrange(1 << 30), c, rock=strata)
    extra += [('r', OA[0] - 3, OA[2] - 3, 140, OA[3] + 3), ('r', OB[0] - 3, OB[2] - 12, 140, OB[3] + 3), ('r', 100, 33, 140, 57)]
    for i in range(9):
        y = -78 + i * 19.5
        for s in (-1, 1):
            trail_post(k, c, (s * (B.LANE_HALF + 3.2), y, 0), yaw=0.0)
    signpost(k, c, (-44.0, -86.0, 0), yaw=math.radians(10))
    extra.append(('c', -44, -86, 4))
    for (cx, cy, n, r) in [(-128, 14, 5, 8), (-126, -30, 4, 7), (-128, -70, 5, 8), (128, -8, 4, 7), (126, -52, 5, 8),
                           (-66, 82, 3, 5), (66, 82, 3, 5), (-96, 88, 3, 5), (98, 88, 3, 5)]:
        grove(k, c, pines, rng, cx, cy, n, r)
        extra.append(('c', cx, cy, r + 2))
    B.band_clusters(k, c, pines, rng, extra=extra, n=34, spacing=12.0, pine_share=0.75, rock=strata)
    B.wall_drifts(k, c, rng, extra=extra)
    B.field_tufts(k, c, rng)
    B.field_specks(k, c, rng, n=40, mat_=strata)
    return {"landmarks": ["snow-capped strata ridge along the rear wall (to ~34 studs at the corners)",
                          "rear-left terrace (top 6) with stairs, log expedition hut, tent, woodpile, flag, crates",
                          "two right-hand rock outcrops (top 10), 23-stud rope bridge, stairs, frozen creek",
                          "18 trail posts flanking the lane, trailhead signpost"]}


# ================================================================== 03
def frozen_fall(k, c, x0, x1, y, z_top, rng, mat_fall, mat_deep):
    """A frozen cascade down a cliff face: ice strands, a splash mound and an
    icicle lip. y is the cliff face; the fall stands just proud of it."""
    bm = L.new_bm()
    n = 7
    for i in range(n):
        xi = x0 + (x1 - x0) * (i + 0.5) / n + rng.uniform(-0.6, 0.6)
        w = (x1 - x0) / n
        h = z_top * rng.uniform(0.85, 1.0)
        r0 = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=6, radius1=w * 0.8, radius2=w * 0.42, depth=h,
                                   matrix=L.xform((xi, y - 1.2 - rng.uniform(0, 1.2), h / 2)))
        for v in r0['verts']:
            v.co.x += rng.uniform(-0.3, 0.3)
            v.co.y += rng.uniform(-0.4, 0.2)
        L._finish(bm, r0['verts'], 0 if i % 2 else 1, rng, True, 0.0, 1)
    L.add_ico(bm, 1.0, ((x0 + x1) / 2, y - 5.0, 0.6), scale=((x1 - x0) * 0.7, 6.5, 2.6), subdiv=2, mi=0, rng=rng, jit=True, lump=0.1)
    L.icicles(bm, x0 - 1, x1 + 1, y - 0.8, z_top + 0.4, rng, 1, length=(1.5, 4.0), radius=(0.3, 0.6))
    return L.obj_from_bm("FrozenFall", bm, [mat_fall, mat_deep], c)


def frozen_pool(k, c, cx, cy, rx, ry, rng, rim=None, open_north=True):
    pool = L.mat("pool_ice", rgb(118, 192, 232), rough=0.04, coat=1.0, spec=0.9, jitter=0.02)
    crack = L.mat("pool_crack", rgb(70, 130, 180), rough=0.3)
    floe = L.mat("pool_floe", rgb(222, 240, 250), rough=0.4)
    bm = L.new_bm()
    pts = []
    for i in range(30):
        a = i / 30 * TAU
        j = 1 + rng.uniform(-0.08, 0.08)
        pts.append((cx + math.cos(a) * rx * j, cy + math.sin(a) * ry * j))
    L.add_prism(bm, pts, 0.02, 0.22, mi=0)
    for i in range(7):
        a = rng.uniform(0, TAU)
        ln = rng.uniform(3, 8)
        px, py = cx + rng.uniform(-0.5, 0.5) * rx, cy + rng.uniform(-0.5, 0.5) * ry
        L.add_box(bm, (ln, 0.18, 0.05), (px, py, 0.24), rot=(0, 0, a), mi=1)
    for i in range(4):
        px, py = cx + rng.uniform(-0.55, 0.55) * rx, cy + rng.uniform(-0.55, 0.55) * ry
        L.add_box(bm, (rng.uniform(2, 3.5), rng.uniform(1.6, 2.8), 0.25), (px, py, 0.3), rot=(0, 0, rng.uniform(0, TAU)), mi=2, bevel=0.1)
    L.obj_from_bm("FrozenPool", bm, [pool, crack, floe], c, solid=False)
    for i in range(22):
        a = i / 22 * TAU + rng.uniform(-0.08, 0.08)
        if open_north and 0.9 < a < 2.25:
            continue
        s = rng.uniform(2.4, 4.8)
        L.rock_obj(k, "PoolRim", (s * 1.4, s, s * 0.8), (cx + math.cos(a) * (rx + 1.2), cy + math.sin(a) * (ry + 1.2), 0),
                   rng.randrange(1 << 30), c, rock=rim)


def ice_arch(k, c, xa, xb, y, H, rng, mats, n=15, r_base=5.8, r_top=3.2, depth=8.0, name="IceArch"):
    """A natural arch of ice chunks spanning xa..xb in the plane y, snow on
    its back, icicles under it. Its opening faces the camera."""
    bm = L.new_bm()
    xm, half = (xa + xb) / 2, (xb - xa) / 2
    faces = set()
    for i in range(n):
        t = i / (n - 1) * math.pi
        x = xm - math.cos(t) * half
        z = math.sin(t) * H
        r = r_base * (1 - math.sin(t)) + r_top * math.sin(t)
        fs = L.add_ico(bm, 1.0, (x, y + rng.uniform(-0.8, 0.8), z + (r * 0.3 if i in (0, n - 1) else 0)),
                       scale=(r * 1.25, depth * 0.55 * rng.uniform(0.85, 1.1), r * 1.05), subdiv=1, mi=0 if i % 3 else 1,
                       rng=rng, jit=True, lump=0.18)
        faces |= fs
    L.snow_tops(bm, faces, 2, thresh=0.62)
    for i in range(18):
        t = rng.uniform(0.18, 0.82) * math.pi
        x = xm - math.cos(t) * half
        z = math.sin(t) * H - (r_base * (1 - math.sin(t)) + r_top * math.sin(t)) * 0.85
        ln = rng.uniform(1.2, 3.2)
        r0 = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=5, radius1=0.0, radius2=rng.uniform(0.25, 0.5),
                                   depth=ln, matrix=L.xform((x, y + rng.uniform(-2, 2), z - ln / 2)))
        L._finish(bm, r0['verts'], 0, rng, True, 0.0, 1)
    return L.obj_from_bm(name, bm, mats, c)


def option_glacier_falls(k, c, rng):
    """03 GLACIER FALLS - the natural-ice option: a blue glacier cliff in the
    rear-right corner with a frozen waterfall into a frozen pool, a natural
    ice arch on the left, and ice boulders through the bands."""
    pines = make_pines(k, 303)
    ice_a = L.mat("glacier_a", rgb(150, 206, 236), rough=0.2, sss=0.2, coat=0.5, jitter=0.12, rand=0.08)
    ice_b = L.mat("glacier_b", rgb(84, 146, 204), rough=0.2, sss=0.2, coat=0.5, jitter=0.12, rand=0.08)
    fall = L.mat("ice_fall", rgb(226, 248, 255), rough=0.05, trans=0.3, emit=0.6, emit_color=rgb(190, 238, 255), coat=0.8)
    fall_deep = L.mat("ice_fall_deep", rgb(150, 214, 244), rough=0.1, trans=0.35, emit=0.2, emit_color=rgb(140, 210, 245), coat=0.6)
    strata = L.strata_mat("glacier_strata", rgb(88, 102, 128), rgb(110, 124, 146), band=3.0)
    extra = []
    cols = []
    for gx in range(62, 138, 6):
        for gy in (86, 93):
            t = (gx - 62) / 75.0
            cols.append((gx + rng.uniform(-1.5, 1.5), gy + rng.uniform(-1.5, 1.5), 13 + 25 * t ** 1.4))
    for gy in range(38, 86, 6):
        for gx in (126, 133):
            t = (gy - 38) / 48.0
            cols.append((gx + rng.uniform(-1.5, 1.5), gy + rng.uniform(-1.5, 1.5), 15 + 22 * t ** 1.3))
    for x, y, h in cols:
        r = rng.uniform(4.0, 5.6)
        L.column_obj(k, "GlacierColumn", r, h * rng.uniform(0.95, 1.15), (x, y, 0), rng.randrange(1 << 30), c,
                     [ice_a if rng.random() < 0.55 else ice_b, k.snow], segs=rng.choice((5, 6, 7)), taper=rng.uniform(0.72, 0.9))
    frozen_fall(k, c, 96.0, 120.0, 82.0, 33.0, rng, fall, fall_deep)
    frozen_pool(k, c, 108.0, 63.0, 16.0, 11.5, rng, rim=strata)
    extra += [('r', 56, 80, 140, 100), ('r', 120, 34, 140, 100), ('c', 108, 64, 18)]
    ice_arch(k, c, -136.0, -96.0, 34.0, 29.0, rng, [ice_a, ice_b, k.snow], r_base=6.6, r_top=3.8, depth=9.0)
    drift_ring(k, c, -117, 34, 6, rng, n=5)
    extra.append(('r', -140, 24, -94, 44))
    pts = [(-129, 92, 27), (-115, 92, 22), (-101, 92, 18), (-87, 92, 14), (-73, 92, 11), (-59, 92, 8), (-131, 70, 18)]
    ridge(k, c, rng, pts, strata, k.snow, depth=(11, 14), width=(12, 20), subdiv=1, lump=0.24, thresh=0.6)
    ridge(k, c, rng, [(-122, 81, 12), (-96, 82, 8), (-132, 52, 10)], strata, k.snow, depth=(8, 11), width=(9, 14), subdiv=1,
          lump=0.24, thresh=0.62)
    for i, (x, y, h) in enumerate([(-121, 80, 12), (-92, 81, 9), (-133, 56, 10)]):
        L.column_obj(k, "IceSeam", 2.6, h, (x, y, 0), 800 + i, c, [ice_b, k.snow], segs=5)
    extra += [('r', -140, 78, -48, 100), ('r', -140, 56, -120, 80)]

    def accent(px, py, r_):
        s = r_.uniform(2.5, 4.5)
        L.rock_obj(k, "IceBoulder", (s * 1.3, s, s * 1.1), (px, py, 0), r_.randrange(1 << 30), c, rock=ice_a, snow=k.snow, lump=0.2)
    for (cx, cy, n, r) in [(-128, 0, 5, 8), (-126, -44, 4, 7), (-126, -80, 4, 6), (100, 30, 4, 6), (128, 10, 5, 8), (126, -40, 5, 8),
                           (126, -80, 4, 6), (-46, 86, 3, 4), (48, 72, 2, 3)]:
        grove(k, c, pines, rng, cx, cy, n, r)
        extra.append(('c', cx, cy, r + 2))
    B.band_clusters(k, c, pines, rng, extra=extra, n=30, spacing=12.0, pine_share=0.55, rock=strata, accent=accent, accent_share=0.5)
    B.wall_drifts(k, c, rng, extra=extra)
    B.field_tufts(k, c, rng)
    B.field_specks(k, c, rng, n=36, mat_=strata)
    return {"landmarks": ["blue glacier cliff, rear-right corner (13 to 38 studs)", "frozen waterfall on its south face",
                          "frozen pool 32 x 23 with a rock rim", "natural ice arch, left band, 40 span x 29 high",
                          "low strata cliffs with ice seams, rear-left", "ice boulders through the bands"]}


# ================================================================== 04
def grotto(k, c, cx, cy, yaw, rng, ice_mats, glow_mat, crystal_mats_, name="Grotto"):
    """A shallow ice grotto: an arched mouth of ice chunks, a solid shell
    behind it, and a glowing back wall with crystals, the mouth facing -Y
    before `yaw` turns it."""
    bm = L.new_bm()
    faces = set()
    span, H, n = 24.0, 17.0, 13
    for i in range(n):
        t = i / (n - 1) * math.pi
        x = -math.cos(t) * span / 2
        z = math.sin(t) * H
        r = 5.8 * (1 - math.sin(t)) + 3.5 * math.sin(t)
        faces |= L.add_ico(bm, 1.0, (x, 0, z + (r * 0.3 if i in (0, n - 1) else 0)), scale=(r * 1.2, 5.2, r), subdiv=1,
                           mi=0 if i % 2 else 1, rng=rng, jit=True, lump=0.18)
    for i in range(10):
        a = i / 9 * math.pi
        faces |= L.add_ico(bm, 1.0, (-math.cos(a) * 12.5, 9 + math.sin(a) * 4, 8 + rng.uniform(-1, 3)),
                           scale=(8.5, 8.5, 10.5), subdiv=1, mi=1, rng=rng, jit=True, lump=0.2)
    L.snow_tops(bm, faces, 2, thresh=0.6)
    r0 = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=20, radius1=9.6, radius2=9.6, depth=0.3,
                               matrix=L.xform((0, 5.2, 6.6), (math.pi / 2, 0, 0), (1.0, 0.85, 1.0)))
    L._finish(bm, r0['verts'], 3, None, False, 0.0, 1)
    L.add_box(bm, (21.0, 9.0, 0.3), (0, 3.2, 0.15), mi=3)
    ob = L.obj_from_bm(name, bm, ice_mats + [glow_mat], c, loc=(cx, cy, 0), rot=(0, 0, yaw))
    for i, (dx, dy, h) in enumerate(((-3.5, 2.5, 5.0), (2.8, 2.0, 4.0), (0.4, 3.2, 6.5))):
        wx = cx + dx * math.cos(yaw) - dy * math.sin(yaw)
        wy = cy + dx * math.sin(yaw) + dy * math.cos(yaw)
        L.crystal_cluster("GrottoCrystal", (wx, wy, 0), 420 + i, c, crystal_mats_, count=5, height=h, radius=h * 0.14, spread=h * 0.3)
    point_light(c, name + "Light", (cx - 1.0 * math.sin(yaw), cy + 1.0 * math.cos(yaw), 5.0), 2500, (0.55, 0.9, 1.0), 3.0)
    return ob


def crystal_post(k, c, loc, mats_, stone):
    bm = L.new_bm()
    L.add_box(bm, (1.3, 1.3, 3.0), (0, 0, 1.5), mi=0, bevel=0.12)
    L.add_box(bm, (1.6, 1.6, 0.4), (0, 0, 3.1), mi=0, bevel=0.1)
    r1 = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=6, radius1=0.45, radius2=0.42, depth=1.4,
                               matrix=L.xform((0, 0, 4.0)))
    r2 = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=6, radius1=0.42, radius2=0.0, depth=0.9,
                               matrix=L.xform((0, 0, 5.15)))
    L._finish(bm, r1['verts'] + r2['verts'], 1, None, False, 0.0, 1)
    L.add_box(bm, (1.5, 1.5, 0.2), (0, 0, 3.38), mi=2, bevel=0.08)
    return L.obj_from_bm("CrystalPost", bm, [stone, mats_[0], k.snow], c, loc=loc)


def option_crystal_grotto(k, c, rng):
    """04 CRYSTAL GROTTO - the magical option: violet and cyan crystal spires
    breaking out of indigo slate in the rear-left, a glowing ice grotto in
    the rear-right, silvery firs, and crystal-tipped posts along the lane."""
    silver = L.mat("pine_silver", rgb(92, 128, 136), rough=0.75, jitter=0.1, rand=0.12)
    silver_d = L.mat("pine_silver_d", rgb(72, 104, 116), rough=0.75, jitter=0.1, rand=0.12)
    pines = make_pines(k, 404, green=silver, dark=silver_d)
    indigo = L.strata_mat("indigo_strata", rgb(66, 64, 104), rgb(84, 82, 124), band=2.6)
    violet = crystal_mats("violet", (190, 140, 255), 1.4)
    cyan = crystal_mats("cyan", (130, 226, 255), 1.3)
    ice_a = L.mat("grotto_ice", rgb(156, 212, 240), rough=0.18, sss=0.2, coat=0.5, jitter=0.12, rand=0.08)
    ice_b = L.mat("grotto_ice_b", rgb(118, 176, 222), rough=0.18, sss=0.2, coat=0.5, jitter=0.12, rand=0.08)
    glow = L.mat("grotto_glow", rgb(150, 236, 255), emit=5.0, emit_color=rgb(120, 225, 255))
    extra = []
    pts = [(-126, 86, 26), (-110, 90, 22), (-94, 88, 16), (-80, 90, 11), (-132, 66, 20), (-118, 72, 12), (-132, 46, 12)]
    ridge(k, c, rng, pts, indigo, k.snow, depth=(12, 16), width=(13, 18), thresh=0.6, subdiv=1, lump=0.24)
    spires = [(-112, 76, 50, violet, 9), (-129, 56, 32, cyan, 7), (-92, 84, 27, cyan, 6), (-126, 90, 22, violet, 5),
              (-102, 62, 17, violet, 5)]
    for i, (x, y, h, m_, n) in enumerate(spires):
        L.crystal_cluster("CrystalSpire", (x, y, 0), 500 + i, c, m_, count=n, height=h, radius=h * 0.11, spread=h * 0.26,
                          tilt=0.4, base_mat=indigo)
    point_light(c, "SpireGlow", (-108, 66, 10), 3000, (0.75, 0.6, 1.0), 4.0)
    extra += [('r', -140, 40, -86, 100), ('r', -140, 78, -72, 100)]
    grotto(k, c, 106.0, 80.0, math.radians(18), rng, [ice_a, ice_b, k.snow], glow, cyan)
    for i, (x, y, h) in enumerate([(128, 90, 30), (134, 74, 24), (90, 92, 16), (76, 91, 12), (134, 56, 16), (62, 92, 9)]):
        L.column_obj(k, "IceRidge", rng.uniform(4.0, 5.5), h, (x, y, 0), 600 + i, c, [ice_a if i % 2 else ice_b, k.snow],
                     segs=6, taper=0.7)
    extra += [('r', 56, 72, 140, 100), ('r', 120, 46, 140, 100)]
    for i in range(7):
        y = -72 + i * 24
        for s in (-1, 1):
            crystal_post(k, c, (s * (B.LANE_HALF + 3.5), y, 0), cyan if i % 2 else violet, indigo)

    def accent(px, py, r_):
        L.crystal_cluster("BandCrystal", (px, py, 0), r_.randrange(1 << 30), c, violet if r_.random() < 0.5 else cyan,
                          count=r_.randint(3, 6), height=r_.uniform(4, 8), radius=0.6, spread=1.6, base_mat=k.snow)
    for (cx, cy, n, r) in [(-128, 14, 4, 7), (-126, -34, 4, 7), (-128, -76, 4, 6), (128, 20, 4, 7), (126, -26, 4, 7),
                           (128, -74, 4, 6), (-60, 90, 3, 4), (46, 90, 3, 4)]:
        grove(k, c, pines, rng, cx, cy, n, r)
        extra.append(('c', cx, cy, r + 2))
    B.band_clusters(k, c, pines, rng, extra=extra, n=32, spacing=12.0, pine_share=0.6, rock=indigo, accent=accent,
                    accent_share=0.55)
    B.wall_drifts(k, c, rng, extra=extra)
    B.field_tufts(k, c, rng)
    B.field_specks(k, c, rng, n=36, mat_=indigo)
    return {"landmarks": ["five crystal spire clusters in indigo slate, rear-left (to ~50 studs)",
                          "ice grotto with a glowing back wall and crystals, rear-right", "ice ridge columns around it",
                          "14 crystal-tipped posts flanking the lane", "crystal outcrops through the bands"]}


# ================================================================== 05
def plinth(k, c, cx, cy, tiers, stone):
    z = 0.0
    for w, h in tiers:
        L.box_obj("Plinth", (w, w, h), (cx, cy, z + h / 2), stone, c, bevel=0.2)
        L.box_obj("PlinthSnow", (w - 0.8, w - 0.8, 0.3), (cx, cy, z + h + 0.12), k.snow, c, bevel=0.12, solid=False)
        z += h
    return z


def tusk_arch(k, c, xa, xb, y, H, ivory, gold, rng, base=None):
    bm = L.new_bm()
    xm, half = (xa + xb) / 2, (xb - xa) / 2
    for s in (-1, 1):
        pts, radii = [], []
        for i in range(14):
            t = i / 13
            ang = t * (math.pi / 2) * 0.97
            pts.append((xm + s * half * math.cos(ang), y + s * 0.8 * math.sin(t * math.pi), H * math.sin(ang)))
            radii.append(1.55 * (1 - t) + 0.55 * t)
        L.add_tube(bm, pts, radii, segs=10, mi=0)
        for zz in (2.6, 4.6):
            L.add_cyl(bm, 1.75, 1.75, 0.55, (xm + s * half * math.cos(math.asin(min(1.0, zz / H))), y, zz), segs=12, mi=1)
    L.add_cyl(bm, 1.0, 1.0, 1.6, (xm, y, H - 0.4), rot=(0, math.pi / 2, 0), segs=12, mi=1)
    ob = L.obj_from_bm("TuskArch", bm, [ivory, gold], c, smooth=True)
    for s in (-1, 1):
        L.rock_obj(k, "TuskBase", (6.5, 6.0, 4.0), (xm + s * half, y, 0), rng.randrange(1 << 30), c, rock=base)
    return ob


def brazier(k, c, loc, stone):
    bm = L.new_bm()
    L.add_cyl(bm, 1.3, 1.0, 2.6, (0, 0, 1.3), segs=10, mi=0)
    L.add_cyl(bm, 1.2, 2.3, 1.3, (0, 0, 3.2), segs=12, mi=0)
    L.add_cyl(bm, 1.6, 0.0, 3.2, (0, 0, 5.4), segs=7, mi=1)
    L.add_cyl(bm, 1.0, 0.0, 2.4, (0.8, 0.4, 5.0), segs=6, mi=2)
    L.add_cyl(bm, 0.9, 0.0, 2.1, (-0.7, -0.5, 4.9), segs=6, mi=2)
    f1 = L.mat("frostfire", rgb(110, 210, 255), emit=8.0, emit_color=rgb(90, 200, 255))
    f2 = L.mat("frostfire_core", rgb(220, 250, 255), emit=9.0, emit_color=rgb(200, 245, 255))
    L.obj_from_bm("FrostBrazier", bm, [stone, f1, f2], c, loc=loc)
    point_light(c, "BrazierLight", (loc[0], loc[1], loc[2] + 5.5), 1400, (0.5, 0.85, 1.0), 1.2)


def runestone(k, c, loc, h, seed, stone, glyph):
    rng = random.Random(seed)
    bm = L.new_bm()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True)
    for v in bm.verts:
        v.co.x *= 3.2
        v.co.y *= 1.8
        v.co.z = (v.co.z + 0.5) * h
        if v.co.z > 0.01:
            v.co.x += rng.uniform(-0.25, 0.25)
            v.co.y += rng.uniform(-0.15, 0.15)
        if v.co.z > h - 0.01:
            v.co.x *= 0.8
    lay = L.jit_layer(bm)
    bm.normal_update()
    for f in bm.faces:
        f[lay] = rng.uniform(-1, 1)
        f.material_index = 1 if f.normal.z > 0.75 else 0
    for i in range(3):
        L.add_box(bm, (rng.uniform(0.9, 1.8), 0.12, 0.22), (rng.uniform(-0.5, 0.5), -0.95, h * (0.35 + 0.18 * i)),
                  rot=(0, rng.choice((0, 0.6, -0.6)), 0), mi=2)
    L.add_box(bm, (0.22, 0.12, h * 0.5), (0.0, -0.95, h * 0.52), mi=2)
    return L.obj_from_bm("Runestone", bm, [stone, k.snow, glyph], c, loc=loc, rot=(0, 0, rng.uniform(-0.3, 0.3)))


class _StatueMats:
    pass


def option_coldsnout_crown(k, c, rng):
    """05 COLDSNOUT'S CROWN - the lore option: a carved statue of King
    Coldsnout, the region's legendary mammoth, wearing his glacier crown on a
    stepped plinth in the rear-left; giant tusk arches and a frost brazier
    on the right; a ring of rune stones in the front-left corner."""
    pines = make_pines(k, 505)
    stone = L.mat("statue_stone", rgb(128, 148, 180), rough=0.62, jitter=0.05)
    stone_d = L.mat("statue_stone_d", rgb(104, 124, 158), rough=0.62, jitter=0.05)
    plinth_stone = L.strata_mat("plinth_stone", rgb(120, 130, 148), rgb(136, 146, 162), band=1.6, distort=0.5)
    ivory = L.mat("ivory", rgb(246, 238, 216), rough=0.35, sss=0.1)
    glyph = L.mat("glyph", rgb(120, 220, 255), emit=4.0, emit_color=rgb(100, 210, 255))
    strata = L.strata_mat("crown_strata", rgb(90, 102, 124), rgb(112, 124, 144), band=3.0)
    crown_ice = L.mat("crown_ice", rgb(150, 225, 255), rough=0.06, trans=0.5, emit=0.9, emit_color=rgb(130, 220, 255))
    gold = L.mat("gold", rgb(232, 176, 64), rough=0.32, metal=1.0)
    extra = []
    top = plinth(k, c, -110.0, 66.0, [(40.0, 2.4), (33.0, 2.4), (26.0, 2.4)], plinth_stone)
    stairs(k, c, -110.0, 46.0, 14.0, 7.2, 4, 2.2, direction=-1, stone=plinth_stone)
    sm = _StatueMats()
    sm.mammoth, sm.mammoth_light, sm.tusk, sm.crown = stone, stone_d, ivory, gold
    sm.eye, sm.shine, sm.horn = L.mat("statue_eye", rgb(34, 42, 60), rough=0.5), stone, crown_ice
    st = B.mammoth(sm, c, (-113.0, 67.0, top), math.radians(-35), scale=5.3)
    st["solid"] = 1
    st["tag"] = "landmark"
    for a in (0.3, 5.1):
        L.lantern_post(k, "PlinthLantern", (-110 + math.cos(a) * 23.0, 66 + math.sin(a) * 23.0, 0), c, height=5.5)
    extra.append(('r', -140, 44, -86, 90))
    tusk_arch(k, c, 99.0, 133.0, 52.0, 30.0, ivory, gold, rng, base=strata)
    tusk_arch(k, c, 102.0, 130.0, 14.0, 25.0, ivory, gold, rng, base=strata)
    brazier(k, c, (116.0, 52.0, 0.0), plinth_stone)
    for x in (108.0, 124.0):
        L.box_obj("BrazierStep", (4.0, 3.0, 0.6), (x, 44.0, 0.3), plinth_stone, c, bevel=0.1, solid=False)
    extra += [('r', 94, 8, 140, 60)]
    for i in range(6):
        a = i / 6 * TAU + 0.3
        runestone(k, c, (-112 + math.cos(a) * 13, -64 + math.sin(a) * 11, 0), rng.uniform(6.5, 9.5), 900 + i, plinth_stone, glyph)
    extra.append(('c', -112, -64, 18))
    for gx in range(70, 138, 7):
        t = (gx - 70) / 67.0
        L.column_obj(k, "GlacierChunk", rng.uniform(3.6, 4.8), 11 + 16 * t, (gx + rng.uniform(-1.5, 1.5), 91 + rng.uniform(-2, 2), 0),
                     rng.randrange(1 << 30), c, [k.ice_opaque if rng.random() < 0.5 else k.ice_deep, k.snow], segs=6)
    ridge(k, c, rng, [(-130, 90, 24), (-116, 92, 20), (-100, 91, 16), (-86, 91, 12), (-72, 90, 9), (-133, 74, 16)], strata, k.snow,
          depth=(12, 15), width=(14, 18))
    extra += [('r', 64, 82, 140, 100), ('r', -140, 80, -64, 100)]
    for i in range(7):
        y = -72 + i * 24
        for s in (-1, 1):
            bm = L.new_bm()
            L.add_cyl(bm, 0.8, 0.7, 1.8, (0, 0, 0.9), segs=8, mi=0)
            L.add_cyl(bm, 0.75, 0.35, 0.45, (0, 0, 2.0), segs=8, mi=1)
            L.obj_from_bm("LaneMarker", bm, [plinth_stone, k.snow], c, loc=(s * (B.LANE_HALF + 3.0), y, 0))
    for (cx, cy, n, r) in [(-128, 20, 5, 8), (-128, -24, 4, 7), (128, -10, 4, 7), (126, -50, 5, 8), (-60, 88, 3, 4),
                           (60, 80, 3, 4), (128, 78, 3, 5), (126, -84, 4, 6)]:
        grove(k, c, pines, rng, cx, cy, n, r)
        extra.append(('c', cx, cy, r + 2))
    B.band_clusters(k, c, pines, rng, extra=extra, n=30, spacing=12.0, pine_share=0.7, rock=strata)
    B.wall_drifts(k, c, rng, extra=extra)
    B.field_tufts(k, c, rng)
    B.field_specks(k, c, rng, n=36, mat_=strata)
    return {"landmarks": ["carved King Coldsnout statue with glacier crown (~36 studs incl. plinth) on a three-tier plinth with stairs",
                          "two ivory tusk arches (34 and 28 span) and a frost brazier, right band",
                          "six rune stones with glowing glyphs, front-left", "glacier chunks rear-right, strata ridge rear-left",
                          "14 carved lane markers"]}


OPTIONS = {
    1: ("01", "IGLOO HOLLOW", "igloo-hollow", option_igloo_hollow),
    2: ("02", "ALPINE OUTPOST", "alpine-outpost", option_alpine_outpost),
    3: ("03", "GLACIER FALLS", "glacier-falls", option_glacier_falls),
    4: ("04", "CRYSTAL GROTTO", "crystal-grotto", option_crystal_grotto),
    5: ("05", "COLDSNOUT'S CROWN", "coldsnouts-crown", option_coldsnout_crown),
}

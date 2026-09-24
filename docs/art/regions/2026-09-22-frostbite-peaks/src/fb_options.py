# The five Frostbite Peaks design options. Each builder dresses the same
# MapBuilder cell (fb_base) with its own landmarks, border band and lane
# treatment, and returns a short record of what it placed.
#
# Shared envelope, as in the Cinder / Splashwater / Gusty rebuilds: landmarks
# stay in the side bands (|x| > 92) and the rear/front bands (|y| > 70), the
# 24-wide lane stays clear end to end, and |x| < 36 stays open in front of
# both gates.
import bpy
import bmesh
import math
import random
from mathutils import Vector

import fb_lib as L
import fb_base as B
from fb_lib import rgb, TAU


def face_to(x, y, tx, ty):
    return math.atan2(ty - y, tx - x)


def make_pines(k, seed, green=None, dark=None, snow=None, count=6):
    rng = random.Random(seed)
    out = []
    for i in range(count):
        h = [7.5, 9.5, 11.5, 13.5, 15.5, 17.5][i % 6]
        tiers = 3 if h < 9 else (4 if h < 14 else 5)
        g = (dark or k.pine_dark) if i % 2 else (green or k.pine)
        out.append(L.pine_mesh(k, f"Pine{i}", h, rng.randrange(1 << 30), tiers=tiers, segs=7, green=g, snow=snow,
                               lean=rng.uniform(-0.25, 0.25), fat=rng.uniform(0.92, 1.1)))
    return out


def grove(k, c, pines, rng, cx, cy, n, radius, scale=(0.9, 1.3), extra=(), solid=True):
    """A clump of firs, tallest in the middle."""
    placed = []
    for i in range(n * 8):
        if len(placed) >= n:
            break
        a = rng.uniform(0, TAU)
        d = radius * math.sqrt(rng.random())
        x, y = cx + math.cos(a) * d, cy + math.sin(a) * d
        if abs(x) > B.IN_X - 2.5 or abs(y) > B.IN_Y - 2.5:
            continue
        if any((x - px) ** 2 + (y - py) ** 2 < 16 for px, py in placed):
            continue
        placed.append((x, y))
        s = rng.uniform(*scale) * (1.15 - 0.35 * d / max(radius, 1e-3))
        L.place(rng.choice(pines), "GrovePine", c, (x, y, 0), rot_z=rng.uniform(0, TAU), scale=s, solid=solid)
    return placed


# ------------------------------------------------------------------ frost props
def igloo(k, name, R, loc, facing, c, seed, block_mat, dark_mat, tunnel=True, lantern=True):
    """An igloo laid in real courses of snow blocks, staggered, with an arched
    entrance tunnel and a dark doorway."""
    rng = random.Random(seed)
    bm = L.new_bm()
    lay = L.jit_layer(bm)
    t = max(0.8, R * 0.11)
    g = 0.14
    top = 0.86 * (math.pi / 2)
    rings = 6 if R > 9 else 5

    def hexa(corners_out, corners_in, mi=0):
        o = [bm.verts.new(p) for p in corners_out]
        i_ = [bm.verts.new(p) for p in corners_in]
        fs = [bm.faces.new(o), bm.faces.new(list(reversed(i_)))]
        for a in range(4):
            b = (a + 1) % 4
            fs.append(bm.faces.new((o[b], o[a], i_[a], i_[b])))
        v = rng.uniform(-1, 1)
        for f in fs:
            f[lay] = v
            f.material_index = mi

    def sph(r, p, a):
        return Vector((r * math.cos(p) * math.cos(a), r * math.cos(p) * math.sin(a), r * math.sin(p)))

    half_gap = math.asin(min(0.95, 0.47))
    for i in range(rings):
        p0 = i / rings * top
        p1 = (i + 1) / rings * top
        pm = (p0 + p1) / 2
        n = max(6, round(TAU * R * math.cos(pm) / (R * 0.62)))
        off = (i % 2) * 0.5 + rng.uniform(-0.06, 0.06)
        dp = g / R
        for j in range(n):
            a0 = (j + off) / n * TAU
            a1 = (j + 1 + off) / n * TAU
            am = (a0 + a1) / 2
            if tunnel and i < 2 and abs(math.atan2(math.sin(am), math.cos(am))) < half_gap:
                continue
            da = g / (R * max(0.2, math.cos(pm)))
            q0, q1 = p0 + dp, p1 - dp
            b0, b1 = a0 + da, a1 - da
            outer = [sph(R, q0, b0), sph(R, q0, b1), sph(R, q1, b1), sph(R, q1, b0)]
            inner = [sph(R - t, q0, b0), sph(R - t, q0, b1), sph(R - t, q1, b1), sph(R - t, q1, b0)]
            hexa(outer, inner)
    rc = R * math.cos(top)
    L.add_cyl(bm, rc + 0.25, rc * 0.35, R * 0.07, (0, 0, R * math.sin(top) + R * 0.02), segs=10, mi=0)
    if tunnel:
        rt = 0.44 * R
        x0, x1 = 0.62 * R, 1.3 * R
        nr = 3
        for jj in range(nr):
            xa = x0 + (x1 - x0) * jj / nr + g / 2
            xb = x0 + (x1 - x0) * (jj + 1) / nr - g / 2
            nb = 5
            off = 0.5 * (jj % 2)
            for bb in range(nb):
                be0 = (bb + (off if bb else 0)) / nb * math.pi
                be1 = min(math.pi, (bb + 1 + off) / nb * math.pi) if bb < nb - 1 else math.pi
                if be1 <= be0 + 0.05:
                    continue
                e0, e1 = be0 + g / rt, be1 - g / rt
                outer = [Vector((xa, rt * math.cos(e0), rt * math.sin(e0))), Vector((xb, rt * math.cos(e0), rt * math.sin(e0))),
                         Vector((xb, rt * math.cos(e1), rt * math.sin(e1))), Vector((xa, rt * math.cos(e1), rt * math.sin(e1)))]
                inner = [Vector((v.x, v.y * (rt - t) / rt, v.z * (rt - t) / rt)) for v in outer]
                hexa(outer, inner)
        # the doorway: dark inside the tunnel
        r0 = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=16, radius1=rt - t + 0.05, radius2=rt - t + 0.05,
                                   depth=0.2, matrix=L.xform((0.95 * R, 0, 0), (0, math.pi / 2, 0)))
        for f in L._faces_of(r0['verts']):
            f.material_index = 1
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    ob = L.obj_from_bm(name, bm, [block_mat, dark_mat], c, loc=loc, rot=(0, 0, facing))
    return ob


def snowman(k, name, loc, c, yaw=0.0, scale=1.0, scarf=None, hat=None):
    bm = L.new_bm()
    L.add_sphere(bm, 1.5, (0, 0, 1.3), segs=14, rings=10, mi=0)
    L.add_sphere(bm, 1.08, (0, 0, 3.35), segs=14, rings=10, mi=0)
    L.add_sphere(bm, 0.78, (0, 0, 4.85), segs=14, rings=10, mi=0)
    for s in (-1, 1):
        L.add_sphere(bm, 0.11, (0.66, s * 0.28, 5.05), segs=6, rings=4, mi=1)
    for z in (2.9, 3.4, 3.9):
        L.add_sphere(bm, 0.1, (1.04, 0, z), segs=6, rings=4, mi=1)
    L.add_cyl(bm, 0.14, 0.0, 0.9, (1.15, 0, 4.8), rot=(0, math.pi / 2, 0), segs=6, mi=2)
    for s in (-1, 1):
        L.add_tube(bm, [(0, s * 0.95, 3.6), (0.1, s * 2.0, 4.3), (0.15, s * 2.4, 4.9)], [0.09, 0.07, 0.04], segs=5, mi=3)
    L.add_cyl(bm, 0.86, 0.8, 0.38, (0, 0, 4.2), segs=14, mi=4)
    L.add_box(bm, (0.35, 0.5, 1.2), (0.6, -0.55, 3.7), rot=(0.25, 0.2, 0), mi=4)
    L.add_cyl(bm, 0.82, 0.82, 0.12, (0, 0, 5.52), segs=14, mi=5)
    L.add_cyl(bm, 0.52, 0.5, 0.95, (0, 0, 6.0), segs=14, mi=5)
    mats = [k.snow, k.black, L.mat("carrot", rgb(240, 130, 40), rough=0.6), k.bark,
            scarf or L.mat("scarf", rgb(210, 60, 64), rough=0.7), hat or k.black]
    return L.obj_from_bm(name, bm, mats, c, loc=loc, rot=(0, 0, yaw), scale=(scale,) * 3, smooth=True)


def fire_pit(k, name, loc, c, seed, stones=None):
    rng = random.Random(seed)
    x, y = loc[0], loc[1]
    for i in range(9):
        a = i / 9 * TAU + rng.uniform(-0.1, 0.1)
        L.rock_obj(k, name + "Stone", (1.3, 1.1, 0.9), (x + math.cos(a) * 2.3, y + math.sin(a) * 2.3, 0), rng.randrange(1 << 30), c,
                   rock=stones, subdiv=1, lump=0.15)
    bm = L.new_bm()
    for a in (0.3, 1.9):
        L.add_cyl(bm, 0.28, 0.28, 3.2, (0, 0, 0.35), rot=(math.pi / 2, 0, a), segs=7, mi=0)
    L.add_cyl(bm, 0.9, 0.0, 2.4, (0, 0, 1.5), segs=7, mi=1)
    L.add_cyl(bm, 0.55, 0.0, 1.8, (0.45, 0.3, 1.2), segs=6, mi=2)
    L.add_cyl(bm, 0.5, 0.0, 1.6, (-0.4, -0.3, 1.1), segs=6, mi=2)
    fl = L.mat("flame", rgb(255, 150, 40), emit=9.0, emit_color=rgb(255, 140, 40))
    fl2 = L.mat("flame_core", rgb(255, 220, 110), emit=10.0, emit_color=rgb(255, 214, 110))
    L.obj_from_bm(name, bm, [k.bark, fl, fl2], c, loc=(x, y, 0))
    ld = bpy.data.lights.new(name + "Light", 'POINT')
    ld.energy = 900
    ld.color = (1.0, 0.62, 0.3)
    ld.shadow_soft_size = 1.0
    lo = bpy.data.objects.new(name + "Light", ld)
    lo.location = (x, y, 2.2)
    c.objects.link(lo)


def sled(k, name, loc, yaw, c, deck=None):
    bm = L.new_bm()
    for s in (-1, 1):
        pts = [(-2.2, s * 0.95, 0.12), (1.6, s * 0.95, 0.12), (2.3, s * 0.95, 0.35), (2.5, s * 0.95, 0.85), (2.2, s * 0.95, 1.05)]
        L.add_tube(bm, pts, [0.12] * len(pts), segs=6, mi=0)
        for xx in (-1.4, 0.0, 1.3):
            L.add_box(bm, (0.2, 0.2, 0.6), (xx, s * 0.95, 0.45), mi=0)
    L.add_box(bm, (3.9, 2.2, 0.22), (0, 0, 0.82), mi=1, bevel=0.06)
    L.add_box(bm, (0.25, 2.3, 0.3), (-1.85, 0, 1.05), mi=1)
    L.obj_from_bm(name, bm, [k.iron, deck or L.mat("sled_red", rgb(200, 64, 56), rough=0.5)], c, loc=loc, rot=(0, 0, yaw))


def ice_blocks(k, name, loc, c, seed, n=4, size=2.6, mat_=None):
    rng = random.Random(seed)
    bm = L.new_bm()
    pos = [(0, 0, 0), (size * 1.05, 0.2, 0), (0.5 * size, 0.1, size), (-size * 0.95, 0.4, 0), (0.1, size, 0)]
    for i in range(min(n, len(pos))):
        px, py, pz = pos[i]
        L.add_box(bm, (size, size, size), (px, py, pz + size / 2), rot=(0, 0, rng.uniform(-0.2, 0.2)), mi=0, bevel=0.18, seg=2,
                  rng=rng, jit=True)
    return L.obj_from_bm(name, bm, [mat_ or k.ice_opaque], c, loc=loc, rot=(0, 0, rng.uniform(0, TAU)))


def crystal_mats(name="cyan", color=(140, 226, 255), emit=1.1):
    a = L.mat("crystal_" + name, rgb(*color), rough=0.06, trans=0.55, ior=1.5, emit=emit, emit_color=rgb(*color), spec=0.7)
    light = tuple(min(255, int(v * 0.5 + 255 * 0.5)) for v in color)
    b = L.mat("crystal_" + name + "_pale", rgb(*light), rough=0.06, trans=0.5, ior=1.5, emit=emit * 0.8, emit_color=rgb(*light), spec=0.7)
    return [a, b]


def drift_ring(k, c, x, y, R, rng, n=7):
    for i in range(n):
        a = i / n * TAU + rng.uniform(-0.2, 0.2)
        L.drift_obj(k, "BaseDrift", (rng.uniform(4, 7), rng.uniform(3, 5), rng.uniform(0.7, 1.4)),
                    (x + math.cos(a) * R, y + math.sin(a) * R, 0), rng.randrange(1 << 30), c)


# ================================================================== 01
def option_igloo_hollow(k, c, rng):
    """01 IGLOO HOLLOW - the V4 world's Frostbite, enlarged: two igloo
    clusters in the rear corners with snowy firs behind them, blue ice
    crystals at the front corners, and a packed-snow lane."""
    pines = make_pines(k, 101)
    block = L.mat("igloo_block", rgb(236, 244, 252), rough=0.55, sss=0.12, jitter=0.07)
    dark = L.mat("igloo_dark", rgb(40, 56, 80), rough=0.9)
    cyan = crystal_mats("cyan", (110, 206, 255), 1.6)
    extra = []
    igloos = [
        (-111, 63, 18.0, (-60, 30)),
        (-80, 84, 12.0, (-56, 40)),
        (-125, 22, 9.5, (-80, 10)),
        (110, 60, 17.5, (60, 30)),
        (80, 85, 11.5, (56, 40)),
    ]
    for i, (x, y, R, tgt) in enumerate(igloos):
        f = face_to(x, y, *tgt)
        igloo(k, f"Igloo{i}", R, (x, y, 0), f, c, 700 + i, block, dark)
        drift_ring(k, c, x, y, R * 0.98, rng, n=8 if R > 9 else 6)
        extra.append(('c', x, y, R * 1.35 + 3))
        # a lantern post by each big igloo's door
        if R > 9:
            dx, dy = math.cos(f), math.sin(f)
            px, py = x + dx * R * 1.45 - dy * R * 0.55, y + dy * R * 1.45 + dx * R * 0.55
            L.lantern_post(k, "IglooLantern", (px, py, 0), c, height=5.5)
    fire_pit(k, "FirePit", (-100, 36, 0), c, 51)
    extra.append(('c', -100, 36, 5))
    snowman(k, "Snowman", (101, 34, 0), c, yaw=math.radians(200), scale=1.25)
    extra.append(('c', 101, 34, 4))
    sled(k, "Sled", (97, 73, 0), math.radians(-30), c)
    extra.append(('c', 97, 73, 4))
    ice_blocks(k, "IceBlocks", (125, 88, 0), c, 61, n=5)
    ice_blocks(k, "IceBlocks", (-129, 47, 0), c, 62, n=3, size=2.2)
    extra += [('c', 125, 88, 6), ('c', -129, 47, 5)]
    for i, (x, y, h, n) in enumerate([(-122, -80, 16, 9), (122, -79, 15, 8), (-126, -28, 10, 6), (127, 6, 11, 7),
                                     (-46, 90, 8, 5), (46, 90, 8, 5), (-100, -88, 7, 4), (102, -88, 7, 4)]):
        L.crystal_cluster("IceCrystal", (x, y, 0), 300 + i, c, cyan, count=n, height=h, radius=h * 0.13, spread=h * 0.32,
                          base_mat=k.snow)
        extra.append(('c', x, y, h * 0.5 + 3))
    # firs close behind the igloos and in the corners
    for (cx, cy, n, r) in [(-126, 88, 7, 10), (-104, 94, 4, 5), (126, 86, 7, 10), (104, 95, 4, 5),
                           (-131, 60, 3, 5), (132, 40, 4, 6), (-132, 2, 3, 5), (132, -40, 3, 6)]:
        grove(k, c, pines, rng, cx, cy, n, r)
        extra.append(('c', cx, cy, r + 2))
    B.band_clusters(k, c, pines, rng, extra=extra, n=44, spacing=11.0, pine_share=0.7)
    B.wall_drifts(k, c, rng, extra=extra)
    B.field_tufts(k, c, rng)
    B.field_specks(k, c, rng, n=46)
    return {"landmarks": ["five snow-block igloos (R 18 / 12 / 9.5 left, 17.5 / 11.5 right)", "fire pit", "snowman", "sled",
                          "ice-block stacks", "eight ice-crystal clusters"]}

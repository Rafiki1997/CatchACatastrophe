# The five Thunderworks options. Each builder dresses the shared base
# (tw_base) with the kit (tw_kit) at real coordinates in the cell's own
# frame: +X east, +Y north (Orbit Outpost's gate), studs. Landmarks go in
# the side bands (|x| > 92) and the rear corners; the field (|x| < 92,
# |y| < 70), the 24-wide lane and |x| < 36 before both gates stay open.
#
#   01 TESLA COIL WORKS      the lightning lab
#   02 COPPERLINE SUBSTATION the working power yard
#   03 SPARKLINE SUBSTATION  01 x 02: a substation feeding one colossal coil
#   04 STORMCLIFF DYNAMO     01 x Cliffside Dynamo: coils on a cliff, a dynamo in it
#   05 COPPERLINE RAILYARD   02 x Stormrail Depot: an electric depot and its substation
import math
import random
import bmesh
from mathutils import Vector, Matrix

import tw_lib as L
import tw_geo as G
import tw_base as B
import tw_kit as K
from tw_lib import rgb, TAU

HP = math.pi / 2
FACE_E = HP        # a -Y-fronted asset turned to face east (+X): left band
FACE_W = -HP       # ... to face west (-X): right band
FACE_N = math.pi   # ... to face north


class Ctx:
    def __init__(self, T, c, rng):
        self.T = T
        self.c = c
        self.rng = rng
        self.cache = {}
        self.props = B.load_props_v1()
        self.extra = []
        self.wires = L.new_bm()
        self.copper = L.new_bm()
        self.arcs = []

    def mesh(self, fn, **kw):
        key = (fn.__name__, tuple(sorted(kw.items())))
        if key not in self.cache:
            self.cache[key] = fn(self.T, **kw)
        return self.cache[key]

    def finish(self):
        L.obj_from_bm("Cables", self.wires, [self.T.graphite], self.c, solid=False)
        L.obj_from_bm("CopperFeeders", self.copper, [self.T.copper], self.c, solid=False)


def _xf(p, loc, rot, s):
    x, y, z = p
    c, sn = math.cos(rot), math.sin(rot)
    return (loc[0] + s * (x * c - y * sn), loc[1] + s * (x * sn + y * c), loc[2] + s * z)


def _world_info(info, loc, rot, s):
    out = {}
    for k, v in info.items():
        if isinstance(v, tuple) and len(v) == 3 and all(isinstance(q, (int, float)) for q in v):
            out[k] = _xf(v, loc, rot, s) if k != "size" else v
        elif isinstance(v, list):
            lst = []
            for item in v:
                if isinstance(item, tuple) and len(item) == 2 and isinstance(item[0], str):
                    lst.append((item[0], _xf(item[1], loc, rot, s)))
                elif isinstance(item, tuple) and len(item) == 3:
                    lst.append(_xf(item, loc, rot, s))
                else:
                    lst.append(item)
            out[k] = lst
        elif isinstance(v, tuple) and len(v) == 2 and all(isinstance(q, tuple) for q in v):
            out[k] = tuple(_xf(q, loc, rot, s) for q in v)
        else:
            out[k] = v
    return out


def _footprint(me, loc, rot, s, margin):
    xs, ys = [], []
    for v in me.vertices:
        if v.co.z < 0.3:
            continue
        x, y, _ = _xf((v.co.x, v.co.y, 0.0), loc, rot, s)
        xs.append(x)
        ys.append(y)
    if not xs:
        return None
    return ('r', min(xs) - margin, min(ys) - margin, max(xs) + margin, max(ys) + margin)


def put(ctx, fn, loc, rot=0.0, scale=1.0, solid=True, name=None, margin=2.0, **kw):
    """Place a kit asset; returns its info with anchors in world space and
    registers its footprint so the band scatter keeps off it."""
    me, info = ctx.mesh(fn, **kw)
    loc3 = (loc[0], loc[1], loc[2] if len(loc) > 2 else 0.0)
    L.place(me, name or me.name, ctx.c, loc3, rot_z=rot, scale=scale, solid=solid)
    fp = _footprint(me, loc3, rot, scale, margin)
    if fp:
        ctx.extra.append(fp)
    return _world_info(info, loc3, rot, scale)


def prop(ctx, key, loc, rot=0.0, scale=1.0, solid=True):
    """One of Astra's eight delivered props-v1 meshes."""
    me = ctx.props.get(key)
    if me is None:
        return
    loc3 = (loc[0], loc[1], loc[2] if len(loc) > 2 else 0.0)
    L.place(me, key, ctx.c, loc3, rot_z=rot, scale=scale, solid=solid)
    fp = _footprint(me, loc3, rot, scale, 1.2)
    if fp:
        ctx.extra.append(fp)


def arc(ctx, p0, p1, seed, r=0.4, forks=2, violet=False, jag=0.16):
    K.arc_obj(ctx.T, "Arc", p0, p1, seed, ctx.c, r=r, forks=forks, jag=jag,
              mat_=ctx.T.arc_violet if violet else ctx.T.arc)


def keepout(ctx, x0, y0, x1, y1):
    ctx.extra.append(('r', min(x0, x1), min(y0, y1), max(x0, x1), max(y0, y1)))


def pad(ctx, x0, y0, x1, y1, mat_=None, h=0.14, name="Pad"):
    """A flush slab (gravel bed, concrete apron): walkable, non-solid."""
    L.box_obj(name, (abs(x1 - x0), abs(y1 - y0), h), ((x0 + x1) / 2, (y0 + y1) / 2, h / 2), mat_ or ctx.T.concrete_mid,
              ctx.c, solid=False)


def fence(ctx, pts, h=7.0, sign_every=18.0, sign_side=-1, gate_at=None):
    """Chain-link along a polyline: posts, rails, alpha mesh, barbed top,
    DANGER plates on the `sign_side` face. One object per straight run so
    the clear-floor measure sees thin strips, not their hull."""
    T = ctx.T
    for i in range(len(pts) - 1):
        p0, p1 = Vector((*pts[i], 0.0)), Vector((*pts[i + 1], 0.0))
        d = p1 - p0
        length = d.length
        if length < 0.5:
            continue
        t = d.normalized()
        n = Vector((-t.y, t.x, 0.0)) * sign_side
        bm = L.new_bm()
        posts = max(1, int(math.ceil(length / 8.0)))
        for k in range(posts + 1):
            q = p0 + d * (k / posts)
            G.rod(bm, q, q + Vector((0, 0, h + 0.2)), 0.17, segs=6, mi=0)
            G.beam(bm, q + Vector((0, 0, h)), q + Vector((0, 0, h)) + n * -0.6 + Vector((0, 0, 0.9)), 0.09, mi=0)
        G.rod(bm, p0 + Vector((0, 0, h)), p1 + Vector((0, 0, h)), 0.1, segs=6, mi=0)
        G.rod(bm, p0 + Vector((0, 0, 0.3)), p1 + Vector((0, 0, 0.3)), 0.05, segs=4, mi=0)
        for k in range(3):
            off = n * -(0.2 * (k + 1)) + Vector((0, 0, h + 0.3 * (k + 1)))
            G.rod(bm, p0 + off, p1 + off, 0.03, segs=3, mi=0)
        mid = (p0 + p1) / 2
        ang = math.atan2(t.y, t.x)
        panel = bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation(mid + Vector((0, 0, (h + 0.3) / 2)))
                                      @ Matrix.Rotation(ang, 4, 'Z') @ Matrix.Diagonal((length, 0.05, h - 0.3, 1.0)))
        L._finish(bm, panel['verts'], 1, None, False, 0.0, 1)
        if sign_every:
            ns = max(1, int(length // sign_every))
            for k in range(ns):
                q = p0 + d * ((k + 0.5) / ns) + n * 0.12
                K.sign_plate(bm, (q.x, q.y, 4.4), 1.9, 1.5, 2, 3, 4, rot_z=math.atan2(-n.x, n.y))
        L.obj_from_bm("Fence", bm, [T.steel, T.chainlink, T.white, T.red, T.black], ctx.c, solid=True)


def cable_run(ctx, pts, sag=0.9, r=0.1, copper=False):
    bm = ctx.copper if copper else ctx.wires
    for i in range(len(pts) - 1):
        G.cable(bm, pts[i], pts[i + 1], sag, radius=r, n=14, segs=5)


def floodlights(ctx, spots):
    """Floodlight masts at the field corners, heads turned to the field."""
    for (x, y) in spots:
        put(ctx, K.floodlight, (x, y), rot=math.atan2(-x, y), margin=1.0)


def firewall(ctx, x0, y0, x1, y1, h=11.0):
    L.box_obj("Firewall", (abs(x1 - x0), abs(y1 - y0), h), ((x0 + x1) / 2, (y0 + y1) / 2, h / 2), ctx.T.concrete, ctx.c, bevel=0.1)
    L.box_obj("FirewallCap", (abs(x1 - x0) + 0.4, abs(y1 - y0) + 0.4, 0.5), ((x0 + x1) / 2, (y0 + y1) / 2, h + 0.25),
              ctx.T.concrete_dk, ctx.c, bevel=0.05)
    keepout(ctx, x0 - 1, y0 - 1, x1 + 1, y1 + 1)


def scatter(ctx, n=34, clutter_share=0.18, rock_share=0.5):
    T = ctx.T

    def clutter(x, y, rng):
        choice = rng.random()
        if choice < 0.45:
            put(ctx, K.yard_clutter, (x, y), rot=rng.uniform(0, TAU), solid=True, margin=1.0)
        elif choice < 0.7 and ctx.props:
            prop(ctx, "TW_Cable_Reel", (x, y), rot=rng.uniform(0, TAU))
        elif choice < 0.85 and ctx.props:
            prop(ctx, "TW_Vent_Housing", (x, y), rot=rng.uniform(0, TAU))
        else:
            put(ctx, K.barrier_block, (x, y), rot=rng.uniform(0, TAU), margin=1.0)
    B.band_scatter(T, ctx.c, ctx.rng, extra=ctx.extra, n=n, rock_share=rock_share, clutter=clutter,
                   clutter_share=clutter_share)


# ------------------------------------------------------------------ dressing
_PINES = {}


def pines(ctx):
    if not _PINES.get(id(ctx)):
        T = ctx.T
        _PINES[id(ctx)] = [B.fir_mesh("YardPine%d" % i, 13 + 3.5 * i, 1500 + i, T.pine, T.pine_dk, T.bark, fat=0.9 + 0.05 * i)
                           for i in range(4)]
    return _PINES[id(ctx)]


def pine_cluster(ctx, x, y, n=5, spread=7.0, smin=0.8, smax=1.35, clip=True):
    """A clump of dark pines: the old yard has grown over at its edges."""
    rng = ctx.rng
    ms = pines(ctx)
    placed = []
    for i in range(n * 4):
        if len(placed) >= n:
            break
        a = rng.uniform(0, TAU)
        d = rng.uniform(0, spread)
        px, py = x + math.cos(a) * d, y + math.sin(a) * d
        if clip and not B.keep_clear(px, py, ctx.extra):
            continue
        if abs(px) > B.IN_X - 3 or abs(py) > B.IN_Y - 3:
            continue
        if any((px - qx) ** 2 + (py - qy) ** 2 < 4.5 ** 2 for qx, qy in placed):
            continue
        placed.append((px, py))
        L.place(rng.choice(ms), "YardPine", ctx.c, (px, py, 0), rot_z=rng.uniform(0, TAU), scale=rng.uniform(smin, smax))
    for (px, py) in placed:
        ctx.extra.append(('c', px, py, 3.5))
    return placed


def pine_row(ctx, x, y0, y1, step=7.0, jitter=2.0, smin=0.9, smax=1.4):
    rng = ctx.rng
    y = min(y0, y1)
    while y < max(y0, y1):
        pine_cluster(ctx, x + rng.uniform(-jitter, jitter), y, n=rng.randint(1, 3), spread=3.0, smin=smin, smax=smax)
        y += step * rng.uniform(0.8, 1.2)


def prop_row(ctx, key, p0, p1, n, rot=0.0, scale=1.0, jitter=0.0):
    rng = ctx.rng
    for i in range(n):
        t = (i + 0.5) / n
        x = p0[0] + (p1[0] - p0[0]) * t + rng.uniform(-jitter, jitter)
        y = p0[1] + (p1[1] - p0[1]) * t + rng.uniform(-jitter, jitter)
        prop(ctx, key, (x, y), rot=rot, scale=scale)


def rock_pile(ctx, x, y, n=3, size=5.0):
    T, rng = ctx.T, ctx.rng

    class _K:
        pass
    kk = _K()
    kk.rock, kk.snow = T.rock, T.moss
    for i in range(n):
        a = rng.uniform(0, TAU)
        d = rng.uniform(0, size * 0.6)
        h = size * rng.uniform(0.45, 0.9)
        L.rock_obj(kk, "YardRock", (h * rng.uniform(1.2, 1.6), h * rng.uniform(1.0, 1.3), h), (x + math.cos(a) * d, y + math.sin(a) * d, 0),
                   rng.randrange(1 << 30), ctx.c, rock=T.rock if i % 2 else T.rock_dk, snow=T.moss, thresh=0.85, lump=0.24)
    ctx.extra.append(('c', x, y, size))


def tufts(ctx, x0, y0, x1, y1, n):
    """Heath grass in the cracks of a band rectangle."""
    rng = ctx.rng
    ms = [B.tuft_mesh(ctx.T, "BandTuft%d" % i, 90 + i) for i in range(3)]
    for i in range(n):
        x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
        if not B.keep_clear(x, y, ctx.extra):
            continue
        L.place(rng.choice(ms), "Tuft", ctx.c, (x, y, 0), rot_z=rng.uniform(0, TAU), scale=rng.uniform(0.9, 1.6), solid=False)


def puddles(ctx, spots):
    """Rain puddles on the band aprons: flush, glossy, catch the sky."""
    water = L.mat("tw_puddle", rgb(70, 80, 100), rough=0.03, coat=1.0, spec=0.9)
    for (x, y, sx, sy) in spots:
        bm = L.new_bm()
        L.add_cyl(bm, 1.0, 1.0, 0.02, (0, 0, 0.16), segs=24, scale=(sx, sy, 1))
        L.obj_from_bm("Puddle", bm, [water], ctx.c, loc=(x, y, 0), rot=(0, 0, ctx.rng.uniform(0, TAU)), solid=False)


def fill_edges(ctx, step=6.0, inset=(3.5, 11.0), pine_share=0.72, gate_gap=40.0):
    """Close every gap left along the inside of the walls with pine clumps
    and rock piles, the way the Frostbite bands are dressed. The front band
    only gets small pines, and only towards its corners, so it never hides
    the field."""
    rng = ctx.rng

    def try_at(x, y):
        if not B.keep_clear(x, y, ctx.extra):
            return
        front = y < -B.HALF_D + 30
        if front and abs(x) < 56:
            return
        if rng.random() < pine_share:
            if front:
                pine_cluster(ctx, x, y, n=rng.randint(1, 3), spread=3.5, smin=0.55, smax=0.8)
            else:
                pine_cluster(ctx, x, y, n=rng.randint(2, 4), spread=4.5, smin=0.8, smax=1.4)
        else:
            rock_pile(ctx, x, y, n=rng.randint(2, 3), size=rng.uniform(3.0, 4.5) if front else rng.uniform(3.5, 6.5))

    for s in (-1, 1):
        y = -B.IN_Y + 3
        while y < B.IN_Y - 3:
            try_at(s * (B.IN_X - rng.uniform(*inset)), y)
            y += step * rng.uniform(0.7, 1.3)
    for s in (-1, 1):
        x = -B.IN_X + 3
        while x < B.IN_X - 3:
            if abs(x) > gate_gap:
                try_at(x, s * (B.IN_Y - rng.uniform(*inset)))
            x += step * rng.uniform(0.7, 1.3)


def coil_arcs(ctx, coil, targets, seed, spare=((0.7, 0.7, -12.0), (-0.9, -0.5, -9.0)), r=1.0):
    """Arcs from a coil's toroid rim to each target point, plus loose arcs
    that fork off sideways and down (never up, out of the frame)."""
    tx, ty, tz = coil["toroid"]
    R = coil["toroid_R"] + coil["toroid_r"] * 0.6
    for i, p in enumerate(targets):
        d = Vector((p[0] - tx, p[1] - ty, 0.0))
        d = d.normalized() if d.length > 1e-3 else Vector((1, 0, 0))
        arc(ctx, (tx + d.x * R, ty + d.y * R, tz + 0.6), p, seed + i, r=r, forks=3)
    for j, (dx, dy, dz) in enumerate(spare):
        d = Vector((dx, dy, 0.0)).normalized()
        p0 = (tx + d.x * R, ty + d.y * R, tz + 0.4)
        p1 = (tx + d.x * (R + 13), ty + d.y * (R + 13), tz + dz)
        arc(ctx, p0, p1, seed + 10 + j, r=r * 0.75, forks=2)


def busbar_row(ctx, x0, x1, y, step=6.5, scale=1.5):
    """Post insulators in a row carrying a copper tube bus."""
    x = x0
    tops = []
    while x <= x1 + 1e-6:
        prop(ctx, "TW_Ceramic_Insulator", (x, y), scale=scale)
        tops.append((x, y, 3.0 * scale + 0.2))
        x += step
    for i in range(len(tops) - 1):
        G.rod(ctx.copper, tops[i], tops[i + 1], 0.22, segs=8)


# =================================================================== 01
def opt_tesla(ctx):
    """TESLA COIL WORKS: two giant coils in the rear corners throwing arcs
    at catch masts, a brick dynamo hall down the west band, a lightning lab
    of Leyden racks, a storm bell jar, spark gaps and a workshop down the
    east band; pines have grown in along the walls."""
    T, rng = ctx.T, ctx.rng
    pad(ctx, -138.5, 70, -42, 98.5, T.concrete_mid, name="CoilYardW")
    pad(ctx, 42, 70, 138.5, 98.5, T.concrete_mid, name="CoilYardE")
    pad(ctx, -106, -50, -93, 26, T.concrete_mid, name="HallApron")
    pad(ctx, 99, -68, 138.5, 54, T.gravel, name="LabGravel")
    pad(ctx, 106, -28, 136, 18, T.concrete, h=0.5, name="LabDeck")
    ca = put(ctx, K.tesla_coil, (-108, 82), h=58.0)
    cb = put(ctx, K.tesla_coil, (110, 83), h=52.0)
    ma = put(ctx, K.collector_mast, (-68, 90), h=26.0)
    mb = put(ctx, K.collector_mast, (70, 90), h=24.0)
    coil_arcs(ctx, ca, [ma["crown"]], 11, spare=((-0.2, -1.0, -10.0), (-1.0, 0.3, -13.0), (0.7, -0.8, -16.0)))
    coil_arcs(ctx, cb, [mb["crown"]], 21, spare=((0.2, -1.0, -10.0), (1.0, 0.3, -12.0), (-0.6, -0.9, -17.0)))
    # the dynamo hall down the west band, doors facing the field
    put(ctx, K.dynamo_hall, (-121.5, -12), rot=FACE_E)
    prop_row(ctx, "TW_Transformer", (-99, 32), (-99, 60), 3, rot=FACE_E, scale=1.3)
    prop_row(ctx, "TW_Switch_Cabinet", (-99, -58), (-99, -44), 3, rot=FACE_E, scale=1.25)
    for y in (28.0, 42.0, 56.0):
        put(ctx, K.cable_tray, (-133, y), rot=HP, margin=1.0)
    put(ctx, K.yard_clutter, (-100, 18), rot=HP)
    prop(ctx, "TW_Transformer", (-88, 78), rot=0.0, scale=1.3)
    prop(ctx, "TW_Capacitor_Bank", (-80, 76), scale=1.3)
    prop(ctx, "TW_Capacitor_Bank", (-56, 78), scale=1.3)
    # the lab down the east band
    put(ctx, K.storm_jar, (116, 38), scale=2.2)
    for y in (12.0, 1.0, -10.0, -21.0):
        put(ctx, K.leyden_rack, (121, y, 0.5), rot=0.0, scale=1.3, margin=0.5)
    for k, y in enumerate((-40.0, -56.0)):
        sg = put(ctx, K.spark_gap, (119, y), rot=0.0, scale=1.4)
        a_, b_ = sg["gap"]
        arc(ctx, a_, b_, 31 + k, r=0.7, forks=1, jag=0.22)
    put(ctx, K.barrel_workshop, (123, 63), rot=FACE_W, scale=1.15)
    prop_row(ctx, "TW_Capacitor_Bank", (103, -26), (103, 16), 5, scale=1.25)
    cable_run(ctx, [(135, -60, 10.0), (135, -20, 10.0), (135, 20, 10.0), (128, 72, 12.0)], sag=0.9, r=0.22, copper=True)
    for y in (-60.0, -20.0, 20.0):
        G.insulator_stack(ctx.copper, (135, y, 0), 10, 0.45, 0.32, 1.0)
    prop(ctx, "TW_Transformer", (88, 78), rot=0.0, scale=1.3)
    prop(ctx, "TW_Capacitor_Bank", (58, 78), scale=1.3)
    # front band: low stuff only
    prop_row(ctx, "TW_Cable_Reel", (-118, -90), (-64, -90), 5, rot=0.3, jitter=1.5, scale=1.2)
    prop_row(ctx, "TW_Cable_Reel", (64, -90), (96, -90), 3, rot=-0.3, jitter=1.5, scale=1.2)
    put(ctx, K.yard_clutter, (-86, -79), rot=0.2)
    put(ctx, K.yard_clutter, (84, -79), rot=-0.2)
    floodlights(ctx, [(-96, -73), (96, -73), (-96, 60), (96, 60)])
    puddles(ctx, [(-100, -30, 3, 1.8), (104, 50, 2.6, 1.6), (-60, 74, 3.4, 2.0), (60, 72, 2.4, 1.5)])
    fill_edges(ctx)
    tufts(ctx, -138, -98, 138, 98, 320)
    scatter(ctx, n=12, clutter_share=0.1)
    return {}


# =================================================================== 02
def opt_substation(ctx):
    """COPPERLINE SUBSTATION: the transmission line on the heath drops into a
    fenced gantry switchyard across the rear-left; two lightning collector
    masts and an accumulator bank hold the rear-right; the brick switch
    house and a second bank sit down the west band; three transformer bays
    stand behind a fence down the east band."""
    T, rng = ctx.T, ctx.rng
    # rear-left switchyard
    pad(ctx, -138.5, 70, -42, 98.5, T.gravel, name="SwitchyardGravel")
    strings = []
    for x in (-116.0, -88.0, -60.0):
        g = put(ctx, K.gantry, (x, 91), span=26.0, h=22.0, strings=(-8.5, 0.0, 8.5), margin=1.0)
        strings.append([p for lab, p in g["ends"] if lab == "string"])
        put(ctx, K.circuit_breaker, (x, 82), scale=1.3, margin=0.6)
    # the incoming line: from the heath pylon at (-158, 90) over the wall
    feeds = [(-150.2, 90.0, 21.6), (-151.7, 90.0, 29.6), (-164.3, 90.0, 29.6)]
    for k in range(3):
        cable_run(ctx, [feeds[k]] + [s[k] for s in strings], sag=1.2, r=0.13)
    busbar_row(ctx, -132.0, -46.0, 75.0)
    fence(ctx, [(-138.5, 70.4), (-42.0, 70.4), (-42.0, 98.5)], sign_side=-1)
    # rear-right collectors
    pad(ctx, 56, 70, 138.5, 98.5, T.gravel, name="CollectorGravel")
    put(ctx, K.collector_mast, (104, 85), h=40.0)
    put(ctx, K.collector_mast, (128, 71), h=34.0)
    put(ctx, K.battery_bank, (76, 86), scale=1.3)
    prop_row(ctx, "TW_Capacitor_Bank", (60, 72), (92, 72), 4, scale=1.3)
    prop(ctx, "TW_Transformer", (122, 90), rot=FACE_W, scale=1.3)
    # west band: the switch house, a second bank, poles to the front
    pad(ctx, -112, -40, -93, 36, T.concrete_mid, name="HouseApron")
    put(ctx, K.switch_house, (-121, 16), rot=FACE_E, scale=1.55)
    put(ctx, K.battery_bank, (-123, -26), rot=FACE_E, scale=1.35)
    put(ctx, K.barrel_workshop, (-122, -66), rot=FACE_E, scale=1.3)
    prop_row(ctx, "TW_Cable_Reel", (-104, -78), (-104, -56), 3, rot=HP, scale=1.3)
    prop_row(ctx, "TW_Switch_Cabinet", (-104, -12), (-104, 0), 3, rot=FACE_E, scale=1.25)
    prop_row(ctx, "TW_Vent_Housing", (-104, 40), (-104, 56), 2, rot=FACE_E, scale=1.3)
    poles = [put(ctx, K.utility_pole, (-97, y), rot=HP, margin=1.0) for y in (-44.0, -90.0)]
    for k in range(3):
        cable_run(ctx, [p["tips"][k] for p in poles], sag=1.4, r=0.09)
    # east band: three transformer bays behind a fence, doors to the field
    pad(ctx, 99, -68, 138.5, 32, T.gravel, name="BayGravel")
    for y in (-50.0, -22.0, 6.0):
        put(ctx, K.power_transformer, (121, y), rot=FACE_W, scale=1.35, margin=0.8)
    for y in (-64.0, -36.0, -8.0, 20.0):
        firewall(ctx, 110, y - 0.7, 132, y + 0.7, h=13.0)
    fence(ctx, [(138.5, 32.0), (100.0, 32.0), (100.0, -68.0), (138.5, -68.0)], sign_side=1)
    put(ctx, K.floodlight, (97, -18), rot=math.atan2(-97, -18), margin=1.0)
    # front band
    prop_row(ctx, "TW_Cable_Reel", (68, -90), (110, -90), 4, rot=0.4, jitter=1.5, scale=1.2)
    put(ctx, K.barrier_block, (-60, -88), rot=0.0)
    put(ctx, K.barrier_block, (60, -84), rot=0.0)
    put(ctx, K.yard_clutter, (-120, -88), rot=0.3)
    floodlights(ctx, [(-96, -73), (96, -73), (-96, 60)])
    puddles(ctx, [(-104, -30, 3, 1.8), (-80, 68, 2.8, 1.6), (108, 42, 2.4, 1.5)])
    fill_edges(ctx)
    tufts(ctx, -138, -98, 138, 98, 300)
    scatter(ctx, n=12, clutter_share=0.2)
    return {}


# =================================================================== 03
def opt_sparkline(ctx):
    """SPARKLINE SUBSTATION (01 x 02): the substation's gantries, bays and
    switch house fill the west side and feed one colossal Tesla coil in the
    rear-right corner, whose bolts two collector masts catch; bottled
    lightning, a storm jar and an accumulator bank line the east band."""
    T, rng = ctx.T, ctx.rng
    pad(ctx, 42, 70, 138.5, 98.5, T.concrete_mid, name="CoilYard")
    coil = put(ctx, K.tesla_coil, (110, 83), h=60.0)
    m1 = put(ctx, K.collector_mast, (68, 90), h=34.0)
    m2 = put(ctx, K.collector_mast, (129, 48), h=32.0)
    coil_arcs(ctx, coil, [m1["crown"], m2["crown"]], 41, spare=((1.0, 0.4, -14.0), (-0.5, -1.0, -18.0)), r=1.1)
    prop_row(ctx, "TW_Capacitor_Bank", (50, 74), (86, 74), 4, scale=1.3)
    # west: switchyard across the rear-left, fed off the heath line
    pad(ctx, -138.5, 70, -46, 98.5, T.gravel, name="SwitchyardGravel")
    strings = []
    for x in (-112.0, -80.0):
        g = put(ctx, K.gantry, (x, 91), span=26.0, h=22.0, strings=(-8.5, 0.0, 8.5), margin=1.0)
        strings.append([p for lab, p in g["ends"] if lab == "string"])
        put(ctx, K.circuit_breaker, (x, 82), scale=1.3, margin=0.6)
    feeds = [(-150.2, 90.0, 21.6), (-151.7, 90.0, 29.6), (-164.3, 90.0, 29.6)]
    for k in range(3):
        cable_run(ctx, [feeds[k]] + [s[k] for s in strings], sag=1.2, r=0.13)
    busbar_row(ctx, -132.0, -54.0, 75.0)
    fence(ctx, [(-138.5, 70.4), (-46.0, 70.4), (-46.0, 98.5)], sign_side=-1)
    # west band: two transformer bays and the switch house
    pad(ctx, -138.5, 0, -99, 62, T.gravel, name="BayGravel")
    for y in (46.0, 18.0):
        put(ctx, K.power_transformer, (-121, y), rot=FACE_E, scale=1.35, margin=0.8)
    for y in (60.0, 32.0, 4.0):
        firewall(ctx, -132, y - 0.7, -110, y + 0.7, h=13.0)
    fence(ctx, [(-138.5, 0.0), (-100.0, 0.0), (-100.0, 62.0), (-138.5, 62.0)], sign_side=1)
    pad(ctx, -112, -46, -93, -8, T.concrete_mid, name="HouseApron")
    put(ctx, K.switch_house, (-122, -28), rot=FACE_E, scale=1.3)
    prop_row(ctx, "TW_Switch_Cabinet", (-104, -60), (-104, -48), 3, rot=FACE_E, scale=1.25)
    # east band: the lab that stores the coil's charge
    pad(ctx, 99, -66, 138.5, 40, T.gravel, name="LabGravel")
    pad(ctx, 106, -30, 136, 8, T.concrete, h=0.5, name="LabDeck")
    put(ctx, K.storm_jar, (117, 24), scale=1.75)
    for y in (0.0, -11.0, -22.0):
        put(ctx, K.leyden_rack, (121, y, 0.5), rot=0.0, scale=1.3, margin=0.5)
    put(ctx, K.battery_bank, (120, -48), rot=0.0, scale=1.3)
    cable_run(ctx, [(135, -56, 10.0), (135, -16, 10.0), (135, 26, 10.0), (128, 72, 12.0)], sag=0.9, r=0.22, copper=True)
    for y in (-56.0, -16.0, 26.0):
        G.insulator_stack(ctx.copper, (135, y, 0), 10, 0.45, 0.32, 1.0)
    prop_row(ctx, "TW_Capacitor_Bank", (103, -26), (103, 6), 4, scale=1.25)
    # front band
    prop_row(ctx, "TW_Cable_Reel", (64, -90), (104, -90), 4, rot=0.2, jitter=1.5, scale=1.2)
    put(ctx, K.yard_clutter, (-116, -86), rot=0.3)
    put(ctx, K.barrier_block, (-66, -88), rot=0.0)
    floodlights(ctx, [(-96, -73), (96, -73), (96, 58)])
    puddles(ctx, [(-104, -60, 3, 1.8), (60, 70, 2.6, 1.6), (104, 44, 2.4, 1.5)])
    fill_edges(ctx)
    tufts(ctx, -138, -98, 138, 98, 300)
    scatter(ctx, n=12, clutter_share=0.15)
    return {}


# =================================================================== 04
def _cliff(ctx, x0, x1, y0, y1, hmin, hmax, seed, tiers=2, step=9.0):
    """A layered slate cliff filling a band rectangle: a row of stacked
    strata blocks with a mossy top on each."""
    T = ctx.T
    rng = random.Random(seed)

    class _K:
        pass
    kk = _K()
    kk.rock, kk.snow = T.strata, T.moss
    along_x = abs(x1 - x0) >= abs(y1 - y0)
    a0, a1 = (x0, x1) if along_x else (y0, y1)
    t = min(a0, a1)
    end = max(a0, a1)
    ledges = []
    while t < end - 1.0:
        w = rng.uniform(step * 0.8, step * 1.3)
        c = t + w / 2
        h = rng.uniform(hmin, hmax)
        deep = abs(y1 - y0) if along_x else abs(x1 - x0)
        if along_x:
            cx, cy = c, (y0 + y1) / 2 + rng.uniform(-1.5, 1.5)
            size = (w * 1.25, deep * 1.02, h)
        else:
            cx, cy = (x0 + x1) / 2 + rng.uniform(-1.5, 1.5), c
            size = (deep * 1.02, w * 1.25, h)
        top_mat = T.moss if rng.random() < 0.55 else T.rock
        L.rock_obj(kk, "CliffBlock", size, (cx, cy, 0), rng.randrange(1 << 30), ctx.c, rock=T.strata, snow=top_mat,
                   thresh=0.8, shape='box', lump=0.14, rot_z=rng.uniform(-0.08, 0.08), sink=0.05)
        ledges.append((cx, cy, size[0], size[1], 0.93 * h, top_mat is T.moss))
        if tiers > 1 and rng.random() < 0.8:
            s2 = (size[0] * 0.7, size[1] * 0.6, h * rng.uniform(0.35, 0.55))
            ox = rng.uniform(-1.5, 1.5)
            if along_x:
                at = (cx + ox, cy + (size[1] * 0.18 if cy > 0 else -size[1] * 0.18), h * 0.9)
            else:
                at = (cx + (size[0] * 0.18 if cx > 0 else -size[0] * 0.18), cy + ox, h * 0.9)
            L.rock_obj(kk, "CliffTop", s2, at, rng.randrange(1 << 30), ctx.c, rock=T.strata, snow=T.moss, thresh=0.8,
                       shape='box', lump=0.16, sink=0.05)
        t += w
    # pines on the mossy ledges, so the cliff reads as wooded rock
    ms = pines(ctx)
    for (cx, cy, sx, sy, zt, mossy) in ledges:
        if not mossy:
            continue
        for k in range(rng.randint(1, 3)):
            px = cx + rng.uniform(-0.32, 0.32) * sx
            py = cy + rng.uniform(-0.32, 0.32) * sy
            L.place(rng.choice(ms), "LedgePine", ctx.c, (px, py, zt - 0.4), rot_z=rng.uniform(0, TAU),
                    scale=rng.uniform(0.55, 0.9), solid=False)
    keepout(ctx, min(x0, x1) - 2, min(y0, y1) - 2, max(x0, x1) + 2, max(y0, y1) + 2)


def _mesa(ctx, outline, z_top, name="CoilMesa"):
    """A flat-topped strata block for the coils to stand on."""
    T = ctx.T
    bm = L.new_bm()
    fs = L.add_prism(bm, outline, 0.0, z_top, mi=0)
    bm.normal_update()
    for f in fs:
        if f.normal.z > 0.9:
            f.material_index = 1
    L.obj_from_bm(name, bm, [T.strata, T.moss], ctx.c, solid=True)
    xs = [p[0] for p in outline]
    ys = [p[1] for p in outline]
    keepout(ctx, min(xs) - 2, min(ys) - 2, max(xs) + 2, max(ys) + 2)


def _stairs(ctx, x, y0, y1, z_top, width=4.0):
    """A steel stair up the cliff face with stringers and handrails."""
    T = ctx.T
    bm = L.new_bm()
    n = max(4, int(z_top / 0.7))
    run = (y1 - y0) / n
    for i in range(n):
        z = (i + 1) * z_top / n
        L.add_box(bm, (width, abs(run) * 1.05, 0.25), (x, y0 + (i + 0.5) * run, z - 0.12), mi=0)
    for s in (-1, 1):
        G.beam(bm, (x + s * width / 2, y0, 0.0), (x + s * width / 2, y1, z_top), 0.35, mi=1)
        G.beam(bm, (x + s * width / 2, y0, 3.4), (x + s * width / 2, y1, z_top + 3.4), 0.14, mi=2)
        for i in range(0, n, 4):
            z = (i + 1) * z_top / n
            G.beam(bm, (x + s * width / 2, y0 + (i + 0.5) * run, z), (x + s * width / 2, y0 + (i + 0.5) * run, z + 3.4), 0.12, mi=2)
    L.obj_from_bm("CliffStair", bm, [T.steel_dk, T.graphite, T.yellow_worn], ctx.c, solid=True)
    keepout(ctx, x - width, min(y0, y1) - 1, x + width, max(y0, y1) + 1)


def opt_stormcliff(ctx):
    """STORMCLIFF DYNAMO (01 x Cliffside Dynamo): a layered slate cliff wraps
    the rear corners; the giant dynamo sits in a lit cut in the west cliff
    with a stair up beside it; two Tesla coils on the east mesa bridge a
    spark between them; barrel-roof workshops line the east band."""
    T, rng = ctx.T, ctx.rng
    _cliff(ctx, -138, -120, 74, 98, 18, 24, 501)
    _cliff(ctx, -88, -42, 76, 98, 14, 20, 502)
    _cliff(ctx, -138, -114, 16, 74, 10, 20, 503)
    _cliff(ctx, 42, 94, 76, 98, 13, 19, 504)
    _cliff(ctx, 114, 138, 24, 70, 9, 16, 505)
    # the dynamo cut: a dark back wall with warm lamps, the drum in front
    L.box_obj("CutBack", (32, 3, 20), (-104, 96.5, 10), T.rock_dk, ctx.c, bevel=0.3)
    for x in (-116.0, -92.0):
        L.box_obj("CutLamp", (1.2, 0.8, 1.0), (x, 94.6, 14.0), T.lamp, ctx.c, solid=False)
    pad(ctx, -120, 70, -88, 98.5, T.concrete_mid, name="DynamoFloor")
    put(ctx, K.dynamo_drum, (-104, 84.5), margin=1.0)
    _stairs(ctx, -84.0, 71.0, 89.0, 15.0)
    bm = L.new_bm()
    L.add_tube(bm, [(-122, 76, 0.5), (-122, 76, 12), (-121, 80, 16), (-110, 94, 19), (-96, 94, 19), (-86, 88, 17)],
               [0.55] * 6, segs=10)
    L.add_tube(bm, [(-86, 72, 0.5), (-86, 72, 8), (-88, 76, 12), (-94, 90, 14)], [0.45] * 4, segs=10)
    L.obj_from_bm("CopperPipe", bm, [T.copper], ctx.c, solid=False)
    prop(ctx, "TW_Transformer", (-100, 64), rot=0.0, scale=1.3)
    prop(ctx, "TW_Switch_Cabinet", (-110, 66), rot=0.0, scale=1.25)
    # the east mesa with its two coils and the spark bridge between them
    outline = [(98.0, 73.0), (137.0, 72.0), (138.4, 98.0), (96.0, 98.0), (94.5, 86.0)]
    ztop = 17.0
    _mesa(ctx, outline, ztop)
    c1 = put(ctx, K.tesla_coil, (106, 86, ztop), h=32.0, margin=0.5)
    c2 = put(ctx, K.tesla_coil, (128, 86, ztop), h=32.0, margin=0.5)
    t1, t2 = c1["toroid"], c2["toroid"]
    R = c1["toroid_R"] + c1["toroid_r"] * 0.7
    arc(ctx, (t1[0] + R, t1[1], t1[2] + 0.4), (t2[0] - R, t2[1], t2[2] + 0.4), 61, r=0.9, forks=3, jag=0.2)
    arc(ctx, (t1[0] - R * 0.6, t1[1] - R * 0.7, t1[2]), (t1[0] - R - 11, t1[1] - R - 6, t1[2] - 13), 62, r=0.45, forks=2)
    arc(ctx, (t2[0] + 1.0, t2[1] - R, t2[2]), (t2[0] + 3, t2[1] - R - 13, t2[2] - 6), 63, r=0.4, forks=2)
    _stairs(ctx, 99.0, 52.0, 72.5, ztop)
    # east band: two workshops, a spark gap, reels
    pad(ctx, 100, -62, 136, 22, T.concrete_mid, name="WorkshopApron")
    put(ctx, K.barrel_workshop, (122, 8), rot=FACE_W, scale=1.2)
    put(ctx, K.barrel_workshop, (122, -22), rot=FACE_W, scale=1.2)
    sg = put(ctx, K.spark_gap, (116, -50), rot=0.0, scale=1.35)
    a_, b_ = sg["gap"]
    arc(ctx, a_, b_, 64, r=0.7, forks=1, jag=0.22)
    prop(ctx, "TW_Cable_Reel", (104, 14), rot=0.3, scale=1.4)
    prop(ctx, "TW_Cable_Reel", (104, 2), rot=-0.2, scale=1.4)
    prop(ctx, "TW_Switch_Cabinet", (104, -30), rot=FACE_W, scale=1.25)
    prop(ctx, "TW_Capacitor_Bank", (104, -38), scale=1.25)
    # west band below the cliff: a spark gap and the dynamo's switchgear
    pad(ctx, -120, -40, -98, 8, T.concrete_mid, name="GapPad")
    sg2 = put(ctx, K.spark_gap, (-112, -8), rot=HP, scale=1.3)
    a_, b_ = sg2["gap"]
    arc(ctx, a_, b_, 65, r=0.65, forks=1, jag=0.22)
    prop_row(ctx, "TW_Capacitor_Bank", (-102, -34), (-102, -20), 3, scale=1.25)
    for y in (-50.0, -64.0):
        put(ctx, K.cable_tray, (-131, y), rot=HP, margin=1.0)
    floodlights(ctx, [(-96, -73), (96, -73)])
    put(ctx, K.yard_clutter, (-118, -86), rot=0.4)
    put(ctx, K.yard_clutter, (116, -84), rot=-0.3)
    puddles(ctx, [(-100, 60, 2.6, 1.6), (104, -8, 2.4, 1.5)])
    fill_edges(ctx, pine_share=0.62)
    tufts(ctx, -138, -98, 138, 98, 300)
    scatter(ctx, n=14, clutter_share=0.1, rock_share=0.62)
    return {}


# =================================================================== 05
def _flatcar(ctx, loc, name="Flatcar"):
    T = ctx.T
    bm = L.new_bm()
    x, y = loc
    for sb in (-1, 1):
        L.add_box(bm, (4.2, 4.0, 0.9), (x, y + sb * 6.0, 1.6), mi=0)
        for k in (-1.2, 1.2):
            for sx in (-1, 1):
                L.add_cyl(bm, 1.1, 1.1, 0.4, (x + sx * 2.3, y + sb * 6.0 + k, 1.1), rot=(0, HP, 0), segs=16, mi=0)
    L.add_box(bm, (5.4, 17.0, 0.8), (x, y, 2.5), mi=1)
    for sx in (-1, 1):
        L.add_box(bm, (0.3, 17.0, 0.5), (x + sx * 2.6, y, 3.1), mi=0)
    L.obj_from_bm(name, bm, [T.graphite, T.teal_dk], ctx.c, solid=True)
    keepout(ctx, x - 4, y - 10, x + 4, y + 10)


def opt_railyard(ctx):
    """COPPERLINE RAILYARD (02 x Stormrail Depot): a Stormrail engine
    half out of its barrel-vaulted shed on the west track under catenary,
    a siding with a flatcar of cable, and on the east side the substation
    that powers the line, a switch house and the bolt water tower."""
    T, rng = ctx.T, ctx.rng
    # west: main line, shed, engine, catenary
    put(ctx, K.rails, (-124, 6), length=172.0, buffer_end=1, margin=0.5)
    put(ctx, K.engine_shed, (-124, 64), length=40.0, margin=0.5)
    put(ctx, K.locomotive, (-124, 33, 0.99), margin=0.5)
    masts = []
    for y in (-70.0, -48.0, -26.0, -4.0, 18.0):
        m = put(ctx, K.catenary_mast, (-135.0, y), reach=11.0, h=19.2, margin=0.5)
        masts.append(m["wire"])
    wire_z = masts[0][2]
    cable_run(ctx, [(-124.0, -80.0, wire_z)] + [(-124.0, p[1], wire_z) for p in masts] + [(-124.0, 84.0, wire_z)], sag=0.4, r=0.08)
    # keep the strip between the main line and the wall open, so the
    # catenary masts read
    keepout(ctx, -138.5, -82.0, -119.0, 46.0)
    # the siding with a flatcar carrying a giant cable drum, and a platform
    put(ctx, K.rails, (-108, -42), length=80.0, buffer_end=-1, margin=0.5, name="Siding")
    put(ctx, K.flatcar, (-108, -30, 0.99), margin=1.0)
    pad(ctx, -103, -80, -95, -2, T.concrete_mid, name="Platform", h=1.1)
    put(ctx, K.yard_clutter, (-99, -60, 1.1), rot=HP)
    put(ctx, K.yard_clutter, (-99, -20, 1.1), rot=HP)
    prop_row(ctx, "TW_Cable_Reel", (-99, -48, 1.1), (-99, -32, 1.1), 2, rot=0.0)
    # east: the substation feeding the line
    pad(ctx, 99, -60, 138.5, 40, T.gravel, name="SubGravel")
    for y in (-42.0, -14.0):
        put(ctx, K.power_transformer, (121, y), rot=FACE_W, scale=1.35, margin=0.8)
    for y in (-56.0, -28.0, 0.0):
        firewall(ctx, 110, y - 0.7, 132, y + 0.7, h=13.0)
    put(ctx, K.gantry, (127, 22), rot=HP, span=22.0, h=18.0, strings=(-7.0, 0.0, 7.0), margin=1.0)
    put(ctx, K.circuit_breaker, (110, 22), rot=FACE_W, scale=1.3, margin=0.6)
    fence(ctx, [(138.5, 40.0), (100.0, 40.0), (100.0, -60.0), (138.5, -60.0)], sign_side=1)
    put(ctx, K.switch_house, (121, 58), rot=FACE_W, scale=1.2)
    put(ctx, K.water_tower, (121, 87), scale=1.25, margin=1.0)
    pad(ctx, 52, 70, 100, 98.5, T.concrete_mid, name="BankPad")
    put(ctx, K.battery_bank, (82, 86), scale=1.3)
    prop_row(ctx, "TW_Capacitor_Bank", (56, 76), (72, 76), 2, scale=1.3)
    poles = [put(ctx, K.utility_pole, (104, y), rot=HP, margin=1.0) for y in (-66.0, -84.0)]
    for k in range(3):
        cable_run(ctx, [p["tips"][k] for p in poles], sag=0.8, r=0.09)
    floodlights(ctx, [(-96, -73), (96, -73), (96, 71), (-96, 60)])
    put(ctx, K.yard_clutter, (118, -76), rot=0.2)
    prop_row(ctx, "TW_Cable_Reel", (62, -90), (92, -90), 3, rot=0.3, jitter=1.2, scale=1.2)
    put(ctx, K.barrier_block, (-64, -88), rot=0.0)
    puddles(ctx, [(-96, 20, 3, 1.8), (96, 50, 2.4, 1.5)])
    fill_edges(ctx)
    tufts(ctx, -138, -98, 138, 98, 300)
    scatter(ctx, n=12, clutter_share=0.2)
    return {}


OPTIONS = {
    1: ("01", "TESLA COIL WORKS", "tesla-coil-works", opt_tesla),
    2: ("02", "COPPERLINE SUBSTATION", "copperline-substation", opt_substation),
    3: ("03", "SPARKLINE SUBSTATION", "sparkline-substation", opt_sparkline),
    4: ("04", "STORMCLIFF DYNAMO", "stormcliff-dynamo", opt_stormcliff),
    5: ("05", "COPPERLINE RAILYARD", "copperline-railyard", opt_railyard),
}

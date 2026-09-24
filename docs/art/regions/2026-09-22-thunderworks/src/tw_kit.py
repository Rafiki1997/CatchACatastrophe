# The Thunderworks asset kit. Every builder makes one mesh datablock in real
# studs (1 Blender unit = 1 stud, pivot at the ground centre, +Z up, the
# asset's front facing -Y), so the same mesh is placed in the region mockups
# and rendered on its own for the asset sheets. Builders return
# (mesh, info): `info` carries footprint, height and named anchor points
# (coil tops, insulator ends) that arcs and cables attach to.
import bpy
import bmesh
import math
import random
from mathutils import Vector, Matrix

import tw_lib as L
import tw_geo as G
from tw_lib import rgb, TAU, xform


def _smooth(faces):
    for f in faces:
        f.smooth = True
    return faces


def _mesh(name, bm, mats):
    G.finalize(bm)
    return L.mesh_from_bm(name, bm, mats)


def prism_along(bm, pts2d, a0, a1, axis='Y', mi=0):
    """Extrude a 2-D outline along an axis. axis Y: pts are (x, z);
    axis X: (y, z); axis Z: (x, y)."""
    def v(p, a):
        if axis == 'Y':
            return (p[0], a, p[1])
        if axis == 'X':
            return (a, p[0], p[1])
        return (p[0], p[1], a)
    bot = [bm.verts.new(v(p, a0)) for p in pts2d]
    top = [bm.verts.new(v(p, a1)) for p in pts2d]
    bm.faces.new(list(reversed(bot)))
    bm.faces.new(top)
    n = len(pts2d)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((bot[i], bot[j], top[j], top[i]))
    return L._finish(bm, bot + top, mi, None, False, 0.0, 1)


BOLT = [(0.12, 0.50), (-0.20, 0.00), (-0.02, 0.00), (-0.14, -0.50), (0.22, 0.06), (0.04, 0.06)]


def bolt_emblem(bm, center, size, thick=0.12, mi=0, rot_z=0.0):
    """The Thunderworks lightning bolt, standing in XZ and facing -Y."""
    M = xform(center, (0, 0, rot_z))
    bot = [bm.verts.new(M @ Vector((u * size, -thick / 2, w * size))) for u, w in BOLT]
    top = [bm.verts.new(M @ Vector((u * size, thick / 2, w * size))) for u, w in BOLT]
    bm.faces.new(bot)
    bm.faces.new(list(reversed(top)))
    n = len(BOLT)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((bot[j], bot[i], top[i], top[j]))
    return L._finish(bm, bot + top, mi, None, False, 0.0, 1)


def sign_plate(bm, center, w, h, mi_face, mi_band, mi_bolt, rot_z=0.0, t=0.08):
    """A DANGER plate: white face, red band across the top, black bolt."""
    x, y, z = center
    M = xform((x, y, z), (0, 0, rot_z))

    def box(size, off, mi):
        r = bmesh.ops.create_cube(bm, size=1.0, matrix=M @ Matrix.Translation(off) @ Matrix.Diagonal((*size, 1.0)))
        L._finish(bm, r['verts'], mi, None, False, 0.0, 1)
    box((w, t, h), (0, 0, 0), mi_face)
    box((w * 0.96, t * 1.3, h * 0.26), (0, 0, h * 0.34), mi_band)
    bm2 = bm
    Mb = M @ Matrix.Translation((0, -t * 0.7, -h * 0.12))
    bot = [bm2.verts.new(Mb @ Vector((u * h * 0.55, -0.02, w_ * h * 0.55))) for u, w_ in BOLT]
    top = [bm2.verts.new(Mb @ Vector((u * h * 0.55, 0.02, w_ * h * 0.55))) for u, w_ in BOLT]
    bm2.faces.new(bot)
    bm2.faces.new(list(reversed(top)))
    for i in range(len(BOLT)):
        j = (i + 1) % len(BOLT)
        bm2.faces.new((bot[j], bot[i], top[i], top[j]))
    L._finish(bm2, bot + top, mi_bolt, None, False, 0.0, 1)


def insulator_axis(bm, p0, direction, n, r_shed, r_core, pitch, mi=0, segs=12):
    """Ceramic sheds along any direction from p0; returns the far end."""
    d = Vector(direction).normalized()
    p0 = Vector(p0)
    length = n * pitch
    G.rod(bm, p0, p0 + d * length, r_core, segs=segs, mi=mi)
    R = G._align(d)
    for i in range(n):
        c = p0 + d * ((i + 0.5) * pitch)
        rr = r_shed * (1.0 if i % 2 == 0 else 0.82)
        M = Matrix.Translation(c) @ R
        res = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=rr, radius2=rr * 0.92,
                                    depth=pitch * 0.34, matrix=M)
        L._finish(bm, res['verts'], mi, None, False, 0.0, 1)
    return p0 + d * length


# ================================================================== heroes
def tesla_coil(T, name="TW_TeslaCoil", h=40.0, seed=1):
    """A giant Tesla coil: stepped plinth with a guard rail, a conical copper
    primary, ceramic column, a banded secondary and a big polished toroid
    with a breakout ball where the arcs leave."""
    s = h / 40.0
    bm = L.new_bm()
    mats = [T.concrete, T.graphite, T.hazard, T.copper, T.cream, T.winding, T.alu, T.yellow_worn, T.steel_dk]
    CON, GRA, HAZ, COP, CRM, WND, ALU, YEL, STL = range(9)
    L.add_cyl(bm, 7.6 * s, 7.6 * s, 1.2 * s, (0, 0, 0.6 * s), segs=28, mi=CON)
    L.add_cyl(bm, 6.3 * s, 6.1 * s, 1.6 * s, (0, 0, 2.0 * s), segs=28, mi=GRA)
    L.add_cyl(bm, 6.36 * s, 6.36 * s, 0.45 * s, (0, 0, 1.75 * s), segs=28, mi=HAZ)
    # the primary: a copper cone of turns on radial spokes
    for i in range(8):
        a_ = i / 8 * TAU
        G.beam(bm, (math.cos(a_) * 2.6 * s, math.sin(a_) * 2.6 * s, 3.0 * s),
               (math.cos(a_) * 6.0 * s, math.sin(a_) * 6.0 * s, 4.1 * s), 0.34 * s, mi=GRA)
    for k, R in enumerate((3.4, 4.0, 4.6, 5.2, 5.8)):
        _smooth(G.add_torus(bm, R * s, 0.22 * s, (0, 0, (3.25 + 0.24 * k) * s), segs=44, rsegs=6, mi=COP))
    # ceramic column and the secondary
    G.insulator_stack(bm, (0, 0, 2.8 * s), 6, 2.7 * s, 1.8 * s, 1.1 * s, mi=CRM, segs=22)
    L.add_cyl(bm, 2.75 * s, 2.75 * s, 0.6 * s, (0, 0, 9.7 * s), segs=28, mi=COP)
    top_sec = 30.6 * s
    L.add_cyl(bm, 2.5 * s, 2.5 * s, top_sec - 10.0 * s, (0, 0, (10.0 * s + top_sec) / 2), segs=32, mi=WND)
    for zz in (15.0, 20.5, 26.0):
        L.add_cyl(bm, 2.62 * s, 2.62 * s, 0.35 * s, (0, 0, zz * s), segs=32, mi=COP)
    L.add_cyl(bm, 2.75 * s, 2.75 * s, 0.6 * s, (0, 0, top_sec + 0.3 * s), segs=28, mi=COP)
    G.rod(bm, (0, 0, top_sec), (0, 0, 33.6 * s), 0.7 * s, segs=12, mi=ALU)
    tz = 34.2 * s
    R_t, r_t = 6.2 * s, 2.1 * s
    _smooth(G.add_torus(bm, R_t, r_t, (0, 0, tz), segs=56, rsegs=18, mi=ALU))
    L.add_cyl(bm, R_t * 0.8, R_t * 0.8, 0.5 * s, (0, 0, tz), segs=40, mi=ALU)
    _smooth(L.add_sphere(bm, 1.6 * s, (0, 0, tz + 1.3 * s), scale=(1, 1, 0.7), segs=18, rings=10, mi=ALU))
    G.rod(bm, (0, 0, tz + 2.2 * s), (0, 0, 39.0 * s), 0.2 * s, segs=8, mi=COP)
    _smooth(L.add_sphere(bm, 0.6 * s, (0, 0, 39.4 * s), segs=12, rings=8, mi=COP))
    bx = (R_t + r_t * 0.55) * math.cos(0.6)
    by = (R_t + r_t * 0.55) * math.sin(0.6)
    _smooth(L.add_sphere(bm, 0.6 * s, (bx, by, tz + r_t * 0.8), segs=12, rings=8, mi=COP))
    # guard rail on the plinth
    for i in range(12):
        a_ = i / 12 * TAU
        G.rod(bm, (math.cos(a_) * 7.1 * s, math.sin(a_) * 7.1 * s, 1.2 * s),
              (math.cos(a_) * 7.1 * s, math.sin(a_) * 7.1 * s, 4.3 * s), 0.14 * s, segs=6, mi=STL)
    for z in (2.9, 4.2):
        G.add_torus(bm, 7.1 * s, 0.12 * s, (0, 0, z * s), segs=48, rsegs=5, mi=YEL)
    me = _mesh(name, bm, mats)
    return me, {"size": (15.2 * s, 15.2 * s, 40.0 * s), "toroid": (0.0, 0.0, tz), "toroid_R": R_t,
                "toroid_r": r_t, "breakout": (bx, by, tz + r_t * 0.8), "top": (0.0, 0.0, 39.4 * s)}


def dynamo_hall(T, name="TW_DynamoHall", length=62.0, depth=28.0, wall_h=15.0):
    """The brick dynamo hall: pilastered walls, tall arched windows lit
    warm, a clerestory on the ridge, a verdigris cupola at the front gable
    and a tall chimney at the back. Long axis on X, main doors facing -Y."""
    bm = L.new_bm()
    mats = [T.brick, T.brick_dk, T.stone, T.slate, T.window, T.teal, T.copper, T.verdigris, T.graphite, T.yellow_worn,
            T.black, T.lamp, T.concrete_dk]
    BRK, BDK, STN, SLT, WIN, TEA, COP, VER, GRA, YEL, BLK, LMP, CDK = range(13)
    hl, hd = length / 2, depth / 2
    L.add_box(bm, (length + 0.8, depth + 0.8, 1.2), (0, 0, 0.6), mi=STN, bevel=0.08)
    L.add_box(bm, (length, depth, wall_h), (0, 0, wall_h / 2), mi=BRK)
    L.add_box(bm, (length + 1.0, depth + 1.0, 0.8), (0, 0, wall_h + 0.2), mi=STN, bevel=0.06)
    # pilasters on all four faces
    nx = int(round(length / 6))
    for i in range(nx + 1):
        x = -hl + i * length / nx
        for sy in (-1, 1):
            L.add_box(bm, (1.3, 0.7, wall_h - 0.4), (x, sy * (hd + 0.3), wall_h / 2), mi=BDK)
    ny = int(round(depth / 6))
    for i in range(ny + 1):
        y = -hd + i * depth / ny
        for sx in (-1, 1):
            L.add_box(bm, (0.7, 1.3, wall_h - 0.4), (sx * (hl + 0.3), y, wall_h / 2), mi=BDK)
    # arched windows between pilasters on the front and back; the middle
    # front bay is the main door
    for i in range(nx):
        x = -hl + (i + 0.5) * length / nx
        for sy in (-1, 1):
            if sy < 0 and i == nx // 2:
                continue
            G.arched_opening(bm, (x, sy * (hd + 0.04), 2.6), 3.0, 8.4, 0.3, mi=WIN)
            L.add_box(bm, (3.8, 0.7, 0.4), (x, sy * (hd + 0.2), 2.45), mi=STN)
            L.add_box(bm, (0.9, 0.5, 1.0), (x, sy * (hd + 0.22), 2.6 + 8.4 + 0.25), mi=STN)
            for k in (-0.5, 0.5):
                L.add_box(bm, (0.12, 0.36, 6.6), (x + k * 1.0, sy * (hd + 0.2), 5.9), mi=GRA)
    # the main door: an arched teal pair in a stone surround, bolt plaque above
    xd = -hl + (nx // 2 + 0.5) * length / nx
    L.add_box(bm, (9.6, 1.0, 12.0), (xd, -hd - 0.3, 6.0), mi=STN)
    G.arched_opening(bm, (xd, -hd - 0.82, 0.0), 7.6, 10.8, 0.3, mi=TEA)
    L.add_box(bm, (0.2, 0.34, 7.0), (xd, -hd - 0.98, 3.5), mi=GRA)
    for k in range(4):
        L.add_box(bm, (7.4, 0.34, 0.18), (xd, -hd - 0.98, 1.2 + k * 1.8), mi=GRA)
    L.add_cyl(bm, 1.8, 1.8, 0.3, (xd, -hd - 0.95, 12.6), rot=(math.pi / 2, 0, 0), segs=24, mi=COP)
    bolt_emblem(bm, (xd, -hd - 1.15, 12.6), 2.6, 0.14, mi=YEL)
    for k in (-1, 1):
        L.add_box(bm, (0.6, 0.7, 0.9), (xd + k * 5.6, -hd - 0.6, 9.4), mi=LMP)
    # gable ends: a big arched window and an oculus
    for sx in (-1, 1):
        G.arched_opening(bm, (sx * (hl + 0.05), 0, 2.6), 5.4, 9.2, 0.3, mi=WIN, axis='X')
        L.add_box(bm, (0.8, 6.2, 0.4), (sx * (hl + 0.25), 0, 2.45), mi=STN)
    # roof: two slate planes over gable triangles, a clerestory on the ridge
    pitch = math.radians(30)
    over = 1.0
    run = hd + over
    rise = run * math.tan(pitch)
    ez = wall_h + 0.6
    for sy in (-1, 1):
        slab_w = run / math.cos(pitch)
        L.add_box(bm, (length + 2.4, slab_w, 0.6), (0, sy * run / 2, ez + rise / 2), rot=(-sy * pitch, 0, 0), mi=SLT)
    ridge = ez + rise
    for sx in (-1, 1):
        prism_along(bm, [(-hd, ez - 0.1), (hd, ez - 0.1), (0, ridge - 0.3)], sx * hl - 0.4, sx * hl + 0.4, axis='X', mi=BRK)
    L.add_cyl(bm, 1.3, 1.3, 0.35, (-hl - 0.6, 0, ez + rise * 0.55), rot=(0, math.pi / 2, 0), segs=20, mi=WIN)
    cl = length * 0.62
    L.add_box(bm, (cl, 5.6, 3.2), (0, 0, ridge + 0.9), mi=BRK)
    for sy in (-1, 1):
        for i in range(9):
            x = -cl / 2 + (i + 0.5) * cl / 9
            L.add_box(bm, (2.4, 0.2, 1.8), (x, sy * 2.82, ridge + 1.1), mi=WIN)
        L.add_box(bm, (cl + 1.2, 3.6, 0.4), (0, sy * 1.55, ridge + 3.1), rot=(-sy * math.radians(22), 0, 0), mi=SLT)
    L.add_box(bm, (cl + 1.2, 0.5, 0.5), (0, 0, ridge + 3.75), mi=COP)
    # verdigris cupola at the front gable end of the ridge
    cx = -hl + 5.0
    L.add_cyl(bm, 2.4, 2.4, 3.0, (cx, 0, ridge + 2.0), segs=8, mi=STN)
    for i in range(8):
        a = (i + 0.5) / 8 * TAU
        L.add_box(bm, (0.9, 0.3, 1.6), (cx + math.cos(a) * 2.3, math.sin(a) * 2.3, ridge + 2.2), rot=(0, 0, a + math.pi / 2), mi=WIN)
    _smooth(L.add_sphere(bm, 2.6, (cx, 0, ridge + 3.5), scale=(1, 1, 1.05), segs=20, rings=12, mi=VER))
    G.rod(bm, (cx, 0, ridge + 6.0), (cx, 0, ridge + 10.5), 0.16, segs=6, mi=COP)
    _smooth(L.add_sphere(bm, 0.45, (cx, 0, ridge + 10.6), segs=10, rings=6, mi=COP))
    # chimney at the back corner
    chx, chy = hl - 4.5, hd - 4.0
    top = 36.0
    L.add_box(bm, (3.6, 3.6, top), (chx, chy, top / 2), mi=BRK)
    for z in (top * 0.45, top * 0.8):
        L.add_box(bm, (4.0, 4.0, 0.7), (chx, chy, z), mi=COP)
    L.add_box(bm, (4.3, 4.3, 0.8), (chx, chy, top + 0.4), mi=STN)
    L.add_box(bm, (2.6, 2.6, 0.2), (chx, chy, top + 0.75), mi=BLK)
    # a copper feeder pipe up the gable into the roof
    L.add_tube(bm, [(hl + 0.9, -hd + 3, 0.2), (hl + 0.9, -hd + 3, 8), (hl + 0.9, -hd + 5, 10), (hl + 0.9, -hd + 5, ez + 1)],
               [0.42] * 4, segs=10, mi=COP)
    me = _mesh(name, bm, mats)
    return me, {"size": (length + 2.4, depth + 2.4, top + 0.8), "ridge": ridge}


def leyden_rack(T, name="TW_LeydenRack", n=5):
    """Bottled lightning: tall glass Leyden jars in a steel rack, copper foil
    round their feet, a glowing charge filament inside each, rod-and-ball
    electrodes joined by a copper bus bar."""
    bm = L.new_bm()
    mats = [T.concrete_mid, T.graphite, T.glass, T.copper, T.copper_dk, T.timber_dk, T.cream, T.white, T.red, T.black,
            T.arc, T.glow_ring]
    CON, GRA, GLS, COP, CDK, TIM, CRM, WHT, RED, BLK, ARC, GLW = range(12)
    pitch = 2.8
    span = (n - 1) * pitch
    L.add_box(bm, (span + 4.4, 4.6, 0.4), (0, 0, 0.2), mi=CON, bevel=0.06)
    for sy in (-1, 1):
        G.beam(bm, (-span / 2 - 1.6, sy * 1.5, 1.0), (span / 2 + 1.6, sy * 1.5, 1.0), 0.3, mi=GRA)
        G.beam(bm, (-span / 2 - 1.6, sy * 1.5, 2.6), (span / 2 + 1.6, sy * 1.5, 2.6), 0.3, mi=GRA)
        for sx in (-1, 0, 1):
            x = sx * (span / 2 + 1.6)
            G.beam(bm, (x, sy * 1.5, 0.4), (x, sy * 1.5, 2.8), 0.34, mi=GRA)
    rng = random.Random(3)
    for i in range(n):
        x = -span / 2 + i * pitch
        L.add_cyl(bm, 1.1, 1.1, 0.2, (x, 0, 0.5), segs=20, mi=TIM)
        prof = [(1.1, 0.6), (1.18, 0.9), (1.18, 4.9), (1.0, 5.6), (0.7, 5.9)]
        _smooth(G.lathe(bm, prof, segs=28, mi=GLS, center=(x, 0, 0)))
        _smooth(L.add_cyl(bm, 1.22, 1.22, 1.9, (x, 0, 1.6), segs=28, mi=COP))
        L.add_cyl(bm, 0.76, 0.76, 0.3, (x, 0, 6.0), segs=20, mi=TIM)
        # the charge: a glowing zigzag filament from the foot to the cap
        pts = [Vector((x, 0, 1.2))]
        for k in range(1, 7):
            pts.append(Vector((x + rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4), 1.2 + k * 0.72)))
        L.add_tube(bm, pts, [0.07] * len(pts), segs=4, mi=ARC)
        _smooth(L.add_sphere(bm, 0.42, (x, 0, 3.4), segs=12, rings=8, mi=GLW))
        G.rod(bm, (x, 0, 6.1), (x, 0, 7.6), 0.12, segs=6, mi=COP)
        _smooth(L.add_sphere(bm, 0.42, (x, 0, 7.75), segs=12, rings=8, mi=COP))
    G.rod(bm, (-span / 2 - 0.9, 0, 7.75), (span / 2 + 0.9, 0, 7.75), 0.14, segs=8, mi=COP)
    for sx in (-1, 1):
        G.insulator_stack(bm, (sx * (span / 2 + 1.6), 0, 2.8), 5, 0.42, 0.24, 0.98, mi=CRM)
    sign_plate(bm, (span / 2 + 1.6 + 0.2, -1.5 - 0.2, 1.8), 1.5, 1.2, WHT, RED, BLK, rot_z=0.0)
    me = _mesh(name, bm, mats)
    return me, {"size": (span + 4.4, 4.6, 8.2), "bus": ((-span / 2 - 0.9, 0, 7.75), (span / 2 + 0.9, 0, 7.75))}


def spark_gap(T, name="TW_SparkGap", gap=4.4):
    """Two ceramic columns carrying copper spheres across a spark gap."""
    bm = L.new_bm()
    mats = [T.concrete, T.hazard, T.steel_dk, T.cream, T.copper, T.graphite]
    CON, HAZ, STL, CRM, COP, GRA = range(6)
    half = gap / 2 + 2.2
    L.add_box(bm, (2 * half + 4.4, 5.6, 0.6), (0, 0, 0.3), mi=CON, bevel=0.06)
    L.add_box(bm, (2 * half + 4.6, 5.8, 0.16), (0, 0, 0.62), mi=HAZ)
    L.add_box(bm, (2 * half + 3.6, 4.8, 0.2), (0, 0, 0.66), mi=CON)
    ends = []
    for sx in (-1, 1):
        x = sx * half
        L.add_box(bm, (2.4, 2.4, 1.6), (x, 0, 1.5), mi=STL, bevel=0.08)
        top = G.insulator_stack(bm, (x, 0, 2.3), 8, 1.25, 0.72, 0.92, mi=CRM, segs=16)
        L.add_cyl(bm, 0.95, 0.95, 0.6, (x, 0, top[2] + 0.3), segs=16, mi=COP)
        inner = x - sx * 1.3
        G.rod(bm, (x, 0, top[2] + 0.6), (inner, 0, top[2] + 1.5), 0.26, segs=8, mi=COP)
        c = (x - sx * (half - gap / 2 - 1.15), 0, top[2] + 1.9)
        G.rod(bm, (inner, 0, top[2] + 1.5), (c[0] + sx * 0.8, 0, c[2]), 0.26, segs=8, mi=COP)
        _smooth(L.add_sphere(bm, 1.15, c, segs=18, rings=12, mi=COP))
        ends.append(c)
    me = _mesh(name, bm, mats)
    return me, {"size": (2 * half + 4.6, 5.8, ends[0][2] + 1.2), "gap": (ends[0], ends[1])}


def gantry(T, name="TW_Gantry", span=24.0, h=18.0, strings=(-8.0, 0.0, 8.0)):
    """A substation portal: two lattice columns, a box-truss beam, shield
    wire peaks and hanging insulator strings."""
    bm = L.new_bm()
    mats = [T.steel, T.concrete, T.cream, T.copper]
    STL, CON, CRM, COP = range(4)
    ends = []
    for sx in (-1, 1):
        x = sx * span / 2
        L.add_box(bm, (3.0, 3.0, 0.8), (x, 0, 0.4), mi=CON, bevel=0.08)
        G.lattice_tower(bm, (x, 0), 0.95, 0.72, 0.8, h - 0.8, 7, leg=0.34, brace=0.14, mi=STL)
        G.beam(bm, (x - 0.72, 0, h), (x, 0, h + 3.6), 0.3, mi=STL)
        G.beam(bm, (x + 0.72, 0, h), (x, 0, h + 3.6), 0.3, mi=STL)
        G.beam(bm, (x, -0.72, h), (x, 0, h + 3.6), 0.24, mi=STL)
        G.beam(bm, (x, 0.72, h), (x, 0, h + 3.6), 0.24, mi=STL)
        ends.append(("peak", (x, 0.0, h + 3.6)))
    G.lattice_girder(bm, (-span / 2, 0, h - 0.75), (span / 2, 0, h - 0.75), 0.72, 10, chord=0.3, brace=0.13, mi=STL)
    for x in strings:
        e = G.insulator_stack(bm, (x, 0, h - 1.5), 9, 0.55, 0.16, 0.42, mi=CRM, down=True, segs=12)
        L.add_box(bm, (0.5, 0.5, 0.5), (x, 0, e[2] - 0.2), mi=COP)
        ends.append(("string", (x, 0.0, e[2] - 0.4)))
    me = _mesh(name, bm, mats)
    return me, {"size": (span + 3.0, 3.0, h + 3.6), "ends": ends}


def power_transformer(T, name="TW_PowerTransformer"):
    """A big substation transformer: teal tank, radiator banks, conservator,
    tall HV bushings, on a kerbed gravel pit."""
    bm = L.new_bm()
    mats = [T.concrete, T.gravel, T.teal, T.teal_dk, T.cream, T.copper, T.graphite, T.white, T.red, T.black]
    CON, GRV, TEA, TDK, CRM, COP, GRA, WHT, RED, BLK = range(10)
    L.add_box(bm, (13.0, 10.0, 0.5), (0, 0, 0.25), mi=CON)
    for sx in (-1, 1):
        L.add_box(bm, (0.6, 10.0, 0.9), (sx * 6.2, 0, 0.7), mi=CON)
    for sy in (-1, 1):
        L.add_box(bm, (13.0, 0.6, 0.9), (0, sy * 4.7, 0.7), mi=CON)
    L.add_box(bm, (11.8, 8.8, 0.2), (0, 0, 0.9), mi=GRV)
    for sx in (-1, 1):
        L.add_box(bm, (7.0, 0.8, 0.8), (0, sx * 1.6, 1.3), mi=GRA)
    L.add_box(bm, (7.6, 5.2, 6.6), (0, 0, 1.7 + 3.3), mi=TEA, bevel=0.14)
    L.add_box(bm, (8.0, 5.6, 0.4), (0, 0, 8.2), mi=TDK, bevel=0.06)
    for sx in (-1, 1):
        for i in range(7):
            y = -2.0 + i * 0.66
            L.add_box(bm, (2.2, 0.16, 5.0), (sx * 5.0, y, 4.9), mi=TDK)
        for z in (2.4, 7.4):
            G.rod(bm, (sx * 4.0, -2.2, z), (sx * 4.0, 2.2, z), 0.22, segs=8, mi=TDK)
            G.rod(bm, (sx * 3.8, 0, z), (sx * 4.0, 0, z), 0.28, segs=8, mi=TDK)
    # conservator
    for sx in (-1, 1):
        G.beam(bm, (sx * 2.0, 1.9, 8.4), (sx * 2.0, 1.9, 9.6), 0.3, mi=TDK)
    _smooth(L.add_cyl(bm, 0.95, 0.95, 5.6, (0, 1.9, 10.3), rot=(0, math.pi / 2, 0), segs=20, mi=TEA))
    for sx in (-1, 1):
        L.add_cyl(bm, 0.95, 0.95, 0.1, (sx * 2.8, 1.9, 10.3), rot=(0, math.pi / 2, 0), segs=20, mi=TDK)
    tops = []
    for x in (-2.5, 0.0, 2.5):
        e = G.insulator_stack(bm, (x, -0.9, 8.4), 7, 0.66, 0.36, 0.64, mi=CRM, segs=14)
        L.add_cyl(bm, 0.42, 0.42, 0.55, (x, -0.9, e[2] + 0.27), segs=12, mi=COP)
        G.rod(bm, (x, -0.9, e[2] + 0.5), (x, -0.9, e[2] + 1.3), 0.1, segs=6, mi=COP)
        tops.append((x, -0.9, e[2] + 1.3))
    L.add_box(bm, (1.8, 0.9, 2.4), (2.4, -3.05, 3.3), mi=GRA, bevel=0.05)
    sign_plate(bm, (-1.6, -2.66, 5.6), 1.6, 1.3, WHT, RED, BLK)
    me = _mesh(name, bm, mats)
    return me, {"size": (13.0, 10.0, tops[0][2]), "bushings": tops}


def circuit_breaker(T, name="TW_CircuitBreaker"):
    """A live-tank breaker: three ceramic poles with copper heads on a steel
    frame over a control cabinet."""
    bm = L.new_bm()
    mats = [T.concrete, T.steel_dk, T.teal_dk, T.cream, T.copper, T.graphite]
    CON, STL, TDK, CRM, COP, GRA = range(6)
    for sx in (-1, 1):
        L.add_box(bm, (1.4, 1.4, 0.6), (sx * 3.0, 0, 0.3), mi=CON)
        G.beam(bm, (sx * 3.0, 0, 0.6), (sx * 3.0, 0, 4.4), 0.55, mi=STL)
    L.add_box(bm, (7.4, 0.9, 0.6), (0, 0, 4.5), mi=STL)
    L.add_box(bm, (2.0, 1.3, 2.6), (0, -0.4, 1.9), mi=TDK, bevel=0.06)
    L.add_box(bm, (2.4, 1.6, 0.6), (0, -0.4, 0.3), mi=CON)
    tops = []
    for x in (-2.5, 0.0, 2.5):
        e = G.insulator_stack(bm, (x, 0, 4.8), 6, 0.58, 0.34, 0.62, mi=CRM, segs=14)
        L.add_cyl(bm, 0.62, 0.62, 1.1, (x, 0, e[2] + 0.55), segs=14, mi=COP)
        L.add_box(bm, (1.6, 0.3, 0.3), (x, 0, e[2] + 1.2), mi=COP)
        tops.append((x, 0.0, e[2] + 1.4))
        G.rod(bm, (x * 0.2, -0.4, 3.2), (x, 0, 4.8), 0.08, segs=5, mi=GRA)
    me = _mesh(name, bm, mats)
    return me, {"size": (7.4, 1.6, tops[0][2]), "tops": tops}


def switch_house(T, name="TW_SwitchHouse", length=22.0, depth=14.0, wall_h=10.0):
    """The brick control building: flat roof behind a parapet, lit windows,
    a teal door under a canopy, roof plant and a radio mast."""
    bm = L.new_bm()
    mats = [T.concrete, T.brick, T.window, T.teal, T.graphite, T.corr_grey, T.steel, T.red_lamp, T.copper, T.yellow_worn,
            T.lamp, T.concrete_dk]
    CON, BRK, WIN, TEA, GRA, CGR, STL, RLP, COP, YEL, LMP, CDK = range(12)
    hl, hd = length / 2, depth / 2
    L.add_box(bm, (length + 0.6, depth + 0.6, 0.8), (0, 0, 0.4), mi=CON)
    L.add_box(bm, (length, depth, wall_h), (0, 0, wall_h / 2), mi=BRK)
    L.add_box(bm, (length + 0.8, depth + 0.8, 0.9), (0, 0, wall_h + 0.45), mi=CON, bevel=0.05)
    L.add_box(bm, (length - 0.6, depth - 0.6, 0.4), (0, 0, wall_h + 0.7), mi=GRA)
    L.add_box(bm, (length + 0.2, depth + 0.2, 0.4), (0, 0, 3.1), mi=CON)
    door_x = 1.8
    for x in (-8.0, -4.0, 5.6, 9.0):
        L.add_box(bm, (2.6, 0.3, 3.4), (x, -hd - 0.05, 5.4), mi=WIN)
        L.add_box(bm, (3.2, 0.5, 0.45), (x, -hd - 0.15, 7.35), mi=CON)
        L.add_box(bm, (3.2, 0.6, 0.35), (x, -hd - 0.2, 3.55), mi=CON)
        L.add_box(bm, (0.14, 0.34, 3.4), (x, -hd - 0.12, 5.4), mi=GRA)
    for y in (-3.0, 3.0):
        L.add_box(bm, (0.3, 2.6, 3.4), (-hl - 0.05, y, 5.4), mi=WIN)
        L.add_box(bm, (0.5, 3.2, 0.45), (-hl - 0.15, y, 7.35), mi=CON)
    L.add_box(bm, (3.4, 0.3, 6.6), (door_x, -hd - 0.06, 3.7), mi=TEA)
    L.add_box(bm, (5.2, 2.2, 0.36), (door_x, -hd - 1.0, 7.4), mi=CON)
    L.add_box(bm, (0.7, 0.6, 0.6), (door_x, -hd - 0.3, 8.3), mi=LMP)
    L.add_box(bm, (6.2, 0.2, 1.5), (door_x, -hd - 0.12, 9.1), mi=GRA)
    bolt_emblem(bm, (door_x - 2.2, -hd - 0.3, 9.1), 1.2, 0.1, mi=YEL)
    for k in range(3):
        L.add_box(bm, (0.8, 0.12, 0.3), (door_x - 0.6 + k * 1.2, -hd - 0.26, 9.1), mi=COP)
    # roof plant
    for x in (-6.0, -1.5):
        L.add_box(bm, (3.4, 2.8, 1.8), (x, 2.0, wall_h + 1.8), mi=CGR, bevel=0.05)
        L.add_cyl(bm, 1.0, 1.0, 0.12, (x, 2.0, wall_h + 2.75), segs=16, mi=GRA)
    L.add_box(bm, (1.2, 1.2, 0.4), (6.5, 3.0, wall_h + 1.1), mi=CON)
    G.rod(bm, (6.5, 3.0, wall_h + 1.3), (6.5, 3.0, wall_h + 10.0), 0.14, segs=6, mi=STL)
    for z in (4.0, 7.0):
        G.beam(bm, (6.5 - 1.0, 3.0, wall_h + z), (6.5 + 1.0, 3.0, wall_h + z), 0.1, mi=STL)
    _smooth(L.add_sphere(bm, 0.3, (6.5, 3.0, wall_h + 10.2), segs=8, rings=6, mi=RLP))
    # cable duct into the side
    L.add_box(bm, (1.8, 6.0, 0.8), (hl + 0.9, 0, 0.4), mi=CDK)
    me = _mesh(name, bm, mats)
    return me, {"size": (length + 0.8, depth + 2.2, wall_h + 10.5)}


def collector_mast(T, name="TW_CollectorMast", h=36.0):
    """The lightning collector from today's Thunderworks, as an asset: a
    lattice mast with two copper rings, a ceramic neck and a crown ball."""
    s = h / 36.0
    bm = L.new_bm()
    mats = [T.concrete, T.graphite, T.cream, T.copper, T.steel, T.alu]
    CON, GRA, CRM, COP, STL, ALU = range(6)
    L.add_box(bm, (7.4 * s, 7.4 * s, 3.8 * s), (0, 0, 1.9 * s), mi=CON, bevel=0.12)
    L.add_box(bm, (8.0 * s, 8.0 * s, 0.6 * s), (0, 0, 4.0 * s), mi=GRA, bevel=0.06)
    for i, d in enumerate((5.4, 5.0, 4.6)):
        L.add_cyl(bm, d / 2 * s, d / 2 * s * 0.94, 1.1 * s, (0, 0, (4.9 + i * 1.3) * s), segs=20, mi=CRM)
    L.add_cyl(bm, 1.2 * s, 1.2 * s, 3.9 * s, (0, 0, 6.2 * s), segs=16, mi=CRM)
    L.add_box(bm, (4.4 * s, 4.4 * s, 0.7 * s), (0, 0, 8.45 * s), mi=COP, bevel=0.05)
    G.lattice_tower(bm, (0, 0), 1.5 * s, 1.1 * s, 8.8 * s, 20.2 * s, 8, leg=0.34 * s, brace=0.14 * s, mi=STL)
    for zc, R, r in ((14.3, 6.5, 0.6), (21.8, 5.0, 0.5)):
        _smooth(G.add_torus(bm, R * s, r * s, (0, 0, zc * s), segs=40, rsegs=10, mi=COP))
        for i in range(4):
            a = i / 4 * TAU + math.pi / 4
            G.beam(bm, (math.cos(a) * 1.3 * s, math.sin(a) * 1.3 * s, zc * s),
                   (math.cos(a) * R * s, math.sin(a) * R * s, zc * s), 0.22 * s, mi=STL)
    L.add_box(bm, (2.8 * s, 2.8 * s, 0.6 * s), (0, 0, 29.2 * s), mi=GRA)
    _smooth(L.add_sphere(bm, 2.4 * s, (0, 0, 31.8 * s), segs=24, rings=14, mi=ALU))
    _smooth(G.add_torus(bm, 2.35 * s, 0.25 * s, (0, 0, 31.8 * s), segs=32, rsegs=6, mi=COP))
    G.rod(bm, (0, 0, 34.0 * s), (0, 0, 35.6 * s), 0.35 * s, segs=8, mi=COP)
    me = _mesh(name, bm, mats)
    return me, {"size": (13.2 * s, 13.2 * s, 35.8 * s), "crown": (0.0, 0.0, 31.8 * s), "top": (0.0, 0.0, 35.6 * s)}


def dynamo_drum(T, name="TW_DynamoDrum", D=16.0, W=8.0):
    """A giant copper dynamo: the wound drum on its axle (along Y), slotted
    copper end plates, teal A-frame cradles, ceramic bushings on the axle."""
    bm = L.new_bm()
    wind = G.winding_mat("tw_winding_y", rgb(206, 118, 62), rgb(58, 34, 28), pitch=0.55, axis='Y')
    mats = [T.concrete, T.teal, T.teal_dk, wind, T.copper, T.graphite, T.cream, T.steel, T.yellow_worn]
    CON, TEA, TDK, WND, COP, GRA, CRM, STL, YEL = range(9)
    R = D / 2
    zc = R + 2.6
    L.add_box(bm, (D + 2.0, W + 14.0, 1.4), (0, 0, 0.7), mi=CON, bevel=0.1)
    # the drum: windings on the barrel (bands along Y via the Y-axis material)
    bm2 = bm
    res = bmesh.ops.create_cone(bm2, cap_ends=True, cap_tris=False, segments=40, radius1=R * 0.97, radius2=R * 0.97, depth=W,
                                matrix=xform((0, 0, zc), (math.pi / 2, 0, 0)))
    fs = L._finish(bm2, res['verts'], WND, None, False, 0.0, 1)
    _smooth(fs)
    for sy in (-1, 1):
        L.add_cyl(bm, R, R, 0.6, (0, sy * (W / 2 + 0.3), zc), rot=(math.pi / 2, 0, 0), segs=40, mi=COP)
        _smooth(G.add_torus(bm, R - 0.1, 0.4, (0, sy * (W / 2 + 0.1), zc), rot=(math.pi / 2, 0, 0), segs=48, rsegs=8, mi=COP))
        for i in range(8):
            a = i / 8 * TAU
            c = (math.cos(a) * R * 0.58, sy * (W / 2 + 0.7), zc + math.sin(a) * R * 0.58)
            L.add_box(bm, (0.55, 0.3, R * 0.55), c, rot=(0, -a + math.pi / 2, 0), mi=GRA)
        L.add_cyl(bm, 2.0, 2.0, 0.8, (0, sy * (W / 2 + 0.8), zc), rot=(math.pi / 2, 0, 0), segs=24, mi=TEA)
    G.rod(bm, (0, -(W / 2 + 7.0), zc), (0, W / 2 + 7.0, zc), 0.9, segs=16, mi=STL)
    for sy in (-1, 1):
        yb = sy * (W / 2 + 3.2)
        prism_along(bm, [(-4.6, 1.4), (4.6, 1.4), (1.6, zc - 1.0), (-1.6, zc - 1.0)], yb - 1.0, yb + 1.0, axis='Y', mi=TEA)
        L.add_box(bm, (3.8, 2.4, 2.2), (0, yb, zc), mi=TDK, bevel=0.1)
        L.add_box(bm, (9.6, 2.6, 0.3), (0, yb, 1.55), mi=YEL)
        insulator_axis(bm, (0, sy * (W / 2 + 4.6), zc), (0, sy, 0), 4, 1.7, 1.0, 0.8, mi=CRM, segs=16)
        L.add_cyl(bm, 1.1, 1.1, 0.5, (0, sy * (W / 2 + 8.1), zc), rot=(math.pi / 2, 0, 0), segs=16, mi=COP)
    # brushes on the barrel
    for sx in (-1, 1):
        L.add_box(bm, (0.8, W * 0.8, 0.8), (sx * (R + 0.2), 0, zc), mi=COP)
        G.beam(bm, (sx * (R + 0.4), 0, zc), (sx * (R + 1.6), 0, 1.4), 0.5, mi=GRA)
    me = _mesh(name, bm, mats)
    return me, {"size": (D + 2.0, W + 17.0, D + 2.6), "hub": (0.0, -(W / 2 + 0.8), zc)}


def barrel_workshop(T, name="TW_BarrelWorkshop", w=12.0, d=16.0, wall_h=4.6):
    """A curved-roof workshop: corrugated walls, a teal barrel roof, a
    roller door in the front gable, a lit window and a wall lamp."""
    bm = L.new_bm()
    corr_door = G.corrugated_mat("tw_corr_door", rgb(120, 128, 138), pitch=0.5, axis='Z', metal=0.5)
    mats = [T.concrete, T.corr_grey_y, T.corr_teal_y, corr_door, T.window, T.graphite, T.lamp, T.teal_dk, T.corr_grey]
    CON, CGY, CTE, CDR, WIN, GRA, LMP, TDK, CGX = range(9)
    r = w / 2 + 0.3
    L.add_box(bm, (w + 1.2, d + 1.2, 0.4), (0, 0, 0.2), mi=CON)
    L.add_box(bm, (w, d, wall_h), (0, 0, wall_h / 2), mi=CGY)
    arc = [(r * math.cos(t), wall_h - 0.05 + r * math.sin(t) * 0.78) for t in [math.pi * i / 16 for i in range(17)]]
    fs = prism_along(bm, arc, -d / 2 - 0.5, d / 2 + 0.5, axis='Y', mi=CTE)
    # gable infill a hair inside the roof
    gable = [(r * 0.96 * math.cos(t), wall_h - 0.05 + r * 0.96 * math.sin(t) * 0.78) for t in [math.pi * i / 16 for i in range(17)]]
    for sy in (-1, 1):
        prism_along(bm, gable, sy * (d / 2) - 0.12, sy * (d / 2) + 0.12, axis='Y', mi=CGX)
    L.add_box(bm, (4.6, 0.3, 4.4), (-1.6, -d / 2 - 0.1, 2.4), mi=CDR)
    L.add_box(bm, (5.0, 0.4, 0.4), (-1.6, -d / 2 - 0.2, 4.7), mi=GRA)
    L.add_box(bm, (1.6, 0.3, 3.2), (3.4, -d / 2 - 0.1, 1.8), mi=TDK)
    L.add_box(bm, (2.4, 0.3, 1.5), (2.2, -d / 2 - 0.1, 6.0), mi=WIN)
    L.add_box(bm, (0.5, 0.5, 0.6), (3.4, -d / 2 - 0.35, 3.9), mi=LMP)
    for y in (-3.0, 3.0):
        L.add_box(bm, (0.3, 2.6, 1.4), (w / 2 + 0.05, y, 3.0), mi=WIN)
    L.add_box(bm, (1.2, 2.4, 1.8), (w / 2 + 0.6, -5.5, 1.1), mi=CGX)
    me = _mesh(name, bm, mats)
    return me, {"size": (w + 1.2, d + 1.2, wall_h + r * 0.78)}


def locomotive(T, name="TW_StormrailEngine", length=24.0):
    """A box-cab electric locomotive: teal body with a cream band and copper
    trim, two three-axle bogies, roof insulators and a pantograph."""
    bm = L.new_bm()
    mats = [T.graphite, T.teal, T.cream, T.copper, T.window_dim, T.lamp, T.steel_dk, T.yellow_worn, T.black, T.red]
    GRA, TEA, CRM, COP, WIN, LMP, STL, YEL, BLK, RED = range(10)
    hl = length / 2
    for sb in (-1, 1):
        yb = sb * (hl - 5.2)
        L.add_box(bm, (4.4, 7.4, 1.0), (0, yb, 2.0), mi=GRA)
        for k in (-2.4, 0.0, 2.4):
            for sx in (-1, 1):
                L.add_cyl(bm, 1.25, 1.25, 0.45, (sx * 2.3, yb + k, 1.25), rot=(0, math.pi / 2, 0), segs=20, mi=BLK)
                L.add_cyl(bm, 0.5, 0.5, 0.5, (sx * 2.55, yb + k, 1.25), rot=(0, math.pi / 2, 0), segs=12, mi=COP)
        for sx in (-1, 1):
            G.beam(bm, (sx * 2.7, yb - 2.4, 1.0), (sx * 2.7, yb + 2.4, 1.0), 0.25, mi=COP)
    L.add_box(bm, (5.0, length - 0.6, 1.1), (0, 0, 3.05), mi=GRA)
    L.add_box(bm, (5.4, length - 3.0, 5.4), (0, 0, 3.6 + 2.7), mi=TEA, bevel=0.3, seg=2)
    L.add_box(bm, (5.5, length - 3.1, 0.7), (0, 0, 5.1), mi=CRM)
    L.add_box(bm, (5.46, length - 3.2, 0.18), (0, 0, 8.4), mi=COP)
    for sb in (-1, 1):
        yc = sb * (hl - 1.2)
        L.add_box(bm, (5.2, 1.8, 4.6), (0, yc, 3.6 + 2.3), mi=TEA, bevel=0.35, seg=2)
        L.add_box(bm, (4.2, 0.3, 1.6), (0, yc + sb * 0.8, 7.0), mi=WIN)
        for sx in (-1, 1):
            L.add_box(bm, (0.3, 1.4, 1.5), (sx * 2.72, sb * (hl - 2.4), 7.0), mi=WIN)
            L.add_cyl(bm, 0.36, 0.36, 0.3, (sx * 1.6, yc + sb * 0.92, 4.6), rot=(math.pi / 2, 0, 0), segs=12, mi=LMP)
            L.add_cyl(bm, 0.34, 0.3, 0.9, (sx * 1.7, sb * (hl + 0.1), 3.1), rot=(math.pi / 2, 0, 0), segs=10, mi=STL)
        L.add_box(bm, (5.3, 0.35, 0.5), (0, sb * (hl - 0.1), 2.6), mi=YEL)
    L.add_box(bm, (5.0, length - 4.0, 0.5), (0, 0, 9.25), mi=STL)
    for sx in (-1, 1):
        for i in range(4):
            L.add_box(bm, (0.12, 2.0, 1.4), (sx * 2.72, -4.5 + i * 3.0, 6.9), mi=GRA)
        bolt_emblem(bm, (sx * 2.76, 3.6 if sx > 0 else -3.6, 6.8), 1.8, 0.1, mi=YEL, rot_z=sx * math.pi / 2)
    for y in (-5.5, -3.0, 3.0):
        G.insulator_stack(bm, (0, y, 9.5), 3, 0.4, 0.22, 0.5, mi=CRM)
    # pantograph: a diamond frame up to the contact shoe
    z0, z1 = 9.5, 13.4
    for sx in (-1, 1):
        G.beam(bm, (sx * 1.3, -1.6, z0), (sx * 0.2, 0.0, (z0 + z1) / 2), 0.14, mi=GRA)
        G.beam(bm, (sx * 0.2, 0.0, (z0 + z1) / 2), (sx * 1.3, 1.6, z1), 0.14, mi=GRA)
    L.add_box(bm, (3.6, 0.35, 0.22), (0, 1.6, z1 + 0.1), mi=COP)
    me = _mesh(name, bm, mats)
    return me, {"size": (5.6, length + 0.8, z1 + 0.2), "shoe": (0.0, 1.6, z1 + 0.2)}


def engine_shed(T, name="TW_EngineShed", length=40.0, width=17.0, eave=11.0):
    """A curved-roof engine shed: steel columns, a teal barrel vault with a
    skylight band, a masonry back wall, hanging lamps."""
    bm = L.new_bm()
    mats = [T.concrete, T.steel_dk, T.corr_teal_y, T.masonry, T.glass, T.lamp, T.graphite, T.window]
    CON, STL, CTE, MAS, GLS, LMP, GRA, WIN = range(8)
    hl, hw = length / 2, width / 2
    L.add_box(bm, (width + 2, length + 2, 0.3), (0, 0, 0.15), mi=CON)
    n = int(round(length / 8))
    for i in range(n + 1):
        y = -hl + i * length / n
        for sx in (-1, 1):
            L.add_box(bm, (1.6, 1.6, 0.6), (sx * hw, y, 0.6), mi=CON)
            G.beam(bm, (sx * hw, y, 0.6), (sx * hw, y, eave), 0.8, mi=STL)
        G.beam(bm, (-hw, y, eave), (hw, y, eave), 0.6, mi=STL)
        G.beam(bm, (-hw, y, eave - 2.2), (-hw + 2.2, y, eave), 0.34, mi=STL)
        G.beam(bm, (hw, y, eave - 2.2), (hw - 2.2, y, eave), 0.34, mi=STL)
        if i < n:
            L.add_box(bm, (0.5, 0.5, 0.9), (0, y + length / n / 2, eave - 2.2), mi=LMP)
            G.rod(bm, (0, y + length / n / 2, eave - 1.7), (0, y + length / n / 2, eave), 0.05, segs=4, mi=GRA)
    for sx in (-1, 1):
        G.beam(bm, (sx * hw, -hl, eave), (sx * hw, hl, eave), 0.6, mi=STL)
    r = hw + 0.8
    rise = 4.6
    outer = [(r * math.cos(t), eave + 0.3 + rise * math.sin(t)) for t in [math.pi * i / 20 for i in range(21)]]
    inner = [(p[0] * 0.97, eave + 0.3 + (p[1] - eave - 0.3) * 0.94 - 0.35) for p in reversed(outer)]
    # the vault as a thick shell, in three runs with a skylight strip between
    shell = outer + inner
    prism_along(bm, shell, -hl - 1.0, hl + 1.0, axis='Y', mi=CTE)
    sky = [(r * 1.004 * math.cos(t), eave + 0.3 + rise * 1.01 * math.sin(t)) for t in [math.pi * (0.42 + 0.16 * i / 6) for i in range(7)]]
    sky_in = [(p[0], p[1] - 0.2) for p in reversed(sky)]
    prism_along(bm, sky + sky_in, -hl + 1.0, hl - 1.0, axis='Y', mi=GLS)
    # masonry back wall (west, -X) with small lit windows
    L.add_box(bm, (1.4, length + 1.0, eave), (-hw - 0.9, 0, eave / 2), mi=MAS)
    for i in range(n):
        y = -hl + (i + 0.5) * length / n
        L.add_box(bm, (0.3, 2.2, 3.0), (-hw - 0.15, y, 6.2), mi=WIN)
    me = _mesh(name, bm, mats)
    return me, {"size": (width + 3.0, length + 2.0, eave + 0.3 + rise)}


def rails(T, name="TW_Rails", length=40.0, gauge=4.7, buffer_end=1):
    """Track on sleepers and ballast, with a buffer stop at one end."""
    bm = L.new_bm()
    mats = [T.gravel, T.sleeper, T.rail, T.redwhite, T.steel_dk]
    GRV, SLP, RAI, RWS, STL = range(5)
    hl = length / 2
    L.add_box(bm, (7.6, length, 0.3), (0, 0, 0.15), mi=GRV)
    n = int(length / 1.7)
    for i in range(n):
        y = -hl + (i + 0.5) * length / n
        L.add_box(bm, (6.4, 0.85, 0.3), (0, y, 0.42), mi=SLP)
    for sx in (-1, 1):
        L.add_box(bm, (0.36, length, 0.42), (sx * gauge / 2, 0, 0.78), mi=RAI)
    if buffer_end:
        yb = buffer_end * (hl - 0.8)
        for sx in (-1, 1):
            G.beam(bm, (sx * gauge / 2, yb, 0.9), (sx * gauge / 2, yb, 3.0), 0.5, mi=STL)
            G.beam(bm, (sx * gauge / 2, yb, 0.9), (sx * gauge / 2, yb + buffer_end * 2.2, 0.9), 0.4, mi=STL)
            G.beam(bm, (sx * gauge / 2, yb, 3.0), (sx * gauge / 2, yb + buffer_end * 2.2, 0.9), 0.4, mi=STL)
        L.add_box(bm, (6.0, 0.8, 1.2), (0, yb - buffer_end * 0.3, 2.6), mi=RWS)
    me = _mesh(name, bm, mats)
    return me, {"size": (7.6, length, 3.2)}


def catenary_mast(T, name="TW_CatenaryMast", h=13.0, reach=5.0):
    """An overhead-line mast: H-column, cantilever with a stay, insulators
    and the contact wire hanger over the track (at +X)."""
    bm = L.new_bm()
    mats = [T.concrete, T.steel_dk, T.cream, T.copper]
    CON, STL, CRM, COP = range(4)
    L.add_box(bm, (1.8, 1.8, 0.8), (0, 0, 0.4), mi=CON)
    for sy in (-0.3, 0.3):
        L.add_box(bm, (0.9, 0.18, h), (0, sy, h / 2), mi=STL)
    L.add_box(bm, (0.14, 0.6, h), (0, 0, h / 2), mi=STL)
    z1, z2 = h - 3.0, h - 0.6
    G.beam(bm, (0.3, 0, z1), (reach, 0, z1), 0.26, mi=STL)
    G.beam(bm, (0.3, 0, z2), (reach, 0, z1 + 0.3), 0.18, mi=STL)
    insulator_axis(bm, (0.5, 0, z1), (1, 0, 0), 3, 0.34, 0.16, 0.4, mi=CRM)
    insulator_axis(bm, (0.5, 0, z2), (1, 0, -0.1), 3, 0.34, 0.16, 0.4, mi=CRM)
    G.rod(bm, (reach - 0.2, 0, z1), (reach - 0.2, 0, z1 - 1.6), 0.06, segs=4, mi=COP)
    me = _mesh(name, bm, mats)
    return me, {"size": (reach + 1.0, 1.8, h), "wire": (reach - 0.2, 0.0, z1 - 1.6)}


def water_tower(T, name="TW_BoltWaterTower", h=26.0):
    """The bolt water tower: braced timber legs, a stave tank with iron
    hoops, a conical roof and the painted bolt."""
    bm = L.new_bm()
    staves = L.plank_mat("tw_staves", rgb(146, 104, 70), board=0.7, axis='X')
    mats = [T.concrete, T.timber_dk, staves, T.graphite, T.slate, T.yellow_worn, T.steel_dk, T.timber]
    CON, TDK, STV, GRA, SLT, YEL, STL, TIM = range(8)
    deck = h * 0.58
    for sx in (-1, 1):
        for sy in (-1, 1):
            L.add_box(bm, (1.6, 1.6, 0.8), (sx * 3.8, sy * 3.8, 0.4), mi=CON)
            G.beam(bm, (sx * 3.8, sy * 3.8, 0.8), (sx * 2.9, sy * 2.9, deck), 0.7, mi=TDK)
    for z0, z1 in ((0.8, deck * 0.5), (deck * 0.5, deck)):
        f0, f1 = (z0 - 0.8) / (deck - 0.8), (z1 - 0.8) / (deck - 0.8)
        w0, w1 = 3.8 - 0.9 * f0, 3.8 - 0.9 * f1
        for k in range(4):
            a = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
            p, q = a[k], a[(k + 1) % 4]
            G.beam(bm, (p[0] * w0, p[1] * w0, z0), (q[0] * w1, q[1] * w1, z1), 0.26, mi=TDK)
            G.beam(bm, (q[0] * w0, q[1] * w0, z0), (p[0] * w1, p[1] * w1, z1), 0.26, mi=TDK)
            G.beam(bm, (p[0] * w1, p[1] * w1, z1), (q[0] * w1, q[1] * w1, z1), 0.3, mi=TDK)
    L.add_box(bm, (9.4, 9.4, 0.5), (0, 0, deck + 0.25), mi=TIM)
    for k in range(4):
        a = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
        p, q = a[k], a[(k + 1) % 4]
        G.beam(bm, (p[0] * 4.6, p[1] * 4.6, deck + 1.6), (q[0] * 4.6, q[1] * 4.6, deck + 1.6), 0.16, mi=GRA)
        G.beam(bm, (p[0] * 4.6, p[1] * 4.6, deck + 0.5), (p[0] * 4.6, p[1] * 4.6, deck + 1.6), 0.16, mi=GRA)
    tb = deck + 0.5
    th = h * 0.26
    L.add_cyl(bm, 4.2, 4.2, th, (0, 0, tb + th / 2), segs=28, mi=STV)
    for f in (0.12, 0.5, 0.88):
        _smooth(G.add_torus(bm, 4.24, 0.12, (0, 0, tb + th * f), segs=40, rsegs=5, mi=GRA))
    L.add_cyl(bm, 4.7, 0.3, h - tb - th, (0, 0, tb + th + (h - tb - th) / 2), segs=28, mi=SLT)
    G.rod(bm, (0, 0, h - 0.3), (0, 0, h + 1.4), 0.12, segs=6, mi=STL)
    L.add_cyl(bm, 2.4, 2.4, 0.2, (0, -4.12, tb + th / 2), rot=(math.pi / 2 - 0.02, 0, 0), segs=24, mi=GRA)
    bolt_emblem(bm, (0, -4.3, tb + th / 2), 3.4, 0.14, mi=YEL)
    for sx in (-0.5, 0.5):
        G.beam(bm, (sx + 3.0, -3.0, 0.8), (sx + 2.9, -2.9, deck), 0.12, mi=STL)
    for i in range(int(deck / 0.9)):
        G.beam(bm, (2.5, -3.0 + 0.0, 1.2 + i * 0.9), (3.5, -3.0, 1.2 + i * 0.9), 0.1, mi=STL)
    me = _mesh(name, bm, mats)
    return me, {"size": (9.4, 9.4, h + 1.4)}


def pylon(T, name="TW_Pylon", h=42.0):
    """A transmission pylon for the heath outside the walls: tapered lattice,
    two cross-arms with hanging insulator strings, an earth-wire peak."""
    bm = L.new_bm()
    mats = [T.concrete, T.steel, T.cream, T.copper]
    CON, STL, CRM, COP = range(4)
    body = h - 6.0
    for sx in (-1, 1):
        for sy in (-1, 1):
            L.add_box(bm, (1.8, 1.8, 0.8), (sx * 3.4, sy * 3.4, 0.4), mi=CON)
    G.lattice_tower(bm, (0, 0), 3.4, 1.0, 0.8, body - 0.8, 9, leg=0.42, brace=0.16, mi=STL)
    G.lattice_tower(bm, (0, 0), 1.0, 0.25, body, 6.0, 2, leg=0.3, brace=0.12, mi=STL)
    ends = []
    for za, reach in ((body - 11.0, 8.0), (body - 3.0, 6.5)):
        for sx in (-1, 1):
            G.beam(bm, (sx * 1.2, -1.0, za), (sx * reach, 0, za), 0.3, mi=STL)
            G.beam(bm, (sx * 1.2, 1.0, za), (sx * reach, 0, za), 0.3, mi=STL)
            G.beam(bm, (sx * 1.1, -1.0, za + 2.6), (sx * reach, 0, za), 0.2, mi=STL)
            G.beam(bm, (sx * 1.1, 1.0, za + 2.6), (sx * reach, 0, za), 0.2, mi=STL)
            e = G.insulator_stack(bm, (sx * (reach - 0.2), 0, za), 8, 0.5, 0.14, 0.38, mi=CRM, down=True, segs=10)
            ends.append((sx * (reach - 0.2), 0.0, e[2] - 0.2))
            L.add_box(bm, (0.4, 0.4, 0.4), (sx * (reach - 0.2), 0, e[2] - 0.15), mi=COP)
    me = _mesh(name, bm, mats)
    return me, {"size": (17.0, 8.6, h), "ends": ends, "peak": (0.0, 0.0, h)}


def floodlight(T, name="TW_Floodlight", h=16.0):
    bm = L.new_bm()
    mats = [T.concrete, T.steel_dk, T.graphite, T.lamp]
    CON, STL, GRA, LMP = range(4)
    L.add_cyl(bm, 1.0, 1.1, 1.0, (0, 0, 0.5), segs=12, mi=CON)
    G.rod(bm, (0, 0, 1.0), (0, 0, h), 0.34, segs=8, mi=STL, r2=0.2)
    L.add_box(bm, (3.6, 0.3, 0.3), (0, -0.3, h - 0.2), mi=GRA)
    L.add_box(bm, (3.6, 0.3, 0.3), (0, -0.3, h - 1.6), mi=GRA)
    for x in (-1.2, 0.0, 1.2):
        for z in (h - 0.2, h - 1.6):
            if x == 0.0 and z < h - 1:
                continue
            M_rot = (math.radians(-28), 0, 0)
            L.add_box(bm, (1.1, 0.7, 0.9), (x, -0.8, z + 0.05), rot=M_rot, mi=GRA)
            L.add_box(bm, (0.9, 0.12, 0.7), (x, -1.18, z - 0.12), rot=M_rot, mi=LMP)
    me = _mesh(name, bm, mats)
    return me, {"size": (3.6, 2.4, h + 0.3)}


def cable_tray(T, name="TW_CableTray", length=12.0):
    """A cable tray on T-stands carrying a bundle of heavy cables."""
    bm = L.new_bm()
    mats = [T.concrete_dk, T.steel_dk, T.teal, T.black, T.copper, T.graphite]
    CDK, STL, TEA, BLK, COP, GRA = range(6)
    n = int(length / 4)
    for i in range(n + 1):
        x = -length / 2 + i * length / n
        L.add_box(bm, (0.9, 0.9, 0.3), (x, 0, 0.15), mi=CDK)
        G.beam(bm, (x, 0, 0.3), (x, 0, 1.8), 0.3, mi=STL)
        L.add_box(bm, (0.3, 2.2, 0.25), (x, 0, 1.85), mi=STL)
    L.add_box(bm, (length + 0.6, 1.8, 0.12), (0, 0, 2.0), mi=STL)
    for sy in (-1, 1):
        L.add_box(bm, (length + 0.6, 0.1, 0.5), (0, sy * 0.9, 2.2), mi=STL)
    for j, (y, mi_, r) in enumerate(((-0.5, TEA, 0.2), (-0.1, BLK, 0.24), (0.3, COP, 0.14), (0.6, GRA, 0.2), (0.1, TEA, 0.16))):
        z = 2.06 + r + (0.28 if j == 4 else 0.0)
        G.rod(bm, (-length / 2 - 0.4, y, z), (length / 2 + 0.4, y, z), r, segs=8, mi=mi_)
    me = _mesh(name, bm, mats)
    return me, {"size": (length + 0.6, 2.2, 2.7)}


def barrier_block(T, name="TW_Barrier", length=6.0):
    """A concrete road barrier in red and white."""
    bm = L.new_bm()
    mats = [T.redwhite, T.concrete]
    RW, CON = range(2)
    prof = [(-1.0, 0.0), (1.0, 0.0), (0.9, 0.3), (0.35, 0.9), (0.3, 1.8), (-0.3, 1.8), (-0.35, 0.9), (-0.9, 0.3)]
    prism_along(bm, [(p[0], p[1]) for p in prof], -length / 2, length / 2, axis='X', mi=RW)
    me = _mesh(name, bm, mats)
    return me, {"size": (length, 2.0, 1.8)}


def utility_pole(T, name="TW_UtilityPole", h=15.0):
    """A timber pole with a crossarm, pin insulators and a pot transformer."""
    bm = L.new_bm()
    mats = [T.timber_dk, T.cream, T.steel, T.graphite, T.copper]
    TDK, CRM, STL, GRA, COP = range(5)
    G.rod(bm, (0, 0, -0.2), (0, 0, h), 0.4, segs=10, mi=TDK, r2=0.3)
    L.add_box(bm, (6.0, 0.45, 0.45), (0, 0, h - 1.2), mi=TDK)
    for x in (-2.6, -0.9, 0.9, 2.6):
        if abs(x) < 1:
            continue
        G.insulator_stack(bm, (x, 0, h - 0.95), 2, 0.3, 0.16, 0.4, mi=CRM)
    G.insulator_stack(bm, (0, 0, h), 2, 0.3, 0.16, 0.4, mi=CRM)
    G.beam(bm, (0, 0, h - 5.0), (0, -0.9, h - 5.0), 0.2, mi=STL)
    L.add_cyl(bm, 0.8, 0.8, 1.9, (0, -1.35, h - 5.2), segs=16, mi=STL)
    L.add_cyl(bm, 0.86, 0.86, 0.2, (0, -1.35, h - 4.2), segs=16, mi=GRA)
    for x in (-0.35, 0.35):
        G.insulator_stack(bm, (x, -1.35, h - 4.1), 2, 0.2, 0.1, 0.3, mi=CRM)
    me = _mesh(name, bm, mats)
    return me, {"size": (6.0, 2.4, h + 0.8), "tips": [(-2.6, 0.0, h - 0.15), (2.6, 0.0, h - 0.15), (0.0, 0.0, h + 0.8)]}


def yard_clutter(T, name="TW_YardClutter", seed=5):
    """A drum stack, a pallet of crates and a cable spool: the small stuff
    every band needs."""
    rng = random.Random(seed)
    bm = L.new_bm()
    crate = L.plank_mat("tw_crate", rgb(164, 120, 78), board=0.75, axis='Z')
    mats = [T.teal, T.graphite, crate, T.timber_dk, T.copper, T.timber, T.yellow_worn]
    TEA, GRA, CRT, TDK, COP, TIM, YEL = range(7)
    for i, (x, y) in enumerate(((-3.2, -0.6), (-1.9, -0.9), (-2.6, 0.6))):
        L.add_cyl(bm, 0.6, 0.6, 1.8, (x, y, 0.9), segs=14, mi=TEA if i != 1 else GRA)
        for z in (0.5, 1.3):
            L.add_cyl(bm, 0.63, 0.63, 0.1, (x, y, z), segs=14, mi=GRA)
    L.add_box(bm, (2.8, 2.4, 0.3), (0.6, 0.2, 0.15), mi=TDK)
    L.add_box(bm, (1.3, 1.1, 1.2), (0.0, -0.2, 0.9), mi=CRT, bevel=0.04)
    L.add_box(bm, (1.2, 1.1, 1.1), (1.3, 0.3, 0.85), mi=CRT, bevel=0.04)
    L.add_box(bm, (1.0, 0.9, 0.9), (0.4, 0.2, 1.95), mi=CRT, bevel=0.04)
    for sx in (-1, 1):
        L.add_cyl(bm, 1.3, 1.3, 0.2, (3.4, sx * 0.7, 1.3), rot=(math.pi / 2, 0, 0), segs=20, mi=TIM)
    L.add_cyl(bm, 0.9, 0.9, 1.2, (3.4, 0, 1.3), rot=(math.pi / 2, 0, 0), segs=20, mi=COP)
    me = _mesh(name, bm, mats)
    return me, {"size": (8.0, 2.8, 2.6)}


def storm_jar(T, name="TW_StormJar", seed=7):
    """A storm in a bell jar: a caught thundercloud swirling under a copper-
    ribbed glass dome, small bolts licking down to the base."""
    rng = random.Random(seed)
    bm = L.new_bm()
    cloud = L.mat("tw_cloud", rgb(92, 98, 122), rough=0.8, sss=0.1, jitter=0.1, rand=0.08)
    cloud_lt = L.mat("tw_cloud_lt", rgb(150, 158, 184), rough=0.8, sss=0.1, jitter=0.1)
    mats = [T.concrete, T.graphite, T.copper, T.glass, cloud, cloud_lt, T.arc, T.glow_ring, T.yellow_worn, T.alu]
    CON, GRA, COP, GLS, CLD, CLT, ARC, GLW, YEL, ALU = range(10)
    L.add_cyl(bm, 5.4, 5.6, 0.7, (0, 0, 0.35), segs=32, mi=CON)
    L.add_cyl(bm, 4.6, 4.8, 1.3, (0, 0, 1.35), segs=32, mi=GRA)
    _smooth(G.add_torus(bm, 4.7, 0.25, (0, 0, 1.95), segs=48, rsegs=8, mi=COP))
    L.add_cyl(bm, 1.6, 1.6, 0.3, (0, 0, 2.15), segs=24, mi=COP)
    prof = [(4.0, 2.0), (4.0, 7.6)] + [(4.0 * math.cos(t), 7.6 + 3.4 * math.sin(t)) for t in [math.pi / 2 * k / 8 for k in range(1, 9)]]
    prof[-1] = (0.0, 11.0)
    _smooth(G.lathe(bm, prof, segs=36, mi=GLS))
    # copper ribs over the dome and two hoops
    for i in range(8):
        a_ = i / 8 * TAU
        pts = [(math.cos(a_) * (r + 0.12), math.sin(a_) * (r + 0.12), z) for r, z in prof[:-1]] + [(0, 0, 11.1)]
        L.add_tube(bm, pts, [0.12] * len(pts), segs=5, mi=COP)
    for z in (3.2, 7.0):
        G.add_torus(bm, 4.14, 0.14, (0, 0, z), segs=48, rsegs=5, mi=COP)
    L.add_cyl(bm, 0.9, 0.7, 0.8, (0, 0, 11.3), segs=16, mi=COP)
    G.rod(bm, (0, 0, 11.6), (0, 0, 14.2), 0.14, segs=6, mi=COP)
    _smooth(L.add_sphere(bm, 0.5, (0, 0, 14.5), segs=12, rings=8, mi=COP))
    # the cloud: a lumpy cluster, dark underneath, paler on top, lit inside
    for k in range(16):
        a_ = rng.uniform(0, TAU)
        d = rng.uniform(0.0, 2.1)
        z = 7.2 + rng.uniform(-0.6, 0.9)
        r = rng.uniform(0.9, 1.5)
        _smooth(L.add_sphere(bm, r, (math.cos(a_) * d, math.sin(a_) * d, z), segs=12, rings=8,
                             mi=CLT if z > 7.5 else CLD))
    _smooth(L.add_sphere(bm, 1.0, (0.3, -0.4, 6.8), segs=12, rings=8, mi=GLW))
    for k in range(3):
        a_ = k / 3 * TAU + 0.4
        p0 = (math.cos(a_) * 1.2, math.sin(a_) * 1.2, 6.2)
        p1 = (math.cos(a_ + 0.5) * 2.4, math.sin(a_ + 0.5) * 2.4, 2.3)
        G.add_bolt(bm, p0, p1, rng, r=0.09, mi=ARC, forks=1, depth=4, jag=0.2)
    bolt_emblem(bm, (0, -4.72, 1.35), 0.9, 0.1, mi=YEL)
    me = _mesh(name, bm, mats)
    return me, {"size": (11.2, 11.2, 15.0)}


def battery_bank(T, name="TW_AccumulatorBank", n=3):
    """Giant accumulator cells in a steel cradle: teal casings with a cream
    band and bolt, copper terminals on a bus, a charge meter on each."""
    bm = L.new_bm()
    meter = L.mat("tw_meter", rgb(110, 240, 140), emit=4.0, emit_color=rgb(110, 240, 140))
    mats = [T.concrete_dk, T.steel_dk, T.teal, T.cream, T.copper, T.black, meter, T.graphite, T.yellow_worn, T.teal_dk]
    CDK, STL, TEA, CRM, COP, BLK, MTR, GRA, YEL, TDK = range(10)
    pitch = 4.6
    span = (n - 1) * pitch
    L.add_box(bm, (span + 6.0, 6.0, 0.6), (0, 0, 0.3), mi=CDK, bevel=0.06)
    for sy in (-1, 1):
        G.beam(bm, (-span / 2 - 2.6, sy * 2.2, 2.0), (span / 2 + 2.6, sy * 2.2, 2.0), 0.4, mi=STL)
        for i in range(n + 1):
            x = -span / 2 - pitch / 2 + i * pitch
            G.beam(bm, (x, sy * 2.2, 0.6), (x, sy * 2.2, 2.2), 0.4, mi=STL)
    tops = []
    for i in range(n):
        x = -span / 2 + i * pitch
        L.add_cyl(bm, 2.0, 2.0, 0.6, (x, 0, 0.9), segs=28, mi=BLK)
        _smooth(L.add_cyl(bm, 2.0, 2.0, 7.0, (x, 0, 4.7), segs=28, mi=TEA))
        L.add_cyl(bm, 2.03, 2.03, 1.6, (x, 0, 4.4), segs=28, mi=CRM)
        L.add_cyl(bm, 1.7, 2.0, 0.5, (x, 0, 8.45), segs=28, mi=TDK)
        L.add_cyl(bm, 0.7, 0.7, 0.8, (x, 0, 9.1), segs=16, mi=COP)
        tops.append((x, 0.0, 9.5))
        bolt_emblem(bm, (x, -2.08, 4.4), 1.3, 0.08, mi=YEL)
        for k in range(4):
            L.add_box(bm, (0.7, 0.14, 0.42), (x, -2.02, 5.7 + k * 0.55), mi=MTR if k < 3 else GRA)
    for i in range(n - 1):
        a_, b_ = Vector(tops[i]), Vector(tops[i + 1])
        L.add_tube(bm, [a_, (a_ + b_) / 2 + Vector((0, 0, 1.1)), b_], [0.22] * 3, segs=8, mi=COP)
    L.add_box(bm, (1.6, 1.2, 2.4), (span / 2 + 3.4, -1.0, 1.8), mi=GRA, bevel=0.05)
    L.add_cyl(bm, 0.5, 0.5, 0.1, (span / 2 + 3.4, -1.62, 2.3), rot=(math.pi / 2, 0, 0), segs=16, mi=CRM)
    me = _mesh(name, bm, mats)
    return me, {"size": (span + 7.0, 6.0, 9.5), "tops": tops}


def fence_section(T, name="TW_FenceSection", length=16.0, h=7.0):
    """A chain-link run: galvanised posts, top rail, alpha mesh, three
    strands of barbed wire on cranked arms, a DANGER plate facing -Y."""
    bm = L.new_bm()
    mats = [T.steel, T.chainlink, T.white, T.red, T.black, T.concrete]
    STL, CHL, WHT, RED, BLK, CON = range(6)
    n = max(1, int(math.ceil(length / 8.0)))
    for i in range(n + 1):
        x = -length / 2 + i * length / n
        L.add_cyl(bm, 0.45, 0.45, 0.4, (x, 0, 0.2), segs=10, mi=CON)
        G.rod(bm, (x, 0, 0), (x, 0, h + 0.2), 0.17, segs=8, mi=STL)
        G.beam(bm, (x, 0, h), (x, 0.6, h + 0.9), 0.09, mi=STL)
    G.rod(bm, (-length / 2, 0, h), (length / 2, 0, h), 0.1, segs=6, mi=STL)
    G.rod(bm, (-length / 2, 0, 0.3), (length / 2, 0, 0.3), 0.05, segs=4, mi=STL)
    for i in range(3):
        G.rod(bm, (-length / 2, 0.2 * (i + 1), h + 0.3 * (i + 1)), (length / 2, 0.2 * (i + 1), h + 0.3 * (i + 1)), 0.03, segs=3, mi=STL)
    L.add_box(bm, (length, 0.05, h - 0.3), (0, 0, (h + 0.3) / 2), mi=CHL)
    sign_plate(bm, (0, -0.12, 4.4), 1.9, 1.5, WHT, RED, BLK)
    me = _mesh(name, bm, mats)
    return me, {"size": (length + 0.9, 1.0, h + 1.1)}


def flatcar(T, name="TW_Flatcar", reel=True):
    """A four-axle flatcar with a giant cable drum chocked on its deck."""
    bm = L.new_bm()
    mats = [T.graphite, T.teal_dk, T.timber, T.copper, T.black, T.yellow_worn]
    GRA, TDK, TIM, COP, BLK, YEL = range(6)
    for sb in (-1, 1):
        L.add_box(bm, (4.2, 4.0, 0.9), (0, sb * 6.0, 1.6), mi=GRA)
        for kk in (-1.2, 1.2):
            for sx in (-1, 1):
                L.add_cyl(bm, 1.1, 1.1, 0.4, (sx * 2.3, sb * 6.0 + kk, 1.1), rot=(0, math.pi / 2, 0), segs=16, mi=BLK)
    L.add_box(bm, (5.4, 17.0, 0.8), (0, 0, 2.5), mi=TDK)
    for sx in (-1, 1):
        L.add_box(bm, (0.3, 17.0, 0.5), (sx * 2.6, 0, 3.1), mi=GRA)
    for sb in (-1, 1):
        L.add_cyl(bm, 0.3, 0.3, 0.8, (0, sb * 8.9, 2.2), rot=(math.pi / 2, 0, 0), segs=10, mi=GRA)
    if reel:
        for sx in (-1, 1):
            L.add_cyl(bm, 4.2, 4.2, 0.45, (sx * 2.1, 0, 7.1), rot=(0, math.pi / 2, 0), segs=28, mi=TIM)
        L.add_cyl(bm, 2.9, 2.9, 3.8, (0, 0, 7.1), rot=(0, math.pi / 2, 0), segs=28, mi=COP)
        for sb in (-1, 1):
            L.add_box(bm, (4.6, 1.0, 1.1), (0, sb * 3.6, 3.45), mi=YEL)
    me = _mesh(name, bm, mats)
    return me, {"size": (5.4, 17.8, 11.3 if reel else 3.4)}


def arc_obj(T, name, p0, p1, seed, collection, r=0.16, forks=2, mat_=None, jag=0.16):
    """A lightning arc between two points, as its own glowing object."""
    rng = random.Random(seed)
    bm = L.new_bm()
    G.add_bolt(bm, p0, p1, rng, r=r, mi=0, forks=forks, jag=jag)
    ob = L.obj_from_bm(name, bm, [mat_ or T.arc], collection, solid=False)
    return ob


# ================================================================== registry
# (id, title, builder, blurb, used in options)
ASSETS = [
    ("tesla_coil", "Giant Tesla Coil", tesla_coil, "Stepped plinth, copper primary, ceramic column, wound secondary, polished toroid.", "01 03 04"),
    ("dynamo_hall", "Dynamo Hall", dynamo_hall, "Pilastered brick hall with arched lit windows, clerestory, verdigris cupola and chimney.", "01"),
    ("leyden_rack", "Leyden Jar Rack", leyden_rack, "Five glass jars with copper foil and ball electrodes on a bus bar.", "01 03"),
    ("spark_gap", "Spark Gap", spark_gap, "Two ceramic columns with copper spheres; an arc jumps the gap.", "01 04"),
    ("storm_jar", "Storm Bell Jar", storm_jar, "A caught thundercloud under a copper-ribbed glass dome.", "01 03"),
    ("battery_bank", "Accumulator Bank", battery_bank, "Giant teal cells with copper terminals and charge meters.", "02 03 05"),
    ("collector_mast", "Lightning Collector Mast", collector_mast, "Today's collector reworked: lattice mast, copper rings, crown ball.", "01 02 03"),
    ("gantry", "Substation Gantry", gantry, "Lattice portal with box-truss beam, earth-wire peaks and insulator strings.", "02 03 05"),
    ("power_transformer", "Power Transformer", power_transformer, "Teal tank, radiator banks, conservator and tall HV bushings on a gravel pit.", "02 03 05"),
    ("circuit_breaker", "Circuit Breaker", circuit_breaker, "Three ceramic poles with copper heads on a steel frame.", "02 03 05"),
    ("switch_house", "Switch House", switch_house, "Brick control building, lit windows, teal door, roof plant and radio mast.", "02 03 05"),
    ("dynamo_drum", "Giant Dynamo Drum", dynamo_drum, "Wound copper drum on teal cradles with slotted end plates and ceramic bushings.", "04"),
    ("barrel_workshop", "Barrel-Roof Workshop", barrel_workshop, "Corrugated walls under a teal barrel roof, roller door, lit window.", "01 02 04"),
    ("locomotive", "Stormrail Engine", locomotive, "Box-cab electric locomotive with pantograph and roof insulators.", "05"),
    ("engine_shed", "Engine Shed", engine_shed, "Steel columns under a teal barrel vault with a skylight, masonry back wall.", "05"),
    ("rails", "Track and Buffer Stop", rails, "Rails on sleepers and ballast, red-and-white buffer stop.", "05"),
    ("catenary_mast", "Catenary Mast", catenary_mast, "H-column with cantilever, stay and insulators over the track.", "05"),
    ("water_tower", "Bolt Water Tower", water_tower, "Braced timber tower, stave tank with hoops, painted bolt.", "05"),
    ("pylon", "Transmission Pylon", pylon, "Tapered lattice tower for the heath outside the walls; carries the lines.", "all"),
    ("floodlight", "Floodlight Mast", floodlight, "Tapered pole with a five-lamp head.", "all"),
    ("cable_tray", "Cable Tray", cable_tray, "T-stands carrying a bundle of heavy cables.", "01 04"),
    ("utility_pole", "Utility Pole", utility_pole, "Timber pole, crossarm, pin insulators and a pot transformer.", "02 05"),
    ("fence_section", "Chain-Link Fence", fence_section, "Galvanised run with barbed top and DANGER plates; fences every compound.", "02 03 05"),
    ("flatcar", "Cable Flatcar", flatcar, "Four-axle flatcar with a giant cable drum chocked on the deck.", "05"),
    ("barrier_block", "Road Barrier", barrier_block, "Red-and-white concrete barrier for the band edges.", "02 03 05"),
    ("yard_clutter", "Yard Clutter", yard_clutter, "Drum stack, crates on a pallet, cable spool.", "all"),
]


def _fx_tesla(T, c, info, ob_loc=(0.0, 0.0, 0.0)):
    ox, oy, oz = ob_loc
    tx, ty, tz = info["toroid"]
    R = info["toroid_R"] + info["toroid_r"] * 0.7
    for k, (ang, reach, drop) in enumerate(((0.6, 11.0, 9.0), (2.4, 9.0, 14.0), (4.1, 12.0, 6.0))):
        p0 = (ox + tx + math.cos(ang) * R, oy + ty + math.sin(ang) * R, oz + tz + 0.6)
        p1 = (ox + tx + math.cos(ang) * (R + reach), oy + ty + math.sin(ang) * (R + reach), oz + tz - drop)
        arc_obj(T, "Arc", p0, p1, 50 + k, c, r=0.2, forks=2)


def _fx_gap(T, c, info, ob_loc=(0.0, 0.0, 0.0)):
    a_, b_ = info["gap"]
    ox, oy, oz = ob_loc
    arc_obj(T, "Arc", (a_[0] + ox + 1.0, a_[1] + oy, a_[2] + oz), (b_[0] + ox - 1.0, b_[1] + oy, b_[2] + oz), 71, c,
            r=0.16, forks=1, jag=0.22)


FX = {"tesla_coil": _fx_tesla, "spark_gap": _fx_gap}

# Geometry and material helpers the Thunderworks mockups add on top of the
# Frostbite kit (tw_lib.py is fb_lib.py unchanged): steel beams and lattice
# towers, tori, sagging cables, lightning arcs, insulator stacks, and the
# industrial materials (coil windings, corrugated sheet, chain-link, hazard
# stripes, glass, the yard floor). Blender 5.1.
#
# Scene axes as everywhere in this pipeline: region-local studs, +X east,
# +Y north (towards Orbit Outpost), +Z up, floor top at z = 0.
import bpy
import bmesh
import math
import random
from mathutils import Vector, Matrix

import tw_lib as L
from tw_lib import rgb, TAU, _finish, xform


# ------------------------------------------------------------------ beams
def _align(t):
    """A rotation taking +Z onto the unit vector t."""
    tn = t.normalized()
    if abs(tn.z) > 0.9995:
        return Matrix.Identity(4) if tn.z > 0 else Matrix.Rotation(math.pi, 4, 'X')
    return tn.to_track_quat('Z', 'Y').to_matrix().to_4x4()


def beam(bm, p0, p1, w, d=None, mi=0, rng=None, jit=False, ext=0.0):
    """A square-section member from p0 to p1 (extended by `ext` at both ends
    so lattice joints close up)."""
    p0, p1 = Vector(p0), Vector(p1)
    t = p1 - p0
    Lh = t.length
    if Lh < 1e-5:
        return set()
    d = w if d is None else d
    M = Matrix.Translation((p0 + p1) / 2) @ _align(t) @ Matrix.Diagonal((w, d, Lh + 2 * ext, 1.0))
    r = bmesh.ops.create_cube(bm, size=1.0, matrix=M)
    return _finish(bm, r['verts'], mi, rng, jit, 0.0, 1)


def rod(bm, p0, p1, r, segs=8, mi=0, r2=None):
    """A round bar (or a tapered one) from p0 to p1."""
    p0, p1 = Vector(p0), Vector(p1)
    t = p1 - p0
    Lh = t.length
    if Lh < 1e-5:
        return set()
    M = Matrix.Translation((p0 + p1) / 2) @ _align(t)
    res = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r,
                                radius2=r if r2 is None else r2, depth=Lh, matrix=M)
    return _finish(bm, res['verts'], mi, None, False, 0.0, 1)


def lattice_tower(bm, center, base_hw, top_hw, z0, h, panels, leg=0.5, brace=0.22, mi=0, girt=True):
    """A four-legged tapering lattice: corner legs, a girt at every panel
    line and X-bracing on all four faces."""
    cx, cy = center
    levels = [z0 + h * i / panels for i in range(panels + 1)]

    def hw(z):
        return base_hw + (top_hw - base_hw) * (z - z0) / h

    def corners(z):
        w = hw(z)
        return [Vector((cx - w, cy - w, z)), Vector((cx + w, cy - w, z)),
                Vector((cx + w, cy + w, z)), Vector((cx - w, cy + w, z))]

    b0, b1 = corners(levels[0]), corners(levels[-1])
    for k in range(4):
        beam(bm, b0[k], b1[k], leg, mi=mi, ext=0.1)
    for i in range(panels):
        lo, hi = corners(levels[i]), corners(levels[i + 1])
        for k in range(4):
            k2 = (k + 1) % 4
            beam(bm, lo[k], hi[k2], brace, mi=mi)
            beam(bm, lo[k2], hi[k], brace, mi=mi)
            if girt:
                beam(bm, hi[k], hi[k2], brace * 1.2, mi=mi)
    if girt:
        for k in range(4):
            beam(bm, b0[k], b0[(k + 1) % 4], brace * 1.2, mi=mi)
    return corners


def lattice_girder(bm, p0, p1, hw, panels, chord=0.36, brace=0.18, mi=0):
    """A square box truss from p0 to p1 (roughly horizontal): four chords,
    verticals and diagonals on every face."""
    p0, p1 = Vector(p0), Vector(p1)
    t = (p1 - p0)
    tn = t.normalized()
    up = Vector((0, 0, 1))
    a = tn.cross(up).normalized() * hw
    b = up * hw

    def ring(p):
        return [p - a - b, p + a - b, p + a + b, p - a + b]

    for k, off in enumerate((-a - b, a - b, a + b, -a + b)):
        beam(bm, p0 + off, p1 + off, chord, mi=mi, ext=0.05)
    for i in range(panels + 1):
        r = ring(p0 + t * (i / panels))
        for k in range(4):
            beam(bm, r[k], r[(k + 1) % 4], brace, mi=mi)
        if i < panels:
            r2 = ring(p0 + t * ((i + 1) / panels))
            for k in range(4):
                k2 = (k + 1) % 4
                if (i + k) % 2:
                    beam(bm, r[k], r2[k2], brace, mi=mi)
                else:
                    beam(bm, r[k2], r2[k], brace, mi=mi)


# ------------------------------------------------------------------ curved
def add_torus(bm, R, r, center=(0, 0, 0), rot=(0, 0, 0), segs=32, rsegs=10, mi=0, arc=TAU, scale=(1, 1, 1)):
    """A torus about local Z (or an open arc of one, capped)."""
    M = xform(center, rot, scale)
    closed = arc >= TAU - 1e-6
    n = segs if closed else segs + 1
    rings = []
    for i in range(n):
        u = arc * i / segs
        cu, su = math.cos(u), math.sin(u)
        ring = []
        for j in range(rsegs):
            v = TAU * j / rsegs
            cv, sv = math.cos(v), math.sin(v)
            ring.append(bm.verts.new(M @ Vector(((R + r * cv) * cu, (R + r * cv) * su, r * sv))))
        rings.append(ring)
    for i in range(n if closed else n - 1):
        i2 = (i + 1) % n
        for j in range(rsegs):
            j2 = (j + 1) % rsegs
            bm.faces.new((rings[i][j], rings[i2][j], rings[i2][j2], rings[i][j2]))
    if not closed:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    verts = [v for ring in rings for v in ring]
    return _finish(bm, verts, mi, None, False, 0.0, 1)


def catenary_pts(p0, p1, sag, n=14):
    p0, p1 = Vector(p0), Vector(p1)
    out = []
    for i in range(n + 1):
        s = i / n
        p = p0.lerp(p1, s)
        p.z -= 4.0 * sag * s * (1 - s)
        out.append(p)
    return out


def cable(bm, p0, p1, sag, radius=0.08, n=14, segs=5, mi=0):
    pts = catenary_pts(p0, p1, sag, n)
    return L.add_tube(bm, pts, [radius] * len(pts), segs=segs, mi=mi)


def bolt_points(p0, p1, rng, depth=5, jag=0.16):
    """A lightning arc by midpoint displacement: jagged, never a smooth curve."""
    pts = [Vector(p0), Vector(p1)]
    t = (pts[1] - pts[0])
    side_a = t.cross(Vector((0, 0, 1)))
    if side_a.length < 1e-4:
        side_a = Vector((1, 0, 0))
    side_a.normalize()
    side_b = t.cross(side_a).normalized()
    amp = t.length * jag
    for _ in range(depth):
        nxt = [pts[0]]
        for i in range(len(pts) - 1):
            a, b = pts[i], pts[i + 1]
            m = (a + b) / 2 + side_a * rng.uniform(-amp, amp) + side_b * rng.uniform(-amp, amp) * 0.6
            nxt += [m, b]
        pts = nxt
        amp *= 0.52
    return pts


def add_bolt(bm, p0, p1, rng, r=0.16, mi=0, forks=2, depth=5, jag=0.16):
    pts = bolt_points(p0, p1, rng, depth, jag)
    n = len(pts)
    radii = [r * (0.55 + 0.45 * math.sin(math.pi * i / (n - 1))) for i in range(n)]
    L.add_tube(bm, pts, radii, segs=5, mi=mi)
    for _ in range(forks):
        i = rng.randrange(n // 4, 3 * n // 4)
        a = pts[i]
        d = (Vector(p1) - Vector(p0)).length * rng.uniform(0.18, 0.32)
        dirv = (pts[min(n - 1, i + 3)] - a).normalized()
        dirv += Vector((rng.uniform(-0.9, 0.9), rng.uniform(-0.9, 0.9), rng.uniform(-0.8, 0.3)))
        b = a + dirv.normalized() * d
        fp = bolt_points(a, b, rng, depth - 2, jag * 1.2)
        L.add_tube(bm, fp, [r * 0.55 * (1 - k / len(fp)) + 0.02 for k in range(len(fp))], segs=4, mi=mi)


def insulator_stack(bm, base, n, r_shed, r_core, pitch, mi=0, down=False, segs=12, cap_mi=None):
    """Ceramic sheds on a core: standing on `base` (or hanging from it when
    down=True). Returns the far end."""
    x, y, z = base
    s = -1 if down else 1
    length = n * pitch
    L.add_cyl(bm, r_core, r_core, length, (x, y, z + s * length / 2), segs=segs, mi=mi)
    for i in range(n):
        zc = z + s * (i + 0.5) * pitch
        rr = r_shed * (1.0 if i % 2 == 0 else 0.82)
        L.add_cyl(bm, rr, rr * 0.92, pitch * 0.34, (x, y, zc), segs=segs, mi=mi)
    end = (x, y, z + s * length)
    if cap_mi is not None:
        L.add_cyl(bm, r_core * 1.25, r_core * 1.25, 0.22, (x, y, end[2]), segs=segs, mi=cap_mi)
    return end


def arched_opening(bm, center, width, height, depth, mi=0, axis='Y', segs=10):
    """A flat panel with a round-arched head (a window or door infill),
    `center` at its sill middle; it faces along `axis` (Y: panel in XZ)."""
    x, y, z = center
    rect_h = height - width / 2
    if axis == 'Y':
        L.add_box(bm, (width, depth, rect_h), (x, y, z + rect_h / 2), mi=mi)
        L.add_cyl(bm, width / 2, width / 2, depth, (x, y, z + rect_h), rot=(math.pi / 2, 0, 0), segs=segs * 2, mi=mi)
    else:
        L.add_box(bm, (depth, width, rect_h), (x, y, z + rect_h / 2), mi=mi)
        L.add_cyl(bm, width / 2, width / 2, depth, (x, y, z + rect_h), rot=(0, math.pi / 2, 0), segs=segs * 2, mi=mi)


def finalize(bm):
    """Consistent outward normals on every closed part."""
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


# ------------------------------------------------------------------ materials
_M = L._M


def _obj_coord(nt):
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    return tc, sep


def _math(nt, op, a, b=None, v=None):
    m = nt.nodes.new("ShaderNodeMath")
    m.operation = op
    if isinstance(a, (int, float)):
        m.inputs[0].default_value = a
    else:
        nt.links.new(a, m.inputs[0])
    if b is not None:
        if isinstance(b, (int, float)):
            m.inputs[1].default_value = b
        else:
            nt.links.new(b, m.inputs[1])
    return m.outputs[0]


def _mix_rgb(nt, fac, c1, c2):
    mx = nt.nodes.new("ShaderNodeMix")
    mx.data_type = 'RGBA'
    if isinstance(fac, (int, float)):
        L.sock(mx.inputs, "Factor_Float").default_value = fac
    else:
        nt.links.new(fac, L.sock(mx.inputs, "Factor_Float"))
    for ident, c in (("A_Color", c1), ("B_Color", c2)):
        if isinstance(c, tuple):
            L.sock(mx.inputs, ident).default_value = c
        else:
            nt.links.new(c, L.sock(mx.inputs, ident))
    return L.sock(mx.outputs, "Result_Color")


def _bump(nt, b, height, strength):
    bp = nt.nodes.new("ShaderNodeBump")
    bp.inputs["Strength"].default_value = strength
    nt.links.new(height, bp.inputs["Height"])
    nt.links.new(bp.outputs["Normal"], b.inputs["Normal"])


def winding_mat(name, copper, gap, pitch=0.32, rough=0.32, axis='Z'):
    """Close-wound copper wire along the object's `axis`: bright turns,
    dark gaps."""
    if name in _M:
        return _M[name]
    m, nt, b = L._new_mat(name)
    tc, sep = _obj_coord(nt)
    f = _math(nt, 'FRACT', _math(nt, 'DIVIDE', sep.outputs[axis], pitch))
    band = _math(nt, 'GREATER_THAN', _math(nt, 'ABSOLUTE', _math(nt, 'SUBTRACT', f, 0.5)), 0.38)
    nt.links.new(_mix_rgb(nt, band, copper, gap), b.inputs["Base Color"])
    nt.links.new(_math(nt, 'MULTIPLY_ADD', band, -0.9, 1.0), b.inputs["Metallic"])
    b.inputs["Roughness"].default_value = rough
    _bump(nt, b, band, 0.35)
    _M[name] = m
    return m


def corrugated_mat(name, color, pitch=0.6, axis='X', rough=0.5, metal=0.35, strength=0.5, jitter=0.0):
    """Corrugated sheet: sinusoidal ribs every `pitch` studs across `axis`."""
    if name in _M:
        return _M[name]
    m, nt, b = L._new_mat(name)
    tc, sep = _obj_coord(nt)
    s = _math(nt, 'SINE', _math(nt, 'MULTIPLY', sep.outputs[axis], TAU / pitch))
    nt.links.new(L._tinted(nt, color, jitter, 0.06), b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    _bump(nt, b, s, strength)
    _M[name] = m
    return m


def chainlink_mat(name, color, cell=0.7, wire=0.2):
    """Galvanised chain-link: a diamond lattice cut out of the panel's alpha.
    The horizontal coordinate is x + y, so any axis-aligned fence works."""
    if name in _M:
        return _M[name]
    m, nt, b = L._new_mat(name)
    tc, sep = _obj_coord(nt)
    h = _math(nt, 'ADD', sep.outputs['X'], sep.outputs['Y'])
    outs = []
    for op in ('ADD', 'SUBTRACT'):
        s = _math(nt, op, h, sep.outputs['Z'])
        f = _math(nt, 'FRACT', _math(nt, 'DIVIDE', s, cell))
        outs.append(_math(nt, 'GREATER_THAN', _math(nt, 'ABSOLUTE', _math(nt, 'SUBTRACT', f, 0.5)), 0.5 - wire / 2))
    alpha = _math(nt, 'MAXIMUM', outs[0], outs[1])
    b.inputs["Base Color"].default_value = color
    b.inputs["Metallic"].default_value = 0.7
    b.inputs["Roughness"].default_value = 0.45
    nt.links.new(alpha, b.inputs["Alpha"])
    _M[name] = m
    return m


def stripe_mat(name, c1, c2, width=0.9, rough=0.55):
    """Diagonal safety stripes in object space (x + y + z)."""
    if name in _M:
        return _M[name]
    m, nt, b = L._new_mat(name)
    tc, sep = _obj_coord(nt)
    s = _math(nt, 'ADD', _math(nt, 'ADD', sep.outputs['X'], sep.outputs['Y']), sep.outputs['Z'])
    band = _math(nt, 'LESS_THAN', _math(nt, 'FRACT', _math(nt, 'DIVIDE', s, 2 * width)), 0.5)
    nt.links.new(_mix_rgb(nt, band, c2, c1), b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = rough
    _M[name] = m
    return m


def glass_mat(name, color, rough=0.04, trans=0.95, ior=1.45):
    return L.mat(name, color, rough=rough, trans=trans, ior=ior, spec=0.6)


def gravel_mat(name, c1, c2, scale=3.5, rough=0.95):
    if name in _M:
        return _M[name]
    m, nt, b = L._new_mat(name)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    vo = nt.nodes.new("ShaderNodeTexVoronoi")
    vo.inputs["Scale"].default_value = scale
    nt.links.new(tc.outputs["Object"], vo.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = c1
    ramp.color_ramp.elements[1].color = c2
    nt.links.new(vo.outputs["Distance"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = rough
    _bump(nt, b, vo.outputs["Distance"], 0.4)
    _M[name] = m
    return m


def yard_floor_mat(name, c_field, c_patch, c_lane, c_joint, lane_half=12.0, half_d=100.0,
                   slab=24.0, lane_slab=6.0, rough=0.88):
    """The Thunderworks catching floor: dark blue-grey asphalt with soft
    patches and faint slab joints, and a paler concrete service road down
    |x| < lane_half with cross joints. No yellow anywhere on it: the Storm
    hazard draws pale yellow circles on this floor."""
    m, nt, b = L._new_mat(name)
    tc, sep = _obj_coord(nt)
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 0.03
    nz.inputs["Detail"].default_value = 3.0
    nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.38
    ramp.color_ramp.elements[0].color = c_field
    ramp.color_ramp.elements[1].position = 0.64
    ramp.color_ramp.elements[1].color = c_patch
    nt.links.new(nz.outputs["Factor"], ramp.inputs["Fac"])
    col = ramp.outputs["Color"]

    def joints(coord, period, width):
        f = _math(nt, 'FRACT', _math(nt, 'DIVIDE', coord, period))
        return _math(nt, 'LESS_THAN', _math(nt, 'ABSOLUTE', _math(nt, 'SUBTRACT', f, 0.5)), width / period / 2)

    # slab joints, only faint
    jx = joints(_math(nt, 'ADD', sep.outputs['X'], slab / 2), slab, 0.35)
    jy = joints(sep.outputs['Y'], slab, 0.35)
    jj = _math(nt, 'MULTIPLY', _math(nt, 'MAXIMUM', jx, jy), 0.55)
    col = _mix_rgb(nt, jj, col, c_joint)
    # the service road
    ax = _math(nt, 'ABSOLUTE', sep.outputs['X'])
    road = _math(nt, 'LESS_THAN', ax, lane_half)
    inside = _math(nt, 'LESS_THAN', _math(nt, 'ABSOLUTE', sep.outputs['Y']), half_d + 2)
    road = _math(nt, 'MULTIPLY', road, inside)
    nz2 = nt.nodes.new("ShaderNodeTexNoise")
    nz2.inputs["Scale"].default_value = 0.2
    nz2.inputs["Detail"].default_value = 2.0
    nt.links.new(tc.outputs["Object"], nz2.inputs["Vector"])
    lane_col = _mix_rgb(nt, _math(nt, 'MULTIPLY', nz2.outputs["Factor"], 0.25), c_lane,
                        tuple(min(1.0, v * 1.12) for v in c_lane[:3]) + (1.0,))
    lj = _math(nt, 'MAXIMUM', joints(sep.outputs['Y'], lane_slab, 0.18),
               _math(nt, 'LESS_THAN', _math(nt, 'ABSOLUTE', _math(nt, 'SUBTRACT', ax, lane_half - 0.3)), 0.3))
    lane_col = _mix_rgb(nt, _math(nt, 'MULTIPLY', lj, 0.6), lane_col, c_joint)
    col = _mix_rgb(nt, road, col, lane_col)
    nt.links.new(col, b.inputs["Base Color"])
    nz3 = nt.nodes.new("ShaderNodeTexNoise")
    nz3.inputs["Scale"].default_value = 1.2
    nz3.inputs["Detail"].default_value = 4.0
    nt.links.new(tc.outputs["Object"], nz3.inputs["Vector"])
    _bump(nt, b, nz3.outputs["Factor"], 0.08)
    b.inputs["Roughness"].default_value = rough
    L._M[name] = m
    return m


def moor_mat(name, c1, c2, scale=0.05):
    """Rough storm heath for the strips outside the walls."""
    if name in _M:
        return _M[name]
    m, nt, b = L._new_mat(name)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = scale
    nz.inputs["Detail"].default_value = 4.0
    nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.35
    ramp.color_ramp.elements[0].color = c1
    ramp.color_ramp.elements[1].position = 0.7
    ramp.color_ramp.elements[1].color = c2
    nt.links.new(nz.outputs["Factor"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.92
    nz2 = nt.nodes.new("ShaderNodeTexNoise")
    nz2.inputs["Scale"].default_value = 2.0
    nt.links.new(tc.outputs["Object"], nz2.inputs["Vector"])
    _bump(nt, b, nz2.outputs["Factor"], 0.25)
    _M[name] = m
    return m


class TWMats:
    """The Thunderworks palette, resolved once per scene. Tones follow the
    current Thunderworks.luau: dark blue-grey yard, teal equipment, cream
    ceramic, copper, and a worn yellow kept to machinery only."""

    def __init__(self):
        self.concrete = L.mat("tw_concrete", rgb(122, 131, 145), rough=0.85, jitter=0.05, rand=0.04)
        self.concrete_mid = L.mat("tw_concrete_mid", rgb(98, 106, 120), rough=0.85, jitter=0.05, rand=0.04)
        self.concrete_dk = L.mat("tw_concrete_dk", rgb(72, 79, 92), rough=0.85, jitter=0.05)
        self.steel = L.mat("tw_steel", rgb(150, 158, 170), rough=0.42, metal=0.75)
        self.steel_dk = L.mat("tw_steel_dk", rgb(96, 104, 116), rough=0.45, metal=0.7)
        self.graphite = L.mat("tw_graphite", rgb(52, 57, 66), rough=0.55, metal=0.3)
        self.teal = L.mat("tw_teal", rgb(40, 132, 140), rough=0.5, metal=0.25, jitter=0.03, rand=0.04)
        self.teal_dk = L.mat("tw_teal_dk", rgb(28, 88, 96), rough=0.5, metal=0.25)
        self.cream = L.mat("tw_cream", rgb(238, 229, 208), rough=0.22, coat=0.4)
        self.copper = L.mat("tw_copper", rgb(204, 116, 64), rough=0.3, metal=1.0)
        self.copper_dk = L.mat("tw_copper_dk", rgb(150, 82, 46), rough=0.38, metal=1.0)
        self.verdigris = L.mat("tw_verdigris", rgb(92, 168, 146), rough=0.55, metal=0.25, jitter=0.06, rand=0.04)
        self.alu = L.mat("tw_alu", rgb(214, 220, 228), rough=0.16, metal=1.0)
        self.brick = L.brick_mat("tw_brick", rgb(150, 76, 58), rgb(176, 160, 142), 1.0, 0.45, rough=0.85)
        self.brick_dk = L.brick_mat("tw_brick_dk", rgb(118, 60, 48), rgb(150, 136, 120), 1.0, 0.45, rough=0.85)
        self.stone = L.mat("tw_stone", rgb(196, 186, 166), rough=0.8, jitter=0.05)
        self.masonry = L.brick_mat("tw_masonry", rgb(118, 122, 132), rgb(88, 92, 102), 2.6, 1.3, rough=0.9)
        self.slate = L.mat("tw_slate", rgb(66, 74, 90), rough=0.7, jitter=0.08)
        self.window = L.mat("tw_window", rgb(255, 214, 138), emit=3.2, emit_color=rgb(255, 204, 120), rough=0.2)
        self.window_dim = L.mat("tw_window_dim", rgb(120, 150, 170), rough=0.08, coat=0.6, spec=0.8)
        self.glass = glass_mat("tw_glass", rgb(210, 236, 232))
        self.lamp = L.mat("tw_lamp", rgb(255, 226, 170), emit=8.0, emit_color=rgb(255, 214, 150))
        self.arc = L.mat("tw_arc", rgb(150, 188, 255), emit=24.0, emit_color=rgb(130, 176, 255))
        self.arc_violet = L.mat("tw_arc_violet", rgb(214, 196, 255), emit=30.0, emit_color=rgb(200, 176, 255))
        self.glow_ring = L.mat("tw_glow_ring", rgb(170, 200, 255), emit=6.0, emit_color=rgb(160, 190, 255), rough=0.2)
        self.red = L.mat("tw_red", rgb(196, 52, 44), rough=0.5)
        self.red_lamp = L.mat("tw_red_lamp", rgb(255, 70, 50), emit=6.0)
        self.white = L.mat("tw_white", rgb(244, 244, 240), rough=0.5)
        self.black = L.mat("tw_black", rgb(26, 28, 32), rough=0.6)
        self.rubber = L.mat("tw_rubber", rgb(34, 36, 40), rough=0.8)
        self.timber = L.plank_mat("tw_timber", rgb(142, 102, 68), board=0.9)
        self.timber_dk = L.mat("tw_timber_dk", rgb(92, 66, 46), rough=0.85, jitter=0.08, rand=0.08)
        self.sleeper = L.mat("tw_sleeper", rgb(78, 62, 50), rough=0.9, jitter=0.1, rand=0.1)
        self.rail = L.mat("tw_rail", rgb(170, 170, 176), rough=0.3, metal=0.9)
        self.yellow_worn = L.mat("tw_yellow_worn", rgb(172, 141, 56), rough=0.6)
        self.hazard = stripe_mat("tw_hazard", rgb(172, 141, 56), rgb(44, 48, 56), width=0.8)
        self.redwhite = stripe_mat("tw_redwhite", rgb(196, 52, 44), rgb(240, 238, 232), width=0.9)
        self.gravel = gravel_mat("tw_gravel", rgb(92, 98, 110), rgb(128, 134, 146))
        self.winding = winding_mat("tw_winding", rgb(214, 124, 68), rgb(70, 40, 30))
        self.winding_big = winding_mat("tw_winding_big", rgb(206, 118, 62), rgb(58, 34, 28), pitch=0.7)
        self.corr_teal = corrugated_mat("tw_corr_teal", rgb(44, 128, 132), pitch=0.7, axis='X')
        self.corr_teal_y = corrugated_mat("tw_corr_teal_y", rgb(44, 128, 132), pitch=0.7, axis='Y')
        self.corr_grey = corrugated_mat("tw_corr_grey", rgb(146, 152, 160), pitch=0.6, axis='X', metal=0.5)
        self.corr_grey_y = corrugated_mat("tw_corr_grey_y", rgb(146, 152, 160), pitch=0.6, axis='Y', metal=0.5)
        self.chainlink = chainlink_mat("tw_chainlink", rgb(176, 184, 192))
        self.rock = L.mat("tw_rock", rgb(92, 98, 112), rough=0.85, jitter=0.14, rand=0.1)
        self.rock_dk = L.mat("tw_rock_dk", rgb(70, 76, 90), rough=0.85, jitter=0.14, rand=0.1)
        self.strata = L.strata_mat("tw_strata", rgb(78, 84, 100), rgb(100, 106, 122), band=2.2)
        self.moss = L.mat("tw_moss", rgb(98, 124, 86), rough=0.9, jitter=0.12, rand=0.1)
        self.grass = L.mat("tw_grass", rgb(104, 132, 88), rough=0.9, jitter=0.12, rand=0.1)
        self.pine = L.mat("tw_pine", rgb(46, 84, 70), rough=0.8, jitter=0.1, rand=0.12)
        self.pine_dk = L.mat("tw_pine_dk", rgb(34, 64, 56), rough=0.8, jitter=0.1, rand=0.12)
        self.bark = L.mat("bark", rgb(92, 66, 48), rough=0.85, jitter=0.1)
        self.sign_face = L.mat("tw_sign_face", rgb(40, 46, 58), rough=0.5)
        self.sign_text = L.mat("tw_sign_text", rgb(255, 236, 190), rough=0.4, emit=1.2, emit_color=rgb(255, 226, 170))


def lathe(bm, profile, segs=24, mi=0, center=(0, 0, 0)):
    """A surface of revolution about Z through `profile` [(r, z), ...];
    a point with r = 0 is a pole, open ends are capped."""
    cx, cy, cz = center
    rings = []
    for (r, z) in profile:
        if r < 1e-5:
            rings.append([bm.verts.new((cx, cy, cz + z))])
        else:
            rings.append([bm.verts.new((cx + r * math.cos(TAU * k / segs), cy + r * math.sin(TAU * k / segs), cz + z))
                          for k in range(segs)])
    for i in range(len(rings) - 1):
        a, b = rings[i], rings[i + 1]
        if len(a) == 1 and len(b) == 1:
            continue
        if len(a) == 1:
            for k in range(segs):
                bm.faces.new((a[0], b[k], b[(k + 1) % segs]))
        elif len(b) == 1:
            for k in range(segs):
                bm.faces.new((a[k], b[0], a[(k + 1) % segs]))
        else:
            for k in range(segs):
                k2 = (k + 1) % segs
                bm.faces.new((a[k], a[k2], b[k2], b[k]))
    if len(rings[0]) > 1:
        bm.faces.new(list(reversed(rings[0])))
    if len(rings[-1]) > 1:
        bm.faces.new(rings[-1])
    verts = [v for r in rings for v in r]
    return _finish(bm, verts, mi, None, False, 0.0, 1)

"""Gusty Gardens meadow kit v1 - hero source models for review. Blender 5.1.
Pine, shrub, moss-rock group and flower bed, each fitted to the envelope of the
current GustyGardens.luau blockout (pineTree / shrub / gardenRock / flowerBed)
and built with the approved broadleaf's construction: modeled leaves/needles,
ridged bark, sculpted masses, restrained grain.

Source/review only: nothing here is optimized, exported, approved or integrated.
Run with -- --rebuild to replace an existing output; --no-render for source only.
The approved broadleaf A is appended for comparison, never modified on disk.
"""
import bpy, bmesh, math, random, json, sys
from pathlib import Path
from mathutils import Vector, Euler, Matrix
from mathutils import noise

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/gusty-gardens/meadow-kit-v1'
OUT.mkdir(parents=True, exist_ok=True)
if (OUT / 'GustyMeadowKit.blend').exists() and '--rebuild' not in sys.argv:
    raise RuntimeError('Existing source preserved; pass -- --rebuild explicitly.')
bpy.ops.wm.read_factory_settings(use_empty=True)
SC = bpy.context.scene
STAGE = bpy.data.collections.new('PREVIEW_ONLY'); SC.collection.children.link(STAGE)

# ------------------------------------------------------------------ materials
def material(name, color, rough=.9, grain=.1, scale=8, distance=.025):
    m = bpy.data.materials.new(name); m.diffuse_color = (*color, 1); m.use_nodes = True
    nt = m.node_tree; p = nt.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1); p.inputs['Roughness'].default_value = rough
    if grain:
        tex = nt.nodes.new('ShaderNodeTexNoise'); tex.inputs['Scale'].default_value = scale
        tex.inputs['Detail'].default_value = 4
        coord = nt.nodes.new('ShaderNodeTexCoord'); nt.links.new(coord.outputs['Object'], tex.inputs['Vector'])
        bump = nt.nodes.new('ShaderNodeBump'); bump.inputs['Strength'].default_value = grain
        bump.inputs['Distance'].default_value = distance
        nt.links.new(tex.outputs['Fac'], bump.inputs['Height']); nt.links.new(bump.outputs['Normal'], p.inputs['Normal'])
    return m

# Bark and leaf values are the approved broadleaf's, so the kit reads as one family.
BARK = material('Honey oak - warm matte ridged bark', (.20, .105, .047), .94, .25, 5)
BARK_LIGHT = material('Bark ridge highlights', (.255, .145, .065), .94, .2, 6)
LEAVES = [material('Meadow leaf %02d' % i, c, .88, .1, 18) for i, c in enumerate([
    (.045, .115, .026), (.067, .174, .032), (.10, .235, .043), (.15, .29, .058), (.21, .34, .078), (.11, .22, .042)])]
CORE = material('Deep canopy interior', (.034, .087, .021), .96, .08)
# Meadow pine: bluer and deeper than the broadleaf, warmer and brighter than Frostbite.
NEEDLES = [material('Meadow pine needles %02d' % i, c, .91, .14, 18) for i, c in enumerate([
    (.020, .070, .036), (.030, .098, .044), (.043, .125, .050), (.060, .150, .058), (.085, .180, .066), (.028, .088, .058)])]
PINE_CORE = material('Pine interior', (.016, .050, .026), .96, .06)
STONE = material('Meadow stone - warm grey', (.125, .118, .106), .86, .35, 2.6, .06)
PEBBLE = material('Pebble grey', (.16, .15, .135), .86, .25, 4, .04)
MOSS = material('Cushion moss', (.058, .135, .028), .96, .5, 9, .05)
GRASS = material('Meadow grass blade', (.11, .25, .045), .9, .08, 20)
DAISY_LEAF = material('Daisy leaf', (.052, .14, .03), .9, .1, 18)
STALK = material('Daisy stalk', (.07, .17, .035), .9, .05)
PETAL_WHITE = material('Daisy petal - warm white', (.86, .85, .80), .72, .06, 22)
PETAL_PINK = material('Daisy petal - blush pink', (.93, .51, .59), .72, .06, 22)
POLLEN = material('Daisy centre - pollen yellow', (.95, .60, .07), .8, .3, 30)
POLLEN_DEEP = material('Daisy florets - deep gold', (.78, .40, .03), .8, .2, 30)
INK = material('Review labels', (.05, .07, .06), .9, 0)

def sphere_template(u, v):
    bm = bmesh.new(); bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=1)
    bm.verts.ensure_lookup_table(); bm.verts.index_update()
    out = ([v.co.copy() for v in bm.verts], [tuple(v.index for v in f.verts) for f in bm.faces]); bm.free(); return out
SPHERE = sphere_template(12, 8)
SPHERE_LO = sphere_template(6, 4)

# ------------------------------------------------------------------ geometry
class Geo:
    """Closed-element mesh accumulator: every primitive added is watertight."""
    def __init__(self): self.v = []; self.f = []; self.m = []
    def add(self, vs, fs, mi=0):
        k = len(self.v); self.v.extend(tuple(v) for v in vs)
        self.f.extend(tuple(k + i for i in f) for f in fs); self.m.extend([mi] * len(fs))
    def oval(self, c, radii, yaw=0, mi=0, lo=False):
        sv, sf = SPHERE_LO if lo else SPHERE
        co, si = math.cos(yaw), math.sin(yaw); vs = []
        for v in sv:
            x, y, z = v.x * radii[0], v.y * radii[1], v.z * radii[2]
            vs.append((c[0] + x * co - y * si, c[1] + x * si + y * co, c[2] + z))
        self.add(vs, sf, mi)
    def tube(self, points, radii, sides=12, ridge=0, mi=0):
        points = [Vector(p) for p in points]; verts = []; faces = []
        for i, (p, r) in enumerate(zip(points, radii)):
            tangent = (points[min(i + 1, len(points) - 1)] - points[max(0, i - 1)]).normalized()
            ref = Vector((0, 1, 0)) if abs(tangent.y) < .9 else Vector((1, 0, 0))
            u = tangent.cross(ref).normalized(); v = tangent.cross(u).normalized()
            for j in range(sides):
                a = j * math.tau / sides; rr = r * (1 + ridge * math.sin(a * 7 + i * .16) + ridge * .4 * math.cos(a * 11 - i * .12))
                verts.append(p + rr * (u * math.cos(a) + v * math.sin(a)))
        faces.append(tuple(reversed(range(sides))))
        for i in range(len(points) - 1):
            for j in range(sides):
                a = i * sides + j; b = i * sides + (j + 1) % sides
                faces.append((a, b, b + sides, a + sides))
        faces.append(tuple(range((len(points) - 1) * sides, len(points) * sides)))
        self.add(verts, faces, mi)
    def leaf(self, p, direction, length, width, roll, mi, droop=.12, arch=.16):
        # The approved broadleaf leaf: folded, arched, closed.
        p = Vector(p); d = Vector(direction).normalized()
        u = d.cross(Vector((0, 0, 1)))
        if u.length < .01: u = d.cross(Vector((0, 1, 0)))
        u.normalize(); n = u.cross(d).normalized()
        u, n = u * math.cos(roll) + n * math.sin(roll), -u * math.sin(roll) + n * math.cos(roll)
        verts = [p]; faces = []
        for t, w in [(.22, .72), (.52, 1), (.8, .64)]:
            c = p + d * (length * t) + n * (length * arch * math.sin(t * math.pi))
            verts.extend([c + u * width * w, c + n * .10 * width * w, c - u * width * w, c - n * .12 * width * w])
        verts.append(p + d * length - n * length * droop)
        for j in range(4): faces.append((0, 1 + (j + 1) % 4, 1 + j))
        for k in range(2):
            for j in range(4): faces.append((1 + k * 4 + j, 1 + k * 4 + (j + 1) % 4, 5 + k * 4 + (j + 1) % 4, 5 + k * 4 + j))
        for j in range(4): faces.append((9 + j, 9 + (j + 1) % 4, 13))
        self.add(verts, faces, mi)
    def needle(self, start, direction, length, width, mi):
        # The approved Powder Fir needle: rounded, pointed, closed.
        p = Vector(start); d = Vector(direction).normalized(); side = d.cross(Vector((0, 0, 1)))
        if side.length < .01: side = d.cross(Vector((0, 1, 0)))
        side.normalize(); up = side.cross(d).normalized(); n = 5
        vs = [p]; fs = []
        for t, w in [(.22, .82), (.62, 1), (.88, .52)]:
            for j in range(n):
                a = j * math.tau / n
                vs.append(p + d * (length * t) + side * (width * w * math.cos(a)) + up * (width * .45 * w * math.sin(a)) - Vector((0, 0, length * .10 * t * t)))
        vs.append(p + d * length - Vector((0, 0, length * .1)))
        for j in range(n): fs.append((0, 1 + (j + 1) % n, 1 + j))
        for k in range(2):
            for j in range(n): fs.append((1 + k * n + j, 1 + k * n + (j + 1) % n, 1 + (k + 1) * n + (j + 1) % n, 1 + (k + 1) * n + j))
        for j in range(n): fs.append((11 + j, 11 + (j + 1) % n, 16))
        self.add(vs, fs, mi)
    def rod(self, a, b, r1, r2, mi=0, n=8):
        self.tube([a, b], [r1, r2], n, 0, mi)
    def petal(self, base, direction, up, length, width, cup, mi):
        # Spoon-shaped daisy petal: narrow claw, broad rounded blade, lifted tip.
        base = Vector(base); d = Vector(direction).normalized(); up = Vector(up).normalized()
        u = d.cross(up).normalized(); up = u.cross(d).normalized(); th = .035
        verts = [base + up * .01]; faces = []
        rings = [(.12, .30), (.38, .86), (.66, 1.0), (.88, .74)]
        for t, w in rings:
            c = base + d * (length * t) + up * (cup * t * t)
            verts.extend([c + u * width * w, c + up * th, c - u * width * w, c - up * th * .8])
        verts.append(base + d * length + up * cup * 1.05)
        for j in range(4): faces.append((0, 1 + (j + 1) % 4, 1 + j))
        for k in range(len(rings) - 1):
            for j in range(4): faces.append((1 + k * 4 + j, 1 + k * 4 + (j + 1) % 4, 5 + k * 4 + (j + 1) % 4, 5 + k * 4 + j))
        last = 1 + (len(rings) - 1) * 4
        for j in range(4): faces.append((last + j, last + (j + 1) % 4, last + 4))
        self.add(verts, faces, mi)
    def object(self, name, col, mats):
        me = bpy.data.meshes.new(name); me.from_pydata(self.v, [], self.f); me.update()
        for m in mats: me.materials.append(m)
        for p, i in zip(me.polygons, self.m): p.material_index = i; p.use_smooth = True
        bm = bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces)); bm.to_mesh(me); bm.free()
        o = bpy.data.objects.new(name, me); col.objects.link(o); return o

def activate(o):
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active = o

def modifier(o, kind, **kw):
    activate(o); mod = o.modifiers.new(kind, kind)
    for k, v in kw.items(): setattr(mod, k, v)
    bpy.ops.object.modifier_apply(modifier=mod.name)

def new_collection(name):
    col = bpy.data.collections.new(name); SC.collection.children.link(col); return col

ASSETS = []  # (code, label, collection, objects, blockout envelope)

# ================================================================== 1. PINE
# Blockout: PineTrunk 2x5.8x2 at y2.9; six PineTier discs 11.2 -> 2.8 wide,
# centres 4.4..15.15, 2.6 tall; PineCrown ball to 18.2. Envelope 11.2 x 18.2 x 11.2.
def build_pine():
    rng = random.Random(51107); col = new_collection('GG_MeadowPine_A')
    wood = Geo(); ribs = Geo(); fol = Geo()
    H, R, TIERS = 18.2, 5.55, 7
    trunk = [(0, 0, 0), (.02, .01, .5), (.05, .03, 1.5), (.06, .02, 3.2), (.02, -.03, 5.5), (-.05, .0, 8.5),
             (-.04, .04, 11.5), (.02, .03, 14.2), (.04, 0, 16.3), (.03, 0, 17.2)]
    rad = [.98, .86, .66, .56, .47, .38, .29, .2, .12, .05]
    wood.tube(trunk, rad, 24, .1)
    for j in range(7):  # root flare
        a = j * math.tau / 7 + .3; L = rng.uniform(1.3, 1.8)
        wood.tube([(math.cos(a) * L, math.sin(a) * L, .04), (math.cos(a) * L * .6, math.sin(a) * L * .6, .22),
                   (math.cos(a) * .55, math.sin(a) * .55, .8), (math.cos(a) * .42, math.sin(a) * .42, 1.8)], [.05, .2, .3, .12], 10, .08)
    for j in range(13):  # winding raised bark ribs
        a = j * math.tau / 13
        pts = [Vector(p) + Vector((math.cos(a + i * .05), math.sin(a + i * .05), 0)) * r * .97 for i, (p, r) in enumerate(zip(trunk[:6], rad[:6]))]
        ribs.tube(pts, [.05, .065, .06, .05, .04, .03], 6, 0)
    needles = 0; boughs = 0
    for tier in range(TIERS):
        u = tier / (TIERS - 1)
        z = 4.3 + (H - 6.4) * (1 - (1 - u) ** 1.22)
        r = R * (1 - u * .82) ** .92
        count = 7 if u < .35 else (6 if u < .7 else 5)
        phase = .41 + tier * 1.13
        fol.oval((0, 0, z - .35), (r * .36, r * .36, max(.3, r * .16)), 0, 0)
        for j in range(count):
            ang = phase + j * math.tau / count + rng.uniform(-.16, .16)
            L = r * rng.uniform(.9, 1.08); dz = rng.uniform(-.35, .35)
            d = Vector((math.cos(ang), math.sin(ang), 0)); side = Vector((-d.y, d.x, 0))
            W = L * rng.uniform(.30, .36)
            def pt(t, s=0, zz=0):
                return d * (L * t) + side * s + Vector((0, 0, z + dz + L * .20 * (1 - t) - L * .20 * t * t + zz))
            wood.rod(pt(.04, 0, -.16), pt(.9, 0, -.22), max(.06, L * .05), .035)
            # Dark supporting bough mass, then the modeled sprays over and around it.
            fol.oval(pt(.46, 0, -.5), (L * .3, W * .42, max(.14, L * .085)), ang, 0)
            for t in [.24, .40, .55, .69, .82]:
                for sign in [-1, 1]:
                    start = pt(t, 0, -.12)
                    a = ang + sign * (.72 + (1 - t) * .22)
                    twig = Vector((math.cos(a), math.sin(a), -.36)).normalized()
                    twiglen = W * (1.45 - .5 * t)
                    for k in range(5):
                        v = k / 4; anchor = start + twig * (twiglen * v)
                        for flank in [-1, 1]:
                            th = a + flank * rng.uniform(.42, .92)
                            dire = Vector((math.cos(th), math.sin(th), rng.uniform(-.8, -.2)))
                            ll = L * rng.uniform(.12, .19) * (1 - .25 * v) + .1
                            fol.needle(anchor, dire, ll, ll * rng.uniform(.095, .125), rng.choices(range(1, 6), [3, 4, 3, 1, 2])[0]); needles += 1
                    fol.needle(start + twig * twiglen, twig, L * .2 + .12, L * .03, 2); needles += 1
            # Upper cover: brighter sprays lying on top of the bough so it reads
            # as a full layered pad from above without any snow mantle.
            for k in range(10):
                t = .08 + k * .088
                for s in [-3, -2, -1, 0, 1, 2, 3]:
                    if abs(s) >= 2 and t < .3 or abs(s) == 3 and t < .5: continue
                    th = ang + s * .19 + rng.uniform(-.12, .12)
                    base = pt(t, W * s * .13 * (.5 + t), L * .06 * (1 - t) + .02)
                    dire = Vector((math.cos(th), math.sin(th), rng.uniform(-.05, .28)))
                    ll = L * rng.uniform(.17, .23) + .12
                    fol.needle(base, dire, ll, ll * .115, rng.choices(range(1, 6), [1, 2, 4, 4, 3])[0]); needles += 1
            boughs += 1
    for k in range(4):  # leader
        z = H - 2.7 + k * .55; rr = .75 * (1 - k / 4) + .15
        for j in range(8):
            a = j * math.tau / 8 + k * .7
            fol.needle((0, 0, z), (math.cos(a), math.sin(a), .35 - k * .05), rr * 1.5 + .2, .09, rng.randrange(2, 6)); needles += 1
    for j in range(5):
        a = j * math.tau / 5
        fol.needle((0, 0, H - .9), (math.cos(a) * .25, math.sin(a) * .25, 1), .75, .08, 4); needles += 1
    objs = [wood.object('GG_MeadowPine_A_Bark', col, [BARK]), ribs.object('GG_MeadowPine_A_BarkRidges', col, [BARK_LIGHT]),
            fol.object('GG_MeadowPine_A_Needles', col, [PINE_CORE] + NEEDLES)]
    # Uniform fit to the blockout height, then fit width without moving the trunk axis.
    pts = [v.co for o in objs for v in o.data.vertices]
    top = max(p.z for p in pts); lo = min(p.z for p in pts); s = H / (top - lo)
    reach = max(max(abs(p.x), abs(p.y)) for p in pts) * s; sxy = min(1.0, 5.6 / reach)
    for o in objs:
        for v in o.data.vertices: v.co = Vector((v.co.x * s * sxy, v.co.y * s * sxy, (v.co.z - lo) * s))
        o.data.update()
    ASSETS.append(dict(code='PINE', label='Meadow Pine', col=col, objs=objs, notes={'needles': needles, 'boughs': boughs, 'tiers': TIERS},
                       blockout_whd=[11.2, 18.2, 11.2]))

# ================================================================== 2. SHRUB
# Blockout: three balls, d = 6.6. Roblox lobe centres/sizes (x,y,z):
# (0,.36d,0) (d,.84d,.96d); (.44d,.30d,.22d) (.68d,.62d,.68d); (-.36d,.26d,-.2d) (.56d,.52d,.56d).
def rbx_to_blender(v): return Vector((v[0], -v[2], v[1]))
def build_shrub():
    rng = random.Random(61223); col = new_collection('GG_MeadowShrub_A')
    wood = Geo(); leaves = Geo(); core = Geo(); d = 6.6
    lobes = [((0, .36 * d, 0), (d, .84 * d, .96 * d), 980), ((.44 * d, .30 * d, .22 * d), (.68 * d, .62 * d, .68 * d), 560),
             ((-.36 * d, .26 * d, -.2 * d), (.56 * d, .52 * d, .56 * d), 440)]
    count = 0
    for li, (c, size, n) in enumerate(lobes):
        c = rbx_to_blender(c); rx, ry, rz = size[0] / 2 * .93, size[2] / 2 * .93, size[1] / 2 * .93
        core.oval((c.x, c.y, c.z + .1), (rx * .5, ry * .5, rz * .48), 0, 0)
        # Stems from the ground crown into each mass; visible where the skirt opens.
        for j in range(5):
            a = j * math.tau / 5 + li
            tip = c + Vector((math.cos(a) * rx * .55, math.sin(a) * ry * .55, rz * .25))
            base = Vector((c.x * .3 + math.cos(a) * .35, c.y * .3 + math.sin(a) * .35, 0))
            wood.tube([base, base.lerp(tip, .45) + Vector((0, 0, .3)), tip], [.16, .1, .02], 8, .05)
        for j in range(n):
            nz = 1 - 2 * ((j + .5) / n); a = j * 2.399963 + li * .9; rr = math.sqrt(1 - nz * nz)
            shell = rng.uniform(.55, .82) if j % 3 == 0 else rng.uniform(.84, 1.0)  # inner layer fills the gaps
            p = c + Vector((rx * rr * math.cos(a), ry * rr * math.sin(a), rz * nz)) * shell
            if p.z < .22: continue  # the shrub sits on the lawn; no leaves under it
            out = Vector((rr * math.cos(a) / rx, rr * math.sin(a) / ry, nz / rz)).normalized()
            # Shingle leaves across the surface (mostly tangent, a little outward),
            # as the broadleaf does; radial leaves read end-on and expose the core.
            tan = out.cross(Vector((0, 0, 1)))
            if tan.length < .05: tan = Vector((1, 0, 0))
            tan.normalize(); bit = out.cross(tan)
            sweep = rng.uniform(0, math.tau)
            dire = (tan * math.cos(sweep) + bit * math.sin(sweep)) + out * .55 + Vector((0, 0, .25))
            L = rng.uniform(.6, .98)
            mi = rng.choices(range(6), [1, 3, 5, 4 if nz > 0 else 1, 2 if nz > .3 else .3, 3])[0]
            leaves.leaf(p, dire, L, L * rng.uniform(.19, .25), rng.uniform(-.6, .6), mi); count += 1
    objs = [wood.object('GG_MeadowShrub_A_Stems', col, [BARK]), core.object('GG_MeadowShrub_A_Core', col, [CORE]),
            leaves.object('GG_MeadowShrub_A_Leaves', col, LEAVES)]
    ASSETS.append(dict(code='SHRUB', label='Meadow Shrub', col=col, objs=objs, notes={'leaves': count},
                       blockout_whd=[9.38, 5.15, 6.86]))

# ================================================================== 3. MOSS ROCK GROUP
# Blockout: three rotated GardenStone slabs 5.6x4.4x5, 4.2x3.4x4.6, 3.4x2.8x3.8
# at (0,1.9,0), (1.5,1.3,-.9), (-1.4,1.2,1.1). First slab is the collision proxy.
def boulder_mesh(name, seed, half, points=16, bevel=.075):
    rng = random.Random(seed); bm = bmesh.new()
    for i in range(points):
        z = 1 - 2 * (i + .5) / points; r = math.sqrt(1 - z * z); a = i * 2.39996 + rng.uniform(-.35, .35)
        s = rng.uniform(.8, 1.0); p = Vector((r * math.cos(a) * half[0], r * math.sin(a) * half[1], z * half[2])) * s
        if p.z < -half[2] * .5: p.z = -half[2] * .5 + rng.uniform(-.02, .02)   # seated base
        if p.z > half[2] * .7: p.z = half[2] * .7 + (p.z - half[2] * .7) * .35  # broad worn top plane
        bm.verts.new(p)
    res = bmesh.ops.convex_hull(bm, input=bm.verts[:])
    loose = list({id(e): e for e in res['geom_interior'] + res['geom_unused'] if isinstance(e, bmesh.types.BMVert)}.values())
    if loose: bmesh.ops.delete(bm, geom=loose, context='VERTS')
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(9), verts=bm.verts[:], edges=bm.edges[:])
    bmesh.ops.bevel(bm, geom=bm.edges[:], offset=min(half) * bevel, offset_type='OFFSET', segments=3,
                    profile=.5, affect='EDGES', clamp_overlap=True)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); SC.collection.objects.link(o); return o

def sculpt_rock(o, seed, half, voxel):
    modifier(o, 'REMESH', mode='VOXEL', voxel_size=voxel)
    me = o.data; strata = [-.12 * half[2], .3 * half[2]]
    off = Vector((seed * .173, seed * .311, seed * .07))
    for v in me.vertices:
        n = v.normal; p = v.co; disp = noise.noise(p * .7 + off) * .07 + noise.noise(p * 3.2 + off) * .02
        if abs(n.z) < .55:  # a few intentional strata on the flanks only
            for k, L in enumerate(strata):
                wobble = noise.noise(Vector((p.x * .3, p.y * .3, k)) + off) * .06 + (p.x + p.y) * .04
                disp -= .06 * math.exp(-((p.z - L - wobble) / .05) ** 2)
        v.co = p + n * disp
    me.update()

def moss_cap(rock, seed, name, top):
    """A cushion that follows gravity: top-facing faces only, organic edge from noise."""
    me = rock.data; bm = bmesh.new(); bm.from_mesh(me); bm.normal_update()
    off = Vector((seed * .41, seed * .13, 0))
    drop = [f for f in bm.faces if not (f.normal.z > .7 and f.calc_center_median().z > top and noise.noise(f.calc_center_median() * .32 + off) > -.08)]
    bmesh.ops.delete(bm, geom=drop, context='FACES')
    if not bm.faces: bm.free(); return None
    for v in bm.verts: v.co += v.normal * .02
    m2 = bpy.data.meshes.new(name); bm.to_mesh(m2); bm.free()
    o = bpy.data.objects.new(name, m2); SC.collection.objects.link(o)
    modifier(o, 'SOLIDIFY', thickness=.24, offset=1, use_rim=True)
    modifier(o, 'REMESH', mode='VOXEL', voxel_size=.05)
    modifier(o, 'SMOOTH', factor=1.0, iterations=8)
    modifier(o, 'DECIMATE', ratio=.35)
    for v in o.data.vertices: v.co += v.normal * noise.noise(v.co * 5 + off) * .025
    o.data.update(); return o

def merge_into(objs, name, col, mats):
    me = bpy.data.meshes.new(name); bm = bmesh.new()
    for o in objs:
        t = bmesh.new(); t.from_mesh(o.data); t.transform(o.matrix_world)
        tmp = bpy.data.meshes.new('tmp'); t.to_mesh(tmp); t.free(); bm.from_mesh(tmp); bpy.data.meshes.remove(tmp)
    bm.to_mesh(me); bm.free()
    for o in objs: bpy.data.objects.remove(o)
    for m in mats: me.materials.append(m)
    for p in me.polygons: p.use_smooth = True
    out = bpy.data.objects.new(name, me); col.objects.link(out); return out

def build_rocks():
    col = new_collection('GG_MossRock_A'); stones = []; mosses = []; extras = []
    specs = [((5.6, 4.4, 5.0), (0, 1.9, 0), (.18, .5, .10)), ((4.2, 3.4, 4.6), (1.5, 1.3, -.9), (-.22, 1.3, .16)),
             ((3.4, 2.8, 3.8), (-1.4, 1.2, 1.1), (.14, 2.2, -.2))]
    for i, (size, at, ang) in enumerate(specs):
        half = Vector((size[0] / 2 * .98, size[2] / 2 * .98, size[1] / 2 * 1.0))
        o = boulder_mesh('boulder%d' % i, 7100 + i * 37, half)
        sculpt_rock(o, 7100 + i * 37, half, .05)
        modifier(o, 'DECIMATE', ratio=.3)
        m = moss_cap(o, 7100 + i * 37, 'moss%d' % i, half.z * .2)
        # Roblox slab rotation (x, y-yaw, z) mapped to Blender (x, -z, y-up).
        mat = Matrix.Translation(rbx_to_blender(at) + Vector((0, 0, -.25))) @ Euler((ang[0], -ang[2], ang[1] + 1.0), 'XZY').to_matrix().to_4x4()
        for obj in [o] + ([m] if m else []): obj.matrix_world = mat
        stones.append(o)
        if m: mosses.append(m)
    rng = random.Random(7331)
    for j in range(5):  # scattered pebbles seat the group in the lawn
        a = j * math.tau / 5 + .4; r = rng.uniform(3.4, 4.3)
        half = Vector((rng.uniform(.28, .5), rng.uniform(.24, .42), rng.uniform(.16, .26)))
        p = boulder_mesh('pebble%d' % j, 7400 + j, half, 14, .22)
        modifier(p, 'REMESH', mode='VOXEL', voxel_size=.035); modifier(p, 'SMOOTH', factor=.5, iterations=2)
        p.matrix_world = Matrix.Translation((math.cos(a) * r, math.sin(a) * r * .8, half.z * .45)) @ Euler((0, 0, a * 2.3)).to_matrix().to_4x4()
        extras.append(p)
    grass = Geo()
    for k, (gx, gy) in enumerate([(-3.2, -1.9), (2.9, -2.3), (3.6, 1.6), (-2.6, 2.4), (.3, -3.1)]):
        for j in range(8):
            a = j * math.tau / 8 + k
            dire = Vector((math.cos(a) * .35, math.sin(a) * .35, 1))
            L = rng.uniform(.9, 1.6)
            grass.leaf((gx + math.cos(a) * .12, gy + math.sin(a) * .12, -.05), dire, L, .07, rng.uniform(-.5, .5), 0, droop=.28, arch=.1)
    objs = [merge_into(stones, 'GG_MossRock_A_Stone', col, [STONE]), merge_into(mosses, 'GG_MossRock_A_Moss', col, [MOSS]),
            merge_into(extras, 'GG_MossRock_A_Pebbles', col, [PEBBLE]), grass.object('GG_MossRock_A_Grass', col, [GRASS])]
    ASSETS.append(dict(code='ROCK', label='Moss Rock Group', col=col, objs=objs, notes={'boulders': 3, 'pebbles': 5, 'grass_tufts': 5},
                       blockout_whd=[8.9, 4.5, 8.2]))

# ================================================================== 4. FLOWER BED
# Blockout: FlowerBed ball 4.2x1.8x4 at y.7; seven daisies at radius .9/1.6/2.3,
# heads 2.1 across at y1.7/2.1/2.5, every sixth pink. Envelope ~6.7 x 2.7 x 6.7.
def build_flowerbed():
    rng = random.Random(81907); col = new_collection('GG_FlowerBed_A')
    mound = Geo(); leaves = Geo(); stalks = Geo(); petals = Geo(); centres = Geo()
    mound.oval((0, 0, .38), (1.85, 1.75, .62), 0, 0)
    leafcount = 0
    for j in range(230):
        nz = 1 - 2 * ((j + .5) / 230) * .62; a = j * 2.399963; rr = math.sqrt(max(0, 1 - nz * nz))
        p = Vector((2.05 * rr * math.cos(a), 1.95 * rr * math.sin(a), .12 + .75 * nz)) * rng.uniform(.84, 1.0)
        if p.z < .06: p.z = .06
        dire = Vector((math.cos(a), math.sin(a), .25 + nz * .9 + rng.uniform(-.2, .3)))
        L = rng.uniform(.62, 1.0)
        leaves.leaf(p, dire, L, L * rng.uniform(.17, .22), rng.uniform(-.7, .7), rng.choices(range(3), [2, 3, 1])[0], droop=.2, arch=.14)
        leafcount += 1
    seed = 1.7; pinks = 0
    for i in range(1, 8):
        a = seed + i * .897; r = .9 + (i % 3) * .7; h = 1.7 + (i % 3) * .4
        head = Vector((math.cos(a) * r, math.sin(a) * r, h))
        # Heads tip outward and toward the viewer's side of the bed, like real daisies.
        normal = (Vector((0, 0, 1)) + Vector((math.cos(a), math.sin(a), 0)) * rng.uniform(.28, .45)).normalized()
        root = Vector((math.cos(a) * r * .55, math.sin(a) * r * .55, .5))
        mid = root.lerp(head, .55) + Vector((math.cos(a) * .12, math.sin(a) * .12, 0))
        stalks.tube([root, mid, head - normal * .12], [.1, .085, .07], 7, 0, 0)
        for s in [-1, 1]:  # a pair of stalk leaves
            b = root.lerp(head, .35 + s * .05); th = a + s * 1.4
            stalks.leaf(b, (math.cos(th), math.sin(th), .55), .75, .14, 0, 1, droop=.2)
        u = normal.cross(Vector((0, 0, 1)))
        if u.length < .01: u = Vector((1, 0, 0))
        u.normalize(); w = normal.cross(u).normalized()
        mi = 1 if (int(seed * 10) + i) % 6 == 0 else 0
        pinks += mi
        for layer, (k, L, lift, off) in enumerate([(15, .82, 0, 0), (11, .66, .05, .5)]):
            for j in range(k):
                t = (j + off) * math.tau / k + rng.uniform(-.06, .06)
                dire = u * math.cos(t) + w * math.sin(t) + normal * (.06 if layer == 0 else .18)
                base = head + (u * math.cos(t) + w * math.sin(t)) * .3 + normal * lift
                petals.petal(base, dire, normal, rng.uniform(.92, 1.04) * L, .15, .1 + rng.uniform(0, .06), mi)
        centres.oval(head + normal * .1, (.44, .44, .2), 0, 0)
        # Floret rings give the centre a modeled texture instead of a flat glowing disc.
        for ring, (n, rr, lift) in enumerate([(16, .34, .12), (10, .2, .24), (5, .08, .29)]):
            for j in range(n):
                t = j * math.tau / n + ring * .3
                pos = head + normal * (.1 + lift * .75) + (u * math.cos(t) + w * math.sin(t)) * rr
                centres.oval(pos, (.075, .075, .06), 0, 1, lo=True)
    objs = [mound.object('GG_FlowerBed_A_Core', col, [CORE]), leaves.object('GG_FlowerBed_A_Leaves', col, [DAISY_LEAF] + LEAVES[:2]),
            stalks.object('GG_FlowerBed_A_Stalks', col, [STALK, DAISY_LEAF]), petals.object('GG_FlowerBed_A_Petals', col, [PETAL_WHITE, PETAL_PINK]),
            centres.object('GG_FlowerBed_A_Centres', col, [POLLEN, POLLEN_DEEP])]
    ASSETS.append(dict(code='FLOWER', label='Daisy Bed', col=col, objs=objs, notes={'daisies': 7, 'pink': pinks, 'leaves': leafcount},
                       blockout_whd=[6.7, 2.75, 6.7]))

build_pine(); build_shrub(); build_rocks(); build_flowerbed()

# ------------------------------------------------------------------ report
report = {'status': 'Hero source art for user review; not optimized, exported, approved or integrated',
          'unit': '1 Blender unit = 1 intended Roblox stud; Roblox (x,y,z) = Blender (x,z,-y)',
          'pivot': 'Root socket at local zero (trunk base / group centre on the ground)', 'assets': []}
for a in ASSETS:
    comps = []
    for o in a['objs']:
        me = o.data; me.calc_loop_triangles(); bm = bmesh.new(); bm.from_mesh(me)
        pts = [v.co for v in me.vertices]; lo = [min(p[i] for p in pts) for i in range(3)]; hi = [max(p[i] for p in pts) for i in range(3)]
        comps.append({'name': o.name, 'triangles': len(me.loop_triangles), 'nonmanifold_edges': sum(not e.is_manifold for e in bm.edges),
                      'degenerate_faces': sum(f.calc_area() < 1e-10 for f in bm.faces),
                      'size_roblox_whd': [hi[0] - lo[0], hi[2] - lo[2], hi[1] - lo[1]],
                      'center_roblox': [(hi[0] + lo[0]) / 2, (hi[2] + lo[2]) / 2, -(hi[1] + lo[1]) / 2]})
        bm.free()
    pts = [v.co for o in a['objs'] for v in o.data.vertices]
    lo = [min(p[i] for p in pts) for i in range(3)]; hi = [max(p[i] for p in pts) for i in range(3)]
    report['assets'].append({'code': a['code'], 'label': a['label'], 'collection': a['col'].name, **a['notes'],
                             'bounds_blender': {'min': lo, 'max': hi},
                             'dimensions_roblox_whd': [hi[0] - lo[0], hi[2] - lo[2], hi[1] - lo[1]],
                             'blockout_envelope_whd': a['blockout_whd'],
                             'triangles': sum(c['triangles'] for c in comps), 'components': comps})
(OUT / 'geometry-report.json').write_text(json.dumps(report, indent=2))
for a in report['assets']:
    print('ASSET', a['code'], 'tris', a['triangles'], 'whd', [round(x, 2) for x in a['dimensions_roblox_whd']],
          'bad', [(c['name'], c['nonmanifold_edges'], c['degenerate_faces']) for c in a['components'] if c['nonmanifold_edges'] or c['degenerate_faces']], flush=True)

# ------------------------------------------------------------------ blockouts (the "before")
BLOCK = new_collection('PREVIEW_BLOCKOUT_BEFORE')
def prim(kind, loc, size, color, rot=(0, 0, 0)):
    if kind == 'cyl': bpy.ops.mesh.primitive_cylinder_add(vertices=32, location=loc)
    elif kind == 'ball': bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, location=loc)
    else: bpy.ops.mesh.primitive_cube_add(location=loc)
    o = bpy.context.object; o.scale = (size[0] / 2, size[1] / 2, size[2] / 2); o.rotation_euler = rot
    for c in list(o.users_collection): c.objects.unlink(o)
    BLOCK.objects.link(o)
    m = bpy.data.materials.get('block %s' % str(color)) or material('block %s' % str(color), color, .7, 0)
    o.data.materials.append(m); return o
def lin(r, g, b): return tuple(((c / 255 + .055) / 1.055) ** 2.4 for c in (r, g, b))
def blockouts(xs):
    x = xs['BROADLEAF']
    prim('cube', (x, 0, 4.2), (2.6, 2.6, 8.5), lin(124, 84, 48))
    for (lx, ly, lz), d, t in [((0, 11.6, 0), 12.6, 2), ((-4.6, 9.6, 1.4), 10.4, 1), ((4.8, 9.8, -1), 10.8, 1), ((1, 9.2, 4.6), 9.8, 0),
                               ((-1.1, 10.2, -4.4), 10, 0), ((.4, 14.2, .6), 8.4, 2)]:
        prim('ball', (x + lx, -lz, ly), (d, d, d * .9), [lin(52, 116, 54), lin(74, 146, 64), lin(104, 178, 78)][t])
    x = xs['PINE']
    prim('cube', (x, 0, 2.9), (2, 2, 5.8), lin(92, 60, 34))
    for i in range(6):
        t = i / 5; d = 11.2 - t * 8.4
        c = [a + (b - a) * t * .8 for a, b in zip(lin(40, 100, 58), lin(56, 124, 68))]
        prim('cyl', (x, 0, 4.4 + i * 2.15), (d, d, 2.6), tuple(c))
    prim('ball', (x, 0, 16.4), (2.8, 2.8, 3.6), lin(56, 124, 68))
    x = xs['SHRUB']; d = 6.6
    for (c, s, col) in [((0, .36 * d, 0), (d, .84 * d, .96 * d), lin(74, 146, 64)), ((.44 * d, .3 * d, .22 * d), (.68 * d, .62 * d, .68 * d), lin(52, 116, 54)),
                        ((-.36 * d, .26 * d, -.2 * d), (.56 * d, .52 * d, .56 * d), lin(74, 146, 64))]:
        prim('ball', (x + c[0], -c[2], c[1]), (s[0], s[2], s[1]), col)
    x = xs['ROCK']
    for (s, c, ang), col in zip([((5.6, 4.4, 5), (0, 1.9, 0), (.18, 1.5, .1)), ((4.2, 3.4, 4.6), (1.5, 1.3, -.9), (-.22, 2.3, .16)),
                                 ((3.4, 2.8, 3.8), (-1.4, 1.2, 1.1), (.14, 3.2, -.2))], [lin(140, 143, 152), lin(172, 175, 183), lin(112, 116, 126)]):
        prim('cube', (x + c[0], -c[2], c[1]), (s[0], s[2], s[1]), col, (ang[0], -ang[2], ang[1]))
    x = xs['FLOWER']
    prim('ball', (x, 0, .7), (4.2, 4, 1.8), lin(74, 146, 64))
    for i in range(1, 8):
        a = 1.7 + i * .897; r = .9 + (i % 3) * .7; h = 1.7 + (i % 3) * .4
        prim('cyl', (x + math.cos(a) * r, math.sin(a) * r, h), (2.1, 2.1, .22), lin(253, 252, 248) if (17 + i) % 6 else lin(247, 190, 202))
        prim('cyl', (x + math.cos(a) * r, math.sin(a) * r, h + .14), (.9, .9, .22), lin(250, 208, 76))

# ------------------------------------------------------------------ review stage
def move(o, col):
    for c in list(o.users_collection): c.objects.unlink(o)
    col.objects.link(o); return o
def aim(o, target): o.rotation_euler = (Vector(target) - o.location).to_track_quat('-Z', 'Y').to_euler()

with bpy.data.libraries.load(str(ROOT / 'assets/gusty-gardens/broadleaf-family-v1/GustyBroadleafFamily.blend'), link=False) as (src, dst):
    dst.collections = ['GG_Broadleaf_A_Meadow']
BROAD = dst.collections[0]; SC.collection.children.link(BROAD)

XS = {'BROADLEAF': -27, 'PINE': -9, 'SHRUB': 4.5, 'ROCK': 16, 'FLOWER': 26}
for o in BROAD.objects: o.location = (XS['BROADLEAF'], 0, 0)
BROAD.instance_offset = (XS['BROADLEAF'], 0, 0)
for a in ASSETS:
    for o in a['objs']: o.location = (XS[a['code']], 0, 0)
    a['col'].instance_offset = (XS[a['code']], 0, 0)
blockouts(XS); BLOCK.hide_render = True

floor = material('Neutral review backdrop', (.53, .56, .53), .95, 0)
bpy.ops.mesh.primitive_plane_add(size=2000, location=(0, 0, -.07)); ground = move(bpy.context.object, STAGE); ground.data.materials.append(floor)
SC.world = bpy.data.worlds.new('Neutral daylight'); SC.world.use_nodes = True
SC.world.node_tree.nodes['Background'].inputs[0].default_value = (.77, .84, 1, 1)
SC.world.node_tree.nodes['Background'].inputs[1].default_value = .4
LIGHTS = []
for name, pos, energy, size, color in [('Key', (-22, -28, 38), 23000, 18, (1, .94, .83)), ('Fill', (24, -9, 26), 10000, 20, (.8, .9, 1)),
                                       ('Rim', (3, 20, 30), 17000, 15, (.95, 1, .88))]:
    bpy.ops.object.light_add(type='AREA', location=pos); o = move(bpy.context.object, STAGE); o.name = name
    o.data.energy = energy; o.data.shape = 'DISK'; o.data.size = size; o.data.color = color; LIGHTS.append((o, Vector(pos)))
def light_rig(center):
    for o, pos in LIGHTS: o.location = pos + Vector(center); aim(o, Vector(center) + Vector((0, 0, 6)))
light_rig((0, 0, 0))

LABELS = []
for code, text in [('BROADLEAF', 'APPROVED BROADLEAF A'), ('PINE', 'MEADOW PINE'), ('SHRUB', 'SHRUB'), ('ROCK', 'MOSS ROCKS'), ('FLOWER', 'DAISY BED')]:
    bpy.ops.object.text_add(location=(XS[code], -12.5, .02)); t = move(bpy.context.object, STAGE)
    t.data.body = text; t.data.align_x = 'CENTER'; t.data.size = .95; t.data.materials.append(INK); LABELS.append(t)

# 5-stud person, same marker as the broadleaf review.
MARKER = bpy.data.collections.new('PREVIEW_5_STUD_PERSON'); STAGE.children.link(MARKER)
mm = material('Scale marker clay', (.26, .29, .31), .9, 0)
for name, pos, scale in [('Head', (0, 0, 4.53), (.46, .40, .47)), ('Torso', (0, 0, 3.14), (.72, .35, .99)), ('LegL', (-.34, 0, 1.2), (.28, .3, 1.2)),
                         ('LegR', (.34, 0, 1.2), (.28, .3, 1.2)), ('ArmL', (-.91, 0, 3.05), (.23, .25, .9)), ('ArmR', (.91, 0, 3.05), (.23, .25, .9))]:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, location=pos); o = move(bpy.context.object, MARKER)
    o.name = 'Person' + name; o.scale = scale; o.data.materials.append(mm)
    for p in o.data.polygons: p.use_smooth = True
MARKER.instance_offset = (0, 0, 0)

# Player-scale meadow vignette built from collection instances, well away from the lineup.
VIG = bpy.data.collections.new('PREVIEW_MEADOW_VIGNETTE'); STAGE.children.link(VIG)
VX = 300
grassmat = material('Vignette lawn', (.16, .33, .085), .95, .15, 3)
bpy.ops.mesh.primitive_plane_add(size=140, location=(VX, 0, -.03)); move(bpy.context.object, VIG).data.materials.append(grassmat)
def inst(col, x, y, yaw, s=1.0):
    o = bpy.data.objects.new('inst ' + col.name, None); o.instance_type = 'COLLECTION'; o.instance_collection = col
    o.location = (VX + x, y, 0); o.rotation_euler = (0, 0, yaw); o.scale = (s, s, s); VIG.objects.link(o); return o
C = {a['code']: a['col'] for a in ASSETS}
for col, x, y, yaw, s in [(BROAD, -14, 22, .4, .94), (C['PINE'], 2, 26, 0, 1.0), (BROAD, 17, 21, 2.2, .98), (C['PINE'], -27, 30, 1.2, 1.05),
                          (C['PINE'], 30, 30, 2.0, .95), (C['SHRUB'], -6, 13, .8, 1.1), (C['SHRUB'], 11, 11, 2.6, .9),
                          (C['ROCK'], 3, 12, 1.7, 1.0), (C['ROCK'], -19, 11, .3, .85), (C['FLOWER'], -2, 5, 0, 1), (C['FLOWER'], 6, 3.5, 1.3, 1),
                          (C['FLOWER'], -10, 6, 2.3, 1), (C['FLOWER'], 15, 5, .6, 1), (C['SHRUB'], 22, 12, 1.4, 1.15)]:
    inst(col, x, y, yaw, s)
inst(MARKER, 1.5, -4, .3)

bpy.ops.object.camera_add(location=(0, -86, 38)); CAM = move(bpy.context.object, STAGE); SC.camera = CAM
SC.render.engine = 'CYCLES'; SC.cycles.samples = 40; SC.cycles.use_denoising = True
try:
    prefs = bpy.context.preferences.addons['cycles'].preferences
    for kind in ('OPTIX', 'CUDA'):
        try:
            prefs.compute_device_type = kind; prefs.get_devices()
            if any(d.type == kind for d in prefs.devices):
                for d in prefs.devices: d.use = d.type == kind
                SC.cycles.device = 'GPU'; break
        except Exception: pass
except Exception as e: print('GPU unavailable', e)
SC.render.resolution_percentage = 100; SC.render.image_settings.file_format = 'PNG'
SC.view_settings.view_transform = 'AgX'; SC.view_settings.look = 'AgX - Medium High Contrast'

for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D': area.spaces.active.region_3d.view_perspective = 'CAMERA'
CAM.data.type = 'ORTHO'; CAM.location = (-4, -86, 40); aim(CAM, (-4, 0, 7)); CAM.data.ortho_scale = 74
SC.render.resolution_x = 2400; SC.render.resolution_y = 1150
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'GustyMeadowKit.blend'))

def shot(name, pos, target, scale, w, h, persp=False, lens=40):
    CAM.data.type = 'PERSP' if persp else 'ORTHO'; CAM.data.lens = lens; CAM.data.ortho_scale = scale
    CAM.location = pos; aim(CAM, target); SC.render.resolution_x = w; SC.render.resolution_y = h
    SC.render.filepath = str(OUT / name)
    if '--no-render' not in sys.argv: bpy.ops.render.render(write_still=True)
    print('SHOT', name, flush=True)

only = sys.argv[sys.argv.index('--only') + 1].split(',') if '--only' in sys.argv else None
def want(key): return only is None or key in only
MARKER.hide_render = True
if want('lineup'):
    shot('meadow-kit-lineup.png', (-4, -86, 40), (-4, 0, 7), 74, 2400, 1150)
if want('before'):
    for a in ASSETS: a['col'].hide_render = True
    BROAD.hide_render = True; BLOCK.hide_render = False
    shot('meadow-kit-blockout-before.png', (-4, -86, 40), (-4, 0, 7), 74, 2400, 1150)
    for a in ASSETS: a['col'].hide_render = False
    BROAD.hide_render = False; BLOCK.hide_render = True
for t in LABELS: t.hide_render = True
HEROES = {'PINE': ((22, -34, 22), (0, 0, 8.6), 21), 'SHRUB': ((14, -22, 12), (0, 0, 2.3), 11.5),
          'ROCK': ((13, -20, 12), (0, 0, 1.8), 11), 'FLOWER': ((9, -14, 9), (0, 0, 1.3), 7.8)}
DETAILS = {'PINE': ((9, -15, 13), (1.2, -1.5, 8.2), 7.5), 'SHRUB': ((7, -11, 7), (1.2, -1.8, 3.2), 5),
           'ROCK': ((7, -11, 7.5), (0, -.6, 2.4), 5.5), 'FLOWER': ((4.2, -6.4, 5.6), (.6, -.9, 2.1), 3.4)}
for code in ['PINE', 'SHRUB', 'ROCK', 'FLOWER']:
    x = XS[code]; key = code.lower()
    light_rig((x, 0, 0))
    if want(key):
        pos, tgt, sc = HEROES[code]
        shot('%s-three-quarter.png' % key, (x + pos[0], pos[1], pos[2]), (x + tgt[0], tgt[1], tgt[2]), sc, 1300, 1300)
        pos, tgt, sc = DETAILS[code]
        shot('%s-detail.png' % key, (x + pos[0], pos[1], pos[2]), (x + tgt[0], tgt[1], tgt[2]), sc, 1300, 1000)
if want('vignette'):
    light_rig((VX, 10, 0))
    shot('meadow-kit-player-scale.png', (VX + 9, -22, 6.8), (VX + 1, 12, 4.2), 30, 1800, 1100, True, 30)
print('GUSTY_MEADOW_KIT_COMPLETE', json.dumps([(a['code'], a['triangles']) for a in report['assets']]), flush=True)

"""Starting-area bushes v1 - mockup source for review. Blender 5.1.
Three bushes for the town island, each fitted to the sites it would replace and
built with the Gusty broadleaf's leaf construction, bark and leaf materials:
  HB_GardenBush   hub garden quadrant, 7 sites   (MapBuilder GardenShrub)
  HB_PlanterShrub Atlas pavilion planters, 2     (HubLandmarks Shrub)
  HB_BorderBush   plot fence lines, 66           (PlotTemplate PP_Shrub_Cluster)
The Gusty meadow shrub hero is appended for comparison and never written to.

Source/review only: nothing here is approved, optimized, exported or integrated.
Run with -- --rebuild to replace an existing output; --no-render for source only;
--only lineup,garden,planter,border to re-render a subset.
"""
import bpy, bmesh, math, random, json, sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/hub/bushes-v1'
OUT.mkdir(parents=True, exist_ok=True)
if (OUT / 'HubBushes.blend').exists() and '--rebuild' not in sys.argv:
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

# The approved broadleaf's values, as the Gusty meadow kit uses them.
BARK = material('Honey oak - warm matte ridged bark', (.20, .105, .047), .94, .25, 5)
LEAVES = [material('Meadow leaf %02d' % i, c, .88, .1, 18) for i, c in enumerate([
    (.045, .115, .026), (.067, .174, .032), (.10, .235, .043), (.15, .29, .058), (.21, .34, .078), (.11, .22, .042)])]
# Darker than the meadow kit's core: at these sizes a gap between leaves looks
# straight onto it, and a lit mid-green ball read as a smooth patch, not depth.
CORE = material('Deep canopy interior', (.016, .042, .011), .97, .08)
INK = material('Review labels', (.05, .07, .06), .9, 0)

def sphere_template(u, v):
    bm = bmesh.new(); bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=1)
    bm.verts.ensure_lookup_table(); bm.verts.index_update()
    out = ([v.co.copy() for v in bm.verts], [tuple(v.index for v in f.verts) for f in bm.faces]); bm.free(); return out
SPHERE = sphere_template(12, 8)

# ------------------------------------------------------------------ geometry
class Geo:
    """Closed-element mesh accumulator: every primitive added is watertight."""
    def __init__(self): self.v = []; self.f = []; self.m = []
    def add(self, vs, fs, mi=0):
        k = len(self.v); self.v.extend(tuple(v) for v in vs)
        self.f.extend(tuple(k + i for i in f) for f in fs); self.m.extend([mi] * len(fs))
    def oval(self, c, radii, mi=0):
        sv, sf = SPHERE
        self.add([(c[0] + v.x * radii[0], c[1] + v.y * radii[1], c[2] + v.z * radii[2]) for v in sv], sf, mi)
    def tube(self, points, radii, sides=8, ridge=0, mi=0):
        points = [Vector(p) for p in points]; verts = []; faces = []
        for i, (p, r) in enumerate(zip(points, radii)):
            tangent = (points[min(i + 1, len(points) - 1)] - points[max(0, i - 1)]).normalized()
            ref = Vector((0, 1, 0)) if abs(tangent.y) < .9 else Vector((1, 0, 0))
            u = tangent.cross(ref).normalized(); v = tangent.cross(u).normalized()
            for j in range(sides):
                a = j * math.tau / sides; rr = r * (1 + ridge * math.sin(a * 7 + i * .16))
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
    def object(self, name, col, mats):
        me = bpy.data.meshes.new(name); me.from_pydata(self.v, [], self.f); me.update()
        for m in mats: me.materials.append(m)
        for p, i in zip(me.polygons, self.m): p.material_index = i; p.use_smooth = True
        bm = bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces)); bm.to_mesh(me); bm.free()
        o = bpy.data.objects.new(name, me); col.objects.link(o); return o

def new_collection(name):
    col = bpy.data.collections.new(name); SC.collection.children.link(col); return col
def rbx_to_blender(v): return Vector((v[0], -v[2], v[1]))
def ellipsoid_area(a, b, c, p=1.6075):
    return 4 * math.pi * (((a * b) ** p + (a * c) ** p + (b * c) ** p) / 3) ** (1 / p)

ASSETS = []

def build_bush(code, label, seed, lobes, leaf_len, sites, envelope, stems=5, density=8.0):
    """Lobes are (centre, size) in Roblox axes, root socket on the ground at zero.
    Leaf count follows each lobe's surface over the leaf area, so a small bush
    keeps readable leaves instead of shrinking the hero's into specks."""
    rng = random.Random(seed); col = new_collection(code)
    wood, leaves, core = Geo(), Geo(), Geo()
    lo, hi = leaf_len; mean = (lo + hi) / 2; f = mean / .79  # .79: the meadow shrub's mean leaf
    count = 0
    for li, (c, size) in enumerate(lobes):
        c = rbx_to_blender(c); rx, ry, rz = size[0] / 2 * .93, size[2] / 2 * .93, size[1] / 2 * .93
        core.oval((c.x, c.y, c.z + .1 * f), (rx * .44, ry * .44, rz * .42))
        # Stems from the ground crown into each mass; visible where the skirt opens.
        for j in range(stems):
            a = j * math.tau / stems + li
            tip = c + Vector((math.cos(a) * rx * .55, math.sin(a) * ry * .55, rz * .25))
            base = Vector((c.x * .3 + math.cos(a) * .35 * f, c.y * .3 + math.sin(a) * .35 * f, 0))
            wood.tube([base, base.lerp(tip, .45) + Vector((0, 0, .3 * f)), tip], [.16 * f, .1 * f, .02 * f], 8, .05)
        n = int(density * ellipsoid_area(rx, ry, rz) / (mean * mean))
        for j in range(n):
            nz = 1 - 2 * ((j + .5) / n); a = j * 2.399963 + li * .9; rr = math.sqrt(1 - nz * nz)
            shell = rng.uniform(.55, .82) if j % 3 == 0 else rng.uniform(.84, 1.0)  # inner layer fills the gaps
            p = c + Vector((rx * rr * math.cos(a), ry * rr * math.sin(a), rz * nz)) * shell
            if p.z < .22 * f: continue  # the bush sits on its bed; no leaves under it
            out = Vector((rr * math.cos(a) / rx, rr * math.sin(a) / ry, nz / rz)).normalized()
            # Shingle leaves across the surface (mostly tangent, a little outward),
            # as the broadleaf does; radial leaves read end-on and expose the core.
            tan = out.cross(Vector((0, 0, 1)))
            if tan.length < .05: tan = Vector((1, 0, 0))
            tan.normalize(); bit = out.cross(tan)
            sweep = rng.uniform(0, math.tau)
            dire = (tan * math.cos(sweep) + bit * math.sin(sweep)) + out * .55 + Vector((0, 0, .25))
            L = rng.uniform(lo, hi)
            mi = rng.choices(range(6), [1, 3, 5, 4 if nz > 0 else 1, 2 if nz > .3 else .3, 3])[0]
            leaves.leaf(p, dire, L, L * rng.uniform(.19, .25), rng.uniform(-.6, .6), mi); count += 1
    objs = [wood.object(code + '_Stems', col, [BARK]), core.object(code + '_Core', col, [CORE]),
            leaves.object(code + '_Leaves', col, LEAVES)]
    ASSETS.append(dict(code=code, label=label, col=col, objs=objs, notes={'leaves': count, 'sites': sites},
                       envelope_whd=envelope))

# Hub garden: the builder's own sizes are 6/8/10 x 4.4 x 5.6 (its Ball shape
# draws them all as 4.4 spheres). Built for the 8-wide site; 6 and 10 scale it
# 0.85 and 1.15. Same three-lobe plan as the Gusty meadow shrub, d = 5.
d = 5.0
build_bush('HB_GardenBush', 'Garden Bush', 72401, [
    ((0, .36 * d, 0), (d, .84 * d, .96 * d)),
    ((.44 * d, .30 * d, .22 * d), (.68 * d, .62 * d, .68 * d)),
    ((-.36 * d, .26 * d, -.2 * d), (.56 * d, .52 * d, .56 * d))],
    (.6, .98), 'hub garden quadrant, 7', [8.0, 4.4, 5.6])
# Atlas planters: a round, fuller mound that spills a little over the 3 x 3
# planter, rooted on its top face (the old ball sank 0.9 into it).
build_bush('HB_PlanterShrub', 'Planter Shrub', 72402, [
    ((0, 1.15, 0), (3.1, 2.3, 3.1)),
    ((.35, 1.95, -.25), (1.9, 1.5, 1.9)),
    ((-.9, .85, .55), (1.5, 1.2, 1.5))],
    (.45, .72), 'Atlas pavilion planters, 2', [3.6, 2.7, 3.6], stems=4)
# Plot fence line: the placeholder's three lobes at its offsets, 0.88 of their
# size to leave room for leaf tips inside PP_Shrub_Cluster 2.6 x 1.3 x 2.0.
s = .88
build_bush('HB_BorderBush', 'Border Bush', 72403, [
    ((0, .62, 0), (1.7 * s, 1.28 * s, 1.7 * s)),
    ((.72, .48, .28), (1.15 * s, 1.0 * s, 1.15 * s)),
    ((-.68, .44, -.24), (1.1 * s, .92 * s, 1.1 * s))],
    (.32, .5), 'plot fence lines, 66', [2.6, 1.3, 2.0], stems=3)

# ------------------------------------------------------------------ report
report = {'status': 'Mockup source for user review; not approved, optimized, exported or integrated',
          'unit': '1 Blender unit = 1 intended Roblox stud; Roblox (x,y,z) = Blender (x,z,-y)',
          'pivot': 'Root socket at local zero, on the ground at the group centre', 'assets': []}
for a in ASSETS:
    comps = []
    for o in a['objs']:
        me = o.data; me.calc_loop_triangles(); bm = bmesh.new(); bm.from_mesh(me)
        comps.append({'name': o.name, 'triangles': len(me.loop_triangles), 'nonmanifold_edges': sum(not e.is_manifold for e in bm.edges),
                      'degenerate_faces': sum(f.calc_area() < 1e-10 for f in bm.faces)})
        bm.free()
    pts = [v.co for o in a['objs'] for v in o.data.vertices]
    lo = [min(p[i] for p in pts) for i in range(3)]; hi = [max(p[i] for p in pts) for i in range(3)]
    report['assets'].append({'code': a['code'], 'label': a['label'], **a['notes'],
                             'bounds_blender': {'min': lo, 'max': hi},
                             'dimensions_roblox_whd': [hi[0] - lo[0], hi[2] - lo[2], hi[1] - lo[1]],
                             'site_envelope_whd': a['envelope_whd'],
                             'triangles': sum(c['triangles'] for c in comps), 'components': comps})
(OUT / 'geometry-report.json').write_text(json.dumps(report, indent=2))
for a in report['assets']:
    print('ASSET', a['code'], 'leaves', a['leaves'], 'tris', a['triangles'], 'whd', [round(x, 2) for x in a['dimensions_roblox_whd']],
          'bad', [(c['name'], c['nonmanifold_edges'], c['degenerate_faces']) for c in a['components'] if c['nonmanifold_edges'] or c['degenerate_faces']], flush=True)

# ------------------------------------------------------------------ the "before": today's parts at true size
def lin(r, g, b): return tuple(((c / 255 + .055) / 1.055) ** 2.4 for c in (r, g, b))
BLOCK = new_collection('PREVIEW_BLOCKOUT_BEFORE')
def prim(kind, loc, size, color, col=BLOCK):
    if kind == 'ball': bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, location=loc)
    else: bpy.ops.mesh.primitive_cube_add(location=loc)
    o = bpy.context.object; o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    for c in list(o.users_collection): c.objects.unlink(o)
    col.objects.link(o)
    if kind == 'ball':
        for p in o.data.polygons: p.use_smooth = True
    key = 'block %s' % str(color)
    m = bpy.data.materials.get(key) or material(key, color, .7, 0)
    o.data.materials.append(m); return o

XS = {'REF': -14.5, 'HB_GardenBush': -3.5, 'HB_PlanterShrub': 5, 'HB_BorderBush': 11, 'PERSON': 16}
# Supports stay in both rows: the planter box and a strip of plot deck.
SUPPORT = bpy.data.collections.new('PREVIEW_SUPPORTS'); STAGE.children.link(SUPPORT)
prim('cube', (XS['HB_PlanterShrub'], 0, .8), (3, 3, 1.6), lin(44, 81, 73), SUPPORT)
prim('cube', (XS['HB_BorderBush'], 0, .25), (4.2, 3.4, .5), lin(146, 152, 176), SUPPORT)
# A Ball part is a sphere of its smallest Size axis, which is what the game draws.
# Garden: a 4.4 sphere centred 1.6 up, on a lawn 0.22 up.
prim('ball', (XS['HB_GardenBush'], 0, 1.38), (4.4, 4.4, 4.4), lin(98, 156, 78))
# Atlas: Size 3.6 x 2.4 x 3.6, so a 2.4 sphere centred 2.7 up, on the same lawn.
prim('ball', (XS['HB_PlanterShrub'], 0, 2.48), (2.4, 2.4, 2.4), lin(87, 176, 123))
for (x, y, z), dia, c in [((0, .62, 0), 1.28, (96, 140, 72)), ((.72, .48, .28), 1.0, (128, 168, 84)), ((-.68, .44, -.24), .92, (66, 108, 58))]:
    prim('ball', (XS['HB_BorderBush'] + x, -z, .5 + y), (dia, dia, dia), lin(*c))

# Planter shrub is rooted on the planter top; the border bush on the deck.
LIFT = {'HB_GardenBush': 0, 'HB_PlanterShrub': 1.6, 'HB_BorderBush': .5}
for a in ASSETS:
    for o in a['objs']: o.location = (XS[a['code']], 0, LIFT[a['code']])

with bpy.data.libraries.load(str(ROOT / 'assets/gusty-gardens/meadow-kit-v1/GustyMeadowKit.blend'), link=False) as (src, dst):
    dst.collections = ['GG_MeadowShrub_A']
REF = dst.collections[0]; SC.collection.children.link(REF)
for o in REF.objects: o.location = (XS['REF'], 0, 0)

floor = material('Neutral review backdrop', (.53, .56, .53), .95, 0)
bpy.ops.mesh.primitive_plane_add(size=2000, location=(0, 0, -.02)); ground = bpy.context.object
for c in list(ground.users_collection): c.objects.unlink(ground)
STAGE.objects.link(ground); ground.data.materials.append(floor)
SC.world = bpy.data.worlds.new('Neutral daylight'); SC.world.use_nodes = True
SC.world.node_tree.nodes['Background'].inputs[0].default_value = (.77, .84, 1, 1)
SC.world.node_tree.nodes['Background'].inputs[1].default_value = .4
def aim(o, target): o.rotation_euler = (Vector(target) - o.location).to_track_quat('-Z', 'Y').to_euler()
LIGHTS = []
for name, pos, energy, size, color in [('Key', (-11, -14, 19), 5800, 9, (1, .94, .83)), ('Fill', (12, -4.5, 13), 2500, 10, (.8, .9, 1)),
                                       ('Rim', (1.5, 10, 15), 4200, 7.5, (.95, 1, .88))]:
    bpy.ops.object.light_add(type='AREA', location=pos); o = bpy.context.object
    for c in list(o.users_collection): c.objects.unlink(o)
    STAGE.objects.link(o); o.name = name
    o.data.energy = energy; o.data.shape = 'DISK'; o.data.size = size; o.data.color = color; LIGHTS.append((o, Vector(pos)))
def light_rig(center):
    for o, pos in LIGHTS: o.location = pos + Vector(center); aim(o, Vector(center) + Vector((0, 0, 2)))

LABELS = []
for code, text in [('REF', 'GUSTY MEADOW SHRUB\n(style reference)'), ('HB_GardenBush', 'GARDEN BUSH\nhub garden x7'),
                   ('HB_PlanterShrub', 'PLANTER SHRUB\nAtlas x2'), ('HB_BorderBush', 'BORDER BUSH\nplot fences x66')]:
    bpy.ops.object.text_add(location=(XS[code], -6.2, .01)); t = bpy.context.object
    for c in list(t.users_collection): c.objects.unlink(t)
    STAGE.objects.link(t); t.data.body = text; t.data.align_x = 'CENTER'; t.data.size = .5; t.data.materials.append(INK); LABELS.append(t)

# 5-stud person, the same marker as the broadleaf and meadow reviews.
MARKER = bpy.data.collections.new('PREVIEW_5_STUD_PERSON'); STAGE.children.link(MARKER)
mm = material('Scale marker clay', (.26, .29, .31), .9, 0)
for name, pos, scale in [('Head', (0, 0, 4.53), (.46, .40, .47)), ('Torso', (0, 0, 3.14), (.72, .35, .99)), ('LegL', (-.34, 0, 1.2), (.28, .3, 1.2)),
                         ('LegR', (.34, 0, 1.2), (.28, .3, 1.2)), ('ArmL', (-.91, 0, 3.05), (.23, .25, .9)), ('ArmR', (.91, 0, 3.05), (.23, .25, .9))]:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, location=(pos[0] + XS['PERSON'], pos[1], pos[2])); o = bpy.context.object
    for c in list(o.users_collection): c.objects.unlink(o)
    MARKER.objects.link(o); o.name = 'Person' + name; o.scale = scale; o.data.materials.append(mm)
    for p in o.data.polygons: p.use_smooth = True

bpy.ops.object.camera_add(location=(0, -40, 16)); CAM = bpy.context.object; SC.camera = CAM
SC.render.engine = 'CYCLES'; SC.cycles.samples = 64; SC.cycles.use_denoising = True
try:
    prefs = bpy.context.preferences.addons['cycles'].preferences
    for kind in ('OPTIX', 'CUDA'):
        try:
            prefs.compute_device_type = kind; prefs.get_devices()
            if any(dv.type == kind for dv in prefs.devices):
                for dv in prefs.devices: dv.use = dv.type == kind
                SC.cycles.device = 'GPU'; break
        except Exception: pass
except Exception as e: print('GPU unavailable', e)
SC.render.resolution_percentage = 100; SC.render.image_settings.file_format = 'PNG'
SC.view_settings.view_transform = 'AgX'; SC.view_settings.look = 'AgX - Medium High Contrast'
BLOCK.hide_render = True
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'HubBushes.blend'))

def shot(name, pos, target, scale, w, h, persp=False, lens=40):
    CAM.data.type = 'PERSP' if persp else 'ORTHO'; CAM.data.lens = lens; CAM.data.ortho_scale = scale
    CAM.location = pos; aim(CAM, target); SC.render.resolution_x = w; SC.render.resolution_y = h
    SC.render.filepath = str(OUT / name)
    if '--no-render' not in sys.argv: bpy.ops.render.render(write_still=True)
    print('SHOT', name, flush=True)

only = sys.argv[sys.argv.index('--only') + 1].split(',') if '--only' in sys.argv else None
def want(key): return only is None or key in only
light_rig((0, 0, 0))
LINEUP = ((-.5, -40, 17), (-.5, 0, 2.2), 40, 2400, 1000)
if want('lineup'):
    shot('bushes-lineup-after.png', *LINEUP)
    for a in ASSETS: a['col'].hide_render = True
    REF.hide_render = True; BLOCK.hide_render = False
    shot('bushes-lineup-before.png', *LINEUP)
    for a in ASSETS: a['col'].hide_render = False
    REF.hide_render = False; BLOCK.hide_render = True
for t in LABELS: t.hide_render = True
MARKER.hide_render = True
HEROES = {'HB_GardenBush': ((11, -17, 9.5), (0, 0, 2.0), 10.5), 'HB_PlanterShrub': ((6, -9, 7), (0, 0, 2.6), 6.2),
          'HB_BorderBush': ((4.2, -6.4, 4.2), (0, 0, 1.0), 3.9)}
for a in ASSETS:
    x = XS[a['code']]; key = a['code'][3:].replace('Bush', '').replace('Shrub', '').lower()
    for other in ASSETS: other['col'].hide_render = other is not a
    REF.hide_render = True
    light_rig((x, 0, 0))
    if want(key):
        pos, tgt, sc = HEROES[a['code']]
        shot('%s-three-quarter.png' % key, (x + pos[0], pos[1], pos[2]), (x + tgt[0], tgt[1], tgt[2]), sc, 1300, 1100)
print('HUB_BUSHES_COMPLETE', json.dumps([(a['code'], a['triangles']) for a in report['assets']]), flush=True)

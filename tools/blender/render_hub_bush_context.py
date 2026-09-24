"""Starting-area bushes v1 in the real town layout: matched before/after renders.

Draws a tools/world_harness.luau dump with render_region_blender's primitives
and materials. "Before" is the dump as built today. "After" hides today's bush
and tree parts and places the HubBushes.blend mockup meshes at every bush site
and the Gusty broadleaf family (the proposed Phase 1 trees) at every island-rim
and plot tree site. Both come from their source .blend files, read-only.

  lune run tools/world_harness.luau map.json
  blender -b --factory-startup -P tools/blender/render_hub_bush_context.py -- --dump map.json
      [--only garden,garden-high,plot,plot-fence,atlas] [--samples 64] [--w 1600 --h 1000]

Blender light, not Roblox's: judge form, scale and density here, never final colour.
"""
import sys, json, math, re, argparse, random
from pathlib import Path
from types import SimpleNamespace
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
import render_region_blender as RR  # its main() only runs as a -P script

OUT = ROOT / 'assets/hub/bushes-v1'
BUSHES = ROOT / 'assets/hub/bushes-v1/HubBushes.blend'
TREES = ROOT / 'assets/gusty-gardens/broadleaf-family-v1/GustyBroadleafFamily.blend'
TREE_COLS = ['GG_Broadleaf_A_Meadow', 'GG_Broadleaf_B_Spreading', 'GG_Broadleaf_C_Upright']
BUSH_COLS = ['HB_GardenBush', 'HB_PlanterShrub', 'HB_BorderBush']

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument('--dump', required=True)
ap.add_argument('--only', default=None)
ap.add_argument('--samples', type=int, default=64)
ap.add_argument('--w', type=int, default=1600)
ap.add_argument('--h', type=int, default=1000)
a = ap.parse_args(argv)

# Roblox axes -> scene axes (X east, Y = -Roblox Z, Z up), as render_region_blender.
A = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
def scene(v): return Vector((v[0], -v[2], v[1]))
def yaw(t):
    c, s = math.cos(t), math.sin(t)
    return Matrix(((c, 0, s), (0, 1, 0), (-s, 0, c)))
def rot(p):
    r = p['cf'][3:]
    return Matrix(((r[0], r[1], r[2]), (r[3], r[4], r[5]), (r[6], r[7], r[8])))

BUSH_SITE = re.compile(r'^Plots/Plot_\d+/PropSites/Shrub_\d+/PlaceholderArt$')
TREE_SITE = re.compile(r'^Plots/Plot_\d+/PropSites/Tree_\d+/PlaceholderArt$')
def old_bush(p):
    return p['name'] == 'GardenShrub' or (p['name'] == 'Shrub' and p['full'] == 'Map/Hub/AtlasKiosk') \
        or BUSH_SITE.match(p['full']) is not None
def old_tree(p):
    return (p['full'] == 'Map/Landscape/IslandRim' and p['name'] in ('Trunk', 'Canopy')) \
        or TREE_SITE.match(p['full']) is not None

# ------------------------------------------------------------------ scene
RR.reset()
RR.setup_render(SimpleNamespace(samples=a.samples, w=a.w, h=a.h, view='Standard', exposure=0.15,
                                sky='0.86,0.91,1.0', world=0.72, sun='0.55,0.45,-0.70', sun_energy=1.3))
parts = json.load(open(a.dump))
meshes = {'Block': RR.unit_block(), 'Cylinder': RR.unit_cylinder_x(), 'Ball': RR.unit_sphere()}
for me in meshes.values(): me.materials.append(None)
cols = {}
for name in ('Base', 'Old', 'New'):
    cols[name] = bpy.data.collections.new(name); bpy.context.scene.collection.children.link(cols[name])

def add_part(p, col):
    size = p['size']; shape = p.get('shape', 'Block'); mesh = p.get('mesh')
    if mesh and mesh.get('kind') == 'Sphere':
        S = Matrix.Diagonal(tuple(size[i] * mesh['scale'][i] for i in range(3))); me = meshes['Ball']
    elif shape == 'Cylinder':
        dd = min(size[1], size[2]); S = Matrix.Diagonal((size[0], dd, dd)); me = meshes['Cylinder']
    elif shape == 'Ball':
        dd = min(size); S = Matrix.Diagonal((dd, dd, dd)); me = meshes['Ball']
    else:
        S = Matrix.Diagonal(tuple(size)); me = meshes['Block']
    M = (A @ rot(p) @ S).to_4x4(); M.translation = scene(p['cf'][:3])
    ob = bpy.data.objects.new(p['name'], me); ob.matrix_world = M; col.objects.link(ob)
    ob.material_slots[0].link = 'OBJECT'
    ob.material_slots[0].material = RR.material(p['color'], p['material'], p['transparency'])

kept = 0
for p in parts:
    if p['transparency'] >= 0.999: continue
    # The harness has no player; the region chain's far cells never reach these views.
    if p['full'].startswith('Regions/') and p['cf'][2] < -420: continue
    add_part(p, cols['Old'] if old_bush(p) or old_tree(p) else cols['Base']); kept += 1
print('PARTS', kept, 'old', len(cols['Old'].objects))

# ------------------------------------------------------------------ source meshes (read-only)
def load(path, names):
    with bpy.data.libraries.load(str(path), link=False) as (src, dst):
        dst.collections = list(names)  # the loader replaces the list's items with datablocks
    out = {}
    for c in dst.collections:
        # mesh data is root-relative; object location is only the gallery offset
        out[c.name] = [(o.data, o.matrix_basis.to_3x3()) for o in c.objects if o.type == 'MESH']
    return out
KIT = load(BUSHES, BUSH_COLS); KIT.update(load(TREES, TREE_COLS))

def place(kind, site, root, R3, s):
    for me, basis in KIT[kind]:
        M = (A @ R3 @ A.transposed() @ Matrix.Diagonal((s, s, s)) @ basis).to_4x4()
        M.translation = scene(root)
        ob = bpy.data.objects.new(site, me); ob.matrix_world = M; cols['New'].objects.link(ob)

rng = random.Random(24091)
counts = {}
def count(k): counts[k] = counts.get(k, 0) + 1
PARK_TOP, ISLAND_TOP, PLANTER_TOP = 0.22, 0.04, 1.8
for i, p in enumerate(q for q in parts if q['name'] == 'GardenShrub'):
    # MapBuilder's own widths 6/8/10 become 0.85/1.0/1.15 of the 8-wide bush
    s = {6: .85, 8: 1.0, 10: 1.15}[round(p['size'][0])]
    place('HB_GardenBush', 'GardenBush', (p['cf'][0], PARK_TOP, p['cf'][2]), yaw(rng.uniform(0, math.tau)), s); count('garden')
for p in (q for q in parts if q['name'] == 'Shrub' and q['full'] == 'Map/Hub/AtlasKiosk'):
    place('HB_PlanterShrub', 'PlanterShrub', (p['cf'][0], PLANTER_TOP, p['cf'][2]), yaw(rng.uniform(0, math.tau)), 1.0); count('planter')
groups = {}
for p in parts:
    if BUSH_SITE.match(p['full']): groups.setdefault(p['full'], []).append(p)
for full, balls in sorted(groups.items()):
    # the site's own frame: the big centre lobe sits 0.62 above the deck
    big = max(balls, key=lambda q: q['size'][0])
    R3 = rot(big); c = Vector(big['cf'][:3]) - R3 @ Vector((0, .62, 0))
    place('HB_BorderBush', full, tuple(c), R3, 1.0); count('border')
rim = [p for p in parts if p['full'] == 'Map/Landscape/IslandRim' and p['name'] == 'Trunk']
for i, p in enumerate(rim):
    # today's tiered tree is ~15.5 * s tall; broadleaf A is 17.95 at scale 1
    s = .86 * p['size'][0] / 1.6
    place(TREE_COLS[i % 3], 'RimTree', (p['cf'][0], ISLAND_TOP, p['cf'][2]), yaw(rng.uniform(0, math.tau)), s); count('rim tree')
plot_trees = [p for p in parts if TREE_SITE.match(p['full']) and p['name'] == 'Trunk']
for i, p in enumerate(plot_trees):
    place(TREE_COLS[(i + 1) % 3], 'PlotTree', (p['cf'][0], ISLAND_TOP, p['cf'][2]), yaw(rng.uniform(0, math.tau)), .6); count('plot tree')
print('PLACED', json.dumps(counts))

# ------------------------------------------------------------------ cameras
platform = next(p for p in parts if p['name'] == 'Platform' and p['full'] == 'Plots/Plot_1')
PLOT_R, PLOT_P = rot(platform), Vector(platform['cf'][:3])
def plot_local(x, y, z): return tuple(PLOT_P + PLOT_R @ Vector((x, y, z)))
VIEWS = {  # Roblox world eye, look, lens mm
    'garden': ((-2, 6.2, 54), (-40, 1.6, 40), 24),  # from the spawn pad
    'garden-high': ((-2, 34, 86), (-40, 0, 40), 30),
    'plot': (plot_local(60, 24, -44), plot_local(22, 1, -2), 28),
    'plot-fence': (plot_local(-15, 5.4, 16), plot_local(-27, 1.0, -14), 26),  # inside, down the left fence
    'atlas': ((36, 5.4, -10), (40, 3.0, -31), 26),
}
sc = bpy.context.scene
cd = bpy.data.cameras.new('Cam'); cd.sensor_fit = 'HORIZONTAL'; cd.sensor_width = 36.0; cd.clip_start = .3; cd.clip_end = 20000
cam = bpy.data.objects.new('Cam', cd); sc.collection.objects.link(cam); sc.camera = cam
sc.render.film_transparent = False
only = a.only.split(',') if a.only else list(VIEWS)
for key in only:
    eye, look, lens = VIEWS[key]
    e, l = scene(eye), scene(look); fwd = (l - e).normalized()
    right = fwd.cross(Vector((0, 0, 1))).normalized(); up = right.cross(fwd).normalized()
    cam.matrix_world = Matrix.Translation(e) @ Matrix((right, up, -fwd)).transposed().to_4x4(); cd.lens = lens
    for state, old_on in (('before', True), ('after', False)):
        cols['Old'].hide_render = not old_on; cols['New'].hide_render = old_on
        sc.render.filepath = str(OUT / ('context-%s-%s.png' % (key, state)))
        bpy.ops.render.render(write_still=True)
        print('SHOT', key, state, flush=True)
print('HUB_BUSH_CONTEXT_COMPLETE', flush=True)

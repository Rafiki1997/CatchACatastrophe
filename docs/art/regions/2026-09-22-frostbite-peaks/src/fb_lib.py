# Shared helpers for the Frostbite Peaks mockup scenes: colour, materials,
# bmesh primitives and the scenery kit (rocks, snowy firs, crystals, ice,
# timber props). Blender 5.1, run headless from render_frostbite.py.
#
# Scene axes are region-local studs: +X east (the player's right walking in),
# +Y north (towards Thunderworks), +Z up, the cell floor top at z = 0. Roblox
# (x, y, z) in the region frame is Blender (x, -z, y).
import bpy
import bmesh
import math
import random
from mathutils import Vector, Matrix, Euler

TAU = math.tau


# ------------------------------------------------------------------ colour
def lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rgb(r, g, b):
    return (lin(r), lin(g), lin(b), 1.0)


# ------------------------------------------------------------------ collections
def coll(name):
    c = bpy.data.collections.get(name)
    if c is None:
        c = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(c)
    return c


# ------------------------------------------------------------------ materials
_M = {}


def sock(coll_, identifier):
    """A node socket by identifier: the Mix node has three sockets named
    'A', and only the identifier tells them apart."""
    for s_ in coll_:
        if s_.identifier == identifier:
            return s_
    raise KeyError(identifier)


def _new_mat(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    return m, nt, nt.nodes["Principled BSDF"]


def _tinted(nt, color, jitter, rand):
    """Base colour, optionally scaled by the per-face `jit` attribute and by
    the object's random value, so one material covers a whole rock field."""
    base = nt.nodes.new("ShaderNodeRGB")
    base.outputs[0].default_value = color
    if jitter <= 0 and rand <= 0:
        return base.outputs[0]
    attr = nt.nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "jit"
    f1 = nt.nodes.new("ShaderNodeMath")
    f1.operation = 'MULTIPLY_ADD'
    nt.links.new(attr.outputs["Fac"], f1.inputs[0])
    f1.inputs[1].default_value = jitter
    f1.inputs[2].default_value = 1.0
    oi = nt.nodes.new("ShaderNodeObjectInfo")
    f2 = nt.nodes.new("ShaderNodeMath")
    f2.operation = 'MULTIPLY_ADD'
    nt.links.new(oi.outputs["Random"], f2.inputs[0])
    f2.inputs[1].default_value = 2 * rand
    f2.inputs[2].default_value = 1.0 - rand
    f3 = nt.nodes.new("ShaderNodeMath")
    f3.operation = 'MULTIPLY'
    nt.links.new(f1.outputs[0], f3.inputs[0])
    nt.links.new(f2.outputs[0], f3.inputs[1])
    vm = nt.nodes.new("ShaderNodeVectorMath")
    vm.operation = 'SCALE'
    nt.links.new(base.outputs[0], vm.inputs[0])
    nt.links.new(f3.outputs[0], vm.inputs["Scale"])
    return vm.outputs[0]


def mat(name, color, rough=0.65, metal=0.0, emit=0.0, emit_color=None, trans=0.0,
        ior=1.45, alpha=1.0, sss=0.0, coat=0.0, spec=0.5, jitter=0.0, rand=0.0,
        bump=0.0, bump_scale=1.0):
    if name in _M:
        return _M[name]
    m, nt, b = _new_mat(name)
    nt.links.new(_tinted(nt, color, jitter, rand), b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    b.inputs["IOR"].default_value = ior
    b.inputs["Specular IOR Level"].default_value = spec
    if trans > 0:
        b.inputs["Transmission Weight"].default_value = trans
    if alpha < 1:
        b.inputs["Alpha"].default_value = alpha
    if sss > 0:
        b.inputs["Subsurface Weight"].default_value = sss
        b.inputs["Subsurface Radius"].default_value = (1.0, 1.0, 1.0)
        b.inputs["Subsurface Scale"].default_value = 0.4
    if coat > 0:
        b.inputs["Coat Weight"].default_value = coat
        b.inputs["Coat Roughness"].default_value = 0.08
    if emit > 0:
        b.inputs["Emission Color"].default_value = emit_color or color
        b.inputs["Emission Strength"].default_value = emit
    if bump > 0:
        tc = nt.nodes.new("ShaderNodeTexCoord")
        nz = nt.nodes.new("ShaderNodeTexNoise")
        nz.inputs["Scale"].default_value = bump_scale
        nz.inputs["Detail"].default_value = 3.0
        nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
        bp = nt.nodes.new("ShaderNodeBump")
        bp.inputs["Strength"].default_value = bump
        nt.links.new(nz.outputs["Factor"], bp.inputs["Height"])
        nt.links.new(bp.outputs["Normal"], b.inputs["Normal"])
    _M[name] = m
    return m


def brick_mat(name, color, mortar, brick_w, row_h, rough=0.8, jitter=0.0, scale=1.0, axis='X'):
    """Block-laid stone: a Brick texture in object space. Courses run along
    u = x + y, so on an axis-aligned box every vertical face reads as laid
    blocks whichever way it faces (the other axis is constant on it)."""
    if name in _M:
        return _M[name]
    m, nt, b = _new_mat(name)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    comb = nt.nodes.new("ShaderNodeCombineXYZ")
    uu = nt.nodes.new("ShaderNodeMath")
    uu.operation = 'ADD'
    nt.links.new(sep.outputs['X'], uu.inputs[0])
    nt.links.new(sep.outputs['Y'], uu.inputs[1])
    nt.links.new(uu.outputs[0], comb.inputs[0])
    nt.links.new(sep.outputs['Z'], comb.inputs[1])
    br = nt.nodes.new("ShaderNodeTexBrick")
    br.inputs["Scale"].default_value = scale
    br.inputs["Brick Width"].default_value = brick_w
    br.inputs["Row Height"].default_value = row_h
    br.inputs["Mortar Size"].default_value = 0.035
    br.inputs["Mortar Smooth"].default_value = 0.2
    br.inputs["Color1"].default_value = color
    c2 = tuple(min(1.0, v * 0.93) for v in color[:3]) + (1.0,)
    br.inputs["Color2"].default_value = c2
    br.inputs["Mortar"].default_value = mortar
    br.offset = 0.5
    nt.links.new(comb.outputs[0], br.inputs["Vector"])
    nt.links.new(br.outputs["Color"], b.inputs["Base Color"])
    bp = nt.nodes.new("ShaderNodeBump")
    bp.inputs["Strength"].default_value = 0.25
    bp.invert = True
    nt.links.new(br.outputs["Fac"], bp.inputs["Height"])
    nt.links.new(bp.outputs["Normal"], b.inputs["Normal"])
    b.inputs["Roughness"].default_value = rough
    _M[name] = m
    return m


def plank_mat(name, color, rough=0.75, board=1.0, axis='Z'):
    """Timber boards: dark seams every `board` studs across the chosen axis."""
    if name in _M:
        return _M[name]
    m, nt, b = _new_mat(name)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.wave_type = 'BANDS'
    wave.bands_direction = 'X'
    wave.wave_profile = 'SAW'
    # Blender bands repeat every 2*pi/20 texture units
    wave.inputs["Scale"].default_value = (2 * math.pi / 20.0) / board
    wave.inputs["Distortion"].default_value = 0.0
    comb = nt.nodes.new("ShaderNodeCombineXYZ")
    nt.links.new(sep.outputs[axis], comb.inputs[0])
    nt.links.new(comb.outputs[0], wave.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = tuple(v * 0.55 for v in color[:3]) + (1.0,)
    ramp.color_ramp.elements[1].position = 0.08
    ramp.color_ramp.elements[1].color = color
    nt.links.new(wave.outputs["Fac"], ramp.inputs["Fac"])
    oi = nt.nodes.new("ShaderNodeObjectInfo")
    f2 = nt.nodes.new("ShaderNodeMath")
    f2.operation = 'MULTIPLY_ADD'
    nt.links.new(oi.outputs["Random"], f2.inputs[0])
    f2.inputs[1].default_value = 0.24
    f2.inputs[2].default_value = 0.88
    vm = nt.nodes.new("ShaderNodeVectorMath")
    vm.operation = 'SCALE'
    nt.links.new(ramp.outputs["Color"], vm.inputs[0])
    nt.links.new(f2.outputs[0], vm.inputs["Scale"])
    nt.links.new(vm.outputs[0], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = rough
    _M[name] = m
    return m


# ------------------------------------------------------------------ bmesh
def new_bm():
    """A bmesh with its `jit` face layer already in place. Adding a layer to
    a bmesh that has geometry reallocates it and kills every live BMFace."""
    bm = bmesh.new()
    bm.faces.layers.float.new("jit")
    return bm


def jit_layer(bm):
    lay = bm.faces.layers.float.get("jit")
    return lay if lay is not None else bm.faces.layers.float.new("jit")


def _faces_of(verts):
    fs = set()
    for v in verts:
        fs.update(v.link_faces)
    return fs


def xform(loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    return (Matrix.Translation(Vector(loc)) @ Euler(rot).to_matrix().to_4x4()
            @ Matrix.Diagonal((scale[0], scale[1], scale[2], 1.0)))


def _finish(bm, verts, mi, rng, jit, bevel, seg):
    faces = _faces_of(verts)
    lay = jit_layer(bm)
    for f in faces:
        f.material_index = mi
        f[lay] = rng.uniform(-1, 1) if (rng and jit) else 0.0
    if bevel > 0:
        edges = list({e for v in verts for e in v.link_edges})
        bmesh.ops.bevel(bm, geom=edges, offset=bevel, segments=seg, affect='EDGES',
                        profile=0.5, clamp_overlap=True, material=mi)
    return faces


def add_box(bm, size, center=(0, 0, 0), rot=(0, 0, 0), mi=0, bevel=0.0, seg=1, rng=None, jit=False):
    r = bmesh.ops.create_cube(bm, size=1.0, matrix=xform(center, rot, size))
    return _finish(bm, r['verts'], mi, rng, jit, bevel, seg)


def add_cyl(bm, r1, r2, h, center=(0, 0, 0), rot=(0, 0, 0), segs=12, mi=0, bevel=0.0, seg=1,
            rng=None, jit=False, scale=(1, 1, 1)):
    r = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r1,
                              radius2=r2, depth=h, matrix=xform(center, rot, scale))
    return _finish(bm, r['verts'], mi, rng, jit, bevel, seg)


def add_sphere(bm, radius, center=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0), segs=12, rings=8,
               mi=0, rng=None, jit=False):
    r = bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=radius,
                                  matrix=xform(center, rot, scale))
    return _finish(bm, r['verts'], mi, rng, jit, 0.0, 1)


def add_ico(bm, radius, center=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0), subdiv=2, mi=0,
            rng=None, jit=False, lump=0.0):
    r = bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius, matrix=xform(center, rot, scale))
    if lump > 0 and rng:
        c = Vector(center)
        for v in r['verts']:
            v.co = c + (v.co - c) * (1.0 + rng.uniform(-lump, lump))
    return _finish(bm, r['verts'], mi, rng, jit, 0.0, 1)


def add_prism(bm, pts2d, z0, z1, mi=0, rng=None, jit=False):
    """Extrude a 2D polygon (counter-clockwise, x/y) from z0 to z1."""
    bot = [bm.verts.new((x, y, z0)) for x, y in pts2d]
    top = [bm.verts.new((x, y, z1)) for x, y in pts2d]
    bm.faces.new(list(reversed(bot)))
    bm.faces.new(top)
    n = len(pts2d)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((bot[i], bot[j], top[j], top[i]))
    return _finish(bm, bot + top, mi, rng, jit, 0.0, 1)


def add_tube(bm, pts, radii, segs=8, mi=0, rng=None, jit=False, cap=True):
    """A tube along a polyline, radius per point. Used for ropes, tusks, trunks."""
    rings = []
    n = len(pts)
    pts = [Vector(p) for p in pts]
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        up = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
        a = t.cross(up).normalized()
        b = t.cross(a).normalized()
        ring = []
        for k in range(segs):
            ang = k / segs * TAU
            ring.append(bm.verts.new(p + (a * math.cos(ang) + b * math.sin(ang)) * radii[i]))
        rings.append(ring)
    for i in range(n - 1):
        for k in range(segs):
            k2 = (k + 1) % segs
            bm.faces.new((rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]))
    if cap:
        if radii[0] > 1e-4:
            bm.faces.new(list(reversed(rings[0])))
        if radii[-1] > 1e-4:
            bm.faces.new(rings[-1])
    verts = [v for r in rings for v in r]
    return _finish(bm, verts, mi, rng, jit, 0.0, 1)


def snow_tops(bm, faces, snow_mi, thresh=0.55):
    bm.normal_update()
    for f in faces:
        if f.normal.z > thresh:
            f.material_index = snow_mi


def obj_from_bm(name, bm, mats, collection, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1),
                solid=True, smooth=False, tag=None):
    me = bpy.data.meshes.new(name)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    if smooth:
        me.shade_smooth()
    ob = bpy.data.objects.new(name, me)
    ob.location = loc
    ob.rotation_euler = rot
    ob.scale = scale
    collection.objects.link(ob)
    ob["solid"] = 1 if solid else 0
    if tag:
        ob["tag"] = tag
    return ob


def mesh_from_bm(name, bm, mats, smooth=False):
    me = bpy.data.meshes.new(name)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    if smooth:
        me.shade_smooth()
    return me


def place(me, name, collection, loc, rot_z=0.0, scale=1.0, solid=True, tag=None, rot=None):
    ob = bpy.data.objects.new(name, me)
    ob.location = loc
    ob.rotation_euler = rot if rot is not None else (0, 0, rot_z)
    s = scale if isinstance(scale, (tuple, list)) else (scale, scale, scale)
    ob.scale = s
    collection.objects.link(ob)
    ob["solid"] = 1 if solid else 0
    if tag:
        ob["tag"] = tag
    return ob


def box_obj(name, size, center, mat_, collection, rot=(0, 0, 0), bevel=0.0, seg=1, solid=True, tag=None):
    bm = new_bm()
    add_box(bm, size, (0, 0, 0), (0, 0, 0), 0, bevel, seg)
    return obj_from_bm(name, bm, [mat_], collection, loc=center, rot=rot, solid=solid, tag=tag)


def cyl_obj(name, r1, r2, h, center, mat_, collection, rot=(0, 0, 0), segs=16, bevel=0.0, solid=True, tag=None, smooth=False):
    bm = new_bm()
    add_cyl(bm, r1, r2, h, (0, 0, 0), (0, 0, 0), segs, 0, bevel)
    return obj_from_bm(name, bm, [mat_], collection, loc=center, rot=rot, solid=solid, tag=tag, smooth=smooth)


def text_obj(name, body, font, size, loc, mat_, collection, rot=(math.pi / 2, 0, 0), align='CENTER',
             extrude=0.04, spacing=1.0, width=None):
    cu = bpy.data.curves.new(name, 'FONT')
    cu.body = body
    cu.font = font
    cu.size = size
    cu.align_x = align
    cu.align_y = 'CENTER'
    cu.extrude = extrude
    cu.space_character = spacing
    ob = bpy.data.objects.new(name, cu)
    ob.data.materials.append(mat_)
    ob.location = loc
    ob.rotation_euler = rot
    collection.objects.link(ob)
    ob["solid"] = 0
    if width:
        # shrink to fit: measure after a depsgraph update
        bpy.context.view_layer.update()
        w = ob.dimensions.x
        if w > width:
            cu.size = size * width / w
    return ob


# ------------------------------------------------------------------ scenery kit
class Kit:
    """Materials shared by every option, resolved once per scene."""

    def __init__(self, palette=None):
        p = palette or {}
        self.snow = mat("snow", p.get("snow", rgb(238, 243, 249)), rough=0.72, sss=0.08, jitter=0.03)
        self.snow_soft = mat("snow_soft", p.get("snow_soft", rgb(228, 236, 245)), rough=0.8, sss=0.06, jitter=0.02, rand=0.03)
        self.rock = mat("rock", p.get("rock", rgb(78, 92, 116)), rough=0.85, jitter=0.14, rand=0.1)
        self.rock_dark = mat("rock_dark", p.get("rock_dark", rgb(76, 86, 106)), rough=0.85, jitter=0.14, rand=0.1)
        self.pine = mat("pine", p.get("pine", rgb(44, 94, 78)), rough=0.8, jitter=0.1, rand=0.12)
        self.pine_dark = mat("pine_dark", p.get("pine_dark", rgb(34, 74, 64)), rough=0.8, jitter=0.1, rand=0.12)
        self.bark = mat("bark", rgb(92, 66, 48), rough=0.85, jitter=0.1)
        self.ice = mat("ice", p.get("ice", rgb(168, 222, 246)), rough=0.12, trans=0.72, ior=1.31, spec=0.6, jitter=0.04)
        self.ice_opaque = mat("ice_opaque", p.get("ice_opaque", rgb(142, 200, 230)), rough=0.22, sss=0.25, coat=0.4, jitter=0.1, rand=0.06)
        self.ice_deep = mat("ice_deep", p.get("ice_deep", rgb(96, 160, 206)), rough=0.2, sss=0.2, coat=0.5, jitter=0.1, rand=0.06)
        self.timber = plank_mat("timber", rgb(156, 110, 70), board=0.9)
        self.timber_dark = mat("timber_dark", rgb(104, 72, 48), rough=0.8, jitter=0.08, rand=0.08)
        self.crate = plank_mat("crate", rgb(170, 124, 78), board=0.75, axis='Z')
        self.iron = mat("iron", rgb(64, 60, 60), rough=0.45, metal=0.6)
        self.gold = mat("gold", rgb(232, 176, 64), rough=0.32, metal=1.0)
        self.gold_deep = mat("gold_deep", rgb(180, 128, 40), rough=0.4, metal=1.0)
        self.lantern = mat("lantern", rgb(255, 214, 140), emit=7.0, emit_color=rgb(255, 206, 120))
        self.glow_warm = mat("glow_warm", rgb(255, 214, 138), emit=4.0)
        self.black = mat("black", rgb(22, 22, 30), rough=0.25, coat=0.5)
        self.white = mat("white", rgb(250, 250, 252), rough=0.4)
        self.rope = mat("rope", rgb(186, 158, 112), rough=0.9)
        self.teal = mat("teal_roof", rgb(40, 122, 124), rough=0.6, jitter=0.05)


def pine_mesh(kit, name, height, seed, tiers=4, segs=7, green=None, snow=None, lean=0.0, fat=1.0):
    """A stylised snow-laden fir: stacked jagged cones, each with a drippy
    snow skirt over its upper half."""
    rng = random.Random(seed)
    bm = new_bm()
    H = height
    trunk_h = 0.18 * H
    add_cyl(bm, 0.07 * H, 0.05 * H, trunk_h * 1.4, (0, 0, trunk_h * 0.7), segs=6, mi=2)
    z0 = trunk_h
    th = (H - z0) * 0.44
    R = 0.34 * H * fat
    for k in range(tiers):
        f = k / (tiers - 1)
        base = z0 + f * (H - z0 - th)
        r = R * (1 - 0.62 * f)
        rot = (0, 0, rng.uniform(0, TAU))
        r0 = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r,
                                   radius2=0.0, depth=th, matrix=xform((lean * f, 0, base + th / 2), rot))
        for v in r0['verts']:
            if v.co.z < base + 0.05:
                v.co.x += rng.uniform(-0.08, 0.08) * r
                v.co.y += rng.uniform(-0.08, 0.08) * r
                v.co.z += rng.uniform(-0.1, 0.08) * th
        _finish(bm, r0['verts'], 0, rng, True, 0.0, 1)
        # the snow skirt
        sb = base + th * 0.36
        sh = th * 0.72
        r1 = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r * 0.74,
                                   radius2=0.0, depth=sh, matrix=xform((lean * f, 0, sb + sh / 2), rot))
        for v in r1['verts']:
            if v.co.z < sb + 0.05:
                v.co.z += rng.uniform(-0.16, 0.04) * th
                s = 1 + rng.uniform(-0.05, 0.08)
                v.co.x = lean * f + (v.co.x - lean * f) * s
                v.co.y *= s
        _finish(bm, r1['verts'], 1, rng, True, 0.0, 1)
    return mesh_from_bm(name, bm, [green or kit.pine, snow or kit.snow, kit.bark])


def rock_obj(kit, name, size, loc, seed, collection, rock=None, snow=None, thresh=0.74, subdiv=1,
             lump=0.2, shape='ico', rot_z=None, sink=0.28, solid=True, smooth=False, tag=None, flat_top=0.0):
    """A faceted boulder whose upward faces are snow. `shape='box'` gives the
    chunky stacked-block rock; `flat_top` shaves the crown into a mesa."""
    rng = random.Random(seed)
    bm = new_bm()
    if shape == 'box':
        r = bmesh.ops.create_cube(bm, size=2.0)
        bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True)
        for v in bm.verts:
            v.co += Vector((rng.uniform(-lump, lump), rng.uniform(-lump, lump), rng.uniform(-lump, lump))) * 0.6
    else:
        bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
        for v in bm.verts:
            v.co *= 1.0 + rng.uniform(-lump, lump)
    sx, sy, sz = size
    for v in bm.verts:
        v.co.x *= sx / 2
        v.co.y *= sy / 2
        v.co.z *= sz / 2
    zmin = -sz / 2 * (1 - 2 * sink)
    zmax = sz / 2 * (1 - flat_top)
    for v in bm.verts:
        if v.co.z < zmin:
            v.co.z = zmin
        if flat_top > 0 and v.co.z > zmax:
            v.co.z = zmax
    lay = jit_layer(bm)
    bm.normal_update()
    for f in bm.faces:
        f[lay] = rng.uniform(-1, 1)
        f.material_index = 1 if (snow is not False and f.normal.z > thresh) else 0
    mats = [rock or kit.rock, (snow if snow not in (None, False) else kit.snow)]
    rz = rng.uniform(0, TAU) if rot_z is None else rot_z
    ob = obj_from_bm(name, bm, mats, collection, loc=(loc[0], loc[1], loc[2] - zmin), rot=(0, 0, rz),
                     solid=solid, smooth=smooth, tag=tag)
    return ob


def drift_obj(kit, name, size, loc, seed, collection, solid=False, mat_=None, tag=None):
    """A soft snowbank: a smooth squashed lump sitting on the ground."""
    rng = random.Random(seed)
    bm = new_bm()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
    for v in bm.verts:
        v.co *= 1.0 + rng.uniform(-0.12, 0.12)
    sx, sy, sz = size
    for v in bm.verts:
        v.co.x *= sx / 2
        v.co.y *= sy / 2
        v.co.z *= sz
        if v.co.z < -0.1 * sz:
            v.co.z = -0.1 * sz
    lay = jit_layer(bm)
    for f in bm.faces:
        f[lay] = rng.uniform(-1, 1)
    return obj_from_bm(name, bm, [mat_ or kit.snow_soft], collection, loc=loc, rot=(0, 0, rng.uniform(0, TAU)),
                       solid=solid, smooth=True, tag=tag)


def crystal_cluster(name, loc, seed, collection, mats, count=7, height=8.0, radius=1.0, spread=2.0,
                    tilt=0.45, solid=True, tag=None, base_mat=None):
    """Hexagonal crystals with pointed tips fanning out of one root."""
    rng = random.Random(seed)
    bm = new_bm()
    for i in range(count):
        h = height * (1.0 if i == 0 else rng.uniform(0.35, 0.8))
        r = radius * (1.0 if i == 0 else rng.uniform(0.45, 0.85)) * (h / height) ** 0.3
        ang = rng.uniform(0, TAU)
        d = 0.0 if i == 0 else rng.uniform(0.3, 1.0) * spread
        off = Vector((math.cos(ang) * d, math.sin(ang) * d, 0))
        tl = 0.0 if i == 0 else tilt * rng.uniform(0.5, 1.0) * (d / spread)
        rot = Euler((0, tl, ang), 'ZYX') if i else Euler((0, 0, rng.uniform(0, TAU)))
        # tilt outwards: rotate about the axis perpendicular to the offset
        axis_rot = Matrix.Rotation(tl, 4, Vector((-math.sin(ang), math.cos(ang), 0))) if i else Matrix.Identity(4)
        mi = 0 if (i % 3) else min(1, len(mats) - 1)
        body = h * 0.78
        tip = h - body
        M = Matrix.Translation(off) @ axis_rot @ Matrix.Rotation(rng.uniform(0, TAU), 4, 'Z')
        r1 = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=6, radius1=r, radius2=r * 0.92,
                                   depth=body, matrix=M @ Matrix.Translation((0, 0, body / 2 - 0.4)))
        r2 = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=6, radius1=r * 0.92, radius2=0.0,
                                   depth=tip, matrix=M @ Matrix.Translation((0, 0, body - 0.4 + tip / 2)))
        _finish(bm, r1['verts'] + r2['verts'], mi, rng, True, 0.0, 1)
    all_mats = list(mats)
    if base_mat is not None:
        add_ico(bm, spread * 0.9 + radius, (0, 0, -0.2), scale=(1, 1, 0.45), subdiv=1, mi=len(all_mats), rng=rng, jit=True)
        all_mats.append(base_mat)
    return obj_from_bm(name, bm, all_mats, collection, loc=loc, solid=solid, tag=tag)


def icicles(bm, x0, x1, y, z, rng, mi, count=None, length=(0.8, 2.6), radius=(0.18, 0.38), axis='X'):
    """A fringe of downward cones along a lip."""
    n = count or max(2, int(abs(x1 - x0) / 0.9))
    for i in range(n):
        t = (i + rng.uniform(0.2, 0.8)) / n
        L = rng.uniform(*length)
        r = rng.uniform(*radius)
        p = x0 + (x1 - x0) * t
        c = (p, y, z - L / 2) if axis == 'X' else (y, p, z - L / 2)
        r0 = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=5, radius1=0.0, radius2=r,
                                   depth=L, matrix=xform(c))
        _finish(bm, r0['verts'], mi, rng, True, 0.0, 1)


def crate_obj(kit, name, size, loc, collection, rot_z=0.0, snow=True, tag=None):
    bm = new_bm()
    sx, sy, sz = size
    add_box(bm, size, (0, 0, sz / 2), mi=0, bevel=0.06)
    # battens on the two long faces
    for s in (-1, 1):
        add_box(bm, (sx * 1.02, 0.12, 0.22 * sz), (0, s * sy / 2, sz * 0.5), mi=1)
        add_box(bm, (0.12, sy * 1.02, 0.22 * sz), (s * sx / 2, 0, sz * 0.5), mi=1)
    if snow:
        add_box(bm, (sx * 0.9, sy * 0.9, 0.22), (0, 0, sz + 0.1), mi=2, bevel=0.08)
    return obj_from_bm(name, bm, [kit.crate, kit.timber_dark, kit.snow], collection, loc=loc, rot=(0, 0, rot_z), tag=tag)


def barrel_obj(kit, name, r, h, loc, collection, snow=True, tag=None):
    bm = new_bm()
    add_cyl(bm, r, r, h, (0, 0, h / 2), segs=12, mi=0)
    for z in (0.2, 0.8):
        add_cyl(bm, r * 1.04, r * 1.04, 0.14 * h, (0, 0, h * z), segs=12, mi=1)
    if snow:
        add_cyl(bm, r * 0.9, r * 0.8, 0.2, (0, 0, h + 0.08), segs=12, mi=2)
    return obj_from_bm(name, bm, [kit.timber_dark, kit.iron, kit.snow], collection, loc=loc, tag=tag)


def lantern_post(kit, name, loc, collection, height=6.0, tag=None, post_mat=None, glow=None):
    bm = new_bm()
    add_box(bm, (0.5, 0.5, height), (0, 0, height / 2), mi=0, bevel=0.05)
    add_box(bm, (1.5, 0.3, 0.3), (0.5, 0, height - 0.3), mi=0)
    add_box(bm, (0.9, 0.9, 1.1), (1.05, 0, height - 1.35), mi=1)
    add_box(bm, (1.15, 1.15, 0.25), (1.05, 0, height - 0.7), mi=2)
    add_box(bm, (1.0, 1.0, 0.2), (1.05, 0, height - 1.95), mi=2)
    add_box(bm, (0.9, 0.9, 0.22), (0, 0, height + 0.1), mi=3, bevel=0.06)
    return obj_from_bm(name, bm, [post_mat or kit.timber_dark, glow or kit.lantern, kit.iron, kit.snow], collection, loc=loc, tag=tag)


def strata_mat(name, c1, c2, band=2.6, rough=0.85, jitter=0.1, distort=2.0):
    """Layered rock: bands of two tones stacked up the object's Z, wobbled
    by noise, with the per-face jitter on top."""
    if name in _M:
        return _M[name]
    m, nt, b = _new_mat(name)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.wave_type = 'BANDS'
    wave.bands_direction = 'Z'
    wave.wave_profile = 'SIN'
    wave.inputs["Scale"].default_value = (2 * math.pi / 20.0) / band
    wave.inputs["Distortion"].default_value = distort
    wave.inputs["Detail"].default_value = 1.0
    wave.inputs["Detail Scale"].default_value = 0.6
    nt.links.new(tc.outputs["Object"], wave.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = 'CONSTANT'
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = c1
    ramp.color_ramp.elements[1].position = 0.55
    ramp.color_ramp.elements[1].color = c2
    nt.links.new(wave.outputs["Fac"], ramp.inputs["Fac"])
    attr = nt.nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "jit"
    f1 = nt.nodes.new("ShaderNodeMath")
    f1.operation = 'MULTIPLY_ADD'
    nt.links.new(attr.outputs["Fac"], f1.inputs[0])
    f1.inputs[1].default_value = jitter
    f1.inputs[2].default_value = 1.0
    vm = nt.nodes.new("ShaderNodeVectorMath")
    vm.operation = 'SCALE'
    nt.links.new(ramp.outputs["Color"], vm.inputs[0])
    nt.links.new(f1.outputs[0], vm.inputs["Scale"])
    nt.links.new(vm.outputs[0], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = rough
    _M[name] = m
    return m


def column_obj(kit, name, r, h, loc, seed, collection, mats, segs=6, taper=0.82, lump=0.18, thresh=0.8, rot_z=None, solid=True):
    """A faceted upright column (ice or basalt-like), snow on its crown."""
    rng = random.Random(seed)
    bm = new_bm()
    r0 = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r, radius2=r * taper, depth=h,
                               matrix=Matrix.Translation((0, 0, h / 2)))
    for v in r0['verts']:
        k = 1 + rng.uniform(-lump, lump)
        v.co.x *= k
        v.co.y *= k
        if v.co.z > h * 0.5:
            v.co.z += rng.uniform(-0.12, 0.08) * h * 0.25
    lay = jit_layer(bm)
    bm.normal_update()
    for f in bm.faces:
        f[lay] = rng.uniform(-1, 1)
        f.material_index = 1 if f.normal.z > thresh else 0
    rz = rng.uniform(0, TAU) if rot_z is None else rot_z
    return obj_from_bm(name, bm, mats, collection, loc=loc, rot=(0, 0, rz), solid=solid)

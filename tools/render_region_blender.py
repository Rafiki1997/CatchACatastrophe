# Render a world_harness part dump in Blender (Cycles) from an explicit camera,
# so a region build can be put side by side with its concept image.
#
#   blender -b --factory-startup -P tools/render_region_blender.py -- \
#       --dump map.json --centre-z -915 --camera cam.json --out build.png
#
# The dump is Roblox parts (Block / Cylinder along local X / Ball) with full
# CFrames. Scene axes follow the Frostbite mockup pipeline: X east (Roblox X),
# Y north (-Roblox Z, relative to --centre-z), Z up (Roblox Y). The camera JSON
# is {"C": [x, y, z], "forward": [...], "up": [...], "fpx": f, "W": 1536,
# "H": 1024} in those scene axes; --eye x,y,z --look x,y,z --lens mm gives a
# free camera instead (player-height views).
#
# SpecialMesh spheres render as the ellipsoid they are in game.
#
# With --kit-blend and --sites the delivered Blender meshes are placed at every
# PropSite (bottom-centre, yaw, uniform scale from the site CSV the verifier
# writes) and the dump's PlaceholderArt parts are left out: a preview of the
# real art in the real layout, still under Blender light rather than Roblox's.
# Materials are approximations of Roblox's (roughness, a little bump on Snow,
# Rock and Slate, emission for Neon). Invisible parts (Transparency 1) are
# skipped, as they are in the game. This renders geometry and colour only:
# it cannot show imported MeshParts, Roblox lighting or post-processing, so it
# is for layout and proportion, never a substitute for a Studio capture.
import sys
import json
import math
import argparse

import bpy
import bmesh
from mathutils import Matrix, Vector


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--dump", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--centre-z", type=float, default=-915.0)
    ap.add_argument("--camera", default=None)
    ap.add_argument("--eye", default=None)
    ap.add_argument("--look", default=None)
    ap.add_argument("--lens", type=float, default=24.0)
    ap.add_argument("--w", type=int, default=1536)
    ap.add_argument("--h", type=int, default=1024)
    ap.add_argument("--samples", type=int, default=96)
    ap.add_argument("--zmin", type=float, default=-140.0, help="scene Y range kept")
    ap.add_argument("--zmax", type=float, default=140.0)
    ap.add_argument("--xmax", type=float, default=215.0)
    ap.add_argument("--sun", default="0.72,0.15,-0.66", help="light travel direction")
    ap.add_argument("--sun-energy", type=float, default=1.3)
    ap.add_argument("--world", type=float, default=0.72)
    ap.add_argument("--exposure", type=float, default=0.0)
    ap.add_argument("--open-gate-z", type=float, default=None,
                    help="world z of a gate to draw open (the harness has no player, so every barrier is locked)")
    ap.add_argument("--kit-blend", default=None, help="Astra's .blend; objects are appended read-only, never saved")
    ap.add_argument("--sites", default=None, help="site CSV from tools/verify_frostbite_alpine.luau")
    ap.add_argument("--view", default="Standard", help="Standard keeps authored colours comparable; AgX for a softer look")
    ap.add_argument("--sky", default="0.86,0.91,1.0", help="world colour (linear)")
    return ap.parse_args(argv)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def setup_render(a):
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    try:
        prefs = bpy.context.preferences.addons['cycles'].preferences
        prefs.compute_device_type = 'OPTIX'
        prefs.refresh_devices()
        for d in prefs.devices:
            d.use = d.type == 'OPTIX'
        sc.cycles.device = 'GPU'
    except Exception as e:  # pragma: no cover
        print("GPU setup failed, CPU render:", e)
    sc.cycles.samples = a.samples
    sc.cycles.use_adaptive_sampling = True
    sc.cycles.use_denoising = True
    sc.cycles.max_bounces = 6
    sc.render.film_transparent = True
    sc.render.resolution_x = a.w
    sc.render.resolution_y = a.h
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGBA'
    # Standard, with a soft sun and a bright sky, renders a lit top face at
    # roughly its authored colour and a shaded one at about four fifths of it,
    # which is the contrast the concept paints.
    sc.view_settings.view_transform = a.view
    if a.view == 'AgX':
        try:
            sc.view_settings.look = 'AgX - Punchy'
        except Exception:
            pass
    sc.view_settings.exposure = a.exposure
    w = bpy.data.worlds.new("World")
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs[0].default_value = tuple(float(v) for v in a.sky.split(",")) + (1.0,)
    bg.inputs[1].default_value = a.world
    sc.world = w
    ld = bpy.data.lights.new("Sun", 'SUN')
    ld.energy = a.sun_energy
    ld.angle = math.radians(3.0)
    ld.color = (1.0, 0.96, 0.9)
    sun = bpy.data.objects.new("Sun", ld)
    d = Vector(tuple(float(v) for v in a.sun.split(","))).normalized()
    sun.rotation_euler = (-d).to_track_quat('Z', 'Y').to_euler()
    sc.collection.objects.link(sun)


def setup_camera(a):
    sc = bpy.context.scene
    cd = bpy.data.cameras.new("Cam")
    cd.sensor_fit = 'HORIZONTAL'
    cd.sensor_width = 36.0
    cd.clip_start = 0.5
    cd.clip_end = 20000.0
    cam = bpy.data.objects.new("Cam", cd)
    if a.camera:
        c = json.load(open(a.camera))
        cd.lens = c["fpx"] * 36.0 / c["W"]
        eye = Vector(c["C"])
        fwd = Vector(c["forward"]).normalized()
        up = Vector(c["up"]).normalized()
    else:
        cd.lens = a.lens
        eye = Vector(tuple(float(v) for v in a.eye.split(",")))
        look = Vector(tuple(float(v) for v in a.look.split(",")))
        fwd = (look - eye).normalized()
        up = Vector((0, 0, 1))
    right = fwd.cross(up).normalized()
    up = right.cross(fwd).normalized()
    # Blender camera looks down its local -Z with +Y up
    rot = Matrix((right, up, -fwd)).transposed()
    cam.matrix_world = Matrix.Translation(eye) @ rot.to_4x4()
    sc.collection.objects.link(cam)
    sc.camera = cam


# ------------------------------------------------------------------ primitives
def unit_block():
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    me = bpy.data.meshes.new("Block")
    bm.to_mesh(me)
    bm.free()
    return me


def unit_cylinder_x(segs=24):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=0.5, radius2=0.5, depth=1.0)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, 'Y'))
    for f in bm.faces:
        f.smooth = True
    me = bpy.data.meshes.new("CylX")
    bm.to_mesh(me)
    bm.free()
    return me


def unit_sphere():
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=14, radius=0.5)
    for f in bm.faces:
        f.smooth = True
    me = bpy.data.meshes.new("Ball")
    bm.to_mesh(me)
    bm.free()
    return me


# ------------------------------------------------------------------ materials
ROUGH = {
    "Snow": 0.88, "Slate": 0.8, "Rock": 0.85, "Cobblestone": 0.85, "Wood": 0.7, "WoodPlanks": 0.72,
    "Metal": 0.45, "Glacier": 0.3, "Ice": 0.12, "Neon": 0.5, "Grass": 0.9, "Fabric": 0.85,
    "SmoothPlastic": 0.45, "Concrete": 0.82, "Sand": 0.9, "Sandstone": 0.85, "Asphalt": 0.9, "Basalt": 0.85,
    "Glass": 0.05, "Ground": 0.9, "Plastic": 0.5, "Brick": 0.85, "Marble": 0.3, "Granite": 0.6,
}
BUMP = {"Snow": (0.06, 38.0), "Slate": (0.25, 6.0), "Rock": (0.3, 5.0), "Cobblestone": (0.35, 3.0),
        "Concrete": (0.08, 10.0), "Sandstone": (0.18, 5.0), "Sand": (0.08, 20.0), "Grass": (0.2, 9.0),
        "WoodPlanks": (0.12, 4.0), "Wood": (0.1, 8.0), "Glacier": (0.05, 3.0)}
_mats = {}


def srgb_to_linear(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def material(color, mat, transparency):
    key = (tuple(color), mat, round(transparency, 2))
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new(f"{mat}_{color[0]}_{color[1]}_{color[2]}_{int(transparency * 100)}")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    lin = tuple(srgb_to_linear(v) for v in color) + (1.0,)
    bsdf.inputs["Base Color"].default_value = lin
    bsdf.inputs["Roughness"].default_value = ROUGH.get(mat, 0.6)
    if mat == "Metal":
        bsdf.inputs["Metallic"].default_value = 0.6
    if mat in ("Ice", "Glacier", "Glass"):
        bsdf.inputs["Coat Weight"].default_value = 0.4
    if mat == "Neon":
        bsdf.inputs["Emission Color"].default_value = lin
        bsdf.inputs["Emission Strength"].default_value = 1.6 if transparency < 0.3 else 0.6
    if transparency > 0.001:
        bsdf.inputs["Alpha"].default_value = max(0.0, 1.0 - transparency)
        try:
            m.surface_render_method = 'BLENDED'
        except Exception:
            pass
    if mat in BUMP:
        strength, scale = BUMP[mat]
        tex = nt.nodes.new("ShaderNodeTexNoise")
        tex.inputs["Scale"].default_value = scale
        tex.inputs["Detail"].default_value = 3.0
        coord = nt.nodes.new("ShaderNodeTexCoord")
        nt.links.new(coord.outputs["Object"], tex.inputs["Vector"])
        bump = nt.nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = strength
        nt.links.new(tex.outputs["Fac"], bump.inputs["Height"])
        nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    _mats[key] = m
    return m


def place_kit(a, col):
    import csv
    import os
    with bpy.data.libraries.load(a.kit_blend, link=False) as (src, dst):
        dst.objects = [n for n in src.objects if n.startswith("FP_Alpine_")]
    base = os.path.dirname(a.kit_blend)
    for img in bpy.data.images:
        if not img.packed_file and img.filepath:
            name = os.path.basename(img.filepath.replace("//", ""))
            candidate = os.path.join(base, name)
            if os.path.exists(candidate):
                img.filepath = candidate
    meshes = {ob.name: ob.data for ob in dst.objects if ob is not None}
    # Blender asset space (X, Y front, Z up) -> Roblox asset space (X, Y up, -Z front)
    Bm = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))
    # region-local (x west, y up, z north) -> scene (X east, Y north, Z up)
    A2 = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))
    placed, missing = 0, set()
    with open(a.sites) as f:
        for row in csv.DictReader(f):
            me = meshes.get(row["asset"])
            if me is None:
                missing.add(row["asset"])
                continue
            yaw = math.radians(float(row["yaw_deg"]))
            c, sn = math.cos(yaw), math.sin(yaw)
            Ry = Matrix(((c, 0, sn), (0, 1, 0), (-sn, 0, c)))
            sc = float(row["scale"])
            M3 = A2 @ Ry @ Matrix.Diagonal((sc, sc, sc)) @ Bm
            M = M3.to_4x4()
            M.translation = A2 @ Vector((float(row["x"]), float(row["y"]), float(row["z"])))
            ob = bpy.data.objects.new(row["site"], me)
            ob.matrix_world = M
            col.objects.link(ob)
            placed += 1
    print("KIT placed", placed, "missing", sorted(missing))


def main():
    a = args()
    reset()
    setup_render(a)
    setup_camera(a)
    parts = json.load(open(a.dump))
    meshes = {"Block": unit_block(), "Cylinder": unit_cylinder_x(), "Ball": unit_sphere()}
    for me in meshes.values():
        me.materials.append(None)
    col = bpy.data.collections.new("Parts")
    bpy.context.scene.collection.children.link(col)
    A = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
    kept = 0
    for p in parts:
        if p["transparency"] >= 0.999:
            continue
        if a.kit_blend and p["path"] == "PlaceholderArt":
            continue
        if a.open_gate_z is not None and (p["name"] == "Gate" or p["path"] == "Gate") and abs(p["cf"][2] - a.open_gate_z) < 4:
            continue
        x, y, z = p["cf"][0], p["cf"][1], p["cf"][2]
        sx, sy = x, -(z - a.centre_z)
        big = max(p["size"]) > 150
        if not big and (abs(sx) > a.xmax or sy < a.zmin or sy > a.zmax):
            continue
        r = p["cf"][3:]
        R = Matrix(((r[0], r[1], r[2]), (r[3], r[4], r[5]), (r[6], r[7], r[8])))
        size = p["size"]
        shape = p.get("shape", "Block")
        mesh = p.get("mesh")
        if mesh and mesh.get("kind") == "Sphere":
            # a SpecialMesh sphere fills the part's box times its Scale
            S = Matrix.Diagonal(tuple(size[i] * mesh["scale"][i] for i in range(3)))
            me = meshes["Ball"]
        elif shape == "Cylinder":
            d = min(size[1], size[2])
            S = Matrix.Diagonal((size[0], d, d))
            me = meshes["Cylinder"]
        elif shape == "Ball":
            d = min(size)
            S = Matrix.Diagonal((d, d, d))
            me = meshes["Ball"]
        else:
            S = Matrix.Diagonal(tuple(size))
            me = meshes["Block"]
        M3 = A @ R @ S
        M = M3.to_4x4()
        M.translation = Vector((sx, sy, y))
        ob = bpy.data.objects.new(p["name"], me)
        ob.matrix_world = M
        col.objects.link(ob)
        # one shared mesh per shape; the colour lives on the object's slot
        ob.material_slots[0].link = 'OBJECT'
        ob.material_slots[0].material = material(p["color"], p["material"], p["transparency"])
        kept += 1
    print("PARTS", kept)
    if a.kit_blend and a.sites:
        place_kit(a, col)
    sc = bpy.context.scene
    sc.render.filepath = a.out
    bpy.ops.render.render(write_still=True)
    print("RENDERED", a.out)


# Blender runs a -P script as __main__; tools/blender/render_hub_bush_context.py
# imports this file for its primitives and materials.
if __name__ == "__main__":
    main()

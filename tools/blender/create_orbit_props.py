"""Orbit Outpost V7 Gravity Garden: reproducible static Blender art.
Uses existing palette/FBX helpers without modifying them. No Studio changes.
blender --background --python tools/blender/create_orbit_props.py
Existing authored blend protected unless -- --replace-generated is provided.
"""
import importlib.util
import json
import math
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("region_kit", Path(__file__).with_name("create_garden_bay_props.py"))
kit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(kit)
CONTRACT = json.loads((ROOT / "assets/orbit-outpost/props-v1/asset-contract.json").read_text())
SIZES = {a["name"]: a["dimensions_studs_xyz"] for a in CONTRACT["assets"]}
kit.PALETTE[:] = [
    (36, 31, 57), (54, 45, 79), (78, 65, 104), (103, 87, 128),
    (125, 111, 151), (152, 137, 174), (184, 176, 200), (223, 223, 233),
    (247, 244, 236), (197, 207, 222), (110, 128, 154), (53, 68, 92),
    (65, 30, 113), (94, 42, 158), (128, 57, 195), (162, 84, 219),
    (194, 123, 241), (219, 171, 251), (75, 153, 167), (66, 197, 210),
    (126, 231, 233), (195, 251, 242), (146, 90, 49), (229, 165, 80),
    (255, 213, 132), (255, 237, 194), (41, 85, 95), (59, 113, 126),
    (86, 146, 156), (129, 178, 184), (137, 145, 194), (179, 187, 221),
]


def box(center, size, color, bevel=.05):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new("Soft edges", "BEVEL")
        mod.width = min(bevel, min(size)*.2)
        mod.segments = 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return kit.colorize(obj, color)


def ball(center, scale, color, subdivisions=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=1, location=center)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return kit.colorize(obj, color)


def crystal(center, radius, height, lean=(0, 0), seed=0):
    """Closed pointed crystal, with staggered triangular facets and no zero-area tips."""
    n = 6
    vs = [(center[0], center[1], center[2])]
    for level, rr in ((.20, .83), (.67, 1.0), (.83, .73)):
        for i in range(n):
            a = math.tau*i/n + seed*.23
            vs.append((center[0]+math.cos(a)*radius*rr+lean[0]*level,
                       center[1]+math.sin(a)*radius*rr+lean[1]*level,
                       center[2]+height*(level+.026*math.sin(i*2+seed))))
    top = len(vs)
    vs.append((center[0]+lean[0]+radius*.16, center[1]+lean[1], center[2]+height))
    faces = [(0, 1+(i+1)%n, 1+i) for i in range(n)]
    for k in range(2):
        for i in range(n):
            a, b = 1+k*n+i, 1+k*n+(i+1)%n
            c, d = b+n, a+n
            faces.extend([(a, b, c), (a, c, d)])
    faces += [(1+2*n+i, 1+2*n+(i+1)%n, top) for i in range(n)]
    return kit.mesh("Crystal", vs, faces, [13, 14, 16, 15, 17, 14, 12])


def finish(name):
    obj = kit.finish(name)
    w, h, d = SIZES[name]
    target = Vector((w, d, h))
    factor = Vector(tuple(target[i]/obj.dimensions[i] for i in range(3)))
    for v in obj.data.vertices:
        for i in range(3):
            v.co[i] *= factor[i]
    obj.data.update()
    bpy.context.view_layer.update()
    obj["AssetName"] = name
    obj["PivotMode"] = "BottomCenter"
    obj["IntendedSizeXYZ"] = SIZES[name]
    return obj


def bent_prong(angle):
    radial = Vector((math.cos(angle), math.sin(angle), 0))
    side = Vector((-math.sin(angle), math.cos(angle), 0))
    levels = [(5.9, .8, 1.7, 1.35), (7, 7, 1.55, 1.22),
              (6.5, 12.5, 1.38, 1.12), (5.35, 19, 1.12, .92),
              (4.4, 22, .86, .76)]
    verts = []
    for r, z, w, dep in levels:
        center = radial*r+Vector((0, 0, z))
        for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            verts.append(center+side*a*w/2+radial*b*dep/2)
    faces = [(3, 2, 1, 0)]
    for j in range(len(levels)-1):
        for k in range(4):
            faces.append((j*4+k, j*4+(k+1)%4, (j+1)*4+(k+1)%4, (j+1)*4+k))
    faces.append(tuple(range(16, 20)))
    kit.mesh("IvoryProng", verts, faces, [7, 8, 9, 7])
    for z, r in ((3.2, 6.4), (10.2, 6.65), (16.4, 5.65)):
        p = radial*r + Vector((0, 0, z))
        item = box(p, (1.3, .30, 1.2), 1)
        item.rotation_euler.z = angle-math.pi/2
        p2 = p-radial*.19
        lens = box(p2, (.82, .12, .69), 20, .035)
        lens.rotation_euler.z = angle-math.pi/2


def mushroom(x, y, height, r, seed):
    kit.beam((x, y, .03), (x+.15, y, height*.77), r*.15, [4, 5, 6], 9)
    # Low-poly umbrella, wide lip and dark violet underside.
    kit.lathe([(height*.66, r*.16), (height*.70, r*.92),
               (height*.74, r), (height*.90, r*.66), (height, r*.16)],
              (x+.15, y, 0), 12, [12, 13, 14, 15, 16])
    kit.ring((x+.15, y, height*.735), r*.91, r*.027, 17)
    for i in range(5):
        a = math.tau*i/5+seed
        ball((x+.15+math.cos(a)*r*.55, y+math.sin(a)*r*.55, height*.91),
             (r*.08, r*.08, r*.025), 17, 1)


def plant():
    kit.beam((0, 0, 0), (0, 0, 2.2), .11, 12)
    for i in range(9):
        a = math.tau*i/9
        r = 1.6 if i % 2 else 1.25
        end = (math.cos(a)*r, math.sin(a)*r, 1.7+(i % 3)*.42)
        kit.leaf((0, 0, .3+i*.12), end, .42, [13, 14, 15, 16])
        kit.beam((0, 0, .3+i*.12), end, .034, 17, 5)


def build():
    kit.start("orbit-outpost")
    kit.MAT.name = "Orbit_GravityGarden_Palette"
    for n in kit.MAT.node_tree.nodes:
        if n.type == "TEX_IMAGE":
            n.image.name = "Orbit_GravityGarden_Atlas"
    assets = []

    kit.lathe([(0, 7.4), (.45, 7.8), (1.0, 7.8), (1.25, 7.25)], sides=24, color=[1, 2, 10, 9])
    kit.lathe([(1.25, 5.7), (1.43, 5.7)], sides=24, color=0)
    kit.ring((0, 0, 1.46), 5.4, .13, 19)
    for a in (math.pi/2, math.pi/2+math.tau/3, math.pi/2+2*math.tau/3):
        bent_prong(a)
    assets.append(finish("OO_Gravity_Cradle"))

    crystal((0, 0, 0), 3, 11, (.8, -.25), 3)
    assets.append(finish("OO_Gravity_Meteor"))

    kit.blob((0, 0, 1.15), (1.4, 1.3, 1.2), [2, 3, 4], 42)
    # Inlaid mineral fleck.
    crystal((.35, -.45, 1.55), .25, .72, (.08, 0), 2)
    assets.append(finish("OO_Orbit_Stone"))

    for i, (x, y, z, size) in enumerate([(-1.3, 0, 1.6, (2.5, 2.1, 2.0)),
                                        (1.8, .3, 1.1, (1.6, 1.7, 1.4)),
                                        (.5, -1.4, .6, (1.2, 1.0, .8))]):
        kit.blob((x, y, z), size, [2, 3, 4, 3, 5], 81+i)
    assets.append(finish("OO_Lunar_Boulder"))

    kit.blob((0, 0, .35), (1.9, 1.7, .6), [2, 3, 4], 33)
    for i, (x, y, r, h) in enumerate([(-.4, .2, .65, 4.5), (.85, .25, .5, 2.9), (-.9, -.55, .42, 2.2)]):
        crystal((x, y, .45), r, h, (x*.38, y*.2), i)
    assets.append(finish("OO_Crystal_Cluster"))

    mushroom(-.5, .25, 6.8, 2.6, 1)
    mushroom(1.2, -.9, 3.4, 1.3, 2)
    assets.append(finish("OO_Alien_Mushroom_Tall"))

    for i, (x, y, h, r) in enumerate([(-.9, 0, 2.8, 1.15), (.85, .2, 1.9, .8), (0, -.8, 1.25, .65)]):
        mushroom(x, y, h, r, i)
    assets.append(finish("OO_Alien_Mushroom_Cluster"))

    plant()
    assets.append(finish("OO_Alien_Fern"))

    for i in range(9):
        a = i*2.4
        rr = .38+(.8 if i > 3 else .1)
        x, y = math.cos(a)*rr, math.sin(a)*rr
        h = .5+(i % 4)*.2
        kit.beam((x, y, 0), (x, y, h), .035, 18, 5)
        for j in range(5):
            ang = j*math.tau/5
            kit.leaf((x, y, h-.08), (x+math.cos(ang)*.22, y+math.sin(ang)*.22, h), .105, 20)
        ball((x, y, h+.04), (.10, .10, .10), 21, 1)
    assets.append(finish("OO_Star_Bloom_Tuft"))

    ball((0, 0, 1.5), (1.5, 1.3, 1.25), 8, 3)
    # Distinct dark blue camera socket pointing toward Blender -Y (Roblox +Z).
    kit.beam((0, -.91, 1.6), (0, -1.40, 1.6), .68, 0, 16)
    kit.beam((0, -1.40, 1.6), (0, -1.49, 1.6), .49, 19, 16)
    ball((-.14, -1.54, 1.79), (.13, .045, .13), 21, 1)
    kit.ring((0, 0, 1.2), 1.28, .07, 10)
    for side in (-1, 1):
        box((side*1.34, 0, 1.35), (.32, .67, .6), 10)
        kit.beam((side*.72, 0, .68), (side*.82, -.15, .05), .12, 11)
    assets.append(finish("OO_Survey_Drone"))

    kit.lathe([(0, 2.3), (.30, 2.5), (.85, 2.5), (1.12, 2.25)], sides=16, color=[1, 10, 9, 7])
    kit.lathe([(1.12, 1.85), (1.28, 1.85)], sides=16, color=1)
    kit.ring((0, 0, 1.31), 1.72, .075, 20)
    for i in range(4):
        a = math.tau*i/4
        item = box((math.cos(a)*2.1, math.sin(a)*2.1, 1.35), (.5, .25, .30), 24)
        item.rotation_euler.z = a
    assets.append(finish("OO_Drone_Dock"))

    kit.lathe([(0, 1.35), (.25, 1.5), (.65, 1.4)], sides=12, color=[1, 10, 9])
    kit.lathe([(.65, 1.08), (3.35, 1.08)], sides=12, color=[26, 27, 28, 29])
    for i in range(4):
        a = math.tau*i/4
        box((math.cos(a)*1.08, math.sin(a)*1.08, 2), (.28, .28, 2.8), 7)
    kit.lathe([(3.3, 1.35), (3.6, 1.5), (3.9, 1.25), (4, .9)], sides=12, color=[9, 7, 8])
    box((0, -1.15, 2.2), (.9, .16, 1.15), 0)
    crystal((0, -1.3, 1.76), .19, .8, (0, 0), 3)
    assets.append(finish("OO_Sample_Pod"))

    kit.lathe([(0, .6), (.18, .6), (.30, .43), (2.1, .40)], sides=10, color=[1, 10, 7])
    kit.lathe([(2.1, .50), (2.26, .50)], sides=10, color=1)
    kit.lathe([(2.26, .40), (2.85, .40), (3, .18)], sides=10, color=[19, 20, 21])
    assets.append(finish("OO_Cosmic_Beacon"))

    kit.lathe([(0, 8), (.45, 8), (.72, 7.6), (4.55, 7.6), (5, 8)], sides=24, color=[9, 7, 8])
    for i in range(12):
        a = math.tau*i/12
        # Flat window panels tangent to the round closed facade.
        for width, thick, height, color, r in [(2.65, .25, 2.65, 1, 7.43),
                                               (2.22, .27, 2.16, 24, 7.60)]:
            p = box((math.sin(a)*r, -math.cos(a)*r, 2.65), (width, thick, height), color, .12)
            p.rotation_euler.z = a
        rail = box((math.sin(a)*7.78, -math.cos(a)*7.78, 2.65), (.12, .1, 2.3), 8, .02)
        rail.rotation_euler.z = a
    # Front has a sealed instrument hatch over one window, not a walk-through door.
    box((0, -7.88, 2.3), (2.55, .2, 3.7), 9, .12)
    box((0, -8.02, 2.35), (1.8, .12, 2.8), 1, .12)
    box((0, -8.11, 3.25), (1.2, .08, .44), 20, .025)
    kit.ring((0, 0, .55), 7.8, .10, 10)
    assets.append(finish("OO_Field_Lab_Base"))

    # Open elliptical hemisphere ribs. Glass is a separate Roblox material layer.
    R, H = 7.75, 6.3
    kit.ring((0, 0, .16), R, .16, 9)
    for j in range(12):
        a = math.tau*j/12
        points = []
        for k in range(7):
            t = k*math.pi/12
            points.append((math.cos(a)*R*math.cos(t), math.sin(a)*R*math.cos(t), .16+H*math.sin(t)))
        for k in range(6):
            kit.beam(points[k], points[k+1], .105, 8, 6)
    for t in (math.pi/6, math.pi/3):
        kit.ring((0, 0, .16+H*math.sin(t)), R*math.cos(t), .10, 9)
    ball((0, 0, H+.16), (.35, .35, .15), 8, 1)
    assets.append(finish("OO_Field_Lab_Dome_Frame"))
    return assets


def aim(obj, target):
    obj.rotation_euler = (Vector(target)-obj.location).to_track_quat("-Z", "Y").to_euler()


def deliver(assets):
    out = kit.OUT
    manifest = {"version": 1, "region": "orbit_outpost", "approved_concept": "V7 Gravity Garden",
                "units": "1 modeling unit = 1 intended Roblox stud; normalize import to these bounds",
                "pivot": "bottom-center", "blender_up": "+Z", "fbx_up": "+Y", "roblox_front": "+Z",
                "texture": "palette.png", "assets": []}
    for obj in assets:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bad = sum(not e.is_manifold for e in bm.edges)
        bm.free()
        assert bad == 0, (obj.name, bad)
        assert all(p.area > 1e-9 for p in obj.data.polygons), obj.name
        obj.data.calc_loop_triangles()
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        kit.fbx(out/(obj.name+".fbx"))
        x, y, z = obj.dimensions
        manifest["assets"].append({"name": obj.name, "file": obj.name+".fbx",
                                  "dimensions_studs_xyz": [round(x, 4), round(z, 4), round(y, 4)],
                                  "triangles": len(obj.data.loop_triangles), "nonmanifold_edges": bad})
    (out/"manifest.json").write_text(json.dumps(manifest, indent=2))
    # Full-size, spaced production meshes. Never export presentation duplicates.
    for i, obj in enumerate(assets):
        obj.location = ((i % 5)*28, (i//5)*30, 0)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in assets:
        obj.select_set(True)
    kit.fbx(out/"OrbitPropsBundle.fbx")

    ink = kit.simple_mat("PreviewText", (.77, .85, .91))
    plate = kit.simple_mat("PreviewPlinth", (.048, .044, .073))
    for i, obj in enumerate(assets):
        obj.hide_render = True
        duplicate = obj.copy()
        duplicate.data = obj.data
        kit.PREVIEW.objects.link(duplicate)
        duplicate.name = "PREVIEW_"+obj.name
        duplicate.hide_render = False
        duplicate.location = ((i % 5-2)*9, (1-i//5)*11, 0)
        factor = min(1.2, 6.1/max(obj.dimensions.x, obj.dimensions.y), 7.1/obj.dimensions.z)
        duplicate.scale = (factor,)*3
        x, y, _ = duplicate.location
        bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=3.6, depth=.16, location=(x,y,-.12))
        bpy.context.object.data.materials.append(plate)
        for body, yy, scale in [(obj.name[3:].replace("_"," ").upper(),y-3.95,.29),
                                 (" x ".join(f"{v:g}" for v in SIZES[obj.name])+" studs",y-4.55,.24)]:
            bpy.ops.object.text_add(location=(x,yy,.03))
            label = bpy.context.object
            label.data.body = body
            label.data.size = scale
            label.data.align_x = "CENTER"
            label.data.materials.append(ink)
    bpy.ops.object.text_add(location=(0,19.8,.04))
    label=bpy.context.object
    label.data.body="ORBIT OUTPOST / V7 GRAVITY GARDEN"
    label.data.size=.74
    label.data.align_x="CENTER"
    label.data.materials.append(ink)
    bpy.ops.object.text_add(location=(0,18.35,.04))
    label=bpy.context.object
    label.data.body="15 CUSTOM BLENDER MESHES / DISPLAY SCALES VARY"
    label.data.size=.33
    label.data.align_x="CENTER"
    label.data.materials.append(ink)
    bpy.ops.mesh.primitive_plane_add(size=300, location=(0,0,-.25))
    bpy.context.object.data.materials.append(kit.simple_mat("PreviewFloor",(.020,.025,.041)))
    scene=bpy.context.scene
    scene.world=bpy.data.worlds.new("Studio")
    scene.world.use_nodes=True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value=(.33,.36,.48,1)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value=.5
    for pos,power,size in [((-14,-18,32),11000,20),((22,8,30),9000,18),((0,20,27),7500,16)]:
        bpy.ops.object.light_add(type="AREA",location=pos)
        o=bpy.context.object
        o.data.energy=power
        o.data.size=size
        aim(o,(0,0,0))
    bpy.ops.object.camera_add(location=(1,-46,64))
    o=bpy.context.object
    o.data.type="ORTHO"
    o.data.ortho_scale=54
    aim(o,(0,2,0))
    scene.camera=o
    scene.render.engine="CYCLES"
    scene.cycles.samples=24
    scene.cycles.use_denoising=True
    scene.render.resolution_x=2100
    scene.render.resolution_y=1800
    scene.render.resolution_percentage=100
    scene.view_settings.view_transform="AgX"
    scene.render.image_settings.file_format="PNG"
    scene.render.filepath=str(out/"preview.png")
    for obj in list(scene.objects):
        if obj not in assets and obj.name not in kit.PREVIEW.objects:
            for collection in list(obj.users_collection):
                collection.objects.unlink(obj)
            kit.PREVIEW.objects.link(obj)
    bpy.ops.wm.save_as_mainfile(filepath=str(out/"props.blend"))
    bpy.ops.render.render(write_still=True)
    print("ORBIT_KIT_COMPLETE",out,sum(a["triangles"] for a in manifest["assets"]),"triangles")


if __name__ == "__main__":
    deliver(build())

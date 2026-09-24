"""Thunderworks electrical-yard kit. Geometry only; no Studio changes.
Run Blender --background --python tools/blender/create_thunderworks_props.py.
Existing production .blend files are protected by the shared kit helper.
"""
import importlib.util
import math
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

source = Path(__file__).with_name('create_garden_bay_props.py')
spec = importlib.util.spec_from_file_location('region_kit', source)
kit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(kit)
kit.PALETTE[:] = [
    (34, 43, 54), (48, 61, 73), (69, 85, 96), (98, 117, 123),
    (132, 151, 151), (183, 202, 198), (223, 231, 212), (239, 237, 212),
    (78, 51, 39), (122, 74, 47), (167, 103, 60), (200, 145, 89),
    (30, 76, 82), (43, 107, 111), (87, 151, 147), (143, 194, 179),
    (45, 50, 57), (69, 75, 81), (103, 108, 112), (148, 151, 146),
    (134, 110, 47), (187, 149, 57), (224, 187, 77), (244, 213, 121),
    (61, 65, 77), (93, 101, 113), (135, 147, 157), (188, 204, 209),
    (118, 69, 48), (153, 92, 57), (181, 116, 70), (217, 168, 108),
]


def box(center, size, color, bevel=0.04):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        modifier = obj.modifiers.new('Soft machined edges', 'BEVEL')
        modifier.width = bevel
        modifier.segments = 1
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return kit.colorize(obj, color)


def insulator(center, height=2.0, radius=0.56):
    x, y, z = center
    kit.lathe([(0, radius*.42), (height, radius*.36)], (x, y, z), 12, 2)
    for i in range(4):
        h = height*.15 + i*height*.19
        kit.lathe([(h, radius*.42), (h+.05, radius), (h+height*.12, radius*.79),
                   (h+height*.15, radius*.36)], (x, y, z), 12, [5, 6, 7, 6])
    kit.lathe([(height*.9, radius*.5), (height, radius*.5)], (x, y, z), 12, 10)


def bolts(xvalues, y, z):
    for x in xvalues:
        kit.beam((x, y, z), (x, y-.12, z), .10, 4, 6)


def finish(name, xyz):
    obj = kit.finish(name)
    # Fixed bounds let Claude use exact placeholders before this export exists.
    target = Vector((xyz[0], xyz[2], xyz[1]))
    current = obj.dimensions.copy()
    factor = Vector((target.x/current.x, target.y/current.y, target.z/current.z))
    for vertex in obj.data.vertices:
        vertex.co.x *= factor.x
        vertex.co.y *= factor.y
        vertex.co.z *= factor.z
    obj.data.update()
    bpy.context.view_layer.update()
    return obj


def build():
    kit.start('thunderworks')
    assets = []
    # Transformer: stout teal enclosure, dark cooling banks, copper bus and two
    # cream ceramic necks. Front faces Blender -Y, exported Roblox +Z.
    box((0, 0, .24), (5.8, 4.6, .48), 1, .10)
    box((0, 0, 2.30), (4.5, 3.25, 3.9), 13, .14)
    for side in (-1, 1):
        for i in range(6):
            box((side*2.38, -.99+i*.4, 2.35), (.6, .15, 3.15), [1, 2, 3], .035)
        insulator((side*1.1, 0, 4.2), 1.75, .6)
    box((0, 0, 4.24), (4.65, 3.35, .28), 3, .06)
    kit.beam((-1.1, 0, 6.02), (1.1, 0, 6.02), .12, [9, 10, 11], 10)
    box((0, -1.67, 2.6), (1.5, .12, 1.35), 1)
    # Small raised lightning badge, solid static colour rather than a decal/UI.
    badge = [(-.14, -1.76, 3.05), (.24, -1.76, 3.05), (-.04, -1.76, 2.68),
             (.25, -1.76, 2.68), (-.24, -1.76, 2.12), (-.10, -1.76, 2.53), (-.34, -1.76, 2.53)]
    verts = badge + [(x, y+.055, z) for x, y, z in badge]
    faces = [tuple(range(7)), tuple(reversed(range(7, 14)))]
    faces += [(i, (i+1)%7, (i+1)%7+7, i+7) for i in range(7)]
    kit.mesh('LightningBadge', verts, faces, 22)
    bolts((-1.8, 1.8), -1.68, 1.0)
    assets.append(finish('TW_Transformer', (5.8, 6.2, 4.6)))

    box((0, 0, .15), (1.7, 1.7, .3), 2)
    insulator((0, 0, .25), 2.5, .9)
    kit.lathe([(2.72, .24), (3.0, .24)], sides=12, color=10)
    assets.append(finish('TW_Ceramic_Insulator', (1.8, 3.0, 1.8)))

    # Horizontal steel reel: flanges stand vertically, rubber wound around its
    # axis. It rests on broad feet so its ground origin is stable.
    start = len(kit.PARTS)
    kit.lathe([(-1.35, 2.0), (-1.10, 2.0)], sides=16, color=[9, 10, 11])
    kit.lathe([(1.10, 2.0), (1.35, 2.0)], sides=16, color=[9, 10, 11])
    kit.lathe([(-1.08, 1.58), (1.08, 1.58)], sides=16, color=16)
    for i in range(13):
        kit.ring((0, 0, -1+i/6), 1.59, .11, [16, 17])
    for side in (-1, 1):
        kit.lathe([(side*1.36-.10, .38), (side*1.36+.10, .38)], sides=12, color=3)
        for i in range(8):
            a=i*math.tau/8
            kit.beam((math.cos(a)*.65, math.sin(a)*.65, side*1.37),
                     (math.cos(a)*1.75, math.sin(a)*1.75, side*1.37), .065, 8, 6)
    transform = Matrix.Translation((0, 0, 2.15)) @ Matrix.Rotation(math.pi/2, 4, 'X')
    for obj in kit.PARTS[start:]: obj.matrix_world = transform @ obj.matrix_world
    for x in (-1.4, 1.4): box((x, 0, .15), (.42, 2.9, .3), 1)
    assets.append(finish('TW_Cable_Reel', (4.0, 4.4, 3.0)))

    box((0, 0, .18), (3.4, 3.4, .36), 2)
    for x, y in ((-.75, -.65), (.75, -.65), (0, .75)):
        kit.lathe([(.32, .62), (.5, .71), (3.8, .71), (4.02, .57)], (x, y, 0), 12, [12, 13, 14])
        for z in (.65, 3.55): kit.lathe([(z, .735), (z+.18, .735)], (x, y, 0), 12, 3)
        insulator((x, y, 4.0), .72, .28)
    kit.beam((-.75, -.65, 4.75), (0, .75, 4.75), .08, 10)
    kit.beam((.75, -.65, 4.75), (0, .75, 4.75), .08, 10)
    assets.append(finish('TW_Capacitor_Bank', (3.4, 4.8, 3.4)))

    box((0, 0, .17), (3.2, 1.8, .34), 1)
    box((0, 0, 2.34), (3.0, 1.55, 4.32), 13, .09)
    box((0, -.80, 2.30), (2.65, .12, 3.76), 14)
    box((0, -.89, 3.28), (1.48, .09, .62), 1)
    for x in (-.48, 0, .48): box((x, -.952, 3.28), (.18, .035, .20), 7, .015)
    for i in range(5): box((-.4, -.89, .86+i*.23), (1.46, .09, .07), 0, .015)
    kit.beam((.93, -.94, 1.80), (.93, -.94, 2.36), .075, 4)
    for z in (1, 3.55): box((-1.25, -.90, z), (.16, .1, .4), 3)
    box((0, 0, 4.5), (3.2, 1.8, .18), 2)
    assets.append(finish('TW_Switch_Cabinet', (3.2, 4.6, 1.8)))

    box((0, 0, .12), (4, 3.4, .24), 1)
    box((0, 0, 1.18), (3.75, 3.1, 2.10), 2, .14)
    box((0, -1.60, 1.27), (3.25, .14, 1.58), 0)
    for i in range(6):
        slat = box((0, -1.71, .70+i*.23), (3.0, .20, .12), [3, 4, 3], .025)
        slat.rotation_euler.x = -.2
    box((0, 0, 2.29), (3.96, 3.35, .20), 13)
    assets.append(finish('TW_Vent_Housing', (4.0, 2.4, 3.4)))

    # Bent conduit on a low mounting plate, closed tube topology at both ends.
    box((0, 0, .12), (3, 2.2, .24), 1)
    points = [Vector((-.95, 0, .25))]
    for i in range(13):
        a=math.pi-i*math.pi/24
        points.append(Vector((-.2+math.cos(a)*.75, 0, .75+math.sin(a)*.75)))
    points += [Vector((.5, 0, 1.5)), Vector((1.18, 0, 1.5))]
    verts=[]
    for i, point in enumerate(points):
        tangent=(points[min(i+1,len(points)-1)]-points[max(i-1,0)]).normalized()
        side=Vector((0,1,0)); up=tangent.cross(side).normalized()
        for j in range(10):
            a=j*math.tau/10; verts.append(point+(side*math.cos(a)+up*math.sin(a))*.35)
    faces=[tuple(reversed(range(10)))]
    for i in range(len(points)-1):
        for j in range(10): faces.append((i*10+j,i*10+(j+1)%10,(i+1)*10+(j+1)%10,(i+1)*10+j))
    faces.append(tuple((len(points)-1)*10+j for j in range(10)))
    kit.mesh('Conduit', verts, faces, [9,10,11])
    kit.lathe([(.25,.50),(.45,.50)],(-.95,0,0),12,3)
    kit.beam((1.02,0,1.5),(1.3,0,1.5),.48,3,12)
    assets.append(finish('TW_Conduit_Elbow', (3.0, 2.5, 2.2)))

    box((0, 0, .12), (1.2,1.2,.24),1)
    kit.lathe([(.2,.42),(2.45,.42),(2.6,.5),(2.8,.42)],sides=10,color=[12,13,14])
    for z in (.55,1.55): kit.lathe([(z,.445),(z+.25,.445)],sides=10,color=21)
    kit.lathe([(2.5,.51),(2.65,.51)],sides=10,color=2)
    kit.lathe([(2.67,.37),(2.9,.32),(3.0,.12)],sides=10,color=[5,6,7])
    assets.append(finish('TW_Storm_Bollard', (1.2, 3.0, 1.2)))
    kit.deliver(assets, 'ThunderworksPropsBundle', 'THUNDERWORKS / ELECTRICAL YARD')


if __name__ == '__main__':
    build()

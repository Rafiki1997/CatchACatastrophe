"""Derive a narrower-leaf review from the saved broadleaf source; preserve original.
Each closed leaf has 14 vertices (root, three 4-vertex rings, tip).
Shrink ring cross-sections 25%, retaining centerline, length, pose and count.
"""
import bpy, bmesh, json, math, sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'assets/gusty-gardens/broadleaf-v2/GustyBroadleaf.blend'
OUT=ROOT/'assets/gusty-gardens/broadleaf-v2-thin-leaves'
OUT.mkdir(parents=True,exist_ok=True)
TARGET=OUT/'GustyBroadleafThinLeaves.blend'
if TARGET.exists() and '--rebuild' not in sys.argv:
    raise RuntimeError('Existing variant preserved; use -- --rebuild explicitly.')
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
sc=bpy.context.scene; cam=sc.camera
hero=bpy.data.collections['GG_Broadleaf_A_Meadow']
leaf=bpy.data.objects['GG_Broadleaf_A_Leaves']
original=leaf.data.copy()
assert len(leaf.data.vertices)==3480*14
for start in range(0,len(leaf.data.vertices),14):
    for ring in range(3):
        vs=[leaf.data.vertices[start+1+ring*4+j] for j in range(4)]
        center=(vs[0].co+vs[2].co)*.5
        for v in vs: v.co=center+(v.co-center)*.75
leaf.data.update()
bm=bmesh.new(); bm.from_mesh(leaf.data)
assert all(e.is_manifold for e in bm.edges)
assert all(f.calc_area()>1e-10 for f in bm.faces)
bm.free()
leaf.data.calc_loop_triangles()
report={'status':'Unapproved narrower-leaf source review; not exported or integrated',
        'derived_from':str(SOURCE.relative_to(ROOT)), 'leaf_cross_section_factor':.75,
        'leaf_count':3480,'leaf_triangles':len(leaf.data.loop_triangles),
        'unchanged':'Trunk, bark, branches, leaf centerlines, lengths, positions, colors, count and scene scale',
        'nonmanifold_edges':0,'degenerate_faces':0}
(OUT/'geometry-report.json').write_text(json.dumps(report,indent=2))
sc.render.filepath=str(OUT/'thin-leaves-three-quarter.png')
bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
bpy.ops.render.render(write_still=True)

cam.location=(13,-25,12)
cam.rotation_euler=(Vector((.7,-1,7))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.ortho_scale=11; sc.render.filepath=str(OUT/'thin-leaves-detail.png')
bpy.ops.render.render(write_still=True)

# Actual geometry side-by-side under the same lights; no image substitutions.
compare=bpy.data.collections.new('PREVIEW_ORIGINAL_COMPARISON'); sc.collection.children.link(compare)
for ob in list(hero.objects):
    old=ob.copy(); old.data=original if ob==leaf else ob.data.copy(); compare.objects.link(old)
    old.name='Original_'+ob.name; old.location.x=-12; old.rotation_euler.z=-math.atan2(27,43)
    ob.location.x=12; ob.rotation_euler.z=-math.atan2(27,43)
cam.location=(0,-70,31)
cam.rotation_euler=(Vector((0,0,8.7))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.ortho_scale=48
sc.render.resolution_x=1800; sc.render.resolution_y=1050
sc.render.filepath=str(OUT/'leaf-width-comparison.png')
bpy.ops.render.render(write_still=True)
print('GUSTY_THIN_LEAF_COMPLETE',json.dumps(report),flush=True)

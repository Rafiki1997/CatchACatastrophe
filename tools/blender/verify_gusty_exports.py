"""Independent fresh-scene FBX verification of components and gallery bundle."""
import bpy,bmesh,json,math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'assets/gusty-gardens/broadleaf-family-v1/roblox'
m=json.loads((OUT/'manifest.json').read_text()); report=[]
def verify(o,item,offset=(0,0,0)):
    vs=[o.matrix_world@v.co for v in o.data.vertices]
    lo=Vector(tuple(min(v[i] for v in vs) for i in range(3))); hi=Vector(tuple(max(v[i] for v in vs) for i in range(3)))
    size=Vector((hi.x-lo.x,hi.z-lo.z,hi.y-lo.y)); center=Vector(((lo.x+hi.x)/2,(lo.z+hi.z)/2,-(lo.y+hi.y)/2))-Vector(offset)
    assert (size-Vector(item['dimensions_studs_xyz'])).length<.005,(o.name,'bounds')
    assert (center-Vector(item['center'])).length<.005,(o.name,'center')
    o.data.calc_loop_triangles(); assert len(o.data.loop_triangles)==item['triangles']<20000
    bm=bmesh.new(); bm.from_mesh(o.data)
    assert all(e.is_manifold for e in bm.edges),(o.name,'manifold')
    assert all(f.calc_area()>1e-10 for f in bm.faces),(o.name,'degenerate')
    bm.free()
    assert len(o.data.materials)==1 and len(o.data.uv_layers)==1
    assert all(math.isfinite(x) and 0<=x<=1 for uv in o.data.uv_layers.active.data for x in uv.uv)
    assert all(all(math.isfinite(x) for x in v.normal) and v.normal.length>.99 for v in o.data.vertices)
    images=[n.image for n in o.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE' and n.image]
    assert images and all(tuple(im.size)==(2048,2048) for im in images),(o.name,'textures')
    return [im.name for im in images]
for item in m['assets']:
    bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.fbx(filepath=str(OUT/item['file']))
    obs=[o for o in bpy.context.scene.objects if o.type=='MESH']
    assert len(obs)==1 and obs[0].name==item['name']
    maps=verify(obs[0],item)
    report.append({'name':item['name'],'triangles':item['triangles'],'bounds_centers_geometry_uv_normals':'passed','imported_maps':maps})
bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.fbx(filepath=str(OUT/'GustyBroadleafBundle.fbx'))
obs={o.name:o for o in bpy.context.scene.objects if o.type=='MESH'}
assert set(obs)=={a['name'] for a in m['assets']}
for variant in m['variants']:
    for name in variant['parts']:
        item=next(a for a in m['assets'] if a['name']==name); verify(obs[name],item,variant['gallery_offset'])
for key,file in m['textures'].items():
    im=bpy.data.images.load(str(OUT/file),check_existing=False); assert tuple(im.size)==(2048,2048)
(OUT/'validation.json').write_text(json.dumps({'status':'passed','components':report,'bundle_components':len(obs),'bundle_bounds_centers':'passed','external_maps':list(m['textures'].values()),'total_triangles':m['total_triangles']},indent=2))
print('GUSTY_BROADLEAF_ROUNDTRIP_PASSED',len(obs),flush=True)

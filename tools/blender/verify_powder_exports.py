"""Independent FBX roundtrip for all Powder Fir components and the bundle."""
import bpy,bmesh,json,math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'assets/frostbite-peaks/powder-firs-v1/roblox'
m=json.loads((OUT/'manifest.json').read_text());report=[]
for item in m['assets']:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(OUT/item['file']))
    obs=[o for o in bpy.context.scene.objects if o.type=='MESH']
    assert len(obs)==1 and obs[0].name==item['name'],item['name']
    o=obs[0];vs=[o.matrix_world@v.co for v in o.data.vertices]
    lo=Vector(tuple(min(v[i] for v in vs) for i in range(3)));hi=Vector(tuple(max(v[i] for v in vs) for i in range(3)))
    whd=Vector((hi.x-lo.x,hi.z-lo.z,hi.y-lo.y));center=Vector(((lo.x+hi.x)/2,(lo.z+hi.z)/2,-(lo.y+hi.y)/2))
    assert (whd-Vector(item['dimensions_studs_xyz'])).length<.005,(o.name,'size')
    assert (center-Vector(item['center'])).length<.005,(o.name,'center')
    o.data.calc_loop_triangles();tris=len(o.data.loop_triangles)
    if tris!=item['triangles']:
        bm=bmesh.new();bm.from_mesh(o.data)
        print('ROUNDTRIP_DIAGNOSTIC',o.name,'expected',item['triangles'],'actual',tris,'nonmanifold',sum(not e.is_manifold for e in bm.edges),'degenerate',sum(f.calc_area()<1e-10 for f in bm.faces),flush=True)
        print('BOUNDARY',[[list(v.co) for v in e.verts] for e in bm.edges if not e.is_manifold],flush=True)
        bm.free()
    assert tris==item['triangles'] and tris<20000,(o.name,tris)
    bm=bmesh.new();bm.from_mesh(o.data)
    assert all(e.is_manifold for e in bm.edges),(o.name,'roundtrip nonmanifold')
    assert all(f.calc_area()>1e-10 for f in bm.faces),(o.name,'roundtrip degenerate face')
    bm.free()
    assert len(o.data.materials)==1 and len(o.data.uv_layers)==1,o.name
    for uv in o.data.uv_layers.active.data:assert all(math.isfinite(x) and 0<=x<=1 for x in uv.uv)
    images=[n.image for n in o.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE' and n.image]
    assert images and all(im.size[0]==2048 and im.size[1]==2048 for im in images),(o.name,'maps')
    report.append({'name':o.name,'triangles':tris,'dimensions_and_center':'passed','textures':'passed'})
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.fbx(filepath=str(OUT/'PowderFirsBundle.fbx'))
assert {o.name for o in bpy.context.scene.objects if o.type=='MESH'}=={a['name'] for a in m['assets']}
(OUT/'validation.json').write_text(json.dumps({'status':'passed','components':report,'bundle_components':len(report),'total_triangles':sum(x['triangles'] for x in report)},indent=2))
print('POWDER_ROUNDTRIP_PASSED',len(report),flush=True)

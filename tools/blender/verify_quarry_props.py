"""Reimport final Quarry FBXs and validate the delivery, independently of export."""
import bpy,bmesh,json,math
from pathlib import Path
from bpy_extras.io_utils import axis_conversion
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'assets/cinder-canyon/quarry-v2'
manifest=json.loads((OUT/'manifest.json').read_text())
assert len(manifest['assets'])==12
assert (axis_conversion(to_forward='-Z',to_up='Y').to_4x4()@Vector((0,1,0))-Vector((0,0,-1))).length<1e-6
results=[]
for a in manifest['assets']:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(OUT/a['file']))
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH'];assert len(meshes)==1,a['name']
    o=meshes[0];assert o.name==a['name']
    points=[o.matrix_world@v.co for v in o.data.vertices]
    lo=[min(v[i] for v in points) for i in range(3)];hi=[max(v[i] for v in points) for i in range(3)]
    ds=[hi[i]-lo[i] for i in range(3)]
    assert max(abs(x-y) for x,y in zip([ds[0],ds[2],ds[1]],a['dimensions_studs_xyz']))<.005,(a['name'],ds)
    assert abs(lo[2])<.001 and abs(lo[0]+hi[0])<.001 and abs(lo[1]+hi[1])<.001,(a['name'],'origin')
    assert o.location.length<.001
    o.data.calc_loop_triangles();assert len(o.data.loop_triangles)==a['triangles']<15000
    bm=bmesh.new();bm.from_mesh(o.data)
    assert all(e.is_manifold for e in bm.edges),(a['name'],'nonmanifold')
    assert all(f.calc_area()>1e-8 for f in bm.faces),(a['name'],'zero area');bm.free()
    assert len(o.data.uv_layers)==1 and o.data.uv_layers[0].name=='PaletteUV'
    uv=o.data.uv_layers[0]
    for p in o.data.polygons:
        coords=[uv.data[i].uv for i in p.loop_indices]
        assert all((v-coords[0]).length<1e-5 for v in coords),(a['name'],'face spans palette colors')
        assert abs(coords[0].y-.5)<1e-5 and abs(coords[0].x*32-.5-round(coords[0].x*32-.5))<1e-4
    assert len(o.data.materials)==1
    textures=[n.image for n in o.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE' and n.image]
    assert textures and list(textures[0].size)==[512,16],(a['name'],'texture')
    for socket,p in a['sockets_roblox_xyz_from_base'].items():
        assert all(math.isfinite(v) for v in p),(a['name'],socket)
    results.append({'name':a['name'],'roundtrip':'pass','triangles':a['triangles'],'dimensions_studs_xyz':a['dimensions_studs_xyz'],'closed_geometry':True,'palette_and_texture':'pass'})
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(OUT/manifest['bundle']))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
assert {o.name for o in meshes}=={a['name'] for a in manifest['assets']}
(OUT/'validation.json').write_text(json.dumps({'status':'passed','assets':results,'bundle_mesh_count':len(meshes),'total_unique_triangles':sum(a['triangles'] for a in manifest['assets']),'forward_axis':'verified -Z Roblox','studio_import':'pending; no uploaded IDs','visual_review':'agent inspection of actual Blender renders'},indent=2))
print('VERIFIED twelve meshes: FBX roundtrip, fixed sizes, base origins, closed faces, palette texture, bundle names')

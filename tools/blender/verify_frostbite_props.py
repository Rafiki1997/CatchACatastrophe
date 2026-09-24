"""Fresh Blender FBX round-trip checks for the Alpine Expedition kit."""
import bpy, bmesh, json
from pathlib import Path

folder=Path(__file__).resolve().parents[2]/'assets/frostbite-peaks/props-v1'
manifest=json.loads((folder/'manifest.json').read_text())
results=[]
for asset in manifest['assets']:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(folder/asset['file']))
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
    assert len(objects)==1,asset['name']
    o=objects[0];o.data.calc_loop_triangles();x,y,z=o.dimensions
    assert max(abs(a-b) for a,b in zip((x,z,y),asset['dimensions_studs_xyz']))<.005,asset['name']
    assert o.location.length<1e-5,asset['name']
    assert len(o.data.loop_triangles)==asset['triangles'],asset['name']
    assert len(o.data.materials)==1 and len(o.data.uv_layers)==1,asset['name']
    for uv in o.data.uv_layers[0].data:
        assert abs(uv.uv.y-.5)<1e-5 and abs((uv.uv.x*32-.5)-round(uv.uv.x*32-.5))<1e-4,asset['name']
    images=[n.image for n in o.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE' and n.image]
    assert images and tuple(images[0].size)==(512,16),asset['name']
    bm=bmesh.new();bm.from_mesh(o.data);bad=sum(not e.is_manifold for e in bm.edges);bm.free()
    assert bad==0 and all(p.area>1e-9 for p in o.data.polygons),asset['name']
    assert min((o.matrix_world@v.co).z for v in o.data.vertices)>=-1e-4,asset['name']
    results.append({'name':asset['name'],'roundtrip':'pass','triangles':asset['triangles'],'nonmanifold_edges':bad,'texture_size':list(images[0].size)})
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(folder/'FrostbitePropsBundle.fbx'))
names={o.name for o in bpy.context.scene.objects if o.type=='MESH'}
assert names=={a['name'] for a in manifest['assets']},names
(folder/'validation.json').write_text(json.dumps({'fbx_roundtrip':results,'bundle_mesh_count':len(names),'studio_import':'not imported; awaits Claude layout and import-staging registration'},indent=2))
print('VERIFIED',len(results),'Frostbite meshes and bundle; triangles',sum(a['triangles'] for a in manifest['assets']))

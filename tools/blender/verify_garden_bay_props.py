"""Independently reimport all delivered FBXs and verify geometry and texture."""
import bpy, bmesh, json
from pathlib import Path
root=Path(__file__).resolve().parents[2]
for region,bundle in [('splashwater-bay','SplashwaterPropsBundle'),('gusty-gardens','GustyPropsBundle')]:
    folder=root/'assets'/region/'props-v1'
    manifest=json.loads((folder/'manifest.json').read_text())
    results=[]
    for asset in manifest['assets']:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.fbx(filepath=str(folder/asset['file']))
        meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
        assert len(meshes)==1,asset['name']
        o=meshes[0];o.data.calc_loop_triangles()
        x,y,z=o.dimensions
        assert max(abs(a-b) for a,b in zip((x,z,y),asset['dimensions_studs_xyz']))<.005,asset['name']
        assert o.location.length<1e-5,asset['name']
        assert len(o.data.loop_triangles)==asset['triangles'],asset['name']
        assert len(o.data.materials)==1 and o.data.uv_layers,asset['name']
        assert len(o.data.uv_layers)==1,asset['name']
        for uv in o.data.uv_layers[0].data:
            assert abs(uv.uv.y-.5)<1e-5 and abs((uv.uv.x*32-.5)-round(uv.uv.x*32-.5))<1e-4,asset['name']
        image_nodes=[n for n in o.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE' and n.image]
        assert image_nodes and image_nodes[0].image.size[0]==512,asset['name']
        bm=bmesh.new();bm.from_mesh(o.data)
        bad=sum(not e.is_manifold for e in bm.edges);bm.free()
        assert bad==0,asset['name']
        assert all(p.area>1e-9 for p in o.data.polygons),asset['name']
        results.append({'name':asset['name'],'roundtrip':'pass','triangles':asset['triangles'],'nonmanifold_edges':bad,'texture_size':list(image_nodes[0].image.size)})
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(folder/(bundle+'.fbx')))
    names={o.name for o in bpy.context.scene.objects if o.type=='MESH'}
    assert names=={a['name'] for a in manifest['assets']},(bundle,names)
    (folder/'validation.json').write_text(json.dumps({'fbx_roundtrip':results,'bundle_mesh_count':len(names),'studio_import':'not yet imported'},indent=2))
    print('VERIFIED',region,len(results),'individual assets and bundle')

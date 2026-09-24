"""Reimport the delivered FBXs; inspect actual geometry, palette UVs and bounds."""
import bpy, bmesh, json, math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/splashwater-bay/tidepools-v2'
manifest=json.loads((OUT/'manifest.json').read_text())
results=[]
for entry in manifest['assets']:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(OUT/entry['file']))
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
    assert len(objects)==1,entry['name']
    o=objects[0]
    assert o.name==entry['name'],o.name
    points=[o.matrix_world@v.co for v in o.data.vertices]
    lows=[min(p[i] for p in points) for i in range(3)]
    highs=[max(p[i] for p in points) for i in range(3)]
    dims=[highs[i]-lows[i] for i in range(3)]
    expected=entry['dimensions_studs_xyz']
    assert max(abs(a-b) for a,b in zip((dims[0],dims[2],dims[1]),expected))<.005,(o.name,dims,expected)
    assert abs(lows[2])<.001,(o.name,'base')
    assert abs(lows[0]+highs[0])<.001 and abs(lows[1]+highs[1])<.001,(o.name,'center')
    assert o.location.length<.001,o.name
    assert len(o.data.uv_layers)==1,(o.name,'UV layers')
    assert o.data.uv_layers.active.name=='PaletteUV',o.name
    # All UV vertices must remain on palette centerline and inside the image.
    for uv in o.data.uv_layers[0].data:
        assert abs(uv.uv.y-.5)<.001,(o.name,'UV centerline',tuple(uv.uv))
        assert 0<uv.uv.x<1,(o.name,'UV bounds')
    assert len(o.data.materials)==1,o.name
    nodes=[n for n in o.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE' and n.image]
    assert nodes and list(nodes[0].image.size)==[512,16],(o.name,'texture')
    o.data.calc_loop_triangles()
    assert len(o.data.loop_triangles)==entry['triangles'],o.name
    assert entry['triangles']<15000,o.name
    bm=bmesh.new();bm.from_mesh(o.data)
    bad=sum(not e.is_manifold for e in bm.edges)
    assert bad==0,(o.name,'nonmanifold',bad)
    assert all(f.calc_area()>1e-8 for f in bm.faces),(o.name,'degenerate')
    bm.free()
    results.append({'name':o.name,'fbx_roundtrip':'pass','dimensions_studs_xyz':expected,'triangles':entry['triangles'],'nonmanifold_edges':bad,'palette_uv':'pass','embedded_texture':'pass'})

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(OUT/manifest['bundle']))
names={o.name for o in bpy.context.scene.objects if o.type=='MESH'}
assert names=={a['name'] for a in manifest['assets']},names
collision=[]
for entry in manifest['assets']:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(OUT/entry['collision_file']))
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
    assert len(objects)==1
    bm=bmesh.new();bm.from_mesh(objects[0].data)
    assert all(e.is_manifold for e in bm.edges)
    assert bm.calc_volume(signed=True)>0
    verts=[v.co for v in bm.verts]
    # Every vertex lies behind each outward plane: true convex hull.
    for f in bm.faces:
        p=f.verts[0].co
        plane_error=max((v-p).dot(f.normal) for v in verts)
        assert plane_error<.002,(entry['name'],plane_error,tuple(f.normal))
    objects[0].data.calc_loop_triangles()
    collision.append({'name':objects[0].name,'triangles':len(objects[0].data.loop_triangles),'convex':'pass'})
    bm.free()

# Optional split palms must reconstruct the same exact visual bounds.
for entry in manifest['assets']:
    if not entry['name'].startswith('SB_Palm_'):continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for suffix in ('Trunk','Crown'):
        bpy.ops.import_scene.fbx(filepath=str(OUT/'split-palms'/(entry['name']+'__'+suffix+'.fbx')))
    pts=[o.matrix_world@v.co for o in bpy.context.scene.objects if o.type=='MESH' for v in o.data.vertices]
    ds=[max(p[i] for p in pts)-min(p[i] for p in pts) for i in range(3)]
    assert max(abs(a-b) for a,b in zip((ds[0],ds[2],ds[1]),entry['dimensions_studs_xyz']))<.005

result={'status':'passed','individual_assets':results,'bundle_mesh_count':len(names),'collision_hulls':collision,
        'split_palms':'all three reconstruct combined dimensions',
        'studio_import':'pending; no Roblox IDs generated','render_review':'separate human/agent visual inspection'}
(OUT/'validation.json').write_text(json.dumps(result,indent=2))
print('VERIFIED: 8 visual meshes, 8 convex hulls, 3 split palms, bundle and embedded textures')

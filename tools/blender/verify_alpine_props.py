"""Independent FBX roundtrip validation; no game or Studio mutations."""
import bpy,bmesh,json,math
from pathlib import Path
from mathutils import Vector
from bpy_extras.io_utils import axis_conversion
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'assets/frostbite-peaks/alpine-v2'
m=json.loads((OUT/'manifest.json').read_text());results=[]
expected={'Lodge':[40,30,24],'Bridge':[10,7.5,34],'Shelf_North':[42.5,10,23.5],
          'Shelf_South':[29,10,15],'Gorge_Rock':[12,11,50],'Cliff_Block':[14,12,12],
          'Snow_Rock_Small':[5,3.5,4.5],'Tent':[8,6,9],'Camp_Sled':[5,2,3],
          'Notice_Board':[4,5,1],'Terrace_Post':[2,7.5,2]}
required={'Lodge','Bridge','Shelf_North','Shelf_South','Gorge_Rock','Cliff_Block','Snow_Rock_Small',
          'Tent','Camp_Sled','Notice_Board','Terrace_Post','Cliff_Tall','Cliff_Wide','Fir_Tall','Fir_Medium','Fir_Sapling',
          'Frosted_Shrub','Grass','Woodpile','Crate','Barrel','Railing','Lantern_Post','Trail_Post','Signpost','Pennant','Snow_Rock','Snow_Drift'}
assert {a['name'] for a in m['assets']} >= {'FP_Alpine_'+x for x in required}
axis=axis_conversion(to_forward='-Z',to_up='Y').to_4x4()
assert (axis@Vector((0,1,0))-Vector((0,0,-1))).length<1e-6
assert (axis@Vector((0,0,1))-Vector((0,1,0))).length<1e-6
assert len({a['name'] for a in m['assets']})==len(m['assets'])
for a in m['assets']:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(OUT/a['file']))
    obs=[o for o in bpy.context.scene.objects if o.type=='MESH']
    assert len(obs)==1,(a['name'],'mesh_count')
    o=obs[0];assert o.name==a['name']
    suffix=a['name'].replace('FP_Alpine_','')
    if suffix in expected:assert a['dimensions_studs_xyz']==expected[suffix]
    ps=[o.matrix_world@v.co for v in o.data.vertices]
    lo=[min(v[i] for v in ps) for i in range(3)];hi=[max(v[i] for v in ps) for i in range(3)]
    dims=[hi[i]-lo[i] for i in range(3)]
    assert max(abs(x-y) for x,y in zip([dims[0],dims[2],dims[1]],a['dimensions_studs_xyz']))<.005,(a['name'],'bounds',dims)
    assert abs(lo[2])<.001 and abs(lo[0]+hi[0])<.001 and abs(lo[1]+hi[1])<.001,(a['name'],'bottom_pivot')
    assert o.location.length<.001
    bm=bmesh.new();bm.from_mesh(o.data)
    assert all(e.is_manifold for e in bm.edges),(a['name'],'nonmanifold')
    assert all(f.calc_area()>1e-9 for f in bm.faces),(a['name'],'zero_area');bm.free()
    o.data.calc_loop_triangles();assert len(o.data.loop_triangles)==a['triangles']
    assert len(o.data.materials)==1 and len(o.data.uv_layers)==1
    uv=o.data.uv_layers[0];assert uv.name=='AlpineAtlasUV'
    textured_faces=0
    for p in o.data.polygons:
        coords=[uv.data[i].uv for i in p.loop_indices]
        assert all(0<u.x<1 and 0<u.y<1 for u in coords)
        tiles={(int(u.x*4),int(u.y*4)) for u in coords}
        assert len(tiles)==1,(a['name'],'uv_tile_bleed')
        if any((u-coords[0]).length>.001 for u in coords):textured_faces+=1
    assert textured_faces>len(o.data.polygons)*.5,(a['name'],'missing_texture_uv')
    tex=[n.image for n in o.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE' and n.image]
    assert tex and any('alpine-color' in im.name for im in tex)
    assert all(list(im.size)==[2048,2048] for im in tex)
    for p in a['sockets_roblox_xyz_from_base'].values():assert len(p)==3 and all(math.isfinite(v) for v in p)
    def top(x,y,wanted):
        hit,pos,n,index=o.ray_cast(Vector((x,y,150)),Vector((0,0,-1)))
        assert hit and abs(pos.z-wanted)<.005,(a['name'],'walking/top socket',x,y,pos.z if hit else None,wanted)
    if suffix=='Lodge':
        top(4,9.5,1);top(4,11.5,.5)
        assert a['sockets_roblox_xyz_from_base']['DoorBase']==[4,1,-5.5]
        assert a['sockets_roblox_xyz_from_base']['ChimneyTop']==[8.5,30,7.5]
    if suffix=='Bridge':
        top(0,0,.3);top(0,16.97,1.5);top(0,-16.97,1.5)
        assert a['sockets_roblox_xyz_from_base']['NorthDeck']==[0,1.5,17]
        assert a['sockets_roblox_xyz_from_base']['SouthDeck']==[0,1.5,-17]
    if suffix=='Shelf_North':
        top(10,0,8.5);top(-10,-8,8.5)
        assert not o.ray_cast(Vector((-10,0,150)),Vector((0,0,-1)))[0], 'gorge filled'
        assert not any(-21.249<v.x<-1.251 and -3.749<v.y<11.749 and v.z>.3 for v in ps),'gorge geometry'
    if suffix=='Shelf_South':top(0,0,8.5);top(0,7.3,8.5)
    if suffix in ('Cliff_Tall','Cliff_Wide','Cliff_Block'):
        top(0,0,a['dimensions_studs_xyz'][1]);top(2,2,a['dimensions_studs_xyz'][1])
    results.append({'name':a['name'],'fbx_roundtrip':'passed','dimensions_studs_xyz':a['dimensions_studs_xyz'],'triangles':a['triangles'],'closed_geometry':True,'uv_tiles_and_texture':'passed'})
    print('PASS',a['name'],flush=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(OUT/m['bundle']))
obs=[o for o in bpy.context.scene.objects if o.type=='MESH']
assert {o.name for o in obs}=={a['name'] for a in m['assets']}
for key in ('color','normal','roughness'):
    im=bpy.data.images.load(str(OUT/m['textures'][key]),check_existing=False)
    assert list(im.size)==[2048,2048]
report={'status':'passed','assets':results,'bundle_mesh_count':len(obs),'required_contract_names':len(required),'total_unique_triangles':sum(a['triangles'] for a in m['assets']),
        'semantic_checks':'lodge porch/step, bridge curve endpoints/midpoint, shelf walking tops/empty gorge, cliff TopMount flat pads',
        'axis_conversion':'Blender +Y front/+Z up -> Roblox -Z front/+Y up verified',
        'texture_maps':'2048 color/normal/roughness; material wiring requires Studio verification',
        'studio_import':'not validated by this script','dimensions_status':m['dimensions_status']}
(OUT/'validation.json').write_text(json.dumps(report,indent=2))
print('ALPINE_VERIFIED',len(obs),report['total_unique_triangles'],flush=True)

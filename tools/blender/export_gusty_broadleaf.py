"""Portable closed-leaf broadleaf export; keep original source intact."""
import bpy,bmesh,json,math,sys
import numpy as np
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]; SRC=ROOT/'assets/gusty-gardens/broadleaf-family-v1'; OUT=SRC/'roblox'; OUT.mkdir(exist_ok=True)
if (OUT/'GustyBroadleafRoblox.blend').exists() and '--rebuild' not in sys.argv: raise RuntimeError('Use -- --rebuild explicitly')
bpy.ops.wm.open_mainfile(filepath=str(SRC/'GustyBroadleafFamily.blend'))
sc=bpy.context.scene; exp=bpy.data.collections.new('ROBLOX_GUSTY_BROADLEAF'); sc.collection.children.link(exp)
source=json.loads((SRC/'source-manifest.json').read_text())
colors=[(.20,.105,.047),(.255,.145,.065),(.045,.115,.026),(.067,.174,.032),(.10,.235,.043),(.15,.29,.058),(.21,.34,.078),(.11,.22,.042)]
size=2048; tw=512; th=1024; rng=np.random.default_rng(92626)
arr={k:np.ones((size,size,4),np.float32) for k in ('color','normal','roughness')}
yy,xx=np.mgrid[0:th,0:tw].astype(np.float32); u=xx/tw; v=yy/th
for i,c in enumerate(colors):
    grain=rng.normal(0,1,(th,tw)).astype(np.float32)
    if i<2:
        noise=np.sin((u*15+np.sin(v*6)*.22)*math.tau)*.3+grain*.08; amplitude=.12
    else:
        # Restrained vein, no baked directional lighting.
        vein=np.exp(-((u-.5)/.023)**2)*.25
        noise=grain*.08+vein; amplitude=.07
    linear=np.clip(np.array(c)[None,None,:]*(1+noise[:,:,None]*amplitude),0,1)
    rgb=np.where(linear<=.0031308,linear*12.92,1.055*linear**(1/2.4)-.055)
    x0=i%4*tw; y0=i//4*th
    arr['color'][y0:y0+th,x0:x0+tw,:3]=rgb
    dy,dx=np.gradient(noise); normal=np.stack((-dx*.35,-dy*.35,np.ones_like(noise)),axis=-1); normal/=np.linalg.norm(normal,axis=-1,keepdims=True)
    arr['normal'][y0:y0+th,x0:x0+tw,:3]=normal*.5+.5
    arr['roughness'][y0:y0+th,x0:x0+tw,:3]=.94 if i<2 else .88
images={}
for key,a in arr.items():
    im=bpy.data.images.new('gusty-broadleaf-'+key,width=size,height=size,alpha=False)
    if key!='color':im.colorspace_settings.name='Non-Color'
    im.pixels.foreach_set(a.ravel()); im.filepath_raw=str(OUT/('gusty-broadleaf-'+key+'.png')); im.file_format='PNG'; im.save(); im.pack(); images[key]=im
mat=bpy.data.materials.new('GustyBroadleaf_Portable'); mat.use_nodes=True; nt=mat.node_tree; bs=nt.nodes.get('Principled BSDF')
for key,target in [('color','Base Color'),('roughness','Roughness'),('normal',None)]:
    node=nt.nodes.new('ShaderNodeTexImage'); node.image=images[key]
    if target:nt.links.new(node.outputs['Color'],bs.inputs[target])
    else:
        norm=nt.nodes.new('ShaderNodeNormalMap'); norm.inputs['Strength'].default_value=.35
        nt.links.new(node.outputs['Color'],norm.inputs['Color']); nt.links.new(norm.outputs['Normal'],bs.inputs['Normal'])
def tile_uv(tile,u,v):return ((tile%4+.025+.95*u)/4,(tile//4+.025+.95*v)/2)
def active(o):
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active=o
def tube_uv(o,tile):
    me=o.data; me.materials.clear(); me.materials.append(mat); uv=me.uv_layers.new(name='GustyAtlasUV')
    cursor=0
    while cursor<len(me.polygons):
        cap=me.polygons[cursor]; n=len(cap.vertices); assert n>4,(o.name,cursor,n)
        start=min(cap.vertices); end=cursor+1
        while len(me.polygons[end].vertices)==4:end+=1
        rings=(end-cursor-1)//n+1
        for idx in (cursor,end):
            p=me.polygons[idx]
            for li in p.loop_indices:
                j=(me.loops[li].vertex_index-start)%n
                uv.data[li].uv=tile_uv(tile,.5+.45*math.cos(j*math.tau/n),.5+.45*math.sin(j*math.tau/n))
        for k in range(cursor+1,end):
            p=me.polygons[k]; side=(k-cursor-1)%n; ring=(k-cursor-1)//n
            coords=[(side/n,ring/(rings-1)),((side+1)/n,ring/(rings-1)),((side+1)/n,(ring+1)/(rings-1)),(side/n,(ring+1)/(rings-1))]
            for li,(u,v) in zip(p.loop_indices,coords):uv.data[li].uv=tile_uv(tile,u,v)
        cursor=end+1
    for p in me.polygons:p.material_index=0
def export(path,objects):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.fbx(filepath=str(path),use_selection=True,object_types={'MESH'},axis_forward='-Z',axis_up='Y',global_scale=1,apply_unit_scale=False,apply_scale_options='FBX_SCALE_NONE',use_mesh_modifiers=True,mesh_smooth_type='FACE',use_triangles=True,path_mode='COPY',embed_textures=True,add_leaf_bones=False,bake_anim=False)
def bounds(objects):
    vs=[v.co for o in objects for v in o.data.vertices]
    return Vector(tuple(min(v[i] for v in vs) for i in range(3))),Vector(tuple(max(v[i] for v in vs) for i in range(3)))
def xyz(v):return [round(v.x,6),round(v.z,6),round(-v.y,6)]
def whd(v):return [round(v.x,6),round(v.z,6),round(v.y,6)]
assets=[]; variants=[]; allobs=[]
for src in source['variants']:
    code=src['id']; col=bpy.data.collections[src['collection']]; col.hide_render=True; made=[]
    for suffix,tile in [('Bark',0),('BarkRidges',1)]:
        original=bpy.data.objects['GG_Broadleaf_'+code+'_'+suffix]; ob=original.copy(); ob.data=original.data.copy(); exp.objects.link(ob)
        ob.name='GG_Broadleaf_'+code+'_'+suffix+'_Export'; ob.location=(0,0,0); tube_uv(ob,tile); made.append(ob)
    active(made[0]); made[1].select_set(True); bpy.ops.object.join(); made=[made[0]]; made[0].name='GG_Broadleaf_'+code+'_Wood'
    mesh=bpy.data.objects['GG_Broadleaf_'+code+'_Leaves'].data
    assert len(mesh.vertices)%14==0
    color_by_root={p.vertices[0]:p.material_index for p in mesh.polygons}
    leaf_count=len(mesh.vertices)//14
    for batch,start in enumerate(range(0,leaf_count,2000),1):
        vs=[]; fs=[]; uvcoords=[]
        for idx in range(start,min(start+2000,leaf_count)):
            off=idx*14; offset=len(vs)
            # Preserve root/tip and the widest folded ring: closed eight-triangle leaf.
            vs.extend(mesh.vertices[off+j].co.copy() for j in [0,5,6,7,8,13])
            faces=[(0,2,1),(0,3,2),(0,4,3),(0,1,4),(5,1,2),(5,2,3),(5,3,4),(5,4,1)]
            coords=[(.5,0),(0,.52),(.5,.52),(1,.52),(.5,.52),(.5,1)]
            tile=color_by_root[off]+2
            for face in faces:
                fs.append(tuple(offset+j for j in face)); uvcoords.extend(tile_uv(tile,*coords[j]) for j in face)
        me=bpy.data.meshes.new('LeafBatch'); me.from_pydata(vs,[],fs); me.materials.append(mat); me.update()
        uv=me.uv_layers.new(name='GustyAtlasUV')
        for loop,co in zip(uv.data,uvcoords):loop.uv=co
        ob=bpy.data.objects.new('GG_Broadleaf_'+code+'_Leaves_'+str(batch),me); exp.objects.link(ob); made.append(ob)
    lo,hi=bounds(made)
    entry={'id':code,'label':src['label'],'size':whd(hi-lo),'trunk_base':[0,0,0],
           'bounds_min':xyz(Vector((lo.x,hi.y,lo.z))),'bounds_max':xyz(Vector((hi.x,lo.y,hi.z))),
           'gallery_offset':[src['gallery_x'],0,0],'parts':[],'leaves_preserved':leaf_count}
    for ob in made:
        bm=bmesh.new(); bm.from_mesh(ob.data); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bmesh.ops.triangulate(bm,faces=list(bm.faces))
        assert all(e.is_manifold for e in bm.edges) and all(f.calc_area()>1e-10 for f in bm.faces),ob.name
        bm.to_mesh(ob.data); bm.free()
        for p in ob.data.polygons:p.use_smooth=True
        ob.data.calc_loop_triangles(); tris=len(ob.data.loop_triangles); assert tris<20000
        a,b=bounds([ob]); item={'name':ob.name,'file':ob.name+'.fbx','dimensions_studs_xyz':whd(b-a),'center':xyz((a+b)/2),'triangles':tris}
        assets.append(item); entry['parts'].append(ob.name); allobs.append(ob); export(OUT/item['file'],[ob])
    variants.append(entry)
for v in variants:
    for name in v['parts']:bpy.data.objects[name].location.x=v['gallery_offset'][0]
export(OUT/'GustyBroadleafBundle.fbx',allobs)
manifest={'version':1,'library':'GustyBroadleafTemplates','bundle':'GustyBroadleafBundle','units':'1 Blender unit = 1 intended Roblox stud; measure importer scale',
          'pivot':'root socket at local zero; use component bounds centers, not gallery offsets','textures':{k:'gusty-broadleaf-'+k+'.png' for k in images},
          'variants':variants,'assets':assets,'source_triangles':sum(v['source_triangles'] for v in source['variants']),'total_triangles':sum(a['triangles'] for a in assets)}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
sc.render.filepath=str(OUT/'broadleaf-family-roblox.png'); bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'GustyBroadleafRoblox.blend'))
bpy.ops.render.render(write_still=True)
print('GUSTY_BROADLEAF_EXPORT_COMPLETE',manifest['total_triangles'],flush=True)

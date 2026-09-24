"""Create portable, split Roblox meshes from the approved Powder Fir source.
Preserve every needle; simplify each closed needle to a six-triangle volume.
"""
import bpy,bmesh,math,json,random,sys
import numpy as np
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'assets/frostbite-peaks/powder-firs-v1';OUT=SRC/'roblox';OUT.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SRC/'PowderFirs.blend'))
SC=bpy.context.scene
EXPORT=bpy.data.collections.new('ROBLOX_POWDER_FIRS');SC.collection.children.link(EXPORT)
colors=[(.85,.91,.97),(.20,.105,.047),(.022,.069,.041),(.032,.098,.049),(.045,.122,.052),(.061,.139,.061),(.080,.152,.067),(.029,.090,.064)]
SIZE=2048;TW=512;TH=1024
arrays={k:np.ones((SIZE,SIZE,4),np.float32) for k in ['color','normal','roughness']}
rng=np.random.default_rng(3209);yy,xx=np.mgrid[0:TH,0:TW].astype(np.float32);u=xx/TW;v=yy/TH
for i,c in enumerate(colors):
    grain=rng.normal(0,1,(TH,TW)).astype(np.float32)
    if i==1:
        noise=np.sin((u*21+np.sin(v*8)*.3)*math.tau)*.35+grain*.10
        amp=.11
    elif i==0:noise=grain*.22+np.sin(u*29)*np.sin(v*23)*.08;amp=.018
    else:noise=grain*.10+np.sin(u*38+np.sin(v*13))*.17;amp=.055
    linear=np.clip(np.array(c)[None,None,:]*(1+noise[:,:,None]*amp),0,1)
    rgb=np.where(linear<=.0031308,linear*12.92,1.055*linear**(1/2.4)-.055)
    x0=(i%4)*TW;y0=(i//4)*TH
    arrays['color'][y0:y0+TH,x0:x0+TW,:3]=rgb
    dy,dx=np.gradient(noise);n=np.stack((-dx*.55,-dy*.55,np.ones_like(noise)),axis=-1);n/=np.linalg.norm(n,axis=-1,keepdims=True)
    arrays['normal'][y0:y0+TH,x0:x0+TW,:3]=n*.5+.5
    arrays['roughness'][y0:y0+TH,x0:x0+TW,:3]=.91
images={}
for key,arr in arrays.items():
    im=bpy.data.images.new('powder-firs-'+key,width=SIZE,height=SIZE,alpha=False)
    if key!='color':im.colorspace_settings.name='Non-Color'
    im.pixels.foreach_set(arr.ravel());im.filepath_raw=str(OUT/('powder-firs-'+key+'.png'));im.file_format='PNG';im.save();im.pack();images[key]=im
mat=bpy.data.materials.new('PowderFirs_Portable');mat.use_nodes=True
nt=mat.node_tree;bs=nt.nodes.get('Principled BSDF')
for key,target in [('color','Base Color'),('roughness','Roughness'),('normal',None)]:
    tex=nt.nodes.new('ShaderNodeTexImage');tex.image=images[key]
    if target:nt.links.new(tex.outputs['Color'],bs.inputs[target])
    else:
        normal=nt.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.35;nt.links.new(tex.outputs['Color'],normal.inputs['Color']);nt.links.new(normal.outputs['Normal'],bs.inputs['Normal'])

def active(o):
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
def reduce(o,budget):
    o.data.calc_loop_triangles();n=len(o.data.loop_triangles)
    m=o.modifiers.new('Roblox topology','DECIMATE');m.ratio=min(1,budget/n);active(o);bpy.ops.object.modifier_apply(modifier=m.name)
def portable(o,tile=None):
    # Existing material indices on foliage are carried to the appropriate tile.
    old=[p.material_index for p in o.data.polygons]
    o.data.materials.clear();o.data.materials.append(mat)
    uv=o.data.uv_layers.new(name='PowderAtlasUV')
    for p,mi in zip(o.data.polygons,old):
        idx=tile if tile is not None else mi+2
        p.material_index=0;p.use_smooth=True
        axes=[j for j in range(3) if j!=max(range(3),key=lambda k:abs(p.normal[k]))]
        verts=[o.data.vertices[j].co for j in p.vertices]
        lo=[min(v[a] for v in verts) for a in axes];hi=[max(v[a] for v in verts) for a in axes]
        for li in p.loop_indices:
            co=o.data.vertices[o.data.loops[li].vertex_index].co
            a=(co[axes[0]]-lo[0])/max(hi[0]-lo[0],1e-7);b=(co[axes[1]]-lo[1])/max(hi[1]-lo[1],1e-7)
            uv.data[li].uv=((idx%4+.025+.95*a)/4,(idx//4+.025+.95*b)/2)
def obj(name,vs,fs,mi):
    me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.update()
    # Dummy material slots preserve per-needle source colour until atlas mapping.
    for i in range(6):me.materials.append(mat)
    for p,m in zip(me.polygons,mi):p.material_index=m
    ob=bpy.data.objects.new(name,me);EXPORT.objects.link(ob);return ob
def bounds(o):
    vs=[v.co for v in o.data.vertices]
    return Vector(tuple(min(v[i] for v in vs) for i in range(3))),Vector(tuple(max(v[i] for v in vs) for i in range(3)))
def xyz(v):return [round(v.x,6),round(v.z,6),round(-v.y,6)]
def dims(v):return [round(v.x,6),round(v.z,6),round(v.y,6)]
def export(path,obs):
    bpy.ops.object.select_all(action='DESELECT')
    for o in obs:o.select_set(True)
    bpy.context.view_layer.objects.active=obs[0]
    bpy.ops.export_scene.fbx(filepath=str(path),use_selection=True,object_types={'MESH'},axis_forward='-Z',axis_up='Y',global_scale=1,apply_unit_scale=False,apply_scale_options='FBX_SCALE_NONE',use_mesh_modifiers=True,mesh_smooth_type='FACE',use_triangles=True,path_mode='COPY',embed_textures=True,add_leaf_bones=False,bake_anim=False)
assets=[];variants=[];allobs=[]
for code,label in [('A','Original'),('B','Broad'),('C','Upright')]:
    prefix='PowderFir_'+code+'_'+label;sourcecol=bpy.data.collections[prefix]
    sourcecol.hide_render=True
    bark=bpy.data.objects[prefix+'_Bark'];source_root=sum((bark.data.vertices[i].co for i in range(18)),Vector())/18
    source_root.z=0
    made=[]
    for suffix,tile,budget in [('Bark',1,900),('Snow',0,6500)]:
        src=bpy.data.objects[prefix+'_'+suffix];o=src.copy();o.data=src.data.copy();EXPORT.objects.link(o);o.name='FP_Powder_'+code+'_'+suffix;o.location=(0,0,0)
        if suffix!='Bark':reduce(o,budget)
        portable(o,tile);made.append(o)
    src=bpy.data.objects[prefix+'_NeedleSprays'];me=src.data
    adjacency=[[] for _ in me.vertices]
    for e in me.edges:
        a,b=e.vertices;adjacency[a].append(b);adjacency[b].append(a)
    seen=set();components=[]
    for i in range(len(me.vertices)):
        if i in seen:continue
        queue=[i];seen.add(i);comp=[]
        while queue:
            n=queue.pop();comp.append(n)
            for j in adjacency[n]:
                if j not in seen:seen.add(j);queue.append(j)
        components.append(sorted(comp))
    vm={p.vertices[0]:p.material_index for p in me.polygons}
    vs=[];fs=[];mis=[];batch=1;needles=0
    def flush():
        global vs,fs,mis,batch
        if not vs:return
        o=obj('FP_Powder_'+code+'_Needles_'+str(batch),vs,fs,mis);portable(o);made.append(o);batch+=1;vs=[];fs=[];mis=[]
    cores=set()
    for comp in components:
        if len(comp)!=17:cores.update(comp);continue
        v=[me.vertices[i].co.copy() for i in comp];root,tip=v[0],v[16]
        center=sum(v[6:11],Vector())/5;side=v[6]-center;up=(v[7]-center-side*math.cos(math.tau/5))/math.sin(math.tau/5)
        ring=[center+side*math.cos(k*math.tau/3)+up*math.sin(k*math.tau/3) for k in range(3)]
        offset=len(vs);vs.extend([root,*ring,tip]);faces=[(0,2,1),(0,3,2),(0,1,3),(4,1,2),(4,2,3),(4,3,1)]
        fs.extend(tuple(offset+i for i in f) for f in faces);mis.extend([vm.get(comp[0],2)]*6);needles+=1
        if len(fs)>=17400:flush()
    flush()
    # Preserve the foliage masses under the sprays, lightly simplified.
    ids=sorted(cores);mapping={j:i for i,j in enumerate(ids)}
    cv=[me.vertices[i].co.copy() for i in ids];cp=[p for p in me.polygons if p.vertices[0] in cores]
    core=obj('Core_'+code,cv,[tuple(mapping[i] for i in p.vertices) for p in cp],[p.material_index for p in cp]);reduce(core,700);portable(core)
    target=next(o for o in made if 'Needles_1' in o.name);active(target);core.select_set(True);bpy.ops.object.join()
    # All submeshes retain coordinates in the same tree-local frame in Blender.
    # The manifest records each bounds centre for Roblox native MeshPart CFrames.
    allv=[v.co for o in made for v in o.data.vertices]
    low=Vector(tuple(min(v[i] for v in allv) for i in range(3)));high=Vector(tuple(max(v[i] for v in allv) for i in range(3)))
    center=Vector(((low.x+high.x)/2,(low.y+high.y)/2,low.z))
    root=source_root-center;root.z=0
    entry={'id':code,'label':label,'size':dims(high-low),'trunk_base':xyz(root),'parts':[],'needles_preserved':needles}
    for o in made:
        for v in o.data.vertices:v.co-=center
        o.data.update();lo,hi=bounds(o)
        bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        bmesh.ops.dissolve_degenerate(bm,dist=.0001,edges=list(bm.edges))
        bmesh.ops.triangulate(bm,faces=list(bm.faces))
        # Decimating tiny enclosed snow bubbles can leave a two-sided triangle
        # with zero volume. FBX drops one side, so remove these internal remnants.
        visited=set();discard=[]
        for vertex in bm.verts:
            if vertex in visited:continue
            stack=[vertex];visited.add(vertex);component=[];faces=set()
            while stack:
                current=stack.pop();component.append(current);faces.update(current.link_faces)
                for edge in current.link_edges:
                    other=edge.other_vert(current)
                    if other not in visited:visited.add(other);stack.append(other)
            if len(faces)<4:discard.extend(component)
        if discard:bmesh.ops.delete(bm,geom=discard,context='VERTS')
        bm.to_mesh(o.data)
        o.data.calc_loop_triangles();tris=len(o.data.loop_triangles)
        bad=sum(not e.is_manifold for e in bm.edges);deg=sum(f.calc_area()<1e-10 for f in bm.faces);bm.free()
        assert bad==0 and deg==0,(o.name,bad,deg)
        assert tris<20000,(o.name,tris)
        a={'name':o.name,'file':o.name+'.fbx','dimensions_studs_xyz':dims(hi-lo),'center':xyz((lo+hi)/2),'triangles':tris}
        assets.append(a);entry['parts'].append(o.name);allobs.append(o)
        export(OUT/a['file'],[o])
    variants.append(entry)
    print('POWDER_EXPORT',code,needles,sum(a['triangles'] for a in assets if a['name'] in entry['parts']),flush=True)
# Gallery offsets make the import easy to inspect, never serve as placement data.
for i,entry in enumerate(variants):
    for o in allobs:
        if o.name in entry['parts']:o.location.x=(i-1)*19.5
export(OUT/'PowderFirsBundle.fbx',allobs)
(OUT/'manifest.json').write_text(json.dumps({'version':1,'library':'FrostbitePowderTemplates','bundle':'PowderFirsBundle','units':'intended studs; inspect import scale','pivot':'tree bottom-center; native part centres are recorded separately','textures':{k:'powder-firs-'+k+'.png' for k in images},'variants':variants,'assets':assets,'total_triangles':sum(a['triangles'] for a in assets)},indent=2))
SC.render.filepath=str(OUT/'powder-firs-roblox-preview.png');SC.cycles.samples=32
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'PowderFirsRoblox.blend'))
if '--no-render' not in sys.argv:bpy.ops.render.render(write_still=True)
print('POWDER_EXPORT_COMPLETE',len(assets),sum(a['triangles'] for a in assets),flush=True)

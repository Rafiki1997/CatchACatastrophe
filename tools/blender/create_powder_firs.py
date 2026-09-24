"""Build three native Powder Fir review models from the approved concept family.
Blender 5.1 background script. Art-only; no production library or source changes.
"""
import bpy, bmesh, math, random, json, sys
import numpy as np
from pathlib import Path
from mathutils import Vector
from mathutils.noise import noise_vector

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/frostbite-peaks/powder-firs-v1'
OUT.mkdir(parents=True,exist_ok=True)
if (OUT/'PowderFirs.blend').exists() and '--rebuild' not in sys.argv:
    raise RuntimeError('Existing scene preserved: use -- --rebuild to regenerate.')
bpy.ops.wm.read_factory_settings(use_empty=True)
SC=bpy.context.scene
STAGE=bpy.data.collections.new('PREVIEW_ONLY');SC.collection.children.link(STAGE)

def mat(name,c,rough=.9,bump=.0,scale=7):
    m=bpy.data.materials.new(name);m.use_nodes=True;nt=m.node_tree
    p=nt.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1);p.inputs['Roughness'].default_value=rough
    if bump:
        tc=nt.nodes.new('ShaderNodeTexCoord');n=nt.nodes.new('ShaderNodeTexNoise');n.inputs['Scale'].default_value=scale;n.inputs['Detail'].default_value=3
        nt.links.new(tc.outputs['Object'],n.inputs['Vector'])
        b=nt.nodes.new('ShaderNodeBump');b.inputs['Strength'].default_value=bump;b.inputs['Distance'].default_value=.045
        nt.links.new(n.outputs['Fac'],b.inputs['Height']);nt.links.new(b.outputs['Normal'],p.inputs['Normal'])
    return m

SNOW=mat('Powder snow',(.85,.91,.97),.9,.22,8)
GREENS=[mat('Needles %02d'%i,c,.91,.14,18) for i,c in enumerate([
    (.022,.069,.041),(.032,.098,.049),(.045,.122,.052),(.061,.139,.061),(.080,.152,.067),(.029,.090,.064)])]
BARK=mat('Warm ridged bark',(.20,.105,.047),.94,.45,4)
FLOOR=mat('Review snow floor',(.66,.74,.83),.94,.14,5)
INK=mat('Review labels',(.045,.075,.105),.9)

# Low-poly sphere template used for canopy interiors and sculpting snow unions.
bm=bmesh.new();bmesh.ops.create_uvsphere(bm,u_segments=12,v_segments=8,radius=1)
bm.verts.ensure_lookup_table();bm.verts.index_update()
SV=[v.co.copy() for v in bm.verts];SF=[tuple(v.index for v in f.verts) for f in bm.faces];bm.free()

class Geo:
    def __init__(self):self.v=[];self.f=[];self.m=[];self.blobs=[];self.needles=[]
    def add(self,vs,fs,mi=0):
        k=len(self.v);self.v.extend(vs);self.f.extend(tuple(k+i for i in f) for f in fs);self.m.extend([mi]*len(fs))
    def oval(self,c,sz,angle=0,mi=0):
        self.blobs.append((tuple(c),sz,angle))
        co,si=math.cos(angle),math.sin(angle);vs=[]
        for v in SV:
            x,y,z=v.x*sz[0],v.y*sz[1],v.z*sz[2]
            vs.append((c[0]+x*co-y*si,c[1]+x*si+y*co,c[2]+z))
        self.add(vs,SF,mi)
    def needle(self,start,direction,length,width,mi):
        vstart=len(self.v);fstart=len(self.f)
        p=Vector(start);d=Vector(direction).normalized();side=d.cross(Vector((0,0,1)))
        if side.length<.01:side=d.cross(Vector((0,1,0)))
        side.normalize();up=side.cross(d).normalized()
        vs=[];fs=[];n=5
        # Rounded, pointed needle cluster; root and tip taper into closed poles.
        vs.append(p)
        for t,w in [(.22,.82),(.62,1),(.88,.52)]:
            for j in range(n):
                a=j*math.tau/n
                vs.append(p+d*(length*t)+side*(width*w*math.cos(a))+up*(width*.45*w*math.sin(a))-Vector((0,0,length*.10*t*t)))
        vs.append(p+d*length-Vector((0,0,length*.1)))
        for j in range(n):fs.append((0,1+(j+1)%n,1+j))
        for k in range(2):
            for j in range(n):fs.append((1+k*n+j,1+k*n+(j+1)%n,1+(k+1)*n+(j+1)%n,1+(k+1)*n+j))
        for j in range(n):fs.append((11+j,11+(j+1)%n,16))
        self.add(vs,fs,mi)
        samples=[p+d*(length*t)-Vector((0,0,length*.1*t*t)) for t in (.42,.68,.93)]
        self.needles.append((vstart,len(self.v),fstart,len(self.f),samples))
    def cull_buried_needles(self,blobs):
        # Remove complete needle elements intersecting a snow mound so tips cannot
        # emerge through its upper surface. Geometry remains closed after filtering.
        points=np.array([[tuple(v) for v in item[4]] for item in self.needles],dtype=np.float32)
        covered=np.zeros(points.shape[:2],dtype=bool)
        for c,sz,angle in blobs:
            delta=points-np.array(c,dtype=np.float32)
            co,si=math.cos(angle),math.sin(angle)
            x=(delta[:,:,0]*co+delta[:,:,1]*si)/sz[0]
            y=(-delta[:,:,0]*si+delta[:,:,1]*co)/sz[1]
            z=delta[:,:,2]/sz[2]
            covered|=(x*x+y*y+z*z)<1.025
        drop=covered.any(axis=1);keepv=np.ones(len(self.v),dtype=bool);keepf=np.ones(len(self.f),dtype=bool)
        for bad,item in zip(drop,self.needles):
            if bad:keepv[item[0]:item[1]]=False;keepf[item[2]:item[3]]=False
        remap=np.cumsum(keepv)-1
        self.v=[v for v,k in zip(self.v,keepv) if k]
        self.f=[tuple(int(remap[i]) for i in f) for f,k in zip(self.f,keepf) if k]
        self.m=[m for m,k in zip(self.m,keepf) if k]
        return int(drop.sum())
    def rod(self,a,b,r1,r2,mi=0,n=8):
        a,b=Vector(a),Vector(b);d=(b-a).normalized();side=d.cross(Vector((0,0,1)))
        if side.length<.01:side=d.cross(Vector((0,1,0)))
        side.normalize();up=d.cross(side).normalized();vs=[]
        for p,r in [(a,r1),(b,r2)]:
            for j in range(n):vs.append(p+r*(side*math.cos(j*math.tau/n)+up*math.sin(j*math.tau/n)))
        fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]
        for j in range(n):fs.append((j,(j+1)%n,(j+1)%n+n,j+n))
        self.add(vs,fs,mi)
    def object(self,name,col,mats,smooth=True):
        me=bpy.data.meshes.new(name);me.from_pydata(self.v,[],self.f);me.update()
        for m in mats:me.materials.append(m)
        for p,mi in zip(me.polygons,self.m):p.material_index=mi;p.use_smooth=smooth
        bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
        ob=bpy.data.objects.new(name,me);col.objects.link(ob);return ob

def activate(o):
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o

CONFIGS=[
    dict(code='A',label='Original',seed=728,h=26.0,r=6.1,phase=.32,tiers=8,x=-19.5),
    dict(code='B',label='Broad',seed=1328,h=23.5,r=6.95,phase=.71,tiers=7,x=0),
    dict(code='C',label='Upright',seed=2328,h=28.3,r=5.65,phase=-.18,tiers=9,x=19.5),
]
TREES=[];REPORT=[]
for cfg in CONFIGS:
    rng=random.Random(cfg['seed']);h=cfg['h'];R=cfg['r'];prefix='PowderFir_'+cfg['code']+'_'+cfg['label']
    col=bpy.data.collections.new(prefix);SC.collection.children.link(col)
    foliage=Geo();wood=Geo();snow=Geo()
    # Flared bark trunk with real irregular longitudinal ridges and roots.
    n=18;levels=[0,.7,1.6,3,5,8,12,16,20,h*.94];vs=[];fs=[]
    for k,z in enumerate(levels):
        rad=.60*(1-z/h)**.75+.08
        if k==0:rad*=1.48
        for j in range(n):
            a=j*math.tau/n
            rr=rad*(1+.10*math.sin(j*2.7)+.07*math.sin(z*.9+j))
            vs.append((rr*math.cos(a)+.09*math.sin(z*.22),rr*math.sin(a)+.06*math.sin(z*.4),z))
    fs=[tuple(reversed(range(n)))]
    for k in range(len(levels)-1):
        for j in range(n):fs.append((k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j))
    fs.append(tuple((len(levels)-1)*n+j for j in range(n)));wood.add(vs,fs)
    for j in range(7):
        a=j*math.tau/7+.1
        wood.rod((math.cos(a)*1.14,math.sin(a)*1.14,.06),(math.cos(a)*.24,math.sin(a)*.24,1.4),.10,.30)
    for j in range(17):
        a=j*math.tau/17
        # Winding bark ribs give highlights along the visible trunk, not just noise.
        for k in range(6):
            z=k*.57+.1;rad=.67-.027*z
            wood.rod((math.cos(a+.045*math.sin(k))*rad,math.sin(a+.045*math.sin(k))*rad,z),
                     (math.cos(a+.045*math.sin(k+1))*rad*.98,math.sin(a+.045*math.sin(k+1))*rad*.98,z+.64),.045,.035,n=5)
    branches=0;needle_count=0
    for tier in range(cfg['tiers']):
        u=tier/(cfg['tiers']-1)
        z=5.7+(h-6.8)*(1-(1-u)**1.35)
        r=R*(1-u*.88)**.90
        count=6 if u<.45 else (5 if u<.8 else 4)
        phase=cfg['phase']+tier*1.07
        # Dense inner foliage hides the trunk while branch skirts remain articulated.
        foliage.oval((0,0,z-.48),(r*.29,r*.29,max(.24,r*.15)),0,0)
        for j in range(count):
            angle=phase+j*math.tau/count+rng.uniform(-.14,.14)
            length=r*rng.uniform(.89,1.09)
            dz=rng.uniform(-.44,.44)
            d=Vector((math.cos(angle),math.sin(angle),0));side=Vector((-d.y,d.x,0))
            width=length*rng.uniform(.30,.37)
            def pt(t,s=0,zz=0):
                return d*(length*t)+side*s+Vector((0,0,z+dz+length*.26*(1-t)-length*.15*t*t+zz))
            wood.rod(pt(.06,0,-.18),pt(.91,0,-.25),max(.055,length*.045),.035)
            # Green structural mass under each snow mantle, hidden by modeled sprays.
            foliage.oval(pt(.54,0,-.46),(length*.42,width*.76,max(.14,length*.10)),angle,0)
            # Feathered sub-branches extend from the center rib. Needles are actual closed meshes.
            for t in [.28,.44,.59,.73,.85]:
                for sign in [-1,1]:
                    start=pt(t,0,-.18)
                    a=angle+sign*(.70+(1-t)*.22)
                    twig=Vector((math.cos(a),math.sin(a),-.42)).normalized()
                    twiglen=width*(1.52-.56*t)
                    for k in range(6):
                        v=k/5;anchor=start+twig*(twiglen*v)
                        for flank in [-1,1]:
                            theta=a+flank*rng.uniform(.42,.92)
                            dire=Vector((math.cos(theta),math.sin(theta),rng.uniform(-.85,-.25)))
                            leaflen=length*rng.uniform(.115,.19)*(1-.25*v)+.10
                            foliage.needle(anchor,dire,leaflen,leaflen*rng.uniform(.12,.17),rng.choices(range(6),[1,3,4,3,1,2])[0]);needle_count+=1
                    foliage.needle(start+twig*twiglen,twig,length*.20+.12,length*.031,2);needle_count+=1
            for k in range(8):
                t=.43+k*.08
                for s in [-1,0,1]:
                    theta=angle+s*.26
                    foliage.needle(pt(t,width*s*.12,-.25),Vector((math.cos(theta),math.sin(theta),-.7)),length*.18+.12,length*.028,rng.randrange(1,6));needle_count+=1
            # Overlapping snow volumes get welded into a continuous sculpted surface.
            # The center mound plus smaller outer fingers produces irregular scalloped overhangs.
            for t,rx,wy,th in [(.28,.29,.68,.16),(.53,.34,1.0,.18),(.72,.25,.88,.16)]:
                snow.oval(pt(t,0,length*.18),(length*rx,width*wy,length*th),angle)
            for k in range(7):
                a=-math.pi*.80+k*(math.pi*1.60/6)
                t=.61+.27*math.cos(a)
                sy=width*.83*math.sin(a)
                finger=length*rng.uniform(.095,.145)
                snow.oval(pt(t,sy,length*.105),(finger*1.55,finger*.94,finger*.97),angle+rng.uniform(-.25,.25))
            branches+=1
    # Small bushy leader; no giant smooth frosting cone.
    for k in range(5):
        z=h-2.1+k*.43;rr=.64*(1-k/5)
        snow.oval((.10*math.sin(k),0,z),(rr,rr*.83,.65-k*.07))
        for j in range(9):
            a=j*math.tau/9+k*.6
            foliage.needle((0,0,z-.22),(math.cos(a),math.sin(a),-.7),rr*1.55+.15,.10 if k<2 else .06,rng.randrange(1,6));needle_count+=1
    for j in range(4):
        a=j*math.tau/4+.2
        snow.oval((math.cos(a)*.72,math.sin(a)*.72,.13),(.59,.47,.19),a)
    culled=foliage.cull_buried_needles(snow.blobs);needle_count-=culled
    print('BUILD_COMPONENTS',cfg['code'],'buried needles removed',culled,flush=True)
    obw=wood.object(prefix+'_Bark',col,[BARK]);obf=foliage.object(prefix+'_NeedleSprays',col,GREENS)
    obs=snow.object(prefix+'_Snow',col,[SNOW]);activate(obs)
    mod=obs.modifiers.new('Weld rounded snow mounds','REMESH');mod.mode='VOXEL';mod.voxel_size=.092;mod.use_smooth_shade=True
    bpy.ops.object.modifier_apply(modifier=mod.name)
    print('SNOW_WELDED',cfg['code'],len(obs.data.vertices),flush=True)
    mod=obs.modifiers.new('Soften snow joins','SMOOTH');mod.factor=1.05;mod.iterations=4;bpy.ops.object.modifier_apply(modifier=mod.name)
    # Small real geometric irregularity; snow shader adds finer grain.
    normals=[v.normal.copy() for v in obs.data.vertices]
    for v,normal in zip(obs.data.vertices,normals):
        v.co+=normal*(noise_vector(v.co*1.85).x*.045)
    mod=obs.modifiers.new('Snow topology reduction','DECIMATE');mod.ratio=.38;bpy.ops.object.modifier_apply(modifier=mod.name)
    for p in obs.data.polygons:p.use_smooth=True
    objects=[obw,obf,obs]
    pts=[v.co for o in objects for v in o.data.vertices]
    lo=Vector(tuple(min(v[i] for v in pts) for i in range(3)));hi=Vector(tuple(max(v[i] for v in pts) for i in range(3)))
    # Normalize intended height while preserving generated width/height proportions.
    scale=h/(hi.z-lo.z);off=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z))
    stats=[]
    for o in objects:
        for v in o.data.vertices:v.co=(v.co-off)*scale
        o.data.update();o.data.calc_loop_triangles()
        bm=bmesh.new();bm.from_mesh(o.data)
        nonman=sum(not e.is_manifold for e in bm.edges)
        deg=sum(f.calc_area()<1e-10 for f in bm.faces);bm.free()
        assert nonman==0,(o.name,nonman)
        assert deg==0,(o.name,deg)
        stats.append(dict(component=o.name,triangles=len(o.data.loop_triangles),nonmanifold_edges=nonman,degenerate_faces=deg))
        o.location.x=cfg['x']
    TREES.append((cfg,col,objects))
    REPORT.append(dict(variant=cfg['code'],name=cfg['label'],height=h,dimensions_roblox_whd=[(hi.x-lo.x)*scale,h,(hi.y-lo.y)*scale],branches=branches,modeled_needles=needle_count,components=stats,triangles=sum(s['triangles'] for s in stats)))
    print('TREE_BUILT',cfg['code'],REPORT[-1]['triangles'],flush=True)

def move(o,col):
    for c in list(o.users_collection):c.objects.unlink(o)
    col.objects.link(o);return o
def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.mesh.primitive_plane_add(size=2000,location=(0,0,-.015));ground=move(bpy.context.object,STAGE);ground.name='Review snow floor';ground.data.materials.append(FLOOR)
LABELS=[]
for cfg,col,objects in TREES:
    bpy.ops.object.text_add(location=(cfg['x'],-8.8,.015),rotation=(0,0,0));t=move(bpy.context.object,STAGE);t.name='Label_'+cfg['code']
    t.data.body=cfg['code']+'  /  '+cfg['label'].upper();t.data.align_x='CENTER';t.data.size=.83;t.data.extrude=0;t.data.materials.append(INK);LABELS.append(t)
SC.world=bpy.data.worlds.new('Winter daylight');SC.world.use_nodes=True
SC.world.node_tree.nodes['Background'].inputs[0].default_value=(.68,.79,1,1);SC.world.node_tree.nodes['Background'].inputs[1].default_value=.5
for name,xyz,power,size,c in [('Warm soft sun',(-25,-25,45),28000,19,(1,.94,.84)),('Sky fill',(25,-10,35),12000,22,(.71,.85,1)),('Snow rim',(0,22,37),22000,17,(.84,.93,1))]:
    bpy.ops.object.light_add(type='AREA',location=xyz);o=move(bpy.context.object,STAGE);o.name=name;o.data.energy=power;o.data.size=size;o.data.color=c;aim(o,(0,0,12))
bpy.ops.object.camera_add(location=(0,-95,48));cam=move(bpy.context.object,STAGE);cam.name='Review camera';cam.data.type='ORTHO';cam.data.ortho_scale=64;aim(cam,(0,0,12));SC.camera=cam
SC.render.engine='CYCLES';SC.cycles.samples=48;SC.cycles.use_denoising=True
SC.render.resolution_x=2400;SC.render.resolution_y=1600;SC.render.resolution_percentage=100;SC.render.image_settings.file_format='PNG'
SC.view_settings.view_transform='AgX';SC.view_settings.look='AgX - Medium High Contrast'
SC.render.filepath=str(OUT/'powder-firs-lineup.png')
# Save editable scene with all three visible and the hero comparison camera active.
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA'
            area.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'PowderFirs.blend'))
(OUT/'geometry-report.json').write_text(json.dumps(dict(status='Native Blender art-review meshes, not approved or integrated',materials='Procedural Blender materials. Texture baking and game optimization pending visual approval.',variants=REPORT),indent=2))
if '--no-render' not in sys.argv:
    bpy.ops.render.render(write_still=True)
    for o in LABELS:o.hide_render=True
    for cfg,col,objects in TREES:
        for _,other,obs in TREES:other.hide_render=other!=col
        for o in objects:o.location.x=0
        cam.location=(19,-48,30);aim(cam,(0,0,cfg['h']*.49));cam.data.ortho_scale=cfg['h']*1.20
        SC.render.resolution_x=1300;SC.render.resolution_y=1600;SC.render.filepath=str(OUT/('powder-fir-'+cfg['code'].lower()+'-'+cfg['label'].lower()+'.png'))
        bpy.ops.render.render(write_still=True)
        if cfg['code']=='A':
            cam.location=(12,-33,18);aim(cam,(0,0,10.4));cam.data.ortho_scale=14
            SC.render.resolution_x=1500;SC.render.resolution_y=1150;SC.render.filepath=str(OUT/'powder-fir-branch-detail.png');bpy.ops.render.render(write_still=True)
        for o in objects:o.location.x=cfg['x']
print('POWDER_FIRS_COMPLETE',sum(r['triangles'] for r in REPORT),flush=True)

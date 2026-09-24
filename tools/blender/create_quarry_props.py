"""Build the approved Cinder Quarry art pack, without touching game code.
Blender 5.1: --background --python tools/blender/create_quarry_props.py
Use -- --rebuild only for this script's generated, unedited output.
"""
import bpy, bmesh, math, random, json, sys
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/cinder-canyon/quarry-v2';OUT.mkdir(parents=True,exist_ok=True)
if (OUT/'CinderQuarry.blend').exists() and '--rebuild' not in sys.argv:
    raise RuntimeError('Refusing to overwrite an existing .blend without --rebuild')
bpy.ops.wm.read_factory_settings(use_empty=True)
SC=bpy.context.scene;SC.unit_settings.system='NONE'
PAL=[(191,78,44),(215,95,51),(234,119,65),(246,145,83),
     (158,62,39),(180,69,40),(223,104,57),(241,132,74),
     (119,77,43),(153,102,55),(177,126,73),(198,150,94),
     (58,49,43),(78,68,55),(47,49,55),(84,80,80),
     (53,112,51),(73,137,57),(99,156,61),(135,177,69),
     (44,108,91),(67,132,106),(86,152,122),(117,173,134),
     (238,115,34),(255,164,38),(255,207,61),(255,229,126),
     (74,40,31),(133,67,42),(171,82,45),(245,204,148)]
atlas=bpy.data.images.new('QuarryPalette',width=512,height=16,alpha=False)
atlas.pixels=[v for y in range(16) for x in range(512) for v in (*[c/255 for c in PAL[x//16]],1)]
atlas.filepath_raw=str(OUT/'quarry-palette.png');atlas.file_format='PNG';atlas.save();atlas.pack()
MAT=bpy.data.materials.new('Quarry_Palette');MAT.use_nodes=True
bs=MAT.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.84
t=MAT.node_tree.nodes.new('ShaderNodeTexImage');t.image=atlas;t.interpolation='Closest';MAT.node_tree.links.new(t.outputs['Color'],bs.inputs['Base Color'])
EXPORT=bpy.data.collections.new('EXPORT_12_ASSETS');SC.collection.children.link(EXPORT)
PREVIEW=bpy.data.collections.new('PREVIEW_ONLY');SC.collection.children.link(PREVIEW)
PARTS=[];ASSETS=[];META=[]

def paint(o,color):
    o.data.materials.clear();o.data.materials.append(MAT)
    while o.data.uv_layers:o.data.uv_layers.remove(o.data.uv_layers[0])
    uv=o.data.uv_layers.new(name='PaletteUV');uv.active_render=True
    colors=color if isinstance(color,list) else [color]
    for p in o.data.polygons:
        c=colors[p.index%len(colors)]
        for li in p.loop_indices:uv.data[li].uv=((c+.5)/32,.5)
    PARTS.append(o);return o

def mesh(name,vs,fs,color):
    d=bpy.data.meshes.new(name);d.from_pydata(vs,[],fs);d.update()
    o=bpy.data.objects.new(name,d);SC.collection.objects.link(o);return paint(o,color)

def box(p,s,color,bevel=.12,rot=(0,0,0)):
    bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=bpy.context.object;o.scale=s
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        m=o.modifiers.new('Chamfer','BEVEL');m.width=bevel;m.segments=1
        bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=m.name)
    o.rotation_euler=rot;return paint(o,color)

def beam(a,b,width,depth,color,bevel=.1):
    a,b=Vector(a),Vector(b);o=box((a+b)/2,(width,depth,(b-a).length),color,bevel)
    o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o

def rod(a,b,r1,r2,color,sides=10):
    a,b=Vector(a),Vector(b)
    bpy.ops.mesh.primitive_cone_add(vertices=sides,radius1=r1,radius2=r2,depth=(b-a).length,location=(a+b)/2)
    o=bpy.context.object;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return paint(o,color)

def blob(p,s,color,seed=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=p);o=bpy.context.object
    rng=random.Random(seed)
    for v in o.data.vertices:
        v.co*=rng.uniform(.94,1.06)
        for i in range(3):v.co[i]*=s[i]
    return paint(o,color)

def mesa(p,rx,ry,h,tiers=3,seed=1):
    rng=random.Random(seed);n=10
    radial=[rng.uniform(.91,1.08) for i in range(n)]
    for k in range(tiers):
        scale=1-k*.12;z=p[2]+h*k/tiers;dz=h/tiers
        ox=rng.uniform(-.025,.025)*rx;oy=rng.uniform(-.02,.02)*ry
        rrings=[v*rng.uniform(.975,1.025) for v in radial]
        vs=[]
        for zz,rr in [(z,.94),(z+dz*.10,1),(z+dz*.88,.99),(z+dz,.91)]:
            for j in range(n):
                a=j*math.tau/n+.10
                vs.append((p[0]+ox+math.cos(a)*rx*scale*rr*rrings[j],p[1]+oy+math.sin(a)*ry*scale*rr*rrings[j],zz))
        fs=[tuple(reversed(range(n)))]
        for r in range(3):
            for j in range(n):fs.append((r*n+j,r*n+(j+1)%n,(r+1)*n+(j+1)%n,(r+1)*n+j))
        fs.append(tuple(3*n+j for j in range(n)))
        o=mesh('SedimentaryBlock',vs,fs,[0,1,6,1,2,6,0,1])
        uv=o.data.uv_layers[0]
        for poly in o.data.polygons:
            # A warm lit cap, dark lower seam, no painted random checker noise.
            c=3 if poly.index==len(fs)-1 else (4 if poly.index<=n else [1,2,6,1][poly.index%4])
            for li in poly.loop_indices:uv.data[li].uv=((c+.5)/32,.5)
        # Hairline broken sediment cracks, flush to selected broad side facets.
        for j in (1,3,6):
            a=Vector(vs[n+j]);b=Vector(vs[n+(j+1)%n])
            aa=Vector(vs[2*n+j]);bb=Vector(vs[2*n+(j+1)%n])
            outward=Vector(((a.x+b.x)/2-p[0],(a.y+b.y)/2-p[1],0)).normalized()*.025
            q0=a.lerp(b,.37).lerp(aa.lerp(bb,.37),.35)+outward
            q1=a.lerp(b,.44).lerp(aa.lerp(bb,.44),.61)+outward
            q2=a.lerp(b,.42).lerp(aa.lerp(bb,.42),.94)+outward
            rod(q0,q1,.025,.025,4,4);rod(q1,q2,.025,.025,4,4)

def ring(p,r,t,color,rotation=(0,0,0)):
    bpy.ops.mesh.primitive_torus_add(major_segments=16,minor_segments=6,location=p,rotation=rotation,major_radius=r,minor_radius=t)
    return paint(bpy.context.object,color)

def leaf(base,a,length,width,rise,drop,color):
    base=Vector(base);direction=Vector((math.cos(a),math.sin(a),0));side=Vector((-math.sin(a),math.cos(a),0))
    n=7;vs=[]
    for j in range(n+1):
        t=j/n;c=base+direction*length*t+Vector((0,0,rise*math.sin(math.pi*t*.85)-drop*t*t))
        w=width*(.04+.96*math.sin(math.pi*t)**.65)
        if j==n:w=.025
        for lat,z in [(-w,0),(0,width*.22*math.sin(math.pi*t)),(w,0),(0,-.07)]:vs.append(c+side*lat+Vector((0,0,z)))
    fs=[(3,2,1,0)]
    for j in range(n):
        for k in range(4):fs.append((j*4+k,j*4+(k+1)%4,(j+1)*4+(k+1)%4,(j+1)*4+k))
    fs.append(tuple(n*4+k for k in range(4)));return mesh('SucculentLeaf',vs,fs,color)

def crystal(p,r,h):
    n=6;vs=[]
    for z,s in [(0,.82),(h*.7,1),(h,.10)]:
        for i in range(n):
            a=i*math.tau/n;vs.append((p[0]+math.cos(a)*r*s,p[1]+math.sin(a)*r*s,p[2]+z))
    fs=[tuple(reversed(range(n)))]
    for j in range(2):
        for i in range(n):fs.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    fs.append(tuple(2*n+i for i in range(n)));mesh('AmberOre',vs,fs,[24,25,26,25,27,26])

def crate(p,size):
    x,y,z=p;w,d,h=size
    # Planked body with individually beveled boards and crossed front braces.
    for i in range(4):
        xx=x-w/2+(i+.5)*w/4
        for yy in (y-d/2,y+d/2):box((xx,yy,z+h/2),(w/4-.08,.25,h),[8,9,10],.04)
    for i in range(4):
        yy=y-d/2+(i+.5)*d/4
        for xx in (x-w/2,x+w/2):box((xx,yy,z+h/2),(.25,d/4-.08,h),[9,8,10],.04)
        box((x,yy,z+h-.12),(w,d/4-.06,.25),[9,10,8],.04)
    box((x,y,z+.15),(w,d,.30),8,.05)
    for xx in (x-w/2,x+w/2):
        for yy in (y-d/2,y+d/2):box((xx,yy,z+h/2),(.55,.55,h+.12),10,.05)
    for yy in (y-d/2-.18,y+d/2+.18):
        for zz in (z+.28,z+h-.28):box((x,yy,zz),(w+.4,.36,.5),10,.05)
        beam((x-w*.42,yy,z+.65),(x+w*.42,yy,z+h-.65),.43,.28,11,.03)

def bounds(o):
    return [min(v.co[i] for v in o.data.vertices) for i in range(3)],[max(v.co[i] for v in o.data.vertices) for i in range(3)]

def move_collection(o,c):
    for old in list(o.users_collection):old.objects.unlink(o)
    c.objects.link(o)

def finish(name,size,sockets=None):
    global PARTS
    bpy.ops.object.select_all(action='DESELECT')
    for o in PARTS:o.select_set(True)
    bpy.context.view_layer.objects.active=PARTS[0];bpy.ops.object.join()
    o=bpy.context.object;o.name=name;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    o.data.materials.clear();o.data.materials.append(MAT)
    for p in o.data.polygons:p.material_index=0;p.use_smooth=False
    bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
    lo,hi=bounds(o);offset=Vector(((lo[0]+hi[0])/2,(lo[1]+hi[1])/2,lo[2]))
    sc=Vector(tuple(size[i]/(hi[i]-lo[i]) for i in range(3)))
    for v in o.data.vertices:
        v.co-=offset
        for i in range(3):v.co[i]*=sc[i]
    o.data.update();move_collection(o,EXPORT);ASSETS.append(o);PARTS=[]
    ss={}
    for k,pos in (sockets or {}).items():
        v=Vector(pos)-offset;v=Vector(tuple(v[i]*sc[i] for i in range(3)))
        ss[k]=[round(v.x,4),round(v.z,4),round(-v.y,4)]
    META.append({'name':name,'file':name+'.fbx','dimensions_studs_xyz':[size[0],size[2],size[1]],'sockets_roblox_xyz_from_base':ss})
    bpy.context.view_layer.update();return o

def mine():
    # Two irregular buttresses and a rear/crown leave a genuinely recessed mine.
    mesa((-22,0,0),12,19,32,4,11);mesa((22,-1,0),12,18,31,4,12)
    mesa((0,-15,0),28,11,38,4,13)
    mesa((-3,-5,27),23,17,15,2,14)
    mesa((-27,14,0),7,10,12,2,16);mesa((28,12,0),7,10,10,2,17)
    # Deep dark interior, well behind the opening, not a painted front plate.
    box((0,-1,10),(21,1.5,20),12,.5)
    for x in (-13,13):
        box((x,17,11),(3.2,3.8,22),[8,9,10,9],.18)
        box((x,17,2),(3.6,4.2,1),12,.06)
        box((x,17,19),(3.5,4.1,.9),12,.04)
    box((0,17,23),(33,5,4),[10,9,11,9],.22)
    for x in (-11,11):box((x,17,23),(.65,5.2,4.25),12,.06)
    for s in (-1,1):beam((s*12,17.2,15),(s*6,17.2,21.4),1.5,2,10,.1)
    # Lantern includes housing; Claude supplies the separate light effect.
    beam((-15,17,22),(-19,20,22),.55,.55,12,.03)
    rod((-19,20,22),(-19,20,18.2),.13,.13,12,8)
    box((-19,20,16.8),(2.0,2.0,2.7),26,.12)
    box((-19,20,18.4),(2.7,2.7,.6),12,.10);box((-19,20,15.2),(2.6,2.6,.5),12,.08)
    for dx in (-1.0,1.0):
        for dy in (-1.0,1.0):beam((-19+dx,20+dy,15.3),(-19+dx,20+dy,18.2),.18,.18,12,.015)
    finish('CC_Quarry_Mine',(64,48,42),{'Lantern':(-19,20,16.8),'DoorBase':(0,19,0),'DoorHeader':(0,19,21)})

def terrace():
    mesa((0,-3,0),31,24,23,3,30)
    mesa((-5,-9,20),22,17,16,2,31)
    mesa((-27,9,0),10,14,13,2,32);mesa((26,6,0),9,15,16,3,33)
    mesa((-18,17,0),13,9,9,2,34)
    # Basalt blocks frame the lava face; lava itself is a separate runtime effect.
    for i,(x,y,h) in enumerate([(17,14,13),(27,16,10),(16,23,6),(29,23,5),(23,6,21)]):
        rod((x,y,0),(x,y,h),3.7,3.4,[14,15,14,12],6)
    o=finish('CC_Quarry_Terrace',(72,56,36),{'HoistBase':(-5,-9,36),'LavaUpperLip':(23,10,20),'LavaLowerLip':(23,18,10),'LavaFoot':(23,25,.5),'Crystal01':(13,12,19),'Crystal02':(-12,20,13)})
    # Mirror the ENTIRE asymmetric terrace so the exposed cascade is on the
    # outer/image-right side, including its open ledges and all effect sockets.
    for v in o.data.vertices:v.co.x=-v.co.x
    bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
    for p in META[-1]['sockets_roblox_xyz_from_base'].values():p[0]=-p[0]

def hoist():
    for x in (-7,7):
        box((x,0,9.5),(2,2.3,19),[8,9,10,9],.13)
        box((x,0,.65),(4,12,1.3),[8,10,9],.13)
        for y in (-4,4):beam((x,y,1),(x,0,7),1.0,1.0,10,.08)
        box((x,0,16.7),(2.3,2.6,.7),12,.03)
    box((0,0,20),(20,3,2.4),[10,11,9,10],.14)
    for s in (-1,1):beam((s*7,0,14.8),(s*3,0,19),1.2,1.2,10,.08)
    # Pulley and rope stay separate closed mesh components inside the asset.
    ring((0,1.8,18.7),1.35,.2,12,(math.pi/2,0,0))
    rod((0,1.8,17.7),(0,1.8,10.1),.13,.13,12,8)
    ring((0,1.8,9.9),.42,.12,12,(math.pi/2,0,0))
    crate((0,1.8,3.6),(6,6,5.8))
    for x in (-2.7,2.7):rod((x,1.8,9.4),(0,1.8,10),.12,.12,12,8)
    finish('CC_Quarry_Hoist',(20,16,22),{'Pulley':(0,1.8,18.7),'LoadCenter':(0,1.8,6.5)})

def cart():
    box((0,0,2.4),(8,11,1),[29,30,29],.18)
    for x in (-4,4):box((x,0,4.5),(.55,11.4,4.4),[29,30,8],.12)
    for y in (-5.5,5.5):box((0,y,4.5),(8.5,.55,4.4),[29,30,8],.12)
    for x in (-4.2,4.2):box((x,0,6.6),(.7,12,.65),[12,15,12],.08)
    for y in (-5.7,5.7):box((0,y,6.6),(8.6,.7,.65),12,.08)
    for y in (-3.9,3.9):
        rod((-5,y,1.5),(5,y,1.5),.32,.32,12)
        for x in (-4.8,4.8):
            rod((x-.35,y,1.5),(x+.35,y,1.5),1.45,1.45,14,12)
            rod((x-.38,y,1.5),(x+.38,y,1.5),.53,.53,15,10)
    for i,(x,y,z,r,h) in enumerate([(-1.7,-2,4.2,1.4,3.0),(1.5,0,4.5,1.35,3.0),(-1,2.7,4.3,1.6,3.5),(1.6,3,4.2,.9,2.1)]):crystal((x,y,z),r,h)
    for x in (-4.5,4.5):
        for y in (-4.7,4.7):blob((x,y,5.7),(.17,.17,.17),15)
    finish('CC_Quarry_Cart',(11,14,8),{'OreGlow':(0,0,6.5)})

def rail():
    for i in range(8):box((0,-11.5+i*3.3,.25),(12,.95,.5),[8,9,10,9],.07)
    for x in (-5.0,5.0):
        box((x,0,.65),(.45,26,.8),[14,15,14],.06)
        for y in (-9.8,-3.2,3.4,10):box((x,y,.52),(1,1,.13),12,.02)
    finish('CC_Quarry_Rail',(12,26,1),{'TrackCenter':(0,0,.9)})

def cactus_stem(p,r,h):
    # Alternating radius creates a ribbed saguaro, with a rounded closed tip.
    n=20;rings=[(0,.94),(.10*h,1),(.78*h,.97),(.91*h,.84),(.98*h,.50),(h,.08)];vs=[]
    for z,s in rings:
        for i in range(n):
            a=i*math.tau/n;rr=r*s*(1 if i%2==0 else .83)
            vs.append((p[0]+math.cos(a)*rr,p[1]+math.sin(a)*rr,p[2]+z))
    fs=[tuple(reversed(range(n)))]
    for j in range(len(rings)-1):
        for i in range(n):fs.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    fs.append(tuple((len(rings)-1)*n+i for i in range(n)))
    mesh('RibbedCactus',vs,fs,[16,17,18,17])

def flower(p,r):
    for i in range(5):
        a=i*math.tau/5
        blob((p[0]+math.cos(a)*r*.6,p[1]+math.sin(a)*r*.6,p[2]),(r*.55,r*.55,r*.3),[24,25,24],i)
    blob((p[0],p[1],p[2]+r*.14),(r*.30,r*.30,r*.25),26,7)

def cactus_tall():
    cactus_stem((0,0,0),1.5,15)
    for s,z,h in [(-1,5,5.5),(1,8,4.5)]:
        rod((s*.8,0,z),(s*3.5,0,z+1),.80,.80,[16,17,18],10)
        blob((s*3.5,0,z+1),(.85,.85,.9),17,5)
        cactus_stem((s*3.5,0,z+1),.83,h)
    for i in range(3):flower((math.cos(i*2.1)*.4,math.sin(i*2.1)*.4,15),.55)
    finish('CC_Quarry_Cactus_Tall',(9,7,17))

def cactus_round():
    cactus_stem((-.8,0,0),2.2,4.8);cactus_stem((1.8,.6,0),1.35,3);cactus_stem((.8,-1.7,0),1.2,2.6)
    flower((-.8,0,4.9),.8);flower((1.8,.6,3.1),.55)
    finish('CC_Quarry_Cactus_Round',(7,7,6))

def agave():
    for i in range(11):leaf((0,0,.1),i*math.tau/11,5,1.1,3+(i%3)*.4,1,[20,21,22,21])
    for i in range(5):leaf((0,0,.1),i*math.tau/5,2.4,.75,6.5,.2,[21,22,23,20])
    finish('CC_Quarry_Agave',(11,11,7))

def flowers():
    for i in range(9):leaf((0,0,.1),i*math.tau/9,2.7,.62,1.6,.5,[16,18,17])
    for i in range(5):
        a=i*math.tau/5;x=1.65*math.cos(a);y=1.65*math.sin(a);h=2.1+(i%2)*.6
        rod((x,y,.1),(x,y,h),.07,.05,16,6);flower((x,y,h),.75)
    finish('CC_Quarry_Flowers',(6,6,4))

mine();terrace();hoist();cart();rail()
mesa((0,0,0),13.5,10.5,22,4,63);finish('CC_Quarry_Mesa_Large',(27,21,22))
mesa((0,0,0),11,8.5,11,3,74);finish('CC_Quarry_Mesa_Low',(22,17,11))
cactus_tall();cactus_round();agave();flowers()
crate((0,0,0),(6,6,6));finish('CC_Quarry_Crate',(6,6,6))

def export(path,objects):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.hide_set(False);o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.fbx(filepath=str(path),use_selection=True,object_types={'MESH'},axis_forward='-Z',axis_up='Y',global_scale=1,
        apply_unit_scale=False,apply_scale_options='FBX_SCALE_NONE',bake_space_transform=False,use_mesh_modifiers=True,
        mesh_smooth_type='FACE',use_triangles=True,path_mode='COPY',embed_textures=True,add_leaf_bones=False,bake_anim=False)

for o,entry in zip(ASSETS,META):
    o.data.calc_loop_triangles();entry['triangles']=len(o.data.loop_triangles)
    bm=bmesh.new();bm.from_mesh(o.data);bad=sum(not e.is_manifold for e in bm.edges);bm.free()
    assert bad==0,(o.name,bad);assert all(p.area>1e-8 for p in o.data.polygons),o.name
    assert entry['triangles']<15000,(o.name,entry['triangles'])
    entry['nonmanifold_edges']=bad;export(OUT/entry['file'],[o])
for i,o in enumerate(ASSETS):o.location=((i%4-1.5)*85,(i//4-1)*75,0)
export(OUT/'CinderQuarryBundle.fbx',ASSETS)
(OUT/'manifest.json').write_text(json.dumps({'version':2,'bundle':'CinderQuarryBundle.fbx','texture':'quarry-palette.png','units':'one modeling unit = one intended Roblox stud; verify import scale',
    'blender_front':'+Y','roblox_front':'-Z','blender_up':'+Z','roblox_up':'+Y','pivot':'base-center','assets':META,
    'collision':'decorative meshes; use explicit layout collision proxies; no physics/interaction changes',
    'glow':'colors only; Claude supplies lava, lantern lights and optional ore glow separately'},indent=2))

def mat(name,c):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*c,1)
    m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.9;return m

def pv(o):move_collection(o,PREVIEW);return o
floor=mat('Preview_background',(.72,.65,.54));base=mat('Preview_plinth',(.17,.20,.19));textmat=mat('Preview_text',(.96,.89,.72))
for i,o in enumerate(ASSETS):
    q=o.copy();q.data=o.data.copy();PREVIEW.objects.link(q)
    k=34/max(o.dimensions);q.scale=(k,k,k);q.location=((i%4-1.5)*49,(i//4-1)*54,0)
    q.name='Display_'+o.name
    x,y,_=q.location
    bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=21,depth=.45,location=(x,y,-.30));pv(bpy.context.object).data.materials.append(base)
    bpy.ops.object.text_add(location=(x,y+18,.015),rotation=(0,0,math.pi));t=pv(bpy.context.object)
    t.data.body=o.name.replace('CC_Quarry_','').replace('_',' ').upper();t.data.size=1.3;t.data.align_x='CENTER';t.data.materials.append(textmat)
EXPORT.hide_render=True;EXPORT.hide_viewport=True
bpy.ops.mesh.primitive_plane_add(size=1600,location=(0,0,-.6));pv(bpy.context.object).data.materials.append(floor)
SC.world=bpy.data.worlds.new('Soft_daylight');SC.world.use_nodes=True
SC.world.node_tree.nodes['Background'].inputs[0].default_value=(.72,.79,.9,1);SC.world.node_tree.nodes['Background'].inputs[1].default_value=.65
def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
for p,power,size in [((-65,80,150),150000,95),((100,-55,120),95000,85),((-70,-95,100),65000,75)]:
    bpy.ops.object.light_add(type='AREA',location=p);l=pv(bpy.context.object);l.data.energy=power;l.data.size=size;aim(l,(0,0,0))
bpy.ops.object.camera_add(location=(15,195,205));cam=pv(bpy.context.object);cam.data.type='ORTHO';cam.data.ortho_scale=233;aim(cam,(0,0,8));SC.camera=cam
SC.render.engine='CYCLES';SC.cycles.samples=24;SC.cycles.use_denoising=True
SC.view_settings.view_transform='Standard';SC.view_settings.look='Medium High Contrast'
SC.render.resolution_x=2000;SC.render.resolution_y=1700;SC.render.resolution_percentage=100;SC.render.image_settings.file_format='PNG'
SC.render.filepath=str(OUT/'preview-all-assets.png')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'CinderQuarry.blend'))
if '--no-render' not in sys.argv:
    bpy.ops.render.render(write_still=True)
    for o in PREVIEW.objects:
        if o.type=='FONT' or (o.type=='MESH' and o.name!='Plane'):o.hide_render=True
    EXPORT.hide_render=False
    for o in ASSETS:o.hide_render=True
    for o in ASSETS:
        old=o.location.copy();o.location=(0,0,0);o.hide_render=False
        e=max(o.dimensions);cam.location=(e*.72,e*1.7,e*1.12);cam.data.ortho_scale=e*1.75;aim(cam,(0,0,o.dimensions.z*.48))
        SC.render.resolution_x=1100;SC.render.resolution_y=950;SC.render.filepath=str(OUT/(o.name+'-preview.png'))
        bpy.ops.render.render(write_still=True);o.location=old;o.hide_render=True
print('QUARRY_COMPLETE',str(OUT),sum(m['triangles'] for m in META),'triangles')

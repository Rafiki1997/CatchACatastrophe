"""Alpine Outpost V2 production art. Blender 5.1, standalone, no game edits.
Run --background --python this_file; -- --rebuild replaces generated output.
Coordinates in this script: +Y front, +Z up. Output manifest: Roblox XYZ.
"""
import bpy, bmesh, math, random, json, sys
import numpy as np
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/frostbite-peaks/alpine-v2'
OUT.mkdir(parents=True,exist_ok=True)
if (OUT/'AlpineOutpost.blend').exists() and '--rebuild' not in sys.argv:
    raise RuntimeError('Existing editable .blend preserved. Explicit --rebuild required.')
bpy.ops.wm.read_factory_settings(use_empty=True)
SC=bpy.context.scene
EXPORT=bpy.data.collections.new('EXPORT_ALPINE_ASSETS');SC.collection.children.link(EXPORT)
PREVIEW=bpy.data.collections.new('PREVIEW_ONLY');SC.collection.children.link(PREVIEW)
PARTS=[];ASSETS=[];META=[]

# Real UV texture maps, one material so imports remain one mesh per asset.
SNOW,WOOD,DARKWOOD,TEAL,SLATE,GLASS,IRON,ROPE,BARK,FIR,CANVAS,GOLD,STONE,ICE,GRASS,SNOWSHADE=range(16)
COLORS=[(237,244,248),(147,94,51),(87,55,34),(29,102,115),
        (92,110,135),(128,78,34),(51,62,73),(169,145,102),
        (88,66,44),(31,78,63),(232,112,43),(192,141,57),
        (132,147,163),(150,204,228),(164,136,84),(210,225,237)]
SIZE=2048;TILE=SIZE//4
color=np.ones((SIZE,SIZE,4),np.float32)
rough=np.ones_like(color);normal=np.ones_like(color)
Y,X=np.mgrid[0:TILE,0:TILE].astype(np.float32)/TILE
rng=np.random.default_rng(4923)
for idx,c in enumerate(COLORS):
    grain=rng.normal(0,1,(TILE,TILE)).astype(np.float32)
    broad=np.sin(X*math.tau*3.0+np.sin(Y*math.tau*2))*.5+np.sin(Y*math.tau*4+X*6)*.25
    h=grain*.08+broad*.12
    if idx in (WOOD,DARKWOOD,BARK):
        warp=X*54+np.sin(Y*9)*.9+np.sin(Y*24+X*13)*.3
        lines=np.sin(warp*math.tau)+np.sin(warp*math.tau*2.3)*.28
        h=lines*.23+grain*.03+broad*.13
        r=np.sqrt(((X-.28)*2.8)**2+((Y-.58)*.65)**2)
        knot=np.exp(-r*13)*np.sin(r*170)*.45
        h+=knot
        amp=.14;roughval=.82
    elif idx in (SLATE,STONE):
        cracks=np.maximum(0,np.cos((X*3.7+np.sin(Y*12)*.13)*math.tau)-.985)*18
        h=broad*.3+grain*.055-cracks*.5
        amp=.13;roughval=.92
    elif idx in (SNOW,SNOWSHADE):
        h=grain*.13+broad*.09; amp=.022;roughval=.87
    elif idx in (CANVAS,ROPE):
        h=np.sin(X*math.tau*110)*np.sin(Y*math.tau*110)*.18+grain*.015+broad*.08
        amp=.055;roughval=.91
    elif idx==FIR:
        h=grain*.1+broad*.35; amp=.12;roughval=.9
    else:
        amp=.035;roughval=.28 if idx in (GLASS,ICE) else .67
    base=np.array(c,np.float32)/255
    a=np.clip(base[None,None,:]*(1+amp*h[:,:,None]*2),0,1)
    yy=(idx//4)*TILE;xx=(idx%4)*TILE
    color[yy:yy+TILE,xx:xx+TILE,:3]=a
    rough[yy:yy+TILE,xx:xx+TILE,:3]=np.clip(roughval+h[:,:,None]*.035,0,1)
    dy,dx=np.gradient(h)
    n=np.stack((-dx*1.8,-dy*1.8,np.ones_like(h)),axis=-1)
    n/=np.linalg.norm(n,axis=-1,keepdims=True)
    normal[yy:yy+TILE,xx:xx+TILE,:3]=n*.5+.5
def image_map(name,arr,noncolor=False):
    im=bpy.data.images.new(name,width=SIZE,height=SIZE,alpha=False)
    if noncolor:im.colorspace_settings.name='Non-Color'
    im.pixels.foreach_set(arr.ravel());im.file_format='PNG'
    im.filepath_raw=str(OUT/(name+'.png'));im.save();im.pack();return im
BASE=image_map('alpine-color',color);ROUGH=image_map('alpine-roughness',rough,True);NORMAL=image_map('alpine-normal',normal,True)
MAT=bpy.data.materials.new('Alpine_Textured');MAT.use_nodes=True
bs=MAT.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.85
for im,target in [(BASE,'Base Color'),(ROUGH,'Roughness'),(NORMAL,None)]:
    n=MAT.node_tree.nodes.new('ShaderNodeTexImage');n.image=im;n.interpolation='Linear'
    if target:MAT.node_tree.links.new(n.outputs['Color'],bs.inputs[target])
    else:
        nm=MAT.node_tree.nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.45
        MAT.node_tree.links.new(n.outputs['Color'],nm.inputs['Color']);MAT.node_tree.links.new(nm.outputs['Normal'],bs.inputs['Normal'])

def paint(o,tile,smooth=False):
    o.data.materials.clear();o.data.materials.append(MAT)
    while o.data.uv_layers:o.data.uv_layers.remove(o.data.uv_layers[0])
    uv=o.data.uv_layers.new(name='AlpineAtlasUV');uv.active_render=True
    coords=[v.co for v in o.data.vertices]
    lo=[min(v[i] for v in coords) for i in range(3)];hi=[max(v[i] for v in coords) for i in range(3)]
    for p in o.data.polygons:
        p.use_smooth=smooth
        axis=max(range(3),key=lambda i:abs(p.normal[i]));axes=[i for i in range(3) if i!=axis]
        for li in p.loop_indices:
            v=o.data.vertices[o.data.loops[li].vertex_index].co
            u=(v[axes[0]]-lo[axes[0]])/max(.001,hi[axes[0]]-lo[axes[0]])
            w=(v[axes[1]]-lo[axes[1]])/max(.001,hi[axes[1]]-lo[axes[1]])
            uv.data[li].uv=((tile%4+.035+.93*u)/4,(tile//4+.035+.93*w)/4)
    PARTS.append(o);return o
def mesh(name,vs,fs,tile,smooth=False):
    d=bpy.data.meshes.new(name);d.from_pydata(vs,[],fs);d.update()
    o=bpy.data.objects.new(name,d);SC.collection.objects.link(o)
    return paint(o,tile,smooth)
def box(p,s,tile,bevel=.08,rot=(0,0,0)):
    bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=bpy.context.object;o.scale=s
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        m=o.modifiers.new('Soft_edges','BEVEL');m.width=min(bevel,min(s)*.3);m.segments=1
        bpy.ops.object.modifier_apply(modifier=m.name)
    o.rotation_euler=rot;return paint(o,tile)
def rod(a,b,r1,r2,tile,sides=10,smooth=False):
    a,b=Vector(a),Vector(b)
    bpy.ops.mesh.primitive_cone_add(vertices=sides,radius1=r1,radius2=r2,depth=(b-a).length,location=(a+b)/2)
    o=bpy.context.object;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return paint(o,tile,smooth)
def beam(a,b,w,d,tile,bevel=.06):
    a,b=Vector(a),Vector(b);o=box((a+b)/2,(w,d,(b-a).length),tile,bevel)
    o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o
def ellipsoid(p,s,tile,seed=1,sub=2,smooth=True):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1,location=p);o=bpy.context.object
    rng=random.Random(seed)
    for v in o.data.vertices:
        v.co*=rng.uniform(.965,1.035)
        for i in range(3):v.co[i]*=s[i]
    return paint(o,tile,smooth)
def tube(points,r,tile,sides=6):
    ps=list(map(Vector,points));vs=[]
    for j,p in enumerate(ps):
        direction=(ps[min(j+1,len(ps)-1)]-ps[max(0,j-1)]).normalized()
        normal=direction.cross(Vector((0,0,1)))
        if normal.length<.01:normal=direction.cross(Vector((0,1,0)))
        normal.normalize();side=direction.cross(normal).normalized()
        for k in range(sides):
            a=k*math.tau/sides;vs.append(p+r*(normal*math.cos(a)+side*math.sin(a)))
    fs=[tuple(reversed(range(sides)))]
    for j in range(len(ps)-1):
        for k in range(sides):fs.append((j*sides+k,j*sides+(k+1)%sides,(j+1)*sides+(k+1)%sides,(j+1)*sides+k))
    fs.append(tuple((len(ps)-1)*sides+k for k in range(sides)))
    return mesh('Rope_or_stem',vs,fs,tile,True)
def torus(p,r,t,tile,rot=(0,0,0)):
    bpy.ops.mesh.primitive_torus_add(major_segments=16,minor_segments=6,major_radius=r,minor_radius=t,location=p,rotation=rot)
    return paint(bpy.context.object,tile,True)

def snowcap(p,rx,ry,h,seed=1):
    # Closed soft cornice with a scalloped skirt and gently domed upper surface.
    rng=random.Random(seed);n=18;rad=[rng.uniform(.93,1.08) for _ in range(n)]
    vs=[]
    for z,scale in [(-h*.15,.90),(0,1.02),(h*.32,1.0),(h*.78,.72),(h,.12)]:
        for i in range(n):
            a=i*math.tau/n
            vs.append((p[0]+math.cos(a)*rx*rad[i]*scale,p[1]+math.sin(a)*ry*rad[i]*scale,p[2]+z+math.sin(a*3+seed)*h*.045))
    fs=[tuple(reversed(range(n)))]
    for j in range(4):
        for i in range(n):fs.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    fs.append(tuple(4*n+i for i in range(n)))
    return mesh('Sculpted_Snowcap',vs,fs,SNOW,True)

def slate(p,rx,ry,h,seed=1,snow=True):
    rng=random.Random(seed);n=10
    rad=[rng.uniform(.84,1.12) for _ in range(n)]
    vs=[]
    for z,scale,dx in [(0,.85,0),(.13*h,1,0),(.72*h,.94,.08*rx),(h,.78,.03*rx)]:
        for i in range(n):
            a=i*math.tau/n+.17
            vs.append((p[0]+math.cos(a)*rx*rad[i]*scale+dx,p[1]+math.sin(a)*ry*rad[i]*scale,p[2]+z))
    fs=[tuple(reversed(range(n)))]
    for j in range(3):
        for i in range(n):fs.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    fs.append(tuple(3*n+i for i in range(n)))
    mesh('Fractured_Slate',vs,fs,SLATE)
    if snow:snowcap((p[0]+.03*rx,p[1],p[2]+h),rx*.86,ry*.86,min(1.5,h*.15),seed+77)

def move_collection(o,c):
    for old in list(o.users_collection):old.objects.unlink(o)
    c.objects.link(o)
def finish(name,size,sockets=None,notes='',exact=False):
    # Input size uses intended Roblox W,H,D, authoring is Blender W,D,H.
    global PARTS
    bpy.ops.object.select_all(action='DESELECT')
    for o in PARTS:o.select_set(True)
    bpy.context.view_layer.objects.active=PARTS[0];bpy.ops.object.join()
    o=bpy.context.object;o.name=name
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    o.data.materials.clear();o.data.materials.append(MAT)
    for p in o.data.polygons:p.material_index=0
    bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
    lo=Vector(tuple(min(v.co[i] for v in o.data.vertices) for i in range(3)))
    hi=Vector(tuple(max(v.co[i] for v in o.data.vertices) for i in range(3)))
    off=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z))
    desired=(size[0],size[2],size[1]);scale=Vector(tuple(desired[i]/(hi[i]-lo[i]) for i in range(3)))
    if exact:
        assert max(abs(hi[i]-lo[i]-desired[i]) for i in range(3))<.005,(name,'exact bounds',list(lo),list(hi),desired)
        assert abs(lo.z)<.005 and abs(lo.x+hi.x)<.005 and abs(lo.y+hi.y)<.005,(name,'exact origin')
        off=Vector((0,0,0));scale=Vector((1,1,1))
    for v in o.data.vertices:
        v.co-=off
        for i in range(3):v.co[i]*=scale[i]
    ss={}
    for key,p in (sockets or {}).items():
        v=Vector(p)-off
        for i in range(3):v[i]*=scale[i]
        ss[key]=[round(v.x,5),round(v.z,5),round(-v.y,5)]
    o.data.update();move_collection(o,EXPORT);PARTS=[];ASSETS.append(o)
    META.append({'name':name,'file':name+'.fbx','dimensions_studs_xyz':list(size),'sockets_roblox_xyz_from_base':ss,'notes':notes})
    return o

def lantern(p,scale=1):
    x,y,z=p;s=scale
    box((x,y,z+1.2*s),(1.05*s,1.05*s,1.6*s),GLASS,.09*s)
    for dx in (-.58,.58):
        for dy in (-.58,.58):beam((x+dx*s,y+dy*s,z+.25*s),(x+dx*s,y+dy*s,z+2.15*s),.10*s,.10*s,IRON,.02*s)
    box((x,y,z+.22*s),(1.4*s,1.4*s,.30*s),IRON,.05*s)
    box((x,y,z+2.12*s),(1.5*s,1.5*s,.32*s),IRON,.06*s)
    rod((x,y,z+2.22*s),(x,y,z+2.75*s),.95*s,.25*s,IRON,4)
    torus((x,y,z+3*s),.25*s,.055*s,IRON,(math.pi/2,0,0))

def lodge_prototype():
    # Stacked logs and stone footings; porch is kept separate from terrace art.
    for i in range(5):
        for s in (-1,1):box((s*9.1,-5.3+i*3.4,.55),(1.7,3.2,1.1),STONE,.16)
    for i in range(8):
        z=1.5+i*1.04
        for x in (-8.5,8.5):rod((x,-7.5,z),(x,7.2,z),.63,.63,WOOD,12)
        rod((-9.2,-6.6,z),(9.2,-6.6,z),.62,.62,WOOD,12)
        # Continuous log wall behind inset door/windows, recessed front plane.
        rod((-9.2,6.5,z),(9.2,6.5,z),.62,.62,WOOD,12)
    # Front and rear gable infill, individual planks.
    for yy in (-6.5,6.55):
        for i in range(13):
            x=-8.4+i*1.4;top=16.7-abs(x)*.79
            box((x,yy,(top+9.0)/2),(1.34,.45,max(.5,top-9)),WOOD,.04)
        for s in (-1,1):beam((s*9,yy+.2,9.1),(0,yy+.2,16.9),.38,.55,DARKWOOD,.05)
    # Roof underlayer and raised standing seams.
    angle=math.atan2(7.7,10.7)
    for s in (-1,1):
        box((s*5.35,0,13.12),(math.sqrt(10.7**2+7.7**2),18.5,.48),TEAL,.08,(0,s*angle,0))
        for yy in (-8.8,-5.9,-2.95,0,2.95,5.9,8.8):
            beam((s*.1,yy,17.12),(s*10.6,yy,9.55),.14,.19,TEAL,.035)
        # Snow blanket follows the roof and leaves a few deliberate teal edge gaps.
        nx,ny=9,12;vs=[]
        for layer in (0,1):
            for j in range(ny+1):
                yy=-9.1+j*18.2/ny
                for i in range(nx+1):
                    t=i/nx;xx=s*(.03+t*10.85)
                    zz=17.6-t*7.65+.17*math.sin(yy*.8+t*5)
                    if layer==0:zz-=.55
                    else:zz+=.35*math.sin(math.pi*t)+.16*math.cos(yy*1.7)*t
                    vs.append((xx,yy+(.16*math.sin(t*12+j) if j in (0,ny) else 0),zz))
        count=(nx+1)*(ny+1);fs=[]
        for j in range(ny):
            for i in range(nx):
                a=j*(nx+1)+i
                fs.append((count+a,count+a+1,count+a+nx+2,count+a+nx+1))
                fs.append((a+nx+1,a+nx+2,a+1,a))
        border=list(range(nx+1))+[j*(nx+1)+nx for j in range(1,ny+1)]+[ny*(nx+1)+i for i in range(nx-1,-1,-1)]+[j*(nx+1) for j in range(ny-1,0,-1)]
        for k,a in enumerate(border):
            b=border[(k+1)%len(border)];fs.append((a,b,count+b,count+a))
        mesh('Thick_Roof_Snow',vs,fs,SNOW,True)
    # Front door, paired warm multi-pane windows, cap and trim.
    box((0,7.18,4.0),(3.25,.36,5.9),DARKWOOD,.09)
    for x in (-1.8,1.8):box((x,7.5,4.1),(.28,.35,6.15),WOOD,.05)
    box((0,7.5,7.15),(3.9,.4,.4),WOOD,.05)
    for x in (-.95,-.3,.35,1):box((x,7.42,3.95),(.59,.12,5.1),WOOD,.025)
    torus((.9,7.60,3.55),.14,.045,IRON,(math.pi/2,0,0))
    def window(x,y,z,w,h):
        box((x,y,z),(w+.55,.36,h+.55),DARKWOOD,.06)
        box((x,y+.22,z),(w,.14,h),GLASS,.04)
        for xx in (-w/2,0,w/2):box((x+xx,y+.35,z),(.13,.19,h+.15),WOOD,.02)
        for zz in (-h/2,0,h/2):box((x,y+.35,z+zz),(w+.15,.19,.13),WOOD,.02)
        box((x,y+.38,z-h/2-.27),(w+.8,.9,.22),WOOD,.04)
        snowcap((x,y+.30,z+h/2+.28),(w+.8)*.52,.48,.34,int(x*8+80))
    for x in (-5.6,5.6):window(x,7.22,5.0,3.3,2.8)
    window(0,7.0,12.9,2.3,2.6)
    for i in range(13):box((-8.6+i*1.43,9.5,1.25),(1.37,5.4,.35),WOOD,.05)
    for x in (-8.6,8.6):
        box((x,9.4,.60),(.8,5.7,1.2),DARKWOOD,.07)
        for yy in (7.5,11.8):box((x,yy,2.5),(.5,.5,2.8),WOOD,.06)
        box((x,9.65,3.65),(.50,4.9,.34),WOOD,.07)
        for yy in (8.3,9.2,10.1,11.0):box((x,yy,2.5),(.23,.23,1.9),WOOD,.03)
    for s in (-1,1):
        box((s*5.9,11.8,3.65),(5.0,.45,.35),WOOD,.06)
        for xx in (3.5,4.6,5.7,6.8,7.9):box((s*xx,11.8,2.5),(.22,.22,1.9),WOOD,.025)
    # Door awning and side braces.
    box((0,8.2,8.0),(6.0,3.0,.55),TEAL,.10)
    snowcap((0,8.2,8.35),3.2,1.5,.50,21)
    for s in (-1,1):beam((s*2.55,7.35,6.7),(s*2.55,9.1,7.8),.22,.22,WOOD,.035)
    # Individually laid chimney blocks and cap; smoke is a runtime socket.
    for row in range(9):
        for col in range(2):
            box((-5.6+(col-.5)*1.2,-3.7,12.45+row*.85),(1.15,2.5,.78),STONE,.10)
    box((-5.6,-3.7,20.0),(3.0,3.2,.55),SLATE,.10)
    box((-5.6,-3.7,20.32),(1.85,1.95,.10),IRON,.02)
    for dx in (-1.2,1.2):snowcap((-5.6+dx,-3.7,20.4),.46,1.65,.32,45)
    for x in (-8.1,8.1):lantern((x,7.6,4.4),.63)
    for x in (-10.25,10.25):
        for j in range(4):rod((x,-5+j*3.5,9.6),(x,-5+j*3.5,8.3-j%2*.35),.15,.035,ICE,6)
    finish('FP_Alpine_Lodge',(30,27,31),{'DoorBase':(0,7.8,1.5),'PorchEntry':(0,12.2,1.5),'Smoke':(-5.6,-3.7,20.6),'WindowLeft':(-5.6,7.8,5),'WindowRight':(5.6,7.8,5),'LanternLeft':(-8.1,7.8,5.2),'LanternRight':(8.1,7.8,5.2)},'Includes visual porch and chimney; use sockets for walking support and effects. No smoke/light exported.')

def bridge_prototype():
    length=26;w=7.2
    def z(y):return 2.2-1.1*(1-(y/(length/2))**2)
    for i in range(24):
        y=-length/2+(i+.5)*length/24
        box((0,y,z(y)),(w,.93,.28),WOOD,.06,(0,0,.013*math.sin(i*3)))
        if i%3!=0:
            for s in (-1,1):
                ellipsoid((s*(2.6+.14*math.sin(i)),y,z(y)+.16),(.60+.16*math.sin(i*2),.34,.075),SNOW,seed=i+55,sub=1)
    for x in (-4.0,4.0):
        for y in (-13,13):
            rod((x,y,0),(x,y,6.4),.43,.38,DARKWOOD,10)
            box((x,y,.6),(.96,.96,.44),IRON,.05)
            box((x,y,5.6),(.92,.92,.3),IRON,.04)
            snowcap((x,y,6.45),.6,.6,.3,20)
            for dz in (3.8,4.05,4.3):torus((x,y,dz),.45,.075,ROPE)
        for zz in (.05,2.1,3.65):
            # Three twisted strands follow the same catenary, closed tubes.
            for strand in range(3):
                ps=[]
                for j in range(53):
                    y=-13+j*.5;a=j*.8+strand*math.tau/3
                    ps.append((x+math.cos(a)*.055,y,z(y)+zz+math.sin(a)*.055))
                tube(ps,.065,ROPE,5)
        for j in range(13):
            y=-12+j*2;tube([(x,y,z(y)+.1),(x,y,z(y)+3.65)],.055,ROPE,5)
    finish('FP_Alpine_Bridge',(10,7,28),{'EntryNear':(0,13,2.35),'EntryFar':(0,-13,2.35),'DeckMiddle':(0,0,1.25)},'Visual catenary bridge only; separate simple segmented deck collider required. Endpoints have equal walking height.')

def cliff(kind):
    if kind=='Tall':
        slate((-3,-1,0),8,7,14,3);slate((1,-1,12),7.3,6.1,10,5);slate((-.4,-2,21),5.9,5.2,8,9)
        slate((6,2,0),4.8,5.2,8,8);size=(25,34,22)
    elif kind=='Wide':
        slate((-5,0,0),8,7,8,12);slate((6,-1,0),7,6.5,11,13);slate((2,-2,9),7.2,6,7,15)
        size=(29,20,21)
    else:
        slate((0,0,0),12,10,6,17);slate((-6,-3,5),6,5,3,19)
        size=(28,11,24)
    finish('FP_Alpine_Cliff_'+kind,size,notes='Layered solid art. Arrange and rotate in bands; separate functional proxies.')

def fir(name,size,seed,tiers):
    rng=random.Random(seed);height=size[1];rad=size[0]*.5
    rod((0,0,0),(0,0,height*.88),rad*.085,rad*.022,BARK,10)
    for j in range(tiers):
        z=height*(.18+j*.13);r=rad*(1-j/(tiers+1))
        rod((0,0,z-height*.015),(0,0,z+height*.15),r*.65,.035,FIR,10)
        n=7 if j<3 else 6
        for i in range(n):
            a=i*math.tau/n+j*.76+seed*.13+rng.uniform(-.09,.09)
            rr=r*rng.uniform(.89,1.08);px=math.cos(a)*rr*.57;py=math.sin(a)*rr*.57
            rod((0,0,z+.45),(math.cos(a)*rr,math.sin(a)*rr,z-height*.055),.14,.035,BARK,6)
            # Closed teardrop branch silhouettes, with separate soft snow blankets.
            o=ellipsoid((px,py,z),(rr*.68,rr*.32,height*.028),FIR,i+j*13,sub=1,smooth=False)
            o.rotation_euler.z=a
            o=snowcap((px*.92,py*.92,z+height*.017),rr*.59,rr*.27,height*.031,seed+i+j*11)
            o.rotation_euler.z=0 # cap coordinates are rotated below around its center
            center=Vector((px*.92,py*.92,0))
            for v in o.data.vertices:
                q=v.co-center;v.co.x=center.x+q.x*math.cos(a)-q.y*math.sin(a);v.co.y=center.y+q.x*math.sin(a)+q.y*math.cos(a)
            # Fine pointed branchlets break the broad foliage silhouette.
            for side in (-1,1):
                aa=a+side*.24
                rod((px*.7,py*.7,z),(math.cos(aa)*rr*1.05,math.sin(aa)*rr*1.05,z-height*.033),rr*.11,.008,FIR,5)
    rod((0,0,height*.72),(0,0,height*.98),rad*.23,.025,FIR,9)
    snowcap((0,0,height*.90),rad*.14,rad*.14,height*.075,seed+100)
    finish(name,size,{'TrunkBase':(0,0,0)},'Tiered branch masses and sculpted snow; no separate needles, no collider on canopy.')

def tent_prototype():
    vs=[(-4,-5,0),(4,-5,0),(-4,5,0),(4,5,0),(0,-5,6.3),(0,5,6.3)]
    mesh('Canvas_Tent',vs,[(0,1,3,2),(0,4,5,2),(1,3,5,4),(0,1,4),(2,5,3)],CANVAS)
    # Dark recessed opening and two split rolled canvas borders.
    mesh('Door_Shadow',[(-2.35,5.04,.03),(2.35,5.04,.03),(0,5.04,4.6),(-2.35,4.92,.03),(2.35,4.92,.03),(0,4.92,4.6)],[(0,1,2),(5,4,3),(0,3,4,1),(1,4,5,2),(2,5,3,0)],DARKWOOD)
    for s in (-1,1):
        rod((s*2.45,5.12,.15),(0,5.12,4.8),.20,.14,CANVAS,8)
        for y in (-5,5):
            tube([(0,y,6.4),(s*5.5,y+(.8 if y>0 else -.8),.2)],.065,ROPE,5)
            rod((s*5.5,y+(.8 if y>0 else -.8),0),(s*5.5,y+(.8 if y>0 else -.8),.85),.1,.1,IRON,6)
    beam((0,-5.3,6.5),(0,5.3,6.5),.15,.15,ROPE,.025)
    finish('FP_Alpine_Tent',(12,7,12),{'DoorBase':(0,5.2,0)},'Static canvas expedition tent; no enterable interior.')

def woodpile():
    for j,n in enumerate((4,3,2)):
        for i in range(n):
            x=(i-(n-1)/2)*1.1;z=.58+j*.94
            rod((x,-2,z),(x,2,z),.55,.53,BARK,10)
            for y in (-2.015,2.015):
                rod((x,y-.035,z),(x,y+.035,z),.42,.42,WOOD,10)
                torus((x,y+.05,z),.27,.022,DARKWOOD,(math.pi/2,0,0))
    snowcap((0,0,2.65),1.65,2.12,.55,62)
    finish('FP_Alpine_Woodpile',(6,4,6))

def shrub():
    rng=random.Random(56)
    for i in range(11):
        a=i*math.tau/11;r=rng.uniform(1.6,3.2);h=rng.uniform(2,4)
        ps=[(0,0,.1),(r*.4*math.cos(a),r*.4*math.sin(a),h*.55),(r*math.cos(a),r*math.sin(a),h)]
        tube(ps,.075,BARK,5)
        for t in (.55,.85,1):
            p=(r*t*math.cos(a),r*t*math.sin(a),h*t)
            ellipsoid(p,(.45,.30,.24),SNOW,seed=i,sub=1)
    snowcap((0,0,.2),1.2,1.1,.35,73)
    finish('FP_Alpine_Frosted_Shrub',(7,5,7))

def grass():
    rng=random.Random(98)
    for i in range(18):
        a=i*2.4;r=rng.uniform(1.3,3);h=rng.uniform(2,4.5)
        base=(math.cos(a)*.35,math.sin(a)*.35,0);tip=(math.cos(a)*r,math.sin(a)*r,h)
        mid=(tip[0]*.35,tip[1]*.35,h*.62)
        tube([base,mid,tip],.045,GRASS,4)
        if i%2==0:
            rod((tip[0]*.86,tip[1]*.86,h*.85),tip,.12,.035,GRASS,6)
    snowcap((0,0,.1),1.2,1,.3,90)
    finish('FP_Alpine_Grass',(6,4,6))

def crate():
    box((0,0,1.8),(3.5,3.4,3.6),DARKWOOD,.07)
    for i in range(4):
        for y in (-1.76,1.76):box((-1.4+i*.93,y,1.8),(.87,.16,3.35),WOOD,.035)
        box((-1.4+i*.93,0,3.6),(.87,3.7,.22),WOOD,.035)
    for y in (-1.9,1.9):
        for z in (.3,3.3):box((0,y,z),(4,.22,.42),WOOD,.04)
        beam((-1.6,y,.65),(1.6,y,2.95),.38,.2,WOOD,.035)
        for x in (-1.55,1.55):
            for z in (.30,3.3):rod((x,y,z),(x,y+.10,z),.09,.09,IRON,8)
    snowcap((-.15,0,3.75),1.85,1.72,.35,44)
    finish('FP_Alpine_Crate',(4.5,4.5,4.5))

def barrel():
    n=14
    for i in range(n):
        a=i*math.tau/n;vs=[]
        for z,r in [(0,1.22),(.7,1.4),(2.8,1.4),(3.5,1.22)]:
            for rr,aa in [(r,a-.20),(r,a+.20),(r-.18,a+.20),(r-.18,a-.20)]:vs.append((rr*math.cos(aa),rr*math.sin(aa),z))
        fs=[(3,2,1,0),(12,13,14,15)]
        for j in range(3):
            for k in range(4):fs.append((j*4+k,j*4+(k+1)%4,(j+1)*4+(k+1)%4,(j+1)*4+k))
        mesh('Barrel_Stave',vs,fs,WOOD)
    for z in (.45,1.15,2.6,3.15):torus((0,0,z),1.39 if 1<z<3 else 1.33,.10,IRON)
    rod((0,0,3.35),(0,0,3.50),1.2,1.2,WOOD,14)
    snowcap((0,0,3.55),1.28,1.28,.27,69)
    finish('FP_Alpine_Barrel',(3.5,4.5,3.5))

def railing():
    for x in (-5.5,0,5.5):
        box((x,0,2.1),(.5,.55,4.2),WOOD,.08);snowcap((x,0,4.22),.43,.44,.25,70)
    for z in (1.4,3.4):box((0,0,z),(11.6,.3,.38),WOOD,.05)
    finish('FP_Alpine_Railing',(12,4.5,1.0),{'EndLeft':(-5.5,0,0),'EndRight':(5.5,0,0)})

def lantern_post():
    box((0,0,.35),(1.7,1.7,.7),SLATE,.12)
    box((0,0,3.1),(.65,.65,5.5),DARKWOOD,.08)
    beam((0,0,5.5),(0,1.2,6),.25,.25,IRON,.025)
    lantern((0,1.2,3.0),.85)
    snowcap((0,0,6),.55,.55,.35,86)
    finish('FP_Alpine_Lantern_Post',(2.4,7,3),{'Light':(0,1.2,4.2)})

def trailpost():
    box((0,0,1.55),(.55,.55,3.1),WOOD,.055)
    box((0,.32,2.3),(.42,.08,.7),GOLD,.015)
    snowcap((0,0,3.1),.4,.4,.24,85)
    finish('FP_Alpine_Trail_Post',(1,3.5,1))

def signpost():
    box((0,0,3.1),(.55,.6,6.2),WOOD,.08)
    for z,s,tile in [(4.9,1,TEAL),(3.75,-1,WOOD)]:
        vs=[(-2.4,-.15,z-.4),(2,-.15,z-.4),(2.8,-.15,z),(2,-.15,z+.4),(-2.4,-.15,z+.4)]
        vs+= [(x,.2,zz) for x,y,zz in vs]
        fs=[(4,3,2,1,0),(5,6,7,8,9)]+[(i,(i+1)%5,(i+1)%5+5,i+5) for i in range(5)]
        o=mesh('Wayfinding_Board',vs,fs,tile)
        if s<0:o.rotation_euler.z=math.pi
    snowcap((0,0,6.2),.43,.43,.27,65)
    finish('FP_Alpine_Signpost',(6,7,1),{'TextUpper':(0,.24,4.9),'TextLower':(0,.24,3.75)},'Blank boards for runtime text; no fabricated lettering.')

def pennant():
    rod((0,0,0),(0,0,10),.13,.10,WOOD,10)
    rod((0,0,10),(4.5,0,10),.10,.10,WOOD,8)
    nx,ny=6,5;vs=[]
    for side in (0,1):
        for j in range(ny+1):
            for i in range(nx+1):
                x=.3+i*4/nx;z=9.8-j*4.2/ny+(j/ny)**4*(.55 if i<nx/2 else -.55)
                vs.append((x,.24*math.sin(i*.8+j*.5)+side*.06,z))
    ct=(nx+1)*(ny+1);fs=[]
    for j in range(ny):
        for i in range(nx):
            a=j*(nx+1)+i;fs.extend([(a,a+1,a+nx+2,a+nx+1),(ct+a+nx+1,ct+a+nx+2,ct+a+1,ct+a)])
    border=list(range(nx+1))+[j*(nx+1)+nx for j in range(1,ny+1)]+[ny*(nx+1)+i for i in range(nx-1,-1,-1)]+[j*(nx+1) for j in range(ny-1,0,-1)]
    for j,a in enumerate(border):b=border[(j+1)%len(border)];fs.append((a,b,ct+b,ct+a))
    mesh('Teal_Pennant',vs,fs,TEAL,True)
    finish('FP_Alpine_Pennant',(5,11,1),{'PoleBase':(0,0,0)},'Static banner mesh; no simulated cloth.')

def flat_top(o,h):
    global PARTS
    # Broad rounded snow shoulder with a flat central mounting area, not a square plinth.
    n=12;vs=[]
    for z,r in [(h-2,4.4),(h-.7,4.4),(h,3.9)]:
        for i in range(n):
            a=i*math.tau/n;vs.append((r*math.cos(a),r*math.sin(a),z))
    fs=[tuple(reversed(range(n)))]
    for j in range(2):
        for i in range(n):fs.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    fs.append(tuple(2*n+i for i in range(n)))
    patch=mesh('Flat_Snow_Mount',vs,fs,SNOW,True)
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);patch.select_set(True)
    bpy.context.view_layer.objects.active=o;bpy.ops.object.join();PARTS=[]
    o.data.materials.clear();o.data.materials.append(MAT)
    for p in o.data.polygons:p.material_index=0
    META[-1]['sockets_roblox_xyz_from_base']['TopMount']=[0,h,0]

def roof_snow(cx,xspan,ymin,ymax,eave,ridge,thick=.8):
    nx,ny=16,12;vs=[]
    for layer in (0,1):
        for j in range(ny+1):
            y=ymin+(ymax-ymin)*j/ny
            for i in range(nx+1):
                t=-1+2*i/nx;x=cx+t*xspan
                z=ridge-(ridge-eave)*abs(t)
                z+=thick if layer else .03
                if layer:z+=.22*(1-abs(t))*math.cos(y*.5)
                vs.append((x,y,z))
    count=(nx+1)*(ny+1);fs=[]
    for j in range(ny):
        for i in range(nx):
            a=j*(nx+1)+i;fs.extend([(count+a,count+a+1,count+a+nx+2,count+a+nx+1),(a+nx+1,a+nx+2,a+1,a)])
    border=list(range(nx+1))+[j*(nx+1)+nx for j in range(1,ny+1)]+[ny*(nx+1)+i for i in range(nx-1,-1,-1)]+[j*(nx+1) for j in range(ny-1,0,-1)]
    for i,a in enumerate(border):b=border[(i+1)%len(border)];fs.append((a,b,count+b,count+a))
    mesh('Contract_Roof_Snow',vs,fs,SNOW,True)

def lodge():
    # Rebuilt to Claude's measured contract, no bounding-box rescale.
    box((4,-2.5,.5),(27.5,16,1),STONE,.12)
    box((-14.875,-5.5,.5),(10.25,12,1),STONE,.12)
    for row in range(11):
        z=1.55+row*1.04
        for x in (-9.2,17.2):rod((x,-10,z),(x,5,z),.55,.55,WOOD,12)
        rod((-9.75,-9.95,z),(17.75,-9.95,z),.55,.55,WOOD,12)
        gaps=[]
        if z<9.5:gaps.append((1.75,6.25))
        if 4.2<z<9.3:gaps.extend([(-5.5,-1.5),(9.5,13.5)])
        at=-9.75
        for a,b in sorted(gaps)+[(17.75,17.75)]:
            if a>at:rod((at,4.95,z),(a,4.95,z),.55,.55,WOOD,12)
            at=b
    # Main gables, leave a real aperture for the gable window.
    for y in (-10.25,5.25):
        for i in range(20):
            x=-9.4+i*1.37;top=25.5-abs(x-4)*13/15.75
            z0=12.5;segments=[(z0,top)]
            if y>0 and abs(x-4)<2.1:segments=[(z0,15),(18,top)]
            for low,high in segments:
                if high>low+.08:box((x,y,(high+low)/2),(1.31,.5,high-low),WOOD,.025)
    angle=math.atan2(13,15.75)
    for s in (-1,1):
        box((4+s*7.875,-2.25,19),(math.hypot(15.75,13),19.5,.45),TEAL,.06,(0,s*angle,0))
        for y in (-11.7,-7.5,-3.3,.9,5.1,7.1):beam((4,y,25.7),(4+s*15.7,y,12.75),.11,.17,TEAL,.02)
    roof_snow(4,16,-12,7.5,13,25.8,1.4)
    # Annex on viewer-right, asset -X; lean-to roof steps down toward the edge.
    for row in range(8):
        z=1.45+row*.96
        rod((-19.5,-11,z),(-19.5,0,z),.50,.50,WOOD,12)
        rod((-20,-11,z),(-9.75,-11,z),.5,.5,WOOD,12)
        if 3.8<z<7.2:
            rod((-20,0,z),(-16.25,0,z),.5,.5,WOOD,12)
            rod((-13.25,0,z),(-9.75,0,z),.5,.5,WOOD,12)
        else:rod((-20,0,z),(-9.75,0,z),.5,.5,WOOD,12)
    # Gable/roof closed loft, held strictly within the annex bounds.
    vs=[(-20,-11.5,9),(-9.75,-11.5,9),(-9.75,.5,9),(-20,.5,9),(-20,-11.5,10.8),(-9.75,-11.5,13),(-9.75,.5,13),(-20,.5,10.8)]
    mesh('Annex_Roof_Base',vs,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],TEAL)
    mesh('Annex_Snow',[(x,y,z+.1) for x,y,z in vs[4:]]+[(x,y,z+.5) for x,y,z in vs[4:]],[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],SNOW,True)
    # Contract porch, actual flat tops at 1.0 and 0.5.
    for i in range(15):box((-5.8+i*1.4,8.25,.84),(1.34,5.5,.32),WOOD,.035)
    box((4,11.5,.25),(5,1,.5),STONE,.06)
    for x in (-6,1.5,6.5,14):
        box((x,10.7,5.2),(.42,.42,8.6),DARKWOOD,.055)
        box((x,10.7,1.3),(.55,.55,.4),IRON,.03)
    for xmin,xmax in [(-6,1.5),(6.5,14)]:
        box(((xmin+xmax)/2,10.7,4.0),(xmax-xmin,.45,.4),WOOD,.06)
        for i in range(1,6):box((xmin+(xmax-xmin)*i/6,10.7,2.55),(.2,.2,2.65),WOOD,.025)
    box((4,7,10.55),(9,3,.45),TEAL,.08)
    snowcap((4,7,10.80),4.5,1.5,.40,681)
    for s in (-1,1):beam((4+s*4,5.6,9.0),(4+s*4,8.2,10.4),.25,.25,WOOD,.04)
    box((4,5.3,5.25),(4.5,.35,8.5),DARKWOOD,.05)
    for i in range(6):box((2.125+i*.75,5.49,5.25),(.70,.12,8.35),WOOD,.025)
    torus((5.6,5.60,4.8),.17,.045,IRON,(math.pi/2,0,0))
    def window(x,y,z,w,h):
        # Recessed dark-amber pane; Claude's runtime warm pane uses this socket.
        box((x,y-.12,z),(w,.16,h),GLASS,.02)
        for xx in (-w/2,w/2):box((x+xx,y+.10,z),(.23,.4,h+.4),DARKWOOD,.025)
        for zz in (-h/2,h/2):box((x,y+.10,z+zz),(w+.4,.4,.23),DARKWOOD,.025)
        box((x,y+.13,z),(.12,.18,h),WOOD,.02);box((x,y+.13,z),(w,.18,.12),WOOD,.02)
        box((x,y+.30,z-h/2-.25),(w+.8,.85,.24),WOOD,.04)
        snowcap((x,y+.17,z+h/2+.30),(w+.6)*.5,.40,.35,int(x*10+444))
    for x in (11.5,-3.5):window(x,5.45,6.75,4,4.5)
    window(4,5.45,16.5,3.5,3);window(-14.75,.45,5.5,3,3)
    for x in (14,-6):lantern((x,10.7,6.6),.65)
    for row in range(10):
        for i in range(2):box((8.5+(i-.5)*1.4,-7.5,20.55+row*.9),(1.34,2.8,.84),STONE,.065)
    box((8.5,-7.5,29.70),(3,3,.6),STONE,.08)
    box((8.5,-7.5,29.99),(1.6,1.6,.02),IRON,0)
    # Limit snow cornice wobble to the contract envelope; no surface-height rescale.
    bpy.context.view_layer.update()
    for o in PARTS:
        inv=o.matrix_world.inverted()
        for v in o.data.vertices:
            p=o.matrix_world@v.co;p.x=max(-20,min(20,p.x));p.y=max(-12,min(12,p.y));p.z=max(0,min(30,p.z));v.co=inv@p
    finish('FP_Alpine_Lodge',(40,30,24),{'DoorBase':(4,5.5,1),'PorchStep':(4,12,0),'PorchEntry':(4,11,1),
        'WindowW':(11.5,5.45,6.75),'WindowE':(-3.5,5.45,6.75),'WindowGable':(4,5.45,16.5),'AnnexWindow':(-14.75,.45,5.5),
        'PorchLanternW':(14,10.7,7.5),'PorchLanternE':(-6,10.7,7.5),'ChimneyTop':(8.5,-7.5,30)},
        'Contract revision: asymmetric east annex, porch top1.0, step0.5. Dark recessed panes; runtime warm glazing/lights separate.',exact=True)

def bridge():
    def top(y):return .3+1.2*(y/17)**2
    for i in range(35):
        y=-17+(i+.5)*34/35
        # Surface sockets denote the continuous deck curve; independent planks are level across their width.
        z=top(y)
        box((0,y,z-.15),(8,34/35-.035,.3),WOOD,.025)
        if i%3!=0:
            for s in (-1,1):ellipsoid((s*3.0,y,z+.045),(.50+.12*math.sin(i),.28,.045),SNOW,i+800,sub=1)
    # End lips land exactly at Z +-17 and top1.5.
    for y in (-16.93,16.93):box((0,y,1.35),(8,.14,.3),WOOD,.015)
    for x in (-4.6,4.6):
        for y in (-16.3,16.3):
            lit=(x>0 and y<0) or (x<0 and y>0)
            ph=6.45 if lit else 7.0
            box((x,y,ph/2),(.8,.8,ph),DARKWOOD,.045)
            for z in (.4,5.8):box((x,y,z),(.80,.80,.26),IRON,.025)
            for z in (3.3,3.55,3.8):torus((x,y,z),.34,.05,ROPE)
            if not lit:box((x,y,7.25),(.8,.8,.5),SNOW,.10)
    for x in (-4.4,4.4):
        for zz in (.04,1.4,3.0):
            for strand in range(3):
                ps=[]
                for j in range(41):
                    y=-16.3+j*32.6/40;a=j*1.07+strand*math.tau/3
                    ps.append((x+math.cos(a)*.045,y,top(y)+zz+math.sin(a)*.045))
                tube(ps,.048,ROPE,5)
        for i in range(17):
            y=-15.5+i*31/16;tube([(x,y,top(y)+.08),(x,y,top(y)+3)],.048,ROPE,5)
    for x,y in [(4.6,-16.3),(-4.6,16.3)]:
        box((x,y,6.96),(.48,.48,.65),GLASS,.03)
        box((x,y,6.53),(.72,.72,.16),IRON,.025)
        for dx in (-.29,.29):
            for dy in (-.29,.29):box((x+dx,y+dy,6.97),(.07,.07,.8),IRON,.01)
        box((x,y,7.36),(.8,.8,.20),IRON,.035)
        box((x,y,7.48),(.72,.72,.04),SNOW,.008)
    finish('FP_Alpine_Bridge',(10,7.5,34),{'NorthDeck':(0,-17,1.5),'SouthDeck':(0,17,1.5),'DeckMiddle':(0,0,.3),'LanternNW':(4.6,-16.3,7),'LanternSE':(-4.6,16.3,7)},
           'Deck top .3+1.2*(Z/17)^2. Use independently authored segmented walking collider. Posts define bounds.',exact=True)

def tent():
    vs=[(-3.1,-4,0),(3.1,-4,0),(-3.1,4.5,0),(3.1,4.5,0),(0,-4,5.5),(0,4.5,5.5)]
    mesh('Canvas_Tent',vs,[(0,1,3,2),(0,4,5,2),(1,3,5,4),(0,1,4),(2,5,3)],CANVAS)
    mesh('Dark_Door',[(-1.8,4.51,.01),(1.8,4.51,.01),(0,4.51,4.2),(-1.8,4.44,.01),(1.8,4.44,.01),(0,4.44,4.2)],[(0,1,2),(5,4,3),(0,3,4,1),(1,4,5,2),(2,5,3,0)],DARKWOOD)
    for s in (-1,1):
        rod((s*1.9,4.52,.1),(0,4.52,4.3),.12,.09,CANVAS,8)
        for y in (-3.5,3.5):
            tube([(0,y,5.55),(s*3.7,y,.15)],.05,ROPE,5);rod((s*3.7,y,0),(s*3.8,y,.5),.065,.065,IRON,6)
    snowcap((0,0,5.55),.36,4.25,.45,858)
    finish('FP_Alpine_Tent',(8,6,9),{'DoorBase':(0,4.55,0)},'Contract size, snow ridge and guy ropes. Static canvas tent.')
    META[-1]['sockets_roblox_xyz_from_base']['DoorBase']=[0,0,-4.5]

def landing(north=True):
    # Region axes X,Z converted to Blender X,-Y. Flat supported walking tops.
    rects=[(-1.25,21.25,-11.75,11.75),(-21.25,-1.25,3.75,11.75)] if north else [(-14.5,14.5,-7.5,7.5)]
    for xmin,xmax,zmin,zmax in rects:
        cx=(xmin+xmax)/2;cy=-(zmin+zmax)/2;w=xmax-xmin;d=zmax-zmin
        box((cx,cy,4.15),(w-.9,d-.9,8.3),SLATE,.05)
        # Individually fractured slate faces, with recessed seams and chipped corners.
        # Every point is inward of the exact footprint; the flat snow top is unchanged.
        for side in range(4):
            span=w if side<2 else d;count=max(2,round(span/5.7))
            for row,(low,high) in enumerate([(0,2.05),(2.16,4.15),(4.26,6.25),(6.36,8.30)]):
                for col in range(count):
                    t0=-span/2+col*span/count+.015;t1=-span/2+(col+1)*span/count-.015
                    rr=random.Random(row*71+col*19+side*5)
                    contour=[(t0+.13,low),(t1-.15,low),(t1,low+.22),(t1,high-.20),(t1-.18,high),(t0+.15,high),(t0,high-.17),(t0,low+.20)]
                    vs=[]
                    for back in (False,True):
                        for j,(t,z) in enumerate(contour):
                            dep=.64 if back else rr.uniform(.02,.23)
                            if side==0:p=(cx+t,cy+d/2-dep,z)
                            elif side==1:p=(cx-t,cy-d/2+dep,z)
                            elif side==2:p=(cx+w/2-dep,cy-t,z)
                            else:p=(cx-w/2+dep,cy+t,z)
                            vs.append(p)
                    fs=[tuple(reversed(range(8))),tuple(8+i for i in range(8))]
                    fs += [(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)]
                    mesh('Shelf_Slate_Fracture',vs,fs,SLATE)
        # Clean vertical contact faces reserved for the stairs and bridge landing.
        if not north:box((0,7.37,4.15),(13,.26,8.3),SLATE,.025)
        elif xmax<0:box((-9.25,-3.88,4.15),(9.5,.26,8.3),SLATE,.025)
        box((cx,cy,8.4),(w,d,.2),SNOW,.08)
    # Raised rim restricted to outer rear corners, away from all landing sockets.
    # Central walk tops stay8.5; map collision should exclude these small snow corners.
    corners=[(20.9,-11.4),(-20.9,-11.4)] if north else [(-14.15,-7.15),(14.15,-7.15)]
    for x,y in corners:box((x,y,9.25),(.7,.7,1.5),SNOW,.18)
    if north:
        finish('FP_Alpine_Shelf_North',(42.5,10,23.5),{'BridgeLanding':(-9.25,-3.75,8.5),'Signpost':(16.75,10.25,8.5),'RailStart':(7.25,11,8.5)},'L-shaped mesh; gorge void is entirely empty. Central walk top8.5; two outer rear corner caps occupy .7x.7 footprints up to10.',exact=True)
    else:
        finish('FP_Alpine_Shelf_South',(29,10,15),{'StairTop':(0,7.5,8.5),'BridgeLanding':(4.2,-7.5,8.5)},'Central walk top8.5, clear south stair connection. Rear extreme corners carry .7x.7 snow caps to10.',exact=True)

def gorge():
    for i in range(5):
        slate((0,-20+i*10,0),5.7,6.0,8.0+(i%2)*1.3,900+i)
    finish('FP_Alpine_Gorge_Rock',(12,11,50),notes='Long wall-side band; +X is visible bridge-facing side. Not walkable.')

def cliff_block():
    slate((0,0,0),7,6,9,942);slate((2,-2,7),4,3.7,3,943)
    o=finish('FP_Alpine_Cliff_Block',(14,12,12));flat_top(o,12)

def sled():
    for x in (-1.85,1.85):tube([(x,-1.35,.18),(x,.9,.18),(x,1.4,.50),(x,1.2,.85)],.12,IRON,7)
    for i in range(6):box((-2.1+i*.84,0,.7),(.78,2.4,.3),TEAL,.05)
    box((0,-.15,1.3),(2.7,1.8,.9),CANVAS,.18)
    for x in (-.9,.9):tube([(x,-1.1,.9),(x,-1.1,1.8),(x,1,1.8),(x,1,.9)],.055,ROPE,5)
    finish('FP_Alpine_Camp_Sled',(5,2,3))

def notice_board():
    for x in (-1.55,1.55):box((x,0,2.3),(.25,.3,4.6),WOOD,.035)
    box((0,0,3.25),(3.6,.20,2.6),TEAL,.04)
    for x in (-1.8,1.8):box((x,.02,3.25),(.16,.25,2.8),WOOD,.025)
    box((0,0,4.7),(4,.65,.20),TEAL,.06);snowcap((0,0,4.85),2,.5,.25,970)
    finish('FP_Alpine_Notice_Board',(4,5,1),{'BoardFace':(0,.15,3.25)},'Blank teal face; runtime text is optional.')

def terrace_post():
    for i in range(6):box((0,0,.55+i*1.02),(1.8,1.8,.99),STONE,.08)
    box((0,0,6.5),(2,2,.6),STONE,.10);snowcap((0,0,6.8),1,1,.7,980)
    finish('FP_Alpine_Terrace_Post',(2,7.5,2))

lodge();bridge()
for k in ('Tall','Wide','Shelf'):
    cliff(k)
    if k!='Shelf':flat_top(ASSETS[-1],META[-1]['dimensions_studs_xyz'][1])
fir('FP_Alpine_Fir_Tall',(15,26,15),111,6)
fir('FP_Alpine_Fir_Medium',(11,18,11),123,5)
fir('FP_Alpine_Fir_Sapling',(6,10,6),135,4)
tent();woodpile();shrub();grass();crate();barrel();railing();lantern_post();trailpost();signpost();pennant()
slate((0,0,0),4.7,3.9,3.8,215);finish('FP_Alpine_Snow_Rock',(11,6,9))
snowcap((0,0,.2),6,3.8,1.5,221);finish('FP_Alpine_Snow_Drift',(13,2.5,8))
for i in range(7):
    x=-3+i;h=1.1+(i%3)*.8
    rod((x,0,3.4),(x,.1,3.4-h),.22,.028,ICE,7)
snowcap((0,0,3.4),3.7,.45,.3,260);finish('FP_Alpine_Icicles',(8,4,1.3))
landing(True);landing(False);gorge();cliff_block()
slate((0,0,0),2.4,2.1,1.8,950);finish('FP_Alpine_Snow_Rock_Small',(5,3.5,4.5))
sled();notice_board();terrace_post()

def export(path,objects):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.hide_set(False);o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.fbx(filepath=str(path),use_selection=True,object_types={'MESH'},axis_forward='-Z',axis_up='Y',global_scale=1,
        apply_unit_scale=False,apply_scale_options='FBX_SCALE_NONE',bake_space_transform=False,use_mesh_modifiers=True,
        mesh_smooth_type='FACE',use_triangles=True,path_mode='COPY' if len(objects)>1 else 'RELATIVE',embed_textures=len(objects)>1,add_leaf_bones=False,bake_anim=False)
for o,a in zip(ASSETS,META):
    o.data.calc_loop_triangles();a['triangles']=len(o.data.loop_triangles)
    bm=bmesh.new();bm.from_mesh(o.data)
    assert all(e.is_manifold for e in bm.edges),(o.name,'nonmanifold')
    assert all(f.calc_area()>1e-9 for f in bm.faces),(o.name,'zero_area')
    bm.free();a['nonmanifold_edges']=0
    export(OUT/a['file'],[o]);print('EXPORTED',o.name,a['triangles'],flush=True)
for i,o in enumerate(ASSETS):o.location=((i%5-2)*42,(i//5-2)*46,0)
export(OUT/'AlpineOutpostBundle.fbx',ASSETS)
(OUT/'manifest.json').write_text(json.dumps({'version':3,'bundle':'AlpineOutpostBundle.fbx','dimensions_status':'reconciled with ALPINE-OUTPOST-V2-ASSET-REQUEST.md; see delivery notes for rear-corner shelf snow-cap interpretation',
    'units':'1 modeling unit = intended Roblox stud; inspect imported scale','blender_front':'+Y','roblox_front':'-Z','blender_up':'+Z','roblox_up':'+Y','pivot':'bottom-center',
    'textures':{'color':'alpine-color.png','normal':'alpine-normal.png','roughness':'alpine-roughness.png','resolution':[SIZE,SIZE]},
    'material_tiles':{str(i):list(c) for i,c in enumerate(COLORS)},'assets':META,'runtime_effects':'Light, smoke, creek ice/water and ground effects remain separate; use sockets.'},indent=2))

def preview_mat(name,c):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*c,1)
    m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.85;return m
def pv(o):move_collection(o,PREVIEW);return o
def aim(o,t):o.rotation_euler=(Vector(t)-o.location).to_track_quat('-Z','Y').to_euler()
floor=preview_mat('Preview_Background',(.20,.28,.35));plinth=preview_mat('Preview_Plinth',(.35,.45,.52));ink=preview_mat('Preview_Type',(.90,.94,.97))
for i,o in enumerate(ASSETS):
    q=o.copy();q.data=o.data;PREVIEW.objects.link(q);q.name='Display_'+o.name
    bpy.context.view_layer.update();k=25/max(o.dimensions);q.scale=(k,k,k);q.location=((2-i%5)*36,(i//5-2.5)*38,0)
    x,y,_=q.location
    bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=15.5,depth=.35,location=(x,y,-.26));pv(bpy.context.object).data.materials.append(plinth)
    bpy.ops.object.text_add(location=(x,y+14.5,.02),rotation=(0,0,math.pi));t=pv(bpy.context.object)
    t.data.body=o.name.replace('FP_Alpine_','').replace('_',' ').upper();t.data.align_x='CENTER';t.data.size=1.15;t.data.materials.append(ink)
EXPORT.hide_render=True;EXPORT.hide_viewport=True
bpy.ops.mesh.primitive_plane_add(size=1500,location=(0,0,-.5));bg=pv(bpy.context.object);bg.name='PreviewGround';bg.data.materials.append(floor)
SC.world=bpy.data.worlds.new('Alpine_Daylight');SC.world.use_nodes=True
SC.world.node_tree.nodes['Background'].inputs[0].default_value=(.71,.82,1,1);SC.world.node_tree.nodes['Background'].inputs[1].default_value=.55
for p,power,size in [((-70,90,150),160000,90),((100,25,90),70000,70),((0,-80,100),95000,75)]:
    bpy.ops.object.light_add(type='AREA',location=p);l=pv(bpy.context.object);l.data.energy=power;l.data.size=size;aim(l,(0,0,0))
bpy.ops.object.camera_add(location=(5,200,265));cam=pv(bpy.context.object);cam.data.type='ORTHO';cam.data.ortho_scale=230;aim(cam,(0,0,2));SC.camera=cam
SC.render.engine='CYCLES';SC.cycles.samples=32;SC.cycles.use_denoising=True
SC.view_settings.view_transform='AgX';SC.view_settings.look='AgX - Medium High Contrast'
SC.render.resolution_x=2300;SC.render.resolution_y=2450;SC.render.resolution_percentage=100;SC.render.image_settings.file_format='PNG'
SC.render.filepath=str(OUT/'preview-all-assets.png')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'AlpineOutpost.blend'))
if '--no-render' not in sys.argv:
    bpy.ops.render.render(write_still=True)
    for o in PREVIEW.objects:
        if o.type=='FONT' or (o.type=='MESH' and o!=bg):o.hide_render=True
    EXPORT.hide_render=False
    for o in ASSETS:o.hide_render=True
    for o in ASSETS:
        old=o.location.copy();o.location=(0,0,0);o.hide_render=False
        bpy.context.view_layer.update();e=max(o.dimensions)
        cam.location=(e*.78,e*1.7,e*1.04);cam.data.ortho_scale=e*1.65;aim(cam,(0,0,o.dimensions.z*.47))
        SC.render.resolution_x=1400;SC.render.resolution_y=1200;SC.render.filepath=str(OUT/(o.name+'-preview.png'))
        bpy.ops.render.render(write_still=True);o.location=old;o.hide_render=True
print('ALPINE_COMPLETE',len(META),'assets',sum(a['triangles'] for a in META),'triangles',flush=True)

"""Deterministic Gusty broadleaf hero, source/review only. Blender 5.1.
Run with -- --rebuild to explicitly replace this version; --no-render for source only.
The approved Powder Fir is appended for comparison, never modified on disk.
"""
import bpy, bmesh, math, random, json, sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
PROFILE = sys.argv[sys.argv.index('--variant')+1] if '--variant' in sys.argv else 'A'
assert PROFILE in ('A','B','C')
OUT = ROOT / ('assets/gusty-gardens/broadleaf-v2' if PROFILE=='A' else 'assets/gusty-gardens/broadleaf-family-v1/source/'+PROFILE)
OUT.mkdir(parents=True, exist_ok=True)
if (OUT / 'GustyBroadleaf.blend').exists() and '--rebuild' not in sys.argv:
    raise RuntimeError('Existing source preserved; pass -- --rebuild explicitly.')
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
rng = random.Random({'A':92326,'B':92426,'C':92526}[PROFILE])
hero = bpy.data.collections.new('GG_Broadleaf_A_Meadow'); sc.collection.children.link(hero)
stage = bpy.data.collections.new('PREVIEW_ONLY'); sc.collection.children.link(stage)

def material(name, color, rough=.9, grain=.1, scale=8):
    m = bpy.data.materials.new(name); m.diffuse_color = (*color, 1); m.use_nodes = True
    nt = m.node_tree; p = nt.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1); p.inputs['Roughness'].default_value = rough
    if grain:
        tex = nt.nodes.new('ShaderNodeTexNoise'); tex.inputs['Scale'].default_value = scale
        coord = nt.nodes.new('ShaderNodeTexCoord'); nt.links.new(coord.outputs['Object'], tex.inputs['Vector'])
        bump = nt.nodes.new('ShaderNodeBump'); bump.inputs['Strength'].default_value = grain
        bump.inputs['Distance'].default_value = .025
        nt.links.new(tex.outputs['Fac'], bump.inputs['Height']); nt.links.new(bump.outputs['Normal'], p.inputs['Normal'])
    return m

bark = material('Honey oak - warm matte ridged bark', (.20, .105, .047), .94, .25, 5)
barklight = material('Bark ridge highlights', (.255, .145, .065), .94, .2, 6)
greens = [material('Meadow leaf %02d' % i, c, .88, .1, 18) for i, c in enumerate([
    (.045,.115,.026),(.067,.174,.032),(.10,.235,.043),(.15,.29,.058),(.21,.34,.078),(.11,.22,.042)])]
coremat = material('Deep canopy interior', (.034,.087,.021), .96, .08)

class Mesh:
    def __init__(self): self.v=[]; self.f=[]; self.mi=[]
    def add(self, vertices, faces, mi=0):
        k=len(self.v); self.v.extend([tuple(v) for v in vertices]); self.f.extend([tuple(k+i for i in f) for f in faces]); self.mi.extend([mi]*len(faces))
    def tube(self, points, radii, sides=12, ridge=0, mi=0):
        points=[Vector(p) for p in points]; verts=[]; faces=[]
        for i,(p,r) in enumerate(zip(points,radii)):
            tangent=(points[min(i+1,len(points)-1)]-points[max(0,i-1)]).normalized()
            u=tangent.cross(Vector((0,1,0))).normalized(); v=tangent.cross(u).normalized()
            for j in range(sides):
                a=j*math.tau/sides; rr=r*(1+ridge*math.sin(a*7+i*.16)+ridge*.4*math.cos(a*11-i*.12))
                verts.append(p+rr*(u*math.cos(a)+v*math.sin(a)))
        faces.append(tuple(reversed(range(sides))))
        for i in range(len(points)-1):
            for j in range(sides):
                a=i*sides+j; b=i*sides+(j+1)%sides
                faces.append((a,b,b+sides,a+sides))
        faces.append(tuple(range((len(points)-1)*sides,len(points)*sides)))
        self.add(verts,faces,mi)
    def leaf(self, p, direction, length, width, roll, mi):
        p=Vector(p); d=Vector(direction).normalized()
        u=d.cross(Vector((0,0,1))).normalized(); n=u.cross(d).normalized()
        u,n=u*math.cos(roll)+n*math.sin(roll),-u*math.sin(roll)+n*math.cos(roll)
        verts=[p]; faces=[]
        for t,w in [(.22,.72),(.52,1),(.8,.64)]:
            c=p+d*(length*t)+n*(length*.16*math.sin(t*math.pi))
            verts.extend([c+u*width*w, c+n*.10*width*w, c-u*width*w, c-n*.12*width*w])
        verts.append(p+d*length-n*length*.12)
        for j in range(4): faces.append((0,1+(j+1)%4,1+j))
        for k in range(2):
            for j in range(4): faces.append((1+k*4+j,1+k*4+(j+1)%4,5+k*4+(j+1)%4,5+k*4+j))
        for j in range(4): faces.append((9+j,9+(j+1)%4,13))
        self.add(verts,faces,mi)
    def object(self,name,mats):
        me=bpy.data.meshes.new(name); me.from_pydata(self.v,[],self.f); me.update()
        for m in mats: me.materials.append(m)
        for p,i in zip(me.polygons,self.mi): p.material_index=i; p.use_smooth=True
        bm=bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(me); bm.free()
        o=bpy.data.objects.new(name,me); hero.objects.link(o); return o

wood=Mesh(); leaves=Mesh(); ribs=Mesh()
trunk=[(0,0,0),(-.12,.03,.45),(-.2,.10,1.4),(-.12,.12,3),(.2,.05,5),(.5,.0,6.8),(1.1,.1,8.4),(1.55,.15,10.4),(1.9,.1,12.2),(2.3,.2,14.4),(2.55,.18,15.6)]
rad=[1.25,1.12,.91,.8,.71,.64,.55,.44,.31,.17,.035]
if PROFILE=='B':
    trunk=[(x*.55,y,z*.86) for x,y,z in trunk]
elif PROFILE=='C':
    trunk=[(x*.7+math.sin(z*.24)*.23,y,z) for x,y,z in trunk]
wood.tube(trunk,rad,32,.12)
for j in range(9):
    a=j*math.tau/9+.12; length=rng.uniform(1.7,2.6)
    points=[(math.cos(a)*length,math.sin(a)*length,.05),(math.cos(a)*length*.65,math.sin(a)*length*.65,.26),(math.cos(a)*.85,math.sin(a)*.85,.85),(math.cos(a)*.67,math.sin(a)*.67,2.2)]
    wood.tube(points,[.06,.27,.39,.15],12,.1)
for j in range(15):
    a=j*math.tau/15
    pts=[Vector(p)+Vector((math.cos(a+i*.023),math.sin(a+i*.023),0))*r*.985 for i,(p,r) in enumerate(zip(trunk[:-2],rad[:-2]))]
    ribs.tube(pts,[.045,.07,.08,.07,.055,.045,.038,.026,.018],7,0,0)

# Deliberate overlapping bough groups; open arches remain under the crown.
lobes=[(-5.7,.7,8.9,3.0,2.8,2.0),(-3.6,-3.9,9.6,3.1,2.7,2.1),(.1,-4.6,10,3.2,2.6,2.2),
       (4.3,-2.6,9.5,3.8,3.0,2.2),(6.1,.9,10.4,3.0,3.0,2.1),(2.7,4.3,10.6,3.6,2.8,2.3),
       (-2.2,4.1,10.1,3.7,2.8,2.3),(-3.9,0,12.2,3.5,3.3,2.6),(.1,-2.3,13.2,3.8,3.2,2.5),
       (3.7,1,13.3,3.6,3.4,2.5),(.0,2.6,13.5,3.5,3.0,2.4),(1.0,0,15.2,3.9,3.4,2.5)]
if PROFILE=='B':
    lobes=[(-6.1,-.4,8.5,3.5,3,2.1),(-4.4,-4.3,8.9,3.3,2.8,2),(.1,-4.8,9.6,3.6,2.5,2.2),
           (4.8,-3.2,9,3.9,3.1,2.1),(6.5,1,9.2,3.6,3.1,2.1),(3.2,4.4,9.8,3.8,3.1,2.1),
           (-2.5,4.4,9.1,3.7,2.9,2.1),(-4.3,.4,11.5,3.7,3.3,2.3),(-1.7,-1.9,12.8,3.2,3,2.4),
           (3.5,-.6,12.2,3.5,3.3,2.5),(1.7,3,12.4,3.8,3.1,2.4),(-.2,.8,14,3.6,3.1,2.3)]
elif PROFILE=='C':
    lobes=[(-3.7,1.1,8.6,2.8,2.6,2),(.1,-3.3,9.4,3.3,2.6,2.2),(3.9,-.8,10.2,3,2.9,2.2),
           (1.2,3.2,11,3.4,2.5,2.3),(-2.8,-.8,11.9,3.2,3,2.5),(2.4,-1.8,13,3.1,2.7,2.4),
           (-1.4,2.3,13.8,3.3,2.7,2.5),(1.8,.8,15.1,3.2,2.9,2.3),(.5,-.3,16.6,2.7,2.6,2.4)]
leafcount=0
for li,(x,y,z,rx,ry,rz) in enumerate(lobes):
    end=Vector((x,y,z)); start=Vector((.45,0,5.6+(li%4)*1.2)); mid=start.lerp(end,.5)-Vector((0,0,.55))
    wood.tube([start,mid,end,end+Vector((1,0,.7))],[.46,.30,.13,.015],14,.08)
    # Short radiating sprays connect visible leaves to the bough structure.
    for j in range(11):
        a=j*math.tau/11+li*.8
        tip=end+Vector((rx*.76*math.cos(a),ry*.76*math.sin(a),rng.uniform(-.45,.7)))
        wood.tube([end, end.lerp(tip,.5)+Vector((0,0,.25)),tip],[.12,.068,.008],8,.04)
    # Phyllotactic shell samples plus inner fill: rounded crown, individually folded leaves.
    for j in range(290):
        nz=1-2*((j+.5)/290); a=j*2.399963+li*.71; rr=math.sqrt(1-nz*nz)
        shell=rng.uniform(.76,1.0)
        p=end+Vector((rx*rr*math.cos(a),ry*rr*math.sin(a),rz*nz))*shell
        direction=Vector((math.cos(a)*.8+.45,math.sin(a)*.85,rng.uniform(-.4,.25)))
        length=rng.uniform(.83,1.45); width=length*rng.uniform(.24,.34)
        if PROFILE!='A': width*=.75
        mi=rng.choices(range(6),[1,3,5,4 if nz>0 else 1,2 if nz>.25 else .4,3])[0]
        leaves.leaf(p,direction,length,width,rng.uniform(-.6,.6),mi); leafcount+=1

objects=[wood.object('GG_Broadleaf_A_Bark',[bark]),ribs.object('GG_Broadleaf_A_BarkRidges',[barklight]),leaves.object('GG_Broadleaf_A_Leaves',greens)]
# Fit once in the authoring scene to the measured current perimeter envelope.
# Keep the actual root axis as socket zero; preserve size and offsets thereafter.
allv=[v.co.copy() for o in objects for v in o.data.vertices]
lo=Vector(tuple(min(v[i] for v in allv) for i in range(3))); hi=Vector(tuple(max(v[i] for v in allv) for i in range(3)))
# Source blockout extents about its root: x[-9.8,10.2], y[-9.5,9.4], z[-.05,17.98].
target_height=16.8 if PROFILE=='B' else 17.98
target_x=(7.7,8.0) if PROFILE=='C' else (9.8,10.2)
target_y=(7.4,7.3) if PROFILE=='C' else (9.5,9.4)
sx=min(target_x[0]/abs(lo.x),target_x[1]/hi.x); sy=min(target_y[0]/abs(lo.y),target_y[1]/hi.y); sz=target_height/(hi.z-lo.z)
for o in objects:
    for v in o.data.vertices: v.co=Vector((v.co.x*sx,v.co.y*sy,(v.co.z-lo.z)*sz))

report={'status':'Source art for user review; not optimized, exported, approved, or integrated',
        'seed':{'A':92326,'B':92426,'C':92526}[PROFILE],'variant':PROFILE,'unit':'1 Blender unit = 1 intended Roblox stud','modeled_leaves':leafcount,
        'source_target':'GustyGardens.bigTree perimeter sites, not legacy GG_Windbent_Tree placements',
        'sockets_roblox':{'TrunkBase':[0,0,0]},'components':[]}
for o in objects:
    me=o.data; me.calc_loop_triangles(); bm=bmesh.new(); bm.from_mesh(me)
    points=[v.co for v in me.vertices]; low=[min(v[i] for v in points) for i in range(3)]; high=[max(v[i] for v in points) for i in range(3)]
    size=[high[i]-low[i] for i in range(3)]; center=[(high[i]+low[i])/2 for i in range(3)]
    item={'name':o.name,'triangles':len(me.loop_triangles),'nonmanifold_edges':sum(not e.is_manifold for e in bm.edges),
          'degenerate_faces':sum(f.calc_area()<1e-10 for f in bm.faces),'size_roblox_whd':[size[0],size[2],size[1]],
          'center_roblox':[center[0],center[2],-center[1]]}
    report['components'].append(item); bm.free()
    assert item['nonmanifold_edges']==0 and item['degenerate_faces']==0,item
report['triangles']=sum(c['triangles'] for c in report['components'])
allv=[v.co for o in objects for v in o.data.vertices]
low=[min(v[i] for v in allv) for i in range(3)]; high=[max(v[i] for v in allv) for i in range(3)]
report['bounds_blender']={'min':low,'max':high}
report['dimensions_roblox_whd']=[high[0]-low[0],high[2]-low[2],high[1]-low[1]]
assert low[0]>=-9.80001 and high[0]<=10.20001 and low[1]>=-9.50001 and high[1]<=9.40001
assert abs(low[2])<1e-5 and abs(high[2]-target_height)<1e-5
(OUT/'geometry-report.json').write_text(json.dumps(report,indent=2))

def move(o,col):
    for c in list(o.users_collection): c.objects.unlink(o)
    col.objects.link(o); return o
def aim(o,target): o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()

refpath=ROOT/'assets/frostbite-peaks/powder-firs-v1/PowderFirs.blend'
with bpy.data.libraries.load(str(refpath),link=False) as (src,dst): dst.collections=['PowderFir_A_Original']
ref=dst.collections[0]; stage.children.link(ref)
for o in ref.objects: o.location=(23,0,0)
ref.hide_render=True
floor=material('Neutral review backdrop',(.53,.56,.53),.95,0)
bpy.ops.mesh.primitive_plane_add(size=2000,location=(0,0,-.07)); ground=move(bpy.context.object,stage); ground.data.materials.append(floor)
sc.world=bpy.data.worlds.new('Neutral daylight'); sc.world.use_nodes=True
sc.world.node_tree.nodes['Background'].inputs[0].default_value=(.77,.84,1,1)
sc.world.node_tree.nodes['Background'].inputs[1].default_value=.4
for name,pos,energy,size,color in [('Key',(-22,-28,38),23000,18,(1,.94,.83)),('Fill',(24,-9,26),10000,20,(.8,.9,1)),('Rim',(3,20,30),17000,15,(.95,1,.88))]:
    bpy.ops.object.light_add(type='AREA',location=pos); o=move(bpy.context.object,stage); o.name=name
    o.data.energy=energy; o.data.shape='DISK'; o.data.size=size; o.data.color=color; aim(o,(0,0,9))
bpy.ops.object.camera_add(location=(27,-43,25)); cam=move(bpy.context.object,stage); sc.camera=cam; cam.data.type='ORTHO'
sc.render.engine='CYCLES'; sc.cycles.samples=32; sc.cycles.use_denoising=True
sc.render.resolution_percentage=100; sc.render.image_settings.file_format='PNG'
sc.view_settings.view_transform='AgX'; sc.view_settings.look='AgX - Medium High Contrast'

# A simple neutral 5-stud human scale marker, preview only.
marker=bpy.data.collections.new('PREVIEW_5_STUD_PERSON'); stage.children.link(marker)
marker_mat=material('Scale marker clay',(.26,.29,.31),.9,0)
def marker_sphere(name,pos,scale):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,location=pos); o=move(bpy.context.object,marker)
    o.name=name; o.scale=scale; o.data.materials.append(marker_mat)
    for p in o.data.polygons: p.use_smooth=True
marker_sphere('Head',(12,-1,4.53),(.46,.40,.47))
marker_sphere('Torso',(12,-1,3.14),(.72,.35,.99))
for side in [-1,1]:
    marker_sphere('Leg',(12+side*.34,-1,1.20),(.28,.30,1.2))
    marker_sphere('Arm',(12+side*.91,-1,3.05),(.23,.25,.90))
marker.hide_render=True

def shot(name,pos,target,scale,w=1200,h=1200):
    cam.location=pos; aim(cam,target); cam.data.ortho_scale=scale
    sc.render.resolution_x=w; sc.render.resolution_y=h; sc.render.filepath=str(OUT/name)
    if '--no-render' not in sys.argv: bpy.ops.render.render(write_still=True)

cam.location=(27,-43,25); aim(cam,(0,0,8.9)); cam.data.ortho_scale=25
sc.render.resolution_x=1200; sc.render.resolution_y=1200
sc.render.filepath=str(OUT/'broadleaf-three-quarter.png')
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D': area.spaces.active.region_3d.view_perspective='CAMERA'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'GustyBroadleaf.blend'))
shot('broadleaf-three-quarter.png',(27,-43,25),(0,0,8.9),25)
shot('broadleaf-front.png',(0,-50,9),(0,0,9),23)
shot('broadleaf-side.png',(50,0,9),(0,0,9),23)
shot('broadleaf-detail.png',(13,-25,12),(.7,-1,7.0),11)
marker.hide_render=False
cam.data.type='PERSP'; cam.data.lens=48
shot('broadleaf-player-scale.png',(26,-42,6.5),(2,0,9),30,1500,1100)
cam.data.type='ORTHO'
ref.hide_render=False
shot('broadleaf-powder-comparison.png',(10,-65,29),(10,0,12),49,1700,1150)
print('GUSTY_BROADLEAF_COMPLETE',json.dumps(report),flush=True)

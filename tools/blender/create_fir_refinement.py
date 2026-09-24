"""Native Blender fir study; isolated from the delivered Alpine kit.
Run Blender --background --python tools/blender/create_fir_refinement.py.
"""
import bpy, bmesh, math, random, json, sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/frostbite-peaks/fir-refinement/v2'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
SC = bpy.context.scene
TREE = bpy.data.collections.new('FIR_STUDY_EDITABLE')
SC.collection.children.link(TREE)
STAGE = bpy.data.collections.new('PREVIEW_ONLY')
SC.collection.children.link(STAGE)
rng = random.Random(90222)

def move(o, collection):
    for c in list(o.users_collection): c.objects.unlink(o)
    collection.objects.link(o)
    return o

def material(name, color, roughness, noise=0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; p = nt.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = roughness
    if noise:
        tex = nt.nodes.new('ShaderNodeTexNoise'); tex.inputs['Scale'].default_value = 11
        tex.inputs['Detail'].default_value = 2
        bump = nt.nodes.new('ShaderNodeBump')
        bump.inputs['Strength'].default_value = noise
        bump.inputs['Distance'].default_value = .035
        nt.links.new(tex.outputs['Fac'], bump.inputs['Height'])
        nt.links.new(bump.outputs['Normal'], p.inputs['Normal'])
    return m

SNOW = material('Snow | soft ivory top, cool shaded underside', (.84,.9,.94), .88, .12)
GREENS = [material('Fir needles %02d' % i, c, .91, .10) for i,c in enumerate([
    (.024,.105,.065), (.033,.135,.080), (.040,.155,.087), (.028,.12,.081)])]
BARK = material('Warm exposed bark', (.19,.095,.035), .95, .26)
GROUND = material('Display snow', (.75,.80,.85), .95, .12)

def mesh(name, vs, fs, mat, smooth=False):
    me = bpy.data.meshes.new(name); me.from_pydata(vs, [], fs); me.update()
    o = bpy.data.objects.new(name, me); TREE.objects.link(o)
    me.materials.append(mat)
    for p in me.polygons: p.use_smooth = smooth
    bm=bmesh.new();bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(me);bm.free()
    return o

def cone_between(name, a, b, r1, r2, mat, vertices=9):
    a,b = Vector(a), Vector(b)
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=r1, radius2=r2, depth=(b-a).length, location=(a+b)*.5)
    o=move(bpy.context.object,TREE);o.name=name
    o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    o.data.materials.append(mat)
    return o

# Thick, tapered branch tongues. Each snow mantle is separate editable geometry.
def bough(name, angle, radius, z, width, rise, snow=True):
    d=Vector((math.cos(angle),math.sin(angle),0));side=Vector((-d.y,d.x,0))
    # Long foliage spikes extend visibly below and outside the rounded snow mantle.
    profile=[(.08,.10,.02),(.23,.65,.09),(.38,.96,.15),(.47,.78,.21),(.56,1.0,.27),(.64,.68,.35),(.72,.77,.43),(.80,.44,.52),(.88,.46,.62),(.95,.20,.74),(1.04,.015,.85)]
    vs=[];fs=[];n=10
    for k,(t,w,drop) in enumerate(profile):
        center=d*(radius*t)+Vector((0,0,z+rise*(1-t)-radius*.42*drop))
        for j in range(n):
            a=math.tau*j/n
            v=center+side*(width*w*math.cos(a))+Vector((0,0,math.sin(a)*radius*.115*w))
            vs.append(v)
    fs.append(tuple(reversed(range(n))))
    for k in range(len(profile)-1):
        for j in range(n):fs.append((k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j))
    fs.append(tuple((len(profile)-1)*n+j for j in range(n)))
    mesh(name+' | green bough',vs,fs,rng.choice(GREENS),False)
    if not snow: return
    # Rounded pillows follow the slope rather than forming flat white tier discs.
    profile=[(.12,.04),(.22,.45),(.36,.82),(.49,1),(.60,.89),(.70,.91),(.80,.66),(.88,.44),(.935,.20),(.945,.012)]
    vs=[];fs=[];n=12
    drift=rng.uniform(-.14,.14)
    snowwidth=rng.uniform(.73,.90)
    fullness=rng.uniform(.17,.22)
    for k,(t,w) in enumerate(profile):
        drop=.85*((t-.08)/.96)**1.65
        c=d*(radius*t)+side*(width*drift*math.sin(t*3))+Vector((0,0,z+rise*(1-t)-radius*.42*drop+radius*.14))
        # Elliptical cross-section, gently folded underside, thick snow in the middle.
        for j in range(n):
            a=math.tau*j/n
            v=c+side*(width*snowwidth*w*math.cos(a))+Vector((0,0,math.sin(a)*radius*fullness*w))
            vs.append(v)
    fs.append(tuple(reversed(range(n))))
    for k in range(len(profile)-1):
        for j in range(n):fs.append((k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j))
    fs.append(tuple((len(profile)-1)*n+j for j in range(n)))
    mesh(name+' | snow mantle',vs,fs,SNOW,True)

cone_between('Tapered trunk',(0,0,0),(.10,-.05,23.4),.60,.07,BARK,11)
for j in range(5):
    a=j*math.tau/5+.3
    cone_between('Root flare %02d'%j,(math.cos(a)*.84,math.sin(a)*.84,.04),(0,0,1.3),.15,.35,BARK,7)

TIERS=[(4.65,4.55,7),(8.15,4.25,7),(11.65,3.50,6),(15.10,2.80,6),(18.20,2.15,5),(21.00,1.48,5)]
for tier,(z,r,count) in enumerate(TIERS):
    angle0=.30+tier*.61
    # Small inner skirt keeps a dark green core behind the overlapping branches.
    n=count*4;vs=[];fs=[]
    for ring in range(3):
        for j in range(n):
            a=j*math.tau/n+angle0
            if ring==0:
                rr=r*.61*(1+.14*math.cos(j*math.pi/2));zz=z-.30-.50*(.5+.5*math.cos(j*math.pi/2))
            elif ring==1:rr=r*.35;zz=z+1.3
            else:rr=.09;zz=z+3.3
            vs.append((rr*math.cos(a),rr*math.sin(a),zz))
    fs.append(tuple(reversed(range(n))))
    for k in range(2):
        for j in range(n):fs.append((k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j))
    fs.append(tuple(2*n+j for j in range(n)))
    mesh('Tier %02d | shadow foliage'%tier,vs,fs,GREENS[tier%4])
    for j in range(count):
        a=angle0+j*math.tau/count+rng.uniform(-.09,.09)
        rr=r*rng.uniform(.89,1.07)
        bough('Tier %02d branch %02d'%(tier,j),a,rr,z+rng.uniform(-.33,.33),rr*rng.uniform(.32,.39),rr*.85,True)

# Slender, snow-heavy terminal shoot with a slightly bent natural tip.
def crown():
    n=12;vs=[];fs=[]
    for z,r in [(21.65,.83),(22.35,.77),(23.3,.48),(24.35,.30),(25.4,.12),(26,.012)]:
        for j in range(n):
            a=j*math.tau/n;rr=r*(1+.12*math.sin(a*3))
            vs.append((rr*math.cos(a)+.10*(z-22)/4,rr*math.sin(a),z))
    fs.append(tuple(reversed(range(n))))
    for k in range(5):
        for j in range(n):fs.append((k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j))
    fs.append(tuple(5*n+j for j in range(n)))
    mesh('Terminal snow spire',vs,fs,SNOW,True)
crown()

# Resting snow around the roots is sculpted art, distinct from the preview ground.
for j in range(3):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=(math.cos(j*2.1)*.63,math.sin(j*2.1)*.63,.14))
    o=move(bpy.context.object,TREE);o.name='Root snow %02d'%j;o.scale=(.85,.65,.23)
    o.data.materials.append(SNOW)
    for p in o.data.polygons:p.use_smooth=True

# Put all geometry on a bottom-centred pivot without modifying existing kit art.
bpy.context.view_layer.update()
pts=[o.matrix_world@Vector(c) for o in TREE.objects for c in o.bound_box]
lo=Vector(tuple(min(p[i] for p in pts) for i in range(3)))
hi=Vector(tuple(max(p[i] for p in pts) for i in range(3)))
offset=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z))
for o in TREE.objects:o.location-=offset
triangles=0
for o in TREE.objects:
    o.data.calc_loop_triangles();triangles+=len(o.data.loop_triangles)
    bm=bmesh.new();bm.from_mesh(o.data)
    assert all(e.is_manifold for e in bm.edges),o.name
    assert all(f.calc_area()>1e-10 for f in bm.faces),o.name
    bm.free()

def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.mesh.primitive_plane_add(size=2000,location=(0,0,-.025))
o=move(bpy.context.object,STAGE);o.name='Preview ground';o.data.materials.append(GROUND)
SC.world=bpy.data.worlds.new('Cool alpine fill');SC.world.use_nodes=True
SC.world.node_tree.nodes['Background'].inputs[0].default_value=(.65,.78,1,1)
SC.world.node_tree.nodes['Background'].inputs[1].default_value=.55
for name,pos,power,size,col in [
    ('Broad daylight',(-16,20,37),13000,13,(1,.93,.83)),
    ('Cool sky fill',(16,8,22),2200,16,(.70,.84,1)),
    ('Snow rim',(-4,-16,30),4500,11,(.86,.94,1))]:
    bpy.ops.object.light_add(type='AREA',location=pos);o=move(bpy.context.object,STAGE)
    o.name=name;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.data.color=col;aim(o,(0,0,12))
bpy.ops.object.camera_add(location=(31,52,34))
cam=move(bpy.context.object,STAGE);cam.name='Review camera';cam.data.type='ORTHO';cam.data.ortho_scale=32
aim(cam,(0,0,12.8));SC.camera=cam
SC.render.engine='CYCLES';SC.cycles.samples=48;SC.cycles.use_denoising=True
SC.render.resolution_x=1200;SC.render.resolution_y=1500;SC.render.resolution_percentage=100
SC.render.image_settings.file_format='PNG';SC.view_settings.view_transform='AgX'
SC.view_settings.look='AgX - Medium High Contrast'
SC.render.filepath=str(OUT/'fir-v2-hero.png')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'FrostbiteFir-v2.blend'))
(OUT/'study.json').write_text(json.dumps({'status':'Art review only; not approved or integrated','dimensions_blender_xyz':list(hi-lo),'dimensions_roblox_whd':[hi.x-lo.x,hi.z-lo.z,hi.y-lo.y],'triangles':triangles,'editable_meshes':len(TREE.objects),'materials':'Native Blender procedural materials; bake and Roblox export after visual approval','notes':'Slender tiered fir. Existing Alpine assets and game source are unchanged.'},indent=2))
bpy.ops.render.render(write_still=True)
cam.location=(-34,48,26);aim(cam,(0,0,12.8));SC.render.filepath=str(OUT/'fir-v2-alternate.png')
bpy.ops.render.render(write_still=True)
cam.location=(16,30,18);aim(cam,(0,0,12.4));cam.data.ortho_scale=15
SC.render.resolution_x=1400;SC.render.resolution_y=1100;SC.render.filepath=str(OUT/'fir-v2-branches.png')
bpy.ops.render.render(write_still=True)
print('FIR_STUDY_COMPLETE',triangles,flush=True)

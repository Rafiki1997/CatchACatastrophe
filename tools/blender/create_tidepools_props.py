"""Tropical Tidepools sculpted asset pack. Run in Blender 5.1 background mode.
New versioned output only; --rebuild permits regeneration of this generated pack.
Blender +Y is the visible front; FBX exports it as Roblox -Z, with +Z up -> +Y.
"""
import bpy, bmesh, json, math, random, sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/splashwater-bay/tidepools-v2'
OUT.mkdir(parents=True, exist_ok=True)
if (OUT/'TropicalTidepools.blend').exists() and '--rebuild' not in sys.argv:
    raise RuntimeError('Preserve existing asset file; use --rebuild only for generated work.')
bpy.ops.wm.read_factory_settings(use_empty=True)
SC = bpy.context.scene
SC.unit_settings.system = 'NONE'
SC.render.engine = 'CYCLES'
SC.cycles.samples = 32
SC.cycles.use_denoising = True
SC.render.resolution_percentage = 100
SC.render.image_settings.file_format = 'PNG'
SC.view_settings.view_transform = 'Standard'
SC.view_settings.look = 'Medium High Contrast'
PAL = [(138,142,152),(172,176,186),(104,108,120),(58,62,74),
       (150,108,66),(118,82,50),(177,132,83),(97,68,44),
       (74,158,66),(48,118,54),(108,186,80),(130,202,82),
       (74,146,64),(52,116,54),(104,178,78),(38,91,46),
       (244,118,126),(255,151,156),(218,82,107),(250,208,76),
       (167,173,183),(121,128,142),(190,194,202),(77,84,101),
       (94,168,67),(58,136,53),(181,211,105),(203,153,95),
       (64,214,235),(148,236,244),(252,252,248),(246,214,152)]
atlas = bpy.data.images.new('TidepoolsPalette', width=512, height=16, alpha=False)
atlas.pixels = [v for y in range(16) for x in range(512) for v in (*[c/255 for c in PAL[x//16]],1)]
atlas.filepath_raw = str(OUT/'palette.png'); atlas.file_format='PNG'; atlas.save(); atlas.pack()
MAT=bpy.data.materials.new('Tidepools_Palette'); MAT.use_nodes=True
bs=MAT.node_tree.nodes.get('Principled BSDF'); bs.inputs['Roughness'].default_value=.86
tex=MAT.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=atlas; tex.interpolation='Closest'
MAT.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
EXPORT=bpy.data.collections.new('EXPORT_EIGHT_ASSETS'); SC.collection.children.link(EXPORT)
SPLIT=bpy.data.collections.new('OPTIONAL_SPLIT_PALMS'); SC.collection.children.link(SPLIT)
COL=bpy.data.collections.new('COLLISION_PROXIES'); SC.collection.children.link(COL)
PREVIEW=bpy.data.collections.new('PREVIEW_ONLY'); SC.collection.children.link(PREVIEW)
PARTS=[]; ASSETS=[]; META=[]; SPLITS=[]

def paint(o, colors):
    o.data.materials.clear(); o.data.materials.append(MAT)
    # Blender primitives arrive with UVMap; retaining it makes the renderer
    # sample the entire palette as stripes instead of the per-face swatches.
    while o.data.uv_layers:o.data.uv_layers.remove(o.data.uv_layers[0])
    uv=o.data.uv_layers.new(name='PaletteUV')
    uv.active_render=True
    colors=colors if isinstance(colors,list) else [colors]
    for p in o.data.polygons:
        c=colors[p.index % len(colors)]
        for li in p.loop_indices: uv.data[li].uv=((c+.5)/32,.5)
    PARTS.append(o); return o

def mesh(name,vs,fs,colors):
    d=bpy.data.meshes.new(name);d.from_pydata(vs,[],fs);d.update()
    o=bpy.data.objects.new(name,d);SC.collection.objects.link(o)
    return paint(o,colors)

def stone(pos,scale,seed=1,dark=False,sub=2):
    rng=random.Random(seed)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1,location=pos)
    o=bpy.context.object;o.name='FacetedBoulder'
    for v in o.data.vertices:
        v.co*=rng.uniform(.90,1.08)
        v.co.x*=scale[0];v.co.y*=scale[1];v.co.z*=scale[2]
        v.co.z=max(v.co.z,-pos[2])
    # Broad coherent shaded patches instead of random high-contrast triangles.
    paint(o,[2,21,2,23] if dark else [0,0,20,0,1,21,0,20])
    return o

def beam(a,b,r1,r2,colors,sides=10):
    a,b=Vector(a),Vector(b)
    bpy.ops.mesh.primitive_cone_add(vertices=sides,radius1=r1,radius2=r2,depth=(b-a).length,location=(a+b)/2)
    o=bpy.context.object;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return paint(o,colors)

def box(pos,size,color,bevel=.5):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        m=o.modifiers.new('Broad_chamfer','BEVEL');m.width=bevel;m.segments=1
        bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=m.name)
    return paint(o,color)

def leaf(base,angle,length,width,rise,drop,colors,scallop=False):
    """Closed curved broad frond with central ridge and gently notched margin."""
    base=Vector(base);direction=Vector((math.cos(angle),math.sin(angle),0));side=Vector((-math.sin(angle),math.cos(angle),0))
    n=10;vs=[]
    for j in range(n+1):
        t=j/n
        center=base+direction*length*t+Vector((0,0,rise*math.sin(math.pi*t*.85)-drop*t*t))
        w=width*(.07+.93*math.sin(math.pi*t)**.70)
        if scallop and j%2==1:w*=.82
        if j==n:w=.035
        for lateral,z in [(-w,0),(0,width*.26*math.sin(math.pi*t)),(w,0),(0,-.10)]:
            vs.append(center+side*lateral+Vector((0,0,z)))
    fs=[(3,2,1,0)]
    for j in range(n):
        for k in range(4):fs.append((j*4+k,j*4+(k+1)%4,(j+1)*4+(k+1)%4,(j+1)*4+k))
    fs.append(tuple(n*4+k for k in range(4)))
    return mesh('CurvedFrond',vs,fs,colors)

def bounds(o):
    pts=[v.co for v in o.data.vertices]
    return Vector(tuple(min(v[i] for v in pts) for i in range(3))),Vector(tuple(max(v[i] for v in pts) for i in range(3)))

def join(parts,name):
    bpy.ops.object.select_all(action='DESELECT')
    for p in parts:p.hide_set(False);p.select_set(True)
    bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join()
    o=bpy.context.object;o.name=name
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    o.data.materials.clear();o.data.materials.append(MAT)
    for p in o.data.polygons:p.material_index=0;p.use_smooth=False
    bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
    return o

def relocate(o,collection):
    for c in list(o.users_collection):c.objects.unlink(o)
    collection.objects.link(o)

def finish(name,size,sockets=None,split_at=None):
    global PARTS
    split=[]
    if split_at is not None:
        for suffix,parts in [('Trunk',PARTS[:split_at]),('Crown',PARTS[split_at:])]:
            copies=[]
            for p in parts:
                q=p.copy();q.data=p.data.copy();SC.collection.objects.link(q);copies.append(q)
            q=join(copies,name+'__'+suffix);relocate(q,SPLIT);split.append(q)
    o=join(PARTS,name);PARTS=[]
    low,high=bounds(o);off=Vector(((low.x+high.x)/2,(low.y+high.y)/2,low.z))
    factors=Vector((size[0]/(high.x-low.x),size[1]/(high.y-low.y),size[2]/(high.z-low.z)))
    for q in [o]+split:
        for v in q.data.vertices:
            v.co-=off
            for i in range(3):v.co[i]*=factors[i]
        q.data.update()
    relocate(o,EXPORT);ASSETS.append(o)
    for q in split:SPLITS.append(q)
    sockets=sockets or {}
    socket_map={}
    for label,p in sockets.items():
        v=Vector(p)-off
        v=Vector(tuple(v[i]*factors[i] for i in range(3)))
        socket_map[label]=[round(v.x,4),round(v.z,4),round(-v.y,4)]
    META.append({'name':name,'file':name+'.fbx','dimensions_studs_xyz':[size[0],size[2],size[1]],'sockets_roblox_xyz_from_base':socket_map})
    bpy.context.view_layer.update()
    return o

def grotto():
    # A real open arch, built from closed voussoirs; dark recessed inner facets.
    steps=9
    for j in range(steps):
        a=j*math.pi/steps;b=(j+1)*math.pi/steps
        vs=[]
        for y in (17,-13):
            for t,rx,rz in [(a,25,26),(b,25,26),(b,11.8,16.3),(a,11.8,16.3)]:
                vs.append((math.cos(t)*rx,y+(j%2)*.65,math.sin(t)*rz))
        o=mesh('ArchStone',vs,[(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],[0,2,20,21,3,0])
        # Chamfer edges without closing the mouth.
        m=o.modifiers.new('Stone_edges','BEVEL');m.width=.8;m.segments=1
        bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=m.name)
    for i in range(7):
        a=(i+.5)*math.pi/7
        stone((math.cos(a)*23,15+(i%3)*1.2,math.sin(a)*22),
              (5.8,6.8,5.4),170+i)
    # Broad irregular crown stones cover the tunnel construction underneath.
    for i,(p,s) in enumerate([((-12,3,21),(10,11,5)),((10,3,22),(10,12,5)),
                               ((-2,11,24),(10,8,4))]):stone(p,s,195+i)
    # Back wall is recessed almost 30 studs from the visible opening.
    stone((0,-16,10),(19,6,12),120,True)
    for i,(p,s) in enumerate([
        ((-25,7,7),(7.6,12,9)),((25,5,6),(7.6,12,8)),
        ((-21,-12,10),(9,11,12)),((21,-14,11),(9,10,13)),
        ((-15,-9,19),(11,12,8)),((8,-8,20),(13,13,7)),
        ((-29,16,3),(4,7,4)),((28,16,3),(4.5,7,4)),
        ((-23,22,2),(5,4.5,3)),((24,22,2),(5,4.5,3))]):stone(p,s,220+i)
    # Small elevated sill inside the mouth, leaves real empty space in front.
    box((5,0,9),(10,9,2.5),[2,0,21],.7)
    finish('SB_Tidepool_Grotto',(65,53,27),{'GrottoFallLip':(5,5,10.25),'GrottoFallFoot':(5,9,.5),'MouthCenter':(0,18,7)})

def cascade():
    # Three rocky terraces, with a broad clear channel on the visible +Y face.
    specs=[
        ((-23,6,7),(7,15,9)),((22,4,9),(8,15,11)),
        ((-18,-12,15),(11,12,16)),((15,-13,18),(12,12,19)),
        ((-13,-14,31),(10,11,10)),((8,-16,34),(12,10,8)),
        ((-19,12,14),(7,8,14)),((17,9,17),(8,10,16)),
        ((-26,17,3),(4,7,4)),((24,18,4),(6,7,5)),
        ((-9,-20,35),(9,5,7)),((3,-9,36),(8,6,6))]
    for i,(p,s) in enumerate(specs):stone(p,s,410+i)
    # Mid shelf and upper lip, actual exposed flat surfaces for Roblox water.
    box((0,9,15.5),(18,15,3),[0,20,2],.9)
    box((0,-4,30.5),(12,13,3),[0,20,2],.8)
    # Back of lower drop, recessed to keep the falling water visible.
    box((0,4,7),(17,12,13),[2,21,0],1.6)
    box((0,-9,23),(11,13,14),[2,21,0],1.0)
    box((0,-1,16),(15,18,12),[2,21,0],1.2)
    finish('SB_Cascade_Rocks',(60,50,42),{'UpperLip':(0,2.5,32),'MidPool':(0,9,17),'LowerLip':(0,16.5,17),'LowerFoot':(0,19,.6)})

def palm(name,size,lean,seed):
    rng=random.Random(seed);height=27;points=[]
    for i in range(8):
        t=i/7;points.append(Vector((lean*height*t*t,.45*math.sin(t*math.pi),height*t)))
    for i in range(7):
        r=2.3-i*.15
        beam(points[i],points[i+1],r,r*.91,[4,4,6,4,5],10)
        # Narrow angled growth scar at the bottom of each drum.
        d=(points[i+1]-points[i]).normalized()
        beam(points[i]+d*.08,points[i]+d*.42,r*1.02,r*.99,5,10)
    split_at=len(PARTS)
    crown=points[-1]
    stone(crown,(2.2,2.2,1.35),seed)
    # Repaint crown boss to bark without adding duplicate UV layers.
    boss=PARTS[-1]
    for uv in boss.data.uv_layers[0].data:uv.uv=((5+.5)/32,.5)
    for i in range(9):
        a=i*math.tau/9+.14
        leaf(crown+Vector((0,0,.5)),a,12.5*rng.uniform(.91,1.06),2.0,4.0,5.3,[8,10,8,9],True)
    for i in range(3):
        a=i*math.tau/3
        p=crown+Vector((1.7*math.cos(a),1.7*math.sin(a),-1.3))
        o=stone(p,(1.15,1.15,1.35),seed+i,sub=1)
        for uv in o.data.uv_layers[0].data:uv.uv=((7+.5)/32,.5)
    finish(name,size,{'CrownPivot':tuple(crown)},split_at)

def foliage(name,size,seed):
    for i in range(9):
        a=i*math.tau/9+seed*.14
        leaf((0,0,.2),a,5.4+(i%3)*.5,1.45,3.4+(i%2)*1.1,1.0,[12,14,12,13])
    for i in range(3):leaf((0,0,.1),i*2.1,2.8,1.1,5.0,.2,[10,12,14,13])
    finish(name,size)

def hibiscus():
    for i in range(9):leaf((0,0,.1),i*math.tau/9,2.8,1.0,1.0,.4,[12,14,13,12])
    for i in range(6):
        a=i*math.tau/6;center=Vector((1.65*math.cos(a),1.65*math.sin(a),1.4+(i%2)*.5))
        beam((center.x,center.y,0),center,.07,.045,13,6)
        # Five broad, softly lobed sculpted petals; still flat shaded.
        for j in range(5):
            ang=j*math.tau/5+a
            pos=center+Vector((.68*math.cos(ang),.68*math.sin(ang),.10))
            bpy.ops.mesh.primitive_uv_sphere_add(segments=10,ring_count=6,radius=1,location=pos)
            o=bpy.context.object;o.scale=(.78,.53,.19);o.rotation_euler=(.1,0,ang)
            paint(o,[16,16,17,16,18])
        beam(center+Vector((0,0,.08)),center+Vector((.14,.1,.5)),.11,.08,19,7)
        o=stone(center+Vector((.14,.1,.52)),(.18,.18,.14),i,sub=1)
        for uv in o.data.uv_layers[0].data:uv.uv=((19+.5)/32,.5)
    finish('SB_Hibiscus_Clump',(6,6,3))

grotto();cascade()
palm('SB_Palm_Tall',(26,26,33),.20,35)
palm('SB_Palm_Bent',(26,26,30),.43,56)
palm('SB_Palm_Small',(19,19,22),.16,73)
foliage('SB_Tropical_Leaf_Broad',(15,15,7),1)
foliage('SB_Tropical_Leaf_Low',(11,11,5),4)
hibiscus()

def select(objects):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.hide_set(False);o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]

def fbx(path,objects):
    select(objects)
    bpy.ops.export_scene.fbx(filepath=str(path),use_selection=True,object_types={'MESH'},
        axis_forward='-Z',axis_up='Y',global_scale=1,apply_unit_scale=False,
        apply_scale_options='FBX_SCALE_NONE',bake_space_transform=False,
        use_mesh_modifiers=True,mesh_smooth_type='FACE',use_triangles=True,
        path_mode='COPY',embed_textures=True,add_leaf_bones=False,bake_anim=False)

for o,entry in zip(ASSETS,META):
    o.data.calc_loop_triangles();entry['triangles']=len(o.data.loop_triangles)
    bm=bmesh.new();bm.from_mesh(o.data)
    entry['nonmanifold_edges']=sum(not e.is_manifold for e in bm.edges);bm.free()
    assert entry['nonmanifold_edges']==0,(o.name,entry)
    assert all(p.area>1e-8 for p in o.data.polygons),o.name
    assert entry['triangles']<15000,(o.name,entry['triangles'])
    fbx(OUT/entry['file'],[o])
    # Separate low-complexity convex collision hull; never included in visible bundle.
    d=bpy.data.meshes.new('Hull');h=bpy.data.objects.new('COL_'+o.name,d);COL.objects.link(h)
    bm=bmesh.new()
    # Guaranteed planar 12-triangle bounds hull. Palms use TRUNK bounds only;
    # leaves are decorative and must never create a large solid canopy.
    col_source=next((q for q in SPLITS if q.name==o.name+'__Trunk'),o)
    lo,hi=bounds(col_source)
    for x in (lo.x,hi.x):
        for y in (lo.y,hi.y):
            for z in (lo.z,hi.z):bm.verts.new((x,y,z))
    hull=bmesh.ops.convex_hull(bm,input=list(bm.verts),use_existing_faces=False)
    bmesh.ops.delete(bm,geom=hull.get('geom_interior',[]),context='VERTS')
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(d);bm.free()
    entry['collision_file']='collision/'+h.name+'.fbx'
    (OUT/'collision').mkdir(exist_ok=True);fbx(OUT/entry['collision_file'],[h])
    h.hide_render=True;h.hide_set(True)

(OUT/'split-palms').mkdir(exist_ok=True)
for o in SPLITS:
    fbx(OUT/'split-palms'/(o.name+'.fbx'),[o]);o.hide_render=True;o.hide_set(True)

# Gallery-space locations only in the eight-object bundle; individual exports at origin.
positions=[(-42,65,0),(42,65,0),(-43,5,0),(0,5,0),(43,5,0),(-35,-34,0),(0,-34,0),(35,-34,0)]
for o,p in zip(ASSETS,positions):o.location=p
fbx(OUT/'TropicalTidepoolsBundle.fbx',ASSETS)
(OUT/'manifest.json').write_text(json.dumps({'version':2,'units':'1 unit = 1 intended Roblox stud; confirm importer scale',
    'blender_front':'+Y','blender_up':'+Z','roblox_front':'-Z','roblox_up':'+Y','pivot':'base-center',
    'texture':'palette.png','bundle':'TropicalTidepoolsBundle.fbx','assets':META,
    'split_palms':'Optional trunk/crown FBXs retain the same base origin as their combined asset.',
    'collision_warning':'Hull blocks grotto entrance. Keep cave decorative or use existing segmented proxies for an enterable cave.'},indent=2))

def material(name,rgb):
    m=bpy.data.materials.new(name);m.diffuse_color=(*rgb,1);m.use_nodes=True
    m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*rgb,1)
    m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.9
    return m

def preview_obj(o):relocate(o,PREVIEW);return o
floor=material('Gallery_sand',(.68,.61,.48));plinth=material('Display_stone',(.20,.27,.29));ink=material('Label_cream',(.9,.94,.92))
for i,(o,p) in enumerate(zip(ASSETS,positions)):
    x,y,z=p;r=35 if i<2 else (17 if i<5 else 12)
    bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=r,depth=.6,location=(x,y,-.42))
    preview_obj(bpy.context.object).data.materials.append(plinth)
    bpy.ops.object.text_add(location=(x,y+r-2,.02),rotation=(0,0,math.pi))
    t=preview_obj(bpy.context.object);t.data.body=o.name[3:].replace('_',' ').upper();t.data.align_x='CENTER';t.data.size=1.15;t.data.materials.append(ink)
bpy.ops.mesh.primitive_plane_add(size=2000,location=(0,0,-.8));preview_obj(bpy.context.object).data.materials.append(floor)
SC.world=bpy.data.worlds.new('Soft_Daylight');SC.world.use_nodes=True
SC.world.node_tree.nodes['Background'].inputs[0].default_value=(.65,.73,.85,1)
SC.world.node_tree.nodes['Background'].inputs[1].default_value=.65
def aim(o,at):o.rotation_euler=(Vector(at)-o.location).to_track_quat('-Z','Y').to_euler()
for pos,power,size in [((-60,80,130),145000,85),((80,-40,110),100000,75),((-30,-100,90),75000,65)]:
    bpy.ops.object.light_add(type='AREA',location=pos);l=preview_obj(bpy.context.object);l.data.energy=power;l.data.shape='DISK';l.data.size=size;aim(l,(0,20,0))
bpy.ops.object.camera_add(location=(45,210,185));cam=preview_obj(bpy.context.object);cam.data.type='ORTHO';cam.data.ortho_scale=210;aim(cam,(0,27,8));SC.camera=cam
SC.render.resolution_x=2000;SC.render.resolution_y=1700;SC.render.filepath=str(OUT/'preview-all-assets.png')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'TropicalTidepools.blend'))
if '--no-render' in sys.argv:
    print('TIDEPOOLS_EXPORT_COMPLETE',str(OUT));sys.exit(0)
bpy.ops.render.render(write_still=True)
# Individual inspection shots are actual Blender geometry, not concept art.
PREVIEW.hide_render=True
for o in ASSETS:o.hide_render=True
# Bring back only the floor/lights/camera, no display labels/platforms.
PREVIEW.hide_render=False
for o in PREVIEW.objects:
    if o.type in {'FONT'} or (o.type=='MESH' and o.name!='Plane'):o.hide_render=True
for i,o in enumerate(ASSETS):
    old=o.location.copy();o.location=(0,0,0);o.hide_render=False
    extent=max(o.dimensions);cam.location=(extent*.80,extent*1.7,extent*1.05);cam.data.ortho_scale=extent*1.75
    aim(cam,(0,0,o.dimensions.z*.50));SC.render.resolution_x=1200;SC.render.resolution_y=1000
    SC.render.filepath=str(OUT/(o.name+'-preview.png'));bpy.ops.render.render(write_still=True)
    o.location=old;o.hide_render=True
print('TIDEPOOLS_COMPLETE',str(OUT),sum(x['triangles'] for x in META),'triangles')

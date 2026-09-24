"""Create two reusable, textured Blender kits; no Studio or game source changes.
Run: blender --background --python tools/blender/create_garden_bay_props.py
Refuses to overwrite existing production .blend files.
"""
import bpy, bmesh, json, math, random, sys
from pathlib import Path
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[2]
PALETTE = [(59,79,90),(82,105,114),(112,134,139),(147,164,160),
 (181,196,187),(226,223,193),(245,232,205),(208,176,137),
 (88,62,44),(122,85,54),(159,115,72),(190,147,96),
 (39,79,109),(57,115,149),(99,165,178),(231,115,83),
 (53,87,47),(69,111,52),(92,138,61),(124,160,74),
 (155,183,99),(220,184,65),(250,209,92),(243,240,218),
 (116,96,160),(151,129,192),(191,163,206),(210,184,220),
 (152,167,137),(119,133,115),(199,143,117),(245,198,151)]

def start(region):
    global OUT, MAT, EXPORT, PREVIEW, PARTS
    OUT=ROOT/'assets'/region/'props-v1'
    OUT.mkdir(parents=True,exist_ok=True)
    if (OUT/'props.blend').exists() and '--replace-generated' not in sys.argv:
        raise RuntimeError(f'Preserve existing {OUT}/props.blend')
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene
    scene.unit_settings.system='NONE'
    EXPORT=bpy.data.collections.new('EXPORT_ASSETS'); scene.collection.children.link(EXPORT)
    PREVIEW=bpy.data.collections.new('PREVIEW_ONLY'); scene.collection.children.link(PREVIEW)
    atlas=bpy.data.images.new('RegionPalette',width=512,height=16,alpha=False)
    atlas.pixels=[v for y in range(16) for x in range(512) for v in (*[c/255 for c in PALETTE[x//16]],1)]
    atlas.filepath_raw=str(OUT/'palette.png'); atlas.file_format='PNG'; atlas.save(); atlas.pack()
    MAT=bpy.data.materials.new('Region_Palette'); MAT.use_nodes=True
    shader=MAT.node_tree.nodes.get('Principled BSDF'); shader.inputs['Roughness'].default_value=.8
    tex=MAT.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=atlas; tex.interpolation='Closest'
    MAT.node_tree.links.new(tex.outputs['Color'],shader.inputs['Base Color'])
    PARTS=[]

def colorize(obj,color):
    obj.data.materials.clear(); obj.data.materials.append(MAT)
    uv=obj.data.uv_layers.new(name='PaletteUV') if not obj.data.uv_layers else obj.data.uv_layers[0]
    uv.name='PaletteUV'
    for poly in obj.data.polygons:
        c=color[poly.index%len(color)] if isinstance(color,list) else color
        for loop in poly.loop_indices: uv.data[loop].uv=((c+.5)/32,.5)
    PARTS.append(obj)
    return obj

def mesh(name,verts,faces,color):
    data=bpy.data.meshes.new(name); data.from_pydata(verts,[],faces); data.update()
    obj=bpy.data.objects.new(name,data); bpy.context.scene.collection.objects.link(obj)
    return colorize(obj,color)

def lathe(rings,center=(0,0,0),sides=10,color=9):
    vs=[(center[0]+math.cos(i*math.tau/sides)*r,center[1]+math.sin(i*math.tau/sides)*r,center[2]+z) for z,r in rings for i in range(sides)]
    fs=[tuple(reversed(range(sides)))]
    for j in range(len(rings)-1):
        for i in range(sides): fs.append((j*sides+i,j*sides+(i+1)%sides,(j+1)*sides+(i+1)%sides,(j+1)*sides+i))
    fs.append(tuple((len(rings)-1)*sides+i for i in range(sides)))
    return mesh('Turned',vs,fs,color)

def blob(pos,scale,color,seed=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=pos)
    o=bpy.context.object; rng=random.Random(seed)
    for v in o.data.vertices:
        v.co*=rng.uniform(.9,1.07)
        v.co.x*=scale[0]; v.co.y*=scale[1]; v.co.z*=scale[2]
    return colorize(o,color)

def beam(a,b,r,color,sides=8):
    a,b=Vector(a),Vector(b)
    bpy.ops.mesh.primitive_cone_add(vertices=sides,radius1=r,radius2=r*.8,depth=(b-a).length,location=(a+b)/2)
    o=bpy.context.object; o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return colorize(o,color)

def ring(pos,r,thickness,color,rotation=(0,0,0)):
    bpy.ops.mesh.primitive_torus_add(major_segments=24,minor_segments=6,location=pos,rotation=rotation,major_radius=r,minor_radius=thickness)
    return colorize(bpy.context.object,color)

def leaf(a,b,width,color):
    a,b=Vector(a),Vector(b); d=b-a
    side=d.cross(Vector((0,0,1)))
    if side.length<.01: side=Vector((1,0,0))
    side.normalize(); mid=a+d*.52; ridge=mid+Vector((0,0,width*.22))
    vs=[a,mid+side*width,b,mid-side*width,ridge,mid-Vector((0,0,.045))]
    return mesh('Leaf',vs,[(0,1,4),(1,2,4),(2,3,4),(3,0,4),(1,0,5),(2,1,5),(3,2,5),(0,3,5)],color)

def finish(name):
    global PARTS
    bpy.ops.object.select_all(action='DESELECT')
    for o in PARTS:o.select_set(True)
    bpy.context.view_layer.objects.active=PARTS[0]; bpy.ops.object.join()
    o=bpy.context.object; o.name=name
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    bm=bmesh.new(); bm.from_mesh(o.data); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(o.data); bm.free()
    xs=[v.co.x for v in o.data.vertices]; ys=[v.co.y for v in o.data.vertices]; zs=[v.co.z for v in o.data.vertices]
    offset=Vector(((min(xs)+max(xs))/2,(min(ys)+max(ys))/2,min(zs)))
    for v in o.data.vertices:v.co-=offset
    # Join may retain identical material slots; normalize to one.
    o.data.materials.clear();o.data.materials.append(MAT)
    for p in o.data.polygons:p.material_index=0
    for c in list(o.users_collection):c.objects.unlink(o)
    EXPORT.objects.link(o); PARTS=[]; bpy.context.view_layer.update()
    return o

def rock(name,tall=False,moss=False):
    blob((0,0,1.5 if tall else .8),(1.45 if tall else 2.2,1.4,1.8 if tall else 1.05),[1,2,3] if not moss else [28,29,3],15 if tall else 7)
    blob((1.2,-.5,.35),(.7,.6,.5),[2,3] if not moss else [28,29],8)
    if moss:
        blob((-.3,.15,3.22 if tall else 1.58),(1.25,1.1,.42 if tall else .32),[17,18,19],32)
        for i in range(3):leaf((-.8+i*.5,-.3,3.5 if tall else 1.8),(-.5+i*.5,-.55,3.95 if tall else 2.3),.14,19)
    return finish(name)

def shell(center,r=1,color=6):
    # Closed scallop with alternating sculpted ribs on its upper surface.
    n=16; rows=4; vs=[]
    for layer in (1,-1):
        for j in range(rows):
            t=.08+j*.92/(rows-1)
            for i in range(n+1):
                a=-1.22+2.44*i/n
                z=(math.sin(t*math.pi)*.28+(i%2)*.065)*layer if layer==1 else -.04
                vs.append((center[0]+math.sin(a)*r*t,center[1]+math.cos(a)*r*t,center[2]+z*r))
    row=n+1; off=rows*row; fs=[]
    for l in range(2):
        for j in range(rows-1):
            for i in range(n):
                q=(l*off+j*row+i,l*off+j*row+i+1,l*off+(j+1)*row+i+1,l*off+(j+1)*row+i)
                fs.append(q if l==0 else tuple(reversed(q)))
    perimeter=list(range(row))+[j*row+n for j in range(1,rows)]+list(range(off-2,off-row-1,-1))+[j*row for j in range(rows-2,0,-1)]
    for i,a in enumerate(perimeter):
        b=perimeter[(i+1)%len(perimeter)];fs.append((a,a+off,b+off,b))
    mesh('Scallop',vs,fs,[color,5,6])

def splash():
    start('splashwater-bay'); assets=[rock('SB_Coastal_Rock_Wide'),rock('SB_Coastal_Rock_Tall',True)]
    beam((-2,0,.4),(2.5,.25,.8),.5,[9,10,11]);beam((.3,.1,.6),(1.25,1.1,1.35),.26,10)
    for i in range(3):beam((-1.5+i*.5,-.39,.5),(.5+i*.5,-.28,.72),.035,8,5)
    assets.append(finish('SB_Driftwood'))
    shell((-.65,-.45,.1),1.25);shell((.6,-.4,.08),.75,7)
    assets.append(finish('SB_Shell_Cluster'))
    vs=[(0,0,.3),(0,0,0)]
    for i in range(10):
        a=i*math.pi/5;r=1.3 if i%2==0 else .5;vs.append((math.sin(a)*r,math.cos(a)*r,.1))
    fs=[]
    for i in range(10):fs.extend([(0,2+i,2+(i+1)%10),(1,2+(i+1)%10,2+i)])
    mesh('Starfish',vs,fs,[15,30,31])
    for i in range(5):
        a=i*math.tau/5
        for t in (.35,.65,.9):blob((math.sin(a)*t,math.cos(a)*t,.25-t*.09),(.055,.055,.04),31,i)
    assets.append(finish('SB_Starfish'))
    lathe([(0,.52),(.15,.6),(2.6,.47),(2.75,.55)],color=[8,9,10])
    lathe([(2.65,.6),(2.87,.6)],color=12)
    for z in (.7,.92,1.14):ring((0,0,z),.56,.115,[7,11])
    assets.append(finish('SB_Rope_Bollard'))
    lathe([(0,.8),(.25,.91),(1.25,1.02),(2.3,.9),(2.5,.8)],color=[9,10,11,10])
    for z,r in ((.35,.94),(2.12,.95)):lathe([(z,r),(z+.18,r)],color=12)
    lathe([(2.49,.76),(2.55,.76)],color=10)
    assets.append(finish('SB_Harbor_Barrel'))
    lathe([(0,.7),(.2,.95),(.7,1.05),(1.2,.9)],color=12)
    lathe([(1.2,.9),(1.8,.65)],color=23);lathe([(1.8,.65),(2.5,.24)],color=15)
    ring((0,0,2.75),.25,.08,8,(math.pi/2,0,0))
    assets.append(finish('SB_Marker_Buoy'))
    deliver(assets,'SplashwaterPropsBundle','SPLASHWATER BAY')

def flower(x,y,h,daisy=True):
    beam((x,y,0),(x+.12,y,h),.055,17,6)
    leaf((x,y,h*.45),(x-.6,y+.08,h*.65),.2,19)
    leaf((x,y,h*.6),(x+.65,y,h*.76),.19,18)
    if daisy:
        for i in range(7):
            a=i*math.tau/7
            o=blob((x+.12+math.sin(a)*.38,y+math.cos(a)*.38,h),(.19,.4,.1),23,i)
            o.rotation_euler.z=-a
        blob((x+.12,y,h+.06),(.22,.22,.12),[21,22],4)
    else:
        for i in range(3):
            z=h-i*.32
            lathe([(z-.27,.27),(z-.15,.25),(z,.1)],(x+.24,y,0),8,[24,25,26])

def garden():
    start('gusty-gardens');assets=[rock('GG_Moss_Rock_Wide',moss=True),rock('GG_Moss_Rock_Tall',True,True)]
    for i,(x,y,h) in enumerate([(-.8,.1,2),(.25,.4,2.7),(.9,-.3,1.7)]):flower(x,y,h)
    assets.append(finish('GG_Daisy_Cluster'))
    for x,y,h in [(-.6,0,2.5),(.25,.2,3.1),(.75,-.4,2)]:flower(x,y,h,False)
    assets.append(finish('GG_Bluebell_Cluster'))
    for i in range(7):
        a=i*math.tau/7; end=Vector((math.sin(a)*1.9,math.cos(a)*1.9,1.0+(i%2)*.35))
        base=Vector((0,0,.05));beam(base,end,.045,17,5)
        side=Vector((math.cos(a),-math.sin(a),0))
        for t in (.25,.4,.55,.7,.85):
            p=base.lerp(end,t)
            for sign in (-1,1):leaf(p,p+side*sign*(1-t)*.8+end*.13,.16*(1-t)+.04,18+i%3)
    assets.append(finish('GG_Fern'))
    for i,(x,y,z,s) in enumerate([(-.9,0,.8,1),(.65,.2,1.1,1.2),(0,-.5,.6,.9)]):blob((x,y,z),(s,s*.9,s),[17,18,19,20],i)
    assets.append(finish('GG_Meadow_Shrub'))
    beam((0,0,0),(1.5,0,6),.65,[8,9,10]);beam((1.2,0,4),(3,.5,8),.4,9)
    beam((.8,0,3.8),(-1,.5,6.5),.3,10)
    for i,(x,y,z,s) in enumerate([(-.8,.4,7,2),(1,.5,8.3,2.4),(3,.4,8,2),(4,-.3,7.4,1.5),(1.5,-1.1,7,1.8)]):
        blob((x,y,z),(s,s*.72,s*.7),[17,18,19,20],20+i)
    assets.append(finish('GG_Windbent_Tree'))
    lathe([(0,.85),(.2,.9),(1.4,1.15),(1.6,1.15),(1.6,1.0),(1.25,.95)],color=[9,10,11])
    for z,r in ((.32,.95),(1.39,1.16)):ring((0,0,z),r,.075,12)
    lathe([(1.3,.97),(1.38,.98)],color=8)
    for x,y,h in [(-.4,0,2.7),(.4,.2,3.2),(.2,-.4,2.5)]:flower(x,y,h)
    assets.append(finish('GG_Flower_Planter'))
    deliver(assets,'GustyPropsBundle','GUSTY GARDENS')

def fbx(path):
    bpy.ops.export_scene.fbx(filepath=str(path),use_selection=True,object_types={'MESH'},
        axis_forward='-Z',axis_up='Y',global_scale=1,apply_unit_scale=False,
        apply_scale_options='FBX_SCALE_NONE',bake_space_transform=False,
        use_mesh_modifiers=True,mesh_smooth_type='FACE',use_triangles=True,
        path_mode='COPY',embed_textures=True,add_leaf_bones=False,bake_anim=False)

def simple_mat(name,color):
    m=bpy.data.materials.new(name);m.use_nodes=True
    m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*color,1)
    return m

def deliver(assets,bundle,title):
    manifest={'version':1,'units':'1 modeling unit = 1 intended Roblox stud; verify importer scale',
        'pivot':'ground-center','blender_up':'+Z','fbx_up':'+Y','texture':'palette.png','assets':[]}
    for o in assets:
        bm=bmesh.new();bm.from_mesh(o.data);bad=sum(not e.is_manifold for e in bm.edges);bm.free()
        assert bad==0,(o.name,bad)
        assert all(p.area>1e-9 for p in o.data.polygons),o.name
        o.data.calc_loop_triangles()
        bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
        fbx(OUT/(o.name+'.fbx'))
        x,y,z=o.dimensions
        manifest['assets'].append({'name':o.name,'file':o.name+'.fbx','dimensions_studs_xyz':[round(x,4),round(z,4),round(y,4)],'triangles':len(o.data.loop_triangles),'nonmanifold_edges':bad})
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
    # Gallery has uniform slots. Tree is displayed smaller, export uses full size.
    for i,o in enumerate(assets):o.location=((i%4-1.5)*8,(.5-i//4)*10,0)
    bpy.ops.object.select_all(action='DESELECT')
    for o in assets:o.select_set(True)
    fbx(OUT/(bundle+'.fbx'))
    plinth=simple_mat('PreviewPlinth',(.07,.095,.11));ink=simple_mat('PreviewText',(.84,.88,.83))
    for i,o in enumerate(assets):
        if 'Tree' in o.name:o.scale=(.55,.55,.55)
        x,y,_=o.location
        bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=3.35,depth=.18,location=(x,y,-.12))
        bpy.context.object.data.materials.append(plinth)
        bpy.ops.object.text_add(location=(x,y-3,.025));label=bpy.context.object
        label.data.body=o.name[3:].replace('_',' ').upper();label.data.size=.29;label.data.align_x='CENTER';label.data.materials.append(ink)
    bpy.ops.object.text_add(location=(0,12,.03));label=bpy.context.object;label.data.body=title+' / BLENDER PROP KIT'
    label.data.size=.65;label.data.align_x='CENTER';label.data.materials.append(ink)
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.25));bpy.context.object.data.materials.append(simple_mat('PreviewFloor',(.027,.044,.054)))
    scene=bpy.context.scene;scene.world=bpy.data.worlds.new('Studio');scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.3,.36,.42,1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value=.6
    def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
    for pos,power,size in [((-12,-15,22),6500,16),((14,4,21),5500,15),((0,16,22),5000,12)]:
        bpy.ops.object.light_add(type='AREA',location=pos);o=bpy.context.object;o.data.energy=power;o.data.size=size;aim(o,(0,0,0))
    bpy.ops.object.camera_add(location=(3,-33,44));o=bpy.context.object;o.data.type='ORTHO';o.data.ortho_scale=37;aim(o,(0,1,0));scene.camera=o
    scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
    scene.render.resolution_x=1800;scene.render.resolution_y=1400;scene.render.resolution_percentage=100
    scene.view_settings.view_transform='AgX';scene.render.image_settings.file_format='PNG';scene.render.filepath=str(OUT/'preview.png')
    for o in list(scene.objects):
        if o not in assets:
            for c in list(o.users_collection):c.objects.unlink(o)
            PREVIEW.objects.link(o)
    # Save production scene at full asset scale; temporarily shrink only render tree.
    tree_scales={o.name:o.scale.copy() for o in assets}
    for o in assets:o.scale=(1,1,1)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'props.blend'))
    for o in assets:o.scale=tree_scales[o.name]
    bpy.ops.render.render(write_still=True)
    print('KIT_COMPLETE',OUT, 'triangles',sum(a['triangles'] for a in manifest['assets']))

if __name__ == '__main__':
    if '--garden-only' not in sys.argv:splash()
    garden()

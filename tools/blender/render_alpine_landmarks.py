"""Render actual Alpine mesh kit assembled for visual review; no asset mutations."""
import bpy,json,math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'assets/frostbite-peaks/alpine-v2'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'AlpineOutpost.blend'))
SC=bpy.context.scene
for c in list(SC.collection.children):c.hide_render=True
SHOW=bpy.data.collections.new('ASSEMBLY_PREVIEW_ONLY');SC.collection.children.link(SHOW)
manifest=json.loads((OUT/'manifest.json').read_text())
meta={a['name']:a for a in manifest['assets']}
def place(short,p,yaw=0,scale=1):
    src=bpy.data.objects['FP_Alpine_'+short];o=src.copy();o.data=src.data;SHOW.objects.link(o)
    o.name='Assembled_'+short;o.location=p;o.rotation_euler.z=math.radians(yaw);o.scale=(scale,)*3;o.hide_render=False
    return o
def socket(o,key):
    a=meta[o.name.replace('Assembled_','FP_Alpine_').split('.')[0]]
    x,y,z=a['sockets_roblox_xyz_from_base'][key]
    bpy.context.view_layer.update();return o.matrix_world@Vector((x,-z,y))
def material(name,c):
    m=bpy.data.materials.new(name);m.use_nodes=True;bs=m.node_tree.nodes['Principled BSDF'];bs.inputs['Base Color'].default_value=(*c,1);bs.inputs['Roughness'].default_value=.85;return m
SNOW=material('Preview_Snow',(.75,.84,.9));STONE=material('Preview_Stone',(.25,.32,.40));ICE=material('Preview_Ice',(.25,.53,.67))
def move(o):
    for c in list(o.users_collection):c.objects.unlink(o)
    SHOW.objects.link(o);return o
def block(p,s,mat,bevel=.25):
    bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=move(bpy.context.object);o.scale=s
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(mat)
    m=o.modifiers.new('Edge','BEVEL');m.width=bevel;m.segments=2
    return o
# Illustrative supports only: production geometry belongs to Claude's map.
block((36,0,2.85),(45,48,5.7),STONE,.8);block((36,0,5.9),(45,48,.5),SNOW,.8)
for i in range(5):
    h=6-(i+1)*1.0;block((36,25+i*2.6,h/2),(13,2.8,h),STONE,.15)
    block((36,25+i*2.6,h+.10),(12.7,2.4,.18),SNOW,.08)
lodge=place('Lodge',(36,-8,6.15))
place('Tent',(23,13,6.15),-20,.82);place('Woodpile',(55,10,6.15),90,.9)
place('Crate',(53,2,6.15),0,.8);place('Barrel',(49,11,6.15),10,.9)
place('Pennant',(17,-17,6.15),-10,1.1)
for x in (27,45):place('Lantern_Post',(x,21,6.15),0,.75)
for y in (-10,3,16):place('Railing',(14,y,6.15),90,1)
bridge=place('Bridge',(-35,0,7.0))
place('Shelf_North',(-24,-11.25,0))
place('Shelf_South',(-40.75,22.5,0))
place('Gorge_Rock',(-53,-10,0))
for i in range(6):
    h=8.5-(i+1)*1.2;block((-40.75,31.2+i*2.4,h/2),(10,2.6,h),STONE,.12)
    block((-40.75,31.2+i*2.4,h+.1),(9.8,2.35,.16),SNOW,.04)
block((-35,0,.2),(19,26,.4),ICE,.2)
for x,y,k in [(-65,-31,'Cliff_Wide'),(-16,-42,'Cliff_Tall'),(58,-22,'Cliff_Tall'),(18,-29,'Cliff_Wide')]:place(k,(x,y,0),8,1)
for x,y,kind,sc in [(54,-28,'Tall',1.15),(17,-23,'Medium',1.0),(57,23,'Medium',.95),(61,1,'Sapling',1.15),(-52,-30,'Tall',1.1),(-51,37,'Medium',1.0),(-19,28,'Sapling',1.1),(7,-34,'Medium',1)]:
    place('Fir_'+kind,(x,y,0),x*3,sc)
for x,y in [(54,25),(17,30),(8,-24),(-47,32),(-22,27),(-20,-11)]:
    place('Snow_Rock',(x,y,0),x*5,.70);place('Grass',(x+3,y+2,0),x,.8);place('Frosted_Shrub',(x-3,y-1,0),x,.75)
place('Signpost',(-7.25,-1,8.5),10,.7)
place('Railing',(-18,-.25,8.5),0,.65)
place('Camp_Sled',(28,15,6.15),-15,1)
place('Notice_Board',(16,-21,6.15),0,1)
for x in (28,44):place('Terrace_Post',(x,24,0),0,1)
for x,y in [(0,5),(0,-13),(0,24)]:place('Snow_Drift',(x,y,0),30,.7)
block((5,2,-1.0),(143,126,1.8),SNOW,2)
bpy.ops.mesh.primitive_plane_add(size=1600,location=(0,0,-2));move(bpy.context.object).data.materials.append(material('Backdrop',(.35,.45,.54)))
def aim(o,p):o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
for p,power,size in [((-65,20,120),145000,65),((70,25,100),70000,65),((0,-90,95),100000,55)]:
    bpy.ops.object.light_add(type='AREA',location=p);o=move(bpy.context.object);o.data.energy=power;o.data.size=size;aim(o,(0,0,8))
for key in ('WindowW','WindowE','WindowGable','AnnexWindow','PorchLanternW','PorchLanternE'):
    p=socket(lodge,key);p.y+=.8
    bpy.ops.object.light_add(type='POINT',location=p);o=move(bpy.context.object);o.data.energy=85;o.data.color=(1,.62,.24);o.data.shadow_soft_size=.5
    if key.startswith('Window') or key=='AnnexWindow':
        pane=material('Preview_WarmPane_'+key,(1,.51,.12));bs=pane.node_tree.nodes.get('Principled BSDF')
        bs.inputs['Emission Color'].default_value=(1,.49,.12,1);bs.inputs['Emission Strength'].default_value=.65
        p=socket(lodge,key);p.y-=.015
        w,h=(4,4.5) if key in ('WindowW','WindowE') else ((3.5,3) if key=='WindowGable' else (3,3))
        block(tuple(p),(w-.22,.025,h-.22),pane,.01)
bpy.ops.object.camera_add(location=(6,145,122));cam=move(bpy.context.object);cam.data.type='ORTHO';cam.data.ortho_scale=155;aim(cam,(5,0,8));SC.camera=cam
SC.render.resolution_x=2200;SC.render.resolution_y=1500;SC.render.resolution_percentage=100;SC.cycles.samples=48
SC.render.filepath=str(OUT/'preview-landmark-assembly.png');bpy.ops.render.render(write_still=True)
print('ALPINE_ASSEMBLY_COMPLETE',flush=True)

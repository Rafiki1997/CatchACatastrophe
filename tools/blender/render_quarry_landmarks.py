"""Actual asset assembly preview. Lava/light dressing is preview-only, not exported."""
import bpy,json,math,sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'assets/cinder-canyon/quarry-v2'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'CinderQuarry.blend'))
SC=bpy.context.scene;source=bpy.data.collections['EXPORT_12_ASSETS']
if '--refresh' in sys.argv:
    bpy.ops.render.render(write_still=True)
manifest=json.loads((OUT/'manifest.json').read_text());meta={a['name']:a for a in manifest['assets']}
for c in list(SC.collection.children):c.hide_render=True
SHOW=bpy.data.collections.new('ASSEMBLY_PREVIEW_ONLY');SC.collection.children.link(SHOW)
def move(o):
    for c in list(o.users_collection):c.objects.unlink(o)
    SHOW.objects.link(o);return o
def copy(name,pos,scale=1):
    o=source.objects[name].copy();o.data=o.data.copy();SHOW.objects.link(o);o.hide_render=False;o.hide_set(False)
    o.location=pos;o.scale=(scale,scale,scale);return o
def socket(name,s):
    x,y,z=meta[name]['sockets_roblox_xyz_from_base'][s]
    return Vector((x,-z,y))
def mat(name,col,emission=0):
    m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes['Principled BSDF']
    n.inputs['Base Color'].default_value=(*col,1);n.inputs['Roughness'].default_value=.8
    if emission:n.inputs['Emission Color'].default_value=(*col,1);n.inputs['Emission Strength'].default_value=emission
    return m
sand=mat('Preview sand',(.58,.26,.12));lava=mat('Preview lava', (1,.30,.025),1.2);hot=mat('Preview hot core',(1,.67,.12),1.0)
mine=copy('CC_Quarry_Mine',(44,-3,0));terrace=copy('CC_Quarry_Terrace',(-45,-3,0))
door=mine.location+socket('CC_Quarry_Mine','DoorBase')
rail=copy('CC_Quarry_Rail',door+Vector((0,13,.10)))
cart=copy('CC_Quarry_Cart',door+Vector((0,16,1.04)))
hoist=copy('CC_Quarry_Hoist',terrace.location+socket('CC_Quarry_Terrace','HoistBase'))
def band(a,b,w,m):
    a,b=Vector(a),Vector(b)
    bpy.ops.mesh.primitive_cube_add(size=1,location=(a+b)/2);o=move(bpy.context.object)
    o.scale=(w,.35,(b-a).length);o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();o.data.materials.append(m)
points=[terrace.location+socket('CC_Quarry_Terrace',n) for n in ('LavaUpperLip','LavaLowerLip','LavaFoot')]
for i in range(2):
    band(points[i]+Vector((0,.3,0)),points[i+1]+Vector((0,.3,0)),3.5+i,lava)
    band(points[i]+Vector((0,.55,0)),points[i+1]+Vector((0,.55,0)),.8,hot)
for name,pos,s in [
    ('CC_Quarry_Cactus_Tall',(77,13,0),.85),('CC_Quarry_Cactus_Round',(11,14,0),1),
    ('CC_Quarry_Cactus_Tall',(-79,4,0),.8),('CC_Quarry_Agave',(-13,22,0),.8),
    ('CC_Quarry_Flowers',(76,22,0),1),('CC_Quarry_Agave',(11,6,0),.7),
    ('CC_Quarry_Crate',(-63,-1,36),.8),('CC_Quarry_Crate',(-60,28,0),1),
    ('CC_Quarry_Crate',(15,25,0),1),('CC_Quarry_Flowers',(-76,20,0),1)]:copy(name,pos,s)
bpy.ops.mesh.primitive_plane_add(size=1500,location=(0,0,-.15));move(bpy.context.object).data.materials.append(sand)
def aim(o,p):o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
for p,power,size in [((-80,70,120),110000,75),((80,-65,110),75000,70)]:
    bpy.ops.object.light_add(type='AREA',location=p);o=move(bpy.context.object);o.data.energy=power;o.data.size=size;aim(o,(0,0,12))
lantern=mine.location+socket('CC_Quarry_Mine','Lantern')
bpy.ops.object.light_add(type='POINT',location=lantern+Vector((0,1,0)));o=move(bpy.context.object);o.data.energy=150;o.data.color=(1,.55,.12);o.data.shadow_soft_size=.8
bpy.ops.object.camera_add(location=(4,175,118));cam=move(bpy.context.object);cam.data.type='ORTHO';cam.data.ortho_scale=195;aim(cam,(0,5,19));SC.camera=cam
SC.render.resolution_x=1900;SC.render.resolution_y=1100;SC.cycles.samples=32
SC.render.filepath=str(OUT/'preview-landmark-assembly.png');bpy.ops.render.render(write_still=True)
if '--refresh' in sys.argv:
    for obj in SHOW.objects:
        if obj.type=='MESH' and obj!=terrace and obj.name!='Plane.001':obj.hide_render=True
    terrace.location=(0,0,0)
    extent=max(terrace.dimensions);cam.location=(extent*.72,extent*1.7,extent*1.12)
    cam.data.ortho_scale=extent*1.75;aim(cam,(0,0,terrace.dimensions.z*.48))
    SC.render.resolution_x=1100;SC.render.resolution_y=950
    SC.render.filepath=str(OUT/'CC_Quarry_Terrace-preview.png');bpy.ops.render.render(write_still=True)
print('ASSEMBLY_PREVIEW_COMPLETE')

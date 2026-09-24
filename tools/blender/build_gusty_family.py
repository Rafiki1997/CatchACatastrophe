"""Assemble approved thin-leaf A and independently built B/C into editable family."""
import bpy,json,sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'assets/gusty-gardens/broadleaf-family-v1'
if (OUT/'GustyBroadleafFamily.blend').exists() and '--rebuild' not in sys.argv: raise RuntimeError('Use -- --rebuild explicitly')
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/gusty-gardens/broadleaf-v2-thin-leaves/GustyBroadleafThinLeaves.blend'))
sc=bpy.context.scene; cam=sc.camera; cols=[]; report=[]
for code,label,x in [('A','Meadow',-23),('B','Spreading',0),('C','Upright',23)]:
    if code=='A': col=bpy.data.collections['GG_Broadleaf_A_Meadow']
    else:
        with bpy.data.libraries.load(str(OUT/'source'/code/'GustyBroadleaf.blend'),link=False) as (src,dst): dst.collections=['GG_Broadleaf_A_Meadow']
        col=dst.collections[0]; sc.collection.children.link(col)
    col.name='GG_Broadleaf_'+code+'_'+label; cols.append(col)
    for o in col.objects:
        suffix=o.name.split('_')[-1].split('.')[0]
        o.name='GG_Broadleaf_'+code+'_'+suffix; o.location=(x,0,0)
    vs=[v.co for o in col.objects for v in o.data.vertices]
    lo=[min(v[i] for v in vs) for i in range(3)]; hi=[max(v[i] for v in vs) for i in range(3)]
    for o in col.objects:o.data.calc_loop_triangles()
    report.append({'id':code,'label':label,'collection':col.name,'gallery_x':x,'bounds_blender':{'min':lo,'max':hi},
                   'source_triangles':sum(len(o.data.loop_triangles) for o in col.objects)})
    bpy.ops.object.text_add(location=(x,-12,0.02)); text=bpy.context.object
    text.name='Review label '+code; text.data.body=code+' / '+label.upper(); text.data.align_x='CENTER'; text.data.size=.9
    for c in list(text.users_collection):c.objects.unlink(text)
    bpy.data.collections['PREVIEW_ONLY'].objects.link(text)
cam.location=(0,-86,38); cam.rotation_euler=(Vector((0,0,8))-cam.location).to_track_quat('-Z','Y').to_euler(); cam.data.ortho_scale=70
sc.render.resolution_x=2000; sc.render.resolution_y=1000; sc.cycles.samples=32
sc.render.filepath=str(OUT/'broadleaf-family-source.png')
(OUT/'source-manifest.json').write_text(json.dumps({'status':'A thinner-leaf treatment approved 2026-09-23; B/C derived structural variants','variants':report},indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'GustyBroadleafFamily.blend'))
bpy.ops.render.render(write_still=True)
print('GUSTY_FAMILY_SOURCE_COMPLETE',flush=True)

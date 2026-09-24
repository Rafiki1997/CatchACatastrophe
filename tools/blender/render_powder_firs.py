"""Re-render the native Powder Fir scene without rebuilding its geometry.
Options after --: --only A|B|C|lineup|detail, --samples 32.
"""
import bpy, sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/frostbite-peaks/powder-firs-v1'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'PowderFirs.blend'))
sc=bpy.context.scene;cam=sc.camera
only=sys.argv[sys.argv.index('--only')+1] if '--only' in sys.argv else 'all'
sc.cycles.samples=int(sys.argv[sys.argv.index('--samples')+1]) if '--samples' in sys.argv else 48
def aim(target):cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
def render(name,w,h):
    sc.render.resolution_x=w;sc.render.resolution_y=h;sc.render.filepath=str(OUT/name);bpy.ops.render.render(write_still=True)
if only in ('all','lineup'):render('powder-firs-lineup.png',2400,1600)
if only!='lineup':
    for o in bpy.data.collections['PREVIEW_ONLY'].objects:
        if o.type=='FONT':o.hide_render=True
    collections=[bpy.data.collections[n] for n in ['PowderFir_A_Original','PowderFir_B_Broad','PowderFir_C_Upright']]
    for c in collections:c.hide_render=True
    for code,label,height,col in zip(['A','B','C'],['Original','Broad','Upright'],[26,23.5,28.3],collections):
        if only not in ('all',code) and not (only=='detail' and code=='A'):continue
        col.hide_render=False;positions={o:o.location.copy() for o in col.objects}
        for o in col.objects:o.location.x=0
        cam.location=(19,-48,30);aim((0,0,height*.49));cam.data.ortho_scale=height*1.2
        if only!='detail':render('powder-fir-'+code.lower()+'-'+label.lower()+'.png',1300,1600)
        if code=='A' and only in ('all','detail'):
            cam.location=(12,-33,18);aim((0,0,10.4));cam.data.ortho_scale=14;render('powder-fir-branch-detail.png',1500,1150)
        for o,p in positions.items():o.location=p
        col.hide_render=True
print('POWDER_RENDER_COMPLETE',flush=True)

"""Render saved source without rebuilding. Optional -- --only player|hero|front|side|detail|comparison."""
import bpy, sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/gusty-gardens/broadleaf-v2'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'GustyBroadleaf.blend'))
sc=bpy.context.scene; cam=sc.camera
only=sys.argv[sys.argv.index('--only')+1] if '--only' in sys.argv else 'all'
shots=[
    ('hero','three-quarter',(27,-43,25),(0,0,8.9),25,1200,1200),
    ('front','front',(0,-50,9),(0,0,9),23,1200,1200),
    ('side','side',(50,0,9),(0,0,9),23,1200,1200),
    ('detail','detail',(13,-25,12),(.7,-1,7),11,1200,1200),
    ('player','player-scale',(26,-42,6.5),(2,0,9),30,1500,1100),
    ('comparison','powder-comparison',(10,-65,29),(10,0,12),49,1700,1150)]
for key,name,pos,target,scale,w,h in shots:
    if only not in ('all',key): continue
    bpy.data.collections['PowderFir_A_Original'].hide_render=key!='comparison'
    bpy.data.collections['PREVIEW_5_STUD_PERSON'].hide_render=key not in ('player','comparison')
    cam.location=pos; cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.type='PERSP' if key=='player' else 'ORTHO'; cam.data.lens=48; cam.data.ortho_scale=scale
    sc.render.resolution_x=w; sc.render.resolution_y=h
    sc.render.filepath=str(OUT/('broadleaf-'+name+'.png')); bpy.ops.render.render(write_still=True)
print('GUSTY_BROADLEAF_RENDER_COMPLETE',flush=True)

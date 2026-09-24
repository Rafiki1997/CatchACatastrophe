"""Refresh gallery and individual previews from the saved .blend; no export edits."""
import bpy,sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'assets/frostbite-peaks/alpine-v2'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'AlpineOutpost.blend'))
SC=bpy.context.scene;cam=SC.camera
SC.render.filepath=str(OUT/'preview-all-assets.png');bpy.ops.render.render(write_still=True)
if '--gallery-only' not in sys.argv:
    pv=bpy.data.collections['PREVIEW_ONLY'];ex=bpy.data.collections['EXPORT_ALPINE_ASSETS']
    for o in pv.objects:
        if o.type=='FONT' or (o.type=='MESH' and o.name!='PreviewGround'):o.hide_render=True
    ex.hide_render=False
    assets=[o for o in ex.objects if o.type=='MESH']
    for o in assets:o.hide_render=True
    for o in assets:
        if '--only' in sys.argv and o.name not in sys.argv[sys.argv.index('--only')+1].split(','):continue
        old=o.location.copy();o.location=(0,0,0);o.hide_render=False
        bpy.context.view_layer.update();e=max(o.dimensions)
        cam.location=(e*.78,e*1.7,e*1.04);cam.data.ortho_scale=e*1.65
        cam.rotation_euler=(Vector((0,0,o.dimensions.z*.47))-cam.location).to_track_quat('-Z','Y').to_euler()
        SC.render.resolution_x=1400;SC.render.resolution_y=1200
        SC.render.filepath=str(OUT/(o.name+'-preview.png'));bpy.ops.render.render(write_still=True)
        o.location=old;o.hide_render=True
print('ALPINE_PREVIEWS_COMPLETE',flush=True)

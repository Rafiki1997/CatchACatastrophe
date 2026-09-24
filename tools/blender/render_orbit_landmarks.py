"""Render assembled exported art at full relative scale; preview only."""
from pathlib import Path
import bpy
from mathutils import Vector
OUT = Path(__file__).resolve().parents[2]/"assets/orbit-outpost/props-v1"
bpy.ops.wm.open_mainfile(filepath=str(OUT/"props.blend"))
scene = bpy.context.scene
preview = bpy.data.collections["PREVIEW_ONLY"]
assets = bpy.data.collections["EXPORT_ASSETS"]
for obj in preview.objects:
    if obj.type in {"MESH", "FONT"}:
        obj.hide_render = True
# Keep the studio ground, lights, camera. Floor uses a unique material.
for obj in preview.objects:
    if obj.type == "MESH" and any(m and m.name=="PreviewFloor" for m in obj.data.materials):
        obj.hide_render = False

def place(name, pos, yaw=0):
    obj = assets.objects[name].copy()
    obj.data = assets.objects[name].data
    preview.objects.link(obj)
    obj.name = "ASSEMBLED_"+name
    obj.location = pos
    obj.rotation_euler.z = yaw
    obj.hide_render = False
    return obj

place("OO_Gravity_Cradle",(-19,1,0))
place("OO_Gravity_Meteor",(-19,1,7))
place("OO_Orbit_Stone",(-24.5,1,10))
place("OO_Orbit_Stone",(-13.5,1,10))
place("OO_Field_Lab_Base",(5,2,0))
place("OO_Field_Lab_Dome_Frame",(5,2,5))
place("OO_Drone_Dock",(23,-4,0))
place("OO_Survey_Drone",(23,-4,1.5))
place("OO_Alien_Mushroom_Tall",(1,-12,0))
place("OO_Alien_Fern",(9,-12,0))
place("OO_Crystal_Cluster",(-10,-9,0))
place("OO_Star_Bloom_Tuft",(6,-12,0))
place("OO_Cosmic_Beacon",(17,-8,0))
scene.camera.location=(25,-64,43)
scene.camera.rotation_euler=(Vector((-1,0,9))-scene.camera.location).to_track_quat("-Z","Y").to_euler()
scene.camera.data.ortho_scale=74
scene.render.resolution_x=1800
scene.render.resolution_y=1100
scene.render.filepath=str(OUT/"landmark-preview.png")
bpy.ops.render.render(write_still=True)
print("ASSEMBLY_PREVIEW_COMPLETE")

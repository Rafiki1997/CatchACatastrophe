"""Render exported decal textures on contrasting surfaces for alpha visual QA."""
import bpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'assets/frostbite-peaks/alpine-v2'
bpy.ops.wm.read_factory_settings(use_empty=True)
for i,(name,bg) in enumerate([('FP_Alpine_Tex_IceCracks',(.12,.34,.46,1)),('FP_Alpine_Decal_Tracks',(.83,.89,.94,1))]):
    m=bpy.data.materials.new(name);m.use_nodes=True;ns=m.node_tree.nodes;links=m.node_tree.links
    ns.clear();out=ns.new('ShaderNodeOutputMaterial');em=ns.new('ShaderNodeEmission');mix=ns.new('ShaderNodeMixRGB');tex=ns.new('ShaderNodeTexImage')
    tex.image=bpy.data.images.load(str(OUT/(name+'.png')));mix.inputs[1].default_value=bg
    links.new(tex.outputs['Alpha'],mix.inputs[0]);links.new(tex.outputs['Color'],mix.inputs[2]);links.new(mix.outputs[0],em.inputs[0]);links.new(em.outputs[0],out.inputs['Surface'])
    bpy.ops.mesh.primitive_plane_add(size=1,location=(i*1.04-.52,0,0));bpy.context.object.data.materials.append(m)
bpy.ops.object.camera_add(location=(0,0,3));cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=2.08
sc=bpy.context.scene;sc.camera=cam;sc.render.engine='CYCLES';sc.cycles.samples=4
sc.render.resolution_x=1400;sc.render.resolution_y=700;sc.render.resolution_percentage=100;sc.view_settings.view_transform='Standard'
sc.render.filepath=str(OUT/'preview-surface-details.png');bpy.ops.render.render(write_still=True)
print('SURFACE_DETAIL_PREVIEW_COMPLETE')

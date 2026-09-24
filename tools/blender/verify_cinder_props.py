"""Round-trip each FBX, then render the saved Blender kit with legible labels."""
import bpy
import bmesh
import json
from pathlib import Path
from mathutils import Vector

out = Path(__file__).resolve().parents[2] / 'assets/cinder-canyon/props-v1'
manifest = json.loads((out/'manifest.json').read_text(encoding='utf-8'))
bpy.ops.wm.open_mainfile(filepath=str(out/'cinder-props.blend'))
# Export local origins, not the presentation gallery's object positions. Preserve
# FBX axis metadata instead of baking the conversion twice into mesh geometry.
for asset in manifest['assets']:
    obj=bpy.data.objects[asset['name']]
    saved=obj.location.copy()
    obj.location=(0,0,0)
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active=obj
    bpy.ops.export_scene.fbx(filepath=str(out/asset['file']),use_selection=True,
        object_types={'MESH'},axis_forward='-Z',axis_up='Y',global_scale=1,
        apply_unit_scale=False,apply_scale_options='FBX_SCALE_NONE',
        bake_space_transform=False,use_mesh_modifiers=True,mesh_smooth_type='FACE',
        use_triangles=True,path_mode='COPY',embed_textures=True,add_leaf_bones=False,bake_anim=False)
    obj.location=saved
results = []
for asset in manifest['assets']:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(out/asset['file']))
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    assert len(meshes) == 1, asset['name']
    obj = meshes[0]
    obj.data.calc_loop_triangles()
    dx,dy,dz = obj.dimensions
    expected = asset['dimensions_studs_xyz']
    assert max(abs(a-b) for a,b in zip([dx,dz,dy],expected)) < .005, (asset['name'],obj.dimensions,expected)
    assert len(obj.data.loop_triangles) == asset['triangles'],asset['name']
    assert obj.location.length < 1e-5,asset['name']
    assert obj.data.uv_layers,asset['name']
    bm=bmesh.new()
    bm.from_mesh(obj.data)
    nonmanifold=sum(not e.is_manifold for e in bm.edges)
    bm.free()
    assert nonmanifold == 0,asset['name']
    assert len(obj.data.materials) == 1,asset['name']
    image_nodes = [n for n in obj.data.materials[0].node_tree.nodes if n.type == 'TEX_IMAGE' and n.image]
    assert image_nodes,asset['name']
    results.append({'name':asset['name'],'roundtrip':'pass','triangles':asset['triangles'],
                    'nonmanifold_edges':nonmanifold,'texture':image_nodes[0].image.name})

(out/'validation.json').write_text(json.dumps({'fbx_roundtrip':results,
    'studio_import':'pending; confirm scale/materials after base map handoff'},indent=2),encoding='utf-8')
bpy.ops.wm.open_mainfile(filepath=str(out/'cinder-props.blend'))
for name,color in [('Preview_Plinth',(.075,.087,.105,1)),('Preview_Text',(.84,.84,.79,1)),('Preview_Floor',(.035,.043,.06,1))]:
    mat=bpy.data.materials[name]
    mat.use_nodes=True
    mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=color
    mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.8
scene=bpy.context.scene
scene.camera.location=(6,-39,48)
scene.camera.rotation_euler=(Vector((0,0,1))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(out/'cinder-props.blend'))
bpy.ops.render.render(write_still=True)
print('VERIFIED',len(results),'FBX assets; total triangles',sum(r['triangles'] for r in results))

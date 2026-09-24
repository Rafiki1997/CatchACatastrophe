"""Bundle the nine gallery meshes for one Studio 3D Importer operation."""
import bpy
from pathlib import Path

folder=Path(__file__).resolve().parents[2]/'assets/cinder-canyon/props-v1'
bpy.ops.wm.open_mainfile(filepath=str(folder/'cinder-props.blend'))
bpy.ops.object.select_all(action='DESELECT')
for obj in bpy.data.collections['EXPORT_ASSETS'].objects:
    obj.select_set(True)
bpy.ops.export_scene.fbx(filepath=str(folder/'CinderPropsBundle.fbx'),use_selection=True,
    object_types={'MESH'},axis_forward='-Z',axis_up='Y',global_scale=1,
    apply_unit_scale=False,apply_scale_options='FBX_SCALE_NONE',
    bake_space_transform=False,use_mesh_modifiers=True,mesh_smooth_type='FACE',
    use_triangles=True,path_mode='COPY',embed_textures=True,add_leaf_bones=False,bake_anim=False)

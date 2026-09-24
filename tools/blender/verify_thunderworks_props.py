"""Reimport production FBXs and verify the Claude handoff envelopes."""
import json
import math
from pathlib import Path

import bpy
import bmesh

folder = Path(__file__).resolve().parents[2] / 'assets/thunderworks/props-v1'
manifest = json.loads((folder / 'manifest.json').read_text())
expected = {
    'TW_Transformer': (5.8, 6.2, 4.6),
    'TW_Ceramic_Insulator': (1.8, 3.0, 1.8),
    'TW_Cable_Reel': (4.0, 4.4, 3.0),
    'TW_Capacitor_Bank': (3.4, 4.8, 3.4),
    'TW_Switch_Cabinet': (3.2, 4.6, 1.8),
    'TW_Vent_Housing': (4.0, 2.4, 3.4),
    'TW_Conduit_Elbow': (3.0, 2.5, 2.2),
    'TW_Storm_Bollard': (1.2, 3.0, 1.2),
}
assert {a['name'] for a in manifest['assets']} == set(expected)
results = []
for asset in manifest['assets']:
    name = asset['name']
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(folder / asset['file']))
    objects = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    assert len(objects) == 1, name
    obj = objects[0]
    obj.data.calc_loop_triangles()
    x, y, z = obj.dimensions
    dims = (x, z, y)
    assert max(abs(a-b) for a, b in zip(dims, expected[name])) < .005, (name, dims)
    assert max(abs(a-b) for a, b in zip(dims, asset['dimensions_studs_xyz'])) < .005
    assert obj.location.length < 1e-5, name
    vertices = [obj.matrix_world @ v.co for v in obj.data.vertices]
    assert all(math.isfinite(c) for v in vertices for c in v), name
    assert abs(min(v.z for v in vertices)) < 1e-4, name
    assert abs(min(v.x for v in vertices)+max(v.x for v in vertices)) < 1e-4, name
    assert abs(min(v.y for v in vertices)+max(v.y for v in vertices)) < 1e-4, name
    assert len(obj.data.loop_triangles) == asset['triangles'], name
    assert len(obj.data.materials) == 1 and len(obj.data.uv_layers) == 1, name
    for uv in obj.data.uv_layers[0].data:
        assert abs(uv.uv.y-.5) < 1e-5
        assert abs((uv.uv.x*32-.5)-round(uv.uv.x*32-.5)) < 1e-4
    images = [n.image for n in obj.data.materials[0].node_tree.nodes if n.type == 'TEX_IMAGE' and n.image]
    assert len(images) == 1 and tuple(images[0].size) == (512, 16), name
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bad = sum(not e.is_manifold for e in bm.edges)
    bm.free()
    assert bad == 0 and all(p.area > 1e-9 for p in obj.data.polygons), name
    results.append({'name': name, 'roundtrip': 'pass', 'dimensions_studs_xyz': list(dims),
                    'triangles': asset['triangles'], 'nonmanifold_edges': bad})

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(folder / 'ThunderworksPropsBundle.fbx'))
objects = [o for o in bpy.context.scene.objects if o.type == 'MESH']
assert len(objects) == 8 and {o.name for o in objects} == set(expected)
assert len(bpy.context.scene.objects) == 8, 'preview geometry exported into bundle'
for obj in objects:
    x, y, z = obj.dimensions
    assert max(abs(a-b) for a, b in zip((x,z,y), expected[obj.name])) < .005, obj.name
report = {'fbx_roundtrip': results, 'bundle_mesh_count': 8,
          'total_triangles': sum(a['triangles'] for a in manifest['assets']),
          'studio_import': 'Not imported; awaits Claude base layout and native-template integration.'}
(folder / 'validation.json').write_text(json.dumps(report, indent=2))
print('VERIFIED', len(results), 'Thunderworks meshes and bundle;', report['total_triangles'], 'triangles')

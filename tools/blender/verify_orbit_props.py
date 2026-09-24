"""Independent FBX round-trip verification; does not touch Studio."""
import json
import math
from pathlib import Path
import bpy
import bmesh

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/"assets/orbit-outpost/props-v1"
contract = json.loads((OUT/"asset-contract.json").read_text())
expected = {a["name"]: a["dimensions_studs_xyz"] for a in contract["assets"]}
manifest = json.loads((OUT/"manifest.json").read_text())
assert len(expected) == 15
assert len(manifest["assets"]) == len(expected)
assert {a["name"] for a in manifest["assets"]} == set(expected)
results = []

for asset in manifest["assets"]:
    name = asset["name"]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(OUT/asset["file"]))
    objects = list(bpy.context.scene.objects)
    assert len(objects) == 1 and objects[0].type == "MESH", (name, "extra objects")
    obj = objects[0]
    obj.data.calc_loop_triangles()
    x, y, z = obj.dimensions
    actual = (x, z, y)
    assert max(abs(a-b) for a,b in zip(actual,expected[name])) < .005, (name,actual)
    assert max(abs(a-b) for a,b in zip(actual,asset["dimensions_studs_xyz"])) < .005
    assert obj.location.length < 1e-5, name
    assert max(abs(s-1) for s in obj.scale) < 1e-5, name
    verts = [obj.matrix_world@v.co for v in obj.data.vertices]
    assert all(math.isfinite(c) for v in verts for c in v), name
    assert abs(min(v.z for v in verts)) < 1e-4, (name,"bottom origin")
    for axis in (0,1):
        assert abs(min(v[axis] for v in verts)+max(v[axis] for v in verts)) < 1e-4, name
    assert len(obj.data.loop_triangles) == asset["triangles"], name
    assert 0 < asset["triangles"] < 10000, name
    assert len(obj.data.materials) == 1 and len(obj.data.uv_layers) == 1, name
    for uv in obj.data.uv_layers[0].data:
        assert abs(uv.uv.y-.5) < 1e-5, name
        assert abs((uv.uv.x*32-.5)-round(uv.uv.x*32-.5)) < 1e-4, name
    images = [n.image for n in obj.data.materials[0].node_tree.nodes if n.type == "TEX_IMAGE" and n.image]
    assert len(images) == 1 and tuple(images[0].size) == (512,16), name
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bad = sum(not e.is_manifold for e in bm.edges)
    bm.free()
    assert bad == 0 and all(p.area > 1e-9 for p in obj.data.polygons), name
    results.append({"name":name, "fbx_roundtrip":"pass", "dimensions_studs_xyz":list(actual),
                    "triangles":asset["triangles"], "nonmanifold_edges":bad})

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(OUT/"OrbitPropsBundle.fbx"))
objects = list(bpy.context.scene.objects)
assert len(objects) == 15 and all(o.type == "MESH" for o in objects)
assert {o.name for o in objects} == set(expected), "Preview geometry leaked into bundle"
for obj in objects:
    x,y,z = obj.dimensions
    assert max(abs(a-b) for a,b in zip((x,z,y),expected[obj.name])) < .005
# Reopen editable production blend: full size originals and separate presentation.
bpy.ops.wm.open_mainfile(filepath=str(OUT/"props.blend"))
production = list(bpy.data.collections["EXPORT_ASSETS"].objects)
assert len(production) == 15 and {o.name for o in production} == set(expected)
assert bpy.data.collections.get("PREVIEW_ONLY") is not None
for obj in production:
    assert all(abs(v-1) < 1e-6 for v in obj.scale), obj.name
    x,y,z = obj.dimensions
    assert max(abs(a-b) for a,b in zip((x,z,y),expected[obj.name])) < .005, obj.name

report = {"assets":results, "bundle_mesh_count":15,
          "total_triangles":sum(a["triangles"] for a in manifest["assets"]),
          "editable_blend":"pass", "preview_in_bundle":False,
          "studio_import":"Not uploaded or imported. Await Claude layout and Codex staging.",
          "limitations":["Disconnected overlapping closed components are intentional decorative art.",
                         "Mesh collision is not authored; use separate Roblox proxies.",
                         "Palette colors do not imply emissive or transparent Roblox materials."]}
(OUT/"validation.json").write_text(json.dumps(report,indent=2))
print("ORBIT_VERIFIED",len(results),"meshes;",report["total_triangles"],"triangles")


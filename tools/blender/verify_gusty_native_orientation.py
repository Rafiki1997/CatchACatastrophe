import bpy,json
from pathlib import Path
from mathutils import Vector,kdtree
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/gusty-gardens/broadleaf-family-v1/roblox'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'GustyBroadleafRoblox.blend'))
manifest=json.loads((OUT/'manifest.json').read_text())
native=json.loads((OUT/'native-vertex-samples.json').read_text())
scale=float(json.loads((OUT/'roblox-import.json').read_text())['importScale'])
results=[]
for a in manifest['assets']:
    o=bpy.data.objects[a['name']]; center=Vector(a['center'])
    kd=kdtree.KDTree(len(o.data.vertices))
    for i,v in enumerate(o.data.vertices):kd.insert(Vector((v.co.x,v.co.z,-v.co.y))-center,i)
    kd.balance(); errors={}
    for yaw in [0,180]:
        sign=1 if yaw==0 else -1; values=[]
        for point in native[a['name']]['points']:
            v=Vector((point[0]*sign,point[1],point[2]*sign))/scale
            values.append(kd.find(v)[2])
        errors[str(yaw)]={'max':max(values),'mean':sum(values)/len(values)}
    best=min(errors,key=lambda k:errors[k]['max'])
    assert errors[best]['max']<.001,(a['name'],errors)
    results.append({'name':a['name'],'correction_yaw_degrees':int(best),'errors_studs':errors,'samples':len(native[a['name']]['points'])})
assert len({r['correction_yaw_degrees'] for r in results})==1
(OUT/'native-orientation-validation.json').write_text(json.dumps({'status':'passed','method':'Nearest exported vertex for 180+ actual uploaded-mesh vertex samples per component, at the measured native import scale','components':results},indent=2))
print('NATIVE_ORIENTATION_VALIDATED',json.dumps(results),flush=True)

# Render Thunderworks kit assets one at a time, each on a shadow catcher
# beside a 5-stud avatar for scale, and write its measured size to JSON.
#
#   blender -b --factory-startup -P render_asset.py -- --out DIR [--only a,b] [--samples N] [--res 0.5]
#
# One image per asset: DIR/<id>.png (transparent, for compose_assets.py) and
# DIR/<id>.json (title, blurb, options, measured W x D x H in studs).
import os
import sys
import json
import math
import time
import argparse

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402
import tw_lib as L  # noqa: E402
import tw_geo as G  # noqa: E402
import tw_base as B  # noqa: E402
import tw_kit as K  # noqa: E402
from tw_lib import rgb  # noqa: E402


def avatar(c, x, y, mat_body, mat_limb):
    """A blocky 5-stud avatar standing at (x, y), facing -Y (the camera)."""
    bm = L.new_bm()
    L.add_box(bm, (0.95, 1.0, 2.0), (-0.52, 0, 1.0), mi=1, bevel=0.05)
    L.add_box(bm, (0.95, 1.0, 2.0), (0.52, 0, 1.0), mi=1, bevel=0.05)
    L.add_box(bm, (2.0, 1.0, 2.0), (0, 0, 3.0), mi=0, bevel=0.06)
    L.add_box(bm, (0.95, 1.0, 2.0), (-1.5, 0, 3.0), mi=1, bevel=0.05)
    L.add_box(bm, (0.95, 1.0, 2.0), (1.5, 0, 3.0), mi=1, bevel=0.05)
    L.add_cyl(bm, 0.62, 0.62, 1.2, (0, 0, 4.6), segs=20, mi=0, bevel=0.12, seg=2)
    return L.obj_from_bm("ScaleAvatar", bm, [mat_body, mat_limb], c, loc=(x, y, 0), solid=False)


def world_bounds(obs):
    dg = bpy.context.evaluated_depsgraph_get()
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for ob in obs:
        ev = ob.evaluated_get(dg)
        me = ev.to_mesh()
        M = ob.matrix_world
        for v in me.vertices:
            w = M @ v.co
            lo = Vector((min(lo.x, w.x), min(lo.y, w.y), min(lo.z, w.z)))
            hi = Vector((max(hi.x, w.x), max(hi.y, w.y), max(hi.z, w.z)))
        ev.to_mesh_clear()
    return lo, hi


def fit_camera(lo, hi, az_deg=36.0, el_deg=24.0, lens=85.0, aspect=4 / 3, margin=0.86):
    """Aim a perspective camera from the front-right at the box lo..hi and
    back off until all eight corners sit inside the frame."""
    sc = bpy.context.scene
    cd = bpy.data.cameras.new("Cam")
    cd.sensor_fit = 'HORIZONTAL'
    cd.sensor_width = 36.0
    cd.lens = lens
    cd.clip_start = 0.5
    cd.clip_end = 5000.0
    cam = bpy.data.objects.new("Cam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    az, el = math.radians(az_deg), math.radians(el_deg)
    d = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))
    T = (lo + hi) / 2
    f = -d
    r = f.cross(Vector((0, 0, 1))).normalized()
    u = r.cross(f).normalized()
    tx = math.tan(math.atan(18.0 / lens)) * margin
    ty = tx / aspect
    D = 1.0
    for cx in (lo.x, hi.x):
        for cy in (lo.y, hi.y):
            for cz in (lo.z, hi.z):
                p = Vector((cx, cy, cz)) - T
                depth_off = p.dot(f)
                D = max(D, abs(p.dot(r)) / tx - depth_off, abs(p.dot(u)) / ty - depth_off)
    cam.location = T + d * D
    cam.rotation_euler = f.to_track_quat('-Z', 'Y').to_euler()
    return cam


def render_one(aid, title, fn, blurb, used, out_dir, samples, res):
    B.reset_scene()
    sc = B.setup_render(samples=samples, res_scale=res, width=1600, height=1200, exposure=-0.1)
    B.setup_world(sky=(0.66, 0.70, 0.78), strength=0.62)
    B.setup_sun(direction=(0.42, 0.5, -0.76), energy=4.4, angle=6.0, color=(1.0, 0.95, 0.88))
    T = G.TWMats()
    # on the pale card ground a white-hot arc disappears: keep it blue
    T.arc = L.mat("tw_arc_card", rgb(96, 150, 255), emit=5.0, emit_color=rgb(96, 150, 255))
    c = L.coll("Asset")
    me, info = fn(T)
    ob = L.place(me, aid, c, (0, 0, 0))
    bpy.context.view_layer.update()
    lo, hi = world_bounds([ob])
    size = hi - lo
    # the avatar stands just off the asset's right front corner
    grey = L.mat("avatar_body", rgb(150, 156, 166), rough=0.6)
    grey2 = L.mat("avatar_limb", rgb(118, 124, 134), rough=0.6)
    av = avatar(c, lo.x - 3.0, lo.y + min(3.0, size.y * 0.3), grey, grey2)
    fx = K.FX.get(aid)
    if fx:
        fx(T, c, info)
    # shadow catcher
    bpy.ops.mesh.primitive_plane_add(size=max(400.0, size.length * 6), location=(0, 0, 0))
    pl = bpy.context.active_object
    pl.is_shadow_catcher = True
    bpy.context.view_layer.update()
    lo2, hi2 = world_bounds([ob, av])
    el = 22.0 if size.z > max(size.x, size.y) * 1.4 else 28.0
    fit_camera(lo2, hi2, az_deg=34.0, el_deg=el)
    sc.render.filepath = os.path.join(out_dir, aid + ".png")
    t0 = time.time()
    bpy.ops.render.render(write_still=True)
    meta = {"id": aid, "title": title, "blurb": blurb, "options": used,
            "size_wdh": [round(size.x, 1), round(size.y, 1), round(size.z, 1)],
            "render_s": round(time.time() - t0, 1)}
    with open(os.path.join(out_dir, aid + ".json"), "w") as f:
        json.dump(meta, f, indent=2)
    print("ASSET", json.dumps(meta))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--only", default="")
    ap.add_argument("--samples", type=int, default=128)
    ap.add_argument("--res", type=float, default=1.0)
    a = ap.parse_args(argv)
    os.makedirs(a.out, exist_ok=True)
    only = set(x for x in a.only.split(",") if x)
    for aid, title, fn, blurb, used in K.ASSETS:
        if only and aid not in only:
            continue
        render_one(aid, title, fn, blurb, used, a.out, a.samples, a.res)


main()

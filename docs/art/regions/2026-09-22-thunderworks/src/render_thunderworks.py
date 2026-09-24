# Build and render one Thunderworks mockup option.
#
#   blender -b --factory-startup -P render_thunderworks.py -- --option 1 --out o1.png
#
# Options: --samples N, --res 0.5 (preview scale), --blend path (save the
# scene), --stats path (clear-floor measurement as JSON), --camera top (a
# straight-down plan of the same scene), --noscene (base only).
import os
import sys
import json
import time
import random
import argparse

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import bpy  # noqa: E402
import tw_lib as L  # noqa: E402
import tw_geo as G  # noqa: E402
import tw_base as B  # noqa: E402
import tw_designs as O  # noqa: E402
from tw_lib import rgb  # noqa: E402


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--option", type=int, default=1)
    ap.add_argument("--out", required=True)
    ap.add_argument("--samples", type=int, default=160)
    ap.add_argument("--res", type=float, default=1.0)
    ap.add_argument("--blend", default=None)
    ap.add_argument("--stats", default=None)
    ap.add_argument("--camera", default="concept")
    ap.add_argument("--pitch", type=float, default=45.0)
    ap.add_argument("--noscene", action="store_true")
    ap.add_argument("--sun", default=None, help="light travel direction x,y,z")
    ap.add_argument("--sunE", type=float, default=None)
    ap.add_argument("--world", type=float, default=None)
    ap.add_argument("--exposure", type=float, default=None)
    a = ap.parse_args(argv)

    t0 = time.time()
    B.reset_scene()
    B.setup_render(samples=a.samples, res_scale=a.res, exposure=a.exposure if a.exposure is not None else 0.25)
    num, title, slug, fn = O.OPTIONS[a.option]
    B.setup_world(strength=a.world if a.world is not None else 0.5)
    sk = {"energy": 8.5}
    if a.sun:
        sk["direction"] = tuple(float(v) for v in a.sun.split(","))
    if a.sunE is not None:
        sk["energy"] = a.sunE
    B.setup_sun(**sk)
    if a.camera == "top":
        B.setup_camera(pitch=90.0, target=(0.0, 5.0, 0.0), dist=2000.0, ortho=372.0)
    else:
        B.setup_camera(pitch=a.pitch, lens=200.0, target=(0.0, -8.0, 0.0), dist=1950.0)

    T = G.TWMats()
    bm_ = B.BaseMats()
    font = bpy.data.fonts.load(B.FONT_PATH)
    c_base = L.coll("Base")
    c_scen = L.coll("Scenery")
    c_crit = L.coll("Creatures")
    floor = G.yard_floor_mat("yard_floor", rgb(78, 84, 99), rgb(88, 94, 110), rgb(112, 118, 130), rgb(62, 67, 80))
    heath = G.moor_mat("heath", rgb(92, 112, 80), rgb(112, 124, 90))
    B.build_ground(bm_, c_base, floor, heath)
    B.build_walls(bm_, c_base, font)
    B.build_neighbours(bm_, T, c_base)
    B.build_flanks(T, c_base)

    info = {}
    if not a.noscene:
        rng = random.Random(1000 + a.option)
        ctx = O.Ctx(T, c_scen, rng)
        info = fn(ctx) or {}
        ctx.finish()
        B.field_marks(T, c_scen, random.Random(77 + a.option))
        B.build_creatures(c_crit)
    t1 = time.time()
    stats = B.clear_floor_stats()
    stats.update({"option": num, "title": title, "slug": slug, "build_s": round(t1 - t0, 1)})
    stats.update(info)
    print("STATS", json.dumps(stats))
    if a.stats:
        with open(a.stats, "w") as f:
            json.dump(stats, f, indent=2)
    if a.blend:
        bpy.ops.wm.save_as_mainfile(filepath=a.blend)
    sc = bpy.context.scene
    sc.render.filepath = a.out
    bpy.ops.render.render(write_still=True)
    print("RENDERED", a.out, "objects", len(sc.objects), "render_s", round(time.time() - t1, 1))


main()

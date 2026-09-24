# Build and render one Frostbite Peaks mockup option.
#
#   blender -b --factory-startup -P render_frostbite.py -- --option 1 --out o1.png
#
# Options: --samples N, --res 0.5 (preview scale), --blend path (save the
# scene), --stats path (clear-floor measurement as JSON), --camera top (a
# straight-down plan view of the same scene).
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
import fb_lib as L  # noqa: E402
import fb_base as B  # noqa: E402
import fb_designs as O  # noqa: E402
from fb_lib import rgb  # noqa: E402


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
    ap.add_argument("--shift", type=float, default=0.0)
    ap.add_argument("--noscene", action="store_true", help="base only, no option scenery")
    ap.add_argument("--sun", default=None, help="light travel direction x,y,z")
    ap.add_argument("--sunE", type=float, default=None)
    ap.add_argument("--world", type=float, default=None)
    ap.add_argument("--exposure", type=float, default=None)
    a = ap.parse_args(argv)

    t0 = time.time()
    B.reset_scene()
    B.setup_render(samples=a.samples, res_scale=a.res, exposure=a.exposure if a.exposure is not None else -0.25)
    spec = O.OPTIONS[a.option]
    num, title, slug, fn = spec[:4]
    look = spec[4] if len(spec) > 4 else {}
    wk = dict(look.get("world", {}))
    if a.world is not None:
        wk["strength"] = a.world
    B.setup_world(**wk)
    sk = dict(look.get("sun", {}))
    if a.sun:
        sk["direction"] = tuple(float(v) for v in a.sun.split(","))
    if a.sunE is not None:
        sk["energy"] = a.sunE
    B.setup_sun(**sk)
    if a.camera == "top":
        B.setup_camera(pitch=90.0, target=(0.0, 5.0, 0.0), dist=2000.0, ortho=372.0)
    else:
        B.setup_camera(pitch=a.pitch, lens=200.0, target=(0.0, -8.0, 0.0), dist=1950.0, shift_y=a.shift)

    k = L.Kit(look.get("palette"))
    bm_ = B.BaseMats()
    font = bpy.data.fonts.load(B.FONT_PATH)
    c_base = L.coll("Base")
    c_scen = L.coll("Scenery")
    c_crit = L.coll("Creatures")
    g = look.get("ground", {})
    field = B.snow_ground_mat("field",
                              g.get("field", rgb(194, 211, 235)),
                              g.get("patch", rgb(212, 225, 243)),
                              g.get("lane", rgb(176, 196, 226)),
                              streak_color=g.get("streak", rgb(226, 236, 248)))
    outer = L.mat("outer_snow", g.get("outer", rgb(226, 234, 243)), rough=0.8, jitter=0.02)
    B.build_ground(k, bm_, c_base, field, outer)
    B.build_walls(k, bm_, c_base, font)
    B.build_neighbours(k, bm_, c_base)
    flank_pines = O.make_pines(k, 900)
    B.build_flanks(k, c_base, flank_pines, rock_mat=k.rock)

    info = {}
    if not a.noscene:
        rng = random.Random(1000 + a.option)
        info = fn(k, c_scen, rng) or {}
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

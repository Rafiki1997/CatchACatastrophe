# Project the layout (region-local) back onto V2 through the comparison
# camera: footprints as wire boxes at their real heights. A reading error
# shows up as a box that does not sit on the thing it was read from.
import math, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import refcam as RC
import layout as Lo

V2 = "C:/Users/nguye/Documents/repos/catch-a-catastrophe/CatchACatastrophe/docs/art/regions/2026-09-22-frostbite-peaks/frostbite-peaks-v2-02-alpine-outpost-refined.png"
out = sys.argv[1] if len(sys.argv) > 1 else 'layout_on_v2.png'
im = Image.open(V2).convert('RGB')
d = ImageDraw.Draw(im, 'RGBA')
f = ImageFont.load_default()


def P(x, z, y):
    # local (x west, z north, y up) -> scene (X east, Y north, Z up)
    return RC.project([[-x, z, y]])[0]


def box(cx, cz, w, dd, h0, h1, yaw=0.0, col=(255, 0, 0, 255), label=None, width=1):
    a = math.radians(yaw)
    c, s = math.cos(a), math.sin(a)
    corners = []
    for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        lx, lz = sx * w / 2, sz * dd / 2
        corners.append((cx + lx * c + lz * s, cz - lx * s + lz * c))
    lo = [P(x, z, h0) for x, z in corners]
    hi = [P(x, z, h1) for x, z in corners]
    for ring in (lo, hi):
        d.line([tuple(p) for p in ring + [ring[0]]], fill=col, width=width)
    for p, q in zip(lo, hi):
        d.line([tuple(p), tuple(q)], fill=col, width=width)
    if label:
        q = P(cx, cz, h1)
        d.text((q[0] + 2, q[1] - 10), label, fill=col, font=f)


def rect(x0, x1, z0, z1, h0, h1, **k):
    box((x0 + x1) / 2, (z0 + z1) / 2, abs(x1 - x0), abs(z1 - z0), h0, h1, **k)


A = Lo.ASSETS
T = Lo.TERRACE
rect(T['x0'], T['x1'], T['z0'], T['z1'], 0, Lo.T_TOP, col=(255, 140, 0, 255), label='terrace')
st = Lo.TERRACE_STAIR
rect(st['x0'], st['x1'], st['top_z'] - st['risers'] * st['tread'], st['top_z'], 0, Lo.T_TOP, col=(255, 255, 0, 255))
w, h, dd = A['FA_Lodge']
box(Lo.LODGE['x'], Lo.LODGE['z'], w, dd, Lo.T_TOP, Lo.T_TOP + h, col=(255, 0, 0, 255), label='lodge', width=2)
for k in ('SHELF_C', 'SHELF_A', 'SHELF_B'):
    s = getattr(Lo, k)
    rect(s['x0'], s['x1'], s['z0'], s['z1'], 0, Lo.S_TOP, col=(0, 255, 255, 255), label=k[-1])
bs = Lo.B_STAIR
rect(bs['x0'], bs['x1'], bs['top_z'] - (bs['risers'] - 1) * bs['tread'], bs['top_z'], 0, Lo.S_TOP, col=(255, 255, 0, 255))
n, s = Lo.BRIDGE['n'], Lo.BRIDGE['s']
yaw = math.degrees(math.atan2(n[0] - s[0], n[1] - s[1]))
box((n[0] + s[0]) / 2, (n[1] + s[1]) / 2, A['FA_Rope_Bridge'][0], math.hypot(n[0] - s[0], n[1] - s[1]), Lo.S_TOP - 1.5, Lo.S_TOP + 6,
    yaw=yaw, col=(255, 0, 255, 255), label='bridge', width=2)
g = Lo.GORGE_ROCK
box(g['x'], g['z'], *(A['FA_Gorge_Rock'][i] for i in (0, 2)), 0, A['FA_Gorge_Rock'][1], col=(120, 120, 255, 255))
for x0, x1, z0, z1 in Lo.CREEK:
    rect(x0, x1, z0, z1, 0, 0.1, col=(0, 120, 255, 255))
for asset, x, z, yaw_, sc in Lo.CLIFFS:
    w, h, dd = (v * sc for v in A[asset])
    box(x, z, w, dd, 0, h, yaw=yaw_, col=(160, 60, 255, 255), label=asset[8:])
for asset, x, z, yaw_, sc in Lo.BOULDERS:
    w, h, dd = (v * sc for v in A[asset])
    box(x, z, w, dd, 0, h, yaw=yaw_, col=(200, 100, 255, 255))
for asset, x, z, hb, sc in Lo.FIRS:
    w, h, dd = (v * sc for v in A[asset])
    box(x, z, w * 0.5, dd * 0.5, hb, hb + h, col=(0, 200, 0, 255))
for asset, x, z, yaw_, hb, sc in Lo.CAMP:
    w, h, dd = (v * sc for v in A[asset])
    box(x, z, w, dd, hb, hb + h, yaw=yaw_, col=(255, 90, 90, 255))
for asset, x, z in Lo.PLANTS:
    w, h, dd = A[asset]
    box(x, z, w, dd, 0, h, col=(255, 200, 0, 255))
for x, z in Lo.LANE_STAKES:
    box(x, z, 0.8, 0.8, 0, 3.2, col=(255, 255, 255, 255))
for x, z, w, dd, yaw_ in Lo.FIELD_ICE:
    box(x, z, w, dd, 0, 0.05, yaw=yaw_, col=(0, 160, 255, 255))
for x, z, a, sc in Lo.FLANK:
    w, h, dd = (v * sc for v in A[a])
    box(x, z, w * 0.5, dd * 0.5, 0, h, col=(0, 140, 0, 255))
im.save(out)
print('saved', out)

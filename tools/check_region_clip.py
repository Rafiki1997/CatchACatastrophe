# -*- coding: utf-8 -*-
"""Does any region prop poke through a wall it should stop at?"""
import json, numpy as np, collections, sys
SP = ("C:/Users/rahul/AppData/Local/Temp/claude/"
      "C--Users-rahul-orca-workspaces-Catch-a-Catastrophe-Catch-A-Catastrophe/"
      "77e9e04c-32f9-48e4-b919-475be3872834/scratchpad/world/")
dump = sys.argv[1] if len(sys.argv) > 1 else SP + "map-v2.json"
CELL_D = float(sys.argv[2]) if len(sys.argv) > 2 else 180.0
parts = json.load(open(dump, encoding="utf-8"))
CHAIN_Z0, HALF, GATE = -215.0, 140.0, 22.0
NREG = 6
dividers = [CHAIN_Z0 - k * CELL_D for k in range(1, NREG)]
zmin, zmax = CHAIN_Z0 - CELL_D * NREG, CHAIN_Z0
SKIP_PATH = {"RegionWalls", "ChainFlanks", "IslandRim", "Landscape"}
# The barrier and its dressing live in the divider plane on purpose.
SKIP_NAME = {"Ground", "Ambience", "Trail", "TrailKerb", "ChainApron", "Causeway",
             "Gate", "GateRail", "GatePost", "GateDiagonal",
             "LockBadge", "LockRim", "LockBody", "LockShackle", "LockKeyhole"}

def aabb(p):
    c = p["cf"]; pos = np.array(c[0:3])
    R = np.array([[c[3],c[4],c[5]],[c[6],c[7],c[8]],[c[9],c[10],c[11]]])
    s = np.array(p["size"]) / 2
    pts = np.array([pos + R@(s*np.array([sx,sy,sz]))
                    for sx in(-1,1) for sy in(-1,1) for sz in(-1,1)])
    return pts.min(axis=0), pts.max(axis=0)

hitsD, hitsL = collections.Counter(), collections.Counter()
worstD, worstL = {}, {}
for p in parts:
    if p["path"] in SKIP_PATH or p["name"] in SKIP_NAME or p["transparency"] >= 0.95:
        continue
    mn, mx = aabb(p)
    if mx[1] < 0.2 or mn[2] > zmax or mx[2] < zmin:
        continue
    for z in dividers:
        if mn[2] < z + 1.5 and mx[2] > z - 1.5 and not (mx[0] < GATE and mn[0] > -GATE):
            hitsD[p["name"]] += 1
            pen = min(mx[2], z + 1.5) - max(mn[2], z - 1.5)
            worstD[p["name"]] = max(worstD.get(p["name"], 0), pen)
    for x in (-HALF, HALF):
        if mn[0] < x + 1.5 and mx[0] > x - 1.5:
            hitsL[p["name"]] += 1
            pen = min(mx[0], x + 1.5) - max(mn[0], x - 1.5)
            worstL[p["name"]] = max(worstL.get(p["name"], 0), pen)

print("CELL_D", CELL_D, "| divider crossings:", sum(hitsD.values()), "| lateral crossings:", sum(hitsL.values()))
for title, h, w in (("DIVIDER", hitsD, worstD), ("LATERAL", hitsL, worstL)):
    for n, c in h.most_common(8):
        print(f"   {title} {n:22s} x{c:3d}  worst {w[n]:5.1f}")

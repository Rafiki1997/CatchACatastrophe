# -*- coding: utf-8 -*-
"""Perspective render of a PlotTemplate part dump, from the concept's camera.

python render3d.py dump.json out.png [--pitch 38] [--yaw 0] [--dist 95] [--fov 38] [--w 1536] [--h 1024]

Rasterises Block / Ball / Cylinder / Wedge parts with a z-buffer and flat sun
shading, so the built plot can be put side by side with the concept image.
The camera sits in front of the plot (local -Z) looking in: +X renders on the
LEFT, which is how a player entering from the driveway sees it.
"""
import json
import math
import sys

import numpy as np
from PIL import Image

AMBIENT = 0.52
# Lit from the south-west and above, which is where Roblox puts the sun at
# this place's ClockTime 15.1. The old key came from the north, so every
# south-facing surface -- windmill sails, doors, gate signs -- rendered
# unlit and the comparison lied about them.
SUN = np.array([0.46, 0.78, 0.43])
SUN = SUN / np.linalg.norm(SUN)
SKY = np.array([0.62, 0.72, 0.88])
GRASS = (118, 152, 86)


# ------------------------------------------------------------------ geometry
def block_faces():
    v = [(-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1),
         (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)]
    quads = [(0, 1, 2, 3), (5, 4, 7, 6), (4, 0, 3, 7), (1, 5, 6, 2), (3, 2, 6, 7), (4, 5, 1, 0)]
    out = []
    for a, b, c, d in quads:
        out.append((v[a], v[b], v[c]))
        out.append((v[a], v[c], v[d]))
    return [tuple(np.array(p, dtype=float) * 0.5 for p in t) for t in out]


BLOCK = block_faces()


def ball_tris(seg=14, ring=9):
    pts = {}
    for i in range(ring + 1):
        phi = math.pi * i / ring
        for j in range(seg):
            th = 2 * math.pi * j / seg
            pts[(i, j)] = np.array([math.sin(phi) * math.cos(th), math.cos(phi), math.sin(phi) * math.sin(th)]) * 0.5
    out = []
    for i in range(ring):
        for j in range(seg):
            j2 = (j + 1) % seg
            a, b, c, d = pts[(i, j)], pts[(i, j2)], pts[(i + 1, j2)], pts[(i + 1, j)]
            out.append((a, b, c))
            out.append((a, c, d))
    return out


BALL = ball_tris()


def cyl_tris(seg=20):
    # axis along local X, like Roblox cylinders
    out = []
    ring = []
    for j in range(seg):
        th = 2 * math.pi * j / seg
        ring.append((math.cos(th) * 0.5, math.sin(th) * 0.5))
    for j in range(seg):
        y0, z0 = ring[j]
        y1, z1 = ring[(j + 1) % seg]
        a = np.array([-0.5, y0, z0]); b = np.array([-0.5, y1, z1])
        c = np.array([0.5, y1, z1]); d = np.array([0.5, y0, z0])
        out.append((a, b, c)); out.append((a, c, d))
    for sx, order in ((0.5, 1), (-0.5, -1)):
        centre = np.array([sx, 0.0, 0.0])
        for j in range(seg):
            y0, z0 = ring[j]
            y1, z1 = ring[(j + 1) % seg]
            a = np.array([sx, y0, z0]); b = np.array([sx, y1, z1])
            out.append((centre, a, b) if order > 0 else (centre, b, a))
    return out


CYL = cyl_tris()
# A SpecialMesh cylinder stands on Y, unlike a Cylinder part, which lies on X.
CYL_Y = [tuple(np.array([v[1], v[0], v[2]]) for v in t) for t in CYL]


def wedge_tris():
    # Roblox wedge: full-height face at +Z, sloping down toward -Z
    p = {
        "a": np.array([-0.5, -0.5, -0.5]), "b": np.array([0.5, -0.5, -0.5]),
        "c": np.array([0.5, -0.5, 0.5]), "d": np.array([-0.5, -0.5, 0.5]),
        "e": np.array([0.5, 0.5, 0.5]), "f": np.array([-0.5, 0.5, 0.5]),
    }
    out = [
        (p["a"], p["c"], p["b"]), (p["a"], p["d"], p["c"]),   # bottom
        (p["d"], p["f"], p["e"]), (p["d"], p["e"], p["c"]),   # back
        (p["a"], p["b"], p["e"]), (p["a"], p["e"], p["f"]),   # slope
        (p["b"], p["c"], p["e"]), (p["a"], p["f"], p["d"]),   # sides
    ]
    return out


WEDGE = wedge_tris()


def part_tris(p):
    shape = p.get("shape", "Block")
    s = np.array(p["size"], dtype=float)
    mesh = p.get("mesh")
    if mesh:
        # A SpecialMesh overrides the part's own shape and scales it. Sphere is
        # the one that matters here: flat decorative pools are cubes wearing one.
        kind = mesh.get("kind", "Brick")
        s = s * np.array(mesh.get("scale", [1, 1, 1]), dtype=float)
        shape = {"Sphere": "Ball", "Head": "Ball", "Cylinder": "MeshCylinder",
                 "Wedge": "Wedge", "Brick": "Block"}.get(kind, "Block")
    proto = BLOCK
    if shape == "Ball":
        proto = BALL
    elif shape == "Cylinder":
        proto = CYL
    elif shape == "MeshCylinder":
        proto = CYL_Y
    elif shape == "Wedge":
        proto = WEDGE
    cf = p["cf"]
    pos = np.array(cf[0:3], dtype=float)
    R = np.array([[cf[3], cf[4], cf[5]], [cf[6], cf[7], cf[8]], [cf[9], cf[10], cf[11]]], dtype=float)
    out = []
    for t in proto:
        out.append(tuple(pos + R @ (v * s) for v in t))
    return out


# ------------------------------------------------------------------ renderer
def render(parts, w, h, pitch, yaw, dist, fov, target, extra=()):
    py, pyaw = math.radians(pitch), math.radians(yaw)
    # camera in front of the plot (-Z), raised; looking at `target`
    tgt = np.array(target, dtype=float)
    fwd = np.array([-math.sin(pyaw) * math.cos(py), -math.sin(py), math.cos(pyaw) * math.cos(py)])
    fwd = fwd / np.linalg.norm(fwd)
    eye = tgt - fwd * dist
    up_world = np.array([0.0, 1.0, 0.0])
    right = np.cross(fwd, up_world)
    right = right / np.linalg.norm(right)
    up = np.cross(right, fwd)

    tris, cols = [], []
    for p in parts:
        if p["transparency"] >= 0.92:
            continue
        col = np.array(p["color"], dtype=float)
        if p.get("material") == "Neon":
            col = np.minimum(255.0, col * 1.15 + 30)
        for t in part_tris(p):
            tris.append(t)
            cols.append((col, p.get("material") == "Neon"))
    for t, c in extra:
        tris.append(t)
        cols.append((np.array(c, dtype=float), False))

    n = len(tris)
    V = np.array(tris, dtype=float).reshape(n * 3, 3)
    rel = V - eye
    cx = rel @ right
    cy = rel @ up
    cz = rel @ fwd
    f = (w / 2) / math.tan(math.radians(fov) / 2)
    # right = fwd x up, so for a camera looking along +Z the right vector is -X:
    # plot +X therefore lands on the LEFT of the frame, as a player entering sees it.
    with np.errstate(divide="ignore", invalid="ignore"):
        sx = w / 2 + cx * f / cz
        sy = h / 2 - cy * f / cz
    sx = sx.reshape(n, 3); sy = sy.reshape(n, 3); cz = cz.reshape(n, 3)

    img = np.zeros((h, w, 3), dtype=np.float32)
    img[:, :] = np.array(SKY) * 255
    zbuf = np.full((h, w), np.inf, dtype=np.float32)

    for i in range(n):
        if np.any(cz[i] <= 0.2):
            continue
        x0, x1, x2 = sx[i]; y0, y1, y2 = sy[i]
        minx = int(max(0, math.floor(min(x0, x1, x2))))
        maxx = int(min(w - 1, math.ceil(max(x0, x1, x2))))
        miny = int(max(0, math.floor(min(y0, y1, y2))))
        maxy = int(min(h - 1, math.ceil(max(y0, y1, y2))))
        if minx > maxx or miny > maxy:
            continue
        area = (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0)
        if abs(area) < 1e-9:
            continue
        xs = np.arange(minx, maxx + 1) + 0.5
        ys = np.arange(miny, maxy + 1) + 0.5
        px, py_ = np.meshgrid(xs, ys)
        w0 = ((x1 - x0) * (py_ - y0) - (px - x0) * (y1 - y0)) / area
        w1 = ((px - x0) * (y2 - y0) - (x2 - x0) * (py_ - y0)) / area
        inside = (w0 >= -1e-6) & (w1 >= -1e-6) & (w0 + w1 <= 1 + 1e-6)
        if not inside.any():
            continue
        z0i, z1i, z2i = 1.0 / cz[i]
        zi = z0i + w1 * (z1i - z0i) + w0 * (z2i - z0i)
        depth = 1.0 / np.maximum(zi, 1e-9)
        a, b, c = tris[i]
        nrm = np.cross(b - a, c - a)
        ln = np.linalg.norm(nrm)
        if ln < 1e-12:
            continue
        nrm = nrm / ln
        if nrm @ (a - eye) > 0:
            nrm = -nrm
        col, neon = cols[i]
        lam = max(0.0, float(nrm @ SUN))
        sky = 0.16 * max(0.0, float(nrm[1]))
        shade = AMBIENT + 0.62 * lam + sky
        if neon:
            shade = max(shade, 1.12)
        shaded = np.clip(col * shade, 0, 255)
        sub = zbuf[miny:maxy + 1, minx:maxx + 1]
        mask = inside & (depth < sub)
        if not mask.any():
            continue
        sub[mask] = depth[mask]
        tile = img[miny:maxy + 1, minx:maxx + 1]
        tile[mask] = shaded
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))


def ground_tris(size=150.0, y=0.0):
    a = np.array([-size, y, -size]); b = np.array([size, y, -size])
    c = np.array([size, y, size]); d = np.array([-size, y, size])
    return [((a, b, c), GRASS), ((a, c, d), GRASS)]


def main():
    args = sys.argv[1:]
    dump_path = args[0]
    out_path = args[1]
    opts = {"pitch": 38.0, "yaw": 0.0, "dist": 95.0, "fov": 38.0, "w": 1536, "h": 1024, "ty": 5.0, "tx": 0.0, "tz": 0.0}
    i = 2
    while i < len(args):
        key = args[i].lstrip("-")
        opts[key] = float(args[i + 1])
        i += 2
    dump = json.load(open(dump_path, encoding="utf-8"))
    parts = dump["parts"] if isinstance(dump, dict) else dump
    gsize = opts.get("ground", 0.0)
    extra = ground_tris(size=gsize) if gsize > 0 else ()
    img = render(parts, int(opts["w"]), int(opts["h"]), opts["pitch"], opts["yaw"],
                 opts["dist"], opts["fov"], (opts["tx"], opts["ty"], opts["tz"]), extra=extra)
    img.save(out_path)
    print("rendered", out_path, "parts", len(parts),
          "pitch", opts["pitch"], "yaw", opts["yaw"], "dist", opts["dist"], "fov", opts["fov"])


if __name__ == "__main__":
    main()

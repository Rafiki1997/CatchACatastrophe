# The fitted comparison camera (refcam.json): project scene points to V2
# pixels and intersect pixel rays with horizontal planes. Scene axes X east,
# Y north, Z up; region-local x = -X, z = Y.
import json, numpy as np

_C = json.load(open(__file__.replace('refcam.py', 'refcam.json')))
C = np.array(_C['C']); F = np.array(_C['forward']); U = np.array(_C['up']); R = np.array(_C['right'])
FPX, W, H = _C['fpx'], _C['W'], _C['H']


def project(X):
    d = np.atleast_2d(X) - C
    z = d @ F
    return np.stack([W / 2 + FPX * (d @ R) / z, H / 2 - FPX * (d @ U) / z], 1)


def ray(u, v):
    d = F + ((u - W / 2) / FPX) * R - ((v - H / 2) / FPX) * U
    return d / np.linalg.norm(d)


def on_plane(u, v, h=0.0):
    d = ray(u, v)
    t = (h - C[2]) / d[2]
    P = C + t * d
    return float(P[0]), float(P[1])


def local(u, v, h=0.0):
    X, Y = on_plane(u, v, h)
    return -X, Y


def height(v_top, u, v_base, h_base=0.0):
    """Height of a vertical feature whose base (at h_base) is at pixel
    (u, v_base) and whose top is at row v_top."""
    X, Y = on_plane(u, v_base, h_base)
    lo, hi = h_base, h_base + 200.0
    for _ in range(60):
        mid = (lo + hi) / 2
        vt = project([X, Y, mid])[0][1]
        if vt > v_top:
            lo = mid
        else:
            hi = mid
    return (lo + hi) / 2 - h_base

# Best physically valid pinhole for rendering the BUILD to compare with V2.
# Points are real engine coordinates (scene axes X east, Y north, Z up) paired
# with where V2 draws them. V2 is not a consistent camera (it draws the gate
# about 10% wide relative to the cell), so the residuals are reported, not hidden.
import json, math, numpy as np
from fit2 import rot, lm as _lm

W, H = 1536, 1024

PTS = [
    # gate pier bases (front face centres) and lantern bulbs
    ((-22.0, -105.3, 0.0), (652, 832), 'S gate L base'), ((22.0, -105.3, 0.0), (884, 832), 'S gate R base'),
    ((-22.0, 94.7, 0.0), (662, 163), 'N gate L base'), ((22.0, 94.7, 0.0), (872, 163), 'N gate R base'),
    ((-22.0, -100.0, 24.2), (652, 703), 'S gate L lamp'), ((22.0, -100.0, 24.2), (884, 703), 'S gate R lamp'),
    ((-22.0, 100.0, 24.2), (662, 60), 'N gate L lamp'), ((22.0, 100.0, 24.2), (872, 62), 'N gate R lamp'),
    # cell outline: inner corners at the south wall top, the north corner lanterns
    ((-138.5, -98.5, 10.0), (101, 762), 'SW corner top'), ((138.5, -98.5, 10.0), (1430, 762), 'SE corner top'),
    ((-140.0, 100.0, 14.1), (152, 113), 'NW corner lamp'), ((140.0, 100.0, 14.1), (1378, 112), 'NE corner lamp'),
    # south divider pier bases
    ((-100.67, -102.6, 0.0), (276, 812), 'S pier -100'), ((-61.33, -102.6, 0.0), (462, 812), 'S pier -61'),
    ((61.33, -102.6, 0.0), (1070, 812), 'S pier +61'), ((100.67, -102.6, 0.0), (1270, 812), 'S pier +100'),
    # north inner pier lanterns
    ((-61.33, 100.0, 14.1), (490, 98), 'N pier -61'), ((61.33, 100.0, 14.1), (1027, 98), 'N pier +61'),
]


def project(p, X):
    Cx, Cy, Cz, yaw, pitch, roll, fpx = p
    r, u, f = rot(yaw, pitch, roll)
    d = np.atleast_2d(X) - np.array([Cx, Cy, Cz])
    z = d @ f
    return np.stack([W / 2 + fpx * (d @ r) / z, H / 2 - fpx * (d @ u) / z], 1)


def res(p, pts):
    X = np.array([q[0] for q in pts]); x = np.array([q[1] for q in pts], float)
    return (project(p, X) - x).ravel()


def lm(p, pts, iters=300):
    lam = 1e-3
    for _ in range(iters):
        r = res(p, pts)
        J = np.zeros((len(r), len(p)))
        for i in range(len(p)):
            dp = np.zeros_like(p); h = 1e-6 * max(1.0, abs(p[i])); dp[i] = h
            J[:, i] = (res(p + dp, pts) - r) / h
        A = J.T @ J; g = J.T @ r
        while True:
            step = np.linalg.solve(A + lam * np.diag(np.diag(A) + 1e-9), -g)
            if (res(p + step, pts) ** 2).sum() < (r ** 2).sum():
                p = p + step; lam = max(lam / 3, 1e-9); break
            lam *= 4
            if lam > 1e9:
                return p
    return p


p = np.array([0.0, -1386.9, 1378.9, 0.0, math.radians(45), 0.0, 8533.3])
p = lm(p, PTS)
e = res(p, PTS).reshape(-1, 2)
for q, d in zip(PTS, e):
    print(f'{q[2]:16s} {np.linalg.norm(d):6.1f}px  ({d[0]:+.1f},{d[1]:+.1f})')
print('rms %.2f px' % math.sqrt((e ** 2).sum(1).mean()))
Cx, Cy, Cz, yaw, pitch, roll, fpx = p
r, u, f = rot(yaw, pitch, roll)
print('C', np.round(p[:3], 1), 'yaw %.2f pitch %.2f roll %.2f deg' % tuple(math.degrees(a) for a in (yaw, pitch, roll)),
      'fpx %.0f lens(36mm) %.1f' % (fpx, fpx * 36 / W))
json.dump({'C': list(map(float, p[:3])), 'forward': list(map(float, f)), 'up': list(map(float, u)), 'right': list(map(float, r)),
           'fpx': float(fpx), 'W': W, 'H': H, 'lens_mm': float(fpx * 36 / W), 'sensor_mm': 36.0,
           'rms_px': float(math.sqrt((e ** 2).sum(1).mean()))}, open('refcam.json', 'w'), indent=1)

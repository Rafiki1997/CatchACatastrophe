# Constrained pinhole fit of the V2 concept. Unknowns: camera centre, yaw,
# pitch, roll, focal length, and two things the image generator redrew: the
# cell half-width at the side walls (X_wall) and the height it gave the
# wall-top lanterns (h_lat). Gates stay at their real +-22 / +-100.
import math, json, numpy as np
from fit import V2PTS, LAT

W, H = 1536, 1024

def rot(yaw, pitch, roll):
    # camera looks along +Y rotated: start forward=(0,1,0), up=(0,0,1)
    cy, sy = math.cos(yaw), math.sin(yaw)
    cp, sp = math.cos(pitch), math.sin(pitch)
    f = np.array([sy * cp, cy * cp, -sp])
    r = np.array([cy, -sy, 0.0])
    u = np.cross(r, f)
    cr, sr = math.cos(roll), math.sin(roll)
    r2 = cr * r + sr * u; u2 = -sr * r + cr * u
    return r2, u2, f

def project(params, X):
    Cx, Cy, Cz, yaw, pitch, roll, fpx = params[:7]
    r, u, f = rot(yaw, pitch, roll)
    d = np.atleast_2d(X) - np.array([Cx, Cy, Cz])
    z = d @ f
    return np.stack([W / 2 + fpx * (d @ r) / z, H / 2 - fpx * (d @ u) / z], 1)

def points3d(params, pts):
    Xw, hl = params[7], params[8]
    out = []
    for X, uv, name in pts:
        X = list(X)
        if 'lamp' in name and 'gate' not in name:
            X[0] = math.copysign(Xw, X[0]); X[2] = hl
        out.append(X)
    return np.array(out, float)

def residuals(params, pts):
    X = points3d(params, pts)
    x = np.array([p[1] for p in pts], float)
    return (project(params, X) - x).ravel()

def lm(p, pts, iters=200):
    lam = 1e-3
    for _ in range(iters):
        r = residuals(p, pts)
        J = np.zeros((len(r), len(p)))
        for i in range(len(p)):
            dp = np.zeros_like(p); h = 1e-6 * max(1.0, abs(p[i])); dp[i] = h
            J[:, i] = (residuals(p + dp, pts) - r) / h
        A = J.T @ J; g = J.T @ r
        while True:
            step = np.linalg.solve(A + lam * np.diag(np.diag(A) + 1e-9), -g)
            r2 = residuals(p + step, pts)
            if (r2 ** 2).sum() < (r ** 2).sum():
                p = p + step; lam = max(lam / 3, 1e-9); break
            lam *= 4
            if lam > 1e9: return p
    return p

if __name__ == '__main__':
    # start from V1
    p = np.array([0.0, -1386.9, 1378.9, 0.0, math.radians(45), 0.0, 8533.3, 140.0, 14.1])
    p = lm(p, V2PTS)
    r = residuals(p, V2PTS).reshape(-1, 2)
    e = np.linalg.norm(r, axis=1)
    for q, ei in zip(V2PTS, e):
        print(f'{q[2]:12s} {ei:6.2f}px  d=({r[V2PTS.index(q)][0]:+.1f},{r[V2PTS.index(q)][1]:+.1f})')
    print('rms %.2f px' % math.sqrt((e ** 2).mean()))
    names = ['Cx', 'Cy', 'Cz', 'yaw', 'pitch', 'roll', 'fpx', 'X_wall', 'h_lat']
    for n, v in zip(names, p):
        print(n, round(math.degrees(v), 3) if n in ('yaw', 'pitch', 'roll') else round(v, 2))
    T = np.array(p[:3]); dist = np.linalg.norm(T)
    print('camera distance from origin %.1f; lens-equivalent %.1f mm on 36 mm' % (dist, p[6] * 36 / W))
    json.dump({'params': list(map(float, p)), 'names': names}, open('v2cam.json', 'w'), indent=1)

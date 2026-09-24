import json, math, numpy as np
from fit2 import rot
from fitcam import PTS, W, H

def project(p, X):
    Cx, Cy, Cz, yaw, pitch, roll, fpx, asp = p
    r, u, f = rot(yaw, pitch, roll)
    d = np.atleast_2d(X) - np.array([Cx, Cy, Cz])
    z = d @ f
    return np.stack([W / 2 + fpx * (d @ r) / z, H / 2 - fpx * asp * (d @ u) / z], 1)

def res(p, pts):
    X = np.array([q[0] for q in pts]); x = np.array([q[1] for q in pts], float)
    return (project(p, X) - x).ravel()

def lm(p, pts, iters=400):
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
            if lam > 1e9: return p
    return p

cam = json.load(open('refcam.json'))
p = np.array([0.0, -947.9, 941.0, 0.0, math.radians(45.3), 0.0, 6155.0, 1.0])
p = lm(p, PTS)
e = res(p, PTS).reshape(-1, 2)
for q, d in zip(PTS, e):
    print(f'{q[2]:16s} {np.linalg.norm(d):6.1f}px  ({d[0]:+.1f},{d[1]:+.1f})')
print('rms %.2f' % math.sqrt((e ** 2).sum(1).mean()), 'aspect', round(p[7], 4), 'pitch', round(math.degrees(p[4]), 2))

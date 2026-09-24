import json, math, numpy as np
from cam import *

LAT = [100.0, 55.56, 11.11, -33.33, -77.78]
V2PTS = []
for y, uv in zip(LAT, [(152, 113), (139, 235), (123, 388), (111, 552), (95, 715)]):
    V2PTS.append(((-140.0, y, 14.1), uv, f'Llamp{y:+.0f}'))
for y, uv in zip(LAT, [(1378, 112), (1392, 235), (1410, 390), (1422, 552), (1438, 713)]):
    V2PTS.append(((140.0, y, 14.1), uv, f'Rlamp{y:+.0f}'))
V2PTS += [
    ((-22.0, -100.0, 24.2), (652, 703), 'SgateLlamp'), ((22.0, -100.0, 24.2), (884, 703), 'SgateRlamp'),
    ((-22.0, 100.0, 24.2), (662, 60), 'NgateLlamp'), ((22.0, 100.0, 24.2), (872, 62), 'NgateRlamp'),
    ((-22.0, -105.3, 0.0), (652, 832), 'SgateLbase'), ((22.0, -105.3, 0.0), (884, 832), 'SgateRbase'),
    ((-22.0, 94.7, 0.0), (662, 163), 'NgateLbase'), ((22.0, 94.7, 0.0), (872, 163), 'NgateRbase'),
]

def dlt(pts):
    X = np.array([p[0] for p in pts], float); x = np.array([p[1] for p in pts], float)
    # normalise
    mX, sX = X.mean(0), X.std() ; mx, sx = x.mean(0), x.std()
    TX = np.diag([1 / sX] * 3 + [1.0]); TX[:3, 3] = -mX / sX
    Tx = np.diag([1 / sx] * 2 + [1.0]); Tx[:2, 2] = -mx / sx
    Xh = (TX @ np.hstack([X, np.ones((len(X), 1))]).T).T
    xh = (Tx @ np.hstack([x, np.ones((len(x), 1))]).T).T
    A = []
    for Xi, xi in zip(Xh, xh):
        A.append(np.concatenate([np.zeros(4), -xi[2] * Xi, xi[1] * Xi]))
        A.append(np.concatenate([xi[2] * Xi, np.zeros(4), -xi[0] * Xi]))
    _, _, Vt = np.linalg.svd(np.array(A))
    Pn = Vt[-1].reshape(3, 4)
    P = np.linalg.inv(Tx) @ Pn @ TX
    return P / P[2, 3] if abs(P[2, 3]) > 1e-12 else P

def proj(P, X):
    X = np.atleast_2d(X); h = (P @ np.hstack([X, np.ones((len(X), 1))]).T).T
    return h[:, :2] / h[:, 2:3]

def resid(P, pts):
    X = np.array([p[0] for p in pts]); x = np.array([p[1] for p in pts], float)
    return np.linalg.norm(proj(P, X) - x, axis=1)

if __name__ == '__main__':
    P = dlt(V2PTS)
    r = resid(P, V2PTS)
    for p, e in zip(V2PTS, r):
        print(f'{p[2]:12s} {e:6.2f}px')
    print('rms', math.sqrt((r ** 2).mean()))
    np.save('P_v2.npy', P)
    # decompose: K R | t
    M = P[:, :3]
    # RQ decomposition
    def rq(M):
        Q, R = np.linalg.qr(np.flipud(M).T)
        R = np.flipud(R.T); Q = Q.T
        return R[:, ::-1], Q[::-1, :]
    K, R = rq(M)
    T = np.diag(np.sign(np.diag(K))); K = K @ T; R = T @ R
    K = K / K[2, 2]
    C = -np.linalg.inv(M) @ P[:, 3]
    print('K', np.round(K, 2)); print('camera centre', np.round(C, 1))
    f = R[2] * np.sign(np.linalg.det(R))
    print('forward', np.round(R[2], 4), 'pitch deg', math.degrees(math.asin(-R[2][2])))
    v1 = v1_camera(); P1 = P_matrix(v1)
    print('V1 cam C', np.round(v1['C'], 1), 'fpx', v1['fpx'])
    r1 = resid(P1 / P1[2, 3], V2PTS)
    print('V1 camera against V2 points rms', math.sqrt((r1 ** 2).mean()))

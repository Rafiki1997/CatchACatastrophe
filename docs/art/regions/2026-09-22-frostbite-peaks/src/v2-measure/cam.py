# V1 mockup camera (fb_base.setup_camera, render_frostbite defaults) and
# overlay helpers. Scene axes: X east, Y north, Z up (= region local
# x' = -X, z' = Y).
import math
import numpy as np

W, H = 1536, 1024

def v1_camera(pitch=45.0, lens=200.0, target=(0.0, -8.0, 0.0), dist=1950.0, sensor=36.0, shift_y=0.0):
    p = math.radians(pitch)
    T = np.array(target, float)
    C = T + np.array([0.0, -dist * math.cos(p), dist * math.sin(p)])
    f = (T - C) / np.linalg.norm(T - C)
    r = np.cross(f, [0, 0, 1.0]); r /= np.linalg.norm(r)
    u = np.cross(r, f)
    fpx = lens / sensor * W
    return dict(C=C, f=f, r=r, u=u, fpx=fpx, cx=W / 2, cy=H / 2 - shift_y * W)

def project(cam, P):
    P = np.atleast_2d(np.asarray(P, float))
    d = P - cam['C']
    z = d @ cam['f']
    x = d @ cam['r']
    y = d @ cam['u']
    return np.stack([cam['cx'] + cam['fpx'] * x / z, cam['cy'] - cam['fpx'] * y / z], 1)

def P_matrix(cam):
    """3x4 projection matrix for the camera."""
    K = np.array([[cam['fpx'], 0, cam['cx']], [0, -cam['fpx'], cam['cy']], [0, 0, 1.0]])
    R = np.stack([cam['r'], cam['u'], cam['f']])
    t = -R @ cam['C']
    return K @ np.hstack([R, t[:, None]])

HALF_W, HALF_D = 140.0, 100.0
LATERAL_PIERS = [-77.78, -33.33, 11.11, 55.56, 100.0]
DIVIDER_PIERS = [-100.67, -61.33, 61.33, 100.67]

def features():
    """Named 3D feature points on the known MapBuilder geometry."""
    F = {}
    for s, nm in ((-1, 'W'), (1, 'E')):
        for y, ny in ((-100.0, 'S'), (100.0, 'N')):
            # gate pier: 9x9 on a 10.6 base, 19 tall + cap at 2.75+19, lantern above
            x = s * 22.0
            F[f'gate{ny}{nm}_base'] = (x, y, 0.0)
            F[f'gate{ny}{nm}_cap'] = (x, y, 21.75)
        for y in LATERAL_PIERS[:-1]:
            F[f'lat{nm}{y:+.0f}_base'] = (s * 140.0, y, 0.0)
            F[f'lat{nm}{y:+.0f}_top'] = (s * 140.0, y, 12.2)
        for yy, ny in ((-100.0, 'S'), (100.0, 'N')):
            F[f'corner{ny}{nm}_base'] = (s * 140.0, yy, 0.0)
            F[f'corner{ny}{nm}_top'] = (s * 140.0, yy, 12.2)
    for x in DIVIDER_PIERS:
        for y, ny in ((-100.0, 'S'), (100.0, 'N')):
            F[f'div{ny}{x:+.0f}_base'] = (x, y, 0.0)
            F[f'div{ny}{x:+.0f}_top'] = (x, y, 12.2)
    return F

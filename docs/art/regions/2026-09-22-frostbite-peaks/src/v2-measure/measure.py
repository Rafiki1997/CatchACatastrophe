# V2 pixel -> real region coordinates.
#   1. ground homography from the four gate-pier bases (homog.py)
#   2. vertical ruler from the gate piers' 15-stud teal panels
#   3. piecewise x map anchored on engine features the image shows:
#      gate piers (22), inner divider piers (61.33), outer divider piers
#      (100.67) and the inner wall face (138.5), read at V2 gate scale as
#      22, 57.7, 94.3, 126.5.
# Output: scene (X east, Y north) and region-local (x = -X, z = Y).
import numpy as np
from homog import to_ground, to_px

def vscale(v):
    # teal panel: 64 px / 15 at v 832 (south), 60 px / 15 at v 163 (north)
    t = (v - 163.0) / (832.0 - 163.0)
    return 4.0 + t * (4.267 - 4.0)

XV = [0.0, 22.0, 57.7, 94.3, 126.5, 160.0]
XR = [0.0, 22.0, 61.33, 100.67, 138.5, 176.2]

def xmap(xv):
    return float(np.sign(xv) * np.interp(abs(xv), XV, XR))

def ground(u, v, h=0.0):
    vg = v
    for _ in range(6):
        vg = v + h * vscale(vg)
    X, Y = to_ground(u, vg)
    return xmap(X), float(Y)

def local(u, v, h=0.0):
    X, Y = ground(u, v, h)
    return -X, Y

def height(v_top, v_base):
    return (v_base - v_top) / vscale(v_base)

if __name__ == '__main__':
    import sys
    for name, u, v, h in [('SW inner corner @wall top', 101, 762, 10), ('SE inner corner', 1430, 762, 10),
                          ('S outer pier L', 276, 812, 0), ('S inner pier L', 462, 812, 0), ('S inner pier R', 1070, 812, 0), ('S outer pier R', 1270, 812, 0),
                          ('N inner pier L lamp', 490, 98, 14.1), ('N inner pier R lamp', 1027, 98, 14.1),
                          ('S wall front base', 300, 810, 0)]:
        print(f'{name:28s} scene {np.round(ground(u, v, h), 1)}  raw {np.round(to_ground(u, v + h * vscale(v)), 1)}')

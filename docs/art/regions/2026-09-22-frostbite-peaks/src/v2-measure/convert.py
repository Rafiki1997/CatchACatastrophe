import json, numpy as np
from measure import ground, local, height, vscale, xmap
import annot as A


def L(u, v, h):
    x, z = local(u, v, h)
    return round(x, 1), round(z, 1)


out = {}
lod = {}
for k, (u, v, h) in A.LODGE.items():
    if h is not None:
        lod[k] = L(u, v, h)
out['lodge'] = lod
fw_l, fw_r = lod['front_wall_L'], lod['front_wall_R']
print('lodge front wall local', fw_l, fw_r, 'width', round(abs(fw_l[0] - fw_r[0]), 1))
base_v = A.LODGE['front_wall_L'][1]
for k in ('eave_L', 'eave_R', 'apex_front', 'door_top'):
    print(' height above porch floor', k, round(height(A.LODGE[k][1], base_v), 1))
hap = height(A.LODGE['apex_front'][1], base_v) + A.T_TOP + 1.0
rb = L(A.LODGE['ridge_back'][0], A.LODGE['ridge_back'][1], hap)
print(' apex height above ground', round(hap, 1), 'ridge back ground', rb, 'depth from front', round(rb[1] - fw_l[1], 1))
ct = L(A.LODGE['chimney_top'][0], A.LODGE['chimney_top'][1], hap + 5)
print(' chimney (assume top = apex + 5):', ct)
print(' annex', L(*A.LODGE['annex_front_L']), L(*A.LODGE['annex_front_R']))
ter = {k: L(*p) for k, p in A.TERRACE.items()}
print('terrace', ter)
out['terrace'] = ter
print('camp')
camp = []
for kind, u, v, h, vt in A.CAMP:
    p = L(u, v, h)
    hh = round(height(vt, v), 1)
    camp.append((kind, p, hh))
    print(' ', kind, p, 'h', hh)
out['camp'] = camp
br = {k: L(*p) for k, p in A.BRIDGE.items() if p[2] is not None}
print('bridge')
for k, v in br.items():
    print(' ', k, v)
out['bridge'] = br
firs = []
for lab, u, v, h, vt in A.FIRS:
    p = L(u, v, h)
    hh = round(height(vt, v), 1)
    firs.append((lab, p, hh))
out['firs'] = firs
rocks = []
for lab, u, v, hw, hd, vt in A.ROCKS:
    p = L(u, v, 0)
    a = local(u - hw, v, 0)
    b = local(u + hw, v, 0)
    c = local(u, v - hd, 0)
    d = local(u, v + hd, 0)
    w = round(abs(a[0] - b[0]), 1)
    dd = round(abs(c[1] - d[1]), 1)
    hh = round(height(vt, v + hd), 1)
    rocks.append((lab, p, w, dd, hh))
out['rocks'] = rocks
out['shrubs'] = [(k, L(u, v, 0)) for k, u, v in A.SHRUBS]
out['ice'] = [((round(-xmap(c[0]), 1), c[1]), s) for c, s in A.FIELD_ICE]
json.dump(out, open('layout_v2.json', 'w'), indent=1)
print('firs (label, local xz, height)')
for f in firs:
    print(' ', f)
print('rocks (label, centre, W, D, H)')
for r in rocks:
    print(' ', r)
print('shrubs')
for s in out['shrubs']:
    print(' ', s)

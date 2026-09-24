# Ground homography of the V2 concept from the four gate-pier bases (front
# face centres, which is what the image shows), plus a vertical ruler from the
# gate piers' teal panels. Scene axes: X east (image right), Y north.
import numpy as np, json

GROUND = [((-22.0, -105.3), (652.0, 832.0)), ((22.0, -105.3), (884.0, 832.0)),
          ((-22.0, 94.7), (662.0, 163.0)), ((22.0, 94.7), (872.0, 163.0))]

def fit_h(pairs):
    A = []
    for (X, Y), (u, v) in pairs:
        A.append([X, Y, 1, 0, 0, 0, -u * X, -u * Y, -u])
        A.append([0, 0, 0, X, Y, 1, -v * X, -v * Y, -v])
    _, _, Vt = np.linalg.svd(np.array(A, float))
    H = Vt[-1].reshape(3, 3)
    return H / H[2, 2]

H = fit_h(GROUND)          # scene ground -> pixel
Hi = np.linalg.inv(H)      # pixel -> scene ground

def to_px(X, Y):
    p = H @ np.array([X, Y, 1.0]); return p[:2] / p[2]

def to_ground(u, v):
    p = Hi @ np.array([u, v, 1.0]); return p[:2] / p[2]

# Vertical ruler: teal panel 15 studs tall; 64 px at the south gate (v 832),
# 55 px at the north gate (v 163). Horizontal scale falls off the same way.
def vscale(v):
    t = (v - 163.0) / (832.0 - 163.0)
    return 55.0 / 15 + t * (64.0 / 15 - 55.0 / 15)

def ground_under(u, v, h):
    """Pixel of a point h studs up -> the ground point beneath it (iterative)."""
    vg = v
    for _ in range(5):
        vg = v + h * vscale(vg)
    return to_ground(u, vg)

def height_of(u_top, v_top, u_base, v_base):
    return (v_base - v_top) / vscale(v_base)

if __name__ == '__main__':
    for (X, Y), (u, v) in GROUND:
        print((X, Y), (u, v), np.round(to_px(X, Y), 2))
    # px per stud across the gate lines and mid-field
    for Y in (-100, -50, 0, 50, 100):
        a, b = to_px(-10, Y), to_px(10, Y)
        print('Y', Y, 'hscale %.2f px/stud' % ((b[0] - a[0]) / 20), 'v %.1f' % a[1])
    json.dump({'H': H.tolist()}, open('H_v2.json', 'w'))

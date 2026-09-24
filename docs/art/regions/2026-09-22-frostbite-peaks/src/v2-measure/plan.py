# Top-down plan of the V2 layout in region studs, oriented like the concept:
# north (the Thunderworks gate) up, local +X (west) on the LEFT.
import math, sys
from PIL import Image, ImageDraw, ImageFont
import layout as Lo

S = 4.0                       # px per stud
PAD = 60
Wc, Hc = 280 + 70, 200 + 30   # show the flanks and the wall bands
W, H = int(Wc * S) + 2 * PAD, int(Hc * S) + 2 * PAD + 70
im = Image.new('RGB', (W, H), (247, 245, 241))
d = ImageDraw.Draw(im, 'RGBA')
try:
    F = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', 13)
    FB = ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf', 16)
    FT = ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf', 24)
except Exception:
    F = FB = FT = ImageFont.load_default()


def px(x, z):
    return (W / 2 - x * S, PAD + 40 + (Hc / 2 - z) * S)


def poly(pts, fill, outline=(40, 40, 40, 255), w=1):
    d.polygon([px(x, z) for x, z in pts], fill=fill, outline=outline)


def box(cx, cz, w, dd, yaw=0.0, **k):
    a = math.radians(yaw); c, s = math.cos(a), math.sin(a)
    pts = []
    for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        lx, lz = sx * w / 2, sz * dd / 2
        pts.append((cx + lx * c + lz * s, cz - lx * s + lz * c))
    poly(pts, **k)


def rect(x0, x1, z0, z1, **k):
    poly([(x0, z0), (x1, z0), (x1, z1), (x0, z1)], **k)


def label(x, z, t, font=F, col=(20, 20, 20)):
    u, v = px(x, z)
    d.text((u, v), t, fill=col, font=font, anchor='mm')


# floor, flanks, lane
rect(-175, 175, -100, 100, fill=(232, 238, 246, 255), outline=None)
rect(-140, 140, -100, 100, fill=(218, 226, 238, 255), outline=None)
rect(-12, 12, -100, 100, fill=(200, 214, 232, 255), outline=None)
rect(-80, 80, -64, 64, fill=(0, 0, 0, 0), outline=(90, 140, 90, 255))
label(0, -66.5, 'creature field |x| < 80, |z| < 64 (FieldHalf)', col=(60, 110, 60))
# walls and gates
for s in (-1, 1):
    rect(s * 138.5, s * 141.5, -101.5, 101.5, fill=(228, 216, 192, 255), outline=(150, 140, 120, 255))
for z in (-100, 100):
    rect(-140, -22, z - 1.5, z + 1.5, fill=(228, 216, 192, 255), outline=(150, 140, 120, 255))
    rect(22, 140, z - 1.5, z + 1.5, fill=(228, 216, 192, 255), outline=(150, 140, 120, 255))
    for s in (-1, 1):
        rect(s * 17.5, s * 26.5, z - 4.5, z + 4.5, fill=(38, 78, 122, 255))
label(0, -104.5, 'SOUTH GATE  FROSTBITE PEAKS / 75K (entry from Cinder)', FB)
label(0, 104.5, 'NORTH GATE  THUNDERWORKS / 300K', FB)
A = Lo.ASSETS
# ice / creek
for x, z, w, dd, yaw in Lo.FIELD_ICE:
    box(x, z, w, dd, yaw, fill=(170, 205, 235, 200), outline=None)
for x0, x1, z0, z1 in Lo.CREEK:
    rect(x0, x1, z0, z1, fill=(110, 160, 210, 220), outline=None)
# terrace + stairs
T = Lo.TERRACE
rect(T['x0'], T['x1'], T['z0'], T['z1'], fill=(196, 188, 176, 255))
st = Lo.TERRACE_STAIR
rect(st['x0'], st['x1'], st['top_z'] - (st['risers'] - 1) * st['tread'], st['top_z'], fill=(150, 150, 160, 255))
label((T['x0'] + T['x1']) / 2, T['z0'] + 4, f"TERRACE  deck +{Lo.T_TOP}", FB)
# shelves, gorge rock, bridge
for k, nm in (('SHELF_C', 'C'), ('SHELF_A', 'A'), ('SHELF_B', 'B')):
    s = getattr(Lo, k)
    rect(s['x0'], s['x1'], s['z0'], s['z1'], fill=(150, 158, 172, 255))
    label((s['x0'] + s['x1']) / 2, (s['z0'] + s['z1']) / 2, f"{nm} +{Lo.S_TOP}", FB, (255, 255, 255))
bs = Lo.B_STAIR
rect(bs['x0'], bs['x1'], bs['top_z'] - (bs['risers'] - 1) * bs['tread'], bs['top_z'], fill=(120, 120, 132, 255))
g = Lo.GORGE_ROCK
box(g['x'], g['z'], A['FA_Gorge_Rock'][0], A['FA_Gorge_Rock'][2], fill=(110, 118, 132, 255))
n, s_ = Lo.BRIDGE['n'], Lo.BRIDGE['s']
yaw = math.degrees(math.atan2(n[0] - s_[0], n[1] - s_[1]))
box((n[0] + s_[0]) / 2, (n[1] + s_[1]) / 2, 8, math.hypot(n[0] - s_[0], n[1] - s_[1]), yaw, fill=(170, 120, 70, 255))
label((n[0] + s_[0]) / 2 + 12, (n[1] + s_[1]) / 2, 'bridge', F)
# cliffs, boulders
for asset, x, z, yaw_, sc in Lo.CLIFFS:
    w, h, dd = (v * sc for v in A[asset])
    box(x, z, w, dd, yaw_, fill=(96, 106, 124, 230))
    label(x, z, f"{asset[8:]} h{h:.0f}", F, (255, 255, 255))
for asset, x, z, yaw_, sc in Lo.BOULDERS:
    w, h, dd = (v * sc for v in A[asset])
    box(x, z, w, dd, yaw_, fill=(120, 128, 142, 230))
for x, z, yaw_, sc in Lo.SNOWBANKS:
    w, h, dd = (v * sc for v in A['FA_Snowbank'])
    box(x, z, w, dd, yaw_, fill=(250, 252, 255, 230), outline=(180, 190, 210, 255))
# lodge + camp
w, h, dd = A['FA_Lodge']
box(Lo.LODGE['x'], Lo.LODGE['z'], w, dd, fill=(150, 96, 60, 255))
label(Lo.LODGE['x'], Lo.LODGE['z'], 'LODGE (door faces south)', FB, (255, 255, 255))
for asset, x, z, yaw_, hb, sc in Lo.CAMP:
    w, h, dd = (v * sc for v in A[asset])
    col = (236, 118, 46, 255) if asset == 'FA_Tent' else (170, 130, 90, 255)
    box(x, z, w, dd, yaw_, fill=col)
# vegetation
for asset, x, z, hb, sc in Lo.FIRS:
    r = A[asset][0] * sc / 2
    u, v = px(x, z)
    d.ellipse([u - r * S, v - r * S, u + r * S, v + r * S], fill=(46, 96, 72, 200), outline=(20, 60, 40, 255))
for x, z, a, sc in Lo.FLANK:
    r = A[a][0] * sc / 2
    u, v = px(x, z)
    d.ellipse([u - r * S, v - r * S, u + r * S, v + r * S], fill=(46, 96, 72, 150), outline=(20, 60, 40, 200))
for asset, x, z in Lo.PLANTS:
    u, v = px(x, z)
    col = (214, 170, 80, 255) if 'Grass' in asset else (190, 210, 220, 255)
    d.ellipse([u - 5, v - 5, u + 5, v + 5], fill=col, outline=(90, 80, 60, 255))
for x, z in Lo.LANE_STAKES:
    u, v = px(x, z)
    d.rectangle([u - 2, v - 2, u + 2, v + 2], fill=(90, 60, 40, 255))
# axes key
d.text((PAD, 14), 'Alpine Outpost V2 - measured plan, region-local studs', font=FT, fill=(27, 56, 102))
d.text((PAD, 46), '+X = west = image LEFT,  +Z = north (Thunderworks),  lane |x| < 12 kept clear gate to gate.  1 grid = 20 studs', font=F, fill=(66, 112, 160))
for x in range(-160, 161, 20):
    u, _ = px(x, 0)
    d.line([(u, PAD + 40), (u, PAD + 40 + Hc * S)], fill=(0, 0, 0, 25))
    d.text((u, H - 60), str(x), font=F, fill=(90, 90, 90), anchor='mm')
for z in range(-100, 101, 20):
    _, v = px(0, z)
    d.line([(PAD, v), (W - PAD, v)], fill=(0, 0, 0, 25))
    d.text((PAD - 25, v), str(z), font=F, fill=(90, 90, 90), anchor='mm')
im.save(sys.argv[1] if len(sys.argv) > 1 else 'plan.png')
print('ok', W, H)

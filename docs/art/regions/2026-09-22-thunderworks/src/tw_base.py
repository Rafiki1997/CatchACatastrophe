# The part of every Thunderworks mockup that is not a design choice: the
# render setup, the cell floor and lane, MapBuilder's walls, piers, gates,
# Orbit Outpost's locked barrier and both banners at their real coordinates,
# glimpses of Frostbite Peaks (south) and Orbit Outpost (north), the heath
# outside the side walls, the Storm creatures, and the clear-floor
# measurement. Adapted from the Frostbite round's fb_base.py; every
# MapBuilder number is quoted from src/server/Map/MapBuilder.luau
# (buildChainWalls, gatePier, wall, lamp, buildRegion) and converted to
# scene axes: Roblox region-local (x, y, z) is (x, -z, y) here.
import bpy
import bmesh
import math
import random
from mathutils import Vector, Matrix

import tw_lib as L
import tw_geo as G
from tw_lib import rgb, TAU

# ------------------------------------------------------------------ layout
HALF_W, HALF_D = 140.0, 100.0          # CELL_W, CELL_D = 280, 200
WALL_T, WALL_H = 3.0, 9.0
GATE_W = 44.0
IN_X, IN_Y = HALF_W - WALL_T / 2, HALF_D - WALL_T / 2   # inner faces, 138.5 / 98.5
Y_SOUTH_EDGE, Y_NORTH_EDGE = -118.0, 128.0              # how much of the neighbours shows
X_EDGE = 172.0
# The side walls run the whole 1200-stud chain with round(1200 / 45) = 27
# piers, one every 44.44 studs from the island edge (MapBuilder.wall). The
# Thunderworks cell (index 5) is centred 900 studs up the chain, so its
# piers fall at 44.44 k - 900: the south divider corner, three inside the
# cell, the north divider corner at 77.78 + 44.44 = 122.2 is Orbit's.
LATERAL_PIERS = [-100.0, -55.56, -11.11, 33.33, 77.78, 122.22]
# Divider halves (-140 .. -22 and 22 .. 140) carry two piers each.
DIVIDER_PIERS = [-100.67, -61.33, 61.33, 100.67]

# Design envelope, the same one the rebuilt regions use (Frostbite V1:
# field half 92 x 70, a 24-wide lane, |x| < 36 open in front of both gates).
LANE_HALF = 12.0
FIELD_HALF = (92.0, 70.0)

WALL_STONE = rgb(228, 216, 192)
WALL_CAP = rgb(203, 189, 163)
WALL_PIER = rgb(216, 203, 179)
LANTERN = rgb(255, 214, 140)
TEAL_PANEL = rgb(38, 78, 122)
NAVY = rgb(30, 52, 92)
BRONZE = rgb(120, 82, 48)
DECK = rgb(120, 126, 142)
STORM_COLOR = rgb(255, 230, 90)
COSMIC_COLOR = rgb(200, 130, 255)
# Orbit's barrier edges: def.color (200, 130, 255) lerped 0.55 toward
# (150, 236, 255), as buildRegion computes it.
COSMIC_EDGE = rgb(173, 188, 255)
FROST_GROUND = rgb(210, 219, 233)
ORBIT_GROUND = rgb(118, 109, 132)
STORM_GROUND = rgb(78, 84, 99)

FONT_PATH = "C:/Windows/Fonts/seguibl.ttf"


# ------------------------------------------------------------------ scene
def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    L._M.clear()


def setup_render(samples=128, res_scale=1.0, width=1536, height=1024, exposure=-0.25, look='AgX - Punchy'):
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    prefs = bpy.context.preferences.addons['cycles'].preferences
    try:
        prefs.compute_device_type = 'OPTIX'
        prefs.refresh_devices()
        for d in prefs.devices:
            d.use = d.type == 'OPTIX'
        sc.cycles.device = 'GPU'
    except Exception as e:  # pragma: no cover - CPU fallback
        print("GPU setup failed, CPU render:", e)
    sc.cycles.samples = samples
    sc.cycles.use_adaptive_sampling = True
    sc.cycles.adaptive_threshold = 0.02
    sc.cycles.use_denoising = True
    for dn in ('OPENIMAGEDENOISE', 'OPTIX'):
        try:
            sc.cycles.denoiser = dn
            break
        except Exception:
            pass
    sc.cycles.max_bounces = 8
    sc.cycles.diffuse_bounces = 3
    sc.cycles.glossy_bounces = 3
    sc.cycles.transmission_bounces = 8
    sc.cycles.transparent_max_bounces = 16
    sc.cycles.caustics_reflective = False
    sc.cycles.caustics_refractive = False
    sc.cycles.blur_glossy = 1.0
    sc.cycles.sample_clamp_indirect = 8.0
    sc.render.film_transparent = True
    sc.render.resolution_x = int(width * res_scale)
    sc.render.resolution_y = int(height * res_scale)
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGBA'
    sc.render.image_settings.color_depth = '8'
    vs = sc.view_settings
    vs.view_transform = 'AgX'
    try:
        vs.look = look
    except Exception:
        pass
    vs.exposure = exposure
    return sc


def setup_world(sky=(0.42, 0.52, 0.80), strength=0.5):
    sc = bpy.context.scene
    w = bpy.data.worlds.new("World")
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (*sky, 1.0)
    bg.inputs[1].default_value = strength
    sc.world = w


def setup_sun(direction=(0.72, 0.15, -0.66), energy=7.0, angle=4.0, color=(1.0, 0.94, 0.86)):
    sc = bpy.context.scene
    ld = bpy.data.lights.new("Sun", 'SUN')
    ld.energy = energy
    ld.angle = math.radians(angle)
    ld.color = color
    sun = bpy.data.objects.new("Sun", ld)
    d = Vector(direction).normalized()
    sun.rotation_euler = (-d).to_track_quat('Z', 'Y').to_euler()
    sc.collection.objects.link(sun)
    return sun


def setup_camera(pitch=45.0, lens=200.0, target=(0.0, -8.0, 0.0), dist=1950.0, shift_x=0.0, shift_y=0.0, ortho=None):
    sc = bpy.context.scene
    cd = bpy.data.cameras.new("Cam")
    cd.sensor_fit = 'HORIZONTAL'
    cd.sensor_width = 36.0
    if ortho:
        cd.type = 'ORTHO'
        cd.ortho_scale = ortho
    else:
        cd.lens = lens
    cd.clip_start = 5.0
    cd.clip_end = 9000.0
    cd.shift_x = shift_x
    cd.shift_y = shift_y
    cam = bpy.data.objects.new("Cam", cd)
    p = math.radians(pitch)
    cam.location = (target[0], target[1] - dist * math.cos(p), target[2] + dist * math.sin(p))
    cam.rotation_euler = (Vector(target) - Vector(cam.location)).to_track_quat('-Z', 'Y').to_euler()
    sc.collection.objects.link(cam)
    sc.camera = cam
    return cam


# ------------------------------------------------------------------ materials
class BaseMats:
    def __init__(self):
        self.wall_x = L.brick_mat("wall_x", WALL_STONE, rgb(188, 174, 148), 4.4, 2.25, axis='X')
        self.wall_y = L.brick_mat("wall_y", WALL_STONE, rgb(188, 174, 148), 4.4, 2.25, axis='Y')
        self.pier = L.brick_mat("pier", WALL_PIER, rgb(182, 168, 142), 2.6, 2.0, axis='X')
        self.pier_y = L.brick_mat("pier_y", WALL_PIER, rgb(182, 168, 142), 2.6, 2.0, axis='Y')
        self.cap = L.mat("wall_cap", WALL_CAP, rough=0.8)
        self.course = L.mat("wall_course", rgb(176, 164, 140), rough=0.85)
        self.teal = L.mat("teal_panel", TEAL_PANEL, rough=0.55)
        self.gold = L.mat("gold", rgb(232, 176, 64), rough=0.32, metal=1.0)
        self.gold_deep = L.mat("gold_deep", rgb(180, 128, 40), rough=0.4, metal=1.0)
        self.iron = L.mat("iron", rgb(64, 60, 60), rough=0.45, metal=0.6)
        self.lantern = L.mat("lantern", LANTERN, emit=7.0, emit_color=rgb(255, 206, 120))
        self.gate_lantern = L.mat("gate_lantern", rgb(255, 238, 196), emit=6.0, emit_color=rgb(255, 222, 160))
        self.navy = L.mat("navy", NAVY, rough=0.5)
        self.bronze = L.mat("bronze", BRONZE, rough=0.5, metal=0.3)
        self.sign_text = L.mat("sign_text", rgb(255, 253, 246), rough=0.4, emit=0.6)
        self.cost_text = L.mat("cost_text", rgb(255, 238, 198), rough=0.4, emit=0.6)
        self.barrier = L.mat("barrier", rgb(186, 230, 250), rough=0.1, alpha=0.38, emit=0.9, emit_color=rgb(186, 230, 250))
        self.edge = L.mat("barrier_edge", COSMIC_EDGE, emit=3.0)
        self.edge_faint = L.mat("barrier_faint", COSMIC_EDGE, emit=2.0, alpha=0.5)
        self.lock_face = L.mat("lock_face", rgb(236, 180, 60), emit=1.2, emit_color=rgb(236, 176, 58), rough=0.3)
        self.lock_white = L.mat("lock_white", rgb(252, 248, 238), rough=0.4)
        self.deck = L.mat("deck", DECK, rough=0.5, metal=0.3)
        self.storm_bulb = L.mat("storm_bulb", STORM_COLOR, emit=5.0)
        self.cosmic_bulb = L.mat("cosmic_bulb", COSMIC_COLOR, emit=5.0)
        self.frost = L.mat("frost_ground", FROST_GROUND, rough=0.8, jitter=0.02)
        self.snow = L.mat("snow", rgb(238, 243, 249), rough=0.72, sss=0.08, jitter=0.03)
        self.slate = L.mat("frost_slate", rgb(70, 82, 104), rough=0.85, jitter=0.12, rand=0.1)
        self.fir = L.mat("frost_fir", rgb(40, 88, 74), rough=0.8, jitter=0.1, rand=0.12)
        self.orbit = L.mat("orbit_ground", ORBIT_GROUND, rough=0.92, jitter=0.05)
        self.orbit_rock = L.mat("orbit_rock", rgb(96, 86, 112), rough=0.85, jitter=0.14, rand=0.1)
        self.orbit_top = L.mat("orbit_top", rgb(126, 116, 142), rough=0.85, jitter=0.1)
        self.crystal = L.mat("orbit_crystal", rgb(168, 110, 240), rough=0.2, emit=1.4, emit_color=rgb(170, 110, 255), coat=0.4)
        self.crystal_cyan = L.mat("orbit_crystal_cyan", rgb(110, 220, 240), rough=0.2, emit=1.6, emit_color=rgb(110, 220, 250), coat=0.4)


# ------------------------------------------------------------------ ground
def build_ground(bm_, c, field_mat, outer_mat):
    """Cell floor, the flank strips, both neighbours' floors."""
    L.box_obj("CellFloor", (HALF_W * 2 + 2, HALF_D * 2, 2.0), (0, 0, -1.0), field_mat, c, solid=False)
    for s in (-1, 1):
        w = X_EDGE - HALF_W - 1
        L.box_obj("FlankFloor", (w, HALF_D * 2, 2.0), (s * (HALF_W + 1 + w / 2), 0, -1.02), outer_mat, c, solid=False)
    dS = -HALF_D - Y_SOUTH_EDGE
    L.box_obj("FrostFloor", (X_EDGE * 2, dS, 2.0), (0, Y_SOUTH_EDGE + dS / 2, -1.01), bm_.frost, c, solid=False)
    dN = Y_NORTH_EDGE - HALF_D
    L.box_obj("OrbitFloor", (X_EDGE * 2, dN, 2.0), (0, HALF_D + dN / 2, -1.01), bm_.orbit, c, solid=False)


# ------------------------------------------------------------------ walls
def _pier(bm_, c, x, y, height, axis='X'):
    top = height + 3.2
    L.box_obj("WallPier", (5.2, 5.2, top), (x, y, top / 2), bm_.pier if axis == 'X' else bm_.pier_y, c, bevel=0.14)
    L.box_obj("LanternBase", (3.4, 3.4, 0.7), (x, y, top + 0.35), bm_.iron, c, bevel=0.08)
    L.box_obj("LanternBulb", (2.4, 2.4, 2.4), (x, y, top + 1.9), bm_.lantern, c, bevel=0.1)
    for sx in (-1, 1):
        for sy in (-1, 1):
            L.box_obj("LanternRib", (0.28, 0.28, 2.4), (x + sx * 1.2, y + sy * 1.2, top + 1.9), bm_.iron, c)
    L.box_obj("LanternCap", (3.8, 3.8, 0.8), (x, y, top + 3.5), bm_.iron, c, bevel=0.1)


def wall_run(bm_, c, x0, y0, x1, y1, height=WALL_H):
    """One straight axis-aligned wall, MapBuilder's wall() minus its piers."""
    along_y = abs(x1 - x0) < 1e-6
    length = abs(y1 - y0) if along_y else abs(x1 - x0)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    size = (WALL_T, length, height) if along_y else (length, WALL_T, height)
    L.box_obj("Wall", size, (cx, cy, height / 2), bm_.wall_y if along_y else bm_.wall_x, c, bevel=0.1)
    cap = (WALL_T + 1.0, length, 1.0) if along_y else (length, WALL_T + 1.0, 1.0)
    L.box_obj("WallCap", cap, (cx, cy, height + 0.5), bm_.cap, c, bevel=0.12)
    for frac in (0.36, 0.7):
        cs = (WALL_T + 0.3, length, 0.32) if along_y else (length, WALL_T + 0.3, 0.32)
        L.box_obj("WallCourse", cs, (cx, cy, height * frac), bm_.course, c)


def gate_pier(bm_, c, x, y, height):
    """MapBuilder.gatePier: cream stone, a teal panel on the face towards the
    approaching player (south), gold trim and diamond, an amber lantern."""
    south = y - 4.8
    L.box_obj("GatePierBase", (10.6, 10.6, 2.0), (x, y, 1.0), bm_.cap, c, bevel=0.15)
    L.box_obj("GatePier", (9, 9, height), (x, y, 2 + height / 2), bm_.pier, c, bevel=0.14)
    L.box_obj("GatePierCap", (10.8, 10.8, 1.5), (x, y, 2.75 + height), bm_.cap, c, bevel=0.15)
    panel_h = height - 4
    L.box_obj("GatePanel", (4.8, 0.7, panel_h), (x, south, 2 + height / 2), bm_.teal, c, bevel=0.05)
    for s in (-1, 1):
        L.box_obj("GatePanelTrim", (1.1, 0.8, panel_h + 1.4), (x + s * 3.2, south, 2 + height / 2), bm_.gold, c, bevel=0.05)
    L.box_obj("GateDiamond", (2.7, 0.5, 2.7), (x, south - 0.5, 2 + height * 0.42), bm_.gold, c, rot=(0, math.radians(45), 0), bevel=0.06)
    lamp_y = 4.2 + height
    L.box_obj("LanternBase", (5.4, 5.4, 0.9), (x, y, lamp_y - 1.0), bm_.gold_deep, c, bevel=0.08)
    L.box_obj("LanternBulb", (4.0, 4.0, 3.6), (x, y, lamp_y + 1.0), bm_.gate_lantern, c, bevel=0.1)
    for sx in (-1, 1):
        for sy in (-1, 1):
            L.box_obj("LanternPost", (0.7, 0.7, 3.8), (x + sx * 2.1, y + sy * 2.1, lamp_y + 1.0), bm_.gold_deep, c)
    L.box_obj("LanternCap", (5.6, 5.6, 1.1), (x, y, lamp_y + 3.3), bm_.gold_deep, c, bevel=0.1)


def gate_sign(bm_, c, font, y, title, cost):
    """The banner over a gate: navy board in a gold frame with a diamond
    finial, the name on a navy top panel, the price on a bronze plaque."""
    L.box_obj("BannerBeam", (GATE_W + 2, 1.1, 1.1), (0, y, 25.6), bm_.gold_deep, c, bevel=0.1)
    zc = 26.5
    L.box_obj("GateSign", (30, 0.9, 13), (0, y, zc), bm_.navy, c, bevel=0.1)
    for sx, sz, px, pz in ((31.4, 1.0, 0, 6.5), (31.4, 1.0, 0, -6.5), (1.0, 14.4, 15.2, 0), (1.0, 14.4, -15.2, 0)):
        L.box_obj("SignFrame", (sx, 1.3, sz), (px, y, zc + pz), bm_.gold, c, bevel=0.08)
    L.box_obj("SignFinial", (2.6, 0.9, 2.6), (0, y, zc + 7.6), bm_.gold, c, rot=(0, math.radians(45), 0), bevel=0.08)
    front = y - 0.55
    L.box_obj("TopPanelRim", (29.0, 0.12, 7.1), (0, front - 0.02, zc + 6.5 - 0.39 - 3.38), bm_.gold, c)
    L.box_obj("TopPanel", (28.4, 0.14, 6.5), (0, front - 0.06, zc + 6.5 - 0.39 - 3.38), bm_.navy, c)
    pz = zc + 6.5 - 0.58 * 13 - 0.36 * 13 / 2
    L.box_obj("PlaqueRim", (22.8, 0.12, 5.2), (0, front - 0.02, pz), bm_.gold, c, bevel=0.05)
    L.box_obj("Plaque", (22.2, 0.14, 4.6), (0, front - 0.06, pz), bm_.bronze, c, bevel=0.05)
    L.text_obj("SignTitle", title, font, 4.2, (0, front - 0.2, zc + 2.73), bm_.sign_text, c, width=26.0, extrude=0.03)
    L.text_obj("SignCost", cost, font, 2.9, (0, front - 0.2, pz), bm_.cost_text, c, width=19.0, extrude=0.03)


def barrier(bm_, c, y):
    """Orbit Outpost's locked barrier as MapBuilder hangs it in the north
    divider: pale pane, violet-blue rails and posts, faint diagonals, gold lock."""
    L.box_obj("Gate", (GATE_W, 1.4, 15), (0, y, 8.5), bm_.barrier, c, solid=False)
    for dz in (-7.2, 7.2):
        L.box_obj("GateRail", (GATE_W + 1.2, 1.8, 0.9), (0, y, 8.5 + dz), bm_.edge, c, solid=False)
    for dx in (-GATE_W / 2, GATE_W / 2):
        L.box_obj("GatePost", (1.1, 1.8, 15.4), (dx, y, 8.5), bm_.edge, c, solid=False)
    ang = math.atan2(15, GATE_W)
    for tilt in (1, -1):
        L.box_obj("GateDiagonal", (math.sqrt(GATE_W * GATE_W + 225) - 2, 0.5, 0.35), (0, y - 0.5, 8.5), bm_.edge_faint, c,
                  rot=(0, -tilt * ang, 0), solid=False)
    L.cyl_obj("LockRim", 5.5, 5.5, 0.7, (0, y - 1.2, 8.5), bm_.gold_deep, c, rot=(math.pi / 2, 0, 0), segs=40, solid=False)
    L.cyl_obj("LockBadge", 4.8, 4.8, 0.9, (0, y - 1.5, 8.5), bm_.lock_face, c, rot=(math.pi / 2, 0, 0), segs=40, solid=False)
    L.box_obj("LockBody", (3.2, 0.6, 2.8), (0, y - 2.2, 7.8), bm_.lock_white, c, bevel=0.2, seg=2, solid=False)
    bm = L.new_bm()
    pts = [(-0.75 + 1.5 * (1 - math.cos(t)) / 2, 0, 9.2 + 1.05 * math.sin(t)) for t in [i / 10 * math.pi for i in range(11)]]
    L.add_tube(bm, pts, [0.3] * len(pts), segs=8)
    L.obj_from_bm("LockShackle", bm, [bm_.lock_white], c, loc=(0, y - 2.2, 0), solid=False)
    L.box_obj("LockKeyhole", (0.8, 0.4, 1.1), (0, y - 2.6, 7.7), bm_.gold_deep, c, solid=False)


def lamp(bm_, c, x, y, bulb_mat):
    """MapBuilder.lamp: a 9-stud post with a glowing ball."""
    L.box_obj("LampPost", (0.5, 0.5, 9), (x, y, 4.5), bm_.deck, c, bevel=0.05)
    bm = L.new_bm()
    L.add_sphere(bm, 0.55, (0, 0, 0), segs=12, rings=8)
    L.obj_from_bm("Bulb", bm, [bulb_mat], c, loc=(x, y, 9.4), smooth=True)


def build_walls(bm_, c, font):
    for s in (-1, 1):
        x = s * HALF_W
        wall_run(bm_, c, x, Y_SOUTH_EDGE, x, Y_NORTH_EDGE)
        for y in LATERAL_PIERS:
            _pier(bm_, c, x, y, WALL_H, axis='Y')
    for y in (-HALF_D, HALF_D):
        wall_run(bm_, c, -HALF_W, y, -GATE_W / 2, y)
        wall_run(bm_, c, GATE_W / 2, y, HALF_W, y)
        for x in DIVIDER_PIERS:
            _pier(bm_, c, x, y, WALL_H)
        for x in (-GATE_W / 2, GATE_W / 2):
            gate_pier(bm_, c, x, y, 19)
    # north: Orbit Outpost's gate, locked; south: this region's own, drawn open
    barrier(bm_, c, HALF_D)
    gate_sign(bm_, c, font, HALF_D, "ORBIT OUTPOST", "1M COINS")
    gate_sign(bm_, c, font, -HALF_D, "THUNDERWORKS", "300K COINS")
    # the two region-coloured lamps just inside each gate
    for s in (-1, 1):
        lamp(bm_, c, s * (GATE_W / 2 + 12), -HALF_D + 9, bm_.storm_bulb)
        lamp(bm_, c, s * (GATE_W / 2 + 12), HALF_D + 9, bm_.cosmic_bulb)


# ------------------------------------------------------------------ neighbours
def fir_mesh(name, height, seed, green, snow, bark, tiers=4, segs=7, fat=1.0):
    """The Frostbite round's fir, re-materialled (a Kit-free pine_mesh)."""
    class _K:
        pass
    k = _K()
    k.pine, k.snow, k.bark = green, snow, bark
    return L.pine_mesh(k, name, height, seed, tiers=tiers, segs=segs, green=green, snow=snow, fat=fat)


def build_neighbours(bm_, T, c):
    rng = random.Random(77)
    firs = [fir_mesh("FrostFir%d" % i, 12 + 3 * i, 700 + i, bm_.fir, bm_.snow, T.bark) for i in range(3)]
    # Frostbite Peaks' north band, just over the south divider: stacked
    # snow-capped slate and snowy firs, as the Alpine Outpost build has there
    class _K:
        pass
    kk = _K()
    kk.rock, kk.snow = bm_.slate, bm_.snow
    for i, x in enumerate([-130, -116, -98, -76, -58, 54, 72, 92, 110, 128]):
        h = rng.uniform(5, 10)
        L.rock_obj(kk, "FrostRock", (rng.uniform(9, 14), rng.uniform(6, 9), h), (x + rng.uniform(-3, 3), -110 + rng.uniform(-3, 3), 0),
                   900 + i, c, rock=bm_.slate, snow=bm_.snow, thresh=0.6, shape='box', lump=0.22, solid=False)
    for i, x in enumerate([-134, -123, -106, -88, -66, -44, 40, 62, 84, 102, 120, 134]):
        L.place(rng.choice(firs), "FrostFir", c, (x + rng.uniform(-3, 3), -113 + rng.uniform(-3, 4), 0),
                rot_z=rng.uniform(0, TAU), scale=rng.uniform(0.8, 1.1), solid=False)
    for i in range(10):
        x = rng.choice((-1, 1)) * rng.uniform(26, 150)
        L.drift_obj(kk, "FrostDrift", (rng.uniform(6, 12), rng.uniform(4, 8), rng.uniform(0.8, 1.6)), (x, -108 + rng.uniform(-6, 6), 0),
                    5000 + i, c, mat_=bm_.snow)
    # Orbit Outpost's south band, just over the north divider: lunar
    # boulders and violet crystal clumps
    kk2 = _K()
    kk2.rock, kk2.snow = bm_.orbit_rock, bm_.orbit_top
    for i, x in enumerate([-130, -112, -92, -70, -50, 50, 68, 88, 108, 128]):
        h = rng.uniform(5, 11)
        L.rock_obj(kk2, "OrbitRock", (rng.uniform(9, 15), rng.uniform(7, 10), h), (x + rng.uniform(-3, 3), 114 + rng.uniform(-3, 4), 0),
                   960 + i, c, rock=bm_.orbit_rock, snow=bm_.orbit_top, thresh=0.7, shape='ico', lump=0.25, solid=False)
    for i, x in enumerate([-122, -80, -60, 60, 96, 118]):
        L.crystal_cluster("OrbitCrystal", (x + rng.uniform(-3, 3), 108 + rng.uniform(0, 8), 0), 990 + i, c,
                          [bm_.crystal, bm_.crystal_cyan], count=6, height=rng.uniform(5, 8), radius=0.8, spread=1.8, solid=False)


# ------------------------------------------------------------------ flanks
def build_flanks(T, c, count=120, seed=11, pylons=True):
    """Outside the side walls: a storm heath of dark firs and grey rock,
    with a transmission line marching along each side (art direction; the
    strip is shared grass with the ChainFlanks treeline today)."""
    import tw_kit as K
    rng = random.Random(seed)
    pines = [fir_mesh("HeathFir%d" % i, 11 + 3 * i, 1200 + i, T.pine, T.pine_dk, T.bark, fat=0.95) for i in range(4)]
    class _K:
        pass
    kk = _K()
    kk.rock, kk.snow = T.rock, T.moss
    placed = []
    pylon_xy = []
    if pylons:
        # Cross-arms span X, so the conductors run north-south along the wall.
        pm, info = K.pylon(T, "Pylon")
        ys_pyl = (-66.0, 12.0, 90.0)
        for s in (-1, 1):
            for y in ys_pyl:
                L.place(pm, "FlankPylon", c, (s * 158.0, y, 0), solid=False)
                pylon_xy.append((s * 158.0, y))
        bm = L.new_bm()
        for s in (-1, 1):
            ys = [Y_SOUTH_EDGE] + list(ys_pyl) + [Y_NORTH_EDGE]
            for (ex, ey, ez) in info["ends"]:
                x = s * 158.0 + ex
                for i in range(len(ys) - 1):
                    G.cable(bm, (x, ys[i], ez), (x, ys[i + 1], ez), sag=3.0, radius=0.12, n=18, segs=5)
        L.obj_from_bm("PowerLines", bm, [T.graphite], c, solid=False)
    tries = 0
    while len(placed) < count and tries < count * 40:
        tries += 1
        s = rng.choice((-1, 1))
        x = s * rng.uniform(HALF_W + 4, X_EDGE - 3)
        y = rng.uniform(-HALF_D + 2, HALF_D + 6)
        if any((x - px) ** 2 + (y - py) ** 2 < 5.5 ** 2 for px, py in placed):
            continue
        if any((x - px) ** 2 + (y - py) ** 2 < 9.0 ** 2 for px, py in pylon_xy):
            continue
        placed.append((x, y))
        if rng.random() < 0.62:
            L.place(rng.choice(pines), "HeathFir", c, (x, y, 0), rot_z=rng.uniform(0, TAU), scale=rng.uniform(0.8, 1.3), solid=False)
        else:
            L.rock_obj(kk, "HeathRock", (rng.uniform(5, 10), rng.uniform(5, 9), rng.uniform(3, 6.5)), (x, y, 0),
                       rng.randrange(1 << 30), c, rock=T.rock, snow=T.moss, thresh=0.82, solid=False)


# ------------------------------------------------------------------ scatter
def poisson(rng, n, sampler, min_d, accept=lambda x, y: True, existing=None, tries=60):
    pts = list(existing or [])
    out = []
    for _ in range(n * tries):
        if len(out) >= n:
            break
        x, y = sampler()
        if not accept(x, y):
            continue
        if any((x - px) ** 2 + (y - py) ** 2 < min_d ** 2 for px, py in pts):
            continue
        pts.append((x, y))
        out.append((x, y))
    return out


def in_circle(x, y, cx, cy, r):
    return (x - cx) ** 2 + (y - cy) ** 2 < r * r


def keep_clear(x, y, extra=()):
    """True where scenery may stand: outside the lane, the field and both gate
    approaches, and outside any landmark footprint the option passes in."""
    if abs(x) < LANE_HALF + 4:
        return False
    if abs(x) < FIELD_HALF[0] and abs(y) < FIELD_HALF[1]:
        return False
    if abs(x) < 36 and abs(y) > HALF_D - 16:
        return False
    if abs(x) > IN_X - 1.2 or abs(y) > IN_Y - 1.2:
        return False
    for e in extra:
        if e[0] == 'c' and in_circle(x, y, e[1], e[2], e[3]):
            return False
        if e[0] == 'r' and e[1] <= x <= e[3] and e[2] <= y <= e[4]:
            return False
    return True


def tuft_mesh(T, name, seed, color=None):
    """A clump of wiry heath grass: thin leaning blades."""
    rng = random.Random(seed)
    bm = L.new_bm()
    for i in range(9):
        a = rng.uniform(0, TAU)
        d = rng.uniform(0, 0.6)
        h = rng.uniform(0.9, 1.8)
        lean = rng.uniform(0.1, 0.5)
        base = Vector((math.cos(a) * d, math.sin(a) * d, 0))
        tip = base + Vector((math.cos(a) * lean, math.sin(a) * lean, h))
        G.rod(bm, base, tip, 0.12, segs=4, r2=0.01)
    return L.mesh_from_bm(name, bm, [color or L.mat("tw_tuft", rgb(118, 128, 84), rough=0.9, jitter=0.15, rand=0.12)])


def band_scatter(T, c, rng, extra=(), n=40, spacing=11.0, rock_share=0.55, max_front_h=4.5, clutter=None, clutter_share=0.0):
    """Border-band dressing: a grey rock or two, heath tufts and pebbles,
    and now and then an item of yard clutter the option passes in."""
    class _K:
        pass
    kk = _K()
    kk.rock, kk.snow = T.rock, T.moss
    tufts = [tuft_mesh(T, "Tuft%d" % i, 40 + i) for i in range(3)]

    def sampler():
        side = rng.random()
        if side < 0.72:
            s = rng.choice((-1, 1))
            return s * rng.uniform(FIELD_HALF[0] + 4, IN_X - 3), rng.uniform(-IN_Y + 3, IN_Y - 3)
        yy = rng.uniform(FIELD_HALF[1] + 4, IN_Y - 3) if side < 0.9 else -rng.uniform(FIELD_HALF[1] + 5, IN_Y - 3)
        return rng.uniform(-IN_X + 3, IN_X - 3), yy

    centres = poisson(rng, n, sampler, spacing, accept=lambda x, y: keep_clear(x, y, extra))
    for (x, y) in centres:
        front = y < -HALF_D + 30
        wall_d = min(IN_X - abs(x), IN_Y - abs(y))
        near = max(0.0, 1.0 - wall_d / 40.0)
        if rng.random() < rock_share:
            rh = (2.2 + 5.0 * near + rng.uniform(0, 2.5))
            if front:
                rh = min(rh, max_front_h)
            rw = rh * rng.uniform(1.2, 1.7)
            L.rock_obj(kk, "BandRock", (rw, rw * rng.uniform(0.7, 1.0), rh), (x, y, 0), rng.randrange(1 << 30), c,
                       rock=T.rock if rng.random() < 0.6 else T.rock_dk, snow=T.moss, thresh=0.86, lump=0.24)
        elif clutter and rng.random() < clutter_share / max(0.01, 1 - rock_share):
            clutter(x, y, rng)
        for j in range(rng.randint(2, 4)):
            a = rng.uniform(0, TAU)
            d = rng.uniform(1.5, 4.5)
            px, py = x + math.cos(a) * d, y + math.sin(a) * d
            if keep_clear(px, py, extra):
                L.place(rng.choice(tufts), "Tuft", c, (px, py, 0), rot_z=rng.uniform(0, TAU), scale=rng.uniform(0.8, 1.4), solid=False)
    return centres


def field_marks(T, c, rng, n=10):
    """A few oil stains and patched squares on the open floor: flush,
    walkable, and never yellow."""
    stain = L.mat("tw_stain", rgb(62, 67, 80), rough=0.6, coat=0.2)
    patch = L.mat("tw_patch", rgb(86, 92, 106), rough=0.9, jitter=0.03)
    for i in range(n):
        x = rng.choice((-1, 1)) * rng.uniform(LANE_HALF + 8, FIELD_HALF[0] - 4)
        y = rng.uniform(-FIELD_HALF[1] + 6, FIELD_HALF[1] - 6)
        if rng.random() < 0.5:
            bm = L.new_bm()
            L.add_cyl(bm, 1.0, 1.0, 0.02, (0, 0, 0.012), segs=20, scale=(rng.uniform(2, 4), rng.uniform(1.5, 3), 1))
            L.obj_from_bm("OilStain", bm, [stain], c, loc=(x, y, 0), rot=(0, 0, rng.uniform(0, TAU)), solid=False)
        else:
            L.box_obj("Patch", (rng.uniform(5, 9), rng.uniform(4, 7), 0.03), (x, y, 0.015), patch, c, rot=(0, 0, rng.choice((0, math.pi / 2))), solid=False)


# ------------------------------------------------------------------ creatures
class CreatureMats:
    def __init__(self):
        self.sprout = L.mat("c_sprout", rgb(120, 200, 90), rough=0.55, sss=0.08)
        self.sprout_dk = L.mat("c_sprout_dk", rgb(84, 150, 70), rough=0.6)
        self.spark = L.mat("c_spark", rgb(255, 235, 90), rough=0.3, emit=1.2, emit_color=rgb(255, 230, 90))
        self.spark_tip = L.mat("c_spark_tip", rgb(255, 255, 200), emit=3.0)
        self.raccoon = L.mat("c_raccoon", rgb(96, 96, 116), rough=0.6)
        self.raccoon_dk = L.mat("c_raccoon_dk", rgb(52, 52, 66), rough=0.6)
        self.mask = L.mat("c_mask", rgb(240, 240, 240), rough=0.6)
        self.bolt = L.mat("c_bolt", rgb(255, 230, 80), rough=0.35, emit=0.8, emit_color=rgb(255, 226, 80))
        self.thumper = L.mat("c_thumper", rgb(74, 74, 100), rough=0.65)
        self.thumper_face = L.mat("c_thumper_face", rgb(122, 120, 148), rough=0.6)
        self.cloud = L.mat("c_cloud", rgb(226, 230, 244), rough=0.75, sss=0.1)
        self.behemoth = L.mat("c_behemoth", rgb(54, 54, 86), rough=0.6)
        self.behemoth_mane = L.mat("c_behemoth_mane", rgb(146, 156, 206), rough=0.65)
        self.antler = L.mat("c_antler", rgb(255, 240, 100), rough=0.25, emit=2.4, emit_color=rgb(255, 236, 110))
        self.eye = L.mat("c_eye", rgb(20, 20, 30), rough=0.1, coat=1.0)
        self.shine = L.mat("c_shine", rgb(255, 255, 255), emit=2.0)


def _eyes(bm, x, y_off, z, r, mi_eye, mi_shine):
    for s in (-1, 1):
        L.add_sphere(bm, r, (x, s * y_off, z), segs=10, rings=8, mi=mi_eye)
        L.add_sphere(bm, r * 0.32, (x + r * 0.55, s * y_off - s * r * 0.1, z + r * 0.45), segs=6, rings=4, mi=mi_shine)


def sprout(cm, c, loc, yaw, scale=1.0):
    """Static Sprout: a green bulb on root feet with electric hair standing
    straight up and two leaves."""
    rng = random.Random(21)
    bm = L.new_bm()
    mats = [cm.sprout, cm.sprout_dk, cm.spark, cm.spark_tip, cm.eye, cm.shine]
    L.add_sphere(bm, 1.0, (0, 0, 1.05), scale=(1.0, 1.0, 1.05), segs=14, rings=10, mi=0)
    for s in (-1, 1):
        L.add_sphere(bm, 0.34, (0.2, s * 0.5, 0.2), scale=(1.3, 1, 0.6), segs=8, rings=6, mi=1)
        L.add_sphere(bm, 0.5, (-0.1, s * 1.15, 1.3), scale=(0.5, 1.4, 0.18), rot=(s * 0.5, 0, 0), segs=10, rings=6, mi=1)
    for i in range(9):
        a = i / 9 * TAU
        tilt = 0.35 + 0.2 * (i % 2)
        base = Vector((math.cos(a) * 0.35, math.sin(a) * 0.35, 1.85))
        tip = base + Vector((math.cos(a) * tilt, math.sin(a) * tilt, rng.uniform(1.0, 1.5)))
        G.rod(bm, base, tip, 0.2, segs=5, mi=2, r2=0.02)
        L.add_sphere(bm, 0.09, tuple(tip), segs=6, rings=4, mi=3)
    _eyes(bm, 0.86, 0.34, 1.25, 0.15, 4, 5)
    return L.obj_from_bm("StaticSprout", bm, mats, c, loc=loc, rot=(0, 0, yaw), scale=(scale,) * 3, solid=False, smooth=True, tag="creature")


def raccoon(cm, c, loc, yaw, scale=1.0):
    """Zap Raccoon: grey body, white mask with a dark band, and a big tail
    ringed with lightning yellow."""
    bm = L.new_bm()
    mats = [cm.raccoon, cm.raccoon_dk, cm.mask, cm.bolt, cm.eye, cm.shine]
    L.add_sphere(bm, 1.0, (0, 0, 1.0), scale=(1.5, 0.95, 0.9), segs=14, rings=10, mi=0)
    L.add_sphere(bm, 0.8, (1.4, 0, 1.6), segs=14, rings=10, mi=0)
    L.add_sphere(bm, 0.5, (1.95, 0, 1.45), scale=(1.0, 0.95, 0.75), segs=10, rings=8, mi=2)
    L.add_sphere(bm, 0.36, (1.72, 0, 1.75), scale=(0.6, 1.9, 0.55), segs=10, rings=6, mi=1)
    L.add_sphere(bm, 0.13, (2.4, 0, 1.5), segs=6, rings=4, mi=1)
    for s in (-1, 1):
        L.add_sphere(bm, 0.3, (1.25, s * 0.55, 2.3), scale=(0.6, 1.0, 1.1), segs=8, rings=6, mi=1)
        for fx in (-0.9, 0.8):
            L.add_sphere(bm, 0.3, (fx, s * 0.55, 0.28), segs=8, rings=6, mi=1)
    _eyes(bm, 1.98, 0.3, 1.78, 0.13, 4, 5)
    # the tail: rings of grey and yellow sweeping up behind
    pts = [(-1.2, 0, 1.2), (-2.0, 0, 1.6), (-2.5, 0, 2.5), (-2.4, 0, 3.4), (-1.9, 0, 4.0)]
    for i in range(len(pts) - 1):
        a, b = Vector(pts[i]), Vector(pts[i + 1])
        for k in range(3):
            p = a.lerp(b, (k + 0.5) / 3)
            r = 0.62 - 0.05 * i
            L.add_sphere(bm, r, tuple(p), segs=10, rings=8, mi=3 if (i * 3 + k) % 3 == 1 else 0)
    return L.obj_from_bm("ZapRaccoon", bm, mats, c, loc=loc, rot=(0, 0, yaw), scale=(scale,) * 3, solid=False, smooth=True, tag="creature")


def thumper(cm, c, loc, yaw, scale=1.0):
    """Thunder Thumper: a storm gorilla with two puffy cloud fists and a bolt
    on its chest."""
    rng = random.Random(9)
    bm = L.new_bm()
    mats = [cm.thumper, cm.thumper_face, cm.cloud, cm.bolt, cm.eye, cm.shine]
    L.add_sphere(bm, 1.0, (0, 0, 2.3), scale=(1.1, 1.3, 1.25), segs=16, rings=12, mi=0)
    L.add_sphere(bm, 0.75, (0.35, 0, 3.75), segs=14, rings=10, mi=0)
    L.add_sphere(bm, 0.5, (0.85, 0, 3.6), scale=(0.7, 1.1, 0.8), segs=12, rings=8, mi=1)
    L.add_sphere(bm, 0.55, (0.9, 0, 2.5), scale=(0.35, 0.9, 0.9), segs=10, rings=8, mi=1)
    _eyes(bm, 0.98, 0.3, 3.95, 0.13, 4, 5)
    for s in (-1, 1):
        L.add_tube(bm, [(0.2, s * 1.1, 3.0), (0.6, s * 1.6, 2.0), (0.9, s * 1.7, 1.1)], [0.42, 0.38, 0.34], segs=8, mi=0)
        for fx in (-0.4, 0.3):
            L.add_cyl(bm, 0.4, 0.34, 1.2, (fx, s * 0.6, 0.6), segs=8, mi=0)
        for k in range(6):
            off = Vector((rng.uniform(-0.5, 0.5), rng.uniform(-0.45, 0.45), rng.uniform(-0.35, 0.45)))
            L.add_sphere(bm, rng.uniform(0.42, 0.62), tuple(Vector((1.0, s * 1.75, 0.9)) + off), segs=10, rings=8, mi=2)
    import tw_kit as K
    K.bolt_emblem(bm, (1.03, 0, 2.5), 0.9, 0.06, mi=3, rot_z=math.pi / 2)
    return L.obj_from_bm("ThunderThumper", bm, mats, c, loc=loc, rot=(0, 0, yaw), scale=(scale,) * 3, solid=False, smooth=True, tag="creature")


def behemoth(cm, c, loc, yaw, scale=1.0):
    """Boltjaw Behemoth: the Legendary, a heavy four-legged storm beast with
    a pale mane and jagged glowing lightning antlers."""
    rng = random.Random(4)
    bm = L.new_bm()
    mats = [cm.behemoth, cm.behemoth_mane, cm.antler, cm.eye, cm.shine]
    L.add_sphere(bm, 1.0, (-0.3, 0, 2.6), scale=(2.3, 1.35, 1.35), segs=16, rings=12, mi=0)
    L.add_ico(bm, 1.5, (1.2, 0, 3.0), scale=(1.0, 1.15, 1.1), subdiv=2, mi=1, rng=rng, lump=0.12)
    L.add_sphere(bm, 0.95, (2.5, 0, 2.9), scale=(1.1, 0.9, 0.85), segs=14, rings=10, mi=0)
    L.add_sphere(bm, 0.55, (3.3, 0, 2.55), scale=(0.9, 0.8, 0.6), segs=10, rings=8, mi=0)
    L.add_box(bm, (1.2, 1.1, 0.3), (3.1, 0, 2.05), rot=(0, 0.25, 0), mi=1)
    _eyes(bm, 3.05, 0.5, 3.25, 0.16, 3, 4)
    for s in (-1, 1):
        for fx in (-1.8, 1.0):
            L.add_cyl(bm, 0.5, 0.42, 1.8, (fx, s * 0.75, 0.9), segs=10, mi=0)
        # jagged antlers: zigzag tines climbing from the brow
        pts = [(2.3, s * 0.55, 3.6), (2.1, s * 1.1, 4.5), (2.5, s * 1.25, 5.0), (2.2, s * 1.8, 5.9), (2.6, s * 2.0, 6.6)]
        L.add_tube(bm, pts, [0.26, 0.22, 0.2, 0.16, 0.05], segs=6, mi=2)
        L.add_tube(bm, [(2.5, s * 1.25, 5.0), (3.1, s * 1.6, 5.5), (3.0, s * 1.9, 6.1)], [0.16, 0.12, 0.04], segs=5, mi=2)
        L.add_tube(bm, [(2.15, s * 1.1, 4.5), (1.7, s * 1.6, 5.0), (1.9, s * 2.0, 5.5)], [0.15, 0.1, 0.04], segs=5, mi=2)
    L.add_tube(bm, [(-2.4, 0, 3.0), (-3.0, 0, 2.6), (-3.4, 0, 2.9), (-3.7, 0, 2.4)], [0.2, 0.18, 0.15, 0.3], segs=6, mi=1)
    return L.obj_from_bm("BoltjawBehemoth", bm, mats, c, loc=loc, rot=(0, 0, yaw), scale=(scale,) * 3, solid=False, smooth=True, tag="creature")


# The same six positions in every option, all on open floor and none on the
# lane. Enlarged about 3x from game scale so they read at this distance.
CREATURES = [
    ("sprout", (-60, 36), math.radians(-25), 2.3),
    ("thumper", (64, 50), math.radians(200), 1.9),
    ("raccoon", (-32, -30), math.radians(25), 2.2),
    ("sprout", (72, -20), math.radians(160), 2.3),
    ("raccoon", (-74, -54), math.radians(15), 2.1),
    ("behemoth", (40, 14), math.radians(205), 1.8),
]


def build_creatures(c, positions=CREATURES):
    cm = CreatureMats()
    fns = {"sprout": sprout, "raccoon": raccoon, "thumper": thumper, "behemoth": behemoth}
    for kind, (x, y), yaw, s in positions:
        fns[kind](cm, c, (x, y, 0), yaw, s)


# ------------------------------------------------------------------ Astra's kit
PROPS_V1 = "C:/Users/rahul/orca/Catch-a-Catastrophe/assets/thunderworks/props-v1/props.blend"


def load_props_v1():
    """Append the eight delivered Thunderworks meshes (TW_Transformer ...)
    read-only, so the substation bays can use the real kit. Returns
    {name: mesh}; empty if the file is missing."""
    import os
    if not os.path.exists(PROPS_V1):
        return {}
    names = ["TW_Transformer", "TW_Ceramic_Insulator", "TW_Cable_Reel", "TW_Capacitor_Bank",
             "TW_Switch_Cabinet", "TW_Vent_Housing", "TW_Conduit_Elbow", "TW_Storm_Bollard"]
    with bpy.data.libraries.load(PROPS_V1, link=False) as (df, dt):
        dt.objects = [n for n in names if n in df.objects]
    out = {}
    for ob in dt.objects:
        if ob is None:
            continue
        me = ob.data
        # Rotation and scale only: the gallery file spreads the props out
        # by object location, and the mesh itself is already ground-centred.
        me2 = me.copy()
        me2.transform(ob.matrix_basis.to_3x3().to_4x4())
        out[ob.name] = me2
    return out


# ------------------------------------------------------------------ measurement
def clear_floor_stats(grid=1.0):
    """How much of the interior no solid scenery stands over, measured from
    each solid object's evaluated vertices (convex hull of the XY
    projection)."""
    import numpy as np
    xs = np.arange(-IN_X + grid / 2, IN_X, grid)
    ys = np.arange(-IN_Y + grid / 2, IN_Y, grid)
    occ = np.zeros((len(ys), len(xs)), dtype=bool)
    dg = bpy.context.evaluated_depsgraph_get()
    count = 0
    lane_hits = []
    field_hits = []
    for ob in bpy.context.scene.objects:
        if ob.type != 'MESH' or not ob.get("solid", 0):
            continue
        ev = ob.evaluated_get(dg)
        me = ev.to_mesh()
        n = len(me.vertices)
        if n == 0:
            ev.to_mesh_clear()
            continue
        co = np.empty(n * 3, dtype=np.float64)
        me.vertices.foreach_get("co", co)
        ev.to_mesh_clear()
        co = co.reshape(-1, 3)
        M = np.array(ob.matrix_world)
        w = co @ M[:3, :3].T + M[:3, 3]
        w = w[w[:, 2] > 0.35]
        if len(w) < 3:
            continue
        p = w[:, :2]
        if p[:, 0].max() < -IN_X or p[:, 0].min() > IN_X or p[:, 1].max() < -IN_Y or p[:, 1].min() > IN_Y:
            continue
        hull = _hull(p)
        x0, x1 = p[:, 0].min(), p[:, 0].max()
        y0, y1 = p[:, 1].min(), p[:, 1].max()
        ix = np.where((xs >= x0) & (xs <= x1))[0]
        iy = np.where((ys >= y0) & (ys <= y1))[0]
        if len(ix) == 0 or len(iy) == 0:
            continue
        gx, gy = np.meshgrid(xs[ix], ys[iy])
        inside = np.ones(gx.shape, dtype=bool)
        m = len(hull)
        for i in range(m):
            ax, ay = hull[i]
            bx, by = hull[(i + 1) % m]
            inside &= ((bx - ax) * (gy - ay) - (by - ay) * (gx - ax)) >= -1e-9
        occ[np.ix_(iy, ix)] |= inside
        count += 1
        if inside.any():
            sx_, sy_ = gx[inside], gy[inside]
            if (np.abs(sx_) < LANE_HALF).any():
                lane_hits.append(ob.name)
            if ((np.abs(sx_) < FIELD_HALF[0]) & (np.abs(sy_) < FIELD_HALF[1])).any():
                field_hits.append(ob.name)
    total = occ.size
    fx = (np.abs(xs) < FIELD_HALF[0])
    fy = (np.abs(ys) < FIELD_HALF[1])
    field = occ[np.ix_(fy, fx)]
    lx = np.abs(xs) < LANE_HALF
    lane = occ[:, lx]
    return {
        "interior_clear_pct": round(100.0 * (1 - occ.sum() / total), 1),
        "field_rect": [2 * FIELD_HALF[0], 2 * FIELD_HALF[1]],
        "field_clear_pct": round(100.0 * (1 - field.sum() / field.size), 1),
        "field_intruders": sorted(set(field_hits))[:16],
        "lane_width": 2 * LANE_HALF,
        "lane_blocked_cells": int(lane.sum()),
        "lane_blockers": sorted(set(lane_hits))[:12],
        "solid_objects": count,
    }


def _hull(p):
    pts = sorted(set(map(tuple, p.round(3))))
    if len(pts) < 3:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for q in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], q) <= 0:
            lower.pop()
        lower.append(q)
    for q in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], q) <= 0:
            upper.pop()
        upper.append(q)
    return lower[:-1] + upper[:-1]

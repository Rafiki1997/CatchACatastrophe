# The part of every Frostbite Peaks mockup that is not a design choice: the
# render setup, the cell floor and lane, MapBuilder's walls, piers, gates,
# barrier and banners at their real coordinates, the neighbouring cells'
# glimpses, the flank treeline, the six frost creatures, and the clear-floor
# measurement. Every MapBuilder number below is quoted from
# src/server/Map/MapBuilder.luau (buildChainWalls, gatePier, wall, lamp,
# buildRegion) and converted to scene axes: Roblox region-local (x, y, z) is
# (x, -z, y) here.
import bpy
import bmesh
import math
import random
from mathutils import Vector, Matrix

import fb_lib as L
from fb_lib import rgb, TAU

# ------------------------------------------------------------------ layout
HALF_W, HALF_D = 140.0, 100.0          # CELL_W, CELL_D = 280, 200
WALL_T, WALL_H = 3.0, 9.0
GATE_W = 44.0
IN_X, IN_Y = HALF_W - WALL_T / 2, HALF_D - WALL_T / 2   # inner faces, 138.5 / 98.5
Y_SOUTH_EDGE, Y_NORTH_EDGE = -118.0, 128.0              # how much of the neighbours shows
X_EDGE = 172.0
# Lateral wall piers: the side walls run the whole 1200-stud chain, so their
# piers fall every 1200/27 = 44.44 studs from the island edge. In this cell
# that puts them at these y values (the last is the north divider corner).
LATERAL_PIERS = [-77.78, -33.33, 11.11, 55.56, 100.0]
# Divider walls (-140 .. -22 and 22 .. 140) carry two piers each.
DIVIDER_PIERS = [-100.67, -61.33, 61.33, 100.67]

# Design envelope the options share, measured the same way the three rebuilt
# regions measure theirs (Cinder: field half 92 x 72, band 44 deep).
LANE_HALF = 12.0
FIELD_HALF = (92.0, 70.0)

WALL_STONE = rgb(228, 216, 192)
WALL_CAP = rgb(203, 189, 163)
WALL_PIER = rgb(216, 203, 179)
LANTERN = rgb(255, 214, 140)
IRON = rgb(64, 58, 56)
TEAL_PANEL = rgb(38, 78, 122)
NAVY = rgb(30, 52, 92)
BRONZE = rgb(120, 82, 48)
DECK = rgb(120, 126, 142)
FROST_COLOR = rgb(170, 230, 255)
STORM_COLOR = rgb(255, 230, 90)
# Thunderworks' barrier edges: def.color lerped 0.55 toward (150, 236, 255)
STORM_EDGE = rgb(197, 233, 181)
CINDER_GROUND = rgb(238, 134, 86)
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
    sc.cycles.transparent_max_bounces = 8
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


def setup_world(sky=(0.42, 0.58, 0.96), strength=0.5):
    sc = bpy.context.scene
    w = bpy.data.worlds.new("World")
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (*sky, 1.0)
    bg.inputs[1].default_value = strength
    sc.world = w


def setup_sun(direction=(0.72, 0.15, -0.66), energy=7.5, angle=4.0, color=(1.0, 0.95, 0.87)):
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


def setup_camera(pitch=33.0, lens=200.0, target=(0.0, 4.0, 4.0), dist=1850.0, shift_x=0.0, shift_y=0.0, ortho=None):
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
        self.edge = L.mat("barrier_edge", STORM_EDGE, emit=3.0)
        self.edge_faint = L.mat("barrier_faint", STORM_EDGE, emit=2.0, alpha=0.5)
        self.lock_face = L.mat("lock_face", rgb(236, 180, 60), emit=1.2, emit_color=rgb(236, 176, 58), rough=0.3)
        self.lock_white = L.mat("lock_white", rgb(252, 248, 238), rough=0.4)
        self.deck = L.mat("deck", DECK, rough=0.5, metal=0.3)
        self.frost_bulb = L.mat("frost_bulb", FROST_COLOR, emit=5.0)
        self.storm_bulb = L.mat("storm_bulb", STORM_COLOR, emit=5.0)
        self.cinder = L.mat("cinder_ground", CINDER_GROUND, rough=0.9, jitter=0.05)
        self.cinder_rock = L.mat("cinder_rock", rgb(196, 96, 66), rough=0.85, jitter=0.12, rand=0.1)
        self.cinder_top = L.mat("cinder_top", rgb(222, 128, 86), rough=0.85, jitter=0.1)
        self.cactus = L.mat("cactus", rgb(88, 150, 88), rough=0.7, jitter=0.1)
        self.storm_ground = L.mat("storm_ground", STORM_GROUND, rough=0.85, jitter=0.04)
        self.storm_teal = L.mat("storm_teal", rgb(40, 132, 140), rough=0.5, metal=0.3)
        self.storm_cream = L.mat("storm_cream", rgb(236, 226, 204), rough=0.5)
        self.copper = L.mat("copper", rgb(196, 112, 64), rough=0.35, metal=1.0)
        self.slab_side = L.mat("slab_side", rgb(132, 140, 156), rough=0.9, jitter=0.08)


def snow_ground_mat(name, c_field, c_patch, c_lane, lane_half=LANE_HALF, lane_strength=0.85,
                    streak_color=None, rough=0.82):
    """The catching floor: soft patches, faint wind streaks running east-west,
    and a packed-snow lane blended in on |x| < lane_half."""
    m, nt, b = L._new_mat(name)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 0.022
    nz.inputs["Detail"].default_value = 2.0
    nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.36
    ramp.color_ramp.elements[0].color = c_field
    ramp.color_ramp.elements[1].position = 0.66
    ramp.color_ramp.elements[1].color = c_patch
    nt.links.new(nz.outputs["Factor"], ramp.inputs["Fac"])
    col = ramp.outputs["Color"]
    # wind streaks
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (0.035, 0.55, 1.0)
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    nz2 = nt.nodes.new("ShaderNodeTexNoise")
    nz2.inputs["Scale"].default_value = 1.0
    nz2.inputs["Detail"].default_value = 1.0
    nt.links.new(mp.outputs["Vector"], nz2.inputs["Vector"])
    r2 = nt.nodes.new("ShaderNodeMapRange")
    r2.inputs["From Min"].default_value = 0.58
    r2.inputs["From Max"].default_value = 0.72
    r2.inputs["To Min"].default_value = 0.0
    r2.inputs["To Max"].default_value = 0.55
    nt.links.new(nz2.outputs["Factor"], r2.inputs["Value"])
    mx = nt.nodes.new("ShaderNodeMix")
    mx.data_type = 'RGBA'
    nt.links.new(r2.outputs[0], L.sock(mx.inputs, "Factor_Float"))
    nt.links.new(col, L.sock(mx.inputs, "A_Color"))
    L.sock(mx.inputs, "B_Color").default_value = streak_color or (1.0, 1.0, 1.0, 1.0)
    col = L.sock(mx.outputs, "Result_Color")
    # lane
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    ab = nt.nodes.new("ShaderNodeMath")
    ab.operation = 'ABSOLUTE'
    nt.links.new(sep.outputs['X'], ab.inputs[0])
    r3 = nt.nodes.new("ShaderNodeMapRange")
    r3.inputs["From Min"].default_value = lane_half - 2.5
    r3.inputs["From Max"].default_value = lane_half + 2.5
    r3.inputs["To Min"].default_value = lane_strength
    r3.inputs["To Max"].default_value = 0.0
    nt.links.new(ab.outputs[0], r3.inputs["Value"])
    # only inside the cell, so the neighbours' floors are untouched
    ay = nt.nodes.new("ShaderNodeMath")
    ay.operation = 'ABSOLUTE'
    nt.links.new(sep.outputs['Y'], ay.inputs[0])
    lt = nt.nodes.new("ShaderNodeMath")
    lt.operation = 'LESS_THAN'
    lt.inputs[1].default_value = HALF_D + 2
    nt.links.new(ay.outputs[0], lt.inputs[0])
    mul = nt.nodes.new("ShaderNodeMath")
    mul.operation = 'MULTIPLY'
    nt.links.new(r3.outputs[0], mul.inputs[0])
    nt.links.new(lt.outputs[0], mul.inputs[1])
    mx2 = nt.nodes.new("ShaderNodeMix")
    mx2.data_type = 'RGBA'
    nt.links.new(mul.outputs[0], L.sock(mx2.inputs, "Factor_Float"))
    nt.links.new(col, L.sock(mx2.inputs, "A_Color"))
    L.sock(mx2.inputs, "B_Color").default_value = c_lane
    nt.links.new(L.sock(mx2.outputs, "Result_Color"), b.inputs["Base Color"])
    # fine bump
    nz3 = nt.nodes.new("ShaderNodeTexNoise")
    nz3.inputs["Scale"].default_value = 0.6
    nz3.inputs["Detail"].default_value = 4.0
    nt.links.new(tc.outputs["Object"], nz3.inputs["Vector"])
    bp = nt.nodes.new("ShaderNodeBump")
    bp.inputs["Strength"].default_value = 0.06
    nt.links.new(nz3.outputs["Factor"], bp.inputs["Height"])
    nt.links.new(bp.outputs["Normal"], b.inputs["Normal"])
    b.inputs["Roughness"].default_value = rough
    b.inputs["Subsurface Weight"].default_value = 0.05
    L._M[name] = m
    return m


# ------------------------------------------------------------------ ground
def build_ground(k, bm_, c, field_mat, outer_mat=None):
    """Cell floor, the flank strips, both neighbours' floors, and the
    diorama's cut sides."""
    L.box_obj("CellFloor", (HALF_W * 2 + 2, HALF_D * 2, 2.0), (0, 0, -1.0), field_mat, c, solid=False)
    om = outer_mat or field_mat
    for s in (-1, 1):
        w = X_EDGE - HALF_W - 1
        L.box_obj("FlankFloor", (w, HALF_D * 2, 2.0), (s * (HALF_W + 1 + w / 2), 0, -1.02), om, c, solid=False)
    dS = -HALF_D - Y_SOUTH_EDGE
    L.box_obj("CinderFloor", (X_EDGE * 2, dS, 2.0), (0, Y_SOUTH_EDGE + dS / 2, -1.01), bm_.cinder, c, solid=False)
    dN = Y_NORTH_EDGE - HALF_D
    L.box_obj("StormFloor", (X_EDGE * 2, dN, 2.0), (0, HALF_D + dN / 2, -1.01), bm_.storm_ground, c, solid=False)
    # the diorama block beneath, so the cut edge reads as ground, not a sheet
    # (no base block: the ground plates' own 2-stud edges are the diorama's cut)


# ------------------------------------------------------------------ walls
def _pier(bm_, c, x, y, height, snow_mat=None, axis='X'):
    top = height + 3.2
    L.box_obj("WallPier", (5.2, 5.2, top), (x, y, top / 2), bm_.pier if axis == 'X' else bm_.pier_y, c, bevel=0.14)
    L.box_obj("LanternBase", (3.4, 3.4, 0.7), (x, y, top + 0.35), bm_.iron, c, bevel=0.08)
    L.box_obj("LanternBulb", (2.4, 2.4, 2.4), (x, y, top + 1.9), bm_.lantern, c, bevel=0.1)
    for sx in (-1, 1):
        for sy in (-1, 1):
            L.box_obj("LanternRib", (0.28, 0.28, 2.4), (x + sx * 1.2, y + sy * 1.2, top + 1.9), bm_.iron, c)
    L.box_obj("LanternCap", (3.8, 3.8, 0.8), (x, y, top + 3.5), bm_.iron, c, bevel=0.1)
    if snow_mat is not None:
        L.box_obj("PierSnow", (3.9, 3.9, 0.5), (x, y, top + 4.05), snow_mat, c, bevel=0.2, seg=2, solid=False)


def wall_run(bm_, c, x0, y0, x1, y1, height=WALL_H, snow_mat=None, snow_range=None, rng=None):
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
    if snow_mat is not None:
        # a lumpy snow line along the cap, only over the stretch asked for
        a0, a1 = snow_range if snow_range else ((y0, y1) if along_y else (x0, x1))
        a0, a1 = min(a0, a1), max(a0, a1)
        t = a0
        while t < a1 - 0.5:
            seg = min(a1 - t, (rng.uniform(5, 11) if rng else 8))
            mid = t + seg / 2
            th = rng.uniform(0.45, 0.8) if rng else 0.6
            size2 = (WALL_T + 0.7, seg + 0.4, th) if along_y else (seg + 0.4, WALL_T + 0.7, th)
            at = (cx, mid, height + 1.0 + th / 2 - 0.1) if along_y else (mid, cy, height + 1.0 + th / 2 - 0.1)
            L.box_obj("WallSnow", size2, at, snow_mat, c, bevel=min(0.3, th / 2 - 0.02), seg=2, solid=False)
            t += seg


def gate_pier(bm_, c, x, y, height, snow_mat=None):
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
    if snow_mat is not None:
        L.box_obj("CapSnow", (5.4, 5.4, 0.6), (x, y, lamp_y + 4.1), snow_mat, c, bevel=0.25, seg=2, solid=False)
        L.box_obj("CapSnow", (10.2, 10.2, 0.5), (x, y, 3.5 + height + 0.25), snow_mat, c, bevel=0.2, seg=2, solid=False)


def gate_sign(bm_, c, font, y, title, cost, snow_mat=None):
    """The banner over a gate: navy board in a gold frame with a diamond
    finial, the name on a navy top panel, the price on a bronze plaque."""
    L.box_obj("BannerBeam", (GATE_W + 2, 1.1, 1.1), (0, y, 25.6), bm_.gold_deep, c, bevel=0.1)
    zc = 26.5
    L.box_obj("GateSign", (30, 0.9, 13), (0, y, zc), bm_.navy, c, bevel=0.1)
    for sx, sz, px, pz in ((31.4, 1.0, 0, 6.5), (31.4, 1.0, 0, -6.5), (1.0, 14.4, 15.2, 0), (1.0, 14.4, -15.2, 0)):
        L.box_obj("SignFrame", (sx, 1.3, sz), (px, y, zc + pz), bm_.gold, c, bevel=0.08)
    L.box_obj("SignFinial", (2.6, 0.9, 2.6), (0, y, zc + 7.6), bm_.gold, c, rot=(0, math.radians(45), 0), bevel=0.08)
    front = y - 0.55
    # top panel (0.96 x 0.52 of the face) and plaque (0.74 x 0.36), both gold-stroked
    L.box_obj("TopPanelRim", (29.0, 0.12, 7.1), (0, front - 0.02, zc + 6.5 - 0.39 - 3.38), bm_.gold, c)
    L.box_obj("TopPanel", (28.4, 0.14, 6.5), (0, front - 0.06, zc + 6.5 - 0.39 - 3.38), bm_.navy, c)
    pz = zc + 6.5 - 0.58 * 13 - 0.36 * 13 / 2
    L.box_obj("PlaqueRim", (22.8, 0.12, 5.2), (0, front - 0.02, pz), bm_.gold, c, bevel=0.05)
    L.box_obj("Plaque", (22.2, 0.14, 4.6), (0, front - 0.06, pz), bm_.bronze, c, bevel=0.05)
    L.text_obj("SignTitle", title, font, 4.2, (0, front - 0.2, zc + 2.73), bm_.sign_text, c, width=26.0, extrude=0.03)
    L.text_obj("SignCost", cost, font, 2.9, (0, front - 0.2, pz), bm_.cost_text, c, width=19.0, extrude=0.03)
    if snow_mat is not None:
        L.box_obj("SignSnow", (30.2, 1.8, 0.55), (0, y, zc + 7.2), snow_mat, c, bevel=0.22, seg=2, solid=False)


def barrier(bm_, c, y):
    """Thunderworks' locked barrier as MapBuilder hangs it in the north
    divider: pale pane, bright rails and posts, faint diagonals, gold lock."""
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
    # the shackle as an arch rather than MapBuilder's 2x2 block, which is how the Gui-less part reads from afar
    bm = L.new_bm()
    pts = [(-0.75 + 1.5 * (1 - math.cos(t)) / 2, 0, 9.2 + 1.05 * math.sin(t)) for t in [i / 10 * math.pi for i in range(11)]]
    L.add_tube(bm, pts, [0.3] * len(pts), segs=8)
    L.obj_from_bm("LockShackle", bm, [bm_.lock_white], c, loc=(0, y - 2.2, 0), solid=False)
    L.box_obj("LockKeyhole", (0.8, 0.4, 1.1), (0, y - 2.6, 7.7), bm_.gold_deep, c, solid=False)


def lamp(bm_, c, x, y, bulb_mat, snow_mat=None):
    """MapBuilder.lamp: a 9-stud post with a glowing ball."""
    L.box_obj("LampPost", (0.5, 0.5, 9), (x, y, 4.5), bm_.deck, c, bevel=0.05)
    bm = L.new_bm()
    L.add_sphere(bm, 0.55, (0, 0, 0), segs=12, rings=8)
    L.obj_from_bm("Bulb", bm, [bulb_mat], c, loc=(x, y, 9.4), smooth=True)
    if snow_mat is not None:
        L.box_obj("LampSnow", (0.7, 0.7, 0.2), (x, y, 9.05), snow_mat, c, solid=False)


def build_walls(k, bm_, c, font, snow=True, south_sign=True):
    rng = random.Random(404)
    sm = k.snow if snow else None
    # lateral walls, the whole visible length; snow only over this cell
    for s in (-1, 1):
        x = s * HALF_W
        wall_run(bm_, c, x, Y_SOUTH_EDGE, x, Y_NORTH_EDGE, snow_mat=sm, snow_range=(-HALF_D, HALF_D), rng=rng)
        for y in LATERAL_PIERS:
            _pier(bm_, c, x, y, WALL_H, snow_mat=sm, axis='Y')
    # the two dividers, each with a 44-wide opening
    for y in (-HALF_D, HALF_D):
        wall_run(bm_, c, -HALF_W, y, -GATE_W / 2, y, snow_mat=sm, rng=rng)
        wall_run(bm_, c, GATE_W / 2, y, HALF_W, y, snow_mat=sm, rng=rng)
        for x in DIVIDER_PIERS:
            _pier(bm_, c, x, y, WALL_H, snow_mat=sm)
        for x in (-GATE_W / 2, GATE_W / 2):
            gate_pier(bm_, c, x, y, 19, snow_mat=sm)
    # north: Thunderworks' gate, locked; south: this region's own, open
    barrier(bm_, c, HALF_D)
    gate_sign(bm_, c, font, HALF_D, "THUNDERWORKS", "300K COINS", snow_mat=sm)
    if south_sign:
        gate_sign(bm_, c, font, -HALF_D, "FROSTBITE PEAKS", "75K COINS", snow_mat=sm)
    else:
        L.box_obj("BannerBeam", (GATE_W + 2, 1.1, 1.1), (0, -HALF_D, 25.6), bm_.gold_deep, c, bevel=0.1)
    # the two region-coloured lamps inside each gate
    for s in (-1, 1):
        lamp(bm_, c, s * (GATE_W / 2 + 12), -HALF_D + 9, bm_.frost_bulb, snow_mat=sm)
        lamp(bm_, c, s * (GATE_W / 2 + 12), HALF_D + 9, bm_.storm_bulb)


# ------------------------------------------------------------------ neighbours
def build_neighbours(k, bm_, c):
    rng = random.Random(77)
    # Cinder Canyon's north band, just over the south divider
    for i, x in enumerate([-128, -112, -95, -72, -52, 52, 70, 90, 108, 126]):
        h = rng.uniform(5, 11)
        L.rock_obj(k, "CinderRock", (rng.uniform(9, 15), rng.uniform(6, 9), h), (x + rng.uniform(-3, 3), -110 + rng.uniform(-2.5, 2.5), 0),
                   900 + i, c, rock=bm_.cinder_rock, snow=bm_.cinder_top, thresh=0.6, shape='box', lump=0.25, solid=False)
    for i, x in enumerate([-84, -40, 38, 82, 118]):
        bm = L.new_bm()
        h = rng.uniform(4.5, 7)
        L.add_cyl(bm, 0.8, 0.7, h, (0, 0, h / 2), segs=8)
        L.add_sphere(bm, 0.8, (0, 0, h), segs=8, rings=6)
        for s in (-1, 1):
            a = rng.uniform(0.35, 0.6) * h
            L.add_cyl(bm, 0.5, 0.5, 1.6, (s * 1.3, 0, a), rot=(0, math.pi / 2, 0), segs=8)
            L.add_cyl(bm, 0.5, 0.45, 2.0, (s * 2.0, 0, a + 1.0), segs=8)
            L.add_sphere(bm, 0.5, (s * 2.0, 0, a + 2.0), segs=8, rings=6)
        L.obj_from_bm("Cactus", bm, [bm_.cactus], c, loc=(x, -113 + rng.uniform(-2, 2), 0), rot=(0, 0, rng.uniform(-0.4, 0.4)), solid=False)
    # Thunderworks' south band, just over the north divider
    for i, (x, y) in enumerate([(-58, 112), (-78, 118), (60, 113), (84, 119), (-118, 114), (120, 112)]):
        bm = L.new_bm()
        w = rng.uniform(5, 8)
        L.add_box(bm, (w, 4.5, 6.5), (0, 0, 3.25), mi=0, bevel=0.2)
        L.add_box(bm, (w * 0.9, 0.2, 4.2), (0, -2.3, 3.2), mi=1)
        for j in range(3):
            L.add_cyl(bm, 0.45, 0.45, 1.8, ((j - 1) * w * 0.28, 0, 7.4), segs=8, mi=2)
        L.obj_from_bm("StormCabinet", bm, [bm_.storm_teal, bm_.storm_ground, bm_.storm_cream], c, loc=(x, y, 0),
                      rot=(0, 0, rng.uniform(-0.2, 0.2)), solid=False)
    for x, y in ((-96, 110), (100, 116)):
        bm = L.new_bm()
        L.add_cyl(bm, 3.2, 3.2, 1.0, (0, 0, 3.4), rot=(math.pi / 2, 0, 0), segs=20, mi=0)
        L.add_cyl(bm, 2.3, 2.3, 3.4, (0, 0, 3.4), rot=(math.pi / 2, 0, 0), segs=20, mi=1)
        L.obj_from_bm("CopperReel", bm, [bm_.storm_cream, bm_.copper], c, loc=(x, y, 0), rot=(0, 0, 0.3), solid=False)


# ------------------------------------------------------------------ flanks
def build_flanks(k, c, pines, rock_mat=None, count=150, seed=11):
    """Outside the lateral walls: a snowed treeline over this cell's stretch."""
    rng = random.Random(seed)
    placed = []
    tries = 0
    while len(placed) < count and tries < count * 40:
        tries += 1
        s = rng.choice((-1, 1))
        x = s * rng.uniform(HALF_W + 4, X_EDGE - 3)
        y = rng.uniform(-HALF_D + 2, HALF_D + 6)
        if any((x - px) ** 2 + (y - py) ** 2 < 5.0 ** 2 for px, py in placed):
            continue
        placed.append((x, y))
        if rng.random() < 0.72:
            me = rng.choice(pines)
            L.place(me, "FlankPine", c, (x, y, 0), rot_z=rng.uniform(0, TAU), scale=rng.uniform(0.85, 1.35), solid=False)
        else:
            L.rock_obj(k, "FlankRock", (rng.uniform(5, 10), rng.uniform(5, 9), rng.uniform(3.5, 7)), (x, y, 0),
                       rng.randrange(1 << 30), c, rock=rock_mat, solid=False)
    for i in range(40):
        s = rng.choice((-1, 1))
        L.drift_obj(k, "FlankDrift", (rng.uniform(8, 16), rng.uniform(6, 12), rng.uniform(1.0, 2.2)),
                    (s * rng.uniform(HALF_W + 3, X_EDGE - 2), rng.uniform(-HALF_D, HALF_D), 0), 5000 + i, c)


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


def band_clusters(k, c, pines, rng, extra=(), n=34, spacing=15.0, rock=None, snow=None, rock_shape='mix',
                  pine_share=0.55, max_front_h=6.5, rock_scale=1.0, accent=None, accent_share=0.0):
    """Border-band scenery in clusters: an anchor rock, a fir or two, small
    stones and a drift at the foot. Tallest against the wall, smaller toward
    the field and toward the camera."""
    def sampler():
        side = rng.random()
        if side < 0.76:
            s = rng.choice((-1, 1))
            return s * rng.uniform(FIELD_HALF[0] + 6, IN_X - 4), rng.uniform(-IN_Y + 4, IN_Y - 4)
        yy = rng.uniform(FIELD_HALF[1] + 6, IN_Y - 4) if side < 0.93 else -rng.uniform(FIELD_HALF[1] + 8, IN_Y - 4)
        return rng.uniform(-IN_X + 4, IN_X - 4), yy

    centres = poisson(rng, n, sampler, spacing, accept=lambda x, y: keep_clear(x, y, extra))
    for i, (x, y) in enumerate(centres):
        wall_d = min(IN_X - abs(x), IN_Y - abs(y))
        near = max(0.0, 1.0 - wall_d / 40.0)            # 1 at the wall, 0 at the field edge
        front = y < -HALF_D + 30
        cap = max_front_h if front else 99.0
        # anchor rock
        rh = min(cap, (4.0 + 9.0 * near + rng.uniform(0, 4)) * rock_scale)
        rw = rh * rng.uniform(1.1, 1.6)
        shape = rock_shape if rock_shape != 'mix' else 'ico'
        L.rock_obj(k, "BandRock", (rw, rw * rng.uniform(0.7, 1.0), rh), (x, y, 0), rng.randrange(1 << 30), c,
                   rock=rock, snow=snow, shape=shape, lump=0.3 if shape == 'box' else 0.22, thresh=0.84)
        if rh > 7 and rng.random() < 0.55:
            # a second, smaller block leaning on the first
            a = rng.uniform(0, TAU)
            d = rw * 0.3
            L.rock_obj(k, "BandRockTop", (rw * 0.62, rw * 0.5, rh * 0.6), (x + math.cos(a) * d, y + math.sin(a) * d, rh * 0.42),
                       rng.randrange(1 << 30), c, rock=rock, snow=snow, shape='box' if shape == 'box' else 'ico', lump=0.26,
                       thresh=0.84)
        # firs
        if rng.random() < pine_share:
            for j in range(rng.randint(1, 4)):
                a = rng.uniform(0, TAU)
                d = rng.uniform(3.5, 8.0)
                px, py = x + math.cos(a) * d, y + math.sin(a) * d
                if not keep_clear(px, py, extra):
                    continue
                sc = rng.uniform(0.75, 1.25) * (0.8 + 0.5 * near)
                if front:
                    sc = min(sc, 0.8)
                L.place(rng.choice(pines), "BandPine", c, (px, py, 0), rot_z=rng.uniform(0, TAU), scale=sc)
        # accents (crystals, lanterns...) supplied by the option
        if accent and rng.random() < accent_share:
            a = rng.uniform(0, TAU)
            px, py = x + math.cos(a) * 4.5, y + math.sin(a) * 4.5
            if keep_clear(px, py, extra):
                accent(px, py, rng)
        # pebbles and a drift
        for j in range(rng.randint(1, 3)):
            a = rng.uniform(0, TAU)
            d = rng.uniform(rw * 0.5, rw * 0.9)
            px, py = x + math.cos(a) * d, y + math.sin(a) * d
            if keep_clear(px, py, extra):
                s2 = rng.uniform(1.2, 2.6)
                L.rock_obj(k, "BandStone", (s2 * 1.3, s2, s2 * 0.8), (px, py, 0), rng.randrange(1 << 30), c,
                           rock=rock, snow=snow, subdiv=1, lump=0.15, thresh=0.86)
        L.drift_obj(k, "BandDrift", (rw * 1.6, rw * 1.2, rh * 0.22), (x + rng.uniform(-2, 2), y + rng.uniform(-2, 2), 0),
                    rng.randrange(1 << 30), c)
    return centres


def wall_drifts(k, c, rng, extra=(), n=46):
    """Soft snow banked against the inside of the walls."""
    for i in range(n):
        side = rng.random()
        if side < 0.7:
            s = rng.choice((-1, 1))
            x, y = s * (IN_X - rng.uniform(1.0, 3.0)), rng.uniform(-IN_Y + 2, IN_Y - 2)
        else:
            s = rng.choice((-1, 1))
            x, y = rng.uniform(-IN_X + 2, IN_X - 2), s * (IN_Y - rng.uniform(1.0, 3.0))
            if abs(x) < GATE_W / 2 + 7:
                continue
        blocked = False
        for e in extra:
            if e[0] == 'c' and in_circle(x, y, e[1], e[2], e[3]):
                blocked = True
        if blocked:
            continue
        L.drift_obj(k, "WallDrift", (rng.uniform(7, 14), rng.uniform(5, 9), rng.uniform(1.0, 2.4)), (x, y, 0),
                    rng.randrange(1 << 30), c)


def lane_berms(k, c, rng, gap_every=None, height=(0.5, 0.95)):
    """Low soft berms either side of the packed lane: the route reads as a
    groomed track without paving it."""
    y = -IN_Y + 14
    while y < IN_Y - 14:
        seg = rng.uniform(6, 12)
        for s in (-1, 1):
            if rng.random() < 0.8:
                L.drift_obj(k, "LaneBerm", (rng.uniform(2.4, 3.4), seg, rng.uniform(*height)),
                            (s * (LANE_HALF + 1.6 + rng.uniform(-0.4, 0.4)), y + seg / 2, 0), rng.randrange(1 << 30), c)
        y += seg + rng.uniform(3, 8)


def field_tufts(k, c, rng, n=16):
    """Low wind-drifts across the open floor, off the lane: walkable, and
    enough relief to catch the low sun."""
    for i in range(n):
        x = rng.choice((-1, 1)) * rng.uniform(LANE_HALF + 5, FIELD_HALF[0] + 2)
        y = rng.uniform(-FIELD_HALF[1] + 4, FIELD_HALF[1] - 2)
        L.drift_obj(k, "FieldTuft", (rng.uniform(9.0, 16.0), rng.uniform(5.0, 9.0), rng.uniform(0.18, 0.34)), (x, y, 0),
                    rng.randrange(1 << 30), c, mat_=L.mat("field_tuft", rgb(200, 216, 238), rough=0.85, jitter=0.02))


def field_specks(k, c, rng, n=70, mat_=None):
    """Sparse pebbles and tiny tufts on the open floor, flat enough to walk."""
    for i in range(n):
        x = rng.choice((-1, 1)) * rng.uniform(LANE_HALF + 4, FIELD_HALF[0] + 4)
        y = rng.uniform(-FIELD_HALF[1], FIELD_HALF[1])
        s = rng.uniform(0.5, 1.2)
        L.rock_obj(k, "FieldPebble", (s * 1.4, s, s * 0.55), (x, y, 0), rng.randrange(1 << 30), c,
                   rock=mat_, subdiv=1, lump=0.18, solid=False)


# ------------------------------------------------------------------ creatures
class CreatureMats:
    def __init__(self):
        self.fur = L.mat("c_fur", rgb(242, 247, 255), rough=0.6, sss=0.1)
        self.fur_blue = L.mat("c_fur_blue", rgb(190, 215, 240), rough=0.6)
        self.flake = L.mat("c_flake", rgb(120, 190, 255), rough=0.3, emit=0.8, emit_color=rgb(120, 190, 255))
        self.sloth = L.mat("c_sloth", rgb(150, 180, 200), rough=0.65)
        self.sloth_face = L.mat("c_sloth_face", rgb(214, 236, 246), rough=0.6)
        self.sloth_patch = L.mat("c_sloth_patch", rgb(110, 130, 160), rough=0.6)
        self.bison = L.mat("c_bison", rgb(128, 104, 92), rough=0.7)
        self.bison_dark = L.mat("c_bison_dark", rgb(86, 68, 62), rough=0.7)
        self.mane = L.mat("c_mane", rgb(232, 241, 250), rough=0.7)
        self.horn = L.mat("c_horn", rgb(160, 220, 255), rough=0.15, emit=0.6, emit_color=rgb(160, 220, 255))
        self.mammoth = L.mat("c_mammoth", rgb(112, 132, 172), rough=0.65)
        self.mammoth_light = L.mat("c_mammoth_light", rgb(220, 235, 250), rough=0.6)
        self.tusk = L.mat("c_tusk", rgb(250, 246, 232), rough=0.35)
        self.crown = L.mat("c_crown", rgb(255, 215, 90), rough=0.25, metal=1.0)
        self.eye = L.mat("c_eye", rgb(20, 20, 30), rough=0.1, coat=1.0)
        self.shine = L.mat("c_shine", rgb(255, 255, 255), emit=2.0)
        self.cheek = L.mat("c_cheek", rgb(255, 170, 190), rough=0.6)


def _eyes(bm, x, y_off, z, r, mi_eye, mi_shine):
    for s in (-1, 1):
        L.add_sphere(bm, r, (x, s * y_off, z), segs=10, rings=8, mi=mi_eye)
        L.add_sphere(bm, r * 0.32, (x + r * 0.55, s * y_off - s * r * 0.1, z + r * 0.45), segs=6, rings=4, mi=mi_shine)


def ferret(cm, c, loc, yaw, scale=1.0):
    bm = L.new_bm()
    mats = [cm.fur, cm.fur_blue, cm.flake, cm.eye, cm.shine, cm.cheek]
    L.add_sphere(bm, 1.0, (0, 0, 1.0), scale=(1.9, 0.95, 0.9), segs=14, rings=10, mi=0)
    L.add_sphere(bm, 0.82, (1.75, 0, 1.55), segs=14, rings=10, mi=0)
    L.add_sphere(bm, 0.42, (2.4, 0, 1.4), scale=(1.0, 0.9, 0.75), segs=10, rings=8, mi=0)
    L.add_sphere(bm, 0.12, (2.82, 0, 1.5), segs=6, rings=4, mi=3)
    for s in (-1, 1):
        L.add_sphere(bm, 0.3, (1.55, s * 0.55, 2.28), scale=(0.7, 1.0, 1.1), segs=8, rings=6, mi=1)
        L.add_sphere(bm, 0.18, (2.3, s * 0.5, 1.28), scale=(1, 1, 0.6), segs=6, rings=4, mi=5)
        for fx in (-1.1, 1.0):
            L.add_sphere(bm, 0.3, (fx, s * 0.55, 0.28), segs=8, rings=6, mi=1)
    _eyes(bm, 2.25, 0.36, 1.72, 0.16, 3, 4)
    # the snowflake tail, standing in the plane that faces the camera
    cx, cz = -2.2, 2.3
    L.add_cyl(bm, 0.22, 0.22, 1.2, (-1.8, 0, 1.6), rot=(0, -0.9, 0), segs=6, mi=0)
    for a in range(6):
        ang = a * math.pi / 3
        L.add_box(bm, (1.7, 0.18, 0.24), (cx + math.cos(ang) * 0.85, 0, cz + math.sin(ang) * 0.85), rot=(0, -ang, 0), mi=2)
        for b in (-1, 1):
            ang2 = ang + b * 0.8
            px, pz = cx + math.cos(ang) * 1.15, cz + math.sin(ang) * 1.15
            L.add_box(bm, (0.6, 0.16, 0.2), (px + math.cos(ang2) * 0.28, 0, pz + math.sin(ang2) * 0.28), rot=(0, -ang2, 0), mi=2)
    return L.obj_from_bm("FlurryFerret", bm, mats, c, loc=loc, rot=(0, 0, yaw), scale=(scale,) * 3, solid=False, smooth=True, tag="creature")


def sloth(cm, c, loc, yaw, scale=1.0):
    bm = L.new_bm()
    mats = [cm.sloth, cm.sloth_face, cm.sloth_patch, cm.eye, cm.shine, cm.horn]
    L.add_sphere(bm, 1.35, (0, 0, 1.45), scale=(1.0, 1.0, 1.05), segs=14, rings=10, mi=0)
    L.add_sphere(bm, 0.95, (0.72, 0, 1.75), scale=(0.5, 1.0, 0.85), segs=12, rings=8, mi=1)
    for s in (-1, 1):
        L.add_sphere(bm, 0.34, (1.08, s * 0.38, 1.9), scale=(0.4, 1.0, 0.7), rot=(s * 0.4, 0, 0), segs=8, rings=6, mi=2)
        # arms up, hugging its little ice arch
        L.add_tube(bm, [(0.2, s * 1.1, 1.6), (0.3, s * 1.5, 2.6), (0.2, s * 1.35, 3.5)], [0.36, 0.34, 0.3], segs=8, mi=0)
        L.add_sphere(bm, 0.36, (0.2, s * 0.7, 0.3), segs=8, rings=6, mi=0)
    _eyes(bm, 1.2, 0.38, 1.92, 0.13, 3, 4)
    L.add_sphere(bm, 0.14, (1.25, 0, 1.62), segs=6, rings=4, mi=3)
    # the arch it hangs from
    pts = [(0.2, 1.35 * math.cos(t), 3.5 + 0.9 * math.sin(t)) for t in [i / 8 * math.pi for i in range(9)]]
    L.add_tube(bm, pts, [0.34] * len(pts), segs=6, mi=5)
    for s in (-1, 1):
        L.add_cyl(bm, 0.3, 0.34, 3.5, (0.2, s * 1.35, 1.75), segs=6, mi=5)
    return L.obj_from_bm("SlushSloth", bm, mats, c, loc=loc, rot=(0, 0, yaw), scale=(scale,) * 3, solid=False, smooth=True, tag="creature")


def bison(cm, c, loc, yaw, scale=1.0):
    rng = random.Random(3)
    bm = L.new_bm()
    mats = [cm.bison, cm.bison_dark, cm.mane, cm.horn, cm.eye, cm.shine]
    L.add_sphere(bm, 1.0, (-0.3, 0, 1.75), scale=(2.0, 1.3, 1.25), segs=14, rings=10, mi=0)
    L.add_ico(bm, 1.45, (0.95, 0, 2.1), scale=(1.0, 1.1, 1.05), subdiv=2, mi=2, rng=rng, lump=0.12)
    L.add_sphere(bm, 0.8, (2.15, 0, 1.55), scale=(1.0, 0.95, 0.9), segs=12, rings=8, mi=1)
    L.add_sphere(bm, 0.48, (2.75, 0, 1.3), scale=(0.8, 1.0, 0.8), segs=10, rings=6, mi=1)
    for s in (-1, 1):
        L.add_tube(bm, [(2.0, s * 0.62, 2.05), (2.05, s * 1.25, 2.3), (2.2, s * 1.45, 3.05)], [0.3, 0.22, 0.02], segs=6, mi=3)
        for fx in (-1.6, 1.1):
            L.add_cyl(bm, 0.36, 0.3, 1.2, (fx, s * 0.62, 0.6), segs=8, mi=1)
    _eyes(bm, 2.62, 0.42, 1.8, 0.14, 4, 5)
    L.add_tube(bm, [(-2.2, 0, 2.1), (-2.7, 0, 1.6), (-2.75, 0, 1.1)], [0.16, 0.14, 0.2], segs=6, mi=1)
    return L.obj_from_bm("BlizzardBison", bm, mats, c, loc=loc, rot=(0, 0, yaw), scale=(scale,) * 3, solid=False, smooth=True, tag="creature")


def mammoth(cm, c, loc, yaw, scale=1.0):
    bm = L.new_bm()
    mats = [cm.mammoth, cm.mammoth_light, cm.tusk, cm.crown, cm.eye, cm.shine, cm.horn]
    L.add_sphere(bm, 1.0, (-0.4, 0, 2.7), scale=(2.4, 1.85, 1.9), segs=16, rings=12, mi=0)
    L.add_sphere(bm, 1.35, (1.9, 0, 3.3), segs=14, rings=10, mi=0)
    L.add_sphere(bm, 0.9, (1.6, 0, 4.4), scale=(1.1, 1.0, 0.7), segs=12, rings=8, mi=0)
    for s in (-1, 1):
        L.add_sphere(bm, 1.0, (1.2, s * 1.35, 3.3), scale=(0.35, 0.9, 1.1), segs=12, rings=8, mi=1)
        for fx in (-1.8, 1.0):
            L.add_cyl(bm, 0.62, 0.55, 1.9, (fx, s * 0.9, 0.95), segs=10, mi=0)
        L.add_tube(bm, [(2.5, s * 0.7, 2.6), (3.4, s * 0.95, 2.1), (4.1, s * 0.9, 2.6), (4.3, s * 0.7, 3.3)],
                   [0.3, 0.26, 0.2, 0.05], segs=8, mi=2)
    L.add_tube(bm, [(3.0, 0, 3.0), (3.5, 0, 2.2), (3.6, 0, 1.3), (3.25, 0, 0.8), (3.0, 0, 1.1)],
               [0.5, 0.42, 0.34, 0.28, 0.25], segs=10, mi=0)
    _eyes(bm, 2.95, 0.55, 3.75, 0.2, 4, 5)
    # a gold crown set with glacier spikes
    L.add_cyl(bm, 0.95, 1.05, 0.55, (1.6, 0, 4.95), segs=16, mi=3)
    for i in range(6):
        a = i / 6 * TAU
        L.add_cyl(bm, 0.22, 0.0, 1.1, (1.6 + math.cos(a) * 0.82, math.sin(a) * 0.82, 5.7), segs=5, mi=6 if i % 2 else 3)
    return L.obj_from_bm("KingColdsnout", bm, mats, c, loc=loc, rot=(0, 0, yaw), scale=(scale,) * 3, solid=False, smooth=True, tag="creature")


# The same six positions in every option, all on open floor and none on the
# lane. Enlarged about 3x from game scale so they read at this distance.
CREATURES = [
    ("ferret", (-60, 36), math.radians(-25), 2.2),
    ("bison", (64, 50), math.radians(200), 2.1),
    ("sloth", (-32, -30), math.radians(25), 2.3),
    ("ferret", (72, -20), math.radians(160), 2.2),
    ("bison", (-74, -54), math.radians(15), 2.0),
    ("mammoth", (40, 14), math.radians(205), 1.8),
]


def build_creatures(c, positions=CREATURES):
    cm = CreatureMats()
    fns = {"ferret": ferret, "sloth": sloth, "bison": bison, "mammoth": mammoth}
    for kind, (x, y), yaw, s in positions:
        fns[kind](cm, c, (x, y, 0), yaw, s)


# ------------------------------------------------------------------ measurement
def clear_floor_stats(grid=1.0):
    """How much of the interior no solid scenery stands over, measured from
    each solid object's evaluated vertices (convex hull of the XY projection),
    so a fir counts its whole canopy, not just its trunk."""
    import numpy as np
    xs = np.arange(-IN_X + grid / 2, IN_X, grid)
    ys = np.arange(-IN_Y + grid / 2, IN_Y, grid)
    occ = np.zeros((len(ys), len(xs)), dtype=bool)
    dg = bpy.context.evaluated_depsgraph_get()
    count = 0
    lane_hits = []
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
        w = w[w[:, 2] > 0.35]            # what stands above the floor
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
        if x0 < LANE_HALF and x1 > -LANE_HALF and inside.any():
            sub = gx[inside]
            if (np.abs(sub) < LANE_HALF).any():
                lane_hits.append(ob.name)
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

# Alpine Outpost V2 layout, region-local studs (the RegionScenery frame):
#   +X west (image LEFT), +Z north (the Thunderworks gate), y above the floor
#   top (absolute y = 0.30 + h). Measured off the V2 concept through the gate
#   homography + piecewise wall/pier x map (measure.py); positions agree with
#   the fitted comparison camera (refcam.py) to 1-2 studs. Heights use the
#   gate-pier ruler (V2's own proportions), +-15%.
T_TOP = 5.5          # terrace walk level above floor (5.2 on V2's pier ruler x 1.12, 9 risers)
S_TOP = 8.5          # bridge shelf walk level (8-9 read, 14 risers)
LANE_HALF = 12.0

# ------------------------------------------------------------------ assets
# name: (W, H, D) Roblox studs, bottom-centre pivot, front = local -Z
ASSETS = {
    'FA_Lodge': (40, 30, 24),
    'FA_Rope_Bridge': (11, 7.5, 34),
    'FA_Shelf_North': (42.5, 10, 23.5),
    'FA_Shelf_South': (29, 10, 15),
    'FA_Gorge_Rock': (12, 11, 50),
    'FA_Cliff_Tall': (22, 32, 18),
    'FA_Cliff_Broad': (28, 18, 16),
    'FA_Cliff_Block': (14, 12, 12),
    'FA_Boulder_Large': (9, 6, 8),
    'FA_Boulder_Medium': (5, 3.5, 4.5),
    'FA_Snowbank': (12, 2.5, 7),
    'FA_Fir_Mature': (14, 31, 14),
    'FA_Fir_Medium': (9.5, 19, 9.5),
    'FA_Fir_Sapling': (5.5, 10, 5.5),
    'FA_Shrub_Frosted': (4, 2.5, 4),
    'FA_Grass_Golden': (3, 2.6, 3),
    'FA_Tent': (8, 6, 9),
    'FA_Woodpile': (6, 3.2, 2.6),
    'FA_Barrel': (2.2, 3, 2.2),
    'FA_Camp_Sled': (5, 2, 3),
    'FA_Notice_Board': (4, 5, 1),
    'FA_Pennant': (2.8, 9, 1),
    'FA_Lantern_Post': (1.6, 6, 1.6),
    'FA_Trail_Marker': (0.8, 3.2, 0.8),
    'FA_Signpost': (4, 7, 1),
    'FA_Railing': (6, 3, 0.6),
    'FA_Terrace_Post': (2, 7.5, 2),
    # props-v1, reused as they are
    'FP_Supply_Crate': (2.6886, 2.4087, 2.65),
    'FP_Rope_Coil': (2.5762, 0.2319, 2.1408),
}

# ------------------------------------------------------------------ landmarks
TERRACE = dict(x0=84.5, x1=138.5, z0=28.5, z1=77.0, top=T_TOP)
TERRACE_STAIR = dict(x0=110.5, x1=120.5, top_z=28.5, risers=9, tread=1.0)
LODGE = dict(x=113.5, z=58.5, yaw=0.0)  # bounds bottom-centre on the deck
SHELF_N = dict(x=-104.75, z=50.25)      # C x -83.5..-106 z 38.5..62 + A x -106..-126 z 54..62
SHELF_S = dict(x=-121.5, z=16.5)        # x -107..-136, z 9..24
GORGE_ROCK = dict(x=-132.3, z=49.0)     # x -126.3..-138.3, z 24..74
SHELF_C = dict(x0=-106.0, x1=-83.5, z0=38.5, z1=62.0)
SHELF_A = dict(x0=-126.0, x1=-106.0, z0=54.0, z1=62.0)
SHELF_B = dict(x0=-136.0, x1=-107.0, z0=9.0, z1=24.0)
B_STAIR = dict(x0=-127.5, x1=-115.5, top_z=9.0, risers=14, tread=1.05)
BRIDGE = dict(n=(-114.0, 56.0), s=(-117.5, 22.0), width=8.0, sag=1.2)

# (asset, x, z, yaw_deg, h_base, scale)
CAMP = [
    ('FA_Tent', 95.5, 33.5, 40, T_TOP, 1), ('FA_Camp_Sled', 104.0, 36.5, -10, T_TOP, 1),
    ('FA_Pennant', 88.5, 39.0, 0, T_TOP, 1), ('FA_Pennant', 96.0, 57.0, 0, T_TOP, 1.4),
    ('FA_Lantern_Post', 126.5, 33.0, 0, T_TOP, 1), ('FA_Lantern_Post', 92.5, 55.5, 0, T_TOP, 1),
    ('FA_Barrel', 135.0, 37.5, 0, T_TOP, 1), ('FA_Barrel', 134.5, 33.5, 20, T_TOP, 1),
    ('FA_Barrel', 135.0, 52.0, 0, T_TOP, 1), ('FA_Barrel', 99.0, 55.5, 0, T_TOP, 1),
    ('FP_Supply_Crate', 131.0, 36.0, 15, T_TOP, 1), ('FA_Woodpile', 129.0, 50.5, 90, T_TOP, 1),
    ('FA_Notice_Board', 89.5, 63.0, -15, T_TOP, 1),
]
CLIFFS = [  # (asset, x, z, yaw, scale)
    ('FA_Cliff_Tall', 118.0, 88.0, 4, 1), ('FA_Cliff_Broad', 104.0, 89.0, -6, 1), ('FA_Cliff_Block', 92.0, 81.0, 12, 1),
    ('FA_Cliff_Broad', 72.0, 90.0, 3, 1), ('FA_Cliff_Block', 49.0, 92.5, -8, 1), ('FA_Cliff_Block', 43.0, 80.0, 20, 1),
    ('FA_Cliff_Block', -66.0, 91.0, -5, 1), ('FA_Cliff_Broad', -86.0, 88.0, 4, 1), ('FA_Cliff_Tall', -105.0, 89.0, -3, 1),
    ('FA_Cliff_Tall', -129.0, 86.0, -90, 1),
    ('FA_Cliff_Broad', 112.0, -14.0, -5, 1), ('FA_Cliff_Block', 116.0, -41.0, 10, 1), ('FA_Cliff_Block', 98.0, -60.0, -15, 1.2),
    ('FA_Cliff_Block', -114.5, -34.0, 8, 1.3), ('FA_Cliff_Block', -130.0, -40.0, -90, 1),
]
BOULDERS = [  # (asset, x, z, yaw, scale)
    ('FA_Boulder_Large', 36.8, 68.9, 30, 1), ('FA_Boulder_Large', 29.0, 64.4, -20, 0.8), ('FA_Boulder_Medium', 40.5, 60.6, 10, 1),
    ('FA_Boulder_Large', -67.8, 69.6, 15, 1), ('FA_Boulder_Medium', -31.6, 77.7, -30, 1.4), ('FA_Boulder_Medium', -102.0, 82.0, 0, 1.3),
    ('FA_Boulder_Large', 102.3, -72.5, 20, 1), ('FA_Boulder_Large', 92.0, -82.0, 30, 1), ('FA_Boulder_Medium', 121.4, -54.2, 0, 1.4),
    ('FA_Boulder_Large', 122.0, -86.0, -10, 0.9), ('FA_Boulder_Medium', 116.0, -46.5, 40, 1.2),
    ('FA_Boulder_Large', -99.4, -55.0, 10, 1.4), ('FA_Boulder_Large', -106.7, -41.8, -25, 1), ('FA_Boulder_Large', -118.3, -81.5, 5, 1.2),
    ('FA_Boulder_Medium', -117.7, -73.1, 15, 1.5), ('FA_Boulder_Large', -89.1, -1.1, 25, 1.3), ('FA_Boulder_Medium', -95.4, -2.6, -15, 1.2),
    ('FA_Boulder_Large', -91.5, 17.7, 0, 1), ('FA_Boulder_Medium', -83.8, 1.0, 30, 1),
]
# (asset, x, z, h_base, scale)
FIRS = [
    # left band
    ('FA_Fir_Mature', 113.0, -34.6, 0, 1.0), ('FA_Fir_Medium', 133.7, -18.4, 0, 1.25), ('FA_Fir_Medium', 123.6, -30.8, 0, 0.88),
    ('FA_Fir_Medium', 91.8, -49.0, 0, 1.12), ('FA_Fir_Mature', 127.4, -75.9, 0, 0.9), ('FA_Fir_Medium', 114.6, -63.8, 0, 0.87),
    ('FA_Fir_Medium', 133.7, -82.8, 0, 0.7), ('FA_Fir_Medium', 125.3, -85.0, 0, 0.72), ('FA_Fir_Sapling', 108.2, -68.1, 0, 1.0),
    ('FA_Fir_Medium', 124.6, 2.5, 0, 1.07), ('FA_Fir_Medium', 135.2, 3.0, 0, 0.86), ('FA_Fir_Sapling', 115.2, 2.0, 0, 1.2),
    ('FA_Fir_Medium', 100.8, -3.5, 0, 0.85),
    # south band beside the gate
    ('FA_Fir_Sapling', 71.0, -84.5, 0, 1.25), ('FA_Fir_Medium', 44.2, -84.0, 0, 0.72), ('FA_Fir_Medium', -48.9, -84.0, 0, 1.0),
    ('FA_Fir_Medium', -56.4, -81.5, 0, 0.77), ('FA_Fir_Sapling', -84.2, -86.0, 0, 0.6),
    # rear left
    ('FA_Fir_Medium', 59.5, 73.4, 0, 1.06), ('FA_Fir_Mature', 39.6, 88.0, 0, 0.76), ('FA_Fir_Sapling', 58.3, 95.0, 0, 1.15),
    ('FA_Fir_Sapling', 47.3, 96.0, 0, 0.8), ('FA_Fir_Medium', 24.5, 70.2, 0, 1.0), ('FA_Fir_Medium', 88.0, 80.0, 0, 1.1),
    ('FA_Fir_Medium', 135.0, 73.5, T_TOP, 0.6),
    # rear right
    ('FA_Fir_Mature', -56.8, 77.7, 0, 0.8), ('FA_Fir_Medium', -52.2, 93.0, 0, 0.85), ('FA_Fir_Mature', -93.7, 76.0, 0, 0.8),
    ('FA_Fir_Medium', -70.0, 91.0, 12.0, 0.9), ('FA_Fir_Medium', -84.0, 90.0, 18.0, 1.0), ('FA_Fir_Medium', -131.0, 88.0, 32.0, 0.9),
    ('FA_Fir_Medium', -130.8, 56.8, 0, 0.73), ('FA_Fir_Sapling', -132.1, 41.0, 0, 1.1),
    # right band
    ('FA_Fir_Medium', -86.4, -46.7, 0, 0.73), ('FA_Fir_Medium', -95.8, -39.5, 0, 0.73), ('FA_Fir_Sapling', -100.6, -43.3, 0, 1.05),
    ('FA_Fir_Mature', -114.9, -64.7, 0, 0.85), ('FA_Fir_Medium', -105.6, -77.9, 0, 1.2), ('FA_Fir_Medium', -129.3, -63.0, 0, 0.93),
    ('FA_Fir_Medium', -131.9, -80.6, 0, 0.86), ('FA_Fir_Medium', -126.5, -28.7, 0, 1.2), ('FA_Fir_Medium', -134.1, -17.0, 0, 0.78),
    ('FA_Fir_Medium', -99.0, -17.6, 0, 0.88), ('FA_Fir_Medium', -104.7, -19.5, 0, 0.74), ('FA_Fir_Sapling', -84.6, -85.6, 0, 0.92),
]
PLANTS = [  # (asset, x, z)
    ('FA_Grass_Golden', 130.8, -37.5), ('FA_Grass_Golden', 102.7, -32.3), ('FA_Grass_Golden', 116.9, -74.5), ('FA_Grass_Golden', 83.3, -77.3),
    ('FA_Shrub_Frosted', 93.2, -4.4), ('FA_Shrub_Frosted', 86.8, -66.6), ('FA_Grass_Golden', -96.3, -16.4), ('FA_Grass_Golden', -120.6, -15.5),
    ('FA_Grass_Golden', -82.2, -46.7), ('FA_Grass_Golden', -93.6, -66.1), ('FA_Grass_Golden', -123.5, -73.9), ('FA_Grass_Golden', -106.6, -81.2),
    ('FA_Shrub_Frosted', -97.6, -64.7), ('FA_Shrub_Frosted', -87.9, -49.0), ('FA_Grass_Golden', -90.8, 24.0), ('FA_Grass_Golden', -81.6, 42.5),
    ('FA_Shrub_Frosted', -82.8, 29.0), ('FA_Grass_Golden', 68.0, 80.9), ('FA_Grass_Golden', 57.5, 68.0), ('FA_Grass_Golden', 46.1, 66.4),
    ('FA_Shrub_Frosted', 67.7, 69.6), ('FA_Grass_Golden', 25.0, 85.8), ('FA_Grass_Golden', -33.1, 90.0), ('FA_Grass_Golden', -36.1, 69.6),
    ('FA_Shrub_Frosted', -38.5, 77.7), ('FA_Grass_Golden', -81.4, 74.4), ('FA_Grass_Golden', 81.1, 22.0), ('FA_Grass_Golden', 101.1, 21.0),
    ('FA_Grass_Golden', 97.5, 18.0), ('FA_Grass_Golden', 40.0, -86.0), ('FA_Grass_Golden', 60.0, -88.0), ('FA_Grass_Golden', -40.0, -87.0),
    ('FA_Grass_Golden', -66.0, -88.0), ('FA_Shrub_Frosted', 78.0, -88.0), ('FA_Shrub_Frosted', -74.0, -84.0),
]
SNOWBANKS = [  # (x, z, yaw, scale)
    (133.0, -60.0, 90, 1.0), (133.0, -40.0, 90, 0.9), (133.5, -95.0, 0, 1.0), (104.0, -92.0, 5, 1.0),
    (-133.0, -55.0, 90, 1.0), (-133.0, 0.0, 90, 0.9), (-133.5, -95.0, 0, 1.0), (-104.0, -92.0, -5, 1.0),
    (78.0, -94.0, 0, 0.9), (-78.0, -94.0, 0, 0.9), (106.0, -24.0, 10, 0.9), (-110.0, -48.0, -15, 0.9),
    (60.0, 62.0, 20, 0.8), (-60.0, 64.0, -20, 0.8), (-88.0, 30.0, 0, 0.8), (88.0, 14.0, 0, 0.8),
]
LANE_STAKES = [(s * 15.25, z) for s in (-1, 1) for z in (-58.5, -39.0, -19.5, 0.0, 19.5, 39.0, 58.5)]
FIELD_ICE = [  # (x, z, w, d, yaw)
    (65.0, 12.0, 24, 11, 8), (-35.0, 46.0, 12, 8, -10), (-46.0, 24.0, 12, 9, 15), (-41.0, -15.0, 14, 7, 0),
    (43.0, -5.0, 10, 6, 5), (-62.0, -37.0, 14, 7, -12), (52.0, 34.0, 9, 6, 20), (-24.0, -48.0, 8, 5, 0),
]
# the creek: (x0, x1, z0, z1) boxes, drawn as overlapping discs in the build
CREEK = [(-108, -121, 62, 80), (-108, -119, 24, 54), (-98, -118, 22, 38), (-99, -107, 2, 24)]
# flank firs outside the side walls: (x, z, asset, scale)
FLANK = [(s * x, z, a, sc) for s in (-1, 1) for (x, z, a, sc) in [
    (148, -88, 'FA_Fir_Mature', 0.95), (160, -70, 'FA_Fir_Mature', 1.0), (149, -52, 'FA_Fir_Medium', 1.2), (166, -38, 'FA_Fir_Mature', 0.9),
    (150, -20, 'FA_Fir_Mature', 1.05), (162, -2, 'FA_Fir_Medium', 1.3), (148, 14, 'FA_Fir_Mature', 0.9), (165, 30, 'FA_Fir_Mature', 1.0),
    (151, 46, 'FA_Fir_Medium', 1.25), (163, 62, 'FA_Fir_Mature', 0.95), (149, 78, 'FA_Fir_Mature', 1.0), (160, 94, 'FA_Fir_Medium', 1.1),
]]

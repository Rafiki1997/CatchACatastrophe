# Readings off the V2 concept, in image pixels (1536 x 1024). Each entry:
#   kind, label, u, v (base centre), h (height of that base above ground),
#   and for tall things v_top (image row of the top) so height can be read.
# Heights read with the gate-pier ruler are estimates (+-15%).
T_TOP = 5.0     # terrace deck, read 5.2 off its retaining wall
S_TOP = 8.0     # bridge shelves, read 8-9 off the stair and its landing

LODGE = {
    'front_wall_L': (177, 268, T_TOP + 1.0), 'front_wall_R': (298, 268, T_TOP + 1.0),
    'eave_L': (168, 227, None), 'eave_R': (302, 220, None), 'apex_front': (237, 177, None),
    'ridge_back': (237, 129, None), 'chimney_top': (227, 105, None), 'chimney_base_roof': (227, 132, None),
    'door': (233, 262, T_TOP + 1.0), 'door_top': (233, 233, None),
    'porch_front': (237, 292, T_TOP + 1.0), 'porch_L': (178, 292, T_TOP), 'porch_R': (298, 292, T_TOP),
    'annex_front_L': (302, 230, T_TOP), 'annex_front_R': (340, 230, T_TOP), 'annex_top': (322, 170, None),
}
TERRACE = {
    'front_W': (145, 350, T_TOP), 'front_E': (378, 350, T_TOP), 'east_N': (380, 190, T_TOP),
    'rear_W': (150, 150, T_TOP), 'stair_top_L': (220, 350, T_TOP), 'stair_top_R': (262, 350, T_TOP),
    'stair_bot_L': (220, 397, 0.0), 'stair_bot_R': (262, 397, 0.0),
}
CAMP = [  # kind, u, v, h, v_top
    ('tent', 330, 334, T_TOP, 285), ('sled', 291, 324, T_TOP, 312), ('pennant', 362, 316, T_TOP, 285),
    ('lantern_post', 196, 336, T_TOP, 305), ('barrel', 160, 320, T_TOP, 300), ('crate', 176, 330, T_TOP, 313),
    ('crate', 180, 318, T_TOP, 303), ('barrel', 165, 268, T_TOP + 1.0, 250), ('woodpile', 190, 275, T_TOP + 1.0, 262),
    ('barrel', 316, 262, T_TOP, 245), ('brazier', 346, 262, T_TOP, 235), ('signboard', 360, 240, T_TOP, 218),
]
BRIDGE = {
    'north_end': (1281, 255, S_TOP), 'south_end': (1311, 375, S_TOP),
    'post_NW': (1242, 255, S_TOP), 'post_NE': (1320, 255, S_TOP), 'post_SW': (1277, 377, S_TOP), 'post_SE': (1345, 372, S_TOP),
    'lantern_N': (1225, 227, None), 'lantern_S': (1348, 352, None),
    'shelfA_NW': (1225, 190, S_TOP), 'shelfA_NE': (1345, 188, S_TOP), 'shelfA_SW': (1228, 258, S_TOP), 'shelfA_SE': (1340, 258, S_TOP),
    'shelfC_NW': (1148, 258, S_TOP), 'shelfC_NE': (1250, 258, S_TOP), 'shelfC_SW': (1150, 305, S_TOP), 'shelfC_SE': (1250, 305, S_TOP),
    'shelfB_NW': (1263, 353, S_TOP), 'shelfB_NE': (1380, 353, S_TOP), 'shelfB_SW': (1263, 400, S_TOP), 'shelfB_SE': (1380, 400, S_TOP),
    'stairB_top_L': (1300, 400, S_TOP), 'stairB_top_R': (1350, 400, S_TOP), 'stairB_bot_L': (1300, 483, 0.0), 'stairB_bot_R': (1350, 483, 0.0),
    'signpost': (1172, 300, S_TOP), 'railpost_C': (1215, 303, S_TOP),
    'creek_N1': (1262, 188, 0.0), 'creek_N2': (1300, 190, 0.0), 'creek_M1': (1250, 330, 0.0), 'creek_M2': (1275, 335, 0.0),
    'creek_S1': (1228, 440, 0.0), 'creek_S2': (1262, 440, 0.0), 'creek_end': (1240, 455, 0.0),
}
# Firs: label, u_base, v_base, h_base, v_top.  L = left band etc.
FIRS = [
    # left band
    ('L', 235, 580, 0, 465), ('L', 150, 525, 0, 435), ('L', 190, 567, 0, 505), ('L', 327, 630, 0, 550),
    ('L', 160, 725, 0, 620), ('L', 220, 682, 0, 620), ('L', 130, 750, 0, 700), ('L', 167, 752, 0, 700),
    ('L', 247, 697, 0, 660), ('L', 195, 455, 0, 380), ('L', 150, 455, 0, 395), ('L', 235, 455, 0, 410),
    ('L', 295, 475, 0, 415), ('L', 420, 752, 0, 705),
    # rear left (behind/around lodge and toward the gate)
    ('RL', 497, 228, 0, 155), ('RL', 505, 160, 0, 118), ('RL', 585, 185, 0, 100), ('RL', 553, 145, 0, 118),
    ('RL', 668, 238, 0, 168), ('RL', 340, 170, T_TOP, 95), ('RL', 158, 160, T_TOP, 120),
    # rear right
    ('RR', 1090, 130, 0, 42), ('RR', 1130, 110, 0, 10), ('RR', 1025, 215, 0, 125), ('RR', 1003, 168, 0, 110),
    ('RR', 1190, 220, 0, 130), ('RR', 1360, 90, 0, 15), ('RR', 1215, 110, 0, 55), ('RR', 1262, 150, 0, 100),
    ('RR', 1350, 280, 0, 230), ('RR', 1360, 330, 0, 290),
    # right band
    ('R', 1182, 622, 0, 570), ('R', 1225, 597, 0, 545), ('R', 1249, 610, 0, 570), ('R', 1317, 685, 0, 585),
    ('R', 1280, 732, 0, 645), ('R', 1380, 679, 0, 612), ('R', 1397, 742, 0, 680), ('R', 1357, 560, 0, 475),
    ('R', 1386, 520, 0, 465), ('R', 1235, 522, 0, 460), ('R', 1260, 522, 0, 470), ('R', 1182, 760, 0, 725),
    # south inner band, beside the gate
    ('S', 425, 752, 0, 705), ('S', 548, 752, 0, 700), ('S', 1010, 752, 0, 680), ('S', 1045, 745, 0, 690),
    ('S', 1180, 758, 0, 735),
]
# Rock formations: label, u, v (footprint centre at ground), half width px, half depth px, v_top
ROCKS = [
    # left band
    ('L', 245, 510, 65, 30, 465), ('L', 222, 600, 42, 18, 575), ('L', 295, 665, 40, 30, 625), ('L', 272, 712, 22, 16, 690),
    ('L', 320, 745, 25, 12, 725), ('L', 193, 648, 16, 12, 630), ('L', 180, 750, 20, 10, 735),
    # rear left (north wall, left of gate)
    ('RL', 450, 170, 32, 30, 128), ('RL', 395, 160, 16, 30, 115), ('RL', 543, 165, 17, 20, 137), ('RL', 570, 212, 30, 28, 177),
    ('RL', 596, 242, 18, 18, 215), ('RL', 630, 256, 15, 12, 240), ('RL', 579, 268, 11, 8, 257),
    ('RL', 250, 90, 60, 60, 15), ('RL', 330, 140, 30, 25, 110),
    # rear right
    ('RR', 1066, 180, 33, 35, 115), ('RR', 1185, 150, 80, 60, 85), ('RR', 1265, 160, 45, 60, 55), ('RR', 1340, 140, 45, 55, 70),
    ('RR', 915, 215, 20, 15, 190), ('RR', 1075, 240, 18, 12, 220), ('RR', 1225, 195, 18, 14, 175),
    # right band
    ('R', 1307, 572, 42, 42, 530), ('R', 1372, 592, 28, 28, 565), ('R', 1246, 651, 34, 19, 632), ('R', 1275, 605, 25, 15, 590),
    ('R', 1337, 745, 27, 15, 730), ('R', 1332, 715, 17, 15, 700), ('R', 1185, 467, 20, 22, 445), ('R', 1215, 472, 15, 12, 460),
    ('R', 1192, 405, 22, 15, 385), ('R', 1160, 460, 12, 10, 450),
]
SHRUBS = [  # kind g = golden grass, f = frosted shrub; u, v
    ('g', 157, 590), ('g', 280, 572), ('g', 207, 720), ('g', 362, 730), ('f', 330, 478), ('f', 347, 692),
    ('g', 1222, 518), ('g', 1328, 515), ('g', 1162, 622), ('g', 1221, 690), ('g', 1358, 718), ('g', 1285, 744),
    ('f', 1240, 685), ('f', 1190, 630), ('g', 1188, 390), ('g', 1142, 325), ('f', 1150, 372),
    ('g', 460, 205), ('g', 505, 245), ('g', 555, 250), ('f', 460, 240), ('g', 660, 190), ('g', 920, 155),
    ('g', 935, 240), ('f', 945, 215), ('g', 1135, 225), ('g', 395, 325), ('g', 300, 385), ('g', 315, 400),
]
FIELD_ICE = [  # centre (V2 gate-scale ground studs, scene X east), size
    ((-60, 12), (24, 11)), ((32, 46), (12, 8)), ((42, 24), (12, 9)), ((38, -15), (14, 7)),
    ((-40, -5), (10, 6)), ((57, -37), (14, 7)), ((-48, 34), (9, 6)), ((22, -48), (8, 5)),
]
LANE_STAKES = {'x': (-15.0, 14.5), 'Y': (57, 38, 18, -1, -20, -40, -59)}

# Labelled V2 crops, one per requested asset family, for Astra.
import sys
from PIL import Image, ImageDraw, ImageFont
V2 = "C:/Users/nguye/Documents/repos/catch-a-catastrophe/CatchACatastrophe/docs/art/regions/2026-09-22-frostbite-peaks/frostbite-peaks-v2-02-alpine-outpost-refined.png"
src = Image.open(V2).convert('RGB')
CROPS = [
    ('FA_Lodge', (150, 20, 390, 300)), ('FA_Tent / FA_Camp_Sled', (268, 275, 385, 350)),
    ('barrels, FP_Supply_Crate, FA_Lantern_Post', (143, 285, 220, 345)), ('FA_Woodpile / barrels (porch W)', (150, 240, 222, 290)),
    ('FA_Pennant / FA_Notice_Board / brazier post', (296, 160, 390, 330)), ('FA_Terrace_Wall + FA_Terrace_Post + stairs', (140, 330, 390, 405)),
    ('FA_Railing (terrace east edge)', (355, 170, 400, 350)), ('FA_Rope_Bridge (lanterns on NW and SE posts)', (1205, 180, 1370, 395)),
    ('FA_Shelf_North (C + A), FA_Signpost', (1125, 235, 1350, 385)), ('FA_Shelf_South + its stair', (1245, 330, 1395, 495)),
    ('FA_Gorge_Rock (east of the bridge)', (1295, 225, 1395, 405)), ('FA_Cliff_Tall (NE corner, fir on top)', (1285, 5, 1400, 265)),
    ('FA_Cliff_Tall + FA_Cliff_Broad (NW, behind lodge)', (160, 0, 345, 160)), ('FA_Cliff_Broad (rear right massif)', (1090, 40, 1290, 265)),
    ('FA_Cliff_Broad (left band)', (168, 450, 335, 560)), ('FA_Cliff_Block (right band)', (1255, 515, 1415, 630)),
    ('FA_Boulder_Large / Medium', (555, 195, 655, 285)), ('FA_Boulder_Large (left band)', (245, 610, 350, 715)),
    ('FA_Fir_Mature', (178, 440, 292, 600)), ('FA_Fir_Medium', (295, 535, 362, 640)),
    ('FA_Fir_Sapling', (1160, 585, 1205, 640)), ('FA_Shrub_Frosted / FA_Grass_Golden', (1190, 495, 1265, 545)),
    ('FA_Grass_Golden (south band)', (330, 700, 400, 760)), ('FA_Snowbank (drifts at cluster feet)', (395, 690, 530, 765)),
    ('FA_Signpost (on shelf C)', (1150, 240, 1225, 315)), ('FA_Trail_Marker (lane stakes)', (676, 385, 712, 425)),
    ('field: ice patch + tracks (reserved textures)', (410, 380, 560, 460)), ('creek ice (reserved texture)', (1225, 325, 1285, 450)),
]
cols, cell, lab = 4, 300, 26
rows = (len(CROPS) + cols - 1) // cols
sheet = Image.new('RGB', (cols * cell + (cols + 1) * 12, rows * (cell + lab) + (rows + 1) * 12 + 50), (247, 245, 241))
d = ImageDraw.Draw(sheet)
try:
    F = ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf', 14)
    FT = ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf', 22)
except Exception:
    F = FT = ImageFont.load_default()
d.text((12, 12), 'Alpine Outpost V2 - reference crops per requested asset (source: frostbite-peaks-v2-02-alpine-outpost-refined.png)', font=FT, fill=(27, 56, 102))
for i, (name, box) in enumerate(CROPS):
    r, c = divmod(i, cols)
    x0 = 12 + c * (cell + 12)
    y0 = 50 + 12 + r * (cell + lab + 12)
    im = src.crop(box)
    k = min(cell / im.width, cell / im.height)
    im = im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.LANCZOS)
    sheet.paste(im, (x0 + (cell - im.width) // 2, y0 + lab + (cell - im.height) // 2))
    d.text((x0, y0 + 4), name, font=F, fill=(30, 30, 30))
    d.text((x0 + cell - 4, y0 + 4), f'{box}', font=ImageFont.load_default(), fill=(110, 110, 110), anchor='ra')
sheet.save(sys.argv[1] if len(sys.argv) > 1 else 'asset-crops.png')
print('ok', sheet.size)

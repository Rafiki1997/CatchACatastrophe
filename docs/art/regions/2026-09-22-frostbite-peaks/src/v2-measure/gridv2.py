# Draw the ground-homography stud grid over V2 (scene X east, Y north), then
# crop regions at 2x for reading.
import sys, numpy as np
from PIL import Image, ImageDraw, ImageFont
from homog import to_px
V2 = "C:/Users/rahul/orca/Catch-a-Catastrophe/docs/art/regions/2026-09-22-frostbite-peaks/frostbite-peaks-v2-02-alpine-outpost-refined.png"
im = Image.open(V2).convert('RGB')
ov = Image.new('RGBA', im.size, (0, 0, 0, 0))
d = ImageDraw.Draw(ov)
f = ImageFont.load_default()
for X in range(-150, 151, 10):
    a, b = to_px(X, -110), to_px(X, 105)
    col = (255, 0, 0, 200) if X % 50 == 0 else (255, 60, 60, 110)
    d.line([tuple(a), tuple(b)], fill=col, width=1)
    for Y in (-95, -45, 5, 55):
        q = to_px(X, Y); d.text((q[0] + 2, q[1]), str(X), fill=(200, 0, 0, 255), font=f)
for Y in range(-110, 106, 10):
    a, b = to_px(-150, Y), to_px(150, Y)
    col = (0, 0, 255, 200) if Y % 50 == 0 else (60, 60, 255, 110)
    d.line([tuple(a), tuple(b)], fill=col, width=1)
    for X in (-135, -75, 25, 85):
        q = to_px(X, Y); d.text((q[0], q[1] - 11), str(Y), fill=(0, 0, 200, 255), font=f)
out = Image.alpha_composite(im.convert('RGBA'), ov).convert('RGB')
out.save('v2_grid.png')
for name, box in {'lodge': (140, 0, 420, 420), 'bridge': (1100, 130, 1420, 520), 'rearL': (380, 40, 700, 300),
                  'rearR': (840, 0, 1400, 260), 'bandL': (100, 380, 440, 800), 'bandR': (1100, 440, 1460, 800),
                  'field': (380, 250, 1180, 700)}.items():
    c = out.crop(box); c = c.resize((c.width * 2, c.height * 2), Image.LANCZOS); c.save(f'g_{name}.png')
print('ok')

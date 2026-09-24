# crop.py img x0 y0 x1 y1 scale out [step]
import sys
from PIL import Image, ImageDraw, ImageFont
img, x0, y0, x1, y1, sc, out = sys.argv[1], *map(int, sys.argv[2:7]), sys.argv[7]
step = int(sys.argv[8]) if len(sys.argv) > 8 else 10
im = Image.open(img).convert('RGB').crop((x0, y0, x1, y1))
im = im.resize(((x1 - x0) * sc, (y1 - y0) * sc), Image.NEAREST)
pad = 40
canvas = Image.new('RGB', (im.width + pad, im.height + pad), (255, 255, 255))
canvas.paste(im, (pad, pad))
d = ImageDraw.Draw(canvas)
f = ImageFont.load_default()
for x in range((x0 // step + 1) * step, x1, step):
    X = pad + (x - x0) * sc
    major = x % (step * 5) == 0
    d.line([(X, pad), (X, canvas.height)], fill=(255, 0, 0) if major else (255, 170, 170), width=1)
    if major: d.text((X - 10, 5), str(x), fill=(0, 0, 0), font=f)
for y in range((y0 // step + 1) * step, y1, step):
    Y = pad + (y - y0) * sc
    major = y % (step * 5) == 0
    d.line([(pad, Y), (canvas.width, Y)], fill=(0, 0, 255) if major else (170, 170, 255), width=1)
    if major: d.text((2, Y - 5), str(y), fill=(0, 0, 0), font=f)
canvas.save(out)

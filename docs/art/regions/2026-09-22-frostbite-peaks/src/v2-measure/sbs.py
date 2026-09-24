# side-by-side: V2 left, build right (same size), plus an optional overlay blend
import sys
from PIL import Image, ImageDraw, ImageFont
V2 = "C:/Users/nguye/Documents/repos/catch-a-catastrophe/CatchACatastrophe/docs/art/regions/2026-09-22-frostbite-peaks/frostbite-peaks-v2-02-alpine-outpost-refined.png"
render, out = sys.argv[1], sys.argv[2]
label = sys.argv[3] if len(sys.argv) > 3 else 'build (placeholder art), refcam'
ref = Image.open(V2).convert('RGB')
r = Image.open(render).convert('RGBA')
bg = Image.new('RGBA', r.size, (247, 245, 241, 255))
bg.alpha_composite(r)
b = bg.convert('RGB')
W, H = ref.size
S = Image.new('RGB', (W * 2 + 20, H + 50), (255, 255, 255))
S.paste(ref, (0, 50)); S.paste(b, (W + 20, 50))
d = ImageDraw.Draw(S)
try:
    f = ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf', 26)
except Exception:
    f = ImageFont.load_default()
d.text((10, 10), 'V2 concept (reference)', font=f, fill=(27, 56, 102))
d.text((W + 30, 10), label, font=f, fill=(27, 56, 102))
S.save(out)
b.save(out.replace('.png', '_bg.png'))

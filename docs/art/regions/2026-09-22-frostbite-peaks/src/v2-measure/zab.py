# crop the same box from V2 and a build render, side by side at a zoom
import sys
from PIL import Image
V2 = "C:/Users/rahul/orca/Catch-a-Catastrophe/docs/art/regions/2026-09-22-frostbite-peaks/frostbite-peaks-v2-02-alpine-outpost-refined.png"
render, out = sys.argv[1], sys.argv[2]
x0, y0, x1, y1 = map(int, sys.argv[3:7])
z = float(sys.argv[7]) if len(sys.argv) > 7 else 2
a = Image.open(V2).convert('RGB').crop((x0, y0, x1, y1))
b = Image.open(render).convert('RGB').crop((x0, y0, x1, y1))
w, h = int((x1 - x0) * z), int((y1 - y0) * z)
S = Image.new('RGB', (w * 2 + 10, h), (255, 255, 255))
S.paste(a.resize((w, h), Image.LANCZOS), (0, 0)); S.paste(b.resize((w, h), Image.LANCZOS), (w + 10, 0))
S.save(out)

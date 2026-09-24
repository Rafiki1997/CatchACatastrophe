"""Labels and pairs the starting-area bush mockup renders (plain Python + Pillow).
Run after create_hub_bushes.py and render_hub_bush_context.py:
  python tools/blender/compose_hub_bush_mockup.py
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parents[2] / 'assets/hub/bushes-v1'

def font(size):
    for name in ('arialbd.ttf', 'DejaVuSans-Bold.ttf'):
        try: return ImageFont.truetype(name, size)
        except OSError: pass
    return ImageFont.load_default()

def banner(img, text, size=34):
    d = ImageDraw.Draw(img); f = font(size); pad = 14
    box = d.textbbox((0, 0), text, font=f)
    d.rectangle((0, 0, box[2] + 2 * pad, box[3] + 2 * pad), fill=(24, 30, 28))
    d.text((pad, pad - box[1] // 2), text, font=f, fill=(255, 255, 255))
    return img

def stack(top, bottom, gap=16):
    w = max(top.width, bottom.width)
    out = Image.new('RGB', (w, top.height + gap + bottom.height), 'white')
    out.paste(top, (0, 0)); out.paste(bottom, (0, top.height + gap)); return out

def side(left, right, gap=16):
    out = Image.new('RGB', (left.width + gap + right.width, max(left.height, right.height)), 'white')
    out.paste(left, (0, 0)); out.paste(right, (left.width + gap, 0)); return out

def rgb(name): return Image.open(OUT / name).convert('RGB')

before = banner(rgb('bushes-lineup-before.png'), 'BEFORE - today\'s bushes, as the game draws them')
after = banner(rgb('bushes-lineup-after.png'), 'AFTER - mockup v1, Gusty broadleaf leaves and materials (Blender source render)')
stack(before, after).save(OUT / 'bushes-before-after.png')

VIEWS = {
    'garden': 'Hub garden from the spawn pad',
    'garden-high': 'Hub garden quadrant',
    'plot': 'Plot 1: border bushes on the fence line',
    'plot-fence': 'Inside plot 1, down the left fence',
    'atlas': 'Atlas pavilion planters',
}
for key, title in VIEWS.items():
    b = banner(rgb('context-%s-before.png' % key), 'BEFORE - ' + title, 30)
    a = banner(rgb('context-%s-after.png' % key), 'AFTER - bushes v1 + Phase 1 broadleaf trees', 30)
    side(b, a).save(OUT / ('context-%s.png' % key))
print('COMPOSED', sorted(p.name for p in OUT.glob('context-*.png') if '-before' not in p.name and '-after' not in p.name))

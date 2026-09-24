# Finish a rendered option for review: the warm off-white presentation ground
# the earlier region rounds use, a soft glow on the lanterns and crystals, and
# the option title with the region subtitle in the lower margin. Also builds
# the five-up contact sheet.
#
#   python compose_frostbite.py raw.png out.png "01" "IGLOO HOLLOW"
#   python compose_frostbite.py --sheet out.png a.png b.png c.png d.png e.png
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops, ImageEnhance

BG = (247, 245, 241)
NUM = (70, 150, 214)
SLASH = (158, 182, 206)
NAME = (27, 56, 102)
SUB = (66, 112, 160)
SUBTITLE = "FROSTBITE PEAKS  \u2022  ENTRY 75,000 COINS"


def font(size, weight="Bold"):
    try:
        f = ImageFont.truetype("C:/Windows/Fonts/bahnschrift.ttf", size)
        for name in (weight + " SemiCondensed", weight, "Bold"):
            try:
                f.set_variation_by_name(name)
                return f
            except Exception:
                continue
        return f
    except Exception:
        return ImageFont.truetype("C:/Windows/Fonts/seguibl.ttf", size)


def bloom(img):
    """Glow from the brightest, most saturated pixels: lantern bulbs, crystal
    tips, the barrier rails. Snow is bright but unsaturated and is left out."""
    rgb = img.convert("RGB")
    hsv = rgb.convert("HSV")
    h, s, v = hsv.split()
    lum = v.point(lambda x: 255 if x > 238 else 0)
    sat = s.point(lambda x: 255 if x > 70 else 0)
    mask = ImageChops.multiply(lum, sat)
    glow_src = Image.composite(rgb, Image.new("RGB", rgb.size, (0, 0, 0)), mask)
    g1 = glow_src.filter(ImageFilter.GaussianBlur(4))
    g2 = glow_src.filter(ImageFilter.GaussianBlur(12))
    glow = ImageChops.add(ImageEnhance.Brightness(g1).enhance(0.55), ImageEnhance.Brightness(g2).enhance(0.45))
    return glow


def compose(raw_path, out_path, num, name):
    raw = Image.open(raw_path).convert("RGBA")
    if raw.size[0] > 1536:
        # rendered oversize for clean edges; finish at the round's 1536 x 1024
        raw = raw.resize((1536, int(raw.size[1] * 1536 / raw.size[0])), Image.LANCZOS)
    W, H = raw.size
    k = W / 1536.0
    bg = Image.new("RGB", (W, H), BG)
    # a faint contact shadow under the diorama
    a = raw.split()[3]
    sh = a.filter(ImageFilter.GaussianBlur(18 * k)).point(lambda x: int(x * 0.16))
    shadow = Image.new("RGB", (W, H), (120, 128, 140))
    bg = Image.composite(shadow, bg, ImageChops.offset(sh, 0, int(10 * k)))
    base = raw.convert("RGB")
    base = ImageEnhance.Color(base).enhance(1.08)
    glow = bloom(raw)
    base = ImageChops.add(base, glow)
    out = Image.composite(base, bg, a)
    # glow spills a little past the diorama edge too
    out = ImageChops.add(out, Image.composite(glow, Image.new("RGB", (W, H), (0, 0, 0)), a.point(lambda x: 255 - x)))
    d = ImageDraw.Draw(out)
    fT = font(int(60 * k))
    fS = font(int(21 * k), "SemiBold")
    parts = [(num, NUM), ("  /  ", SLASH), (name, NAME)]
    widths = [d.textlength(t, font=fT) for t, _ in parts]
    x = (W - sum(widths)) / 2
    yT = H - int(118 * k)
    for (t, col), w in zip(parts, widths):
        d.text((x, yT), t, font=fT, fill=col)
        x += w
    # letter-spaced subtitle between two rules
    spacing = 3.2 * k
    chars = list(SUBTITLE)
    cw = [d.textlength(ch, font=fS) for ch in chars]
    tw = sum(cw) + spacing * (len(chars) - 1)
    x0 = (W - tw) / 2
    yS = H - int(44 * k)
    x = x0
    for ch, w in zip(chars, cw):
        d.text((x, yS), ch, font=fS, fill=SUB)
        x += w + spacing
    ym = yS + int(13 * k)
    rl = int(78 * k)
    gap = int(22 * k)
    d.line([(x0 - gap - rl, ym), (x0 - gap, ym)], fill=SUB, width=max(1, int(2 * k)))
    d.line([(x0 + tw + gap, ym), (x0 + tw + gap + rl, ym)], fill=SUB, width=max(1, int(2 * k)))
    out.save(out_path, optimize=True)


def sheet(out_path, paths):
    ims = [Image.open(p).convert("RGB") for p in paths]
    w = 760
    h = int(ims[0].height * w / ims[0].width)
    pad = 20
    cols = 3
    rows = (len(ims) + cols - 1) // cols
    S = Image.new("RGB", (cols * w + (cols + 1) * pad, rows * h + (rows + 1) * pad + 70), BG)
    d = ImageDraw.Draw(S)
    d.text((pad, 18), "FROSTBITE PEAKS \u2022 FIVE OPTIONS", font=font(40), fill=NAME)
    for i, im in enumerate(ims):
        r, cc = divmod(i, cols)
        if r == rows - 1 and len(ims) % cols:
            off = (cols - len(ims) % cols) * (w + pad) // 2
        else:
            off = 0
        S.paste(im.resize((w, h), Image.LANCZOS), (pad + off + cc * (w + pad), 70 + pad + r * (h + pad)))
    S.save(out_path, optimize=True)


if __name__ == "__main__":
    if sys.argv[1] == "--sheet":
        sheet(sys.argv[2], sys.argv[3:])
    else:
        compose(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])

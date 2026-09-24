# Finish a rendered Thunderworks option for review, in the same format as
# the Frostbite round: the warm off-white presentation ground, a soft glow on
# arcs, lanterns and lit windows, and the option title with the region
# subtitle in the lower margin. Also builds the five-up overview and the
# plan sheet.
#
#   python compose_thunderworks.py raw.png out.png "01" "TESLA COIL WORKS"
#   python compose_thunderworks.py --sheet out.png a.png b.png c.png d.png e.png
#   python compose_thunderworks.py --plans out.png "01|TITLE|plan.png" ...
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops, ImageEnhance

BG = (247, 245, 241)
NUM = (214, 146, 52)
SLASH = (190, 168, 132)
NAME = (30, 40, 64)
SUB = (86, 96, 122)
SUBTITLE = "THUNDERWORKS  \u2022  ENTRY 300,000 COINS"


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
    """Glow from the brightest, most saturated pixels: arcs, lantern bulbs,
    lit windows, the barrier rails. Snow is bright but unsaturated and is
    left out, as in the Frostbite round."""
    rgb = img.convert("RGB")
    hsv = rgb.convert("HSV")
    h, s, v = hsv.split()
    lum = v.point(lambda x: 255 if x > 232 else 0)
    sat = s.point(lambda x: 255 if x > 58 else 0)
    mask = ImageChops.multiply(lum, sat)
    # Arc cores render pure white (saturation 0), so also take anything whose
    # darkest channel is near white. Snow peaks near V 215 here and stays out.
    r_, g_, b_ = rgb.split()
    core = ImageChops.darker(ImageChops.darker(r_, g_), b_).point(lambda x: 255 if x >= 240 else 0)
    mask = ImageChops.lighter(mask, core)
    glow_src = Image.composite(rgb, Image.new("RGB", rgb.size, (0, 0, 0)), mask)
    arc_tint = Image.composite(Image.new("RGB", rgb.size, (150, 190, 255)), Image.new("RGB", rgb.size, (0, 0, 0)), core)
    g1 = glow_src.filter(ImageFilter.GaussianBlur(4))
    g2 = glow_src.filter(ImageFilter.GaussianBlur(14))
    g3 = arc_tint.filter(ImageFilter.GaussianBlur(9))
    glow = ImageChops.add(ImageEnhance.Brightness(g1).enhance(0.6), ImageEnhance.Brightness(g2).enhance(0.5))
    glow = ImageChops.add(glow, ImageEnhance.Brightness(g3).enhance(1.6))
    return glow


def compose(raw_path, out_path, num, name):
    raw = Image.open(raw_path).convert("RGBA")
    if raw.size[0] > 1536:
        # rendered oversize for clean edges; finish at the round's 1536 x 1024
        raw = raw.resize((1536, int(raw.size[1] * 1536 / raw.size[0])), Image.LANCZOS)
    W, H = raw.size
    k = W / 1536.0
    bg = Image.new("RGB", (W, H), BG)
    a = raw.split()[3]
    sh = a.filter(ImageFilter.GaussianBlur(18 * k)).point(lambda x: int(x * 0.16))
    shadow = Image.new("RGB", (W, H), (120, 128, 140))
    bg = Image.composite(shadow, bg, ImageChops.offset(sh, 0, int(10 * k)))
    base = raw.convert("RGB")
    base = ImageEnhance.Color(base).enhance(1.08)
    glow = bloom(raw)
    base = ImageChops.add(base, glow)
    out = Image.composite(base, bg, a)
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


def sheet(out_path, paths, title="THUNDERWORKS \u2022 FIVE OPTIONS"):
    ims = [Image.open(p).convert("RGB") for p in paths]
    w = 760
    h = int(ims[0].height * w / ims[0].width)
    pad = 20
    cols = 3
    rows = (len(ims) + cols - 1) // cols
    S = Image.new("RGB", (cols * w + (cols + 1) * pad, rows * h + (rows + 1) * pad + 70), BG)
    d = ImageDraw.Draw(S)
    d.text((pad, 18), title, font=font(40), fill=NAME)
    for i, im in enumerate(ims):
        r, cc = divmod(i, cols)
        if r == rows - 1 and len(ims) % cols:
            off = (cols - len(ims) % cols) * (w + pad) // 2
        else:
            off = 0
        S.paste(im.resize((w, h), Image.LANCZOS), (pad + off + cc * (w + pad), 70 + pad + r * (h + pad)))
    S.save(out_path, optimize=True)


def plans(out_path, specs):
    """Straight-down plans of each option, captioned, on one sheet."""
    ims = []
    for spec in specs:
        num, name, path = spec.split("|")
        im = Image.open(path).convert("RGBA")
        bg = Image.new("RGBA", im.size, BG + (255,))
        bg.alpha_composite(im)
        ims.append((num, name, bg.convert("RGB")))
    w = 760
    h = int(ims[0][2].height * w / ims[0][2].width)
    pad, cap = 20, 44
    cols = 3
    rows = (len(ims) + cols - 1) // cols
    S = Image.new("RGB", (cols * w + (cols + 1) * pad, rows * (h + cap) + (rows + 1) * pad + 70), BG)
    d = ImageDraw.Draw(S)
    d.text((pad, 18), "THUNDERWORKS \u2022 PLANS (NORTH UP, ORBIT OUTPOST GATE AT THE TOP)", font=font(34), fill=NAME)
    f = font(26)
    for i, (num, name, im) in enumerate(ims):
        r, cc = divmod(i, cols)
        off = (cols - len(ims) % cols) * (w + pad) // 2 if (r == rows - 1 and len(ims) % cols) else 0
        x = pad + off + cc * (w + pad)
        y = 70 + pad + r * (h + cap + pad)
        S.paste(im.resize((w, h), Image.LANCZOS), (x, y))
        d.text((x + 6, y + h + 6), num + "  /  " + name, font=f, fill=NAME)
    S.save(out_path, optimize=True)


if __name__ == "__main__":
    if sys.argv[1] == "--sheet":
        sheet(sys.argv[2], sys.argv[3:])
    elif sys.argv[1] == "--plans":
        plans(sys.argv[2], sys.argv[3:])
    else:
        compose(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])

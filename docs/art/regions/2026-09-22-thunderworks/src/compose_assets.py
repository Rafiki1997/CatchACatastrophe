# Finish the Thunderworks asset renders: one captioned card per asset
# (title, measured size in studs, what it is, which options use it) and the
# kit sheet with every asset on one page.
#
#   python compose_assets.py RAW_DIR OUT_DIR
#
# RAW_DIR holds render_asset.py's <id>.png / <id>.json pairs; OUT_DIR gets
# tw-asset-NN-<id>.png per asset and thunderworks-asset-kit.png.
import os
import sys
import json
from PIL import Image, ImageDraw, ImageFilter, ImageChops, ImageEnhance

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from compose_thunderworks import font, bloom, BG, NUM, NAME, SUB  # noqa: E402

ORDER = ["tesla_coil", "dynamo_hall", "leyden_rack", "spark_gap", "storm_jar", "battery_bank",
         "collector_mast", "gantry", "power_transformer", "circuit_breaker", "switch_house", "dynamo_drum",
         "barrel_workshop", "locomotive", "engine_shed", "rails", "catenary_mast", "water_tower",
         "pylon", "floodlight", "cable_tray", "utility_pole", "fence_section", "flatcar",
         "barrier_block", "yard_clutter"]
CHIP = (232, 226, 214)


def studs(v):
    return ("%.1f" % v).rstrip("0").rstrip(".")


def finish_render(raw):
    """Presentation ground, contact shadow from the shadow catcher, glow."""
    W, H = raw.size
    top = (250, 249, 246)
    bot = (236, 234, 229)
    grad = Image.new("RGB", (1, H))
    for y in range(H):
        t = y / (H - 1)
        grad.putpixel((0, y), tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))
    bg = grad.resize((W, H))
    base = ImageEnhance.Color(raw.convert("RGB")).enhance(1.06)
    base = ImageChops.add(base, bloom(raw))
    return Image.composite(base, bg, raw.split()[3])


def card(raw_path, meta, out_path, idx):
    raw = Image.open(raw_path).convert("RGBA")
    W, H = raw.size
    k = W / 1600.0
    body = finish_render(raw)
    capH = int(190 * k)
    C = Image.new("RGB", (W, H + capH), BG)
    C.paste(body, (0, 0))
    d = ImageDraw.Draw(C)
    d.line([(int(60 * k), H), (W - int(60 * k), H)], fill=(214, 206, 192), width=max(1, int(2 * k)))
    x0 = int(60 * k)
    fT = font(int(58 * k))
    fN = font(int(58 * k))
    num = "%02d" % idx
    d.text((x0, H + int(26 * k)), num, font=fN, fill=NUM)
    nx = x0 + d.textlength(num + "  ", font=fN)
    d.text((nx, H + int(26 * k)), meta["title"].upper(), font=fT, fill=NAME)
    fB = font(int(26 * k), "SemiBold")
    d.text((x0, H + int(104 * k)), meta["blurb"], font=fB, fill=SUB)
    w_, d_, h_ = meta["size_wdh"]
    size_txt = "%s × %s × %s STUDS  (W × D × H)" % (studs(w_), studs(d_), studs(h_))
    fS = font(int(24 * k), "SemiBold")
    d.text((x0, H + int(146 * k)), size_txt, font=fS, fill=NAME)
    # option chips on the right
    opts = meta["options"].split()
    label = "ALL OPTIONS" if opts == ["all"] else "OPTIONS"
    chips = ["ALL"] if opts == ["all"] else opts
    fC = font(int(26 * k))
    xr = W - int(60 * k)
    cy = H + int(140 * k)
    for ch in reversed(chips):
        tw = d.textlength(ch, font=fC)
        bw = tw + int(26 * k)
        d.rounded_rectangle([xr - bw, cy - int(4 * k), xr, cy + int(36 * k)], radius=int(10 * k), fill=CHIP)
        d.text((xr - bw + int(13 * k), cy), ch, font=fC, fill=NAME)
        xr -= bw + int(10 * k)
    fL = font(int(20 * k), "SemiBold")
    d.text((xr - d.textlength(label, font=fL) - int(4 * k), cy + int(8 * k)), label, font=fL, fill=SUB)
    fK = font(int(20 * k), "SemiBold")
    tag = "THUNDERWORKS KIT  •  GREY FIGURE = 5-STUD AVATAR"
    d.text((W - int(60 * k) - d.textlength(tag, font=fK), int(26 * k)), tag, font=fK, fill=SUB)
    C.save(out_path, optimize=True)
    return C


def kit_sheet(cards, metas, out_path):
    cols = 6
    w = 520
    h = int(cards[0].height * w / cards[0].width)
    pad = 18
    rows = (len(cards) + cols - 1) // cols
    S = Image.new("RGB", (cols * w + (cols + 1) * pad, rows * h + (rows + 1) * pad + 96), BG)
    d = ImageDraw.Draw(S)
    d.text((pad + 4, 22), "THUNDERWORKS • ASSET KIT", font=font(48), fill=NAME)
    sub = "%d NEW ASSETS FOR THE FIVE OPTIONS  •  BLENDER, TRUE STUD SCALE  •  GREY FIGURE = 5-STUD AVATAR" % len(cards)
    fS = font(22, "SemiBold")
    d.text((S.width - pad - d.textlength(sub, font=fS), 40), sub, font=fS, fill=SUB)
    for i, c in enumerate(cards):
        r, cc = divmod(i, cols)
        S.paste(c.resize((w, h), Image.LANCZOS), (pad + cc * (w + pad), 96 + pad + r * (h + pad)))
    S.save(out_path, optimize=True)


def main():
    raw_dir, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)
    cards, metas = [], []
    idx = 0
    for aid in ORDER:
        png = os.path.join(raw_dir, aid + ".png")
        js = os.path.join(raw_dir, aid + ".json")
        if not (os.path.exists(png) and os.path.exists(js)):
            continue
        idx += 1
        meta = json.load(open(js))
        out = os.path.join(out_dir, "tw-asset-%02d-%s.png" % (idx, aid.replace("_", "-")))
        cards.append(card(png, meta, out, idx))
        metas.append(meta)
        print("card", out)
    kit_sheet(cards, metas, os.path.join(os.path.dirname(out_dir.rstrip("/\\")), "thunderworks-asset-kit.png"))
    with open(os.path.join(out_dir, "assets.json"), "w") as f:
        json.dump(metas, f, indent=2)


if __name__ == "__main__":
    main()

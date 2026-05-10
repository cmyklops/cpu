#!/usr/bin/env python3
"""Generate CPUMeter macOS app icons at all required sizes."""

from PIL import Image, ImageDraw, ImageFilter
import os

OUTPUT_DIR = os.path.join(
    os.path.dirname(__file__),
    "CPUMeter/Assets.xcassets/AppIcon.appiconset"
)


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


def rounded_gradient(size, radius, top, bottom):
    """Create a clipped vertical gradient for a rounded app-icon layer."""
    gradient = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(gradient)
    for y in range(size):
        t = y / max(1, size - 1)
        color = tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(4))
        gd.line([(0, y), (size, y)], fill=color)

    mask = Image.new("L", (size, size), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    gradient.putalpha(mask)
    return gradient


def create_icon(size):
    """Create a CPUMeter icon at the given pixel size."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    s = size

    # ── Background ────────────────────────────────────────────────────────────
    corner_r = int(s * 0.225)
    base = rounded_gradient(
        s,
        corner_r,
        top=(248, 253, 255, 230),
        bottom=(42, 72, 104, 245),
    )
    img = Image.alpha_composite(img, base)
    draw = ImageDraw.Draw(img)

    # Ambient color and specular edge.
    if size >= 64:
        overlay = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        od = ImageDraw.Draw(overlay)
        od.ellipse(
            [int(-s * 0.18), int(-s * 0.16), int(s * 0.82), int(s * 0.78)],
            fill=(255, 255, 255, 86),
        )
        od.ellipse(
            [int(s * 0.30), int(s * 0.30), int(s * 1.18), int(s * 1.12)],
            fill=(0, 220, 190, 42),
        )
        od.ellipse(
            [int(-s * 0.04), int(s * 0.48), int(s * 0.78), int(s * 1.20)],
            fill=(96, 115, 255, 34),
        )
        overlay = overlay.filter(ImageFilter.GaussianBlur(max(1, int(s * 0.035))))
        img = Image.alpha_composite(img, overlay)
        draw = ImageDraw.Draw(img)

    draw.rounded_rectangle(
        [int(s * 0.035), int(s * 0.035), int(s * 0.965), int(s * 0.965)],
        radius=int(corner_r * 0.88),
        outline=(255, 255, 255, 112),
        width=max(1, int(s * 0.012)),
    )

    # ── CPU Chip body ─────────────────────────────────────────────────────────
    chip_pad = s * 0.18
    cx0, cy0 = chip_pad, chip_pad
    cx1, cy1 = s - chip_pad, s - chip_pad
    chip_w = cx1 - cx0
    chip_h = cy1 - cy0
    chip_corner = max(2, int(s * 0.05))
    border_w = max(1, int(s * 0.025))

    chip_layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    cd = ImageDraw.Draw(chip_layer)
    cd.rounded_rectangle(
        [int(cx0), int(cy0), int(cx1), int(cy1)],
        radius=chip_corner,
        fill=(232, 250, 255, 84),
    )
    cd.rounded_rectangle(
        [int(cx0), int(cy0), int(cx1), int(cy1)],
        radius=chip_corner,
        outline=(255, 255, 255, 184),
        width=border_w,
    )
    if size >= 128:
        shadow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        sd = ImageDraw.Draw(shadow)
        sd.rounded_rectangle(
            [int(cx0), int(cy0 + s * 0.025), int(cx1), int(cy1 + s * 0.025)],
            radius=chip_corner,
            fill=(0, 18, 34, 62),
        )
        shadow = shadow.filter(ImageFilter.GaussianBlur(max(1, int(s * 0.025))))
        img = Image.alpha_composite(img, shadow)
    img = Image.alpha_composite(img, chip_layer)
    draw = ImageDraw.Draw(img)

    # ── Pins ──────────────────────────────────────────────────────────────────
    if size >= 48:
        pin_n = 3
        pin_thick = max(1, int(s * 0.018))
        pin_len = max(2, int(s * 0.09))
        pin_col = (218, 250, 255, 182)

        v_step = chip_h / (pin_n + 1)
        for i in range(pin_n):
            py = int(cy0 + v_step * (i + 1))
            py0, py1 = py - pin_thick // 2, py + pin_thick // 2 + 1
            draw.rectangle([int(cx0) - pin_len, py0, int(cx0) - border_w, py1], fill=pin_col)
            draw.rectangle([int(cx1) + border_w, py0, int(cx1) + pin_len, py1], fill=pin_col)

        h_step = chip_w / (pin_n + 1)
        for i in range(pin_n):
            px = int(cx0 + h_step * (i + 1))
            px0, px1 = px - pin_thick // 2, px + pin_thick // 2 + 1
            draw.rectangle([px0, int(cy0) - pin_len, px1, int(cy0) - border_w], fill=pin_col)
            draw.rectangle([px0, int(cy1) + border_w, px1, int(cy1) + pin_len], fill=pin_col)

    # ── Activity bars ─────────────────────────────────────────────────────────
    inner_pad = s * 0.30
    bax0, bay0 = inner_pad, inner_pad
    bax1, bay1 = s - inner_pad, s - inner_pad
    bar_area_w = bax1 - bax0
    bar_area_h = bay1 - bay0

    if size >= 48:
        bar_count = 5
        heights = [0.45, 0.85, 0.60, 1.0, 0.55]
    else:
        bar_count = 3
        heights = [0.60, 1.0, 0.70]

    bar_spacing = bar_area_w / bar_count
    bar_width = bar_spacing * 0.58
    bar_corner = max(1, int(bar_width * 0.30))

    for i, h in enumerate(heights):
        bx = bax0 + i * bar_spacing + (bar_spacing - bar_width) / 2
        bh = bar_area_h * h
        by = bay1 - bh
        if h < 0.58:
            r, g, b = (77, 240, 190)
        elif h < 0.86:
            r, g, b = (255, 210, 88)
        else:
            r, g, b = (255, 92, 102)
        draw.rounded_rectangle(
            [bx, by, bx + bar_width, bay1],
            radius=bar_corner,
            fill=(r, g, b, 232),
        )
        if size >= 96:
            draw.line(
                [(bx + bar_width * 0.28, by + bar_width * 0.22), (bx + bar_width * 0.28, bay1 - bar_width * 0.30)],
                fill=(255, 255, 255, 90),
                width=max(1, int(bar_width * 0.12)),
            )

    # Bar glow for large sizes
    if size >= 128:
        glow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        gd = ImageDraw.Draw(glow)
        for i, h in enumerate(heights):
            bx = bax0 + i * bar_spacing + (bar_spacing - bar_width) / 2
            bh = bar_area_h * h
            by = bay1 - bh
            if h < 0.58:
                r, g, b = (77, 240, 190)
            elif h < 0.86:
                r, g, b = (255, 210, 88)
            else:
                r, g, b = (255, 92, 102)
            exp = int(s * 0.015)
            gd.rounded_rectangle(
                [bx - exp, by - exp, bx + bar_width + exp, bay1],
                radius=bar_corner + exp,
                fill=(r, g, b, 46),
            )
        glow = glow.filter(ImageFilter.GaussianBlur(max(1, int(s * 0.012))))
        img = Image.alpha_composite(img, glow)

    if size >= 128:
        shine = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        sd = ImageDraw.Draw(shine)
        sd.arc(
            [int(s * 0.13), int(s * 0.08), int(s * 0.86), int(s * 0.54)],
            start=196,
            end=338,
            fill=(255, 255, 255, 118),
            width=max(1, int(s * 0.018)),
        )
        img = Image.alpha_composite(img, shine)

    return img


# (pixel_size, output_filename)
ICONS = [
    (16,   "icon_16x16.png"),
    (32,   "icon_16x16@2x.png"),
    (32,   "icon_32x32.png"),
    (64,   "icon_32x32@2x.png"),
    (128,  "icon_128x128.png"),
    (256,  "icon_128x128@2x.png"),
    (256,  "icon_256x256.png"),
    (512,  "icon_256x256@2x.png"),
    (512,  "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    cache = {}
    for pixel_size, filename in ICONS:
        if pixel_size not in cache:
            cache[pixel_size] = create_icon(pixel_size)
        out_path = os.path.join(OUTPUT_DIR, filename)
        cache[pixel_size].save(out_path, "PNG")
        print(f"  Saved {filename}  ({pixel_size}px)")
    print("\nAll icons generated.")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Generate CPUMeter macOS app icons at all required sizes."""

from PIL import Image, ImageDraw
import os

OUTPUT_DIR = os.path.join(
    os.path.dirname(__file__),
    "CPUMeter/Assets.xcassets/AppIcon.appiconset"
)


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


def create_icon(size):
    """Create a CPUMeter icon at the given pixel size."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    s = size

    # ── Background ────────────────────────────────────────────────────────────
    corner_r = int(s * 0.225)
    draw.rounded_rectangle(
        [0, 0, s - 1, s - 1],
        radius=corner_r,
        fill=(20, 24, 52, 255),
    )

    # Subtle upper glow
    if size >= 64:
        overlay = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        od = ImageDraw.Draw(overlay)
        gw = int(s * 0.70)
        gx = (s - gw) // 2
        gy = int(s * 0.02)
        od.ellipse([gx, gy, gx + gw, gy + gw], fill=(60, 100, 180, 25))
        img = Image.alpha_composite(img, overlay)
        draw = ImageDraw.Draw(img)

    # ── CPU Chip body ─────────────────────────────────────────────────────────
    chip_pad = s * 0.18
    cx0, cy0 = chip_pad, chip_pad
    cx1, cy1 = s - chip_pad, s - chip_pad
    chip_w = cx1 - cx0
    chip_h = cy1 - cy0
    chip_corner = max(2, int(s * 0.05))
    border_w = max(1, int(s * 0.025))

    # Chip fill (slightly lighter than bg)
    draw.rounded_rectangle(
        [cx0, cy0, cx1, cy1],
        radius=chip_corner,
        fill=(28, 34, 68, 255),
    )
    # Chip border
    draw.rounded_rectangle(
        [cx0, cy0, cx1, cy1],
        radius=chip_corner,
        outline=(70, 130, 230, 255),
        width=border_w,
    )

    # ── Pins ──────────────────────────────────────────────────────────────────
    if size >= 48:
        pin_n = 3
        pin_thick = max(1, int(s * 0.018))
        pin_len = max(2, int(s * 0.09))
        pin_col = (70, 130, 230, 200)

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
        r = 0
        g = int(clamp(155 + h * 85, 0, 255))
        b = int(clamp(80 + h * 170, 0, 255))
        draw.rounded_rectangle(
            [bx, by, bx + bar_width, bay1],
            radius=bar_corner,
            fill=(r, g, b, 240),
        )

    # Bar glow for large sizes
    if size >= 128:
        glow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        gd = ImageDraw.Draw(glow)
        for i, h in enumerate(heights):
            bx = bax0 + i * bar_spacing + (bar_spacing - bar_width) / 2
            bh = bar_area_h * h
            by = bay1 - bh
            r = 0
            g = int(clamp(155 + h * 85, 0, 255))
            b = int(clamp(80 + h * 170, 0, 255))
            exp = int(s * 0.015)
            gd.rounded_rectangle(
                [bx - exp, by - exp, bx + bar_width + exp, bay1],
                radius=bar_corner + exp,
                fill=(r, g, b, 38),
            )
        img = Image.alpha_composite(img, glow)

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

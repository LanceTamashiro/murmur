#!/usr/bin/env python3
"""Generate Murmur app icons — a stylized waveform on an indigo-violet gradient."""

import math
from pathlib import Path
from PIL import Image, ImageDraw

# Output directory
ICON_DIR = Path(__file__).parent.parent / "Murmur" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset"

# macOS required icon sizes: (filename, pixel_size)
ICON_SIZES = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

MASTER_SIZE = 1024


def superellipse_mask(size: int, n: float = 5.0) -> Image.Image:
    """Create a macOS-style squircle (superellipse) mask."""
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    cx, cy = size / 2, size / 2
    # Inset slightly so the edge isn't clipped
    r = size / 2 * 0.93

    points = []
    for deg in range(360):
        t = math.radians(deg)
        cos_t = math.cos(t)
        sin_t = math.sin(t)
        x = cx + r * math.copysign(abs(cos_t) ** (2 / n), cos_t)
        y = cy + r * math.copysign(abs(sin_t) ** (2 / n), sin_t)
        points.append((x, y))

    draw.polygon(points, fill=255)
    return mask


def draw_gradient(img: Image.Image):
    """Draw a rich indigo → violet → soft teal diagonal gradient."""
    w, h = img.size
    pixels = img.load()

    # Color stops: deep indigo → violet → teal-tinged purple
    c1 = (58, 12, 163)    # Deep indigo
    c2 = (142, 45, 226)   # Violet
    c3 = (74, 0, 224)     # Electric indigo
    c4 = (50, 100, 200)   # Soft teal-blue accent

    for y in range(h):
        for x in range(w):
            # Diagonal gradient factor
            t = (x / w * 0.6 + y / h * 0.4)
            # Multi-stop interpolation
            if t < 0.33:
                f = t / 0.33
                r = int(c1[0] + (c2[0] - c1[0]) * f)
                g = int(c1[1] + (c2[1] - c1[1]) * f)
                b = int(c1[2] + (c2[2] - c1[2]) * f)
            elif t < 0.66:
                f = (t - 0.33) / 0.33
                r = int(c2[0] + (c3[0] - c2[0]) * f)
                g = int(c2[1] + (c3[1] - c2[1]) * f)
                b = int(c2[2] + (c3[2] - c2[2]) * f)
            else:
                f = (t - 0.66) / 0.34
                r = int(c3[0] + (c4[0] - c3[0]) * f)
                g = int(c3[1] + (c4[1] - c3[1]) * f)
                b = int(c3[2] + (c4[2] - c3[2]) * f)
            pixels[x, y] = (r, g, b, 255)


def draw_waveform(draw: ImageDraw.Draw, size: int):
    """Draw stylized audio waveform bars — the core visual element."""
    # 7 bars with varying heights to create a speech-like waveform pattern
    bar_heights = [0.18, 0.32, 0.55, 0.70, 0.50, 0.35, 0.15]
    num_bars = len(bar_heights)

    total_width = size * 0.52
    bar_width = total_width / num_bars * 0.55
    gap = total_width / num_bars
    start_x = (size - total_width) / 2 + gap * 0.22
    center_y = size * 0.50

    # Slight glow/shadow layer first (subtle depth)
    for i, h_ratio in enumerate(bar_heights):
        bar_h = size * h_ratio * 0.42
        x = start_x + i * gap
        radius = bar_width / 2

        draw.rounded_rectangle(
            [x - 1, center_y - bar_h - 1, x + bar_width + 1, center_y + bar_h + 1],
            radius=radius + 1,
            fill=(255, 255, 255, 40),
        )

    # Main white bars
    for i, h_ratio in enumerate(bar_heights):
        bar_h = size * h_ratio * 0.42
        x = start_x + i * gap
        radius = bar_width / 2

        draw.rounded_rectangle(
            [x, center_y - bar_h, x + bar_width, center_y + bar_h],
            radius=radius,
            fill=(255, 255, 255, 230),
        )

    # Bright inner highlight for depth
    for i, h_ratio in enumerate(bar_heights):
        bar_h = size * h_ratio * 0.42
        x = start_x + i * gap
        inset = bar_width * 0.18
        inner_h = bar_h * 0.75
        radius = (bar_width - 2 * inset) / 2

        draw.rounded_rectangle(
            [x + inset, center_y - inner_h, x + bar_width - inset, center_y + inner_h],
            radius=max(radius, 1),
            fill=(255, 255, 255, 255),
        )


def generate_master_icon() -> Image.Image:
    """Generate the 1024x1024 master icon."""
    img = Image.new("RGBA", (MASTER_SIZE, MASTER_SIZE), (0, 0, 0, 0))

    # Draw gradient background
    draw_gradient(img)

    # Draw waveform
    draw = ImageDraw.Draw(img)
    draw_waveform(draw, MASTER_SIZE)

    # Apply squircle mask
    mask = superellipse_mask(MASTER_SIZE)
    img.putalpha(mask)

    return img


def main():
    print("Generating Murmur app icons...")
    master = generate_master_icon()

    ICON_DIR.mkdir(parents=True, exist_ok=True)

    for filename, px_size in ICON_SIZES:
        resized = master.resize((px_size, px_size), Image.LANCZOS)
        out_path = ICON_DIR / filename
        resized.save(out_path, "PNG")
        print(f"  {filename} ({px_size}x{px_size})")

    print(f"\nGenerated {len(ICON_SIZES)} icons in {ICON_DIR}")


if __name__ == "__main__":
    main()

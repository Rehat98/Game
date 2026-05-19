#!/usr/bin/env python3
"""Add a minimal iPhone 17 Pro Max device frame to each screenshot in
`docs/launch/screenshots/`. Outputs framed versions to `docs/launch/screenshots/framed/`.

Frame composition (no third-party device-mockup assets needed):
  - Rounded corners on the screenshot (60px radius)
  - Solid black bezel (~14px) around the screen
  - Subtle inner highlight + outer drop shadow for depth
  - Soft neutral background for marketing-ready PNGs

Output canvas size matches input (1320x2868) so the files are still
App Store 6.9"-compatible. Screen content is scaled down slightly to
accommodate the bezel.

Requires Pillow (already installed user-local). Run from anywhere:
    python3 scripts/frame-screenshots.py
"""

from PIL import Image, ImageDraw, ImageFilter
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
SRC_DIR = REPO / "docs" / "launch" / "screenshots"
OUT_DIR = SRC_DIR / "framed"

BEZEL_PX = 14         # black device edge thickness
SCREEN_CORNER = 60    # px corner radius for the screen edge
BEZEL_CORNER = 74     # px corner radius for the outer black bezel (screen + bezel)
SHADOW_BLUR = 32      # px gaussian blur for drop shadow
SHADOW_OFFSET = 16    # px Y offset for drop shadow
SHADOW_OPACITY = 80   # 0-255
BG_COLOR = (255, 255, 255, 255)   # white — App-Store-marketing standard
BEZEL_COLOR = (16, 16, 16, 255)    # near-black device edge


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    """Build an L-mode (alpha) mask with rounded corners."""
    w, h = size
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w, h), radius=radius, fill=255)
    return mask


def frame_one(src_path: Path, dst_path: Path) -> None:
    screen = Image.open(src_path).convert("RGBA")
    canvas_w, canvas_h = screen.size

    # Scale screen down to leave room for the bezel inside the canvas.
    inner_w = canvas_w - 2 * BEZEL_PX
    inner_h = canvas_h - 2 * BEZEL_PX
    screen_scaled = screen.resize((inner_w, inner_h), Image.LANCZOS)

    # Apply rounded corners to the scaled screen content.
    screen_mask = rounded_mask((inner_w, inner_h), SCREEN_CORNER)
    rounded_screen = Image.new("RGBA", (inner_w, inner_h), (0, 0, 0, 0))
    rounded_screen.paste(screen_scaled, (0, 0), screen_mask)

    # Build the black bezel as a rounded rectangle.
    bezel_layer = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    bezel_draw = ImageDraw.Draw(bezel_layer)
    bezel_draw.rounded_rectangle(
        (0, 0, canvas_w - 1, canvas_h - 1),
        radius=BEZEL_CORNER,
        fill=BEZEL_COLOR,
    )

    # Compose: bezel on bottom, screen on top inset by BEZEL_PX.
    device = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    device = Image.alpha_composite(device, bezel_layer)
    device.paste(rounded_screen, (BEZEL_PX, BEZEL_PX), rounded_screen)

    # Drop shadow under the device.
    shadow = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    sd_draw = ImageDraw.Draw(shadow)
    sd_draw.rounded_rectangle(
        (0, 0, canvas_w - 1, canvas_h - 1),
        radius=BEZEL_CORNER,
        fill=(0, 0, 0, SHADOW_OPACITY),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(SHADOW_BLUR))

    # Final composite onto a cream background, with shadow offset down.
    background = Image.new("RGBA", (canvas_w, canvas_h), BG_COLOR)
    # Paste shadow with Y offset (clipped to canvas — shadow falls within canvas).
    background.alpha_composite(shadow, dest=(0, SHADOW_OFFSET))
    # Paste device on top.
    background.alpha_composite(device)

    background.save(dst_path, "PNG", optimize=True)


def main() -> None:
    if not SRC_DIR.exists():
        raise SystemExit(f"Source dir not found: {SRC_DIR}")
    OUT_DIR.mkdir(exist_ok=True)

    pngs = sorted(p for p in SRC_DIR.glob("*.png") if p.name != "README.md")
    if not pngs:
        raise SystemExit(f"No PNGs in {SRC_DIR}")

    for src in pngs:
        dst = OUT_DIR / src.name
        print(f"  Framing {src.name} -> {dst.relative_to(REPO)}")
        frame_one(src, dst)

    print(f"\nDone. {len(pngs)} framed screenshots in {OUT_DIR.relative_to(REPO)}/")


if __name__ == "__main__":
    main()

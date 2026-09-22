#!/usr/bin/env python3
"""Generate the app icon procedurally.

§9 forbids stock or commissioned art: every image in this project is produced by
code in this repo. This draws the mark — a doubled ascending chevron, read as
"levelling up" — and writes the flattened 1024x1024 RGB PNG that both the iOS and
watchOS asset catalogues point at.

App Store icons must have no alpha channel, so the output is RGB and never RGBA.
The mark is inset far enough to survive watchOS's circular mask.

    python3 tools/generate-app-icon.py
"""

from __future__ import annotations

import pathlib

from PIL import Image, ImageDraw

SIZE = 1024
SUPERSAMPLE = 4  # draw large, downsample once — cheap antialiasing without a lib

BACKDROP_TOP = (16, 19, 26)
BACKDROP_BOTTOM = (29, 35, 48)
CHEVRON_UPPER = (245, 247, 250)
CHEVRON_LOWER = (229, 56, 59)  # the §9 primary-muscle accent


def _vertical_gradient(size: int, top: tuple[int, int, int],
                       bottom: tuple[int, int, int]) -> Image.Image:
    base = Image.new("RGB", (1, size))
    pixels = base.load()
    for y in range(size):
        t = y / (size - 1)
        pixels[0, y] = tuple(round(a + (b - a) * t) for a, b in zip(top, bottom))
    return base.resize((size, size), Image.NEAREST)


def _chevron(draw: ImageDraw.ImageDraw, cx: float, cy: float,
             half_width: float, rise: float, stroke: float,
             colour: tuple[int, int, int]) -> None:
    """One ascending chevron, apex up, drawn as a round-jointed polyline."""
    draw.line(
        [(cx - half_width, cy + rise), (cx, cy), (cx + half_width, cy + rise)],
        fill=colour, width=round(stroke), joint="curve",
    )
    # Round the two open ends; ImageDraw.line leaves them square.
    for x in (cx - half_width, cx + half_width):
        r = stroke / 2
        draw.ellipse([x - r, cy + rise - r, x + r, cy + rise + r], fill=colour)


def build() -> Image.Image:
    s = SIZE * SUPERSAMPLE
    img = _vertical_gradient(s, BACKDROP_TOP, BACKDROP_BOTTOM)
    draw = ImageDraw.Draw(img)

    half_width = s * 0.215
    rise = s * 0.150
    stroke = s * 0.088

    # Offsets place the mark's ink centre on the canvas centre, not its apex:
    # the drawn extent runs from (upper - stroke/2) to (lower + rise + stroke/2).
    _chevron(draw, s / 2, s * 0.323, half_width, rise, stroke, CHEVRON_UPPER)
    _chevron(draw, s / 2, s * 0.528, half_width, rise, stroke, CHEVRON_LOWER)

    return img.resize((SIZE, SIZE), Image.LANCZOS).convert("RGB")


def main() -> None:
    repo = pathlib.Path(__file__).resolve().parent.parent
    icon = build()
    targets = [
        repo / "app/StudentAthlete/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png",
        repo / "app/StudentAthleteWatch/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png",
    ]
    for path in targets:
        path.parent.mkdir(parents=True, exist_ok=True)
        icon.save(path, "PNG", optimize=True)
        print(f"wrote {path.relative_to(repo)} ({path.stat().st_size} bytes)")

    assert icon.mode == "RGB", "App Store icons must not carry an alpha channel"


if __name__ == "__main__":
    main()

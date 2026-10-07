#!/usr/bin/env python3
"""Website screenshots from the real app.

    gh run download <screenshots run> -n app-store-screenshots -D /tmp/shots
    python3 website/screens.py /tmp/shots [dashboard.png]

Takes the iPhone tabs, the schedule sheet and the Watch from the
`screenshots` workflow and (optionally) the coach dashboard from
dashboard-shot.mjs, and writes them as WebP to src/assets/screens/.
"""
import pathlib
import sys

from PIL import Image

shots = pathlib.Path(sys.argv[1])
out = pathlib.Path(__file__).resolve().parent / "src/assets/screens"
out.mkdir(parents=True, exist_ok=True)


def save(src: pathlib.Path, name: str, width: int) -> None:
    im = Image.open(src).convert("RGB")
    im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
    im.save(out / f"{name}.webp", "WEBP", quality=84, method=6)
    print(f"{name}.webp  {im.width}x{im.height}")


def one(pattern: str) -> pathlib.Path:
    found = sorted(shots.glob(pattern))
    if not found:
        sys.exit(f"missing {pattern} in {shots}")
    return found[0]


for tab, name in [("today", "home"), ("workout", "workout"), ("campus", "campus")]:
    save(one(f"iPhone*-dark-{tab}.png"), name, 660)
save(one("all/iPhone*-home-schedule.png"), "schedule", 660)
save(one("Watch-1-today.png"), "watch", 420)
if len(sys.argv) > 2:
    save(pathlib.Path(sys.argv[2]), "dashboard", 1600)

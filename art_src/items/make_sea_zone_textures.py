"""Makes the two stand-in flipbooks of the sea zones (Enrico will redraw them), 4 x 4 frames of 64 x 64 each, tiling:
  Assets/Landscape/sea_zones/boiling.png         the boiling water: bubbles welling up, swelling into rings and
                                                 popping, on a slightly darker grey than the sea;
  Assets/Landscape/sea_zones/strong_current.png  the strong current: dashed streaks and chevrons ("^") pointing UP,
                                                 sliding up one 16th of the tile a frame (so the loop is seamless).
                                                 UP is the way the current flows: the sea shader turns it.
Greys only (the dither makes them paper and ink). Run:  python art_src/items/make_sea_zone_textures.py  (needs numpy, Pillow)."""
import numpy as np
from PIL import Image, ImageDraw

FRAME = 64
FRAMES = 16
rng = np.random.default_rng(11)


def sheet(frames):
    out = Image.new("L", (FRAME * 4, FRAME * 4))
    for i, frame in enumerate(frames):
        out.paste(frame, ((i % 4) * FRAME, (i // 4) * FRAME))
    return out


def wrapped_ellipse(draw, cx, cy, r, **style):
    """A circle drawn nine times (shifted by a tile each way), so one crossing the edge comes back on the other side."""
    for dx in (-FRAME, 0, FRAME):
        for dy in (-FRAME, 0, FRAME):
            draw.ellipse([cx + dx - r, cy + dy - r, cx + dx + r, cy + dy + r], **style)


# ---- boiling: 14 bubbles, each with its own place and its own moment in the 16-frame loop ----
bubbles = [(rng.uniform(0, FRAME), rng.uniform(0, FRAME), rng.uniform(2.5, 6.0), rng.integers(0, FRAMES))
           for _ in range(14)]
frames = []
for f in range(FRAMES):
    img = Image.new("L", (FRAME, FRAME), 170)            # a little darker than the sea's grey
    draw = ImageDraw.Draw(img)
    for (x, y, size, start) in bubbles:
        age = (f - start) % FRAMES                       # 0..15: how far along this bubble's life is
        if age < 9:                                      # welling up and swelling: a dark dome with a light glint
            r = 1.0 + size * age / 9.0
            wrapped_ellipse(draw, x, y, r, fill=90, outline=40)
            wrapped_ellipse(draw, x - r * 0.3, y - r * 0.3, max(0.8, r * 0.3), fill=235)
        elif age < 12:                                   # popped: a light ring spreading out
            r = size + (age - 8) * 2.0
            wrapped_ellipse(draw, x, y, r, outline=245, width=1)
    frames.append(img)
sheet(frames).save("Assets/Landscape/sea_zones/boiling.png")
print("saved Assets/Landscape/sea_zones/boiling.png")

# ---- strong current: streaks and chevrons sliding up ----
streaks = [(rng.uniform(0, FRAME), rng.uniform(0, FRAME), rng.uniform(6, 14)) for _ in range(10)]
chevrons = [(rng.uniform(0, FRAME), rng.uniform(0, FRAME)) for _ in range(4)]
frames = []
for f in range(FRAMES):
    img = Image.new("L", (FRAME, FRAME), 150)
    draw = ImageDraw.Draw(img)
    shift = f * FRAME / FRAMES                           # one tile in 16 frames: the loop joins up
    for (x, y, length) in streaks:
        top = (y - shift) % FRAME
        for dy in (-FRAME, 0, FRAME):
            draw.line([x, top + dy, x, top + dy + length], fill=235, width=1)
    for (x, y) in chevrons:
        top = (y - shift) % FRAME
        for dy in (-FRAME, 0, FRAME):
            for dx in (-FRAME, 0, FRAME):
                draw.line([x + dx - 4, top + dy + 4, x + dx, top + dy, x + dx + 4, top + dy + 4], fill=40, width=2)
    frames.append(img)
sheet(frames).save("Assets/Landscape/sea_zones/strong_current.png")
print("saved Assets/Landscape/sea_zones/strong_current.png")

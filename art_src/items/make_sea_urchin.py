"""Makes the sea urchin's two stand-in pictures (Enrico will redraw them), seen from straight above, greys on
see-through (the dither makes them paper and ink):
  Assets/Dangers/sea_urchin/sea_urchin.png  128 x 128: a big dark round urchin, its spikes sticking out all round,
                                            a paler ring of foam where it meets the water;
  Assets/Dangers/sea_urchin/spike.png       32 x 64: one spike flying, its point at the TOP (the way it flies), with a
                                            short pale streak behind it.
Run:  python art_src/items/make_sea_urchin.py  (needs numpy, Pillow)."""
import math
import numpy as np
from PIL import Image, ImageDraw

rng = np.random.default_rng(5)

# ---- the urchin ----
size = 128
img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)
c = size / 2
draw.ellipse([c - 46, c - 46, c + 46, c + 46], fill=(235, 235, 235, 255))          # foam ring on the water
for i in range(56):                                                                  # spikes all round
    a = i / 56 * math.tau + rng.uniform(-0.05, 0.05)
    length = rng.uniform(46, 62)
    draw.line([c + math.cos(a) * 24, c + math.sin(a) * 24, c + math.cos(a) * length, c + math.sin(a) * length],
              fill=(30, 30, 30, 255), width=2)
draw.ellipse([c - 30, c - 30, c + 30, c + 30], fill=(45, 45, 45, 255), outline=(15, 15, 15, 255), width=2)  # body
for i in range(18):                                                                  # little bumps on the body
    a = rng.uniform(0, math.tau)
    r = rng.uniform(6, 24)
    x, y = c + math.cos(a) * r, c + math.sin(a) * r
    draw.ellipse([x - 2, y - 2, x + 2, y + 2], fill=(110, 110, 110, 255))
draw.ellipse([c - 10, c - 14, c - 2, c - 6], fill=(200, 200, 200, 255))            # a glint
img.save("Assets/Dangers/sea_urchin/sea_urchin.png")
print("saved Assets/Dangers/sea_urchin/sea_urchin.png")

# ---- one spike, pointing up ----
img = Image.new("RGBA", (32, 64), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)
draw.line([16, 30, 16, 62], fill=(240, 240, 240, 200), width=3)                      # the pale streak behind it
draw.polygon([(16, 2), (21, 36), (16, 32), (11, 36)], fill=(25, 25, 25, 255), outline=(240, 240, 240, 255))
img.save("Assets/Dangers/sea_urchin/spike.png")
print("saved Assets/Dangers/sea_urchin/spike.png")

"""Makes the landscape map template from the coasts Enrico drew on the Supernote.

The coasts come from the HTML prototype (index.html, between the `// DRAWN_LAND >>>` markers): rings of
points in the prototype's world pixels (0..5040), filled even-odd (a ring inside land is sea again).

Writes:
  art_src/map/map_paint_base.png   4096x4096, greys: the map to paint over (sea, shallows, sand, land, coast line)
  art_src/map/map_guide.png        4096x4096, transparent: the A1..I9 grid, the labels and home, to use as a top layer
  art_src/map/map_preview.png      the two together, to look at
  Assets/Landscape/world/map_paint.png      the map the game shows (a copy of the base, until Enrico paints his own)
  Assets/Landscape/world/map_collision.png  1024x1024, white = land, black = sea: where the boat can't go

Run from the Godot project's folder:  python art_src/map/make_map_template.py path/to/Sail---Prototype/index.html
"""
import re, sys, pathlib
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageChops
from scipy import ndimage

WORLD = 5040          # the prototype's world, px a side
SIZE = 4096           # the painting, px a side
MASK = 1024           # the collision mask, px a side
GRID = 9              # A..I x 1..9

src = pathlib.Path(sys.argv[1]).read_text(encoding='utf-8')
block = re.search(r'// DRAWN_LAND >>>\n(.*?)// <<< DRAWN_LAND', src, re.S).group(1)
rings = [[float(v) for v in m.split(',')] for m in re.findall(r'\[([-\d.,\s]+)\]', block)]

def land_mask(size):
    """Fill every ring, even-odd: each ring flips land and sea inside it."""
    k = size / WORLD
    acc = Image.new('1', (size, size), 0)
    for r in rings:
        pts = [(r[i] * k, r[i + 1] * k) for i in range(0, len(r) - 1, 2)]
        if len(pts) < 3:
            continue
        one = Image.new('1', (size, size), 0)
        ImageDraw.Draw(one).polygon(pts, fill=1)
        acc = ImageChops.logical_xor(acc, one)
    return np.array(acc, dtype=bool)

land = land_mask(SIZE)
px_per_m = SIZE / (WORLD / 10)                       # 1 m in the game = 10 px of the prototype
sea_dist = ndimage.distance_transform_edt(~land) / px_per_m   # metres from the nearest land, at sea
land_dist = ndimage.distance_transform_edt(land) / px_per_m   # metres from the nearest sea, on land

g = np.full((SIZE, SIZE), 232, np.uint8)             # open sea: pale
g[(~land) & (sea_dist < 6)] = 210                    # shallows: a little darker
g[land] = 150                                        # land: mid grey
g[land & (land_dist < 2.5)] = 200                    # sand along the shore: light
g[land & (land_dist < 0.5)] = 40                     # the coast line: ink
base = Image.fromarray(g, 'L')

out = pathlib.Path('art_src/map'); out.mkdir(parents=True, exist_ok=True)
base.save(out / 'map_paint_base.png')

# the guide: grid, labels, home
guide = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
d = ImageDraw.Draw(guide)
ink = (27, 26, 23, 255)
step = SIZE / GRID
font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf', 64)
for i in range(GRID + 1):
    p = round(i * step)
    d.line([(p, 0), (p, SIZE)], fill=ink, width=4)
    d.line([(0, p), (SIZE, p)], fill=ink, width=4)
for i in range(GRID):
    for j in range(GRID):
        d.text((i * step + 16, j * step + 10), chr(65 + i) + str(j + 1), fill=ink, font=font)
c = SIZE / 2                                        # home: the middle of the map (E5), where the boat starts
d.ellipse([c - 40, c - 40, c + 40, c + 40], outline=ink, width=10)
d.line([(c - 60, c), (c + 60, c)], fill=ink, width=6)
d.line([(c, c - 60), (c, c + 60)], fill=ink, width=6)
guide.save(out / 'map_guide.png')
Image.alpha_composite(base.convert('RGBA'), guide).convert('RGB').save(out / 'map_preview.png')

world = pathlib.Path('Assets/Landscape/world')
base.save(world / 'map_paint.png')
Image.fromarray(land_mask(MASK).astype(np.uint8) * 255, 'L').save(world / 'map_collision.png')
print('rings', len(rings), '| land share %.0f%%' % (land.mean() * 100), '| land at home:', bool(land[SIZE // 2, SIZE // 2]))

"""Makes Assets/Items/sea_mine/sea_mine.png: the sea mine floating on the water, seen from above (a stand-in for
Enrico to redraw), 64 x 64 pixels: a round ink body with six horns (short paper studs with ink knobs) round it, a
paper glint on top, on a faint ring of foam. Drawn 4 x bigger and shrunk, then cut to ink / paper / clear.
Run:  python art_src/items/make_sea_mine.py  (needs Pillow)."""
import math
from PIL import Image, ImageDraw

INK = (27, 26, 23, 255)
PAPER = (235, 231, 220, 255)
S = 4                     # drawn this many times bigger, then shrunk (smoother curves)
W = 64 * S
C = W / 2                 # the middle
im = Image.new("RGBA", (W, W), (0, 0, 0, 0))
d = ImageDraw.Draw(im)


def circle(x, y, r, **kw):
    d.ellipse([x - r, y - r, x + r, y + r], **kw)


circle(C, C, 29 * S, outline=(235, 231, 220, 140), width=2 * S)          # foam round it
# The six horns: an ink stud with a paper rim, sticking out of the body.
for i in range(6):
    a = math.tau * i / 6 - math.pi / 2
    x, y = C + math.cos(a) * 20 * S, C + math.sin(a) * 20 * S
    d.line([C, C, x, y], fill=INK, width=6 * S)
    circle(x, y, 5 * S, fill=PAPER)
    circle(x, y, 3.5 * S, fill=INK)
circle(C, C, 15 * S, fill=PAPER)                                          # the body's paper edge
circle(C, C, 13 * S, fill=INK)                                            # the body
circle(C - 5 * S, C - 5 * S, 3.5 * S, fill=PAPER)                         # a glint on top
im = im.resize((64, 64), Image.LANCZOS)

# Cut to hard pixels: clear, ink or paper (the game draws it alpha-scissored, nearest).
px = im.load()
for y in range(64):
    for x in range(64):
        r, g, b, a = px[x, y]
        if a < 110:
            px[x, y] = (0, 0, 0, 0)
        elif r + g + b < 380:
            px[x, y] = INK
        else:
            px[x, y] = PAPER
im.save("Assets/Items/sea_mine/sea_mine.png")
print("saved Assets/Items/sea_mine/sea_mine.png")

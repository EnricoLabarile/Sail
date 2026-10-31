"""Makes Assets/Items/key/key.png: the key floating on the water, seen from above (a stand-in for Enrico to redraw),
64 x 64 pixels: a big old key in paper with an ink outline (a round bow with a hole, the shaft, two teeth at the
bit), pointing to the top, on a faint ring of foam. Drawn 4 x bigger and shrunk, then cut to ink / paper / clear.
Run:  python art_src/items/make_key.py  (needs Pillow)."""
from PIL import Image, ImageDraw

INK = (27, 26, 23, 255)
PAPER = (235, 231, 220, 255)
S = 4                     # drawn this many times bigger, then shrunk (smoother curves)
W = 64 * S
im = Image.new("RGBA", (W, W), (0, 0, 0, 0))
d = ImageDraw.Draw(im)


def shapes(fill, grow):
    """The key's parts, `grow` pixels fatter (for the ink outline under the paper)."""
    g = grow
    d.ellipse([20 * S - g, 36 * S - g, 44 * S + g, 60 * S + g], fill=fill)          # the bow (the round handle)
    d.rectangle([29 * S - g, 8 * S - g, 35 * S + g, 40 * S + g], fill=fill)         # the shaft
    d.rectangle([35 * S - g, 8 * S - g, 44 * S + g, 13 * S + g], fill=fill)         # the first tooth
    d.rectangle([35 * S - g, 17 * S - g, 41 * S + g, 21 * S + g], fill=fill)        # the second tooth


d.ellipse([4 * S, 4 * S, 60 * S, 60 * S], outline=(235, 231, 220, 140), width=2 * S)   # foam round it
shapes(INK, 2 * S)                                                                   # the ink outline
shapes(PAPER, 0)                                                                     # the paper key
d.ellipse([27 * S, 43 * S, 37 * S, 53 * S], fill=(0, 0, 0, 0), outline=INK, width=2 * S)   # the hole in the bow
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
im.save("Assets/Items/key/key.png")
print("saved Assets/Items/key/key.png")

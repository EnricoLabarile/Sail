"""Makes Assets/Items/barrel/barrel.png: a stand-in flipbook (4 x 4 frames of 64 x 64) of a big wooden barrel
lying on its side in the water, seen from above, rocking a little and bobbing, with a ring of foam round it.
Frame order: left to right, top to bottom; it loops. Enrico redraws it.
Run:  python art_src/items/make_barrel.py  (needs Pillow)."""
import math
from PIL import Image, ImageDraw

FRAME = 64
COLS = ROWS = 4
SCALE = 4                       # drawn 4x bigger, then shrunk: smoother edges before the dither
INK = (27, 26, 23, 255)
WOOD = (225, 205, 170, 255)     # light, so it stands out from the sea once dithered
WOOD_DARK = (120, 95, 70, 255)
WOOD_LIGHT = (250, 245, 235, 255)
FOAM = (240, 238, 230, 255)

sheet = Image.new("RGBA", (FRAME * COLS, FRAME * ROWS), (0, 0, 0, 0))
for f in range(COLS * ROWS):
    t = f / (COLS * ROWS) * 2 * math.pi
    S = FRAME * SCALE
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = S / 2
    # the foam ring on the water, swelling and shrinking with the bob
    ring = S * (0.40 + 0.03 * math.sin(t))
    d.ellipse([c - ring, c - ring * 0.8, c + ring, c + ring * 0.8], outline=FOAM, width=int(S * 0.025))
    # the barrel: lying across, a bulging body, two ends, three hoops
    body = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    b = ImageDraw.Draw(body)
    half_l, half_w = S * 0.30, S * 0.20
    # the bulge: the outline is wider in the middle
    pts = []
    for i in range(41):
        x = -half_l + 2 * half_l * i / 40
        w = half_w * (0.82 + 0.18 * math.cos(x / half_l * math.pi / 2))
        pts.append((c + x, c - w))
    for i in range(41):
        x = half_l - 2 * half_l * i / 40
        w = half_w * (0.82 + 0.18 * math.cos(x / half_l * math.pi / 2))
        pts.append((c + x, c + w))
    b.polygon(pts, fill=WOOD)
    b.line(pts + [pts[0]], fill=INK, width=int(S * 0.03))   # a thick ink outline
    # staves: lines along the barrel
    for k in (-0.55, -0.2, 0.2, 0.55):
        line = []
        for i in range(41):
            x = -half_l + 2 * half_l * i / 40
            w = half_w * (0.82 + 0.18 * math.cos(x / half_l * math.pi / 2))
            line.append((c + x, c + w * k))
        b.line(line, fill=WOOD_DARK, width=int(S * 0.012))
    # a light streak on top, as if lit from the north-west
    b.line([(c - half_l * 0.7, c - half_w * 0.45), (c + half_l * 0.5, c - half_w * 0.5)], fill=WOOD_LIGHT, width=int(S * 0.03))
    # hoops: dark bands across
    for hx in (-0.72, 0.0, 0.72):
        x = c + half_l * hx
        w = half_w * (0.82 + 0.18 * math.cos(hx * math.pi / 2)) + 2
        b.line([(x, c - w), (x, c + w)], fill=INK, width=int(S * 0.04))
    # the two ends (lids), seen edge-on as ellipses
    for side in (-1, 1):
        x = c + side * half_l
        b.ellipse([x - S * 0.04, c - half_w * 0.82, x + S * 0.04, c + half_w * 0.82], fill=WOOD_DARK, outline=INK, width=int(S * 0.012))
    # it rocks a few degrees and bobs a pixel or two
    body = body.rotate(6 * math.sin(t), resample=Image.BICUBIC, center=(c, c))
    img.alpha_composite(body, (0, int(S * 0.02 * math.sin(t + 1.0))))
    small = img.resize((FRAME, FRAME), Image.LANCZOS)
    sheet.alpha_composite(small, ((f % COLS) * FRAME, (f // COLS) * FRAME))
sheet.save("Assets/Items/barrel/barrel.png")
print("saved Assets/Items/barrel/barrel.png")

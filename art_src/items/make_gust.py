"""Makes Assets/Landscape/gust/gust.png: the wind gust booster's flipbook (a stand-in for Enrico to redraw).
A 4 x 4 sheet of 128 x 128 frames, looped: three cartoon gusts (thick strokes curling into a spiral at their
end, paper with an ink edge so they read on any sea) whirling round the middle and pulsing, plus a dashed ring
round the edge. Thicker, curlier and rounder than the plain wind lines, so it stands out from them.
Run:  python art_src/items/make_gust.py  (needs Pillow and numpy)."""
import math
from PIL import Image, ImageDraw

FRAME, COLS, ROWS, SS = 128, 4, 4, 4      # SS: drawn 4 times bigger, then shrunk (smooth edges)
INK = (27, 26, 23, 255)
PAPER = (235, 231, 220, 255)
N = COLS * ROWS


def gust_points(t, k):
    """Points of one gust: an arc round the middle that curls inward into a little spiral at its head."""
    pts = []
    start = k * 2 * math.pi / 3 + t * 2 * math.pi / 3     # the three gusts turn a third of a round a loop
    pulse = 1.0 + 0.08 * math.sin(t * 2 * math.pi * 2 + k)
    for i in range(60):
        s = i / 59
        a = start + s * 1.4
        r = (0.36 + 0.06 * math.sin(s * math.pi)) * pulse
        pts.append((a, r))
    # The curl at the head: a tightening spiral.
    a0, r0 = pts[-1]
    for i in range(1, 40):
        s = i / 39
        a = a0 + s * 2 * math.pi * 0.9
        r = r0 - 0.12 * s
        cx = 0.5 + (r0 - 0.06) * math.cos(a0)
        cy = 0.5 + (r0 - 0.06) * math.sin(a0)
        pts.append(("abs", cx + 0.06 * (1 - s * 0.6) * math.cos(a), cy + 0.06 * (1 - s * 0.6) * math.sin(a)))
    out = []
    for p in pts:
        if p[0] == "abs":
            out.append((p[1], p[2]))
        else:
            a, r = p
            out.append((0.5 + r * math.cos(a), 0.5 + r * math.sin(a)))
    return out


sheet = Image.new("RGBA", (FRAME * COLS, FRAME * ROWS), (0, 0, 0, 0))
for f in range(N):
    t = f / N
    big = Image.new("RGBA", (FRAME * SS, FRAME * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    size = FRAME * SS
    for k in range(3):
        pts = [(x * size, y * size) for x, y in gust_points(t, k)]
        d.line(pts, fill=INK, width=int(9 * SS), joint="curve")      # the ink edge
        d.line(pts, fill=PAPER, width=int(5 * SS), joint="curve")    # the paper stroke
    # A dashed ring round the edge, turning the other way.
    for i in range(16):
        a = i * 2 * math.pi / 16 - t * 2 * math.pi / 8
        r = 0.46 * size
        box = [size / 2 - r, size / 2 - r, size / 2 + r, size / 2 + r]
        deg = math.degrees(a)
        d.arc(box, deg, deg + 10, fill=INK, width=int(4 * SS))
        d.arc(box, deg + 1, deg + 9, fill=PAPER, width=int(2 * SS))
    small = big.resize((FRAME, FRAME), Image.LANCZOS)
    sheet.paste(small, ((f % COLS) * FRAME, (f // COLS) * FRAME))
sheet.save("Assets/Landscape/gust/gust.png")
print("saved Assets/Landscape/gust/gust.png")

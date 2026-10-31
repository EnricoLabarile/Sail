"""Makes Assets/NPCs/raft_npc/raft_npc.png: a castaway on a little raft, seen from above (a stand-in for Enrico to
redraw), 96 x 96 pixels: five paper logs side by side with ink outlines and two ink cross-planks, a seated figure in the
middle (round head, shoulders) waving a rag on a stick, a faint ring of foam round it. Drawn 4 x bigger and shrunk,
then cut to ink / paper / clear (the game draws it alpha-scissored, nearest).
Run:  python art_src/items/make_raft_npc.py  (needs Pillow)."""
from PIL import Image, ImageDraw

INK = (27, 26, 23, 255)
PAPER = (235, 231, 220, 255)
S = 4
W = 96 * S
im = Image.new("RGBA", (W, W), (0, 0, 0, 0))
d = ImageDraw.Draw(im)


def box(x0, y0, x1, y1):
    return [x0 * S, y0 * S, x1 * S, y1 * S]


d.ellipse(box(6, 6, 90, 90), outline=(235, 231, 220, 140), width=2 * S)       # foam round it
for i in range(5):                                                              # the logs, top to bottom
    x0 = 22 + i * 10.5
    d.rounded_rectangle(box(x0, 20, x0 + 10, 78), radius=5 * S, fill=PAPER, outline=INK, width=2 * S)
    d.line(box(x0 + 5, 26, x0 + 5, 40), fill=INK, width=S)                     # grain
d.rectangle(box(19, 28, 77, 32), fill=INK)                                       # cross-planks
d.rectangle(box(19, 66, 77, 70), fill=INK)
d.ellipse(box(32, 44, 64, 62), fill=INK)                                         # the castaway's shoulders (dark coat)
d.ellipse(box(40, 36, 56, 52), fill=PAPER, outline=INK, width=2 * S)             # the head (a straw hat, seen from above)
d.line(box(58, 48, 74, 30), fill=INK, width=2 * S)                               # the stick
d.polygon([(74 * S, 30 * S), (86 * S, 26 * S), (82 * S, 36 * S)], fill=PAPER, outline=INK)   # the rag
im = im.resize((96, 96), Image.LANCZOS)

px = im.load()
for y in range(96):
    for x in range(96):
        r, g, b, a = px[x, y]
        if a < 110:
            px[x, y] = (0, 0, 0, 0)
        elif r + g + b < 380:
            px[x, y] = INK
        else:
            px[x, y] = PAPER
im.save("Assets/NPCs/raft_npc/raft_npc.png")
print("saved Assets/NPCs/raft_npc/raft_npc.png")

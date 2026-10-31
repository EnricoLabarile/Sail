"""Makes Assets/Inventory/icons/paddles.png: the paddles' icon (a stand-in for Enrico to redraw), 24 x 28 pixels like
the others: an ink paddle wheel (a rim, a hub and eight boards) over a little crank handle.
Run:  python art_src/items/make_paddles_icon.py  (needs Pillow)."""
import math
from PIL import Image, ImageDraw

INK = (27, 26, 23, 255)
W, H = 24, 28
im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
cx, cy, r = 12, 11, 10
d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=INK, width=2)        # the rim
for i in range(8):                                                       # the boards, out from the hub
    a = math.tau * i / 8
    d.line([cx, cy, cx + math.cos(a) * r, cy + math.sin(a) * r], fill=INK, width=2)
d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=INK)                     # the hub
d.line([12, 22, 12, 26], fill=INK, width=2)                               # the crank's arm…
d.ellipse([15, 24, 19, 27], fill=INK)                                     # …and its knob
d.line([12, 26, 17, 26], fill=INK, width=2)
im.save("Assets/Inventory/icons/paddles.png")
print("saved Assets/Inventory/icons/paddles.png")

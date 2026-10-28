"""Makes Assets/Inventory/icons/aeolus_jar.png: the Aeolus Jar's icon (a stand-in for Enrico to redraw),
24 x 28 pixels like the bomb's: an ink amphora (a round belly, a narrow neck, a cork, two handles) with a paper
swirl of wind on its belly.
Run:  python art_src/items/make_aeolus_jar.py  (needs Pillow)."""
from PIL import Image, ImageDraw

INK = (27, 26, 23, 255)
PAPER = (235, 231, 220, 255)
W, H = 24, 28
im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
d.rectangle([9, 1, 14, 3], fill=INK)                      # the cork
d.rectangle([10, 4, 13, 8], fill=INK)                     # the neck
d.rectangle([8, 7, 15, 8], fill=INK)                      # the lip of the belly
d.ellipse([3, 8, 20, 25], fill=INK)                       # the belly
d.arc([1, 6, 9, 15], 120, 270, fill=INK, width=2)         # the left handle
d.arc([14, 6, 22, 15], 270, 60, fill=INK, width=2)        # the right handle
d.rectangle([8, 24, 15, 26], fill=INK)                    # the foot
# The wind on its belly: a paper spiral and a gust line.
d.arc([7, 12, 16, 21], 200, 520, fill=PAPER, width=1)
d.arc([9, 14, 14, 19], 20, 300, fill=PAPER, width=1)
d.line([5, 22, 11, 22], fill=PAPER)
im.save("Assets/Inventory/icons/aeolus_jar.png")
print("saved Assets/Inventory/icons/aeolus_jar.png")

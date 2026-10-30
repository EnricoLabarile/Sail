"""Makes the harpoon's stand-in pictures (for Enrico to redraw):
  Assets/Inventory/icons/harpoon.png  24 x 28, the icon: an ink harpoon standing on its tail, barbed head at the top,
                                      a ring of rope at the bottom;
  Assets/Items/harpoon/harpoon.png    16 x 32, the flying head seen from above, point at the TOP (the plane is turned
                                      so the top points the way it flies): a paper-edged ink point with two barbs
                                      and a short shaft with the rope's eye.
Run:  python art_src/items/make_harpoon.py  (needs Pillow)."""
from PIL import Image, ImageDraw

INK = (27, 26, 23, 255)
PAPER = (235, 231, 220, 255)

# The icon.
im = Image.new("RGBA", (24, 28), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
d.polygon([(12, 0), (16, 7), (13, 6), (13, 8), (11, 8), (11, 6), (8, 7)], fill=INK)   # the point and barbs
d.rectangle([11, 8, 12, 22], fill=INK)                                              # the shaft
d.ellipse([7, 20, 16, 27], outline=INK, width=2)                                     # a coil of rope
im.save("Assets/Inventory/icons/harpoon.png")

# The head seen from above (a paper edge round the ink, so it reads on the dark sea).
im = Image.new("RGBA", (16, 32), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
head = [(8, 0), (14, 12), (10, 10), (10, 30), (6, 30), (6, 10), (2, 12)]
d.polygon(head, fill=PAPER)
inner = [(8, 2), (12, 10), (9, 9), (9, 28), (7, 28), (7, 9), (4, 10)]
d.polygon(inner, fill=INK)
im.save("Assets/Items/harpoon/harpoon.png")
print("saved the harpoon's pictures")

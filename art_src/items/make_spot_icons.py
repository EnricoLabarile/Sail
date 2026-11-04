"""Makes the two icons a fishing spot's haul shows above the boat (Assets/Boat/item_show.gd), stand-ins for Enrico to
redraw, 24 x 28 pixels like the others:
  Assets/Inventory/icons/coin.png            an ink coin seen from the front: a thick ring, an inner ring, a "c" in the middle
  Assets/Inventory/icons/heart_container.png an ink heart with a paper shine on its upper left
Run:  python art_src/items/make_spot_icons.py  (needs Pillow)."""
from PIL import Image, ImageDraw

INK = (27, 26, 23, 255)
PAPER = (235, 231, 220, 255)

# The coin.
im = Image.new("RGBA", (24, 28), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
d.ellipse([1, 3, 22, 24], fill=INK)                    # the coin
d.ellipse([4, 6, 19, 21], outline=PAPER, width=1)      # the raised rim inside
d.arc([8, 9, 16, 18], 40, 320, fill=PAPER, width=2)    # a "c" for coin
im.save("Assets/Inventory/icons/coin.png")
print("saved Assets/Inventory/icons/coin.png")

# The heart: two round tops and a point at the bottom.
im = Image.new("RGBA", (24, 28), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
d.ellipse([1, 5, 12, 16], fill=INK)                    # the left top
d.ellipse([11, 5, 22, 16], fill=INK)                   # the right top
d.polygon([(1.5, 12), (22.5, 12), (12, 24)], fill=INK) # down to the point
d.ellipse([4, 8, 7, 11], fill=PAPER)                   # the shine
im.save("Assets/Inventory/icons/heart_container.png")
print("saved Assets/Inventory/icons/heart_container.png")

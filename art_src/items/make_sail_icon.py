"""Makes Assets/Inventory/icons/sail.png: the sail's icon (a stand-in for Enrico to redraw), 24 x 28 pixels like the
others: an ink mast with a triangular sail bellied a little, and the boom along its foot.
Run:  python art_src/items/make_sail_icon.py  (needs Pillow)."""
from PIL import Image, ImageDraw

INK = (27, 26, 23, 255)
W, H = 24, 28
im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
d.rectangle([7, 1, 8, 26], fill=INK)                                  # the mast
d.polygon([(9, 2), (20, 21), (9, 21)], fill=INK)                      # the sail
d.polygon([(20, 21), (21, 15), (17, 8)], fill=INK)                    # its belly, bulging out
d.rectangle([7, 22, 21, 23], fill=INK)                                # the boom
im.save("Assets/Inventory/icons/sail.png")
print("saved Assets/Inventory/icons/sail.png")

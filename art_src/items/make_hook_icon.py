"""Makes Assets/Inventory/icons/hook.png: the hook's icon (a stand-in for Enrico to redraw), 24 x 28 pixels like the
others: an ink grappling hook (a ring at the top, a shank, a curved hook at the bottom with its point).
Run:  python art_src/items/make_hook_icon.py  (needs Pillow)."""
from PIL import Image, ImageDraw

INK = (27, 26, 23, 255)
im = Image.new("RGBA", (24, 28), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
d.ellipse([9, 0, 15, 6], outline=INK, width=2)              # the ring
d.rectangle([11, 6, 12, 18], fill=INK)                      # the shank
d.arc([4, 11, 20, 27], 0, 180, fill=INK, width=3)           # the curve of the hook
d.polygon([(18, 18), (21, 13), (21, 20)], fill=INK)         # its point
im.save("Assets/Inventory/icons/hook.png")
print("saved Assets/Inventory/icons/hook.png")

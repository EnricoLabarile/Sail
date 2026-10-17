# LAYERS TO SHEET: puts every layer of the open Krita document into one image, as a grid (a flipbook sheet).
# Run it in Krita: Tools > Scripts > Scripter, open this file (or paste it), press Run (the play button).
#
# - Frame 1 is the BOTTOM layer in the Layers panel, then upwards. Only plain paint layers at the top level
#   count (no groups, no filter layers).
# - The document must be RGB/Alpha, 8-bit (Image > Properties).
# - It saves "<your file name>_sheet.png" next to your .kra file.

from krita import Krita, InfoObject
import math
import os

COLUMNS = 4   # frames across; 0 = work it out (a square-ish grid)

app = Krita.instance()
doc = app.activeDocument()
w = doc.width()
h = doc.height()

# 1. The frames: the paint layers, from the bottom one up.
frames = [node for node in doc.rootNode().childNodes() if node.type() == "paintlayer"]
count = len(frames)
cols = COLUMNS if COLUMNS > 0 else math.ceil(math.sqrt(count))
rows = math.ceil(count / cols)

# 2. A new, empty image as big as the whole grid, with one layer.
sheet = app.createDocument(w * cols, h * rows, "sheet", "RGBA", "U8", "", doc.resolution())
layer = sheet.createNode("frames", "paintlayer")
sheet.rootNode().addChildNode(layer, None)

# 3. Copy each frame's pixels into its cell, left to right, then the next row.
for i, node in enumerate(frames):
    x = (i % cols) * w
    y = (i // cols) * h
    layer.setPixelData(node.pixelData(0, 0, w, h), x, y, w, h)
sheet.refreshProjection()

# 4. Save it as a PNG next to the .kra file.
kra = doc.fileName()
folder = os.path.dirname(kra) if kra else os.path.expanduser("~")
base = os.path.splitext(os.path.basename(kra))[0] if kra else "sea"
path = os.path.join(folder, base + "_sheet.png")
sheet.setBatchmode(True)
sheet.exportImage(path, InfoObject())
sheet.close()
print("Saved " + path + "  (" + str(cols) + " x " + str(rows) + " frames of " + str(w) + " x " + str(h) + ")")

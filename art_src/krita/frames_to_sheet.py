# FRAMES TO SHEET: puts the animation frames of the open Krita document (the Animation Timeline) into one
# image, as a grid (a flipbook sheet for the game's sea).
# Run it in Krita: Tools > Scripts > Scripter, open this file (or paste it), press Run (the play button).
#
# - It takes FRAMES frames starting at the first frame of the timeline's range (frame 0 normally), and for
#   each one the whole picture as you see it (all visible layers, masks and fills together).
# - The document must be RGB/Alpha, 8-bit (Image > Properties).
# - When it's done it asks where to save the PNG and under what name (it suggests "<your file name>_sheet.png"
#   next to your .kra file). Cancel and nothing is saved.

from krita import Krita, InfoObject
from PyQt5.QtWidgets import QApplication, QFileDialog
import os

FRAMES = 16    # how many frames to put in the sheet
COLUMNS = 4    # frames across (4 x 4 for 16 frames)

app = Krita.instance()
doc = app.activeDocument()
w = doc.width()
h = doc.height()
rows = (FRAMES + COLUMNS - 1) // COLUMNS
first = doc.fullClipRangeStartTime()
start_time = doc.currentTime()

# 1. A new, empty image as big as the whole grid, with one layer.
sheet = app.createDocument(w * COLUMNS, h * rows, "sheet", "RGBA", "U8", "", doc.resolution())
layer = sheet.createNode("frames", "paintlayer")
sheet.rootNode().addChildNode(layer, None)

# 2. For each frame: go to it on the timeline, let Krita redraw it, copy the picture into its cell
#    (left to right, then the next row).
for i in range(FRAMES):
    doc.setCurrentTime(first + i)
    doc.refreshProjection()
    doc.waitForDone()
    QApplication.processEvents()
    x = (i % COLUMNS) * w
    y = (i // COLUMNS) * h
    layer.setPixelData(doc.pixelData(0, 0, w, h), x, y, w, h)
doc.setCurrentTime(start_time)        # back to the frame you were on
sheet.refreshProjection()

# 3. Ask where to save it and under what name (a normal "Save as" window), suggesting next to the .kra file.
kra = doc.fileName()
folder = os.path.dirname(kra) if kra else os.path.expanduser("~")
base = os.path.splitext(os.path.basename(kra))[0] if kra else "sea"
suggested = os.path.join(folder, base + "_sheet.png")
path, _ = QFileDialog.getSaveFileName(None, "Save the sheet as", suggested, "PNG image (*.png)")

# 4. Save it there (if a name was picked: Cancel gives an empty name, and nothing is saved).
if path:
    if not path.lower().endswith(".png"):
        path += ".png"
    sheet.setBatchmode(True)
    sheet.exportImage(path, InfoObject())
    print("Saved " + path + "  (" + str(COLUMNS) + " x " + str(rows) + " frames of " + str(w) + " x " + str(h) + ")")
else:
    print("Not saved (cancelled)")
sheet.close()

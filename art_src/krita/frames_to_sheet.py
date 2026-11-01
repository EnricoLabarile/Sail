# FRAMES TO SHEET: puts the animation frames of the open Krita document (the Animation Timeline) into one
# image, as a grid (a flipbook sheet for the game's sea).
# Run it in Krita: Tools > Scripts > Scripter, open this file (or paste it), press Run (the play button).
#
# - It takes every frame of the timeline's range (Start to End in the Animation docker), or FRAMES frames if you set
#   FRAMES below, and for each one the whole picture as you see it (all visible layers, masks and fills together).
# - THE GRID (Enrico): it works out the layout from the number of frames, as square as possible: 4 frames -> 2 x 2,
#   9 -> 3 x 3, 16 -> 4 x 4, 25 -> 5 x 5. When there's more than one sensible layout (for example 8 frames: 4 x 2,
#   2 x 4, or 3 x 3 with one empty cell) it shows a little list to pick from, with the squarest one already chosen:
#   press OK to keep it. Set ASK = False to never be asked (it then takes the squarest).
#   In Godot, set the shader's frames_x (columns) and frames_y (rows) to the layout it prints at the end.
# - The document must be RGB/Alpha, 8-bit (Image > Properties).
# - Transparent stays transparent: whatever is see-through in your frames is see-through in the sheet.
#   Only what you see goes in, so keep hidden any layer that mustn't end up there (a background, a fill layer).
# - When it's done it asks where to save the PNG and under what name (it suggests "<your file name>_sheet.png"
#   next to your .kra file). Cancel and nothing is saved.

from krita import Krita, InfoObject
from PyQt5.QtWidgets import QApplication, QFileDialog, QInputDialog
import os

FRAMES = 0     # how many frames to put in the sheet (0 = all the frames of the timeline's range)
ASK = True     # True: let me pick the layout when there's more than one; False: always the squarest


## The layouts that fit `count` frames, as (columns, rows), the squarest first:
##   - the square-ish grid: columns = the square root rounded up, rows = as many as needed (may leave empty cells);
##   - every exact grid (columns x rows = count, no empty cells), e.g. 8 -> 4 x 2 and 2 x 4.
## A square number (4, 9, 16…) gives just one: its square. Single strips (1 x n, n x 1) are left out.
def layouts_for(count):
    columns = 1
    while columns * columns < count:
        columns += 1
    rows = (count + columns - 1) // columns
    found = [(columns, rows)]
    if columns * columns == count:
        return found                     # a square number: its square, nothing to ask
    for c in range(2, count):            # (a single long strip, 1 x n, is left out)
        if count % c == 0 and (c, count // c) not in found:
            found.append((c, count // c))
    # The squarest first (the smallest difference between columns and rows), then fewer empty cells.
    found.sort(key=lambda layout: (abs(layout[0] - layout[1]), layout[0] * layout[1] - count))
    return found


app = Krita.instance()
doc = app.activeDocument()
w = doc.width()
h = doc.height()
first = doc.fullClipRangeStartTime()
start_time = doc.currentTime()

# How many frames: FRAMES if set, else the timeline's whole range (its End is the last frame, counted too).
if FRAMES > 0:
    frame_count = FRAMES
else:
    frame_count = doc.fullClipRangeEndTime() - first + 1

# The layout: the squarest, or the one picked from the list.
choices = layouts_for(frame_count)
COLUMNS, rows = choices[0]
if ASK and len(choices) > 1:
    names = []
    for c, r in choices:
        empty = c * r - frame_count
        name = str(c) + " x " + str(r) + "  (" + str(c) + " across, " + str(r) + " down"
        if empty > 0:
            name += ", " + str(empty) + " empty"
        names.append(name + ")")
    picked, ok = QInputDialog.getItem(None, "Sheet layout", str(frame_count) + " frames: pick the grid", names, 0, False)
    if not ok:
        raise SystemExit("Cancelled: no sheet made")
    COLUMNS, rows = choices[names.index(picked)]
FRAMES = frame_count

# 1. A new image as big as the whole grid, with one layer.
sheet = app.createDocument(w * COLUMNS, h * rows, "sheet", "RGBA", "U8", "", doc.resolution())
#    Krita makes every new document with a solid white background layer already in it: remove it, or the
#    frames would sit on white and the saved sheet would have no transparency at all.
for old_layer in sheet.rootNode().childNodes():
    old_layer.remove()
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
    # The same options as Krita's own PNG export window: keep the transparency (alpha), lossless.
    options = InfoObject()
    options.setProperty("alpha", True)          # "Store alpha channel (transparency)"
    options.setProperty("compression", 1)       # "Compression (Lossless)"
    options.setProperty("forceSRGB", True)      # "Force convert to sRGB"
    sheet.exportImage(path, options)
    print("Saved " + path + "  (" + str(FRAMES) + " frames in " + str(COLUMNS) + " x " + str(rows) + " of " + str(w) + " x " + str(h)
          + "; in Godot: frames_x = " + str(COLUMNS) + ", frames_y = " + str(rows) + ")")
else:
    print("Not saved (cancelled)")
sheet.close()

# OFFSET LAYER FRAMES: slides the drawing of the selected layer by X / Y pixels on EVERY frame of its
# animation, wrapping round the edges (what goes out on the right comes back in on the left, and so on),
# so a tileable texture stays tileable. Krita's own Layer > Offset Layer only does the frame you're on.
# Run it in Krita: Tools > Scripts > Scripter, open this file (or paste it), press Run (the play button).
#
# - Select the layer first (e.g. your duplicate) in the Layers docker.
# - It asks how many pixels to move: X (+ = right, - = left) and Y (+ = down, - = up).
# - It moves every keyframe of that layer inside the timeline's range. If the layer isn't animated, only the
#   picture you see.
# - It may not undo with Ctrl+Z: save first, or work on a duplicate layer. Running it again with the opposite
#   numbers (e.g. -10 instead of 10) puts it back.

from krita import Krita
from PyQt5.QtWidgets import QApplication, QInputDialog


## Slides a picture (raw bytes, row by row, left to right) by dx, dy pixels, wrapping round the edges.
## w, h: the picture's size in pixels; the bytes per pixel are worked out from the data's length, so it
## works with any colour depth.
def wrap_shift(data, w, h, dx, dy):
    data = bytes(data)
    bpp = len(data) // (w * h)          # bytes per pixel (4 for RGBA 8-bit)
    row_len = w * bpp
    dx = dx % w                         # moving by a whole width is no move: keep it inside 0..w-1
    dy = dy % h
    cut = (w - dx) * bpp                # where to cut each row: its last dx pixels go to the front
    rows = []
    for y in range(h):
        # Row y of the new picture is the old row (y - dy), wrapped round from the bottom.
        old_y = (y - dy) % h
        row = data[old_y * row_len:(old_y + 1) * row_len]
        rows.append(row[cut:] + row[:cut])
    return b"".join(rows)


app = Krita.instance()
doc = app.activeDocument()
node = doc.activeNode()
w = doc.width()
h = doc.height()

# 1. How far to move.
dx, ok_x = QInputDialog.getInt(None, "Offset all frames", "Pixels to move right (minus = left):", 0, -w, w)
dy, ok_y = QInputDialog.getInt(None, "Offset all frames", "Pixels to move down (minus = up):", 0, -h, h)

if not (ok_x and ok_y):
    print("Cancelled")
elif node is None:
    print("No layer selected")
else:
    # 2. Which frames: every keyframe of this layer in the timeline's range (or just the one picture).
    start_time = doc.currentTime()
    if node.animated():
        frames = []
        for t in range(doc.fullClipRangeStartTime(), doc.fullClipRangeEndTime() + 1):
            if node.hasKeyframeAtTime(t):
                frames.append(t)
    else:
        frames = [start_time]

    # 3. For each one: read its pixels, slide them, go to that frame and write them back.
    for t in frames:
        pixels = node.pixelDataAtTime(0, 0, w, h, t)
        moved = wrap_shift(pixels, w, h, dx, dy)
        doc.setCurrentTime(t)
        doc.waitForDone()
        QApplication.processEvents()
        node.setPixelData(moved, 0, 0, w, h)

    # 4. Back to the frame you were on, and redraw.
    doc.setCurrentTime(start_time)
    doc.refreshProjection()
    print("Moved " + str(len(frames)) + " frame(s) of '" + node.name() + "' by " + str(dx) + ", " + str(dy) + " px")

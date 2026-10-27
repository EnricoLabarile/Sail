@tool
extends Control
## The wind indicator, top right (Enrico: keep it simple): one arrow pointing the way the wind BLOWS.
## The camera always looks north (up on the screen = north), so the arrow is turned like the wind on the map:
## the wind blowing east points right, blowing south points down.
## The arrow is ink with a paper edge round it, so it reads on the dark sea and on the light one.
## It's redrawn only when the wind turns (by half a degree or more).
## (Like a UMG widget that reads a value on tick and rotates an image.)
## @tool: the script also runs in the editor, so it's drawn there too and you can place and size it yourself.
## In the editor it only draws: the wind blowing south (from the north).
## HIDDEN FOR NOW (Enrico): wind_vane.tscn's CanvasLayer has Visible off and is in no Hud group, so nothing shows
## it. To bring it back: tick Visible on WindVane in wind_vane.tscn and put it back in the groups
## "hidden_at_start" and "hidden_while_talking" (Node dock → Groups).

const PAPER := Color("ebe7dc")
const INK := Color("1b1a17")

@export var edge_width := 2.0    # pixels of paper round the ink arrow

var blows_to := 180.0            # compass angle the wind blows toward: 0 = north (up), 90 = east (right)


func _process(_dt: float) -> void:
	if Engine.is_editor_hint():
		return                       # in the editor: only the drawing
	if not is_visible_in_tree():
		return                       # hidden (Enrico, for now): nothing to keep up to date
	# Wind.from_deg is where the wind comes FROM; it blows the opposite way, 180° round.
	var angle := wrapf(Wind.from_deg + 180.0, 0.0, 360.0)
	if absf(wrapf(angle - blows_to, -180.0, 180.0)) > 0.5:
		blows_to = angle
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var half := minf(size.x, size.y) * 0.5 - edge_width - 2.0   # half the arrow's length, inside the box
	# The arrow's shape pointing UP, in its own units (tip at the top, tail at the bottom)…
	var tip := Vector2(0.0, -half)
	var head_back := -half * 0.15                  # where the head's two barbs are (y)
	var head_wide := half * 0.55                   # how far out each barb goes
	var shaft := half * 0.18                       # half the shaft's width
	var points := PackedVector2Array([
		tip,
		Vector2(head_wide, head_back),
		Vector2(shaft, head_back),
		Vector2(shaft, half),
		Vector2(-shaft, half),
		Vector2(-shaft, head_back),
		Vector2(-head_wide, head_back),
	])
	# …then turned to where the wind blows (clockwise from the top, like a compass) and moved to the middle.
	var turn := deg_to_rad(blows_to)
	for i in points.size():
		points[i] = c + points[i].rotated(turn)
	# The paper edge (the outline drawn thick), then the ink arrow on top.
	var outline := points.duplicate()
	outline.append(points[0])                       # close the outline
	draw_polyline(outline, PAPER, edge_width * 2.0, true)
	draw_colored_polygon(points, INK)

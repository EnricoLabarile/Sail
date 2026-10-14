extends Control
## THE LOGBOOK BUTTON (bottom left): a small leather book. Tapped, it says so with the signal `pressed`
## (logbook.gd listens and opens or shuts the book).
##
## It is drawn with code, in greys, like the HTML prototype's icon: it sits on a CanvasLayer UNDER the
## dither (layer 95, the dither is 100), so the dither turns the greys into paper-and-ink dots.
##
## open_amount goes from 0 (shut: the cover) to 1 (open: two pages). logbook.gd changes it smoothly
## with a Tween; while it changes, the cover swings away on its spine and the open pages fade in.

signal pressed

## How open the icon looks, 0..1. The "set(value)" part runs every time someone changes it:
## it stores the value and asks Godot to draw the icon again (queue_redraw).
var open_amount := 0.0:
	set(value):
		open_amount = value
		queue_redraw()


## A tap on the icon: tell logbook.gd.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		pressed.emit()
		accept_event()                     # the tap stops here (it doesn't reach what's underneath)


func _draw() -> void:
	# The drawing is made in a 56 x 56 grid (as in the prototype) and scaled up to the button's size.
	var k := size.x / 56.0

	# 1. The shut book (the cover). It turns on its spine (x = 12, near its left edge) like a door:
	#    its width shrinks with cos(angle), and past 90 degrees it flips over. It fades out halfway.
	var angle := open_amount * deg_to_rad(160.0)
	var cover_alpha := clampf(1.0 - (open_amount - 0.4) * 2.5, 0.0, 1.0)
	if cover_alpha > 0.0:
		draw_set_transform(Vector2(12.0 * k, 0.0), 0.0, Vector2(k * cos(angle), k))
		_draw_cover(cover_alpha, -12.0)
	# 2. The open book: fades in and grows from 85% to full size, round its middle (28, 28).
	var pages_alpha := clampf((open_amount - 0.3) * 1.6, 0.0, 1.0)
	if pages_alpha > 0.0:
		var s := k * (0.85 + 0.15 * pages_alpha)
		draw_set_transform(Vector2(28.0 * k, 28.0 * k) - Vector2(28.0, 28.0) * s, 0.0, Vector2(s, s))
		_draw_pages(pages_alpha, 0.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)    # back to normal for anything drawn next


# ---- little helpers ----

## A grey (0 = black, 255 = white) with some transparency.
func grey(v: float, alpha: float) -> Color:
	return Color(v / 255.0, v / 255.0, v / 255.0, alpha)


## A rectangle moved sideways by dx (dx shifts the drawing so the spine sits on the turning point).
func box(x: float, y: float, w: float, h: float, dx: float) -> Rect2:
	return Rect2(x + dx, y, w, h)


## The outline of a rectangle (filled = false draws only its edges).
func outline(r: Rect2, color: Color, width: float) -> void:
	draw_rect(r, color, false, width)


## Points along a curve from a to b, pulled toward the control point c (a quadratic Bezier curve).
func curve(a: Vector2, c: Vector2, b: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 9:
		var t := i / 8.0
		points.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
	return points


# ---- the two drawings ----

## The shut book: page block, dark leather cover, spine, metal corners, strap and clasp.
func _draw_cover(a: float, dx: float) -> void:
	draw_rect(box(13, 10, 33, 40, dx), grey(90, a))                 # shadow
	draw_rect(box(14, 8, 30, 39, dx), grey(255, a))                 # the pages' edges
	outline(box(14, 8, 30, 39, dx), grey(0, a), 1.4)
	var y := 11.0
	while y < 45.0:                                                 # thin lines of the pages
		draw_line(Vector2(40 + dx, y), Vector2(43.2 + dx, y), grey(150, a), 0.8)
		y += 2.2
	# the cover: dark leather, a little lighter at the top left (each corner gets its own grey)
	var c := box(9, 5, 31, 40, dx)
	draw_polygon(PackedVector2Array([c.position, Vector2(c.end.x, c.position.y), c.end, Vector2(c.position.x, c.end.y)]),
		PackedColorArray([grey(78, a), grey(55, a), grey(30, a), grey(55, a)]))
	draw_rect(box(9, 5, 7, 40, dx), grey(0, a))                     # the spine
	for band_y in [11, 19, 31, 39]:                                 # raised bands on the spine
		draw_line(Vector2(9.5 + dx, band_y), Vector2(15.5 + dx, band_y), grey(200, a), 1.2)
	for corner_y in [5.0, 45.0]:                                    # metal corners on the right
		var sy := 1.0 if corner_y < 10.0 else -1.0
		var tip := Vector2(40 + dx, corner_y)
		var tri := PackedVector2Array([tip, tip + Vector2(-9, 0), tip + Vector2(0, 9 * sy)])
		draw_colored_polygon(tri, grey(235, a))
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), grey(0, a), 1.1)
	draw_rect(box(34, 21, 12, 6, dx), grey(225, a))                 # the strap
	outline(box(34, 21, 12, 6, dx), grey(0, a), 1.1)
	draw_rect(box(41, 20, 5, 8, dx), grey(255, a))                  # the clasp
	outline(box(41, 20, 5, 8, dx), grey(0, a), 1.1)
	draw_circle(Vector2(43.5 + dx, 24), 0.9, grey(0, a))
	outline(c, grey(0, a), 1.6)                                     # the cover's edge


## The open book: the cover underneath, two curved pages with lines of writing, the crease.
func _draw_pages(a: float, dx: float) -> void:
	draw_rect(box(5, 14, 48, 32, dx), grey(90, a))                  # shadow
	draw_rect(box(3, 12, 50, 31, dx), grey(60, a))                  # the cover underneath
	outline(box(3, 12, 50, 31, dx), grey(0, a), 1.4)
	for side in [-1.0, 1.0]:                                        # left page, then right page
		var top := curve(Vector2(28, 15), Vector2(28 + side * 11, 10), Vector2(28 + side * 22, 13))
		var bottom := curve(Vector2(28 + side * 22, 39), Vector2(28 + side * 11, 36), Vector2(28, 41))
		var page := PackedVector2Array()
		page.append_array(top)
		page.append_array(bottom)
		draw_colored_polygon(page, grey(255, a))
		page.append(page[0])
		draw_polyline(page, grey(0, a), 1.2)
		for i in 5:                                                 # lines of writing
			var ly := 18.0 + i * 4.0
			var end_x := 14.0 if i == 4 else 19.0
			draw_line(Vector2(28 + side * 5, ly + 0.6), Vector2(28 + side * end_x, ly), grey(110, a), 0.9)
	draw_line(Vector2(28, 15), Vector2(28, 41), grey(0, a), 1.4)    # the crease

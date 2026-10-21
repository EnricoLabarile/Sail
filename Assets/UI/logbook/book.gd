@tool
extends Control
## THE OPEN LOGBOOK: the leather book with its two pages and, across them, the map.
## (For now only pages 1–2, the map, as Enrico asked.)
##
## Everything is drawn with code in _draw(), like the HTML prototype's book:
##   - the leather cover: dark, with a fine dotted grain, stitching round the edge and metal corners;
##   - two paper pages with the edges of the pages beneath showing at the sides;
##   - the map: the world cut into 9 x 9 squares (A..I from the west, 1..9 from the north, home in E5),
##     drawn as one square across both pages, with the square she's in shaded (read when the book opens:
##     the book isn't redrawn every frame).
##
## `unfold` (0..1) is changed by logbook.gd with a Tween:
##   0 = shut: only the right half shows, the front cover lying over the right page (leather up);
##   1 = open flat: the front cover has swung over on the spine and its inside is the left page.
## @tool: the script also runs in the editor, so it's drawn there too and you can place and size it yourself
## (like a Blueprint's construction script). In the editor it only draws: it doesn't react or read the game.

const PAPER := Color("ebe7dc")
const INK := Color("1b1a17")

# The book's measurements, in pixels (as in the prototype's CSS)
const PAD_SIDE := 12.0        # leather left and right of the pages
const PAD_TOP := 12.0         # leather above the pages
const PAD_BOTTOM := 15.0      # leather below the pages
const CREASE := 4.0           # the gap between the two pages (the gutter)
const PAGE_PAD := 10.0        # paper margin inside a page (none on the crease side, so the map meets in the middle)

# The map's own measurements, in "map units": the whole map is 100 x 100 units (as the prototype's SVG)
const ROOMS := 9              # 9 x 9 squares
const LABEL_MARGIN := 6.0     # room for the letters on top and the numbers on the left
const GRID_START := 8.0       # where the first square starts
const ROOM_SIZE := 10.0       # one square

## How open the book is, 0..1. Every change redraws it (see book_icon.gd for how "set(value)" works).
var unfold := 0.0:
	set(value):
		unfold = value
		queue_redraw()

var _grain: ImageTexture        # a small tile of the leather's dots, repeated over the cover
var _boat_square := Vector2i(-1, -1)   # the square she's in (column 0..8 = A..I, row 0..8 = 1..9), read on opening
var _fps_label: Label           # the frame-rate counter, a Label of its own (see _make_fps_label)


func _ready() -> void:
	_grain = _make_grain_tile()
	if Engine.is_editor_hint():
		unfold = 1.0                 # in the editor: drawn open, to see it (no counter)
		return
	_fps_label = _make_fps_label()


## Every frame, while the book is open: the frame-rate counter. Only the Label changes, so only it is
## redrawn, not the whole book (grid, leather, stitching). Shut or hidden, it's hidden and nothing is done.
func _process(_dt: float) -> void:
	if Engine.is_editor_hint():
		return
	var open := visible and unfold > 0.99
	_fps_label.visible = open
	if not open:
		return
	# First line: the game view's size (the dithered picture, in game pixels) and how many real pixels a
	# game pixel is (game_view.gd), e.g. "360x655 x3". Second line: frames a second, milliseconds a frame,
	# and the draw calls (the jobs sent to the graphics chip this frame: fewer is lighter).
	# Third line: where the time goes, in milliseconds: the scripts (_process), the physics (_physics_process),
	# and drawing the game view on the processor (cpu) and on the graphics chip (gpu; 0 if the browser won't say).
	var top := ""
	var render_cpu := 0.0
	var render_gpu := 0.0
	var game_view := get_tree().get_first_node_in_group("game_view")
	if game_view and game_view.view:
		top = str(game_view.view.size.x) + "x" + str(game_view.view.size.y) + "  x" + str(game_view.dot_scale)
		var rid: RID = game_view.view.get_viewport_rid()
		render_cpu = RenderingServer.viewport_get_measured_render_time_cpu(rid)
		render_gpu = RenderingServer.viewport_get_measured_render_time_gpu(rid)
	var fps := Engine.get_frames_per_second()
	var ms := 1000.0 / maxf(fps, 1.0)
	var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var script_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_fps_label.text = top + "\n" + str(int(fps)) + " fps  " + str(snappedf(ms, 0.1)) + " ms  " + str(draw_calls) + " dc" \
		+ "\nscript " + str(snappedf(script_ms, 0.1)) + "  phys " + str(snappedf(physics_ms, 0.1)) \
		+ "  cpu " + str(snappedf(render_cpu, 0.1)) + "  gpu " + str(snappedf(render_gpu, 0.1))
	# In the bottom right corner of the right page, 4 px in (the same page as _draw works out).
	var page_w := size.x * 0.5 - CREASE * 0.5 - PAD_SIDE
	var page_bottom_right := Vector2(size.x - PAD_SIDE, size.y - PAD_BOTTOM)
	_fps_label.size = Vector2(minf(180.0, page_w), 38.0)
	_fps_label.position = page_bottom_right - _fps_label.size - Vector2(4.0, 2.0)


## Called by logbook.gd when the book is opened: reads what the pages show, once. The book isn't
## redrawn every frame any more (Enrico: nobody keeps it open long enough to need it); it's drawn
## again only while its cover turns (see `unfold` above) or when this is called.
func refresh() -> void:
	# The square she's in: her place in the world as a share of the map (home, world 0, 0, is the middle),
	# times the 9 squares, cut to a whole number.
	var boat := get_tree().get_first_node_in_group("player_boat") as Node3D
	if boat:
		var col := int(floor((boat.global_position.x / Land.WORLD_SIZE + 0.5) * ROOMS))
		var row := int(floor((boat.global_position.z / Land.WORLD_SIZE + 0.5) * ROOMS))
		_boat_square = Vector2i(clampi(col, 0, ROOMS - 1), clampi(row, 0, ROOMS - 1))
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var spine := w * 0.5                                  # the middle of the book
	var page_w := spine - CREASE * 0.5 - PAD_SIDE         # one page's width
	var page_h := h - PAD_TOP - PAD_BOTTOM                # the pages' height

	# How far the front cover has turned. reach goes from -1 (shut, lying over the right page)
	# through 0 (standing up, seen edge on) to 1 (open flat, as the left page).
	var reach := cos(PI * (1.0 - unfold))

	# 1. The leather behind everything: the right half always; the left half appears as the cover opens.
	var left_edge := spine - spine * maxf(reach, 0.0)
	var leather := Rect2(left_edge, 0.0, w - left_edge, h)
	_draw_leather(leather)

	# 2. The right page, with page 2's half of the map on it.
	var right_page := Rect2(spine + CREASE * 0.5, PAD_TOP, page_w, page_h)
	_draw_page(right_page, 1.0)
	_draw_map(right_page, 1, 1.0)

	# 3. The front cover, turning on the spine.
	if reach > 0.0:
		# Open (more than halfway): we see its inside, the left page, squeezed while it turns.
		var left_w := page_w * reach
		var left_page := Rect2(spine - CREASE * 0.5 - left_w, PAD_TOP, left_w, page_h)
		_draw_page(left_page, -1.0)
		_draw_map(left_page, 0, reach)
		# the crease: the gap between the pages is paper too, with a faint ink hairline down the middle
		draw_rect(Rect2(spine - CREASE * 0.5, PAD_TOP, CREASE, page_h), PAPER)
		draw_line(Vector2(spine, PAD_TOP), Vector2(spine, PAD_TOP + page_h), Color(INK, 0.25), 1.0)
	else:
		# Not yet halfway: we see its outside, leather, lying over the right page.
		var cover_w := (page_w + PAD_SIDE) * -reach
		_draw_leather(Rect2(spine, 0.0, cover_w, h))

	# 4. Stitching round the leather and the metal corners.
	_draw_stitching(leather)
	_draw_corners(leather)


# ---- the leather ----

## A 15 x 15 pixel tile: dark leather with two grids of pale dots (every 3 and every 5 pixels),
## repeated over the cover by draw_texture_rect(..., tile = true). Made once, in _ready().
func _make_grain_tile() -> ImageTexture:
	var img := Image.create(15, 15, false, Image.FORMAT_RGBA8)
	img.fill(INK)
	for y in 15:
		for x in 15:
			if x % 3 == 0 and y % 3 == 0:
				img.set_pixel(x, y, INK.lerp(PAPER, 0.38))
			elif x % 5 == 1 and y % 5 == 2:
				img.set_pixel(x, y, INK.lerp(PAPER, 0.2))
	return ImageTexture.create_from_image(img)


func _draw_leather(r: Rect2) -> void:
	if r.size.x <= 0.5:
		return
	draw_texture_rect(_grain, r, true)
	draw_rect(r, INK, false, 2.0)                         # a dark edge


func _draw_stitching(r: Rect2) -> void:
	var s := r.grow(-4.0)                                 # 4 px inside the edge
	if s.size.x <= 0.0:
		return
	var thread := Color(PAPER, 0.55)
	var tl := s.position
	var tr := Vector2(s.end.x, s.position.y)
	var br := s.end
	var bl := Vector2(s.position.x, s.end.y)
	for side in [[tl, tr], [tr, br], [br, bl], [bl, tl]]:
		draw_dashed_line(side[0], side[1], thread, 1.5, 4.0)


## Four metal corners: a light triangle with a rounded outer edge, an ink outline and a rivet.
func _draw_corners(r: Rect2) -> void:
	var corners := [
		[r.position + Vector2(-3, -3), Vector2(1, 1)],                      # top left
		[Vector2(r.end.x + 3, r.position.y - 3), Vector2(-1, 1)],           # top right (mirrored)
		[Vector2(r.position.x - 3, r.end.y + 3), Vector2(1, -1)],           # bottom left
		[r.end + Vector2(3, 3), Vector2(-1, -1)],                           # bottom right
	]
	for c in corners:
		var o: Vector2 = c[0]
		var flip: Vector2 = c[1]
		# the shape, in a 26 x 26 box from the very corner: round edge, then straight back to the corner
		var shape := PackedVector2Array()
		for i in 7:
			var t := i / 6.0
			var a := Vector2(1, 13).lerp(Vector2(1, 1), t)          # a curve from (1, 13) to (13, 1)
			var b := Vector2(1, 1).lerp(Vector2(13, 1), t)
			shape.append(o + a.lerp(b, t) * flip)
		shape.append(o + Vector2(25, 1) * flip)
		shape.append(o + Vector2(1, 25) * flip)
		draw_colored_polygon(shape, PAPER.lerp(INK, 0.15))
		shape.append(shape[0])
		draw_polyline(shape, INK, 2.0)
		draw_circle(o + Vector2(8, 8) * flip, 2.6, INK)                    # the rivet
		draw_circle(o + Vector2(7.3, 7.3) * flip, 0.9, PAPER)


# ---- a page ----

## A paper page; behind it, the edges of two more pages, stepping out to the side (side = -1 left, 1 right).
func _draw_page(r: Rect2, side: float) -> void:
	for step in [[6.0, INK], [5.0, PAPER], [3.0, INK], [2.0, PAPER]]:
		var off := Vector2(side * step[0], step[0])
		draw_rect(Rect2(r.position + off, r.size), step[1])
	draw_rect(r, PAPER)


# ---- the frame-rate counter ----

## A tiny, faint counter for the bottom right corner of the right page (as in the prototype): the screen's
## resolution and the 3D scale over "60 fps" (to compare the phone with the PC). A Label (in Unreal a
## TextBlock), made here in code, a child of the book; _process fills it every frame while the book is open.
func _make_fps_label() -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color(INK, 0.45))
	label.add_theme_constant_override("line_spacing", 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE   # it doesn't catch taps
	label.visible = false
	add_child(label)
	return label


# ---- the map ----

## Draws one half of the map on a page: half 0 (the west half) on the left page, half 1 on the right.
## The map is a square as tall as two pages are wide, cut down the middle by the crease.
## squeeze (0..1) narrows it sideways while the left page is still turning.
func _draw_map(page: Rect2, half: int, squeeze: float) -> void:
	# How big the map is: as big as fits (each half fits in a page, below the top margin).
	var full_page_w := size.x * 0.5 - CREASE * 0.5 - PAD_SIDE
	var half_w := minf(full_page_w - PAGE_PAD, (page.size.y - PAGE_PAD) * 0.5)
	var k := half_w * 2.0 / 100.0                             # pixels per map unit
	var top := page.position.y + PAGE_PAD

	# From map units (u across, v down, 0..100) to a point on the screen.
	# The left half ends at the left page's inner edge; the right half starts at the right page's.
	var to_screen := func(u: float, v: float) -> Vector2:
		if half == 0:
			return Vector2(page.end.x - (50.0 - u) * k * squeeze, top + v * k)
		return Vector2(page.position.x + (u - 50.0) * k, top + v * k)
	var lo := 0.0 if half == 0 else 50.0                      # the map units this half shows
	var hi := 50.0 if half == 0 else 100.0

	# The frame and the dotted seams between the squares (each line cut to this half).
	var grid_end := GRID_START + ROOMS * ROOM_SIZE
	for i in ROOMS + 1:
		var p := GRID_START + i * ROOM_SIZE
		var is_edge := i == 0 or i == ROOMS
		# a horizontal line, from u = GRID_START to grid_end, at v = p
		var a := clampf(GRID_START, lo, hi)
		var b := clampf(grid_end, lo, hi)
		if b > a:
			_map_line(to_screen.call(a, p), to_screen.call(b, p), is_edge)
		# a vertical line at u = p, if it lies in this half
		if p >= lo and p <= hi:
			_map_line(to_screen.call(p, GRID_START), to_screen.call(p, grid_end), is_edge)

	# The letters along the top (A..I) and, on the left half, the numbers down the side (1..9).
	var font := get_theme_default_font()
	var font_size := int(round(3.2 * k))
	for i in ROOMS:
		var middle := GRID_START + (i + 0.5) * ROOM_SIZE
		if middle >= lo and middle < hi:
			var pos: Vector2 = to_screen.call(middle, LABEL_MARGIN - 1.4)
			draw_string(font, pos - Vector2(font_size * 0.5, 0), char(65 + i), HORIZONTAL_ALIGNMENT_CENTER, font_size, font_size, Color(INK, 0.8))
		if half == 0:
			var row_pos: Vector2 = to_screen.call(LABEL_MARGIN - 1.2, middle + 1.5)
			draw_string(font, row_pos - Vector2(font_size, 0), str(i + 1), HORIZONTAL_ALIGNMENT_RIGHT, font_size, font_size, Color(INK, 0.8))

	# The square she's in (read when the book opened): shaded in ink, the part of it on this half.
	if _boat_square.x >= 0:
		var u0 := GRID_START + _boat_square.x * ROOM_SIZE
		var v0 := GRID_START + _boat_square.y * ROOM_SIZE
		var a := clampf(u0, lo, hi)                           # the square's left and right edges, cut to this half
		var b := clampf(u0 + ROOM_SIZE, lo, hi)
		if b > a:
			var corner_1: Vector2 = to_screen.call(a, v0)
			var corner_2: Vector2 = to_screen.call(b, v0 + ROOM_SIZE)
			draw_rect(Rect2(corner_1, corner_2 - corner_1), Color(INK, 0.3))


## A line of the map: the frame's edge solid, the seams between squares dotted and paler.
func _map_line(a: Vector2, b: Vector2, solid: bool) -> void:
	if solid:
		draw_line(a, b, INK, 1.5)
	else:
		draw_dashed_line(a, b, Color(INK, 0.55), 1.0, 1.5)

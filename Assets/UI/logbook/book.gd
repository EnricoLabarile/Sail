@tool
extends Control
## THE OPEN LOGBOOK: the leather book with its two pages; on them, the hold (the top half) and the map (the
## bottom half). One spread for now (Enrico): the two pages read as one sheet, with no line down the middle.
##
## Everything is drawn with code in _draw(), like the HTML prototype's book:
##   - the leather cover: dark, with a fine dotted grain, stitching round the edge and metal corners;
##   - two paper pages with the edges of the pages beneath showing at the sides;
##   - the top half: the hold ("Cargo", the Inventory autoload): its slots in a grid of 3 across, each thing
##     aboard drawn in its slot (its picture from Inventory.ICONS; a pile of bombs or traps with its number in
##     the corner), the empty slots dashed and faint. Tapping a bomb's or a trap's slot equips it (or unequips
##     it): the equipped slot has a thick double frame (Inventory.toggle_equip);
##   - the bottom half: the map, the world cut into 9 x 9 squares (A..I from the west, 1..9 from the north,
##     home in E5), with the square she's in shaded.
## What the pages show is read when the book opens (and when the hold changes): it isn't redrawn every frame.
##
## `unfold` (0..1) is changed by logbook.gd with a Tween:
##   0 = shut: only the right half shows, the front cover lying over the right page (leather up);
##   1 = open flat: the front cover has swung over on the spine and its inside is the left page.
## While it turns, the left page is squeezed toward the spine, and so is what's drawn on it (see _draw_half).
## @tool: the script also runs in the editor, so it's drawn there too and you can place and size it yourself
## (like a Blueprint's construction script). In the editor it only draws: it doesn't react or read the game.

const PAPER := Color("ebe7dc")
const INK := Color("1b1a17")

# The book's measurements, in pixels (as in the prototype's CSS)
const PAD_SIDE := 12.0        # leather left and right of the pages
const PAD_TOP := 12.0         # leather above the pages
const PAD_BOTTOM := 15.0      # leather below the pages
const PAGE_PAD := 10.0        # paper margin round what's written on the pages

# The map's own measurements, in "map units": the whole map is 100 x 100 units (as the prototype's SVG)
const ROOMS := 9              # 9 x 9 squares
const LABEL_MARGIN := 6.0     # room for the letters on top and the numbers on the left
const GRID_START := 8.0       # where the first square starts
const ROOM_SIZE := 10.0       # one square
const LABEL_MIN_SIZE := 8     # the letters and numbers are never smaller than this (pixels), to stay readable

# The hold's slots (as the prototype's Cargo: a grid of 3 across)
const SLOT_COLUMNS := 3
const SLOT_MAX := 40.0        # a slot's largest size, in pixels (smaller if the half page is short)
const SLOT_GAP := 6.0         # the space between two slots
const HEADING_HEIGHT := 20.0  # room above the slots for "Cargo" and the count

## How open the book is, 0..1. Every change redraws it (see book_icon.gd for how "set(value)" works).
var unfold := 0.0:
	set(value):
		unfold = value
		queue_redraw()

var _grain: ImageTexture        # a small tile of the leather's dots, repeated over the cover
var _boat_square := Vector2i(-1, -1)   # the square she's in (column 0..8 = A..I, row 0..8 = 1..9), read on opening
var _marked_squares: Array[Vector2i] = []   # the squares with an X: those of the active map markers, read on opening
var _slot_count := 9            # how many slots the hold has (Inventory.SLOTS, read on opening)
var _slots: Array = []          # the hold's slots as Inventory.slots() gives them ({item, count}), read on opening
var _equipped := ""             # what's equipped (Inventory.equipped), read on opening
var _slot_rects: Array[Rect2] = []   # where each slot is drawn on the book (worked out in _draw_hold), for taps

# The part of the spread being drawn right now, from x = _half_from to x = _half_to (see _draw_half):
# the helpers below (_half_line, _half_rect, _half_texture, _half_text) draw only what falls inside it.
var _half_from := 0.0
var _half_to := 0.0


func _ready() -> void:
	_grain = _make_grain_tile()
	if Engine.is_editor_hint():
		unfold = 1.0                 # in the editor: drawn open, to see it
		return
	Inventory.changed.connect(refresh)   # something came aboard or went out: the hold's page changes
	Inventory.equipped_changed.connect(refresh)   # something was equipped or unequipped


## Called by logbook.gd when the book is opened (and by the Inventory when the hold changes): reads what the
## pages show, once. The book isn't redrawn every frame (Enrico: nobody keeps it open long enough to need it);
## it's drawn again only while its cover turns (see `unfold` above) or when this is called.
func refresh() -> void:
	# The square she's in: her place in the world as a share of the map (home, world 0, 0, is the middle),
	# times the 9 squares, cut to a whole number.
	var boat := get_tree().get_first_node_in_group("player_boat") as Node3D
	if boat:
		var col := int(floor((boat.global_position.x / Land.WORLD_SIZE + 0.5) * ROOMS))
		var row := int(floor((boat.global_position.z / Land.WORLD_SIZE + 0.5) * ROOMS))
		_boat_square = Vector2i(clampi(col, 0, ROOMS - 1), clampi(row, 0, ROOMS - 1))
	# The squares marked with an X: every active map marker (Assets/Quests/map_marker) says which square it's in.
	_marked_squares.clear()
	for marker in get_tree().get_nodes_in_group("map_markers"):
		if marker.active and not _marked_squares.has(marker.square()):
			_marked_squares.append(marker.square())
	# The hold: how many slots, and the picture of each thing aboard (in the order it came in).
	_slot_count = Inventory.SLOTS
	_slots = Inventory.slots()
	_equipped = Inventory.equipped
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var spine := w * 0.5                                  # the middle of the book
	var page_w := spine - PAD_SIDE                        # one page's width
	var page_h := h - PAD_TOP - PAD_BOTTOM                # the pages' height

	# How far the front cover has turned. reach goes from -1 (shut, lying over the right page)
	# through 0 (standing up, seen edge on) to 1 (open flat, as the left page).
	var reach := cos(PI * (1.0 - unfold))

	# 1. The leather behind everything: the right half always; the left half appears as the cover opens.
	var left_edge := spine - spine * maxf(reach, 0.0)
	var leather := Rect2(left_edge, 0.0, w - left_edge, h)
	_draw_leather(leather)

	# 2. The paper: the right page, and, once the cover is more than halfway over, its inside, the left page,
	#    squeezed while it turns. The two pages meet at the spine with no gap, so they read as one sheet.
	_draw_page(Rect2(spine, PAD_TOP, page_w, page_h), 1.0)
	if reach > 0.0:
		var left_w := page_w * reach
		_draw_page(Rect2(spine - left_w, PAD_TOP, left_w, page_h), -1.0)

	# 3. What's written on the pages: the right page's part as it is, the left page's part squeezed with it.
	_draw_half(spine, w, 1.0)
	if reach > 0.0:
		_draw_half(0.0, spine, reach)

	# 4. Not yet halfway: the cover's outside, leather, lying over the right page.
	if reach <= 0.0:
		var cover_w := (page_w + PAD_SIDE) * -reach
		_draw_leather(Rect2(spine, 0.0, cover_w, h))

	# 5. Stitching round the leather and the metal corners.
	_draw_stitching(leather)
	_draw_corners(leather)


## Draws the part of the pages' content that lies between x = from and x = to (one page), laid out as if
## the book were open flat. squeeze (0..1) narrows it toward the spine, for the left page while it turns:
## draw_set_transform scales everything drawn after it (like a scale on a UMG widget's render transform).
func _draw_half(from: float, to: float, squeeze: float) -> void:
	_half_from = from
	_half_to = to
	var spine := size.x * 0.5
	if squeeze < 1.0:
		draw_set_transform(Vector2(spine * (1.0 - squeeze), 0.0), 0.0, Vector2(squeeze, 1.0))

	# The writing area of the open spread (both pages, inside the paper margin), cut in two halves:
	# the hold on top, the map below.
	var page_h := size.y - PAD_TOP - PAD_BOTTOM
	var half_h := page_h * 0.5
	var area_x := PAD_SIDE + PAGE_PAD
	var area_w := size.x - 2.0 * area_x
	var hold_area := Rect2(area_x, PAD_TOP + PAGE_PAD, area_w, half_h - PAGE_PAD)
	var map_area := Rect2(area_x, PAD_TOP + half_h, area_w, half_h - PAGE_PAD)
	_draw_hold(hold_area)
	_draw_map(map_area)

	draw_set_transform(Vector2.ZERO)   # back to normal for whatever is drawn next


# ---- taps ----

## A finger on the open book: on a slot holding a bomb or a trap, it's equipped (or unequipped, if it already
## was: Inventory.toggle_equip). Only while the book is fully open. The pages are drawn again by `refresh`,
## which the Inventory's signal calls.
func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or unfold < 1.0:
		return
	if not (event is InputEventScreenTouch and event.pressed):
		return
	for i in _slot_rects.size():
		if i < _slots.size() and _slot_rects[i].has_point(event.position):
			Inventory.toggle_equip(_slots[i]["item"])
			accept_event()
			return


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


# ---- the hold (the top half) ----

## "Cargo" and how many slots are taken ("2/9"), then the slots in a grid of SLOT_COLUMNS across, centred on
## the spine: each thing aboard in a solid frame with its picture, the empty slots dashed and faint
## (as the prototype's Cargo).
func _draw_hold(area: Rect2) -> void:
	var spine := size.x * 0.5
	var rows := ceili(_slot_count / float(SLOT_COLUMNS))
	var room_h := area.size.y - HEADING_HEIGHT           # the height left for the slots under the heading
	var slot := minf(SLOT_MAX, (room_h - SLOT_GAP * (rows - 1)) / rows)
	var grid_w := SLOT_COLUMNS * slot + (SLOT_COLUMNS - 1) * SLOT_GAP
	var grid_h := rows * slot + (rows - 1) * SLOT_GAP
	var left := spine - grid_w * 0.5
	var top := area.position.y + HEADING_HEIGHT + (room_h - grid_h) * 0.5   # the grid in the middle of the room left

	# The heading, just above the grid: the title on the left, the count on the right.
	var used := _slots.size()
	_half_text(Vector2(left, top - 7.0), "Cargo", 13, INK, HORIZONTAL_ALIGNMENT_LEFT)
	_half_text(Vector2(left + grid_w, top - 7.0), str(used) + "/" + str(_slot_count), 10, Color(INK, 0.8), HORIZONTAL_ALIGNMENT_RIGHT)

	# The slots, row by row. Their places are kept in _slot_rects, for the taps (_gui_input).
	_slot_rects.clear()
	for i in _slot_count:
		var col := i % SLOT_COLUMNS
		var row := floori(i / float(SLOT_COLUMNS))
		var r := Rect2(left + col * (slot + SLOT_GAP), top + row * (slot + SLOT_GAP), slot, slot)
		_slot_rects.append(r)
		if i < used:
			var item: String = _slots[i]["item"]
			var amount: int = _slots[i]["count"]
			_half_frame(r, INK, 1.5, false)
			if item == _equipped:
				_half_frame(r.grow(-3.0), INK, 2.0, false)      # equipped: a second, thick frame inside
			var icon: Texture2D = Inventory.ICONS.get(item)
			if icon:
				_draw_icon(icon, r)
			if Inventory.STACKABLE.has(item):
				# the pile's number, small, in the bottom right corner
				_half_text(r.end - Vector2(4.0, 4.0), str(amount), 10, INK, HORIZONTAL_ALIGNMENT_RIGHT)
		else:
			_half_frame(r, Color(INK, 0.45), 1.0, true)


## A thing's picture in the middle of its slot, at its own size (so its pixels stay sharp), or smaller if it
## doesn't fit.
func _draw_icon(icon: Texture2D, slot: Rect2) -> void:
	var icon_size := icon.get_size()
	var fit := minf(1.0, (slot.size.x - 8.0) / maxf(icon_size.x, icon_size.y))
	icon_size *= fit
	var corner := (slot.get_center() - icon_size * 0.5).round()   # on whole pixels, so it isn't blurred
	_half_texture(icon, Rect2(corner, icon_size))


# ---- the map (the bottom half) ----

## The map: a square as big as fits in `area`, its middle on the spine (as before, across both pages).
func _draw_map(area: Rect2) -> void:
	var k := minf(area.size.x, area.size.y) / 100.0           # pixels per map unit
	var map_left := size.x * 0.5 - 50.0 * k                   # the map's middle (50 units) on the spine
	var map_top := area.position.y + (area.size.y - 100.0 * k) * 0.5

	# From map units (u across, v down, 0..100) to a point on the page.
	var to_screen := func(u: float, v: float) -> Vector2:
		return Vector2(map_left + u * k, map_top + v * k)

	# The frame and the dotted seams between the squares.
	var grid_end := GRID_START + ROOMS * ROOM_SIZE
	for i in ROOMS + 1:
		var p := GRID_START + i * ROOM_SIZE
		var is_edge := i == 0 or i == ROOMS
		_map_line(to_screen.call(GRID_START, p), to_screen.call(grid_end, p), is_edge)   # across
		_map_line(to_screen.call(p, GRID_START), to_screen.call(p, grid_end), is_edge)   # down

	# The letters along the top (A..I) and the numbers down the left side (1..9).
	var font_size := maxi(LABEL_MIN_SIZE, int(round(3.2 * k)))
	for i in ROOMS:
		var middle := GRID_START + (i + 0.5) * ROOM_SIZE
		_half_text(to_screen.call(middle, LABEL_MARGIN - 1.4), char(65 + i), font_size, Color(INK, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
		_half_text(to_screen.call(LABEL_MARGIN - 1.2, middle + 1.5), str(i + 1), font_size, Color(INK, 0.8), HORIZONTAL_ALIGNMENT_RIGHT)

	# The square she's in (read when the book opened): shaded in ink.
	if _boat_square.x >= 0:
		var corner: Vector2 = to_screen.call(GRID_START + _boat_square.x * ROOM_SIZE, GRID_START + _boat_square.y * ROOM_SIZE)
		_half_rect(Rect2(corner, Vector2(ROOM_SIZE, ROOM_SIZE) * k), Color(INK, 0.3))

	# An X in the middle of each marked square (the map markers), its arms 0.3 of a square from the middle.
	for marked in _marked_squares:
		var middle: Vector2 = to_screen.call(GRID_START + (marked.x + 0.5) * ROOM_SIZE, GRID_START + (marked.y + 0.5) * ROOM_SIZE)
		var arm := ROOM_SIZE * 0.3 * k
		_half_line(middle + Vector2(-arm, -arm), middle + Vector2(arm, arm), INK, 2.0, false)
		_half_line(middle + Vector2(arm, -arm), middle + Vector2(-arm, arm), INK, 2.0, false)


## A line of the map: the frame's edge solid, the seams between squares dotted and paler.
func _map_line(a: Vector2, b: Vector2, solid: bool) -> void:
	if solid:
		_half_line(a, b, INK, 1.5, false)
	else:
		_half_line(a, b, Color(INK, 0.55), 1.0, true)


# ---- drawing only on the half being drawn (see _draw_half) ----

## A line from a to b, only the part of it between _half_from and _half_to.
func _half_line(a: Vector2, b: Vector2, color: Color, width: float, dashed: bool) -> void:
	if a.x > b.x:
		var swap := a                                     # make a the left end
		a = b
		b = swap
	if a.x == b.x:
		# straight down: all on this half, or none of it
		if a.x < _half_from or a.x >= _half_to:
			return
	else:
		# cut the ends that stick out of this half
		var from_x := maxf(a.x, _half_from)
		var to_x := minf(b.x, _half_to)
		if to_x <= from_x:
			return
		var start := a.lerp(b, (from_x - a.x) / (b.x - a.x))
		var end := a.lerp(b, (to_x - a.x) / (b.x - a.x))
		a = start
		b = end
	if dashed:
		draw_dashed_line(a, b, color, width, 1.5)
	else:
		draw_line(a, b, color, width)


## A rectangle's outline (solid or dashed), only the part of it on this half.
func _half_frame(r: Rect2, color: Color, width: float, dashed: bool) -> void:
	var tl := r.position
	var tr := Vector2(r.end.x, r.position.y)
	var br := r.end
	var bl := Vector2(r.position.x, r.end.y)
	_half_line(tl, tr, color, width, dashed)
	_half_line(bl, br, color, width, dashed)
	_half_line(tl, bl, color, width, dashed)
	_half_line(tr, br, color, width, dashed)


## The part of a rectangle that lies on this half (its width is 0 or less if none does).
func _half_part(r: Rect2) -> Rect2:
	var left := maxf(r.position.x, _half_from)
	var right := minf(r.end.x, _half_to)
	return Rect2(left, r.position.y, right - left, r.size.y)


## A filled rectangle, only the part of it on this half.
func _half_rect(r: Rect2, color: Color) -> void:
	var part := _half_part(r)
	if part.size.x > 0.0:
		draw_rect(part, color)


## A picture stretched over r, only the part of it on this half (and only that part of the picture).
func _half_texture(texture: Texture2D, r: Rect2) -> void:
	var part := _half_part(r)
	if part.size.x <= 0.0:
		return
	var picture := texture.get_size()
	var source := Rect2((part.position.x - r.position.x) / r.size.x * picture.x, 0.0,
		part.size.x / r.size.x * picture.x, picture.y)
	draw_texture_rect_region(texture, part, source)


## A word with its baseline at pos: pos is its left end, its middle or its right end (align). Words can't
## be cut in two, so it's drawn only on the half that holds all of it (the layout keeps every word on one page).
func _half_text(pos: Vector2, text: String, font_size: int, color: Color, align: HorizontalAlignment) -> void:
	var font := get_theme_default_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var left := pos.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		left -= width * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		left -= width
	if left < _half_from or left + width > _half_to:
		return
	draw_string(font, Vector2(left, pos.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

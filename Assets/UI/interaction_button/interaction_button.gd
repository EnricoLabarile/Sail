@tool
extends Control
## THE INTERACTION BUTTON (Enrico, Nov 2026): the round button in the middle of the wheel, where the anchor's hub
## was (the anchor is worked by the throttle lever now). It's the ONE button for everything, and what it does depends on the
## moment (the first that fits, top to bottom):
##   1. someone is talking            -> an arrow: a tap shows the whole page, then the next one (talk_box.tap)
##   2. near an NPC not yet talked to -> a speech bubble with a glint: a tap drops the anchor and starts the talk
##   3. over a fishing spot           -> a question mark: only a hint (fish by dropping anchor with the lever)
##   4. a thing in hand               -> its icon (bomb, jar, harpoon, hook, trap): a tap uses it (its action's use())
##   5. nothing                       -> an empty face, faint
## Every press clicks, and it's black for as long as the finger holds it (Enrico's rule for every button: it shows
## "you're keeping this pressed").
##
## The thing in hand is Inventory.equipped (one at a time, picked in the logbook). What each one does lives in its
## "item action" node (bomb_button.gd, jar_button.gd, harpoon_button.gd, hook_button.gd in ui_layout.tscn): this
## button finds the one whose ITEM is the equipped thing (group "item_actions") and calls it. The trap has no action:
## it's laid when the anchor goes down while it's in hand (trap_setter.gd), so here it's only shown.
## (In Unreal terms: a context-sensitive "Interact" button that asks a few systems in turn who wants the press.)
##
## It sits as a child of the wheel (helm.tscn) and puts itself on the wheel's middle, the size of the old hub,
## every frame (helm.gd hub_middle / hub_radius), so moving or resizing the Helm moves it too.

const INK := Color("1b1a17")
const PAPER := Color("ebe7dc")

@export var icon_fps := 12.0      # frames a second for a flipbook icon (the hook's empty hand)
@export var shimmer_time := 0.5      # by an NPC: the glint takes this long to sweep across…
@export var shimmer_every := 1.6     # …once every this many seconds
@export var equip_anim_time := 0.6   # seconds the rings pulse out when a bomb is put in hand
@export var equip_ring_grow := 22.0  # pixels each ring grows past the edge before it fades away

var finger := -1                     # the finger on it (-1 = none): black while it's down
var shimmer_t := 0.0                 # the glint's clock
var equip_anim_left := 0.0           # seconds left of the equip rings (0 = none)
var paper_icons := {}                # icon -> the same icon in paper (for the inked face while the hook holds)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if Engine.is_editor_hint():
		return
	Inventory.equipped_changed.connect(_on_equipped_changed)


func _boat() -> Node:
	return get_tree().get_first_node_in_group("player_boat")


## The bomb just put in hand: the rings pulse out (its click-clack is played by bomb_button.gd).
func _on_equipped_changed() -> void:
	if Inventory.equipped == "bomb":
		equip_anim_left = equip_anim_time


# ---- what it is now ----

## Which of the five moments it is: "talk_next", "talk_start", "fishing", "item" or "empty".
func mode() -> String:
	if Engine.is_editor_hint():
		return "empty"
	var boat := _boat()
	if boat == null:
		return "empty"
	if boat.talking:
		return "talk_next"
	if boat.npc_to_talk_to() != null:
		return "talk_start"
	if boat.over_fishing_spot():
		return "fishing"
	if Inventory.equipped != "":
		return "item"
	return "empty"


## The action node of the thing in hand (null for the trap, or nothing in hand).
func current_action() -> Node:
	for action in get_tree().get_nodes_in_group("item_actions"):
		if action.ITEM == Inventory.equipped:
			return action
	return null


# ---- every frame: where it sits, its clocks ----

func _process(dt: float) -> void:
	var wheel := get_parent()
	if wheel != null and wheel.has_method("hub_middle"):
		var r: float = wheel.hub_radius()
		size = Vector2(r, r) * 2.0
		position = wheel.hub_middle() - size * 0.5
	if not Engine.is_editor_hint():
		equip_anim_left = maxf(0.0, equip_anim_left - dt)
		shimmer_t += dt
	queue_redraw()


# ---- touching it ----

## Only the round button counts, not the corners of its box.
func _has_point(point: Vector2) -> bool:
	return point.distance_to(size * 0.5) <= size.x * 0.5


func _gui_input(e: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if e is InputEventScreenTouch:
		if e.pressed and finger == -1:
			finger = e.index
			press()
			accept_event()
		elif not e.pressed and e.index == finger:
			finger = -1
			accept_event()


## Enter on the PC does the same as a tap.
func _unhandled_key_input(e: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if e is InputEventKey and e.pressed and not e.echo and (e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER):
		press()


## A press: the click always; then whatever this moment does.
func press() -> void:
	Sfx.button_press()
	var boat := _boat()
	match mode():
		"talk_next":
			var box := get_tree().get_first_node_in_group("talk_box")
			if box:
				box.tap()
		"talk_start":
			# Enrico: talking stops the boat, so the anchor goes down first (with its sound), unless it's
			# already down or she's tied up at a pier. Before the talk opens: while talking the anchor is locked.
			var npc: Node3D = boat.npc_to_talk_to()
			if not boat.anchored:
				boat.toggle_anchor()
			npc.start_talk()
		"item":
			var action := current_action()
			if action != null and action.can_use():
				action.use()
		# "fishing" and "empty": only the click (and black while held).


# ---- drawing it ----

func grey(v: float, alpha: float = 1.0) -> Color:
	return Color(v / 255.0, v / 255.0, v / 255.0, alpha)


func _draw() -> void:
	var middle := size * 0.5
	var s := size.x * 0.5 / 15.0          # the hub is drawn in units where its radius is 15 (as the prototype's)
	var now := mode()
	var action := current_action() if now == "item" else null
	var inked: bool = action != null and action.is_active()     # the hook holding something, a harpoon out

	draw_set_transform(middle, 0.0, Vector2(s, s))
	_draw_face(inked, now == "empty")

	# The glyph: ink on the light face, paper on the inked one.
	var mark := grey(255) if inked else grey(0)
	match now:
		"talk_next":
			_draw_arrow(mark)
		"talk_start":
			_draw_speech_bubble(mark)
		"fishing":
			_draw_question_mark(mark)
		"item":
			# An action can pick its own picture for the moment (the hook: empty or full hand, current_icon);
			# otherwise the thing's own icon.
			var icon := Inventory.icon_of(Inventory.equipped)
			var frames := Vector2i(1, 1)          # a still picture; an action may give a flipbook's grid
			if action != null and action.has_method("current_icon"):
				icon = action.current_icon()
			if action != null and action.has_method("current_icon_frames"):
				frames = action.current_icon_frames()
			_draw_icon(icon, inked, frames)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Resting after a use: the ink pie of what's left of the wait.
	if action != null and action.cooldown_share() > 0.0:
		_draw_pie(middle, size.x * 0.5 * 0.8, action.cooldown_share())
	# By an NPC: now and then a glint sweeps across.
	if now == "talk_start":
		_draw_shimmer(middle, s)
	# A bomb just put in hand: the rings.
	if equip_anim_left > 0.0:
		_draw_equip_rings(middle, size.x * 0.5)
	# Held down: all black, for as long as the finger is on it.
	if finger != -1:
		draw_circle(middle, size.x * 0.5, INK)


## The brass bezel with four rivets and the face inside it: light, or ink while the thing in hand is busy;
## faint when it has nothing to do.
func _draw_face(inked: bool, faint: bool) -> void:
	var ink := grey(0)
	var paper := grey(255)
	var hub_r := 15.0
	var face_r := hub_r - 3.2
	var a := 0.55 if faint else 1.0
	_lit_disc(hub_r, grey(245, a), grey(200, a), grey(140, a))
	draw_arc(Vector2.ZERO, hub_r, 0.0, TAU, 48, Color(ink, a), 1.6)
	for i in 4:
		var angle := PI / 4.0 + i * PI / 2.0
		var r := Vector2(cos(angle), sin(angle)) * (hub_r - 1.6)
		draw_circle(r, 1.05, Color(ink, a))
		draw_rect(Rect2(r.x - 0.6, r.y - 0.6, 0.6, 0.6), Color(paper, a))
	if inked:
		_radial_disc(Vector2(-face_r * 0.15, -face_r * 0.15), face_r, grey(100), grey(28))
	else:
		_radial_disc(Vector2(-face_r * 0.15, -face_r * 0.15), face_r, grey(255, a), grey(182, a))
	draw_arc(Vector2.ZERO, face_r, 0.0, TAU, 40, Color(ink, a), 1.0)
	draw_arc(Vector2.ZERO, face_r - 1.6, PI * 1.08, PI * 1.38, 8, Color(paper, a), 1.1)    # the glint


## The thing in hand's icon in the middle of the face (in paper on the inked face).
## A FLIPBOOK icon (`frames` = its grid, columns x rows, more than 1 x 1): only one cell of the picture is drawn, the
## next every 1 / icon_fps seconds, left to right then the next row, round and round (as the sea's flipbooks).
func _draw_icon(icon: Texture2D, inked: bool, frames := Vector2i(1, 1)) -> void:
	if icon == null:
		return
	var picture := _paper_copy(icon) if inked else icon
	# One cell: its size, and which one it is now (counted from the time, so it plays by itself).
	var cell := icon.get_size() / Vector2(frames)
	var count := frames.x * frames.y
	var frame := int(Time.get_ticks_msec() / 1000.0 * icon_fps) % count
	var cell_rect := Rect2(Vector2(frame % frames.x, frame / frames.x) * cell, cell)
	var height := 16.0                                    # in the hub's units (the face is 23.6 across)
	var icon_size := cell * (height / cell.y)
	draw_texture_rect_region(picture, Rect2(-icon_size * 0.5, icon_size), cell_rect)


## The same picture with every pixel turned to paper (its see-through kept), made once per icon.
func _paper_copy(picture: Texture2D) -> Texture2D:
	if paper_icons.has(picture):
		return paper_icons[picture]
	var image := picture.get_image()
	if image == null:
		return picture
	image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			image.set_pixel(x, y, Color(PAPER, image.get_pixel(x, y).a))
	var copy := ImageTexture.create_from_image(image)
	paper_icons[picture] = copy
	return copy


## A disc lit from the top left (a diagonal gradient), as the wheel's brass.
func _lit_disc(radius: float, light: Color, middle: Color, dark: Color) -> void:
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for i in 40:
		var angle := TAU * i / 40.0
		var p := Vector2(cos(angle), sin(angle)) * radius
		points.append(p)
		var t := clampf(((p.x + p.y) / (radius * 2.0)) + 0.5, 0.0, 1.0)   # 0 top left .. 1 bottom right
		colors.append(light.lerp(middle, t * 2.0) if t < 0.5 else middle.lerp(dark, t * 2.0 - 1.0))
	draw_polygon(points, colors)


## A disc whose grey changes from the middle (inner) to the edge (outer): a fan of triangles.
func _radial_disc(center: Vector2, radius: float, inner: Color, outer: Color) -> void:
	for i in 40:
		var a0 := TAU * i / 40.0
		var a1 := TAU * (i + 1) / 40.0
		var tri := PackedVector2Array([center, center + Vector2(cos(a0), sin(a0)) * radius, center + Vector2(cos(a1), sin(a1)) * radius])
		draw_polygon(tri, PackedColorArray([inner, outer, outer]))


## Points along a curve from a to b, pulled toward c (a quadratic Bezier curve).
func _curve(a: Vector2, c: Vector2, b: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 9:
		var t := i / 8.0
		points.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
	return points


## "Go on" in a talk: an arrow pointing right.
func _draw_arrow(mark: Color) -> void:
	draw_line(Vector2(-6.0, 0.0), Vector2(5.0, 0.0), mark, 2.2)
	draw_polyline(PackedVector2Array([Vector2(0.5, -4.8), Vector2(5.5, 0.0), Vector2(0.5, 4.8)]), mark, 2.2)


## A speech bubble: a rounded box with a little tail at the bottom left and three dots inside.
func _draw_speech_bubble(mark: Color) -> void:
	var box := PackedVector2Array()
	var half := Vector2(7.0, 4.6)        # half its width and height
	var corner := 2.2                    # how round its corners are
	var middle := Vector2(0.0, -1.5)
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for i in 4:
		var centre: Vector2 = middle + Vector2(corners[i].x * (half.x - corner), corners[i].y * (half.y - corner))
		var start := PI + i * PI / 2.0
		for j in 5:
			var a := start + j * PI / 8.0
			box.append(centre + Vector2(cos(a), sin(a)) * corner)
	box.append(box[0])
	draw_polyline(box, mark, 1.6)
	var bottom := middle.y + half.y
	draw_polyline(PackedVector2Array([Vector2(-3.5, bottom), Vector2(-5.0, bottom + 3.6), Vector2(-0.5, bottom)]), mark, 1.6)
	for x in [-3.2, 0.0, 3.2]:
		draw_circle(Vector2(x, middle.y), 1.05, mark)


## A question mark: an arc round its top, a curve down to the middle, and the dot.
func _draw_question_mark(mark: Color) -> void:
	var hook := PackedVector2Array()
	for i in 17:
		var a := lerpf(PI * 1.05, PI * 2.45, i / 16.0)
		hook.append(Vector2(0.0, -3.2) + Vector2(cos(a), sin(a)) * 4.2)
	hook.append_array(_curve(hook[hook.size() - 1], Vector2(0.0, 0.8), Vector2(0.0, 3.0)))
	draw_polyline(hook, mark, 2.4)
	draw_circle(Vector2(0.0, 7.0), 1.5, mark)


## The glint: a slanted band of paper with thin ink edges sweeping across the face, cut to its round shape
## (Geometry2D.intersect_polygons gives the part the band and the circle share, like a mask in a material).
func _draw_shimmer(middle: Vector2, s: float) -> void:
	var share := fmod(shimmer_t, shimmer_every) / shimmer_time   # 0 → 1 while sweeping; more = resting
	if share >= 1.0:
		return
	var r := 15.0
	var x := lerpf(-r * 1.8, r * 1.8, share)
	var half := 2.6
	var lean := r * 0.5
	var band := PackedVector2Array([
		Vector2(x - half + lean, -r * 1.2), Vector2(x + half + lean, -r * 1.2),
		Vector2(x + half - lean, r * 1.2), Vector2(x - half - lean, r * 1.2)])
	var circle := PackedVector2Array()
	for i in 32:
		circle.append(Vector2(cos(TAU * i / 32.0), sin(TAU * i / 32.0)) * r)
	draw_set_transform(middle, 0.0, Vector2(s, s))
	for piece in Geometry2D.intersect_polygons(circle, band):
		draw_colored_polygon(piece, grey(255))
		var edge := piece.duplicate()
		edge.append(piece[0])
		draw_polyline(edge, grey(0), 0.6)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A pie slice in see-through ink: `share` of the circle, from the top, clockwise.
func _draw_pie(middle: Vector2, radius: float, share: float) -> void:
	var points := PackedVector2Array([middle])
	var steps := maxi(2, int(48 * share))
	for i in steps + 1:
		var angle := TAU * share * i / steps
		points.append(middle + Vector2(sin(angle), -cos(angle)) * radius)
	draw_colored_polygon(points, Color(INK, 0.5))


## Two rings, one after the other, growing out from the edge and fading (ink over a paper edge).
func _draw_equip_rings(middle: Vector2, radius: float) -> void:
	var share := 1.0 - equip_anim_left / equip_anim_time
	for ring in 2:
		var ring_share := clampf((share - ring * 0.3) / 0.7, 0.0, 1.0)
		if ring_share <= 0.0 or ring_share >= 1.0:
			continue
		var r := radius + 4.0 + equip_ring_grow * ring_share
		var width := lerpf(4.0, 1.0, ring_share)
		var fade := 1.0 - ring_share
		draw_arc(middle, r, 0.0, TAU, 48, Color(PAPER, fade), width + 2.0)
		draw_arc(middle, r, 0.0, TAU, 48, Color(INK, fade), width)

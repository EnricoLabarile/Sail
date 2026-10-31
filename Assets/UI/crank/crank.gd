@tool
extends Control
## THE CRANK (up and to the left of the wheel), as in the HTML prototype's wound spring: it works the paddle wheels
## (Assets/Boat/paddles.gd). Turn it clockwise with a finger: ONE FULL TURN winds the paddles and they push the boat
## for a while (paddles.gd push_time). Let go before the turn is complete and the arm springs back, nothing wound.
## Turning it anticlockwise does nothing (a ratchet).
## While the paddles push, the crank is LOCKED (pale, no touch), except in the last seconds of the push (paddles.gd
## recharge_window, Enrico): then it can be wound again, so the push never runs out if you keep it up.
## The ring round the plate shows the push left. It shows only while the paddles are on (the logbook).
##
## Drawn with code, in greys, like the wheel: its CanvasLayer (crank.tscn) sits UNDER the dither (95, the dither is
## 100), so it comes out in paper-and-ink dots. The drawing is in the prototype's units (a 72 x 72 box round the
## middle) scaled to this Control's size: a toothed gear with a dotted face, a hatched plate with three rivets, the
## ring, and the arm with its knob.
## @tool: drawn in the editor too, so you can place and size it (its place and size are this Control's in
## crank.tscn); there it only draws.
## (In Unreal: a UMG widget with its own OnPaint and touch handling.)

@export var spring_back_speed := 12.0   # rad/s the arm springs back when let go before a full turn
@export var press_flash := 0.12         # a touch turns it black for this long (s), with a click (Enrico: every button)

var crank_angle := 0.0        # the arm's angle (radians, 0 = pointing up, clockwise +)
var wound_so_far := 0.0       # how far this turn has got (radians, 0..TAU): at TAU the paddles are wound
var drag_index := -1          # the finger on it (-1 = none)
var last_a := 0.0             # the finger's angle round the middle a moment ago
var press_flash_left := 0.0   # seconds it stays black after a touch


func _paddles() -> Node:
	var boat := get_tree().get_first_node_in_group("player_boat")
	if boat == null:
		return null
	return boat.paddles


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	Inventory.toggled.connect(_on_inventory_changed)
	Inventory.changed.connect(_update_shown)
	_update_shown()


## Shown only while the paddles are on (a hidden Control gets no touches, so hiding it switches it off too).
func _update_shown() -> void:
	visible = Inventory.is_on("paddles")
	if not visible:
		drag_index = -1
		wound_so_far = 0.0
		crank_angle = 0.0


func _on_inventory_changed(_item: String, _on: bool) -> void:
	_update_shown()


## Can it be wound now? (paddles.gd: on, and not pushing, or in the last seconds of a push)
func _can_wind() -> bool:
	var paddles := _paddles()
	return paddles != null and paddles.can_wind()


## How many screen pixels one of the prototype's units is.
func _k() -> float:
	return minf(size.x, size.y) / 72.0


## Only a touch on the crank's round face counts (the square's corners let a touch through).
func _has_point(point: Vector2) -> bool:
	return point.distance_to(size * 0.5) < 36.0 * _k() + 6.0


# ---- touching it ----

func _gui_input(e: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	var c := size * 0.5
	if e is InputEventScreenTouch:
		if e.pressed and drag_index == -1:
			# Every touch: black for a moment and a click (Enrico: every button), even while it's locked.
			press_flash_left = press_flash
			Sfx.button_press()
			queue_redraw()
			if _can_wind():
				drag_index = e.index
				last_a = (e.position - c).angle()
			accept_event()
		elif not e.pressed and e.index == drag_index:
			drag_index = -1                 # let go: if the turn isn't complete, _process springs it back
			accept_event()
	elif e is InputEventScreenDrag and e.index == drag_index:
		var a: float = (e.position - c).angle()
		var turned := wrapf(a - last_a, -PI, PI)   # how far the finger went round since last time
		last_a = a
		# A ratchet: only clockwise counts (on screen, clockwise is a growing angle). A huge jump is a glitch.
		if turned > 0.0 and turned < 1.5:
			wound_so_far += turned
			crank_angle = wound_so_far
			if wound_so_far >= TAU:
				_full_turn()
			queue_redraw()
		accept_event()


## A full turn: the paddles are wound, and the arm is back up, ready for the next turn.
func _full_turn() -> void:
	var paddles := _paddles()
	if paddles:
		paddles.wound()
	wound_so_far = 0.0
	crank_angle = 0.0
	drag_index = -1                         # the finger must come off and start a new turn


func _process(dt: float) -> void:
	if Engine.is_editor_hint() or not visible:
		return
	if press_flash_left > 0.0:
		press_flash_left = maxf(0.0, press_flash_left - dt)
	# Let go before a full turn: the arm springs back anticlockwise to the top, and nothing is wound.
	if drag_index == -1 and wound_so_far > 0.0:
		wound_so_far = maxf(0.0, wound_so_far - spring_back_speed * dt)
		crank_angle = wound_so_far
	# Locked meanwhile (the paddles pushing, outside their last seconds): no finger can stay on it.
	if drag_index != -1 and not _can_wind():
		drag_index = -1
	queue_redraw()                          # the ring follows the push left every frame while it shows


# ---- the drawing ----

## A grey (0 = black, 255 = white).
func grey(v: float, alpha: float = 1.0) -> Color:
	return Color(v / 255.0, v / 255.0, v / 255.0, alpha)


## The gear's outline: 16 teeth round the middle, each a little trapezoid between radius 30.5 and 33.8.
func gear_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	var teeth := 16
	for i in teeth:
		var a := TAU * i / teeth
		var step := TAU / teeth
		points.append(Vector2(cos(a), sin(a)) * 30.5)                             # the gap between two teeth
		points.append(Vector2(cos(a + step * 0.2), sin(a + step * 0.2)) * 33.8)   # up the tooth
		points.append(Vector2(cos(a + step * 0.45), sin(a + step * 0.45)) * 33.8) # its top
		points.append(Vector2(cos(a + step * 0.65), sin(a + step * 0.65)) * 30.5) # back down
	return points


func _draw() -> void:
	var k := _k()
	var middle := size * 0.5
	var locked := false if Engine.is_editor_hint() else not _can_wind()
	var fade := 0.35 if locked else 1.0     # locked: pale (arm and gear faded, as in the prototype)
	var ink := grey(0, fade)
	var paper := grey(255)

	# Just touched: the whole crank black for a moment.
	if press_flash_left > 0.0:
		draw_set_transform(middle, 0.0, Vector2(k, k))
		draw_colored_polygon(gear_points(), grey(0))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return

	# 1. The parts that turn with the arm: the gear (a mid grey, which the dither makes dotted, with an ink edge),
	#    the plate (paper with a hatch of thin lines), three rivets.
	draw_set_transform(middle, crank_angle, Vector2(k, k))
	var gear := gear_points()
	draw_colored_polygon(gear, grey(185, fade))
	var closed := gear.duplicate()
	closed.append(gear[0])
	draw_polyline(closed, ink, 1.6, true)
	draw_circle(Vector2.ZERO, 24.0, paper)
	# the hatch: lines at 45 degrees, each cut to fit inside the plate (radius 23)
	var c := -22.0
	while c <= 22.0:
		var half := sqrt(23.0 * 23.0 - c * c)
		var across := Vector2(0.7071, -0.7071) * c       # how far this line is from the middle
		var along := Vector2(0.7071, 0.7071) * half      # half its length, along the line
		draw_line(across - along, across + along, grey(150, fade), 0.8)
		c += 4.0
	draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 48, ink, 1.4)
	for r in [Vector2(0, 13), Vector2(11.3, -6.5), Vector2(-11.3, -6.5)]:
		draw_circle(r, 1.5, ink)

	# 2. The ring that doesn't turn: a dotted track, and over it an ink arc as long as the push left.
	draw_set_transform(middle, 0.0, Vector2(k, k))
	for i in 36:
		var a := TAU * i / 36.0
		draw_circle(Vector2(cos(a), sin(a)) * 19.5, 0.5, grey(0, 0.6))
	var paddles := null if Engine.is_editor_hint() else _paddles()
	if paddles and paddles.push_left > 0.0:
		var share: float = paddles.push_left / paddles.push_time
		draw_arc(Vector2.ZERO, 19.5, -PI / 2.0, -PI / 2.0 + share * TAU, 32, grey(0), 3.6)

	# 3. The arm and its knob, turning; the hub on top.
	draw_set_transform(middle, crank_angle, Vector2(k, k))
	draw_line(Vector2.ZERO, Vector2(0, -26), ink, 4.0)
	draw_circle(Vector2(0, -26), 8.5 + 1.1, ink)
	draw_circle(Vector2(0, -26), 8.5 - 1.1, paper)
	draw_circle(Vector2(0, -26), 2.4, ink)
	draw_circle(Vector2.ZERO, 4.5, ink)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

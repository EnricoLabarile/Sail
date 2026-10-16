extends Control
## THE CRANK (bottom right), as in the HTML prototype (CRANK_DIRECT): turn it clockwise with a finger and
## the paddle wheels push the boat; stop and they let go. Turning it anticlockwise does nothing (a ratchet).
## How fast you turn it sets how hard they push: a turn in about 1.3 seconds (crank_full_rate) is full push.
##
## Drawn with code, in greys, like the wheel: its CanvasLayer (crank.tscn) sits UNDER the dither (95, the
## dither is 100), so it comes out in paper-and-ink dots. The drawing is in the prototype's units (a 72 x 72
## box round the middle) scaled to this Control's size: a toothed gear with a dotted face, a hatched plate with
## three rivets, a ring that fills with the wheels' push, and the arm with its knob.
## It tells the boat (group "player_boat") how fast it's being turned: boat.set_crank(0..1).

@export var crank_full_rate := 5.0   # rad/s of cranking for the wheels' full push (6.3 = a turn a second)

var crank_angle := 0.0     # the arm's angle (radians, 0 = pointing up, clockwise +)
var crank_move := 0.0      # how far it was turned since the last frame (radians, forward only)
var crank_speed := 0.0     # how fast it's turning (rad/s, smoothed)
var drag_index := -1       # the finger on it (-1 = none)
var last_a := 0.0          # the finger's angle round the middle a moment ago
var shown_power := -1.0    # the push the ring was last drawn with (to redraw only when it changes)


func _boat() -> Node:
	return get_tree().get_first_node_in_group("player_boat")


## How many screen pixels one of the prototype's units is.
func _k() -> float:
	return minf(size.x, size.y) / 72.0


## Only a touch on the crank's round face counts (the square's corners let a touch through to the wheel).
func _has_point(point: Vector2) -> bool:
	return point.distance_to(size * 0.5) < 36.0 * _k() + 6.0


# ---- touching it ----

func _gui_input(e: InputEvent) -> void:
	var c := size * 0.5
	if e is InputEventScreenTouch:
		if e.pressed and drag_index == -1:
			drag_index = e.index
			last_a = (e.position - c).angle()
			accept_event()
		elif not e.pressed and e.index == drag_index:
			drag_index = -1
			accept_event()
	elif e is InputEventScreenDrag and e.index == drag_index:
		var a: float = (e.position - c).angle()
		var turned := wrapf(a - last_a, -PI, PI)   # how far the finger went round since last time
		last_a = a
		# A ratchet: only clockwise counts (on screen, clockwise is a growing angle). A huge jump is a glitch.
		if turned > 0.0 and turned < 1.5:
			crank_angle = wrapf(crank_angle + turned, -PI, PI)
			crank_move += turned
			queue_redraw()
		accept_event()


func _process(dt: float) -> void:
	# 1. How fast it's being turned: this frame's turning per second, smoothed a little.
	#    No finger on it: it isn't turning at all.
	crank_speed += (crank_move / dt - crank_speed) * minf(1.0, dt * 10.0)
	crank_move = 0.0
	if drag_index == -1:
		crank_speed = 0.0
	# 2. Tell the boat: 0 = still, 1 = turned fast enough for full push.
	var b := _boat()
	if b:
		b.set_crank(minf(1.0, crank_speed / crank_full_rate))
		# 3. The ring shows how hard the wheels push now: redraw it when that changes.
		if absf(b.paddle_power - shown_power) > 0.01:
			shown_power = b.paddle_power
			queue_redraw()


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
		points.append(Vector2(cos(a), sin(a)) * 30.5)                       # the gap between two teeth
		points.append(Vector2(cos(a + step * 0.2), sin(a + step * 0.2)) * 33.8)   # up the tooth
		points.append(Vector2(cos(a + step * 0.45), sin(a + step * 0.45)) * 33.8) # its top
		points.append(Vector2(cos(a + step * 0.65), sin(a + step * 0.65)) * 30.5) # back down
	return points


func _draw() -> void:
	var k := _k()
	var middle := size * 0.5
	var ink := grey(0)
	var paper := grey(255)
	var power := 0.0
	var b := _boat()
	if b:
		power = b.paddle_power

	# 1. The parts that turn with the arm: the gear (a mid grey, which the dither makes dotted, with an ink
	#    edge), the plate (paper with a hatch of thin lines), three rivets.
	draw_set_transform(middle, crank_angle, Vector2(k, k))
	var gear := gear_points()
	draw_colored_polygon(gear, grey(185))
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
		draw_line(across - along, across + along, grey(150), 0.8)
		c += 4.0
	draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 48, ink, 1.4)
	for r in [Vector2(0, 13), Vector2(11.3, -6.5), Vector2(-11.3, -6.5)]:
		draw_circle(r, 1.5, ink)

	# 2. The ring that doesn't turn: a dotted track, and over it an ink arc as long as the wheels' push.
	draw_set_transform(middle, 0.0, Vector2(k, k))
	for i in 36:
		var a := TAU * i / 36.0
		draw_circle(Vector2(cos(a), sin(a)) * 19.5, 0.5, grey(0, 0.6))
	if power > 0.0:
		draw_arc(Vector2.ZERO, 19.5, -PI / 2.0, -PI / 2.0 + power * TAU, 32, ink, 3.6)

	# 3. The arm and its knob, turning; the hub on top.
	draw_set_transform(middle, crank_angle, Vector2(k, k))
	draw_line(Vector2.ZERO, Vector2(0, -26), ink, 4.0)
	draw_circle(Vector2(0, -26), 8.5 + 1.1, ink)
	draw_circle(Vector2(0, -26), 8.5 - 1.1, paper)
	draw_circle(Vector2(0, -26), 2.4, ink)
	draw_circle(Vector2.ZERO, 4.5, ink)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

extends Control
## The ship's wheel (like a UMG widget that drives the pawn): drag round the rim to steer,
## half a turn either way = full rudder, and let go it spins back to the middle; hold the hub to drop
## or weigh the anchor. The arrow keys turn it too.
## It finds the boat through the group "player_boat".

const PAPER := Color("ebe7dc")
const INK := Color("1b1a17")

@export var hub_hold := 0.33     # s to hold the hub for the anchor
@export var lock_turn := PI      # how far the wheel turns for full rudder (PI = half a turn)
@export var return_rate := 3.5   # let go, the wheel spins back to the middle: this share of its angle a second…
@export var return_min := 0.8    # …but at least this many rad/s, so it gets all the way back (as in the HTML prototype)
@export var key_rate := PI * 1.1 # rad/s the arrow keys turn it

var wheel_angle := 0.0
var drag_index := -1             # the finger turning the wheel
var last_a := 0.0
var hub_index := -1              # the finger holding the hub
var hub_t := 0.0
var shown_anchor := true          # the anchor state the hub was last drawn with

func _boat() -> Node:
	return get_tree().get_first_node_in_group("player_boat")

func _radius() -> float:
	return minf(size.x, size.y) * 0.5 - 16.0

func _hub_r() -> float:
	return _radius() * 0.3

func _gui_input(e: InputEvent) -> void:
	var c := size * 0.5
	if e is InputEventScreenTouch:
		var d: float = (e.position - c).length()
		if e.pressed:
			if d < _hub_r():
				hub_index = e.index
				hub_t = 0.0
			elif d < _radius() + 24.0 and drag_index == -1:
				drag_index = e.index
				last_a = (e.position - c).angle()
			accept_event()
		else:
			if e.index == drag_index:
				drag_index = -1
			if e.index == hub_index:
				hub_index = -1
				hub_t = 0.0
			queue_redraw()
	elif e is InputEventScreenDrag and e.index == drag_index:
		var a: float = (e.position - c).angle()
		wheel_angle = clampf(wheel_angle + wrapf(a - last_a, -PI, PI), -lock_turn, lock_turn)
		last_a = a
		var b := _boat()
		if b:
			b.set_rudder(wheel_angle / lock_turn)
		accept_event()
		queue_redraw()

func _process(dt: float) -> void:
	var b := _boat()
	if hub_index != -1:
		hub_t += dt
		if hub_t >= hub_hold:
			if b:
				b.toggle_anchor()
			hub_index = -1
			hub_t = 0.0
		queue_redraw()
	if drag_index == -1:
		var keys := Input.get_axis("ui_left", "ui_right")
		if keys != 0.0:                                   # the arrow keys turn it
			wheel_angle = clampf(wheel_angle + keys * key_rate * dt, -lock_turn, lock_turn)
			queue_redraw()
		elif wheel_angle != 0.0:                          # let go: it spins back to the middle
			var step := maxf(absf(wheel_angle) * return_rate, return_min) * dt
			wheel_angle = 0.0 if absf(wheel_angle) <= step else wheel_angle - signf(wheel_angle) * step
			queue_redraw()
		if b:
			b.set_rudder(wheel_angle / lock_turn)
	if b and b.anchored != shown_anchor:
		shown_anchor = b.anchored
		queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var r := _radius()
	var hr := _hub_r()
	# the spokes, turning with the wheel, each ending in a handle past the rim
	for i in 8:
		var a := wheel_angle + i * TAU / 8.0
		var dir := Vector2(cos(a), sin(a))
		draw_line(c + dir * hr, c + dir * (r + 12.0), INK, 7.0)
		draw_line(c + dir * hr, c + dir * (r + 12.0), PAPER, 3.0)
		draw_circle(c + dir * (r + 12.0), 7.0, INK)
		draw_circle(c + dir * (r + 12.0), 4.0, PAPER)
	# the rim
	draw_arc(c, r, 0.0, TAU, 64, INK, 12.0)
	draw_arc(c, r, 0.0, TAU, 64, PAPER, 6.0)
	# the hub: light while sailing, dark at anchor, with an anchor on it
	var anchored: bool = _boat() != null and _boat().anchored
	var face := INK if anchored else PAPER
	var mark := PAPER if anchored else INK
	draw_circle(c, hr, INK)
	draw_circle(c, hr - 3.0, face)
	var s := hr * 0.55
	draw_line(c + Vector2(0, -s), c + Vector2(0, s), mark, 3.0)
	draw_line(c + Vector2(-s * 0.5, -s * 0.5), c + Vector2(s * 0.5, -s * 0.5), mark, 3.0)
	draw_arc(c + Vector2(0, s * 0.2), s * 0.8, 0.15 * PI, 0.85 * PI, 16, mark, 3.0)
	draw_circle(c + Vector2(0, -s - 3.0), 3.0, mark)
	# holding the hub: a ring fills round it
	if hub_index != -1:
		draw_arc(c, hr + 6.0, -PI / 2.0, -PI / 2.0 + TAU * hub_t / hub_hold, 32, INK, 4.0)

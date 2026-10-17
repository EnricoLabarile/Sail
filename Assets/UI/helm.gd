extends Control
## The ship's wheel (like a UMG widget that drives the pawn), drawn and behaving as in the HTML prototype.
##
## - Drag round the wheel to steer: half a turn either way = full rudder. Let go and it spins back to the middle.
## - The hub is the anchor button: hold it hub_hold seconds to drop or weigh the anchor (a ring fills round
##   it while you hold, then the hub gives a little shake). Moving your finger off it turns the wheel instead.
## - At anchor the wheel doesn't steer (the drag and the arrow keys do nothing until the anchor is up).
## - The arrow keys turn it too.
##
## It is drawn with code, in greys, like the logbook button: its CanvasLayer (helm.tscn) sits UNDER the
## dither (layer 95, the dither is 100), so the dither turns the greys into paper-and-ink dots.
## The drawing is made in the prototype's units (its wheel was 221 x 242 px, the middle at 110.5, 131)
## and scaled to this Control's size. It finds the boat through the group "player_boat".

@export var hub_hold := 0.33     # s to hold the hub for the anchor
@export var lock_turn := PI      # how far the wheel turns for full rudder (PI = half a turn)
@export var return_rate := 3.5   # let go, the wheel spins back to the middle: this share of its angle a second…
@export var return_min := 0.8    # …but at least this many rad/s, so it gets all the way back (as in the prototype)
@export var key_rate := PI * 1.1 # rad/s the arrow keys turn it

# The prototype's measures (in its pixels): the drawing's size, its middle, how much the wheel is scaled up.
const DRAW_W := 221.0
const DRAW_H := 242.0
const MIDDLE := Vector2(110.5, 131.0)
const WHEEL_SCALE := 1.3         # the wheel is drawn 30% up (WH_S)
const HUB_SCALE := 2.0           # the hub is drawn twice as big again (hubScale)
const HUB_GRIP_SAILING := 16.5   # the hub's grip while sailing: only the hub, so the spokes round it still steer
const HUB_GRIP_ANCHORED := 21.0  # the hub's grip at anchor (a bit bigger: then the wheel doesn't steer anyway)
const OUTER_GRIP := 84.0         # past this (× WHEEL_SCALE) a touch misses the wheel

# Greys (0 = black, 255 = white) for the wood: a mid grey, so the wheel stands out from the pale sea.
const WOOD := 172.0
const WOOD_SHADE := 122.0
const WOOD_RIM := 160.0

# A spoke and a handle are "turned" like lathe pieces: [distance from the middle, half its width] stations.
const HANDLE := [[58, 2.2], [61, 2.6], [62.5, 4.2], [64, 2.8], [66, 4.6], [69.5, 5.4], [72.5, 4.4], [74, 2.6], [75.5, 3.6], [78, 3.4], [79.5, 1.8]]
const SPOKE := [[13, 3.8], [22, 3.2], [27, 3], [28.5, 4.6], [31, 4.6], [32.5, 3], [44, 2.8], [50, 3.2]]

var wheel_angle := 0.0
var drag_index := -1             # the finger on the wheel (-1 = none)
var last_a := 0.0                # the finger's angle round the middle, a moment ago
var hub_index := -1              # the finger holding the hub (-1 = none)
var hub_t := 0.0                 # how long it has been held
var hub_start := Vector2.ZERO    # where that finger came down (in the prototype's units)
var hub_shake := 0.0             # 1 right after the anchor goes down or comes up, fading to 0
var shown_anchor := true         # the anchor state the hub was last drawn with


func _boat() -> Node:
	return get_tree().get_first_node_in_group("player_boat")


func _is_anchored() -> bool:
	var b := _boat()
	return b != null and b.anchored


## How many screen pixels one of the prototype's pixels is (the Control may be a different size).
func _k() -> float:
	return minf(size.x / DRAW_W, size.y / DRAW_H)


## A point of the screen (inside this Control) in the prototype's units, measured from the wheel's middle.
func _local(screen_pos: Vector2) -> Vector2:
	var middle_on_screen := size * 0.5 + (MIDDLE - Vector2(DRAW_W, DRAW_H) * 0.5) * _k()
	return (screen_pos - middle_on_screen) / _k()


# ---- touching it ----

## Only a touch on the wheel itself counts (inside its handles): the corners of this box let a touch
## through to what's under them (the logbook).
func _has_point(point: Vector2) -> bool:
	return _local(point).length() < OUTER_GRIP * WHEEL_SCALE

func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		var p := _local(e.position)
		var d := p.length()
		if e.pressed:
			if d > OUTER_GRIP * WHEEL_SCALE or drag_index != -1:
				return                                    # outside the handles, or a finger is already on it
			drag_index = e.index
			last_a = p.angle()
			var grip := HUB_GRIP_ANCHORED if _is_anchored() else HUB_GRIP_SAILING
			if d < grip * WHEEL_SCALE * HUB_SCALE:        # on the hub: hold it for the anchor
				hub_index = e.index
				hub_t = 0.0
				hub_start = p
			accept_event()
		elif e.index == drag_index:
			drag_index = -1
			hub_index = -1
			hub_t = 0.0
			queue_redraw()
	elif e is InputEventScreenDrag and e.index == drag_index:
		var p := _local(e.position)
		var a := p.angle()
		# A finger that moves off where it pressed the hub is turning the wheel, not holding the hub.
		if hub_index != -1 and p.distance_to(hub_start) > 9.0:
			hub_index = -1
			hub_t = 0.0
		# Too close to the middle the angle jumps about; and at anchor the wheel doesn't steer.
		if p.length() < 14.0 * WHEEL_SCALE or _is_anchored():
			last_a = a
			accept_event()
			return
		wheel_angle = clampf(wheel_angle + wrapf(a - last_a, -PI, PI), -lock_turn, lock_turn)
		last_a = a
		accept_event()
		queue_redraw()


func _process(dt: float) -> void:
	var b := _boat()
	var anchored := _is_anchored()

	# 1. Holding the hub: when the time is up, drop or weigh the anchor, and shake the hub.
	if hub_index != -1:
		hub_t += dt
		if hub_t >= hub_hold:
			if b:
				b.toggle_anchor()
			hub_index = -1
			hub_t = 0.0
			hub_shake = 1.0
		queue_redraw()
	if hub_shake > 0.0:
		hub_shake = maxf(0.0, hub_shake - dt * 3.6)
		queue_redraw()

	# 2. The arrow keys turn it (not at anchor); with no finger and no key it spins back to the middle.
	var keys := Input.get_axis("ui_left", "ui_right")
	if keys != 0.0 and not anchored and drag_index == -1:
		wheel_angle = clampf(wheel_angle + keys * key_rate * dt, -lock_turn, lock_turn)
		queue_redraw()
	elif drag_index == -1 and wheel_angle != 0.0:
		var step := maxf(absf(wheel_angle) * return_rate, return_min) * dt
		wheel_angle = 0.0 if absf(wheel_angle) <= step else wheel_angle - signf(wheel_angle) * step
		queue_redraw()
	if b:
		b.set_rudder(wheel_angle / lock_turn)

	# 3. The hub's face changes with the anchor: redraw when it does.
	if anchored != shown_anchor:
		shown_anchor = anchored
		queue_redraw()


# ---- little drawing helpers ----

## A grey (0 = black, 255 = white).
func grey(v: float, alpha: float = 1.0) -> Color:
	return Color(v / 255.0, v / 255.0, v / 255.0, alpha)


## The outline of a turned piece (a spoke or a handle) lying along +x: its top edge out, its bottom edge back.
func turned(stations: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for st in stations:
		points.append(Vector2(st[0], -st[1]))
	for i in range(stations.size() - 1, -1, -1):
		points.append(Vector2(stations[i][0], stations[i][1]))
	return points


## The lower half of a turned piece (from 1 unit below its middle line to its bottom edge): its shaded flank.
func turned_flank(stations: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for st in stations:
		points.append(Vector2(st[0], 1.0))
	for i in range(stations.size() - 1, -1, -1):
		points.append(Vector2(stations[i][0], stations[i][1]))
	return points


## A closed outline: the polygon's points joined, back to the first.
func draw_outline(points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, color, width, true)


## A disc whose grey changes from the middle (inner) to the edge (outer): a radial gradient.
## Made of a fan of triangles, one colour at the middle point and another on the rim (Godot blends between).
func radial_disc(center: Vector2, radius: float, inner: Color, outer: Color) -> void:
	var n := 40
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var tri := PackedVector2Array([center, center + Vector2(cos(a0), sin(a0)) * radius, center + Vector2(cos(a1), sin(a1)) * radius])
		draw_polygon(tri, PackedColorArray([inner, outer, outer]))


## A disc lit from the top left: light at the top left, dark at the bottom right (a diagonal gradient).
func lit_disc(radius: float, light: Color, middle: Color, dark: Color) -> void:
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for i in 40:
		var a := TAU * i / 40.0
		var p := Vector2(cos(a), sin(a)) * radius
		points.append(p)
		var t := clampf(((p.x + p.y) / (radius * 2.0)) + 0.5, 0.0, 1.0)   # 0 top left .. 1 bottom right
		colors.append(light.lerp(middle, t * 2.0) if t < 0.5 else middle.lerp(dark, t * 2.0 - 1.0))
	draw_polygon(points, colors)


## Points along a curve from a to b, pulled toward the control point c (a quadratic Bezier curve).
func curve(a: Vector2, c: Vector2, b: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 9:
		var t := i / 8.0
		points.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
	return points


# ---- the drawing ----

func _draw() -> void:
	var k := _k()
	var middle_on_screen := size * 0.5 + (MIDDLE - Vector2(DRAW_W, DRAW_H) * 0.5) * k
	_draw_wheel(middle_on_screen, k)
	_draw_hub(middle_on_screen, k)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)    # back to normal


## The wheel: a dark backing, eight spokes with turned handles, the rim, and the small hub boss.
## Everything is drawn round (0, 0), turned by wheel_angle and scaled by WHEEL_SCALE.
func _draw_wheel(middle: Vector2, k: float) -> void:
	var ink := grey(0)
	var paper := grey(255)
	var s := k * WHEEL_SCALE
	draw_set_transform(middle, wheel_angle, Vector2(s, s))

	# 1. A dark backing inside the rim: the gaps between the spokes are a deep dotted tone,
	#    so the light wood reads on any sea. A touch lighter toward the middle.
	radial_disc(Vector2.ZERO, 50.0, grey(70), grey(44))

	# 2. The eight spokes, each with its handle past the rim.
	for i in 8:
		var a := wheel_angle + i * PI / 4.0 - PI / 2.0
		draw_set_transform(middle, a, Vector2(s, s))      # turn the drawing so this spoke lies along +x
		# the handle: wood, a shaded lower flank, an ink outline, a grain line and an ink band at the neck
		draw_colored_polygon(turned(HANDLE), grey(WOOD))
		draw_colored_polygon(turned_flank(HANDLE), grey(WOOD_SHADE))
		draw_outline(turned(HANDLE), ink, 1.6)
		draw_line(Vector2(69.5, -5.4), Vector2(69.5, 5.4), ink, 1.0)
		draw_rect(Rect2(63.2, -3.4, 1.6, 6.8), ink)
		if i == 0:                                        # the king spoke: a whipped rope band, to see the middle
			draw_rect(Rect2(66.5, -5.2, 6.0, 10.4), ink)
			var u := 67.3
			while u < 72.5:
				draw_line(Vector2(u, -4.6), Vector2(u + 0.8, 4.6), paper, 0.9)
				u += 1.6
		# the spoke
		draw_colored_polygon(turned(SPOKE), grey(WOOD))
		draw_colored_polygon(turned_flank(SPOKE), grey(WOOD_SHADE))
		draw_outline(turned(SPOKE), ink, 1.4)

	# 3. The rim: two ink edges round a wooden band, darker at the bottom right (the light comes from
	#    the top left, so this shade doesn't turn with the wheel), with grain marks along it.
	draw_set_transform(middle, wheel_angle, Vector2(s, s))
	draw_arc(Vector2.ZERO, 55.0, 0.0, TAU, 64, ink, 12.0)
	draw_arc(Vector2.ZERO, 55.0, 0.0, TAU, 64, grey(WOOD_RIM), 8.6)
	draw_arc(Vector2.ZERO, 55.0, -0.15 * PI - wheel_angle, 0.85 * PI - wheel_angle, 32, grey(0, 0.18), 8.6)
	for g in 10:
		var a0 := g * 0.63 + (g % 3) * 0.07
		var radius := 53.5 + (g % 2) * 2.5
		var length := 0.22 + (g % 3) * 0.06
		draw_arc(Vector2.ZERO, radius, a0, a0 + length, 6, ink, 0.8)
	# brass caps with a rivet where each spoke passes through the rim
	for i in 8:
		draw_set_transform(middle, wheel_angle + i * PI / 4.0 - PI / 2.0, Vector2(s, s))
		draw_rect(Rect2(50.2, -3.6, 9.6, 7.2), ink)
		draw_rect(Rect2(51.4, -2.4, 7.2, 4.8), paper)
		draw_circle(Vector2(55.0, 0.0), 1.3, ink)

	# 4. The hub's boss: an ink ring with eight bolts, an inked cap and a bright axle.
	draw_set_transform(middle, wheel_angle, Vector2(s, s))
	draw_circle(Vector2.ZERO, 15.5, ink)
	draw_circle(Vector2.ZERO, 13.0, grey(WOOD_SHADE))
	draw_circle(Vector2.ZERO, 9.5, ink)
	for i in 8:
		var a := i * PI / 4.0
		draw_circle(Vector2(cos(a), sin(a)) * 11.3, 1.1, ink)
	draw_circle(Vector2.ZERO, 4.8, paper)
	draw_arc(Vector2.ZERO, 2.4, 0.0, TAU, 16, ink, 1.2)
	draw_line(Vector2(-2.4, 0.0), Vector2(2.4, 0.0), ink, 1.2)


## The hub, the anchor button, drawn big over the middle of the wheel (it doesn't turn with it):
## a brass bezel lit from the top left with four rivets, a shaded face with a glint of glass, and an anchor.
## Sailing: a light face with an ink anchor. At anchor: a dark face, one light rim, a paper anchor.
func _draw_hub(middle: Vector2, k: float) -> void:
	var ink := grey(0)
	var paper := grey(255)
	var anchored := _is_anchored()
	var shake_x := sin(Time.get_ticks_msec() * 0.09) * 2.2 * hub_shake    # a little shake after a press
	var s := k * WHEEL_SCALE * HUB_SCALE
	draw_set_transform(middle + Vector2(shake_x * k * WHEEL_SCALE, 0.0), 0.0, Vector2(s, s))
	var hub_r := 15.0
	var face_r := hub_r - 3.2

	# 1. The bezel, with its ink edge and four rivets (each with a speck of light).
	lit_disc(hub_r, grey(245), grey(200), grey(140))
	draw_arc(Vector2.ZERO, hub_r, 0.0, TAU, 48, ink, 1.6)
	for i in 4:
		var a := PI / 4.0 + i * PI / 2.0
		var r := Vector2(cos(a), sin(a)) * (hub_r - 1.6)
		draw_circle(r, 1.05, ink)
		draw_rect(Rect2(r.x - 0.6, r.y - 0.6, 0.6, 0.6), paper)

	# 2. The face: light while sailing, dark at anchor (a little lighter toward its top left).
	if anchored:
		radial_disc(Vector2(-face_r * 0.15, -face_r * 0.15), face_r, grey(100), grey(28))
	else:
		radial_disc(Vector2(-face_r * 0.15, -face_r * 0.15), face_r, grey(255), grey(182))
	draw_arc(Vector2.ZERO, face_r, 0.0, TAU, 40, ink, 1.0)
	draw_arc(Vector2.ZERO, face_r - 1.6, PI * 1.08, PI * 1.38, 8, paper, 1.1)    # the glint
	if anchored:
		draw_arc(Vector2.ZERO, hub_r + 1.4, 0.0, TAU, 48, paper, 1.3)           # a light rim: reads on dark water

	# 3. Holding it: a ring fills round it (ink, with a paper edge so it reads anywhere).
	if hub_index != -1:
		var fill := minf(1.0, hub_t / hub_hold)
		var end := -PI / 2.0 + fill * TAU
		draw_arc(Vector2.ZERO, hub_r + 1.5, -PI / 2.0, end, 32, paper, 4.8)
		draw_arc(Vector2.ZERO, hub_r + 1.5, -PI / 2.0, end, 32, ink, 2.8)

	# 4. The anchor: ink on the light face, paper on the dark one.
	var mark := paper if anchored else ink
	var w := 1.7 if anchored else 1.75
	draw_set_transform(middle + Vector2(shake_x * k * WHEEL_SCALE, 0.0), 0.0, Vector2(s, s) * 1.2)
	draw_arc(Vector2(0.0, -7.0), 1.9, 0.0, TAU, 16, mark, w)                     # the ring at the top
	draw_line(Vector2(0.0, -5.0), Vector2(0.0, 7.5), mark, w)                     # the shank
	draw_line(Vector2(-4.5, -2.2), Vector2(4.5, -2.2), mark, w)                   # the stock
	draw_polyline(curve(Vector2(-6.5, 2.5), Vector2(-5.0, 7.5), Vector2(0.0, 7.5)), mark, w)   # the arms
	draw_polyline(curve(Vector2(0.0, 7.5), Vector2(5.0, 7.5), Vector2(6.5, 2.5)), mark, w)

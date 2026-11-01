@tool
extends Control
## THE THROTTLE LEVER (Enrico, Nov 2026, from his sketch; it replaced the crank turned round, keeping its files and
## its name in the scenes): a lever on a pivot at the bottom, swinging left and right over a curved plate. Drag it
## with a finger; let go and its SPRING brings it back to the middle, always (also after reaching an end).
##
## Where it is sets the MOST she may go (paddles.gd set_lever_share; not a brake, she reaches it at her usual rate):
##   all the way left = 0%, the middle (at rest) = 50%, all the way right = 100%, in a straight line in between.
## The two ends do more:
##   - ALL THE WAY RIGHT, while she's off (at anchor, tied up, or the battery empty): she TURNS ON: the anchor comes up
##     (or she casts off) and the paddles' battery is full (paddles.turn_on). Then the lever springs back to the middle.
##   - ALL THE WAY RIGHT, while she runs, in the battery's last seconds (paddles.recharge_window): the battery is full
##     again (paddles.refill). The lever stays where the finger holds it (100%).
##   - ALL THE WAY LEFT, while the anchor is up: she TURNS OFF: the anchor goes down (paddles.turn_off). Then the
##     lever springs back to the middle.
## An end works once each time the lever gets there: to use it again, the lever must leave it first.
## The battery runs down faster the faster the lever lets her go (paddles.gd drain_rate).
##
## The track along the plate's inner edge shows the battery left.
## Its sounds (Enrico): a light click every notch (NOTCHES across the plate), higher toward the right
## (Sfx.crank_click); a firm snap at an end that turns her on, off or fills the battery (Sfx.lever_done, with the
## anchor's own sound); the unlock sound the moment the battery can be filled again (Sfx.crank_unlock).
##
## Drawn with code, in greys, like the wheel: its CanvasLayer (crank.tscn) sits UNDER the dither, so it comes out in
## paper-and-ink dots. The drawing is in its own units (a 72 x 72 box round the Control's middle), scaled to this
## Control's size: the plate (a ring segment), the lever (a striped grip, like a spring) and the pivot's knob.
## @tool: drawn in the editor too, so you can place and size it (its place and size are this Control's in crank.tscn).
## (In Unreal: a UMG widget with its own OnPaint and touch handling.)

@export var spring_back_speed := 3.0    # how fast it springs back to the middle (a whole half-swing in 1/3 s)
@export var press_flash := 0.12         # a touch turns it black for this long (s), with a click (Enrico: every button)

const MAX_ANGLE := deg_to_rad(45.0)     # how far the lever swings either way from upright
const PIVOT := Vector2(0.0, 28.0)       # the pivot, in the drawing's units (from the box's middle; y down)
const PLATE_INNER := 26.0               # the plate's inner and outer edge (distance from the pivot)
const PLATE_OUTER := 50.0
const LEVER_LENGTH := 56.0              # from the pivot to the grip's top
const NOTCHES := 16                     # clicks across the whole swing
const END := 0.98                       # how close to an end (of 1) counts as there

var lever := 0.0              # where it is: -1 all the way left, 0 the middle, +1 all the way right
var drag_index := -1          # the finger on it (-1 = none)
var last_a := 0.0             # the finger's angle round the pivot a moment ago
var press_flash_left := 0.0   # seconds it stays black after a touch
var notch := NOTCHES / 2      # the notch it's at (for the clicks)
var at_left_end := false      # is it at an end now? (an end works once each time the lever gets there)
var at_right_end := false
var was_free := true          # could the battery be filled a frame ago? (to hear the moment it can)


func _paddles() -> Node:
	var boat := get_tree().get_first_node_in_group("player_boat")
	if boat == null:
		return null
	return boat.paddles


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var paddles := _paddles()
	was_free = paddles == null or paddles.can_wind()   # no unlock sound for the state it starts in


## How many screen pixels one of the drawing's units is.
func _k() -> float:
	return minf(size.x, size.y) / 72.0


## The pivot on the screen (in this Control's pixels).
func _pivot() -> Vector2:
	return size * 0.5 + PIVOT * _k()


## The angle of a point round the pivot, measured from straight up, clockwise + (so right = +).
func _angle_round_pivot(point: Vector2) -> float:
	var off := point - _pivot()
	return atan2(off.x, -off.y)


## Only a touch on the plate and lever counts: within the lever's reach from the pivot, and not below the pivot.
func _has_point(point: Vector2) -> bool:
	var off := point - _pivot()
	return off.length() < (LEVER_LENGTH + 6.0) * _k() and off.y < 8.0 * _k()


# ---- touching it ----

func _gui_input(e: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if e is InputEventScreenTouch:
		if e.pressed and drag_index == -1:
			# Every touch: black for a moment and a click (Enrico: every button).
			press_flash_left = press_flash
			Sfx.button_press()
			drag_index = e.index
			last_a = _angle_round_pivot(e.position)
			accept_event()
		elif not e.pressed and e.index == drag_index:
			drag_index = -1                 # let go: _process springs it back to the middle
			accept_event()
	elif e is InputEventScreenDrag and e.index == drag_index:
		var a := _angle_round_pivot(e.position)
		var turned := wrapf(a - last_a, -PI, PI)   # how far the finger went round the pivot since last time
		last_a = a
		if absf(turned) < 1.5:              # a huge jump is a glitch: ignored
			move_lever(turned / MAX_ANGLE)
		accept_event()


## Moves the lever by `amount` (of the half-swing: 1 = from the middle to an end), clicks its notches and works the ends.
func move_lever(amount: float) -> void:
	lever = clampf(lever + amount, -1.0, 1.0)
	click_notches()
	check_ends()


## A light click for each notch passed, higher toward the right (notch n of NOTCHES at 2^(n/NOTCHES)).
func click_notches() -> void:
	var now := int(round((lever + 1.0) * 0.5 * NOTCHES))
	if now != notch:
		notch = now
		Sfx.crank_click(notch, NOTCHES)


## The ends: each works once when the lever gets there (it must leave it before it works again).
func check_ends() -> void:
	var paddles := _paddles()
	# All the way right.
	if lever >= END and not at_right_end:
		at_right_end = true
		if paddles:
			if not paddles.is_running():
				paddles.turn_on()           # off: she starts (anchor up, battery full)…
				Sfx.lever_done()
				let_go()                    # …and the lever springs back to the middle
			elif paddles.can_wind():
				paddles.refill()            # running, battery nearly out: full again; she keeps the 100%
				Sfx.lever_done()
	elif lever < END:
		at_right_end = false
	# All the way left.
	if lever <= -END and not at_left_end:
		at_left_end = true
		var boat := get_tree().get_first_node_in_group("player_boat")
		if paddles and boat and not boat.anchored:
			paddles.turn_off()              # she stops: anchor down…
			Sfx.lever_done()
			let_go()                        # …and the lever springs back to the middle
	elif lever > -END:
		at_left_end = false


## The finger must come off: the spring takes the lever back to the middle.
func let_go() -> void:
	drag_index = -1


func _process(dt: float) -> void:
	if Engine.is_editor_hint() or not visible:
		return
	if press_flash_left > 0.0:
		press_flash_left = maxf(0.0, press_flash_left - dt)
	# Let go: the spring takes it back to the middle (silently).
	if drag_index == -1 and lever != 0.0:
		lever = move_toward(lever, 0.0, spring_back_speed * dt)
		notch = int(round((lever + 1.0) * 0.5 * NOTCHES))
		check_ends()                        # (only to notice it has left an end)
	var paddles := _paddles()
	if paddles:
		# The most she may go: 0% all the way left, 50% in the middle, 100% all the way right.
		paddles.set_lever_share(0.5 + 0.5 * lever)
		# The moment the battery can be filled again (its last seconds, or empty): the unlock sound, once.
		var free: bool = paddles.can_wind()
		if free and not was_free:
			Sfx.crank_unlock()
		was_free = free
	queue_redraw()                          # the battery track follows the battery every frame


# ---- the drawing ----

## A grey (0 = black, 255 = white).
func grey(v: float, alpha: float = 1.0) -> Color:
	return Color(v / 255.0, v / 255.0, v / 255.0, alpha)


## A point at `distance` from the pivot, at `angle` from straight up (clockwise +), in the drawing's units.
func at(angle: float, distance: float) -> Vector2:
	return PIVOT + Vector2(sin(angle), -cos(angle)) * distance


## The plate's outline: along the outer edge left to right, then back along the inner edge.
func plate_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps := 24
	for i in steps + 1:
		points.append(at(lerpf(-MAX_ANGLE, MAX_ANGLE, float(i) / steps), PLATE_OUTER))
	for i in steps + 1:
		points.append(at(lerpf(MAX_ANGLE, -MAX_ANGLE, float(i) / steps), PLATE_INNER))
	return points


func _draw() -> void:
	var k := _k()
	var ink := grey(0)
	var paper := grey(255)
	draw_set_transform(size * 0.5, 0.0, Vector2(k, k))
	var black := press_flash_left > 0.0      # just touched: all of it black for a moment

	# 1. The plate: paper with an ink edge, the middle marked by a thin line (as in the sketch).
	var plate := plate_points()
	draw_colored_polygon(plate, ink if black else paper)
	var closed := plate.duplicate()
	closed.append(plate[0])
	draw_polyline(closed, ink, 1.6, true)
	draw_line(at(0.0, PLATE_INNER), at(0.0, PLATE_OUTER), ink, 0.8)

	# 2. The battery: a dotted track just inside the plate's inner edge, and over it an ink arc from the left as long
	#    as the battery left.
	var track := PLATE_INNER + 4.0
	for i in 21:
		draw_circle(at(lerpf(-MAX_ANGLE, MAX_ANGLE, i / 20.0), track), 0.5, grey(0, 0.6))
	var paddles := null if Engine.is_editor_hint() else _paddles()
	if paddles and paddles.push_left > 0.0:
		var share: float = paddles.push_left / paddles.push_time
		var arc := PackedVector2Array()
		for i in 25:
			arc.append(at(lerpf(-MAX_ANGLE, -MAX_ANGLE + share * 2.0 * MAX_ANGLE, i / 24.0), track))
		draw_polyline(arc, paper if black else ink, 3.0)

	# 3. The lever: a stem from the pivot, then the grip wound like a spring (an ink box with slanted stripes).
	var angle := lever * MAX_ANGLE
	draw_set_transform(size * 0.5 + PIVOT * k, angle, Vector2(k, k))   # now drawing in the lever's own frame (up = -y)
	draw_line(Vector2.ZERO, Vector2(0, -24.0), ink, 3.0)
	var grip := Rect2(-5.0, -LEVER_LENGTH, 10.0, LEVER_LENGTH - 22.0)
	draw_rect(grip, paper)
	var y := grip.position.y + 2.0
	while y < grip.end.y - 3.0:                   # the spring's coils: slanted lines across the grip
		draw_line(Vector2(-5.0, y + 3.0), Vector2(5.0, y), ink, 1.4)
		y += 4.0
	draw_rect(grip, ink, false, 1.6)
	# The knob on the pivot: an ink ring round paper with an ink dot.
	draw_circle(Vector2.ZERO, 7.0, ink)
	draw_circle(Vector2.ZERO, 4.8, paper)
	draw_circle(Vector2.ZERO, 1.8, ink)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

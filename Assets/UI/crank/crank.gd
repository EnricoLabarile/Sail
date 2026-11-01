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
## THE BATTERY (Enrico): a little battery icon, line art, inside the knob on the pivot; it stays level (it doesn't turn
## with the lever) and its fill shows the charge left. In the last recharge_window seconds (when the lever all the way
## right fills it again) it blinks.
## THE HINTS (Enrico): a little anchor beside the end that works the anchor now: LEFT while the anchor is up (all the
## way left drops it), RIGHT while she's at anchor or tied up (all the way right weighs it and starts her). Drifting with
## the battery empty, or while it's in its last seconds (blinking), also a little battery on the right (all the way right
## fills it).
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
@export var refill_show_time := 0.5    # seconds the battery icon takes to fill up when it's refilled (Enrico: seen filling, not at once)
@export var blink_per_second := 4.0     # the battery blinks this fast in its last seconds (when it can be filled again)

const MAX_ANGLE := deg_to_rad(45.0)     # how far the lever swings either way from upright
const PIVOT := Vector2(0.0, 26.0)       # the pivot, in the drawing's units (from the box's middle; y down)
const KNOB_R := 10.0                    # the knob on the pivot, with the battery inside it (Enrico)
const ICON_DISTANCE := 38.0             # the anchor / battery hints: this far from the pivot…
const ICON_PAST_END := 0.3              # …and this many radians past each end of the plate
const PLATE_INNER := 26.0               # the plate's inner and outer edge (distance from the pivot)
const PLATE_OUTER := 50.0
const LEVER_LENGTH := 56.0              # from the pivot to the grip's top
const NOTCHES := 16                     # clicks across the whole swing
const END := 0.98                       # how close to an end (of 1) counts as there

var lever := 0.0              # where it is: -1 all the way left, 0 the middle, +1 all the way right
var drag_index := -1          # the finger on it (-1 = none)
var last_a := 0.0             # the finger's angle round the pivot a moment ago
var shown_charge := 1.0      # the charge the battery icon shows (0..1): it follows the real one, filling up slowly
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
			# Every touch: a click; the lever is black while the finger holds it (Enrico: every button).
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
	update_shown_charge(dt)
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
	var held := drag_index != -1             # the finger on it: the lever (only the lever, Enrico) is drawn black

	# 1. The plate: paper with an ink edge, the middle marked by a thin line (as in the sketch).
	var plate := plate_points()
	draw_colored_polygon(plate, paper)
	var closed := plate.duplicate()
	closed.append(plate[0])
	draw_polyline(closed, ink, 1.6, true)
	draw_line(at(0.0, PLATE_INNER), at(0.0, PLATE_OUTER), ink, 0.8)

	# 3. The lever: a stem from the pivot, then the grip wound like a spring (an ink box with slanted stripes).
	var angle := lever * MAX_ANGLE
	draw_set_transform(size * 0.5 + PIVOT * k, angle, Vector2(k, k))   # now drawing in the lever's own frame (up = -y)
	#    Held: the grip turns ink and its stripes paper (the colours swapped), for as long as the finger is on it.
	draw_line(Vector2(0, -KNOB_R), Vector2(0, -24.0), ink, 3.0)
	var grip := Rect2(-5.0, -LEVER_LENGTH, 10.0, LEVER_LENGTH - 22.0)
	draw_rect(grip, ink if held else paper)
	var stripe_color := paper if held else ink
	var y := grip.position.y + 2.0
	while y < grip.end.y - 3.0:                   # the spring's coils: slanted lines across the grip
		draw_line(Vector2(-5.0, y + 3.0), Vector2(5.0, y), stripe_color, 1.4)
		y += 4.0
	draw_rect(grip, ink, false, 1.6)

	# 4. The knob on the pivot (not turned: the battery inside stays level): paper with an ink ring.
	draw_set_transform(size * 0.5 + PIVOT * k, 0.0, Vector2(k, k))
	draw_circle(Vector2.ZERO, KNOB_R, paper)
	draw_arc(Vector2.ZERO, KNOB_R, 0.0, TAU, 32, ink, 1.6)
	var paddles := null if Engine.is_editor_hint() else _paddles()
	var share := 1.0                                   # the charge shown, 0..1 (full in the editor)
	if paddles:
		share = shown_charge
	if not _battery_blinked_off(paddles):
		_draw_battery(Vector2.ZERO, 1.0, share, ink)

	# 5. The hints beside the ends (see the notes at the top).
	draw_set_transform(size * 0.5, 0.0, Vector2(k, k))
	var left_spot := at(-MAX_ANGLE - ICON_PAST_END, ICON_DISTANCE)
	var right_spot := at(MAX_ANGLE + ICON_PAST_END, ICON_DISTANCE)
	var boat := null if Engine.is_editor_hint() else get_tree().get_first_node_in_group("player_boat")
	# Each hint is drawn twice: first thicker in paper (a thin halo, so it reads on the dark sea too), then in ink.
	for pass_number in 2:
		var color := paper if pass_number == 0 else ink
		var extra := 2.0 if pass_number == 0 else 0.0
		if boat == null or not boat.anchored:
			_draw_anchor(left_spot, color, extra)                    # anchor up: all the way left drops it
			# The battery can be filled now (its last seconds, while the knob's blinks, or empty, drifting): a little
			# battery on the right says "all the way right fills it".
			if paddles and paddles.can_wind():
				_draw_battery(right_spot, 0.7, 0.0, color, extra)
		else:
			_draw_anchor(right_spot, color, extra)                   # at anchor / tied up: all the way right weighs it
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The charge the icon shows: when the battery is filled (lever all the way right, a booster) it climbs to the new
## charge over refill_show_time seconds, so the player sees it filling; going down it just follows.
func update_shown_charge(dt: float) -> void:
	var paddles := _paddles()
	if paddles == null:
		return
	var real: float = paddles.push_left / paddles.push_time
	if real > shown_charge and refill_show_time > 0.0:
		shown_charge = move_toward(shown_charge, real, dt / refill_show_time)
	else:
		shown_charge = real


## Is the battery in its blink's "off" moment? Only in the last seconds of a running battery.
func _battery_blinked_off(paddles: Node) -> bool:
	if paddles == null or not paddles.is_running() or not paddles.can_wind():
		return false
	var phase := fmod(Time.get_ticks_msec() / 1000.0 * blink_per_second, 1.0)
	return phase > 0.5


## A battery, line art like a phone's: a box with a little knob on its right and a fill inside as long as `share`
## (0..1). `size_k` scales it (1 = the one in the knob, 12 units wide).
## `extra` makes its lines that much thicker (for the paper halo).
func _draw_battery(middle: Vector2, size_k: float, share: float, color: Color, extra := 0.0) -> void:
	var body := Rect2(middle + Vector2(-6.5, -3.5) * size_k, Vector2(12.0, 7.0) * size_k)
	draw_rect(body, color, false, 1.2 + extra)
	var knob := Rect2(middle + Vector2(5.5, -1.5) * size_k, Vector2(1.5, 3.0) * size_k)
	draw_rect(knob.grow(extra * 0.5), color)                                                # the little knob
	if share > 0.0:
		var inner := body.grow(-1.8 * size_k)
		inner.size.x *= clampf(share, 0.0, 1.0)
		draw_rect(inner, color)


## An anchor, line art: a ring at the top, the shank, the stock across, and the two curved arms with their points.
## `extra` makes its lines that much thicker (for the paper halo).
func _draw_anchor(middle: Vector2, color: Color, extra := 0.0) -> void:
	var w := 1.2 + extra
	draw_arc(middle + Vector2(0, -5.0), 1.4, 0.0, TAU, 12, color, w)                       # the ring
	draw_line(middle + Vector2(0, -3.6), middle + Vector2(0, 5.5), color, w)               # the shank
	draw_line(middle + Vector2(-3.0, -2.0), middle + Vector2(3.0, -2.0), color, w)         # the stock
	var arm := PackedVector2Array()
	for i in 13:                                                                            # the arms: half a circle under it
		var a := PI * i / 12.0
		arm.append(middle + Vector2(cos(a) * 4.5, 1.5 + sin(a) * 4.0))
	draw_polyline(arm, color, w)
	draw_line(middle + Vector2(4.5, 1.5), middle + Vector2(5.5, 0.2), color, w)            # the points
	draw_line(middle + Vector2(-4.5, 1.5), middle + Vector2(-5.5, 0.2), color, w)

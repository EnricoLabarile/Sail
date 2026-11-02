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
##     again (paddles.refill). The lever stays where the finger holds it (100%). Only with a grab that BEGAN in those
##     last seconds (Enrico): held at 100% from before, the player must let go and push it right again.
##   - ALL THE WAY LEFT, while the anchor is up: she TURNS OFF: the anchor goes down (paddles.turn_off). Then the
##     lever springs back to the middle.
## An end works once each time the lever gets there: to use it again, the lever must leave it first.
## The battery runs down faster the faster the lever lets her go (paddles.gd drain_rate).
##
## THE BATTERY (Enrico, Nov 2026): the charge left is an ink filling inside the plate, from its left end: full = the
## whole plate inked, half = up to the middle. (The battery icon in the knob, its blinking and the moving dashes are gone.)
##   - Pushed past the middle (she goes faster, so the battery runs down faster): the filling carries paper chevrons
##     "<" (zig-zags, like Enrico's pattern turned a quarter left) flowing leftwards, quicker the faster it drains.
##   - When it can be filled again (its last seconds, or empty, with the anchor up): a circular arrow in the knob that
##     turns clockwise in short loops: "push it round to the right".
##   - Refilled: the filling climbs back over refill_show_time, and meanwhile the knob has its colours swapped and the
##     chevrons turn ">" and flow rightwards (Enrico: the battery is filling up).
## THE HINTS (Enrico): a little anchor beside the end that works the anchor now: LEFT while the anchor is up (all the
## way left drops it), RIGHT while she's at anchor or tied up (all the way right weighs it and starts her).
## Its sounds (Enrico): a light click every notch (NOTCHES across the plate), higher toward the right
## (Sfx.crank_click); a firm snap at an end that turns her on, off or fills the battery (Sfx.lever_done, with the
## anchor's own sound); the unlock sound the moment the battery can be filled again (Sfx.crank_unlock).
##
## Drawn with code, in greys, like the wheel: its CanvasLayer (crank.tscn) sits UNDER the dither, so it comes out in
## paper-and-ink dots. The drawing is in its own units (a 72 x 72 box round the Control's middle), scaled to this
## Control's size: the plate (a ring segment), the lever (a striped grip, like a spring) and the pivot's knob.
## @tool: drawn in the editor too, so you can place and size it (its place and size are this Control's in crank.tscn).
## (In Unreal: a UMG widget with its own OnPaint and touch handling.)

## The spring inside (Enrico): let go, the lever is pulled back to the middle like a real spring, overshoots it a
## little and wiggles to a stop. Stiffness = how hard the spring pulls (more = quicker and faster wiggles);
## damping = how quickly the wiggle dies out (less = more wiggles, more = it just settles). With 80 and 7 it reaches
## the middle in ~0.2 s from an end, swings about a quarter past it and settles after two or three wiggles.
## (Keep the damping above ~5: with less, the swing past the middle could reach the left end.)
@export var spring_stiffness := 80.0
@export var spring_damping := 7.0
@export var refill_show_time := 0.5    # seconds the filling takes to climb back when it's refilled (Enrico: seen filling, not at once)
# The chevrons flowing left in the filling while she goes faster than the middle (the battery drains faster):
@export var chevron_count := 7          # how many chevrons across the whole plate
@export var chevron_teeth := 3          # how many points each chevron column has, from the inner edge to the outer
@export var chevron_speed := 5        # chevrons going by a second at full speed (slower just past the middle)
@export var refill_chevron_speed := 5 # while it refills, the chevrons turn ">" and flow rightwards this fast (a second)
# The circular arrow in the knob when the battery can be filled:
@export var arrow_turn_deg := 100.0     # how far it turns in one loop (then it starts again)
@export var arrow_loop_time := 2.0      # seconds a loop takes

const MAX_ANGLE := deg_to_rad(45.0)     # how far the lever swings either way from upright
const PIVOT := Vector2(0.0, 26.0)       # the pivot, in the drawing's units (from the box's middle; y down)
const KNOB_R := 10.0                    # the knob on the pivot (the circular arrow shows inside it)
const ICON_DISTANCE := 38.0             # the anchor hints: this far from the pivot…
const ICON_PAST_END := 0.3              # …and this many radians past each end of the plate
const PLATE_INNER := 26.0               # the plate's inner and outer edge (distance from the pivot)
const PLATE_OUTER := 50.0
const LEVER_LENGTH := 56.0              # from the pivot to the grip's top
const NOTCHES := 16                     # clicks across the whole swing
const END := 0.98                       # how close to an end (of 1) counts as there

var lever_speed := 0.0       # how fast the lever is swinging on its spring (half-swings a second; only after letting go)
var lever := 0.0              # where it is: -1 all the way left, 0 the middle, +1 all the way right
var drag_index := -1          # the finger on it (-1 = none)
var last_a := 0.0             # the finger's angle round the pivot a moment ago
var shown_charge := 1.0      # the charge the filling shows (0..1): it follows the real one, climbing slowly when refilled
var filling := false         # is the filling climbing now? (then the knob is drawn with its colours swapped)
var notch := NOTCHES / 2      # the notch it's at (for the clicks)
var at_left_end := false      # is it at an end now? (an end works once each time the lever gets there)
var at_right_end := false
## Was the lever grabbed after the battery's last seconds began? (Enrico: to refill it the player must let go and push it
## all the way right again; holding it at 100% from before isn't enough, nor is a finger wobbling at the end.)
var grabbed_in_window := false
var held_time := 0.0         # seconds the finger has held it since the grab (or since the last refill): for paddles.boost_wait
var was_free := true          # could the battery be filled a frame ago? (to hear the moment it can)
var chevron_shift := 0.0      # how far the chevrons have flowed left (in plate shares; it grows while she boosts)
var arrow_time := 0.0         # the circular arrow's clock (seconds)


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
			lever_speed = 0.0               # the finger stops the spring's swing
			held_time = 0.0                 # the boost's wait starts again
			last_a = _angle_round_pivot(e.position)
			var paddles := _paddles()
			grabbed_in_window = paddles != null and paddles.is_running() and paddles.can_wind()
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
			elif paddles.can_wind() and grabbed_in_window:
				# Running, battery nearly out, and this grab began in its last seconds: full again; she keeps the 100%.
				paddles.refill()
				held_time = 0.0             # just refilled: holding it here doesn't drain faster until boost_wait has passed
				Sfx.lever_done()
				grabbed_in_window = false   # once per grab
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
	arrow_time += dt
	var paddles_now := _paddles()
	if filling:
		# Refilling (Enrico): the chevrons flow rightwards instead, the battery is filling up.
		chevron_shift -= dt * refill_chevron_speed / chevron_count
	elif paddles_now and paddles_now.lever_share > 0.5 and paddles_now.boost_counts:
		# Boosting: the chevrons flow left, quicker the further past the middle (0 at the middle, full at the right end).
		var boost: float = (paddles_now.lever_share - 0.5) / 0.5
		chevron_shift += dt * chevron_speed * boost / chevron_count
	# Let go: the spring takes it back to the middle, overshoots and wiggles to a stop (Enrico), clicking each notch it
	# passes, as when dragged. A spring with damping: the pull toward the middle grows with the distance from it, the
	# damping brakes the swing; the speed changes by the two, then the lever moves by the speed.
	if drag_index == -1 and (lever != 0.0 or lever_speed != 0.0):
		var pull := -spring_stiffness * lever - spring_damping * lever_speed
		lever_speed += pull * dt
		lever = clampf(lever + lever_speed * dt, -1.0, 1.0)
		if absf(lever) < 0.002 and absf(lever_speed) < 0.02:
			lever = 0.0                     # still enough: it rests in the middle
			lever_speed = 0.0
		click_notches()
		check_ends()                        # (only to notice it has left an end)
	var paddles := _paddles()
	if paddles:
		# The most she may go: 0% all the way left, 50% in the middle, 100% all the way right.
		paddles.set_lever_share(0.5 + 0.5 * lever)
		# The boost drains more only while the finger holds it and has held it boost_wait seconds (since the grab or the
		# last refill); let go, the drain is normal at once, while her speed eases down with the lever.
		if drag_index != -1:
			held_time += dt
		paddles.boost_counts = drag_index != -1 and held_time >= paddles.boost_wait
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
## With `upto` < 1 only the part from the left end to that share of the plate (the battery's filling).
func plate_points(upto := 1.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps := 24
	var right_edge := lerpf(-MAX_ANGLE, MAX_ANGLE, clampf(upto, 0.0, 1.0))
	for i in steps + 1:
		points.append(at(lerpf(-MAX_ANGLE, right_edge, float(i) / steps), PLATE_OUTER))
	for i in steps + 1:
		points.append(at(lerpf(right_edge, -MAX_ANGLE, float(i) / steps), PLATE_INNER))
	return points


func _draw() -> void:
	var k := _k()
	var ink := grey(0)
	var paper := grey(255)
	draw_set_transform(size * 0.5, 0.0, Vector2(k, k))
	var held := drag_index != -1             # the finger on it: the lever (only the lever, Enrico) is drawn black

	var paddles := null if Engine.is_editor_hint() else _paddles()
	var boat := null if Engine.is_editor_hint() else get_tree().get_first_node_in_group("player_boat")
	var share := 1.0                                   # the charge shown, 0..1 (full in the editor)
	if paddles:
		share = shown_charge

	# 1. The plate: paper, then the charge as an ink filling from its left end.
	var plate := plate_points()
	draw_colored_polygon(plate, paper)
	if share > 0.005:
		draw_colored_polygon(plate_points(share), ink)
		# Refilling: paper chevrons ">" flowing rightwards inside the filling. Boosting (past the middle): "<" leftwards.
		if filling:
			_draw_chevrons(share, paper, 1.0)
		elif paddles and paddles.lever_share > 0.5 and paddles.is_running():
			_draw_chevrons(share, paper, -1.0)
	#    Its ink edge on top, and the middle marked by a thin line (as in the sketch).
	var closed := plate.duplicate()
	closed.append(plate[0])
	draw_polyline(closed, ink, 1.6, true)
	draw_line(at(0.0, PLATE_INNER), at(0.0, PLATE_OUTER), paper if share > 0.5 else ink, 0.8)

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
	#    While it's filling up (Enrico: to make the recharge stand out), the whole knob has its colours swapped: an ink
	#    disc and the battery in paper; back to normal once it's full.
	var knob_fill := ink if filling else paper
	var knob_mark := paper if filling else ink
	draw_circle(Vector2.ZERO, KNOB_R, knob_fill)
	draw_arc(Vector2.ZERO, KNOB_R, 0.0, TAU, 32, knob_mark, 1.6)   # its ring swaps too (so it reads on the dark sea)
	#    The battery can be filled now (its last seconds, or empty) with the anchor up: the circular arrow.
	if paddles and paddles.can_wind() and boat and not boat.anchored:
		_draw_turning_arrow(knob_mark)

	# 5. The hints beside the ends (see the notes at the top).
	draw_set_transform(size * 0.5, 0.0, Vector2(k, k))
	var left_spot := at(-MAX_ANGLE - ICON_PAST_END, ICON_DISTANCE)
	var right_spot := at(MAX_ANGLE + ICON_PAST_END, ICON_DISTANCE)
	# Each hint is drawn twice: first thicker in paper (a thin halo, so it reads on the dark sea too), then in ink.
	for pass_number in 2:
		var color := paper if pass_number == 0 else ink
		var extra := 2.0 if pass_number == 0 else 0.0
		if boat == null or not boat.anchored:
			_draw_anchor(left_spot, color, extra)                    # anchor up: all the way left drops it
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
		filling = shown_charge < real            # still climbing (false the frame it gets there)
	else:
		shown_charge = real
		filling = false


## The chevrons: columns of zig-zags (each one a "<", its points facing left) standing across the plate inside the
## filling (from its left end to `share`), sliding leftwards by chevron_shift: a column leaving the left end comes back
## at the right one. Drawn in `color` (paper, over the ink filling). `facing` -1 = points to the left "<" (boosting),
## +1 = points to the right ">" (refilling: then chevron_shift goes down, so they slide right).
func _draw_chevrons(share: float, color: Color, facing: float) -> void:
	var step := 1.0 / chevron_count                     # the gap between two columns, as a share of the plate's width
	var depth := step * 0.35 * facing                   # how far each point reaches out (left if negative)
	var first := fposmod(-chevron_shift, step)          # where the first column stands now (it slides left, then loops)
	var x := first
	while x <= share:
		if x + minf(depth, 0.0) >= 0.0 and x + maxf(depth, 0.0) <= share:   # the whole column inside the filling
			var points := PackedVector2Array()
			var rows := chevron_teeth * 2
			for i in rows + 1:
				var radius := lerpf(PLATE_INNER + 3.0, PLATE_OUTER - 3.0, float(i) / rows)
				var along := x + depth if i % 2 == 1 else x     # every other point juts out (left or right)
				points.append(at(lerpf(-MAX_ANGLE, MAX_ANGLE, along), radius))
			draw_polyline(points, color, 1.6)
		x += step


## The circular arrow in the knob: three quarters of a ring with an arrowhead, turning clockwise by arrow_turn_deg
## over arrow_loop_time (quick at first, slowing), then starting again: "turn it to the right".
func _draw_turning_arrow(color: Color) -> void:
	var loop := fmod(arrow_time / arrow_loop_time, 1.0)
	var eased := 1.0 - (1.0 - loop) * (1.0 - loop)
	var turn := deg_to_rad(arrow_turn_deg) * eased
	var radius := KNOB_R * 0.55
	var start := -PI * 0.5 + turn                        # angles: 0 = right, growing clockwise (the screen's y is down)
	var finish := start + PI * 1.5
	draw_arc(Vector2.ZERO, radius, start, finish, 24, color, 1.6)
	# The arrowhead at the end of the arc, pointing the way it turns (clockwise).
	var tip := Vector2(cos(finish), sin(finish)) * radius
	var ahead := Vector2(-sin(finish), cos(finish))      # the way the arc goes on, at its end
	var outward := Vector2(cos(finish), sin(finish))
	var head := PackedVector2Array([tip + ahead * 3.0, tip - ahead * 0.5 + outward * 2.4, tip - ahead * 0.5 - outward * 2.4])
	draw_colored_polygon(head, color)


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

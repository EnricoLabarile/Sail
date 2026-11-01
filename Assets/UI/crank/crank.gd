@tool
extends Control
## THE CRANK (up and to the left of the wheel), as in the HTML prototype's wound spring: it works the paddle wheels
## (Assets/Boat/paddles.gd). Turn it clockwise with a finger: ONE FULL TURN winds the paddles and they push the boat
## for a while (paddles.gd push_time). Let go before the turn is complete and the arm springs back, nothing wound.
## Turned ANTICLOCKWISE it's the BRAKE (Enrico): the further back the arm is held, the harder she brakes (a quarter
## turn back = a quarter of the brake, paddles.gd set_brake); the push left is cancelled. A WHOLE TURN back works the
## ANCHOR, exactly like the wheel's hub (boat.gd toggle_anchor): sailing, it drops it (so she stops); at anchor, it
## weighs it. Let go, the arm springs back to the top and the brake ends.
## While the paddles push, winding (clockwise) is LOCKED, except in the last seconds of the push (paddles.gd
## recharge_window, Enrico): then it can be wound again, so the push never runs out if you keep it up. The crank can
## always be touched (to brake); clockwise turns while it's locked just do nothing.
## The ring round the plate shows the push left.
## Its sounds (Enrico): a clack for each of the gear's 16 teeth as it's wound, each a little higher, an octave up by
## the end of the turn (Sfx.crank_click); and a snappy mechanical unlock the moment it can be wound again
## (Sfx.crank_unlock). It shows only while the paddles are on (the logbook).
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

const TEETH := 16   # the gear's teeth: a clack each as it's wound

var crank_angle := 0.0        # the arm's angle (radians, 0 = pointing up, clockwise +; braking turns it below 0)
var wound_so_far := 0.0       # how far this turn has got (radians, 0..TAU): at TAU the paddles are wound
var drag_index := -1          # the finger on it (-1 = none)
var last_a := 0.0             # the finger's angle round the middle a moment ago
var press_flash_left := 0.0   # seconds it stays black after a touch
var teeth_clicked := 0        # teeth of this turn already clacked (0..TEETH)
var was_free := true          # could it be wound a frame ago? (to hear the moment it unlocks)


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
		teeth_clicked = 0
	was_free = _can_wind()        # shown again: no unlock sound for the state it's already in


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
			drag_index = e.index            # always: clockwise winds (when it can), anticlockwise brakes
			last_a = (e.position - c).angle()
			accept_event()
		elif not e.pressed and e.index == drag_index:
			drag_index = -1                 # let go: if the turn isn't complete, _process springs it back
			accept_event()
	elif e is InputEventScreenDrag and e.index == drag_index:
		var a: float = (e.position - c).angle()
		var turned := wrapf(a - last_a, -PI, PI)   # how far the finger went round since last time
		last_a = a
		# On screen, clockwise is a growing angle. A huge jump is a glitch: ignored.
		if turned > 0.0 and turned < 1.5:
			wind(turned)                    # clockwise: winding (only while it can be wound)
		elif turned < 0.0 and turned > -1.5:
			brake(turned)                   # anticlockwise: the brake
		accept_event()


## Clockwise: winds the paddles, if it can be wound now (else the ratchet holds and nothing moves). Coming back from
## braking (the arm below the top), it first just turns back up to the top.
func wind(turned: float) -> void:
	if crank_angle < 0.0:
		crank_angle = minf(0.0, crank_angle + turned)
		queue_redraw()
		return
	if not _can_wind():
		return
	wound_so_far += turned
	crank_angle = wound_so_far
	click_teeth()
	if wound_so_far >= TAU:
		_full_turn()
	queue_redraw()


## Anticlockwise: the arm follows the finger backward (a turn that was being wound is lost). How far back it is sets the
## brake (_process sends it every frame). A whole turn back: the anchor (_full_turn_back).
func brake(turned: float) -> void:
	wound_so_far = 0.0
	teeth_clicked = 0
	crank_angle += turned                   # the arm goes back with the finger (below 0)
	if crank_angle <= -TAU:
		_full_turn_back()
	queue_redraw()


## A whole turn back: the anchor goes down (or comes up if she's at anchor), as with the wheel's hub. The arm is back up
## and the finger must come off and start again.
func _full_turn_back() -> void:
	var boat := get_tree().get_first_node_in_group("player_boat")
	if boat:
		boat.toggle_anchor()
	crank_angle = 0.0
	drag_index = -1


## A clack for every tooth the arm has gone past since the last one (a quick finger can pass two in a frame),
## each higher than the one before: tooth n of 16 at 2^(n/16), so the 16th, at the full turn, is an octave up.
func click_teeth() -> void:
	var teeth_now := mini(TEETH, int(wound_so_far / (TAU / TEETH)))
	while teeth_clicked < teeth_now:
		teeth_clicked += 1
		Sfx.crank_click(teeth_clicked, TEETH)


## A full turn: the paddles are wound, and the arm is back up, ready for the next turn.
func _full_turn() -> void:
	var paddles := _paddles()
	if paddles:
		paddles.wound()
	wound_so_far = 0.0
	crank_angle = 0.0
	teeth_clicked = 0
	was_free = false                        # now locked: the unlock sound comes when it's free again
	drag_index = -1                         # the finger must come off and start a new turn


func _process(dt: float) -> void:
	if Engine.is_editor_hint() or not visible:
		return
	if press_flash_left > 0.0:
		press_flash_left = maxf(0.0, press_flash_left - dt)
	# Let go: the arm springs back to the top (from a half wound turn, nothing is wound; from braking, the brake ends).
	if drag_index == -1 and crank_angle != 0.0:
		crank_angle = move_toward(crank_angle, 0.0, spring_back_speed * dt)
		wound_so_far = maxf(0.0, crank_angle)
		teeth_clicked = 0                   # the next turn starts low again (springing back is silent)
	# The brake: as hard as the arm is held back (0 = at the top, 1 = a whole turn back); none once it's let go.
	var paddles := _paddles()
	if paddles:
		var back := 0.0
		if drag_index != -1 and crank_angle < 0.0:
			back = -crank_angle / TAU
		paddles.set_brake(back)
	# The moment it can be wound again (the last seconds of the push, or the push over): the unlock sound, once.
	var free := _can_wind()
	if free and not was_free:
		Sfx.crank_unlock()
	was_free = free
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
	var fade := 1.0                         # never pale now (Enrico): it can always be touched, to brake
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

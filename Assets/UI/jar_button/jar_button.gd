@tool
extends Control
## THE AEOLUS JAR BUTTON (bottom right, under the bomb button): a round paper button with the jar on it.
## The Aeolus Jar (Enrico) is a consumable: a tap uncorks one and the wind turns to blow from right behind her
## sail, the way her bow points now (Wind.turn_to). It then stays like that, as any wind does, until she uncorks
## another jar or crosses a wind zone. One jar out of the hold each time.
## It shows only while a jar is equipped and at least one is aboard (Inventory.equipped_wind: the jar has its own
## equip slot, "wind", so it's equipped alongside a bomb or a trap; jars coming aboard are equipped by themselves).
## After each jar the button rests for `cooldown` seconds (Enrico: long, at least 30): taps do nothing, and a
## see-through ink pie of the wait still left shrinks clockwise from the top, as the bomb button's.
## Drawn with code under the dither (CanvasLayer 95, like the wheel), so it's 1-bit.
## @tool: drawn in the editor too (always shown there), so you can place and size it; there it only draws.
## (In Unreal: a UMG button whose OnClicked sets a value in the wind's subsystem, with a cooldown timer.)

const JAR := "aeolus_jar"            # the item's id (Assets/Inventory/items/aeolus_jar.tres)
const ICON := preload("res://Assets/Inventory/icons/aeolus_jar.png")
const PAPER := Color("ebe7dc")
const INK := Color("1b1a17")

@export var cooldown := 30.0         # seconds after a jar before the next one can be uncorked
@export var turn_time := 1.5         # seconds the wind takes to swing round behind her

@export var press_flash := 0.12      # a press turns the button black for this long (s), with a click (Enrico: every button)

var press_flash_left := 0.0          # seconds it stays black after a press (any press, even while it rests)
var pressed_time := 0.0              # > 0 for a moment after a tap: the button is drawn pushed in
var cooldown_left := 0.0             # seconds before another jar can be uncorked (0 = ready)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	Inventory.equipped_changed.connect(_update_shown)   # equipped or unequipped
	Inventory.changed.connect(_update_shown)            # jars coming aboard or going out
	_update_shown()


## Shown only while a jar is equipped AND there's at least one aboard (a hidden Control gets no taps, so hiding
## it also switches it off).
func _update_shown() -> void:
	visible = Inventory.equipped_wind == JAR and Inventory.count(JAR) > 0


func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	# A finger coming down on it (on the PC the mouse counts as a finger: emulate_touch_from_mouse).
	if event is InputEventScreenTouch and event.pressed:
		# Every press: a low click and the button black for a moment (Enrico: so she sees it was pressed),
		# whether it does something or not (still resting after the last one).
		press_flash_left = press_flash
		Sfx.button_press()
		queue_redraw()
		uncork_jar()
		accept_event()                # the tap stops here (it doesn't also reach the wheel or the sea)


func _process(dt: float) -> void:
	if Engine.is_editor_hint():
		return
	if pressed_time > 0.0:
		pressed_time = maxf(0.0, pressed_time - dt)
		queue_redraw()
	if press_flash_left > 0.0:
		press_flash_left = maxf(0.0, press_flash_left - dt)
		queue_redraw()                    # once it runs out, it's drawn as usual again
	# The cooldown counts down, and the pie is drawn again every frame meanwhile (it shrinks).
	if cooldown_left > 0.0:
		cooldown_left = maxf(0.0, cooldown_left - dt)
		queue_redraw()


## One jar out of the hold, and the wind swings round to blow from right astern.
func uncork_jar() -> void:
	var boat := get_tree().get_first_node_in_group("player_boat") as Node3D
	if boat == null or boat.sinking:
		return
	if cooldown_left > 0.0:
		return                            # still resting after the last jar
	if not Inventory.remove(JAR):
		return
	# Which way her bow points, as a compass angle (0 = north, 90 = east): her -Z is the way the bow points,
	# and in Godot's 3D north is -Z and east is +X, so the angle is atan2(east part, north part).
	var ahead: Vector3 = -boat.global_transform.basis.z
	var bow_deg := rad_to_deg(atan2(ahead.x, -ahead.z))
	# The wind must blow the way she's heading, so it comes FROM right behind her: half a turn round.
	Wind.turn_to(bow_deg + 180.0, turn_time)
	pressed_time = 0.15
	cooldown_left = cooldown
	queue_redraw()


## A paper disc with an ink rim and the jar's picture; pushed in (smaller) for a moment after a tap.
func _draw() -> void:
	var middle := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 3.0
	if pressed_time > 0.0:
		radius *= 0.9
	draw_circle(middle + Vector2(3, 3), radius, INK)           # a hard shadow, as the bomb button's
	draw_circle(middle, radius, PAPER)
	draw_arc(middle, radius, 0.0, TAU, 48, INK, 3.0)
	var icon_size := ICON.get_size() * (radius * 1.1 / ICON.get_size().y)
	draw_texture_rect(ICON, Rect2(middle - icon_size * 0.5, icon_size), false)
	# Just pressed: the whole button black (as the wheel's hub does).
	if press_flash_left > 0.0:
		draw_circle(middle, radius, INK)
		return
	# Resting after a jar: the pie of what's left of the wait, in see-through ink (the dither turns it to dots).
	if cooldown_left > 0.0:
		_draw_pie(middle, radius, cooldown_left / cooldown)


## A pie slice in see-through ink: `share` of the circle (1 = all of it, 0 = nothing), starting at the top and
## going clockwise. It's a fan: the middle, then points round the edge from the top to where the slice ends.
func _draw_pie(middle: Vector2, radius: float, share: float) -> void:
	var points := PackedVector2Array([middle])
	var steps := maxi(2, int(48 * share))            # more points for a bigger slice, so the edge stays round
	for i in steps + 1:
		var angle := TAU * share * i / steps          # 0 = the top, growing clockwise
		points.append(middle + Vector2(sin(angle), -cos(angle)) * radius)
	draw_colored_polygon(points, Color(INK, 0.5))

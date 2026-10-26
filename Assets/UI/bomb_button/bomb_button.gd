@tool
extends Control
## THE BOMB BUTTON (bottom right, where the slingshot was): a round paper button with the bomb on it. It shows
## only while a bomb is equipped (tap the bombs' slot in the logbook: Inventory.equipped). A tap drops a bomb
## off the boat's bow (Enrico; Assets/Items/bomb/bomb.tscn) and takes one out of the hold; when the last one goes,
## nothing is equipped any more and the button hides.
## After each bomb the button rests for `cooldown` seconds (Enrico): taps do nothing, and a see-through ink pie
## covers the share of the wait still left, shrinking clockwise from the top until it's gone (like a cooldown in
## any action game).
## Drawn with code under the dither (CanvasLayer 95, like the wheel), so it's 1-bit.
## @tool: drawn in the editor too (always shown there), so you can place and size it; there it only draws.

const BOMB_SCENE := preload("res://Assets/Items/bomb/bomb.tscn")
const ICON := preload("res://Assets/Inventory/icons/bomb.png")
const PAPER := Color("ebe7dc")
const INK := Color("1b1a17")

@export var bow_offset := 2.2        # metres ahead of the boat's middle the bomb is dropped (about her bow)
@export var cooldown := 2.0          # seconds after a bomb before the next one can be dropped

var pressed_time := 0.0              # > 0 for a moment after a tap: the button is drawn pushed in
var cooldown_left := 0.0             # seconds before it can drop another bomb (0 = ready)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	Inventory.equipped_changed.connect(_update_shown)
	_update_shown()


## Shown only while a bomb is equipped.
func _update_shown() -> void:
	visible = Inventory.equipped == "bomb"


func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	# A finger coming down on it (on the PC the mouse counts as a finger: emulate_touch_from_mouse).
	if event is InputEventScreenTouch and event.pressed:
		drop_bomb()
		accept_event()                # the tap stops here (it doesn't also reach the wheel or the sea)


func _process(dt: float) -> void:
	if Engine.is_editor_hint():
		return
	if pressed_time > 0.0:
		pressed_time = maxf(0.0, pressed_time - dt)
		queue_redraw()
	# The cooldown counts down, and the pie is drawn again every frame meanwhile (it shrinks).
	if cooldown_left > 0.0:
		cooldown_left = maxf(0.0, cooldown_left - dt)
		queue_redraw()


## A bomb off the bow, one out of the hold.
func drop_bomb() -> void:
	var boat := get_tree().get_first_node_in_group("player_boat") as Node3D
	if boat == null or boat.sinking:
		return
	if cooldown_left > 0.0:
		return                            # still resting after the last bomb
	if not Inventory.remove("bomb"):
		return
	var bomb := BOMB_SCENE.instantiate()
	boat.get_parent().add_child(bomb)        # into the world, not onto the boat (it stays where it fell)
	var ahead: Vector3 = -boat.global_transform.basis.z   # the boat's -Z is the way her bow points
	ahead.y = 0.0
	bomb.global_position = boat.global_position + ahead.normalized() * bow_offset
	bomb.global_position.y = 0.0
	pressed_time = 0.15
	cooldown_left = cooldown
	queue_redraw()


## A paper disc with an ink rim and the bomb's picture; pushed in (smaller) for a moment after a tap.
func _draw() -> void:
	var middle := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 3.0
	if pressed_time > 0.0:
		radius *= 0.9
	draw_circle(middle + Vector2(3, 3), radius, INK)           # a hard shadow, as the hearts' panel
	draw_circle(middle, radius, PAPER)
	draw_arc(middle, radius, 0.0, TAU, 48, INK, 3.0)
	var icon_size := ICON.get_size() * (radius * 1.1 / ICON.get_size().y)
	draw_texture_rect(ICON, Rect2(middle - icon_size * 0.5, icon_size), false)
	# Resting after a bomb: the pie of what's left of the wait, in see-through ink (the dither turns it to dots).
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

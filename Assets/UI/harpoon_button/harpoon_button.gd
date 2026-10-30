@tool
extends Control
## THE HARPOON BUTTON (bottom right, in the Aeolus Jar's place: the harpoon goes in the same equip slot, "wind",
## as an alternative to the jar, so only one of the two buttons ever shows). A round paper button with the harpoon.
## A tap shoots one harpoon (harpoon.tscn) from her bow, straight ahead; it hooks what it meets and pulls it to her
## (see harpoon.gd). Harpoons are spent: one out of the hold each shot (Enrico: like bombs and jars, bought again).
## One at a time: while it's out, taps do nothing; after each shot the button rests `cooldown` seconds (the ink pie).
## It shows only while a harpoon is equipped and at least one is aboard.
## Drawn with code under the dither (CanvasLayer 95, like the wheel), so it's 1-bit.
## @tool: drawn in the editor too (always shown there), so you can place and size it; there it only draws.
## (In Unreal: a UMG button whose OnClicked spawns the harpoon actor at the bow.)

const HARPOON := "harpoon"           # the item's id (Assets/Inventory/items/harpoon.tres)
const HARPOON_SCENE := preload("res://Assets/Items/harpoon/harpoon.tscn")
const ICON := preload("res://Assets/Inventory/icons/harpoon.png")
const PAPER := Color("ebe7dc")
const INK := Color("1b1a17")

@export var cooldown := 1.0          # seconds after a shot before the next one (and never while one is out)

@export var press_flash := 0.12      # a press turns the button black for this long (s), with a click (Enrico: every button)

var press_flash_left := 0.0          # seconds it stays black after a press (any press, even while it rests)
var pressed_time := 0.0              # > 0 for a moment after a tap: the button is drawn pushed in
var cooldown_left := 0.0             # seconds before another harpoon can be shot (0 = ready)
var harpoon_out: Node3D = null       # the harpoon flying now (null = none)

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	Inventory.equipped_changed.connect(_update_shown)   # equipped or unequipped
	Inventory.changed.connect(_update_shown)            # harpoons coming aboard or going out
	_update_shown()


## Shown only while a harpoon is equipped AND there's at least one aboard (a hidden Control gets no taps, so hiding
## it also switches it off).
func _update_shown() -> void:
	visible = Inventory.equipped_wind == HARPOON and Inventory.count(HARPOON) > 0


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
		shoot_harpoon()
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


## One harpoon out of the hold, shot from her bow.
func shoot_harpoon() -> void:
	var boat := get_tree().get_first_node_in_group("player_boat") as Node3D
	if boat == null or boat.sinking or boat.emerging:
		return
	if cooldown_left > 0.0 or is_instance_valid(harpoon_out):
		return                            # still resting, or the last one is still out
	if not Inventory.remove(HARPOON):
		return
	harpoon_out = HARPOON_SCENE.instantiate()
	boat.get_parent().add_child(harpoon_out)   # into the level, next to the boat (it flies on its own)
	harpoon_out.launch(boat)
	pressed_time = 0.15
	cooldown_left = cooldown
	queue_redraw()


## A paper disc with an ink rim and the harpoon's picture; pushed in (smaller) for a moment after a tap.
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
	# Resting after a shot: the pie of what's left of the wait, in see-through ink (the dither turns it to dots).
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

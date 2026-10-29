@tool
extends Control
## THE BOMB BUTTON (bottom right, where the slingshot was): a round paper button with the bomb on it. It shows
## only while a bomb is equipped (tap the bombs' slot in the logbook: Inventory.equipped). A tap drops a bomb
## off the boat's bow (Enrico; Assets/Items/bomb/bomb.tscn) and takes one out of the hold; when the last one goes,
## nothing is equipped any more and the button hides.
## After each bomb the button rests for `cooldown` seconds (Enrico): taps do nothing, and a see-through ink pie
## covers the share of the wait still left, shrinking clockwise from the top until it's gone (like a cooldown in
## any action game).
## When a bomb is equipped (Enrico): two rings pulse out round the button, quickly (equip_anim_time, under a
## second), and a snappy click-clack plays, like a gun being loaded (Sfx.equip_bomb).
## Drawn with code under the dither (CanvasLayer 95, like the wheel), so it's 1-bit.
## @tool: drawn in the editor too (always shown there), so you can place and size it; there it only draws.

const BOMB_SCENE := preload("res://Assets/Items/bomb/bomb.tscn")
const ICON := preload("res://Assets/Inventory/icons/bomb.png")
const PAPER := Color("ebe7dc")
const INK := Color("1b1a17")

@export var bow_offset := 2.2        # metres ahead of the boat's middle the bomb is dropped (about her bow)
@export var cooldown := 2.0          # seconds after a bomb before the next one can be dropped
@export var equip_anim_time := 0.6   # seconds the rings pulse out when a bomb is equipped
@export var equip_ring_grow := 22.0  # pixels each ring grows past the button's edge before it fades away

@export var press_flash := 0.12      # a press turns the button black for this long (s), with a click (Enrico: every button)

var press_flash_left := 0.0          # seconds it stays black after a press (any press, even while it rests)
var pressed_time := 0.0              # > 0 for a moment after a tap: the button is drawn pushed in
var cooldown_left := 0.0             # seconds before it can drop another bomb (0 = ready)
var equip_anim_left := 0.0           # seconds left of the equip rings (0 = none)
var was_equipped := false            # was a bomb equipped a moment ago? (to notice the moment it gets equipped)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	Inventory.equipped_changed.connect(_on_equipped_changed)
	Inventory.changed.connect(_update_shown)          # bombs coming aboard or going out
	_update_shown()
	was_equipped = Inventory.equipped == "bomb"


## Something was equipped or unequipped (Inventory.equipped_changed): show or hide the button, and if a bomb has
## just been equipped, the rings and the click-clack.
func _on_equipped_changed() -> void:
	_update_shown()
	var is_equipped := Inventory.equipped == "bomb"
	if is_equipped and not was_equipped:
		equip_anim_left = equip_anim_time
		Sfx.equip_bomb()
		queue_redraw()
	was_equipped = is_equipped


## Shown only while a bomb is equipped AND there's at least one aboard (Enrico: with 0 bombs it's hidden and does
## nothing; a hidden Control gets no taps, so hiding it also switches it off).
func _update_shown() -> void:
	visible = Inventory.equipped == "bomb" and Inventory.count("bomb") > 0


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
		drop_bomb()
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
	# The equip rings: drawn again every frame while they pulse out.
	if equip_anim_left > 0.0:
		equip_anim_left = maxf(0.0, equip_anim_left - dt)
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
	# Just pressed: the whole button black (as the wheel's hub does).
	if press_flash_left > 0.0:
		draw_circle(middle, radius, INK)
		return
	# Resting after a bomb: the pie of what's left of the wait, in see-through ink (the dither turns it to dots).
	if cooldown_left > 0.0:
		_draw_pie(middle, radius, cooldown_left / cooldown)
	# Just equipped: the rings pulsing out.
	if equip_anim_left > 0.0:
		_draw_equip_rings(middle, radius)


## Two rings, one after the other, growing out from the button's edge by equip_ring_grow pixels and thinning and
## fading as they go (ink over a paper edge, so they read on the sea). `share` runs 0 → 1 over equip_anim_time.
func _draw_equip_rings(middle: Vector2, radius: float) -> void:
	var share := 1.0 - equip_anim_left / equip_anim_time
	for ring in 2:
		var ring_share := clampf((share - ring * 0.3) / 0.7, 0.0, 1.0)   # the second ring starts a little later
		if ring_share <= 0.0 or ring_share >= 1.0:
			continue
		var r := radius + 4.0 + equip_ring_grow * ring_share
		var width := lerpf(4.0, 1.0, ring_share)
		var fade := 1.0 - ring_share
		draw_arc(middle, r, 0.0, TAU, 48, Color(PAPER, fade), width + 2.0)
		draw_arc(middle, r, 0.0, TAU, 48, Color(INK, fade), width)


## A pie slice in see-through ink: `share` of the circle (1 = all of it, 0 = nothing), starting at the top and
## going clockwise. It's a fan: the middle, then points round the edge from the top to where the slice ends.
func _draw_pie(middle: Vector2, radius: float, share: float) -> void:
	var points := PackedVector2Array([middle])
	var steps := maxi(2, int(48 * share))            # more points for a bigger slice, so the edge stays round
	for i in steps + 1:
		var angle := TAU * share * i / steps          # 0 = the top, growing clockwise
		points.append(middle + Vector2(sin(angle), -cos(angle)) * radius)
	draw_colored_polygon(points, Color(INK, 0.5))

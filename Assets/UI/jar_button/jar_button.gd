extends Control
## THE AEOLUS JAR'S ACTION (Enrico, Nov 2026: no button of its own any more). When the jar is the thing in hand
## (Inventory.equipped), a tap on the interaction button (Assets/UI/interaction_button) calls `use()`: one jar out of
## the hold, and the wind swings round to blow from right astern, the way her bow points (Wind.turn_to over
## `turn_time`); it stays so until another jar or a wind zone. Then it rests `cooldown` seconds (the ink pie).
## The same few things as every item action: ITEM, ICON, use(), can_use(), cooldown_share(), is_active().
## This node stays in ui_layout.tscn only to hold its numbers (Inspector) and its timer; it's never drawn.

const ITEM := "aeolus_jar"
const ICON := preload("res://Assets/Inventory/icons/aeolus_jar.png")

@export var cooldown := 30.0         # seconds after a jar before the next one can be uncorked
@export var turn_time := 1.5         # seconds the wind takes to swing round behind her

var cooldown_left := 0.0             # seconds before another jar can be uncorked (0 = ready)


func _ready() -> void:
	visible = false                      # never drawn: the interaction button shows it
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("item_actions")         # so the interaction button finds it


func _process(dt: float) -> void:
	if cooldown_left > 0.0:
		cooldown_left = maxf(0.0, cooldown_left - dt)


## Can a tap do something now? (A jar aboard and not resting.)
func can_use() -> bool:
	return cooldown_left <= 0.0 and Inventory.count(ITEM) > 0


## The share of the rest still left (1 = just used, 0 = ready): the ink pie.
func cooldown_share() -> float:
	return cooldown_left / cooldown if cooldown > 0.0 else 0.0


func is_active() -> bool:
	return false


## One jar out of the hold, and the wind swings round to blow from right astern.
func use() -> void:
	var boat := get_tree().get_first_node_in_group("player_boat") as Node3D
	if boat == null or boat.sinking or not can_use():
		return
	if not Inventory.remove(ITEM):
		return
	# Which way her bow points, as a compass angle (0 = north, 90 = east): her -Z is the way the bow points,
	# and in Godot's 3D north is -Z and east is +X, so the angle is atan2(east part, north part).
	var ahead: Vector3 = -boat.global_transform.basis.z
	var bow_deg := rad_to_deg(atan2(ahead.x, -ahead.z))
	# The wind must blow the way she's heading, so it comes FROM right behind her: half a turn round.
	Wind.turn_to(bow_deg + 180.0, turn_time)
	cooldown_left = cooldown

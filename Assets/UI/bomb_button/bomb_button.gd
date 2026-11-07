extends Control
## THE BOMB'S ACTION (Enrico, Nov 2026: no button of its own any more). When the bomb is the thing in hand
## (Inventory.equipped), a tap on the interaction button (Assets/UI/interaction_button) calls `use()`: a bomb off the
## boat's bow (Assets/Items/bomb/bomb.tscn), one out of the hold; when the last one goes, nothing is in hand any more.
## After each bomb it rests `cooldown` seconds (the interaction button draws the ink pie from `cooldown_share()`).
## Each bomb also heats the engine by `heat_cost` of the overheat bar (Enrico, Nov 2026: 75% of it; paddles.gd
## add_heat): reaching the top, she overheats (the lever's filling shows how hot she is).
## When a bomb is equipped, a snappy click-clack plays, like a gun being loaded (Sfx.equip, from bomb.tres); the interaction
## button pulses its rings.
## Every item action has the same few things (the interaction button uses them): ITEM, ICON, use(), can_use(),
## cooldown_share(), is_active(). (In Unreal: a small component per tool, called through the same interface.)
## This node stays in ui_layout.tscn only to hold its numbers (Inspector) and its timer; it's never drawn.

const ITEM := "bomb"
const ICON := preload("res://Assets/Inventory/icons/bomb.png")
const BOMB_SCENE := preload("res://Assets/Items/bomb/bomb.tscn")

@export var bow_offset := 2.2        # metres ahead of the boat's middle the bomb is dropped (about her bow)
@export var cooldown := 2.0          # seconds after a bomb before the next one can be dropped
@export var heat_cost := 0.75        # share of the paddles' overheat bar each bomb adds (0.75 = 75%; 0 = none)

var cooldown_left := 0.0             # seconds before it can drop another bomb (0 = ready)


func _ready() -> void:
	visible = false                      # never drawn: the interaction button shows it
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("item_actions")         # so the interaction button finds it
	set_process(false)                   # nothing to count until a bomb is dropped


## Only while it rests after a use (switched on in use()): the wait counts down, then it switches itself off.
func _process(dt: float) -> void:
	cooldown_left = maxf(0.0, cooldown_left - dt)
	if cooldown_left == 0.0:
		set_process(false)


## Can a tap do something now? (A bomb aboard, and not resting.)
func can_use() -> bool:
	return cooldown_left <= 0.0 and Inventory.count(ITEM) > 0


## The share of the rest still left (1 = just used, 0 = ready): the ink pie.
func cooldown_share() -> float:
	return cooldown_left / cooldown if cooldown > 0.0 else 0.0


## Bombs are never "held": always false (the hook's is true while it holds something).
func is_active() -> bool:
	return false


## A bomb off the bow, one out of the hold.
func use() -> void:
	var boat := Boat.current as Node3D
	if boat == null or boat.sinking or not can_use():
		return
	if not Inventory.remove(ITEM):
		return
	boat.paddles.add_heat(heat_cost)         # the engine heats up (paddles.gd; she may overheat)
	var bomb := BOMB_SCENE.instantiate()
	boat.get_parent().add_child(bomb)        # into the world, not onto the boat (it stays where it fell)
	var ahead: Vector3 = -boat.global_transform.basis.z   # the boat's -Z is the way her bow points
	ahead.y = 0.0
	bomb.global_position = boat.global_position + ahead.normalized() * bow_offset
	bomb.global_position.y = 0.0
	cooldown_left = cooldown
	set_process(true)                    # the rest counts down (_process)

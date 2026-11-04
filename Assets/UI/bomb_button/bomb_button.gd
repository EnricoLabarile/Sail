extends Control
## THE BOMB'S ACTION (Enrico, Nov 2026: no button of its own any more). When the bomb is the thing in hand
## (Inventory.equipped), a tap on the interaction button (Assets/UI/interaction_button) calls `use()`: a bomb off the
## boat's bow (Assets/Items/bomb/bomb.tscn), one out of the hold; when the last one goes, nothing is in hand any more.
## After each bomb it rests `cooldown` seconds (the interaction button draws the ink pie from `cooldown_share()`).
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

var cooldown_left := 0.0             # seconds before it can drop another bomb (0 = ready)
var was_equipped := false            # was a bomb equipped a moment ago? (to notice the moment it gets equipped)


func _ready() -> void:
	visible = false                      # never drawn: the interaction button shows it
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("item_actions")         # so the interaction button finds it
	Inventory.equipped_changed.connect(_on_equipped_changed)
	was_equipped = Inventory.is_equipped(ITEM)


## The moment a bomb gets equipped (its click-clack is now played by the interaction button, Sfx.equip, as every thing's).
func _on_equipped_changed() -> void:
	was_equipped = Inventory.is_equipped(ITEM)


func _process(dt: float) -> void:
	if cooldown_left > 0.0:
		cooldown_left = maxf(0.0, cooldown_left - dt)


## Can a tap do something now? (A bomb aboard and not resting.)
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
	var boat := get_tree().get_first_node_in_group("player_boat") as Node3D
	if boat == null or boat.sinking or not can_use():
		return
	if not Inventory.remove(ITEM):
		return
	var bomb := BOMB_SCENE.instantiate()
	boat.get_parent().add_child(bomb)        # into the world, not onto the boat (it stays where it fell)
	var ahead: Vector3 = -boat.global_transform.basis.z   # the boat's -Z is the way her bow points
	ahead.y = 0.0
	bomb.global_position = boat.global_position + ahead.normalized() * bow_offset
	bomb.global_position.y = 0.0
	cooldown_left = cooldown

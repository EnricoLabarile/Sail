extends Control
## THE HARPOON'S ACTION (Enrico, Nov 2026: no button of its own any more). When the harpoon is the thing in hand
## (Inventory.equipped), a tap on the interaction button (Assets/UI/interaction_button) calls `use()`: one harpoon out
## of the hold (they're spent, bought again), shot from her bow (Assets/Items/harpoon/harpoon.tscn: it hooks what it
## meets and pulls it to her). One out at a time; after each shot it rests `cooldown` seconds (the ink pie).
## The same few things as every item action: ITEM, ICON, use(), can_use(), cooldown_share(), is_active().
## This node stays in ui_layout.tscn only to hold its numbers (Inspector) and its timer; it's never drawn.

const ITEM := "harpoon"
const ICON := preload("res://Assets/Inventory/icons/harpoon.png")
const HARPOON_SCENE := preload("res://Assets/Items/harpoon/harpoon.tscn")

@export var cooldown := 1.0          # seconds after a shot before the next one (and never while one is out)

var cooldown_left := 0.0             # seconds before another harpoon can be shot (0 = ready)
var harpoon_out: Node3D = null       # the harpoon flying now (null = none)


func _ready() -> void:
	visible = false                      # never drawn: the interaction button shows it
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("item_actions")         # so the interaction button finds it


func _process(dt: float) -> void:
	if cooldown_left > 0.0:
		cooldown_left = maxf(0.0, cooldown_left - dt)


## Can a tap do something now? (A harpoon aboard, none out, not resting.)
func can_use() -> bool:
	return cooldown_left <= 0.0 and not is_instance_valid(harpoon_out) and Inventory.count(ITEM) > 0


## The share of the rest still left (1 = just used, 0 = ready): the ink pie.
func cooldown_share() -> float:
	return cooldown_left / cooldown if cooldown > 0.0 else 0.0


## True while a harpoon is out (flying or pulling).
func is_active() -> bool:
	return is_instance_valid(harpoon_out)


## One harpoon out of the hold, shot from her bow.
func use() -> void:
	var boat := get_tree().get_first_node_in_group("player_boat") as Node3D
	if boat == null or boat.sinking or boat.emerging or not can_use():
		return
	if not Inventory.remove(ITEM):
		return
	harpoon_out = HARPOON_SCENE.instantiate()
	boat.get_parent().add_child(harpoon_out)   # into the level, next to the boat (it flies on its own)
	harpoon_out.launch(boat)
	cooldown_left = cooldown

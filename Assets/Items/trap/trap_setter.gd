extends Node
## THE TRAP SETTER: a little helper node inside the boat (boat.tscn: Boat/TrapSetter). It listens to the boat:
## when her anchor goes down (boat.gd's signal anchor_dropped) and a trap is equipped (Inventory.equipped), it
## lays a trap (trap.tscn) on the water where she is. The trap itself does the rest (trap.gd: arming, catching).
## (In Unreal: an Actor Component on the pawn, bound to one of the pawn's Event Dispatchers.)

const TRAP_SCENE := preload("res://Assets/Items/trap/trap.tscn")

@onready var boat: Node3D = get_parent()


func _ready() -> void:
	boat.anchor_dropped.connect(_on_anchor_dropped)


func _on_anchor_dropped() -> void:
	if Inventory.equipped != "trap" or Inventory.count("trap") == 0:
		return
	var trap := TRAP_SCENE.instantiate()
	boat.get_parent().add_child(trap)        # into the world: it stays when she sails away
	trap.global_position = Vector3(boat.global_position.x, 0.0, boat.global_position.z)
	trap.lay(boat)

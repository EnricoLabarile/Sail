extends Node3D
## ONE TRAP, laid on the water by the boat (trap_setter.gd, when the anchor goes down with a trap equipped).
##   1. ARMING: it lies there, faint, for `arm_time` seconds. She must stay at anchor all that time: if she
##      weighs anchor first, the trap is taken back aboard (nothing is spent).
##   2. ACTIVE: one trap less in the hold, and the trap shows solid. It stays where it is, even when she sails
##      away. When an enemy comes up within `radius` of it (a sea imp: sea_imp_zone.gd hit_imp_at, only while
##      it's out of the water), the enemy loses `damage` hearts and the trap is used up.
## (In Unreal: a small actor with a timer and an overlap test, destroyed once it has fired.)

@export var arm_time := 1.5          # seconds at anchor before it's set
@export var radius := 2.0            # metres from its middle an enemy must come up to be caught
@export var damage := 1.0            # hearts it takes off the enemy

enum State { ARMING, ACTIVE }

var state := State.ARMING
var time := 0.0
var boat: Node3D                     # the boat that laid it (it waits for her anchor while arming)

@onready var picture: MeshInstance3D = $Picture


## trap_setter.gd calls this right after adding it to the world.
func lay(by_boat: Node3D) -> void:
	boat = by_boat
	picture.material_override = picture.material_override.duplicate()   # its own see-through-ness
	set_faint(true)


func _process(dt: float) -> void:
	time += dt
	if state == State.ARMING:
		# She weighed anchor (or sank) too soon: the trap comes back aboard, nothing spent.
		if not boat.anchored or boat.sinking:
			queue_free()
			return
		if time >= arm_time:
			arm()
		return
	# ACTIVE: did an enemy come up on it?
	for zone in get_tree().get_nodes_in_group("sea_imps"):
		if zone.hit_imp_at(global_position, radius, damage):
			queue_free()                 # used up
			return


## Set: it's spent from the hold and shows solid.
func arm() -> void:
	if not Inventory.remove("trap"):
		queue_free()                     # none left after all
		return
	state = State.ACTIVE
	set_faint(false)


## Faint while arming, solid once set.
func set_faint(faint: bool) -> void:
	var material: StandardMaterial3D = picture.material_override
	material.albedo_color.a = 0.4 if faint else 1.0

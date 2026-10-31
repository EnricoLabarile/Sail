@tool
extends Node3D
## A KEY (Enrico): a big key floating on the water, placed by hand somewhere in the world. It opens a bridge lock
## (Assets/Landscape/architecture/bridge_lock.gd): the boat hooks it, tows it to the lock, and once it's within the
## lock's `open_radius` the lock opens and the key is used up (gone).
## `key_id` says which lock it opens: a lock opens for a key with the same id (a lock with no id: any key).
##
## Towing it is its `Towable` child's job (the component, Assets/Items/towable/towable.gd: how close to grab it, the
## rope, the slowdown are set there). This script only bobs the picture and gets used up.
## It isn't solid: she can sail over it.
## (In Unreal: an actor with a tag "Key" and a towing component, that a gate actor looks for within a radius.)

## Which lock it opens: the same text as the lock's `key_id` (empty = any lock that takes any key).
@export var key_id := ""
@export var bob_height := 0.1       # metres it bobs up and down on the water
@export var bob_speed := 2.0        # how fast it bobs

var used := false                   # it opened its lock: it's going
var bob_time := 0.0

@onready var picture: MeshInstance3D = $Picture
@onready var picture_height: float = $Picture.position.y   # where the picture sits, as placed in key.tscn
@onready var towable: Towable = $Towable                    # the component that lets the hook drag it


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("keys")                                 # so the locks find every key (bridge_lock.gd)
	bob_time = randf() * TAU                             # each key bobs on its own beat


func _process(dt: float) -> void:
	if Engine.is_editor_hint():
		return
	# It bobs a little on the water (only the picture: the key's place doesn't change).
	bob_time += dt * bob_speed
	picture.position.y = picture_height + sin(bob_time) * bob_height


## Its lock opened (bridge_lock.gd): the rope comes off and the key is gone.
func use_up() -> void:
	used = true
	towable.stop_tow()
	queue_free()

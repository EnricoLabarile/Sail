@tool
extends Node3D
## A BRIDGE LOCK (Enrico): a gate standing in the water under a bridge, across a river, that shuts the way. It's
## solid: the boat bumps on it like a shore. When a KEY (Assets/Items/key, towed there with the hook) comes within
## `open_radius` of it, the gate sinks straight down into the water, by its own height, over `open_time` seconds; then
## it stops being solid and the boat can sail through. The key is used up (gone). It stays open for good.
## `key_id`: it opens only for a key with the same id (empty = any key opens it).
## The signal `opened` is sent once, when it starts to open (connect it to anything else that should happen).
## (In Unreal: an actor with a blocking collision that looks for actors tagged "Key" within a radius, then plays a
## timeline that lowers the mesh and switches the collision off, and fires an Event Dispatcher.)
##
## Its parts (bridge_lock.tscn): `Gate` (the part that sinks) holding `Mesh` (Enrico's sm_bridge_lock_01_a.fbx:
## a flat panel 1 m wide and 1.5 m tall, its origin at its bottom) and `Body` (a StaticBody3D whose box is made in
## code as big as the mesh, `thickness` deep, so Land's rays hit it: the boat and a towed key stop against it).
## Scale the BridgeLock node in the level to make it as big as the bridge: everything follows.

## Sent once, when a key opens it.
signal opened

## Which key opens it: the same text as the key's `key_id` (empty = any key).
@export var key_id := ""
## Metres from the gate's middle a key must come within to open it.
@export var open_radius := 6.0
## Seconds it takes to sink all the way down.
@export var open_time := 1.5
## Metres deep the solid box is (the mesh is a flat panel: the box gives it some thickness, so the boat can't slip
## through it). In the gate's own size, so it grows with the node's scale.
@export var thickness := 1.5:
	set(value):
		thickness = value
		_fit_body()

var is_open := false
var progress := 0.0                 # 0 = shut, 1 = all the way down
var height := 6                   # the gate's height (the mesh's), worked out in _fit_body

@onready var gate: Node3D = $Gate


func _ready() -> void:
	_fit_body()
	if Engine.is_editor_hint():
		return
	set_physics_process(true)


## The solid box as big as the mesh (its width and height), `thickness` deep, standing on the same bottom.
## (Its own copy of the shape: local to scene in bridge_lock.tscn.) get_node_or_null: the setter can run while the
## scene is still being loaded, before the nodes exist.
func _fit_body() -> void:
	var mesh := find_mesh(get_node_or_null("Gate/Mesh"))
	var shape_node := get_node_or_null("Gate/Body/Shape") as CollisionShape3D
	if mesh == null or shape_node == null or shape_node.shape == null:
		return
	var box := mesh.get_aabb()                           # the mesh's own size and place (in its node's space)
	height = box.size.y
	var middle := box.get_center()
	shape_node.shape.size = Vector3(box.size.x, box.size.y, thickness)
	shape_node.position = Vector3(middle.x, middle.y, middle.z)


## The MeshInstance3D inside the imported model (the .fbx makes it a little scene with the mesh inside).
func find_mesh(node: Node) -> MeshInstance3D:
	if node == null:
		return null
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := find_mesh(child)
		if found:
			return found
	return null


func _physics_process(dt: float) -> void:
	if Engine.is_editor_hint():
		return
	if not is_open:
		look_for_key()
	else:
		sink(dt)


## Shut: is a key that fits close enough? Then it opens, and the key is used up.
func look_for_key() -> void:
	for key in get_tree().get_nodes_in_group("keys"):
		if key.used:
			continue
		if key_id != "" and key.key_id != key_id:
			continue                                     # not this lock's key
		var off: Vector3 = key.global_position - middle()
		off.y = 0.0
		if off.length() <= open_radius:
			open()
			key.use_up()
			return


## The gate's middle on the water (the solid box's middle: the mesh doesn't sit on the node's own origin).
func middle() -> Vector3:
	return $Gate/Body/Shape.global_position


## It opens: from now on it sinks (sink, every physics frame).
func open() -> void:
	is_open = true
	opened.emit()


## Going down: the gate sinks by its own height over open_time; once all the way down it's no longer solid, and
## this stops running.
func sink(dt: float) -> void:
	progress = minf(1.0, progress + dt / open_time)
	var eased := progress * progress * (3.0 - 2.0 * progress)   # smoothstep: starts and ends gently
	gate.position.y = -height * eased
	if progress >= 1.0:
		$Gate/Body/Shape.disabled = true                 # the way is open: the boat can sail through
		set_physics_process(false)

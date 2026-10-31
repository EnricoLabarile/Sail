@tool
extends Node3D
## A BRIDGE LOCK (Enrico): a gate standing in the water under a bridge, across a river, that shuts the way. It's
## solid: the boat bumps on it like a shore. When a KEY (Assets/Items/key, towed there with the hook) comes within
## `open_radius` metres of its solid box (of the box's surface, wherever it is: in front, at a side, at a corner),
## the gate sinks straight down into the water, by its own height, over `open_time` seconds; then
## it stops being solid and the boat can sail through. The key is used up (gone). It stays open for good.
## `key_id`: it opens only for a key with the same id (empty = any key opens it).
## The signal `opened` is sent once, when it starts to open (connect it to anything else that should happen).
## (In Unreal: an actor with a blocking collision that looks for actors tagged "Key" within a radius, then plays a
## timeline that lowers the mesh and switches the collision off, and fires an Event Dispatcher.)
##
## Its parts (bridge_lock.tscn): `Gate` (the part that sinks) holding the mesh (Enrico's sm_bridge_lock_01_a.fbx, any
## node name: the first MeshInstance3D inside Gate is used) and `Body` (a StaticBody3D with a box, `Shape`, that YOU
## size and place in the editor: it's the WALL, not a trigger. Land's rays hit it, so the boat and a towed key stop
## against it). There's no trigger shape: the "trigger" is `open_radius`, measured from the box's surface.
## How far it sinks: the mesh's height (worked out at start, with the mesh's own scale; 6 m now), plus `sink_extra`.

## Sent once, when a key opens it.
signal opened

## Which key opens it: the same text as the key's `key_id` (empty = any key).
@export var key_id := ""
## Metres from the solid box's surface a key must come within to open it. (A towed key stops a little way off the
## box, as against a shore, so this must be more than that: 4 is plenty.)
@export var open_radius := 4.0
## Seconds it takes to sink all the way down.
@export var open_time := 1.5
## Metres it sinks further than its own height (0 = its top ends level with the water).
@export var sink_extra := 0.0

var is_open := false
var progress := 0.0                 # 0 = shut, 1 = all the way down
var height := 1.5                   # how far it sinks: the mesh's height (in the Gate's space), worked out in _ready

@onready var gate: Node3D = $Gate


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	height = mesh_height()
	set_physics_process(true)


## The mesh's height as it stands inside the Gate: its own box (get_aabb, in the mesh's own units) carried through
## the scales of the nodes between it and the Gate (the .fbx gives the mesh a scale of its own: 16 × 4 × 4, so
## 1.5 × 4 = 6 m). No mesh found: 1.5.
func mesh_height() -> float:
	var mesh := find_mesh(gate)
	if mesh == null:
		return 1.5
	var to_gate: Transform3D = gate.global_transform.affine_inverse() * mesh.global_transform
	var box: AABB = to_gate * mesh.get_aabb()            # the mesh's box, seen from the Gate
	return box.size.y


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
		if distance_to_box(key.global_position) <= open_radius:
			open()
			key.use_up()
			return


## How far a point is from the solid box, across the water (0 = on it or inside it). Worked out in the box's own
## space: the point is brought into it, pushed onto the box (clamped to its half size on x and z), and the distance
## between the two is the answer. (A sphere round the middle didn't work for a long, deep box: a key stopped against
## a 12 m deep box is more than 6 m from its middle.)
func distance_to_box(point: Vector3) -> float:
	var shape_node := $Gate/Body/Shape as CollisionShape3D
	var box := shape_node.shape as BoxShape3D
	var local: Vector3 = shape_node.global_transform.affine_inverse() * point   # the point, seen from the box
	var half: Vector3 = box.size * 0.5
	var nearest := Vector3(clampf(local.x, -half.x, half.x), local.y, clampf(local.z, -half.z, half.z))
	var off: Vector3 = shape_node.global_transform * nearest - point              # back in the world
	off.y = 0.0
	return off.length()


## It opens: from now on it sinks (sink, every physics frame).
func open() -> void:
	is_open = true
	opened.emit()


## Going down: the gate sinks by its own height over open_time; once all the way down it's no longer solid, and
## this stops running.
func sink(dt: float) -> void:
	progress = minf(1.0, progress + dt / open_time)
	var eased := progress * progress * (3.0 - 2.0 * progress)   # smoothstep: starts and ends gently
	gate.position.y = -(height + sink_extra) * eased
	if progress >= 1.0:
		$Gate/Body/Shape.disabled = true                 # the way is open: the boat can sail through
		set_physics_process(false)

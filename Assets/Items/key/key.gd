@tool
extends Node3D
## A KEY (Enrico): a big key floating on the water, placed by hand somewhere in the world. It opens a bridge lock
## (Assets/Landscape/architecture/bridge_lock.gd): the boat hooks it (the hook button, Assets/UI/hook_button), tows
## it to the lock, and once it's within the lock's `open_radius` the lock opens and the key is used up (gone).
## `key_id` says which lock it opens: a lock opens for a key with the same id (a lock with no id: any key).
##
## Towing (the hook button's interface, like the barrel's): with the hook equipped and her middle within
## `grab_reach` of it, a tap ties a rope from her stern to it, and it follows behind her, `rope_length` metres from
## her stern (pulled when the rope is taut, left where it is when she comes back toward it); never onto land (a
## closed lock counts as land too: it stops against it). Another tap lets it go, and it stays there.
## If she's hurt, the hook lets go of it (hook_button.gd).
## It isn't solid: she can sail over it.
## (In Unreal: an actor with a tag "Key" that a gate actor looks for within a radius.)

## Which lock it opens: the same text as the lock's `key_id` (empty = any lock that takes any key).
@export var key_id := ""
@export var grab_reach := 4.0       # metres from its middle her middle may be for the hook button to grab it
@export var rope_length := 4.0      # metres of rope from her stern to it while towed
@export var tow_slowdown := 0.9     # her speed × this while she tows it (1 = it doesn't hold her back)
@export var size := 1.2             # metres: its own size (the rope ends this far from its middle; land is looked for this far ahead)
@export var rope_width := 0.15      # metres
@export var rope_height := 0.6      # metres above the water the rope runs
@export var bob_height := 0.1       # metres it bobs up and down on the water
@export var bob_speed := 2.0        # how fast it bobs

var tow_boat: Node3D = null         # the boat towing it (null = not towed)
var used := false                   # it opened its lock: it's going
var rope: MeshInstance3D            # the ink strip from her stern to it (made in code, shown only while towed)
var bob_time := 0.0

@onready var picture: MeshInstance3D = $Picture
@onready var picture_height: float = $Picture.position.y   # where the picture sits, as placed in key.tscn


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("keys")                                 # so the locks find every key (bridge_lock.gd)
	add_to_group("towable")                              # so the hook button can grab it
	# Moved in physics frames while towed, like the boat: drawn smoothly between them (physics interpolation).
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	bob_time = randf() * TAU                             # each key bobs on its own beat
	make_rope()
	set_physics_process(false)                           # nothing to do until it's towed


func _process(dt: float) -> void:
	if Engine.is_editor_hint():
		return
	# It bobs a little on the water (only the picture: the key's place doesn't change).
	bob_time += dt * bob_speed
	picture.position.y = picture_height + sin(bob_time) * bob_height
	if tow_boat:
		draw_rope()


func _physics_process(_dt: float) -> void:
	if Engine.is_editor_hint():
		return
	if tow_boat:
		follow_boat()


# ---- towing (the hook button's interface, Assets/UI/hook_button/hook_button.gd) ----

## May it be grabbed now?
func can_be_towed() -> bool:
	return not used and tow_boat == null


## How close her middle must be to its middle to grab it.
func tow_reach() -> float:
	return grab_reach


## Grabbed: from now on it follows her on the rope, and she's held back a little.
func start_tow(by_boat: Node3D) -> void:
	tow_boat = by_boat
	tow_boat.held_back = tow_slowdown                    # boat.gd: her speed × this
	rope.visible = true
	set_physics_process(true)


## Let go: it stays where it is.
func stop_tow() -> void:
	if tow_boat == null:
		return
	if is_instance_valid(tow_boat):
		tow_boat.held_back = 1.0
	tow_boat = null
	rope.visible = false
	set_physics_process(false)


## Still held?
func is_towed() -> bool:
	return tow_boat != null


## Towed, every physics frame: when the rope is taut it's pulled toward her stern, along the rope, to just
## rope_length from it. Slack: it stays where it is. Never onto land (it stops on the shore). She sank: let go.
func follow_boat() -> void:
	if not is_instance_valid(tow_boat) or tow_boat.sinking:
		stop_tow()
		return
	var stern: Vector3 = tow_boat.stern_point()
	var off: Vector3 = global_position - stern           # from her stern to it
	off.y = 0.0
	if off.length() <= rope_length:
		return                                           # slack: it doesn't move
	var place: Vector3 = stern + off.normalized() * rope_length
	place.y = global_position.y
	# Not onto land: its middle and a point `size` ahead on the way it goes must both be on water.
	var step: Vector3 = place - global_position
	var ahead: Vector3 = place
	if step.length() > 0.001:
		ahead = place + step.normalized() * size
	if Land.is_land(place) or Land.is_land(ahead):
		return
	global_position = place


## Its lock opened (bridge_lock.gd): the rope comes off and the key is gone.
func use_up() -> void:
	used = true
	stop_tow()
	queue_free()


## A thin flat ink strip from her stern to it (a 1 x 1 plane moved to the middle, turned along the line and
## stretched to its length, as the barrel's rope). Drawn every frame from the smoothed places of both.
func draw_rope() -> void:
	if not is_instance_valid(tow_boat):
		return
	var boat_now: Transform3D = tow_boat.get_global_transform_interpolated()
	var stern: Vector3 = boat_now.origin + boat_now.basis.z * tow_boat.bow_reach   # her stern (her forward is -Z)
	var middle: Vector3 = get_global_transform_interpolated().origin
	var line: Vector3 = middle - stern
	line.y = 0.0
	var length := line.length() - size * 0.5             # the rope ends at the key's bow, not its middle
	if length < 0.05:
		rope.visible = false
		return
	rope.visible = true
	var direction := line.normalized()
	var start := Vector3(stern.x, rope_height, stern.z)
	rope.global_position = start + direction * length * 0.5
	rope.global_rotation = Vector3(0.0, atan2(-direction.x, -direction.z), 0.0)
	rope.scale = Vector3(rope_width, 1.0, length)


## The rope: a 1 x 1 plane in plain ink (unshaded), placed in world space (top_level) and not smoothed (it's
## placed every drawn frame from smoothed places already).
func make_rope() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(1, 1)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("1b1a17")
	material.render_priority = 2
	mesh.material = material
	rope = MeshInstance3D.new()
	rope.mesh = mesh
	rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rope.top_level = true
	rope.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	rope.visible = false
	add_child(rope)

@tool
extends Node3D
## A LEVER (Enrico, like A Link to the Past's levers pulled out of a wall): placed by hand. With the HOOK equipped
## (the item "hook", in A or B), the boat runs into it and is hooked to its handle by a rope. Then, the further she
## sails from it, the further the handle comes out; while she pulls, the rope holds her back (her speed × `slowdown`).
## Once she's `pull_length` metres further out than where she hooked on, it's pulled all the way: the signal `pulled`
## is sent (connect it to whatever should happen: a door…), the rope lets her go, and the handle slides back in by
## itself. It can be pulled again. Coming back toward it lets the handle slide back as far.
## (In Unreal: an actor with an overlap volume, a cable component to the pawn, and an Event Dispatcher "Pulled".)
##
## Its parts (lever.tscn): `Post` (the fixed part, solid: a StaticBody so the boat bumps on it like a shore), `Handle`
## (slides out toward the boat), `Rope` (an ink strip from the handle to her stern), `Sensor` (how close she must come
## to hook on, `touch_radius`). Stand-ins: plain shapes with the boat's toon_shade material.

## Sent once each time it's pulled all the way out.
signal pulled

## Metres from its middle the boat must come within to hook on (with the hook equipped). The sensor follows it.
@export var touch_radius := 3.5:
	set(value):
		touch_radius = value
		_fit_sensor()
@export var pull_length := 15.0       # metres she must sail out (from where she hooked on) to pull it all the way
@export var slowdown := 0.5           # her speed × this while she's pulling it (Enrico: the rope holds her back)
@export var handle_travel := 1.5      # metres the handle comes out at the end of the pull (only the look)
@export var return_time := 0.6        # seconds the handle takes to slide back in
@export var rope_width := 0.12        # metres
@export var rope_height := 0.6        # metres above the water the rope runs

const HOOK := "hook"   # the item that must be equipped (Assets/Inventory/items/hook.tres)

enum State { IDLE, HOOKED, RETURNING }

var state := State.IDLE
var boat: Node3D = null         # the boat hooked to it (HOOKED)
var hooked_distance := 0.0      # how far her stern was from its middle when she hooked on
var progress := 0.0             # 0 = handle in, 1 = pulled all the way
var pull_direction := Vector3.FORWARD   # which way the handle comes out (toward her, flat)

@onready var handle: Node3D = $Handle
@onready var rope: MeshInstance3D = $Rope
@onready var handle_rest: Vector3 = $Handle.position   # where the handle sits when it's in (as placed in lever.tscn)


func _ready() -> void:
	_fit_sensor()
	if Engine.is_editor_hint():
		return
	rope.visible = false
	rope.top_level = true                 # placed in world space (easier: it runs from the handle to her stern)
	$Sensor.area_entered.connect(_on_sensor_entered)


## The sensor's cylinder is as wide as `touch_radius` (each lever has its own copy of the shape: local to scene).
func _fit_sensor() -> void:
	var shape_node := get_node_or_null("Sensor/Shape") as CollisionShape3D
	if shape_node and shape_node.shape:
		shape_node.shape.radius = touch_radius


## The boat came close: if she has the hook equipped (and it's free), she's hooked to it.
func _on_sensor_entered(area: Area3D) -> void:
	var other := area.get_parent() as Node3D
	if other == null or not other.is_in_group("player_boat"):
		return
	if state != State.IDLE or other.sinking or not Inventory.is_equipped(HOOK):
		return
	boat = other
	state = State.HOOKED
	hooked_distance = flat_distance(global_position, boat.stern_point())
	boat.held_back = slowdown             # the rope holds her back (boat.gd: her speed × this)
	rope.visible = true


func _process(dt: float) -> void:
	if Engine.is_editor_hint():
		return
	match state:
		State.HOOKED:
			pull(dt)
		State.RETURNING:
			slide_back(dt)


## Hooked: the handle comes out as far as she has sailed out since she hooked on (pull_length = all the way).
func pull(_dt: float) -> void:
	if not is_instance_valid(boat) or boat.sinking or not Inventory.is_equipped(HOOK):
		let_go()                           # she sank, or took the hook off: the rope comes off
		state = State.RETURNING
		return
	var stern: Vector3 = boat.stern_point()
	var off := stern - global_position
	off.y = 0.0
	if off.length() > 0.01:
		pull_direction = off.normalized()
	progress = clampf((off.length() - hooked_distance) / pull_length, 0.0, 1.0)
	place_handle()
	draw_rope(stern)
	if progress >= 1.0:
		pulled.emit()                      # all the way out: whatever is connected happens
		let_go()
		state = State.RETURNING


## Unhooked: the rope comes off and she's free again.
func let_go() -> void:
	if is_instance_valid(boat):
		boat.held_back = 1.0
	boat = null
	rope.visible = false


## The handle slides back in by itself, then the lever can be pulled again.
func slide_back(dt: float) -> void:
	progress = maxf(0.0, progress - dt / return_time)
	place_handle()
	if progress <= 0.0:
		state = State.IDLE


## The handle out of the post toward where she pulls, as far as the progress says. (Its place is in the lever's own
## space, so the pull direction is turned into it.)
func place_handle() -> void:
	var local_direction := global_transform.basis.inverse() * pull_direction
	handle.position = handle_rest + local_direction * handle_travel * progress


## The rope: a thin flat ink strip from the handle to her stern (a 1 x 1 plane moved to the middle, turned along the
## line and stretched to its length, as the harpoon's).
func draw_rope(stern: Vector3) -> void:
	var start := handle.global_position
	start.y = rope_height
	var end := stern
	end.y = rope_height
	var line := end - start
	line.y = 0.0
	var length := line.length()
	if length < 0.05:
		return
	rope.global_position = (start + end) * 0.5
	rope.global_rotation = Vector3(0.0, atan2(-line.x, -line.z), 0.0)
	rope.scale = Vector3(rope_width, 1.0, length)


## The distance across the water (not the height) between two points.
func flat_distance(a: Vector3, b: Vector3) -> float:
	var off := a - b
	off.y = 0.0
	return off.length()

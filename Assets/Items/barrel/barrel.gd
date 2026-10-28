@tool
extends Node3D
## A BARREL: a big wooden barrel floating on the water, with something inside (like the pots in Zelda).
## Only a bomb can break it: when one goes off within its reach (bomb.gd calls blast_at on every barrel), it breaks
## and leaves what was inside floating where it was, as an ordinary pickup (Assets/Items/pickup) for her to sail over.
## YOU decide what's inside: `contents` and `count` in the Inspector (empty `contents` = nothing inside).
##
## It's solid: the boat can't sail over it. Running into it is a bump, as against a shore (boat.gd bump): she's
## pushed back, loses her way and half a heart. The barrel itself never moves (Enrico): it stays where it was placed.
## (In Unreal: an actor with an overlap volume that does a radial-damage check, then spawns its loot.)
##
## How the boat is felt: `Sensor` (an Area3D, like a Trigger Volume) a little wider than the barrel; while her
## SpotSensor is inside it, the barrel checks her every physics frame (set_physics_process on only then).

const PICKUP := preload("res://Assets/Items/pickup/pickup.tscn")
const SENSOR_MARGIN := 3.0          # metres the sensor reaches past the barrel's edge

## What's inside (drag a .tres from Assets/Inventory/items here). Empty = the barrel breaks and leaves nothing.
@export var contents: ItemData
@export var count := 1              # how many of it
## Metres: how close her middle can come to its middle (its size as a collider). The sensor follows it by
## itself (radius + SENSOR_MARGIN, _fit_sensor), in the editor too.
@export var radius := 5:
	set(value):
		radius = value
		_fit_sensor()
var boat: Node3D                    # the boat, while she's inside the sensor (else null)
var broken := false

@onready var picture: MeshInstance3D = $Picture


func _ready() -> void:
	_fit_sensor()
	if Engine.is_editor_hint():
		return
	add_to_group("barrels")                              # so a bomb finds every barrel (bomb.gd explode)
	picture.material_override = picture.material_override.duplicate()   # its own phase
	picture.material_override.set_shader_parameter("phase", randf() * 16.0)
	$Sensor.area_entered.connect(_on_sensor_entered)
	$Sensor.area_exited.connect(_on_sensor_exited)
	set_physics_process(false)                           # nothing to do until she's near


## The sensor always a little wider than the barrel, whatever `radius` is, so she's felt before she touches it.
## (Its own copy of the shape: local to scene in barrel.tscn.) get_node_or_null: the setter can run while the scene
## is still being loaded, before the nodes exist.
func _fit_sensor() -> void:
	var shape_node := get_node_or_null("Sensor/Shape") as CollisionShape3D
	if shape_node and shape_node.shape:
		shape_node.shape.radius = radius + SENSOR_MARGIN


## Her SpotSensor came near: start checking her every physics frame.
func _on_sensor_entered(area: Area3D) -> void:
	var body := area.get_parent() as Node3D
	if body and body.is_in_group("player_boat"):
		boat = body
		set_physics_process(true)


## She went away: stop checking.
func _on_sensor_exited(area: Area3D) -> void:
	if area.get_parent() == boat:
		boat = null
		set_physics_process(false)


func _physics_process(_dt: float) -> void:
	if Engine.is_editor_hint():
		return
	if boat:
		keep_boat_out()


## The barrel is solid: if her middle is closer than `radius`, she's put back on its edge. If her own way was
## taking her into it, it's a bump (as against a shore): she's pushed back and hurt. The barrel stays put.
func keep_boat_out() -> void:
	var out: Vector3 = boat.global_position - global_position   # from the barrel to her
	out.y = 0.0
	if out.length() >= radius:
		return
	if out.length() < 0.01:
		out = Vector3.FORWARD                            # right on top of it: any way will do
	out = out.normalized()
	# How fast her own way takes her into the barrel (m/s).
	var fwd: Vector3 = -boat.global_transform.basis.z
	var into: float = -(fwd * boat.speed).dot(out)
	if into > 0.0:
		boat.bump(out, into)                             # her push back, her lost way, half a heart (boat.gd)
	# Put her back on the barrel's edge, so she never sails over it.
	var place: Vector3 = global_position + out * radius
	place.y = boat.global_position.y
	boat.global_position = place


## A bomb went off at `point`, reaching `reach` metres: if the barrel is in reach, it breaks.
func blast_at(point: Vector3, reach: float) -> void:
	if broken:
		return
	var off := global_position - point
	off.y = 0.0
	if off.length() <= reach + radius:                   # the blast touches any part of it
		break_open()


## It breaks: what was inside is left floating where the barrel was (a pickup), and the barrel is gone.
func break_open() -> void:
	broken = true
	if contents:
		var pickup := PICKUP.instantiate()
		pickup.item = contents
		pickup.count = count
		get_parent().add_child(pickup)
		pickup.global_position = Vector3(global_position.x, 0.0, global_position.z)
	queue_free()

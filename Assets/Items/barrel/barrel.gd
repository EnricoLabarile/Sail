@tool
extends Node3D
## A BARREL: a big wooden barrel floating on the water, with something inside (like the pots in Zelda).
## Only a bomb can break it: when one goes off within its reach (bomb.gd calls blast_at on every barrel), it breaks
## and leaves what was inside floating where it was, as an ordinary pickup (Assets/Items/pickup) for her to sail over.
## YOU decide what's inside: `contents` and `count` in the Inspector (empty `contents` = nothing inside).
##
## It's solid: the boat can't sail over it. Running into it is a bump, as against a shore (boat.gd bump): she's
## pushed back, loses her way and half a heart. The barrel is pushed the other way just as hard, and slides
## away, slowing down (it stops at the shore).
## (In Unreal: an actor with an overlap volume that does a radial-damage check, then spawns its loot.)
##
## How the boat is felt: `Sensor` (an Area3D, like a Trigger Volume) a little wider than the barrel; while her
## SpotSensor is inside it, the barrel checks her every physics frame (set_physics_process on only then).

const PICKUP := preload("res://Assets/Items/pickup/pickup.tscn")

## What's inside (drag a .tres from Assets/Inventory/items here). Empty = the barrel breaks and leaves nothing.
@export var contents: ItemData
@export var count := 1              # how many of it
@export var radius := 1.6           # metres: how close her middle can come to its middle (its size as a collider)
@export var push_fade := 3.5        # how quickly the barrel's push dies away (higher = it stops sooner)

var push := Vector3.ZERO            # the barrel's own push (m/s, on the sea), after she ran into it; fades away
var boat: Node3D                    # the boat, while she's inside the sensor (else null)
var broken := false

@onready var picture: MeshInstance3D = $Picture


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("barrels")                              # so a bomb finds every barrel (bomb.gd explode)
	picture.material_override = picture.material_override.duplicate()   # its own phase
	picture.material_override.set_shader_parameter("phase", randf() * 16.0)
	$Sensor.area_entered.connect(_on_sensor_entered)
	$Sensor.area_exited.connect(_on_sensor_exited)
	set_physics_process(false)                           # nothing to do until she's near or it's moving


## Her SpotSensor came near: start checking her every physics frame.
func _on_sensor_entered(area: Area3D) -> void:
	var body := area.get_parent() as Node3D
	if body and body.is_in_group("player_boat"):
		boat = body
		set_physics_process(true)


## She went away: stop checking (unless the barrel is still sliding).
func _on_sensor_exited(area: Area3D) -> void:
	if area.get_parent() == boat:
		boat = null


func _physics_process(dt: float) -> void:
	if Engine.is_editor_hint():
		return
	slide(dt)
	if boat:
		keep_boat_out()
	if boat == null and push.length() < 0.05:
		push = Vector3.ZERO
		set_physics_process(false)                       # still and nobody near: rest


## The barrel's own push: it moves with it, slowing down; it stops where the next step would be on land.
func slide(dt: float) -> void:
	push *= exp(-push_fade * dt)
	var next_place := global_position + push * dt
	if Land.is_land(next_place):
		push = Vector3.ZERO
	else:
		global_position = next_place


## The barrel is solid: if her middle is closer than `radius`, she's put back on its edge. If her own way was
## taking her into it, it's a bump (as against a shore): she's pushed back and hurt, and the barrel is pushed
## the other way just as hard.
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
		var was_waiting: bool = boat.bump_wait > 0.0
		boat.bump(out, into)                             # her push back, her lost way, half a heart (boat.gd)
		if not was_waiting and into >= boat.bounce_min_speed:
			# The same push for the barrel, the other way (boat.gd's bump: bounce_kick + into × bounce_extra).
			push -= out * (boat.bounce_kick + into * boat.bounce_extra)
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

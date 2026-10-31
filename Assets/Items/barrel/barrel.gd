@tool
extends Node3D
## A BARREL: a big wooden barrel floating on the water, with something inside (like the pots in Zelda).
## Only a bomb can break it: when one goes off with an arm of its blast on it (bomb.gd calls blast_at on every barrel), it breaks
## and leaves what was inside floating where it was, as an ordinary pickup (Assets/Items/pickup) for her to sail over.
## YOU decide what's inside: `contents` and `count` in the Inspector (empty `contents` = nothing inside).
##
## It's solid: the boat can't sail over it. Running into it is a bump, as against a shore (boat.gd bump): she's
## pushed back, loses her way and half a heart. Bumping doesn't move it.
## THE HOOK can tow it (Enrico): with the hook equipped and her middle within `radius` + `grab_reach`, a tap of the
## hook button (Assets/UI/hook_button) ties a rope from her stern to it, and it follows behind her, `rope_length`
## metres from her stern to its edge (pulled when the rope is taut, left where it is when she comes back toward it).
## While towed it isn't solid for her, it stops at the shore (never onto land), and she goes at × `tow_slowdown`.
## Another tap lets it go: it stays where she left it, solid again. It's in the group "towable" (the hook button's
## interface: can_be_towed, tow_reach, start_tow, stop_tow, is_towed).
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
@export_group("Towing (the hook)")
@export var grab_reach := 3.0       # metres past its edge her middle may be for the hook button to grab it
@export var rope_length := 4.0      # metres of rope from her stern to its edge while towed
@export var tow_slowdown := 0.8     # her speed × this while she tows it (1 = it doesn't hold her back)
@export var rope_width := 0.15      # metres
@export var rope_height := 0.6      # metres above the water the rope runs

var boat: Node3D                    # the boat, while she's inside the sensor (else null)
var tow_boat: Node3D = null         # the boat towing it (null = not towed)
var broken := false
var rope: MeshInstance3D            # the ink strip from her stern to it (made in code, shown only while towed)

@onready var picture: MeshInstance3D = $Picture


func _ready() -> void:
	_fit_sensor()
	if Engine.is_editor_hint():
		return
	add_to_group("barrels")                              # so a bomb finds every barrel (bomb.gd explode)
	add_to_group("towable")                              # so the hook button can grab it
	# Moved in physics frames while towed, like the boat: drawn smoothly between them (physics interpolation).
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	make_rope()
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


## She went away: stop checking (unless she's towing it: then it keeps following her).
func _on_sensor_exited(area: Area3D) -> void:
	if area.get_parent() == boat:
		boat = null
		set_physics_process(tow_boat != null)


func _physics_process(_dt: float) -> void:
	if Engine.is_editor_hint():
		return
	if tow_boat:
		follow_boat()                                    # towed: it follows her, and isn't solid for her
	elif boat:
		keep_boat_out()


func _process(_dt: float) -> void:
	if Engine.is_editor_hint():
		return
	if tow_boat:
		draw_rope()


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


# ---- towing (the hook button's interface, Assets/UI/hook_button/hook_button.gd) ----

## May it be grabbed now?
func can_be_towed() -> bool:
	return not broken and tow_boat == null


## How close her middle must be to its middle to grab it.
func tow_reach() -> float:
	return radius + grab_reach


## Grabbed: from now on it follows her on the rope, and she's held back a little.
func start_tow(by_boat: Node3D) -> void:
	tow_boat = by_boat
	tow_boat.held_back = tow_slowdown                    # boat.gd: her speed × this
	rope.visible = true
	set_physics_process(true)
	set_process(true)


## Let go: it stays where it is, solid again.
func stop_tow() -> void:
	if tow_boat == null:
		return
	if is_instance_valid(tow_boat):
		tow_boat.held_back = 1.0
	tow_boat = null
	rope.visible = false
	set_process(false)
	set_physics_process(boat != null)                    # still near her: solid again (keep_boat_out)


## Still held?
func is_towed() -> bool:
	return tow_boat != null


## Towed, every physics frame: when the rope is taut (its edge further than rope_length from her stern) it's
## pulled toward her stern, along the rope, to just rope_length from it. Slack: it stays where it is.
## It never goes onto land: then it stays where it was (stuck on the shore). She sank: the rope comes off.
func follow_boat() -> void:
	if not is_instance_valid(tow_boat) or tow_boat.sinking:
		stop_tow()
		return
	var stern: Vector3 = tow_boat.stern_point()
	var off: Vector3 = global_position - stern           # from her stern to it
	off.y = 0.0
	var reach := rope_length + radius                    # the rope plus the barrel's own size, to its middle
	if off.length() <= reach:
		return                                           # slack: it doesn't move
	var place: Vector3 = stern + off.normalized() * reach
	place.y = global_position.y
	# Not onto land: its middle and its edge on the way it goes must both be on water.
	var step: Vector3 = place - global_position
	var ahead: Vector3 = place
	if step.length() > 0.001:
		ahead = place + step.normalized() * radius * 0.5
	if Land.is_land(place) or Land.is_land(ahead):
		return
	global_position = place


## A thin flat ink strip from her stern to its edge (a 1 x 1 plane moved to the middle, turned along the line and
## stretched to its length, as the lever's rope). Drawn every frame from the smoothed places of both.
func draw_rope() -> void:
	if not is_instance_valid(tow_boat):
		return
	var boat_now: Transform3D = tow_boat.get_global_transform_interpolated()
	var stern: Vector3 = boat_now.origin + boat_now.basis.z * tow_boat.bow_reach   # her stern (her forward is -Z)
	var middle: Vector3 = get_global_transform_interpolated().origin
	var line: Vector3 = middle - stern
	line.y = 0.0
	var length := line.length() - radius * 0.5           # the rope ends at the barrel's side, not its middle
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
	set_process(false)


## A bomb went off: if one of its arms touches the barrel (bomb.gd in_blast, its radius added), it breaks.
func blast_at(bomb: Node3D) -> void:
	if broken:
		return
	if bomb.in_blast(global_position, radius):           # an arm of the blast touches any part of it (bomb.gd)
		break_open()


## It breaks: what was inside is left floating where the barrel was (a pickup), and the barrel is gone.
func break_open() -> void:
	stop_tow()                                           # towed: the rope comes off (she's free again)
	broken = true
	if contents:
		var pickup := PICKUP.instantiate()
		pickup.item = contents
		pickup.count = count
		get_parent().add_child(pickup)
		pickup.global_position = Vector3(global_position.x, 0.0, global_position.z)
	queue_free()

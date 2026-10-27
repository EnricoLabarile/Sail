@tool
@icon("res://Assets/Landscape/wind_zone/wind_zone_icon.svg")
extends Node3D
## A WIND ZONE: an invisible box you place in the world. When the boat sails into it, the wind turns to a new
## direction (Wind.turn_to) and stays like that until she crosses another zone.
## Each zone works ONCE: after the boat has crossed it, it does nothing more.
##
## In the Inspector you choose what it does:
##   - mode SPECIFIC: the wind will blow TOWARD `blow_toward_deg` (0 = north, 90 = east, 180 = south, 270 = west);
##   - mode RANDOM: the wind will blow toward a random direction, picked when she crosses it.
## `size` is the box's width and length in metres (turn the node to turn the box, e.g. a long thin one across a
## channel, like a finish line); `turn_time` how many seconds the wind takes to turn.
##
## In the editor: a wind icon (scene tree and 3D view, always on top), a see-through blue box on the water and,
## in SPECIFIC mode, an arrow pointing where the wind will blow (in RANDOM mode a "?"). In the game nothing shows.
## (In Unreal: a Trigger Box with an editor-only billboard that sets a value in a World Subsystem, DoOnce.)

enum Mode { SPECIFIC, RANDOM }

const ICON := preload("res://Assets/Landscape/wind_zone/wind_zone_icon.svg")

## SPECIFIC = toward blow_toward_deg; RANDOM = toward a random direction.
@export var mode := Mode.SPECIFIC:
	set(value):
		mode = value
		_fit_editor_helpers()
## Where the wind will blow TOWARD (SPECIFIC mode): 0 = north (up the screen), 90 = east, 180 = south, 270 = west.
@export_range(0, 360, 1) var blow_toward_deg := 0.0:
	set(value):
		blow_toward_deg = value
		_fit_editor_helpers()
## The box's width (x) and length (z), in metres. It's turned with the node.
@export var size := Vector2(20, 20):
	set(value):
		size = value
		_fit_sensor()
		_fit_editor_helpers()
## Seconds the wind takes to turn to its new direction (0 = at once).
@export var turn_time := 4.0

var used := false   # true once the boat has crossed it: then it never works again


func _ready() -> void:
	_fit_sensor()
	if Engine.is_editor_hint():
		_make_editor_helpers()
		set_notify_transform(true)        # so the arrow can keep pointing the right way when the node is turned
		return
	# The physics engine calls this when the boat's sensor comes in (OnBeginOverlap in Unreal).
	$Sensor.area_entered.connect(_on_sensor_entered)


## The sensor's box is as big as `size`. (Each zone has its own copy of the shape: local to scene in
## wind_zone.tscn, so changing one zone's size doesn't change the others'.)
func _fit_sensor() -> void:
	var shape := get_node_or_null("Sensor/Shape") as CollisionShape3D
	if shape and shape.shape:
		shape.shape.size = Vector3(size.x, 4.0, size.y)


## The boat came in: the first time, the wind turns. Then the zone is spent.
func _on_sensor_entered(area: Area3D) -> void:
	if used:
		return
	var boat := area.get_parent() as Node3D
	if boat == null or not boat.is_in_group("player_boat"):
		return
	used = true
	var toward := blow_toward_deg
	if mode == Mode.RANDOM:
		toward = randf_range(0.0, 360.0)
	# The Wind keeps where it blows FROM: the opposite side, half a turn round.
	Wind.turn_to(toward + 180.0, turn_time)
	# Nothing more to listen for (it works only once).
	$Sensor.area_entered.disconnect(_on_sensor_entered)


# ---------- In the editor only: the icon, the box and the arrow ----------
# Made in code with no owner, so they aren't saved in the scene and never appear in the game.

var _editor_box: MeshInstance3D
var _editor_arrow: MeshInstance3D
var _editor_question: Label3D

func _make_editor_helpers() -> void:
	# 1. The icon, as the map marker's: same size on screen however far, over the islands and the sea.
	var sprite := Sprite3D.new()
	sprite.texture = ICON
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.fixed_size = true
	sprite.pixel_size = 0.0015
	sprite.no_depth_test = true
	sprite.render_priority = 12
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	sprite.position.y = 2.0
	add_child(sprite)
	# 2. The box: a flat see-through blue rectangle on the water, 1 m a side, scaled to `size`.
	var see_through := StandardMaterial3D.new()
	see_through.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	see_through.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	see_through.albedo_color = Color(0.2, 0.5, 1.0, 0.25)
	see_through.cull_mode = BaseMaterial3D.CULL_DISABLED
	see_through.render_priority = 10    # after the sea, never hidden by it from afar
	see_through.no_depth_test = true    # and on top of the land
	var box_mesh := PlaneMesh.new()
	box_mesh.size = Vector2(1, 1)
	box_mesh.material = see_through
	_editor_box = MeshInstance3D.new()
	_editor_box.mesh = box_mesh
	_editor_box.position.y = 0.1
	add_child(_editor_box)
	# 3. The arrow: a flat triangle whose tip points where the wind will blow. It's top_level (it doesn't turn
	#    with the node), since the direction is on the map, not relative to the box.
	var arrow_material := see_through.duplicate()
	arrow_material.albedo_color = Color(0.2, 0.5, 1.0, 0.85)
	arrow_material.render_priority = 11   # over its own box
	var arrow_mesh := PrismMesh.new()
	arrow_mesh.size = Vector3(4.0, 8.0, 0.05)
	arrow_mesh.material = arrow_material
	_editor_arrow = MeshInstance3D.new()
	_editor_arrow.mesh = arrow_mesh
	_editor_arrow.top_level = true
	add_child(_editor_arrow)
	# 4. In RANDOM mode a "?" instead of the arrow.
	_editor_question = Label3D.new()
	_editor_question.text = "?"
	_editor_question.font_size = 96
	_editor_question.modulate = Color(0.2, 0.5, 1.0)
	_editor_question.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_editor_question.no_depth_test = true
	_editor_question.render_priority = 11
	_editor_question.position.y = 0.5
	add_child(_editor_question)
	_fit_editor_helpers()


## The box follows `size`, the arrow `blow_toward_deg` and `mode`.
func _fit_editor_helpers() -> void:
	if _editor_box == null:
		return
	_editor_box.scale = Vector3(size.x, 1.0, size.y)
	_editor_arrow.visible = mode == Mode.SPECIFIC
	_editor_question.visible = mode == Mode.RANDOM
	# A PrismMesh has its tip up (+Y): turned -90 degrees round X the tip points north (-Z); then turned round Y
	# to the angle (Godot turns anticlockwise seen from above, the compass clockwise: hence the minus).
	_editor_arrow.global_position = global_position + Vector3(0, 0.2, 0)
	_editor_arrow.global_rotation = Vector3(deg_to_rad(-90.0), deg_to_rad(-blow_toward_deg), 0.0)


## In the editor, when the node is moved or turned: the arrow (top_level) follows it.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_fit_editor_helpers()

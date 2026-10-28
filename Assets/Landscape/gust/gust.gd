@tool
extends Node3D
## A WIND GUST: a booster that stays where you place it (Enrico). A little whirl of wind on the water; when the
## boat sails through it, her top speed is multiplied by `speed_multiplier` (2 = doubled) for `boost_time`
## seconds, whichever way she's heading: it doesn't care where the wind blows, it just lets her go faster for a
## moment. A little screen shake and a very mild whoosh say she caught it. It stays there and works again every
## time she sails into it (it's the entering that counts: she has to leave it and come back).
## (In Unreal: a Trigger Volume that calls a function on the pawn, with a flipbook decal on the water.)
##
## To place one: instance gust.tscn anywhere (like placing a Blueprint) and set its numbers in the Inspector.
## The picture is a flipbook (gust.png, 4 x 4 frames, a stand-in for Enrico to redraw), drawn as big as `radius`.

## Metres round its middle the boat must come within to catch it. The picture and the sensor follow it.
@export var radius := 3.0:
	set(value):
		radius = value
		_fit_sensor()
		_fit_picture()
@export var speed_multiplier := 2.0     # her top speed × this while the boost lasts (2 = double)
@export var boost_time := 1.0           # seconds the boost lasts
@export var boost_accel := 4.0          # how quickly she picks up the extra speed (her usual is boat.gd's accel, 1)
@export var shake_strength := 0.2       # the little screen shake when she catches it (metres)…
@export var shake_time := 0.15          # …and how long it lasts (seconds)

@onready var picture: MeshInstance3D = $Picture


func _ready() -> void:
	_fit_sensor()
	_fit_picture()
	if Engine.is_editor_hint():
		return
	# Its own copy of the material, starting at a random frame, so two gusts don't whirl in step.
	picture.material_override = picture.material_override.duplicate()
	picture.material_override.set_shader_parameter("phase", randf() * 16.0)
	# The physics engine calls this when the boat's sensor comes in (OnBeginOverlap in Unreal).
	$Sensor.area_entered.connect(_on_sensor_entered)


## The boat came in: the boost, the shake and the whoosh.
func _on_sensor_entered(area: Area3D) -> void:
	var boat := area.get_parent() as Node3D
	if boat == null or not boat.is_in_group("player_boat"):
		return
	if boat.sinking or boat.anchored:
		return                                 # at anchor or tied up she isn't sailing: nothing to boost
	boat.boost(speed_multiplier, boost_time, boost_accel)   # boat.gd: a higher top speed for a while
	boat.camera.shake_hard(shake_strength, shake_time)      # boat_camera.gd
	Sfx.gust_whoosh()


## The sensor's cylinder is as wide as `radius` (its own copy of the shape: local to scene in gust.tscn).
## get_node_or_null: the setter can run while the scene is still being loaded, before the nodes exist.
func _fit_sensor() -> void:
	var shape_node := get_node_or_null("Sensor/Shape") as CollisionShape3D
	if shape_node and shape_node.shape:
		shape_node.shape.radius = radius


## The picture (a 1 m square) scaled to the circle's width, so what you see is what she has to hit.
func _fit_picture() -> void:
	var plane := get_node_or_null("Picture") as Node3D
	if plane:
		plane.scale = Vector3(radius * 2.0, 1.0, radius * 2.0)

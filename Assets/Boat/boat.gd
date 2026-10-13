extends Node3D
## The player's boat (like a Pawn in Unreal): she sails by the wind, turns with the rudder,
## stops at anchor. The wheel (ui/helm) finds her through the group "player_boat" and sets
## her rudder; Space works the anchor. Her camera follows her without turning.
## 1 unit = 10 px of the HTML prototype.

@export var top_speed := 4.2        # units/s with the sail at its best (~42 px/s in the prototype)
@export var accel := 0.9            # how quickly she gathers way (higher = quicker)
@export var anchor_bite := 4.0      # how quickly the anchor stops her
@export var turn_rate := 1.2        # rad/s at full rudder once she has way on
@export var heel_max_deg := 10.0    # how far she leans with the wind on the sail
@export var camera_tilt_deg := 30.0 # the camera's tilt from straight down (the prototype's BOAT_TILT look)

# The Marconi sail's curve: [degrees off the wind, share of top speed] (SAIL_POLAR_MARCONI)
const POLAR := [[0.0, 0.0], [5.0, 0.4], [10.0, 0.8], [15.0, 1.0], [180.0, 1.0]]

var rudder := 0.0      # -1 (port, left) .. 1 (starboard, right)
var speed := 0.0
var anchored := true   # she starts at anchor: hold the wheel's hub (or press Space) to weigh it

@onready var model: Node3D = $Model
@onready var rig: Node3D = $Model/Rig
@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	add_to_group("player_boat")
	camera.top_level = true   # it follows her position but not her turning

func set_rudder(v: float) -> void:
	rudder = clampf(v, -1.0, 1.0)

func toggle_anchor() -> void:
	anchored = not anchored

func polar(off_deg: float) -> float:
	for i in range(1, POLAR.size()):
		if off_deg <= POLAR[i][0]:
			var a = POLAR[i - 1]
			var b = POLAR[i]
			return lerpf(a[1], b[1], (off_deg - a[0]) / (b[0] - a[0]))
	return POLAR[-1][1]

func _physics_process(dt: float) -> void:
	# the keyboard: Space / Enter works the anchor (the arrows turn the wheel, in ui/helm)
	if Input.is_action_just_pressed("ui_accept"):
		toggle_anchor()

	var fwd := -global_transform.basis.z                        # Godot's forward is -Z
	var wind_from: Vector3 = Wind.from_vector()                 # the wind (Assets/Landscape/world/wind.gd)
	var off := rad_to_deg(fwd.angle_to(wind_from))               # 0 = head to wind, 180 = wind astern
	var drive := 0.0 if anchored else polar(off)

	# speed eases toward what the sail gives; the anchor takes her way off quickly
	var target := top_speed * drive
	speed += (target - speed) * minf(1.0, dt * (anchor_bite if anchored else accel))

	# she turns only with way on (and not at anchor)
	var way := clampf(speed / top_speed * 1.5, 0.0, 1.0)
	if not anchored:
		rotate_y(-rudder * turn_rate * maxf(way, 0.25) * dt)
	global_position += fwd * speed * dt

	# the look: heel away from the wind, the boom out to leeward, a gentle bob
	var side := signf(global_transform.basis.x.dot(wind_from))   # + = wind from starboard
	model.rotation.z = lerpf(model.rotation.z, side * deg_to_rad(heel_max_deg) * drive, dt * 2.0)
	var boom := side * deg_to_rad(clampf(off * 0.5, 8.0, 80.0))
	rig.rotation.y = lerpf(rig.rotation.y, boom if drive > 0.0 else 0.0, dt * 2.0)
	model.position.y = sin(Time.get_ticks_msec() * 0.0013) * 0.04

func _process(_dt: float) -> void:
	# the camera: from the south, tilted, always the same way up (like a spring arm that doesn't rotate)
	var t := deg_to_rad(camera_tilt_deg)
	camera.global_position = global_position + Vector3(0.0, cos(t), sin(t)) * 40.0
	camera.global_rotation = Vector3(-(PI / 2.0 - t), 0.0, 0.0)

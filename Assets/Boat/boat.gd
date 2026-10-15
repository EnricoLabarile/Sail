extends Node3D
## The player's boat (like a Pawn in Unreal): she sails by the wind, turns with the rudder,
## stops at anchor. The wheel (ui/helm) finds her through the group "player_boat" and sets
## her rudder; Space works the anchor. Her camera follows her without turning.
## 1 unit = 10 px of the HTML prototype.

@export var top_speed := 4.2        # units/s with the sail at its best (~42 px/s in the prototype)
@export var accel := 0.9            # how quickly she gathers way (higher = quicker)
@export var anchor_bite := 4.0      # how quickly the anchor stops her
@export var turn_rate := 1.2        # rad/s at full rudder once she has way on
@export var bow_reach := 2.2        # metres from her middle to the bow: the shore stops her there
@export var heel_max_deg := 10.0    # how far she leans with the wind on the sail
@export var camera_tilt_deg := 30.0 # the camera's tilt from straight down (the prototype's BOAT_TILT look)
@export var sail_fill_rate := 2.0   # how quickly the sail fills or empties (higher = quicker)

# The Marconi sail's curve: [degrees off the wind, share of top speed] (SAIL_POLAR_MARCONI)
const POLAR := [[0.0, 0.0], [5.0, 0.4], [10.0, 0.8], [15.0, 1.0], [180.0, 1.0]]

var rudder := 0.0      # -1 (port, left) .. 1 (starboard, right)
var speed := 0.0
var anchored := true   # she starts at anchor: hold the wheel's hub (or press Space) to weigh it
var belly := 0.0       # how full the sail is: -1 full to port (left), 0 flat, +1 full to starboard (right)

@onready var model: Node3D = $Model
@onready var rig: Node3D = $Model/Rig
@onready var camera: Camera3D = $Camera3D

# The sail's mesh: the MeshInstance3D inside the imported sm_boat_sail (the FBX makes it a little scene
# of its own, so we look for the first MeshInstance3D inside it).
@onready var sail_mesh: MeshInstance3D = $Model/Rig/sm_boat_sail.find_children("*", "MeshInstance3D")[0]
# The numbers of its two shape keys (made in Blender). find_blend_shape_by_name gives -1 if there's none.
@onready var key_right: int = sail_mesh.find_blend_shape_by_name("Inflated_Right")   # belly to starboard
@onready var key_left: int = sail_mesh.find_blend_shape_by_name("Inflated_Left")     # belly to port

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
	move_unless_land(fwd * speed * dt)

	# the look: heel away from the wind, the boom out to leeward, a gentle bob
	var side := signf(global_transform.basis.x.dot(wind_from))   # + = wind from starboard
	model.rotation.z = lerpf(model.rotation.z, side * deg_to_rad(heel_max_deg) * drive, dt * 2.0)
	# The boom swings out to leeward, the side away from the wind: wind from starboard (side = +1)
	# puts the sail out to port. A positive rotation.y turns the rig anticlockwise seen from above,
	# which swings the boom (behind the mast) over to starboard: so the sign is the opposite of `side`.
	var boom := -side * deg_to_rad(clampf(off * 0.5, 8.0, 80.0))
	rig.rotation.y = lerpf(rig.rotation.y, boom if drive > 0.0 else 0.0, dt * 2.0)
	model.position.y = sin(Time.get_ticks_msec() * 0.0013) * 0.04
	update_sail_belly(dt, side)

## The sail fills with the wind: the faster she goes, the fuller it is, and the belly is always on the
## side away from the wind (to leeward, like the boom). Uses the two shape keys made in Blender.
## side: +1 if the wind comes from starboard, -1 if from port (worked out in _physics_process).
func update_sail_belly(dt: float, side: float) -> void:
	# 1. How full: her speed as a share of her top speed (0 = still, 1 = full speed).
	var fullness := clampf(speed / top_speed, 0.0, 1.0)
	# 2. Which way: away from the wind. Wind from port (side = -1) fills it to starboard (+).
	var target := -side * fullness
	# 3. Change it gently, not all at once. When she changes tack the target jumps to the other side,
	#    and belly slides there through 0: the sail empties, goes flat, and fills on the other side.
	belly = lerpf(belly, target, minf(1.0, dt * sail_fill_rate))
	# 4. Share it out to the two shape keys: one gets the belly, the other stays at 0.
	#    (maxf(belly, 0) is belly when it's positive and 0 when it's negative.)
	if key_right >= 0:
		sail_mesh.set_blend_shape_value(key_right, maxf(belly, 0.0))
	if key_left >= 0:
		sail_mesh.set_blend_shape_value(key_left, maxf(-belly, 0.0))


## Moves her by `step`, unless that would put her middle or her bow on land (the Land autoload,
## which reads map_collision.png). On the shore she just stops: speed 0. She can still turn away
## (slowly, see turn_rate) and sail off again.
func move_unless_land(step: Vector3) -> void:
	var next := global_position + step                  # where she would be
	var fwd := -global_transform.basis.z
	var next_bow := next + fwd * bow_reach               # where her bow would be
	if Land.is_land(next) or Land.is_land(next_bow):
		speed = 0.0                                      # aground: she stops
	else:
		global_position = next


func _process(_dt: float) -> void:
	# the camera: from the south, tilted, always the same way up (like a spring arm that doesn't rotate)
	var t := deg_to_rad(camera_tilt_deg)
	camera.global_position = global_position + Vector3(0.0, cos(t), sin(t)) * 40.0
	camera.global_rotation = Vector3(-(PI / 2.0 - t), 0.0, 0.0)

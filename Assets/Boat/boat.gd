extends Node3D
## The player's boat (like a Pawn in Unreal): she sails by the wind, turns with the rudder,
## stops at anchor. The wheel (ui/helm) finds her through the group "player_boat" and sets
## her rudder; Space works the anchor. Her camera follows her without turning.
## 1 unit = 10 px of the HTML prototype.

@export var top_speed := 4.2        # units/s with the sail at its best (~42 px/s in the prototype)
@export var accel := 0.9            # how quickly she gathers way (higher = quicker)
@export var anchor_bite := 4.0      # how quickly the anchor stops her
@export var turn_rate := 1.5        # rad/s at full rudder once she has way on
@export var bow_reach := 2.2        # metres from her middle to the bow: the shore stops her there
@export var heel_max_deg := 15    # how far she leans with the wind on the sail
@export var camera_tilt_deg := 45 # the camera's tilt from straight down (the prototype's BOAT_TILT look)
@export var sail_fill_rate := 1   # how quickly the sail fills or empties (higher = quicker)
@export var boom_max_deg := 90    # the furthest the sail swings out from the boat's middle line, either side

# The shallows: near the coast there's less wind, so the sail gives less.
@export var shallows_width := 6.0   # metres from the land that count as shallows (the grey band on the map)
@export var shallows_sail := 0.3    # what the sail gives there, as a share of the usual (0.3 = 30%)

# The current (the HTML prototype's CURRENT_DRIFT): the wind sets the water moving, and the water carries her
# downwind whatever the sail does, so she must steer to make up for it. None at anchor (the anchor holds her).
@export var current_speed := 1.5    # m/s the current carries her downwind (18 px/s in the prototype)
@export var current_ease := 0.8     # how quickly it takes hold after weighing anchor (and lets go when it's dropped)

# Bumping into the shore (the HTML prototype's impact()): she bounces back off it.
@export var bounce_kick := 7     # m/s of push away from the shore on any bump…
@export var bounce_extra := 0.9     # …plus this much of the speed she hit it with
@export var bounce_fade := 3.5      # how quickly the push dies away (higher = shorter)
@export var bounce_slowdown := 0.25 # her speed is multiplied by this (0.25 = a quarter left)
@export var bounce_min_speed := 0.4 # m/s: slower than this into the shore, it's a nudge, not a bump
@export var bounce_cooldown := 0.6  # s after a bump before the next one counts (one bump, not one per frame)

# The Marconi sail's curve: [degrees off the wind, share of top speed] (SAIL_POLAR_MARCONI)
const POLAR := [[0.0, 0.0], [30.0, 0.4], [45.0, 0.8], [90.0, 1.0], [180.0, 1.0]]

var rudder := 0.0      # -1 (port, left) .. 1 (starboard, right)
var speed := 0.0
var anchored := true   # she starts at anchor: hold the wheel's hub (or press Space) to weigh it
var belly := 0.0       # how full the sail is: -1 full to port (left), 0 flat, +1 full to starboard (right)
var knock := Vector3.ZERO   # the push of a bump (m/s, a direction on the sea): added to her motion, fades away
var drift := Vector3.ZERO   # the current's push (m/s, downwind): added to her motion
var drift_amount := 0.0     # 0..1: how much the current has her (eases in and out, see current_ease)
var bump_wait := 0.0        # seconds left before another bump can count

# The parts the code moves. find_child("Name") looks for a node with that name anywhere inside the boat
# (children, children of children, and so on), so you can rearrange the hierarchy freely: only the
# NAMES must stay the same. ($Model, with the $, is a fixed address: it must be a direct child of Boat.)
@onready var model: Node3D = $Model            # heels and bobs: everything inside it follows
@onready var rig: Node3D = find_child("Rig")   # turns round the mast: the sail (and boom) inside it swing out
@onready var camera: Camera3D = $Camera3D

# The sail's mesh: the MeshInstance3D inside the imported sm_boat_sail (the FBX makes it a little scene
# of its own, so we look for the first MeshInstance3D inside it).
@onready var sail_mesh: MeshInstance3D = find_child("sm_boat_sail").find_children("*", "MeshInstance3D")[0]
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
	# In the shallows (land within shallows_width metres) the sail gives only shallows_sail of its push.
	if Land.is_near_land(global_position, shallows_width):
		drive *= shallows_sail

	# speed eases toward what the sail gives; the anchor takes her way off quickly
	var target := top_speed * drive
	speed += (target - speed) * minf(1.0, dt * (anchor_bite if anchored else accel))

	# she turns only with way on (and not at anchor)
	var way := clampf(speed / top_speed * 1.5, 0.0, 1.0)
	if not anchored:
		rotate_y(-rudder * turn_rate * maxf(way, 0.25) * dt)
	update_current(dt, wind_from)
	move_and_bounce(dt)
	Fog.reveal(global_position)                                 # clear the fog round her (fog.gd)

	# the look: heel away from the wind, the boom out to leeward, a gentle bob
	var side := signf(global_transform.basis.x.dot(wind_from))   # + = wind from starboard
	model.rotation.z = lerpf(model.rotation.z, side * deg_to_rad(heel_max_deg) * drive, dt * 2.0)
	# The boom swings out to leeward, the side away from the wind: wind from starboard (side = +1)
	# puts the sail out to port. A positive rotation.y turns the rig anticlockwise seen from above,
	# which swings the boom (behind the mast) over to starboard: so the sign is the opposite of `side`.
	# How far out: half the wind's angle off the bow, but never less than 8 degrees and never more than
	# boom_max_deg (30), so the sail never stands across the boat.
	var boom := -side * deg_to_rad(clampf(off * 0.5, 8.0, boom_max_deg))
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


## Moves her for this frame: her own way (forward × speed) plus the push of a bump (knock).
## If that would put her middle or her bow on land (the Land autoload), she doesn't go there:
## she bumps (see bump) and bounces back off the shore.
func move_and_bounce(dt: float) -> void:
	bump_wait = maxf(0.0, bump_wait - dt)
	knock *= exp(-bounce_fade * dt)                      # the push of the last bump dies away

	var fwd := -global_transform.basis.z
	var own_way := fwd * speed                           # her own way, from the sail
	var velocity := own_way + knock + drift              # how she's moving now, in m/s (her way + a bump's push + the current)
	var next := global_position + velocity * dt          # where she would be
	var next_bow := next + fwd * bow_reach               # where her bow would be

	# Which point would touch land? (none: just go)
	var touching := Vector3.INF
	if Land.is_land(next_bow):
		touching = next_bow
	elif Land.is_land(next):
		touching = next
	if touching == Vector3.INF:
		global_position = next
		return

	# She'd touch land. Which way is the open sea from there?
	var out := Land.way_to_sea(touching)
	if out == Vector3.ZERO:
		speed = 0.0                                      # land all round that point: never go there
		return
	if velocity.dot(out) >= 0.0:
		global_position = next                           # all in all moving away from it (e.g. the push): let her go
		return
	# Moving into the shore: she stays put this frame. It's a bump only if her OWN way takes her into it
	# (as in the prototype); if it's just the current pressing her against the shore, she simply stays there.
	var into := -own_way.dot(out)                        # how fast her own way goes INTO the shore (m/s)
	if into > 0.0:
		bump(out, into)


## The current: downwind (the opposite of where the wind comes from), at current_speed.
## It eases in after the anchor is weighed and eases out when it's dropped (drift_amount 0..1).
func update_current(dt: float, wind_from: Vector3) -> void:
	var target := 0.0 if anchored else 1.0
	drift_amount += (target - drift_amount) * minf(1.0, dt * current_ease)
	drift = -wind_from * current_speed * drift_amount


## A bump against the shore: `out` is the way to the open sea, `into` how fast she hit (m/s).
## As in the HTML prototype: a push back out, much less speed, the bow swung off a little.
func bump(out: Vector3, into: float) -> void:
	speed *= bounce_slowdown                             # she loses most of her way
	if bump_wait > 0.0 or into < bounce_min_speed:
		return                                           # just a nudge, or the same bump as a moment ago
	bump_wait = bounce_cooldown

	# 1. The push away from the shore: a bit more the harder she hit.
	knock += out * (bounce_kick + into * bounce_extra)

	# 2. The bow swings off, so she doesn't hit the same spot again. Which way? Away from the shore:
	#    the "cross" of her heading and the way out says if the sea is on her left or her right.
	var fwd := -global_transform.basis.z
	var turn_side := signf(fwd.cross(out).y)
	if turn_side == 0.0:
		turn_side = 1.0 if randf() < 0.5 else -1.0          # head-on: either way
	var swing := minf(0.3, 0.08 + into / top_speed * 0.25)  # radians, at most about 17 degrees
	rotate_y(turn_side * swing)


func _process(_dt: float) -> void:
	# the camera: from the south, tilted, always the same way up (like a spring arm that doesn't rotate)
	var t := deg_to_rad(camera_tilt_deg)
	camera.global_position = global_position + Vector3(0.0, cos(t), sin(t)) * 40.0
	camera.global_rotation = Vector3(-(PI / 2.0 - t), 0.0, 0.0)

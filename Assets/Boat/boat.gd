extends Node3D
## The player's boat (like a Pawn in Unreal): she sails by the wind, turns with the rudder,
## stops at anchor. The wheel (ui/helm) finds her through the group "player_boat" and sets
## her rudder; Space works the anchor. Her camera follows her without turning.
## 1 unit = 10 px of the HTML prototype.

@export var top_speed := 5        # m/s with the sail at its best (doubled by Enrico; the prototype had ~4.2)
@export var accel := 0.9            # how quickly she gathers way (higher = quicker)
@export var anchor_bite := 4.0      # how quickly the anchor stops her
@export var turn_rate := 2.25       # rad/s at full rudder, whatever her speed (Enrico: between the old 1.5 and 3)
@export var bow_reach := 2.2        # metres from her middle to the bow: the shore stops her there
@export var heel_max_deg := 5		    # how far she leans with the wind on the sail
@export var camera_tilt_deg := 45 # the camera's tilt from straight down (the prototype's BOAT_TILT look)
# How far the camera sits from her, along the way it looks. It's orthographic (no perspective), so this
# doesn't change the picture at all: it only has to be far enough that tall things (the clouds, 15 m up)
# near the bottom of the screen don't end up behind the camera's near plane and get cut off.
@export var camera_distance := 100.0
@export var sail_fill_rate := 2   # how quickly the sail fills or empties (higher = quicker)
@export var boom_max_deg := 90    # the furthest the sail swings out from the boat's middle line, either side

# Turning: she leans out of the turn (the prototype's "lean out of a turn"), more the quicker she turns
# and the faster she goes.
@export var turn_lean_deg := 5.0   # how far she leans turning at turn_rate at top_speed, in degrees (the prototype's)

# Speeding up and slowing down: the bow lifts as she gathers way and dips as she slows (as in the prototype).
@export var surge_pitch_deg := 5      # degrees the bow lifts for every m/s² she speeds up (dips the same slowing down)
@export var surge_pitch_max_deg := 4.5  # never more than this, either way

# How she leans and pitches: not straight to where she should be, but like a weight on a spring, so she
# swings a little past it and settles (the prototype's damped springs). This is what makes her feel alive.
@export var roll_stiffness := 16.0      # how strongly the roll is pulled to where it should be (higher = snappier)
@export var roll_damping := 3.2         # how quickly the swinging dies away (lower = more swinging)
@export var pitch_stiffness := 22.0     # the same for the pitch (bow up and down)
@export var pitch_damping := 4.5

# The anchor (the prototype's ANCHOR_RODE): it stays where it fell, off the bow. The current carries her
# until the line is taut; then the line holds her bow and she swings round the anchor, stern downstream.
@export var anchor_rode := 3.0          # metres of anchor line from the bow to the anchor
@export var furl_rate := 2.2            # how quickly the sail is gathered up when the anchor goes down…
@export var unfurl_rate := 3.5          # …and spread again when it comes up (higher = quicker)
@export var furled_height := 0.06       # how tall the sail is when gathered up, as a share of its full height

# The ink outline round her (Assets/Boat/boat_outline.gdshader).
@export var outline_width := 1.5        # how thick, in phone points (0 = no outline)

# The waves: she rocks gently on them, side to side (roll) and bow to stern (pitch).
@export var wave_roll_deg := 3.0    # how far she rolls each way on the waves, in degrees
@export var wave_pitch_deg := 2.0   # how far the bow rises and dips on the waves, in degrees
@export var wave_period := 3.0      # seconds for one wave to pass under her (higher = slower rocking)

# The shallows: near the coast there's less wind, so the sail gives less.
@export var shallows_width := 6.0   # metres from the land that count as shallows
@export var shallows_sail := 0.3    # what the sail gives there, as a share of the usual (0.3 = 30%)
# The bow wave (boat.tscn: BowWaveRight / BowWaveLeft, bow_wave.png, a 4 x 4 flipbook).
@export var bow_wave_fps := 12.0        # frames a second it plays at top speed (slower when slower)
@export var bow_wave_min_size := 0.4    # its size at a crawl, as a share of full size (full at top speed)
@export var shallows_check_time := 0.2   # seconds between looks for land nearby (it's up to 48 rays: not every frame)

# The current (the HTML prototype's CURRENT_DRIFT): the wind sets the water moving, and the water carries her
# downwind whatever the sail does, so she must steer to make up for it. At anchor too: the anchor line holds her.
@export var current_speed := 1   # m/s the current carries her downwind (18 px/s in the prototype)
@export var current_ease := 0.8     # how quickly it takes hold at the start

# Bumping into the shore (the HTML prototype's impact()): she bounces back off it.
@export var bounce_kick := 7     # m/s of push away from the shore on any bump…
@export var bounce_extra := 0.9     # …plus this much of the speed she hit it with
@export var bounce_fade := 3.5      # how quickly the push dies away (higher = shorter)
@export var bounce_slowdown := 0.25 # her speed is multiplied by this (0.25 = a quarter left)
@export var bounce_min_speed := 0.4 # m/s: slower than this into the shore, it's a nudge, not a bump
@export var bounce_cooldown := 0.6  # s after a bump before the next one counts (one bump, not one per frame)

# The Marconi sail's curve: [degrees off the wind, share of top speed] (SAIL_POLAR_MARCONI)
const POLAR := [[0.0, 0.0], [15.0, 0.4], [30.0, 0.1], [45.0, 1.5], [180.0, 1.0]]

var rudder := 0.0      # -1 (port, left) .. 1 (starboard, right)
var speed := 0.0
var bow_wave_strength := 0.0   # how solid the bow wave is now, 0..1 (eased toward her speed share)
var bow_wave_frame := 0.0      # the bow wave's flipbook frame, counting up
var in_shallows := false     # land within shallows_width? (looked again every shallows_check_time seconds)
var shallows_wait := 0.0     # seconds left before the next look
var anchored := true   # she starts at anchor: hold the wheel's hub (or press Space) to weigh it
var belly := 0.0       # how full the sail is: -1 full to port (left), 0 flat, +1 full to starboard (right)
var knock := Vector3.ZERO   # the push of a bump (m/s, a direction on the sea): added to her motion, fades away
var drift := Vector3.ZERO   # the current's push (m/s, downwind): added to her motion
var drift_amount := 0.0     # 0..1: how much the current has her (eases in and out, see current_ease)
var bump_wait := 0.0        # seconds left before another bump can count
var heel := 0.0             # how far she leans with the wind (radians), without the waves' roll
var last_speed := 0.0       # her speed a frame ago (to work out how quickly it changes)
var turn_speed := 0.0       # how quickly she is turning now, in rad/s (+ = to the left), measured each frame
var roll := 0.0             # her lean now (radians, + = to port), and how quickly it's changing (the spring)
var roll_velocity := 0.0
var pitch := 0.0            # the bow's angle now (radians, + = up), and how quickly it's changing
var pitch_velocity := 0.0
var anchor_point := Vector3.ZERO   # where the anchor lies on the bottom (set when it's dropped)
var model_height := 0.0      # Model's height as placed in the editor (read at start): she bobs round it
var furl := 1.0             # 0 = sail spread, 1 = gathered up on the boom (she starts at anchor: gathered up)

# The parts the code moves. find_child("Name") looks for a node with that name anywhere inside the boat
# (children, children of children, and so on), so you can rearrange the hierarchy freely: only the
# NAMES must stay the same. ($Model, with the $, is a fixed address: it must be a direct child of Boat.)
@onready var model: Node3D = $Model            # heels and bobs: everything inside it follows
@onready var rig: Node3D = find_child("Rig")   # turns round the mast: the sail (and boom) inside it swing out
@onready var camera: Camera3D = $Camera3D
@onready var wake: CPUParticles3D = find_child("Wake")          # the dots left behind the stern
@onready var bow_wave_right: Node3D = find_child("BowWaveRight") # the water thrown up and out at the bow (Wind
@onready var bow_wave_left: Node3D = find_child("BowWaveLeft")   # Waker's "wings"; bow_wave.gdshader), a side each
@onready var sail_node: Node3D = find_child("sm_boat_sail")   # the whole sail: squashed down onto the boom to furl it

# The sail's mesh: the MeshInstance3D inside the imported sm_boat_sail (the FBX makes it a little scene
# of its own, so we look for the first MeshInstance3D inside it).
@onready var sail_mesh: MeshInstance3D = find_child("sm_boat_sail").find_children("*", "MeshInstance3D")[0]
# The numbers of its two shape keys (made in Blender). find_blend_shape_by_name gives -1 if there's none.
@onready var key_right: int = sail_mesh.find_blend_shape_by_name("Inflated_Right")   # belly to starboard
@onready var key_left: int = sail_mesh.find_blend_shape_by_name("Inflated_Left")     # belly to port

func _ready() -> void:
	add_to_group("player_boat")
	camera.top_level = true   # it follows her position but not her turning
	anchor_point = bow_point()   # she starts at anchor: it lies off her bow
	model_height = model.position.y   # how deep she sits: wherever Model was placed in boat.tscn
	add_water_mask()
	add_outline()


## The ink outline round the boat (Assets/Boat/boat_outline.gdshader): a rectangle in front of the
## camera that the shader stretches over the whole screen. Made here in code (and not in the scene) so it
## doesn't cover the editor's view.
func add_outline() -> void:
	var outline := ShaderMaterial.new()
	outline.shader = load("res://Assets/Boat/boat_outline.gdshader")
	outline.render_priority = 1                 # drawn after the sea (0), so the line sits on the water
	outline.set_shader_parameter("outline_width", outline_width)
	var quad := QuadMesh.new()
	quad.material = outline
	var screen := MeshInstance3D.new()
	screen.mesh = quad
	screen.extra_cull_margin = 16384.0         # never skipped as "out of view" (the shader moves it)
	screen.position = Vector3(0.0, 0.0, -1.0)  # just in front of the camera
	camera.add_child(screen)


## Puts the boat's mask (Assets/Boat/boat_mask.gdshader) on the INSIDE of the hull only, as a
## material_overlay: an extra invisible layer that marks those pixels, so the sea doesn't draw over them.
## Everything else (the outside of the hull, mast, sail) has no mask: where it sits below the water
## (y = 0) the sea covers it, so she looks partly sunk in the water, as a real boat.
## The inside is any mesh with "inner" in its name, or in its parent's name (e.g. sm_boat_hull_inner,
## made in Blender as an object of its own): the floor of the boat lies below the water line, and
## without the mask the sea would cover it.
func add_water_mask() -> void:
	var mask := ShaderMaterial.new()
	mask.shader = load("res://Assets/Boat/boat_mask.gdshader")
	mask.render_priority = -1    # among the see-through things, drawn before the sea (which has 0)
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var names: String = (String(mesh.name) + " " + String(mesh.get_parent().name)).to_lower()
		if names.contains("inner"):
			mesh.material_overlay = mask

func set_rudder(v: float) -> void:
	rudder = clampf(v, -1.0, 1.0)

func toggle_anchor() -> void:
	anchored = not anchored
	if anchored:
		anchor_point = bow_point()   # let go off the bow: it stays there
	Sfx.anchor(anchored)             # its sound: the splash going down, the chain coming up (Assets/SFX/sfx.gd)


## Where her bow is now, on the water.
func bow_point() -> Vector3:
	var fwd := -global_transform.basis.z
	return global_position + fwd * bow_reach

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
	# Looking for land takes up to 48 rays, so it's done every shallows_check_time seconds, not every frame.
	shallows_wait -= dt
	if shallows_wait <= 0.0:
		shallows_wait = shallows_check_time
		in_shallows = Land.is_near_land(global_position, shallows_width)
	if in_shallows:
		drive *= shallows_sail

	# speed eases toward what the sail gives; the anchor takes her way off quickly
	var target := top_speed * drive
	speed += (target - speed) * minf(1.0, dt * (anchor_bite if anchored else accel))

	# She turns at the same rate whatever her speed, as in the prototype; not at anchor.
	var yaw_before := rotation.y
	if not anchored:
		rotate_y(-rudder * turn_rate * dt)
	update_current(dt, wind_from)
	move_and_bounce(dt)
	hold_at_anchor()
	# How quickly she really turned this frame (the rudder, a bump, the anchor line swinging her):
	# wrapf keeps the difference between -PI and PI when the angle goes round past 180 degrees.
	turn_speed = wrapf(rotation.y - yaw_before, -PI, PI) / dt
	Fog.reveal(global_position)                                 # clear the fog round her (fog.gd)

	# the look: heel away from the wind, the boom out to leeward, a gentle bob
	var side := signf(global_transform.basis.x.dot(wind_from))   # + = wind from starboard
	heel = side * deg_to_rad(heel_max_deg) * drive
	rock_and_roll(dt)
	# The boom swings out to leeward, the side away from the wind: wind from starboard (side = +1)
	# puts the sail out to port. A positive rotation.y turns the rig anticlockwise seen from above,
	# which swings the boom (behind the mast) over to starboard: so the sign is the opposite of `side`.
	# How far out: half the wind's angle off the bow, but never less than 8 degrees and never more than
	# boom_max_deg (30), so the sail never stands across the boat.
	var boom := -side * deg_to_rad(clampf(off * 0.5, 8.0, boom_max_deg))
	rig.rotation.y = lerpf(rig.rotation.y, boom if drive > 0.0 else 0.0, dt * 2.0)
	# A gentle bob up and down, round the height Model has in the scene (set it there to sink her more or less).
	model.position.y = model_height + sin(Time.get_ticks_msec() * 0.0013) * 0.04
	update_sail_belly(dt, side)
	update_furl(dt)
	update_water_fx(dt)

## How she leans (roll) and how her bow rises and dips (pitch). First where she should be:
##   roll  = the heel from the wind + the lean out of a turn + the waves' roll
##   pitch = the bow lifting as she speeds up (dipping as she slows) + the waves' pitch
## Then, instead of jumping there, she is pulled there like a weight on a spring (a damped spring):
## she swings a little past it and settles. That swing is what makes the boat feel alive when you turn.
func rock_and_roll(dt: float) -> void:
	# 1. The lean out of a turn: as in the prototype, how quickly she turns × how fast she goes.
	#    Turning right, turn_speed is negative and she leans left (+), so the sign is flipped.
	var turn_share := -turn_speed / turn_rate          # 1 = turning right at turn_rate
	var speed_share := speed / top_speed               # 1 = at top speed
	var turn_lean := turn_share * speed_share * deg_to_rad(turn_lean_deg)

	# 2. The bow and her speed: how quickly her speed changes (m/s every second), in degrees, kept within
	#    surge_pitch_max_deg either way.
	var acceleration := (speed - last_speed) / dt
	last_speed = speed
	var max_surge := deg_to_rad(surge_pitch_max_deg)
	var surge := clampf(acceleration * deg_to_rad(surge_pitch_deg), -max_surge, max_surge)

	# 3. The waves: two slow sine waves (pitch a little quicker than roll, so they don't move in step).
	#    TAU (2 x pi) / period makes one full swing take `period` seconds.
	var seconds := Time.get_ticks_msec() / 1000.0
	var wave_roll := sin(seconds * TAU / wave_period) * deg_to_rad(wave_roll_deg)
	var wave_pitch := sin(seconds * TAU / (wave_period * 0.8)) * deg_to_rad(wave_pitch_deg)

	# 4. Where she should be.
	var roll_target := heel + turn_lean + wave_roll
	var pitch_target := surge + wave_pitch

	# 5. The springs: the further she is from the target, the harder she's pulled toward it (stiffness);
	#    the faster she's moving, the more that's held back (damping). velocity changes the angle.
	roll_velocity += (roll_stiffness * (roll_target - roll) - roll_damping * roll_velocity) * dt
	roll += roll_velocity * dt
	pitch_velocity += (pitch_stiffness * (pitch_target - pitch) - pitch_damping * pitch_velocity) * dt
	pitch += pitch_velocity * dt
	# never further than the prototype allowed: about 34 degrees of roll, 17 of pitch
	roll = clampf(roll, -0.6, 0.6)
	pitch = clampf(pitch, -0.3, 0.3)

	model.rotation.z = roll    # z: round her length, so she leans left (+) and right (-)
	model.rotation.x = pitch   # x: across her, so the bow goes up (+) and down (-)


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


## At anchor the line is a pivot. The anchor stays where it fell. While the line is slack she drifts
## freely (the current carries her); once her bow is anchor_rode metres from the anchor, the taut line
## holds the bow there, and the hull trails behind it the way it's pushed: she swings round the anchor,
## bow to the anchor, stern downstream. (The prototype's anchorPt.)
func hold_at_anchor() -> void:
	if not anchored:
		return
	var bow := bow_point()
	var from_anchor := bow - anchor_point
	from_anchor.y = 0.0
	var distance := from_anchor.length()
	# Carried very far off some other way (a bump, say): the anchor drags and bites again where she is.
	if distance > anchor_rode * 4.0:
		anchor_point = bow
		return
	# Slack line: nothing to do, she drifts.
	if distance <= anchor_rode:
		return
	# 1. Taut line: the bow can go no further than anchor_rode from the anchor.
	bow = anchor_point + from_anchor / distance * anchor_rode
	# 2. The hull trails from the bow, the way it was being pushed: her middle goes back to bow_reach
	#    metres from the bow, along the line from the bow to where her middle is now.
	var bow_to_middle := global_position - bow
	bow_to_middle.y = 0.0
	var back := bow_to_middle.normalized()
	global_position = bow + back * bow_reach
	# 3. She faces the anchor: her forward (-Z) points from her middle to her bow, the opposite of `back`.
	#    A turn of rotation.y = a points her +Z along (sin a, 0, cos a), so a = atan2(back.x, back.z).
	rotation.y = atan2(back.x, back.z)
	# 4. The line takes her way off.
	speed = minf(speed, 0.0)
	knock *= 0.5


## At anchor the sail is gathered up onto the boom (only a look: as in the prototype); it spreads
## again as the anchor comes up. Done by squashing the sail's node down (scale.y) onto the boom.
## The wake (the CPUParticles3D node in boat.tscn, like a small CPU Niagara emitter: its look is set in the
## Inspector). Here only how fast it runs: the slower she goes, the slower it plays (speed_scale), so fewer
## dots come out and they drift aside more slowly. That keeps the dots the same distance apart on the water
## whatever her speed, as in the HTML prototype (a dot every 0.7 m). Nothing when she's (almost) still or at
## anchor; the dots already out fade by themselves.
## Then the bow wave (update_bow_wave).
func update_water_fx(dt: float) -> void:
	var k := clampf(speed / top_speed, 0.0, 1.0)   # 0 = still, 1 = top speed
	var on := k > 0.06 and not anchored            # the prototype's "none below 6% of top speed"
	if wake:
		wake.emitting = on
		# never slower than 0.35, or the last dots would hang on the water for ages
		wake.speed_scale = maxf(k, 0.35) if on else 1.0
	update_bow_wave(dt, k, on)


## The bow wave (Wind Waker's wings of water at the bow): two flat pictures, a side each, playing a flipbook
## (bow_wave.gdshader, one material shared by both). The faster she goes, the longer and taller they are, the
## faster the flipbook plays and the more solid they get; still or at anchor they fade away.
func update_bow_wave(dt: float, k: float, on: bool) -> void:
	if bow_wave_right == null or bow_wave_left == null:
		return
	# 1. How solid: eases toward k while she moves (0 when not), so it grows and fades smoothly.
	var target := k if on else 0.0
	bow_wave_strength = lerpf(bow_wave_strength, target, minf(1.0, dt * 4.0))
	# 2. Which frame: counted up at bow_wave_fps × how fast she goes (the shader shows it counted round).
	bow_wave_frame += dt * bow_wave_fps * maxf(k, 0.3)
	var material: ShaderMaterial = bow_wave_right.mesh.material
	material.set_shader_parameter("strength", bow_wave_strength)
	material.set_shader_parameter("frame", bow_wave_frame)
	# 3. Their size: from bow_wave_min_size at a crawl to full size at top speed (they grow from the stem,
	#    where each picture starts). Hidden when there's nothing to see.
	var grow := lerpf(bow_wave_min_size, 1.0, bow_wave_strength)
	for wing in [bow_wave_right, bow_wave_left]:
		wing.scale = Vector3(grow, grow, 1.0)
		wing.visible = bow_wave_strength > 0.02


func update_furl(dt: float) -> void:
	var target := 1.0 if anchored else 0.0
	var rate := furl_rate if anchored else unfurl_rate
	furl = lerpf(furl, target, minf(1.0, dt * rate))
	sail_node.scale.y = lerpf(1.0, furled_height, furl)


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
## It eases in at the start (drift_amount 0..1). It carries her at anchor too: the anchor line holds her
## (see hold_at_anchor).
func update_current(dt: float, wind_from: Vector3) -> void:
	drift_amount += (1.0 - drift_amount) * minf(1.0, dt * current_ease)
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
	camera.global_position = global_position + Vector3(0.0, cos(t), sin(t)) * camera_distance
	camera.global_rotation = Vector3(-(PI / 2.0 - t), 0.0, 0.0)

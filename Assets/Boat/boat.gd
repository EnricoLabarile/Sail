extends Node3D
## The player's boat (like a Pawn in Unreal): she sails by the wind, turns with the rudder,
## stops at anchor. The wheel (ui/helm) finds her through the group "player_boat" and sets
## her rudder; Space works the anchor. Her camera (boat_camera.gd, on the Camera3D node) follows her.
## 1 unit = 10 px of the HTML prototype.

@export var top_speed := 10.0      # m/s with the sail at its best (Enrico: halved from 7, the gusts boost it; the prototype had ~4.2)
@export var accel := 3.0            # how quickly she gathers way (higher = quicker)
@export var anchor_bite := 4.0      # how quickly the anchor stops her
@export var turn_rate := 2.25       # rad/s at full rudder, whatever her speed (Enrico: between the old 1.5 and 3)
@export var bow_reach := 2.2        # metres from her middle to the bow: the shore stops her there
@export var heel_max_deg := 5		    # how far she leans with the wind on the sail
# (The sail itself, its curve, boom, belly, gathering up and trail, is its own script: sail.gd, on the Rig node.)

# Turning: she leans out of the turn (the prototype's "lean out of a turn"), more the quicker she turns
# and the faster she goes.
@export var turn_lean_deg := 15   # how far she leans turning at turn_rate at top_speed, in degrees (the prototype's)

# Speed lifts the bow (Enrico, like a motorboat): the faster she goes, the higher the bow, and it STAYS up as long
# as she keeps that speed; it comes down again as she slows.
@export var bow_lift_deg := 15       # degrees the bow is lifted at top_speed
@export var bow_lift_curve := 2.0     # how the lift grows with speed: 1 = evenly; 2 = little when slow, most near top speed

# Big waves (Assets/Dangers/big_waves): surfing one from astern, or being hit by one head-on or broadside.
@export var surf_boost := 3.2        # m/s on top of what the sail gives, while she surfs a wave
@export var surf_time := 2.6         # seconds a surf lasts (the boost fades over its last 0.8 s)
@export var wave_push := 4.5         # m/s a wave taken badly shoves her its way (× how strong it is)
@export var wave_slowdown := 0.4     # her speed is multiplied by this when a wave hits her
@export var wave_slew_deg := 14.0    # degrees a wave taken badly slews her bow round (× how badly)

# Tying up at a pier (Assets/Landscape/pier): she glides to the pier's berth and turns to its heading.
@export var dock_speed := 3.0   # how quickly she glides into place (higher = quicker; about 1/3 s to get most of the way)
# Casting off (Enrico): so the wind can't pin her against the shore by the pier, for a moment after she leaves it
# the wind and the current don't touch her, and she gets a push forward (her bow points the way the berth does).
@export var cast_off_calm_time := 3.0   # seconds after casting off with no wind and no current
@export var cast_off_push := 10	        # m/s of way she's given as she leaves (it fades as she slows down)

# How she leans and pitches: not straight to where she should be, but like a weight on a spring, so she
# swings a little past it and settles (the prototype's damped springs). This is what makes her feel alive.
@export var roll_stiffness := 16.0      # how strongly the roll is pulled to where it should be (higher = snappier)
@export var roll_damping := 3.2         # how quickly the swinging dies away (lower = more swinging)
@export var pitch_stiffness := 22.0     # the same for the pitch (bow up and down)
@export var pitch_damping := 4.5

# The anchor (the prototype's ANCHOR_RODE): it stays where it fell, off the bow. The current carries her
# until the line is taut; then the line holds her bow and she swings round the anchor, stern downstream.
@export var anchor_rode := 3.0          # metres of anchor line from the bow to the anchor

# The waves: she rocks gently on them, side to side (roll) and bow to stern (pitch).
@export var wave_roll_deg := 3.0    # how far she rolls each way on the waves, in degrees
@export var wave_pitch_deg := 2.0   # how far the bow rises and dips on the waves, in degrees
@export var wave_period := 3.0      # seconds for one wave to pass under her (higher = slower rocking)

# The shallows: near the coast there's less wind, so the sail gives less (how much less: sail.gd shallows_sail).
@export var shallows_width := 3.0   # metres from the land that count as shallows
# Near an NPC (inside its talk radius, Enrico): she slows down, so it's easy to stop by and talk.
@export var npc_speed_limit := 1  # her top speed there, as a share of top_speed (0.2 = 20%)
# The bow wave (boat.tscn: BowWaveRight / BowWaveLeft, bow_wave.png, a 4 x 4 flipbook).
@export var bow_wave_fps := 12.0        # frames a second it plays at top speed (slower when slower)
@export var bow_wave_min_size := 0.4    # its size at a crawl, as a share of full size (full at top speed)
@export var shallows_check_time := 0.2   # seconds between looks for land nearby (it's up to 48 rays: not every frame)

# The current carries her downwind whatever the sail does, so she must steer to make up for it. At anchor too:
# the anchor line holds her. How strong it is lives in the Wind autoload (wind.gd, CURRENT_SPEED), shared with
# everything else that floats; here only how it takes hold of her at the start.
@export var current_ease := 0.8     # how quickly it takes hold at the start
@export var shore_calm_distance := 6.0   # metres from the coast where the current stops carrying her

# Boiling water (a SeaZone of kind BOILING, baked into the level's sea zones picture: Land.boil_at): while she's in
# it she loses boil_damage hearts every boil_every seconds (Enrico: half a heart a second).
@export var boil_damage := 1      # hearts each time
@export var boil_every := 1.0       # seconds between one and the next
@export var boil_threshold := 0.5   # how far into the zone's soft edge counts as "in it" (0..1: 0.5 = halfway in)

# Bumping into the shore (the HTML prototype's impact()): she bounces back off it.
@export var bounce_kick := 7     # m/s of push away from the shore on any bump…
@export var bounce_extra := 0.9     # …plus this much of the speed she hit it with
@export var bounce_fade := 3.5      # how quickly the push dies away (higher = shorter)
@export var bounce_slowdown := 0.25 # her speed is multiplied by this (0.25 = a quarter left)
@export var bounce_min_speed := 0.4 # m/s: slower than this into the shore, it's a nudge, not a bump
@export var bounce_cooldown := 0.6  # s after a bump before the next one counts (one bump, not one per frame)

# Her health (the prototype's hull), counted in hearts like Zelda's; the hearts top left (Assets/UI/health)
# show it. A bump against anything solid (a shore, an island) takes hit_damage off.
@export var max_hearts := 3         # how many hearts she has when the hull is whole (a heart container adds one)
@export var hit_damage := 0.0       # hearts lost in a bump (0.5 = half a heart, as in the prototype)
# Running into an enemy (Enrico, a rule for every monster: bump_into_enemy, called by the enemy): she bounces back off it
# like off a shore and loses enemy_touch_damage hearts; then enemy_touch_cooldown seconds before it can happen again.
@export var enemy_touch_damage := 0.5
@export var enemy_touch_cooldown := 1.0

## Sent whenever her health or her number of hearts changes (the hearts top left listen, to draw again).
## `hurt` is true when she has just lost some (the hearts flash).
signal health_changed(hurt: bool)

# Sinking: at 0 hearts she goes down; then the game over card (Assets/UI/game_over) and back home, whole.
@export var sink_time := 2.0        # seconds she takes to go under
@export var sink_depth := 2.5       # metres she goes down
@export var sink_lean_deg := 25.0   # how far she rolls over as she goes
@export var emerge_on_start := true # she comes up out of the water when the level starts (and always after a respawn)

## Sent once she's gone under (the game over card listens).
signal sank

## Sent when she comes over a fishing spot (over = true) or leaves the last one she was over (false).
## The wheel listens, to show a question mark instead of the anchor. The spots tell her (set_over_fishing_spot).
signal over_fishing_spot_changed(over: bool)

## Sent when the anchor goes down (not when she ties up at a pier). The trap setter listens (TrapSetter in
## boat.tscn, Assets/Items/trap/trap_setter.gd): with a trap equipped, it lays one.
signal anchor_dropped

## Sent when the anchor comes up (not when she casts off from a pier). The start screen listens: weighing the
## anchor the first time starts the game.
signal anchor_weighed

## Sent when the wheel's hub should start or stop showing the speech bubble instead of the anchor: she came into
## an NPC's radius or left it, or a talk started or ended (talk_hint() says which). The wheel listens.
signal talk_hint_changed

## An NPC is talking (the talk box sets it): the anchor button does nothing meanwhile.
var talking := false:
	set(value):
		var had_hint := talk_hint()
		talking = value
		if talk_hint() != had_hint:
			talk_hint_changed.emit()
var npcs_near: Array[Node3D] = []   # the NPCs whose radius she's in now (they tell her: npc.gd)
var npcs_talked_to: Array[Node3D] = []   # of those, the ones she has already talked to since she came in (npc.gd tells her)

var rudder := 0.0      # -1 (port, left) .. 1 (starboard, right)
var speed := 0.0
var bow_wave_strength := 0.0   # how solid the bow wave is now, 0..1 (eased toward her speed share)
var bow_wave_frame := 0.0      # the bow wave's flipbook frame, counting up
var in_shallows := false     # land within shallows_width? (looked again every shallows_check_time seconds)
var shallows_wait := 0.0     # seconds left before the next look
## At anchor (or tied up at a pier)? She starts at anchor: hold the wheel's hub (or press Space) to weigh it.
## Whenever it changes, the icons on the screen hide or come back (Enrico: at anchor only the hub shows;
## the Hud autoload, Assets/UI/hud.gd). (A setter: like a Blueprint "Set" node that also runs some code.)
var anchored := true:
	set(value):
		anchored = value
		Hud.set_hidden("anchor", ["hidden_at_start"], anchored)
var knock := Vector3.ZERO   # the push of a bump (m/s, a direction on the sea): added to her motion, fades away
var drift := Vector3.ZERO   # the current's push (m/s, downwind): added to her motion
var whirl_pull := Vector3.ZERO   # the maelstroms' pull this frame (m/s, toward their eye): added to her motion
var caught_eye: Node3D = null    # the maelstrom's eye holding her (null = free): she spins in it, no helm, no anchor
var caught_spin := 0.0           # how fast she spins while held (radians a second)
var fling_velocity := Vector3.ZERO   # the push of being spat out of a maelstrom (m/s)…
var fling_left := 0.0                # …and the seconds it still lasts
var boil_time := 0.0        # seconds she has been in boiling water since the last scald (see update_boiling)
var drift_amount := 0.0     # 0..1: how much the current has her (eases in and out, see current_ease)
var bump_wait := 0.0        # seconds left before another bump can count
var enemy_wait := 0.0       # seconds left before running into an enemy can hurt her again (enemy_touch_cooldown)
var heel := 0.0             # how far she leans with the wind (radians), without the waves' roll
var turn_speed := 0.0       # how quickly she is turning now, in rad/s (+ = to the left), measured each frame
var roll := 0.0             # her lean now (radians, + = to port), and how quickly it's changing (the spring)
var roll_velocity := 0.0
var pitch := 0.0            # the bow's angle now (radians, + = up), and how quickly it's changing
var pitch_velocity := 0.0
var surfing_left := 0.0     # seconds of surf left (0 = not surfing)
var boost_left := 0.0       # seconds left of a wind gust's boost (0 = none; gust.gd calls boost())
var boost_multiplier := 1.0 # her top speed × this while the boost lasts
var boost_accel := 1.0      # how quickly she picks up speed while the boost lasts
var berth: Node3D = null     # the pier's berth she's tied up at (null = not tied up)
var calm_left := 0.0         # seconds left of the calm after casting off (no wind, no current)
var anchor_point := Vector3.ZERO   # where the anchor lies on the bottom (set when it's dropped)
var model_height := 0.0      # Model's height as placed in the editor (read at start): she bobs round it
var health := 3.0           # hearts left (0.5 = half a heart); set to max_hearts at start
var sinking := false        # true from 0 hearts until she's back home (no sailing, no anchor)
var sunk_for := 0.0         # seconds since she started sinking
var emerging := false       # true while she comes up out of the water (the sinking played backwards; no control)
var emerged_for := 0.0      # seconds since she started coming up
var home_position := Vector3.ZERO   # where she starts (home): read at start, she comes back here after sinking
var home_turn := 0.0                # and which way she faced there (rotation.y)
var water_mask: ShaderMaterial      # the mask on her inside (see add_water_mask)
var masked_meshes: Array[MeshInstance3D] = []   # the meshes that wear it
var fishing_spots_under: Array[Node3D] = []     # the fishing spots she's over now (usually none or one)

# The parts the code moves. find_child("Name") looks for a node with that name anywhere inside the boat
# (children, children of children, and so on), so you can rearrange the hierarchy freely: only the
# NAMES must stay the same. ($Model, with the $, is a fixed address: it must be a direct child of Boat.)
@onready var model: Node3D = $Model            # heels and bobs: everything inside it follows
@onready var sail: Node3D = find_child("Rig")   # the sail (sail.gd, on the Rig node): the wind's push and its look
@onready var paddles: Node3D = find_child("Paddles")   # the paddle wheels (paddles.gd): a crank's push and their look
@onready var camera: Camera3D = $Camera3D   # her camera, with its own script (boat_camera.gd)
@onready var wake: CPUParticles3D = find_child("Wake")          # the dots left behind the stern
@onready var bow_wave_right: Node3D = find_child("BowWaveRight") # the water thrown up and out at the bow (Wind
@onready var bow_wave_left: Node3D = find_child("BowWaveLeft")   # Waker's "wings"; bow_wave.gdshader), a side each

func _ready() -> void:
	add_to_group("player_boat")
	Hud.set_hidden("anchor", ["hidden_at_start"], anchored)   # she starts at anchor: the icons hidden
	# PHYSICS INTERPOLATION (Project Settings > Physics > Common, on): she moves in _physics_process, 60 times a
	# second, but the phone draws the screen at its own uneven pace; Godot draws her where she'd be between two
	# ticks, so she glides instead of jumping. Only she (and what's inside her) is smoothed: everything else in the
	# level moves itself every drawn frame, which needs no smoothing (and would lag behind with it), so the rest of
	# the tree is switched off here, once.
	get_tree().root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	anchor_point = bow_point()   # she starts at anchor: it lies off her bow
	model_height = model.position.y   # how deep she sits: wherever Model was placed in boat.tscn
	health = max_hearts               # she sets out with the hull whole
	home_position = global_position   # home: where she was placed in Overworld
	home_turn = rotation.y
	add_water_mask()
	# Whatever comes into the hold, from wherever (a pickup, an imp, a haul of fish, a buy), the boat makes the
	# same sound: it's her taking it aboard (Enrico). The Inventory tells her (like an Event Dispatcher).
	Inventory.came_aboard.connect(_on_came_aboard)
	if emerge_on_start:
		start_emerging()


## Something came into the hold (Inventory.came_aboard): the "came aboard" sound. One sound for everything, for
## now (Enrico); `item` says what it was, if one day each kind gets its own.
func _on_came_aboard(_item: String, _count: int) -> void:
	Sfx.came_aboard()


## Puts the boat's mask (Assets/Boat/boat_mask.gdshader) on the INSIDE of the hull only, as a
## material_overlay: an extra invisible layer that marks those pixels, so the sea doesn't draw over them.
## Everything else (the outside of the hull, mast, sail) has no mask: where it sits below the water
## (y = 0) the sea covers it, so she looks partly sunk in the water, as a real boat.
## The inside is any mesh with "inner" in its name, or in its parent's name (e.g. sm_boat_hull_inner,
## made in Blender as an object of its own): the floor of the boat lies below the water line, and
## without the mask the sea would cover it.
func add_water_mask() -> void:
	water_mask = ShaderMaterial.new()
	water_mask.shader = load("res://Assets/Boat/boat_mask.gdshader")
	water_mask.render_priority = -1    # among the see-through things, drawn before the sea (which has 0)
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var names: String = (String(mesh.name) + " " + String(mesh.get_parent().name)).to_lower()
		if names.contains("inner"):
			masked_meshes.append(mesh)
	set_water_mask(true)


## Puts the mask on her inside (on = true) or takes it off: while she sinks it's off, so the sea covers
## her inside too and she really goes under.
func set_water_mask(on: bool) -> void:
	for mesh in masked_meshes:
		mesh.material_overlay = water_mask if on else null

func set_rudder(v: float) -> void:
	rudder = clampf(v, -1.0, 1.0)

func toggle_anchor() -> void:
	if sinking:
		return                       # going down: nothing to work
	# Coming up out of the water (Enrico): the anchor can be weighed already, so one press after "Set sail" is
	# enough; she sets off as soon as she's up (update_emerging lets her go).
	if talking:
		return                       # someone is talking (Assets/UI/talk_box): the hub's taps go on with the talk
	if caught_eye != null:
		return                       # spinning in a maelstrom: no anchor
	if berth != null:
		cast_off()                   # tied up at a pier: the anchor button casts off
		return
	anchored = not anchored
	if anchored:
		anchor_point = bow_point()   # let go off the bow: it stays there
		# Did it go down by a fishing spot? Each spot checks if the anchor is within its reach and, if it is,
		# starts fishing (Assets/Landscape/fishing_spots/fishing_spot.gd).
		for spot in get_tree().get_nodes_in_group("fishing_spots"):
			spot.try_fishing(self)
		anchor_dropped.emit()
	else:
		anchor_weighed.emit()
	Sfx.anchor(anchored)             # its sound: the splash going down, the chain coming up (Assets/SFX/sfx.gd)


## A big wave reached her from astern (big_wave.gd): she surfs it, a push of speed for surf_time seconds.
func surf_wave() -> void:
	surfing_left = surf_time


## She sailed through a wind gust (Assets/Landscape/gust/gust.gd): for `time` seconds her top speed is
## × `multiplier`, and she gathers way at `rate` (quicker than usual), whichever way she's heading.
func boost(multiplier: float, time: float, rate: float) -> void:
	boost_multiplier = multiplier
	boost_left = time
	boost_accel = rate


## A big wave reached her head-on or broadside (big_wave.gd): half a heart (the zone's `damage`), a shove the
## wave's way, her speed cut, her bow slewed round to one side or the other. `strength` (0..1) is how big the
## wave is now, `badly` (0..1) how badly she took it (head-on and broadside are the worst).
func hit_by_wave(direction: Vector3, strength: float, badly: float, damage: float) -> void:
	take_damage(damage)
	knock += direction * wave_push * strength
	speed *= wave_slowdown
	var side := 1.0 if randf() < 0.5 else -1.0
	rotate_y(side * deg_to_rad(wave_slew_deg) * badly)


## A maelstrom caught her: she stops and is held in its eye, spinning, until it lets her go (release).
func catch(eye: Node3D, spin: float) -> void:
	caught_eye = eye
	caught_spin = spin
	speed = 0.0
	knock = Vector3.ZERO


## The maelstrom spits her out: a push of `push_speed` m/s along `direction` for `push_time` seconds.
func release(direction: Vector3, push_speed: float, push_time: float) -> void:
	caught_eye = null
	fling_velocity = direction * push_speed
	fling_left = push_time


## Held in a maelstrom's eye: she slides into its middle (it moves, so she follows it) and spins on herself.
func update_caught(dt: float) -> void:
	var eye := caught_eye.global_position
	global_position.x = lerpf(global_position.x, eye.x, minf(1.0, dt * 4.0))   # glides in, quickly
	global_position.z = lerpf(global_position.z, eye.z, minf(1.0, dt * 4.0))
	rotate_y(-caught_spin * dt)      # minus: clockwise, the way the whirlpool turns
	rock_and_roll(dt)                # she keeps bobbing


## A pier's berth (pier.gd) tells her to tie up there: she stops, gathers the sail (as at anchor, so the wheel
## doesn't steer and the hub shows the anchor), and glides into place (glide_to_berth, every physics frame).
func dock_at(spot: Node3D) -> void:
	if sinking or berth != null:
		return
	berth = spot
	anchored = true
	speed = 0.0
	knock = Vector3.ZERO


## Leaves the pier (the anchor button): free to sail, already facing out to sea.
func cast_off() -> void:
	berth = null
	anchored = false
	calm_left = cast_off_calm_time   # for a moment neither the wind nor the current touches her…
	speed = cast_off_push            # …and she's pushed off forward, out of the berth


## Every physics frame while tied up: a little closer to the berth and a little more turned to its heading,
## each time the same share of what's left (so she slows down as she arrives, with no bump at the end).
## The berth's -Z is the way her bow points (as hers: Godot's forward is -Z).
func glide_to_berth(dt: float) -> void:
	var share := 1.0 - exp(-dock_speed * dt)     # the share of the way to go this frame
	var target := berth.global_position
	global_position.x = lerpf(global_position.x, target.x, share)
	global_position.z = lerpf(global_position.z, target.z, share)
	rotation.y = lerp_angle(rotation.y, berth.global_rotation.y, share)   # lerp_angle: the short way round


## Takes `hearts` off her health (never below 0) and tells the hearts top left. At 0 she starts to sink.
func take_damage(hearts: float) -> void:
	if sinking or emerging:
		return                       # going down, or still coming up: nothing more can hurt her
	if hearts > 0.0:
		Sfx.boat_hurt()              # the one sound for every kind of damage (sfx.gd); not for a 0 (a shore bump: only the shake)
	health = maxf(0.0, health - hearts)
	health_changed.emit(true)
	camera.shake()                   # the screen shakes (boat_camera.gd)
	if health <= 0.0:
		start_sinking()


## 0 hearts: she stops where she is and goes down (update_sinking does it, frame by frame).
func start_sinking() -> void:
	sinking = true
	sunk_for = 0.0
	speed = 0.0
	knock = Vector3.ZERO
	caught_eye = null
	fling_left = 0.0
	set_water_mask(false)            # the sea may cover her inside now
	if wake:
		wake.emitting = false        # no wake behind a wreck
	sail.stop_trail()
	for wing in [bow_wave_right, bow_wave_left]:
		if wing:
			wing.visible = false


## Each frame while she sinks: down by sink_depth and over by sink_lean_deg in sink_time seconds, slowly at
## first and quicker at the end (share × share). Once she's under, `sank` is sent, once.
func update_sinking(dt: float) -> void:
	var was_under := sunk_for >= sink_time
	sunk_for += dt
	var share := minf(1.0, sunk_for / sink_time)     # 0 = just started, 1 = under
	model.position.y = model_height - sink_depth * share * share
	model.rotation.z = roll + deg_to_rad(sink_lean_deg) * share
	if share >= 1.0 and not was_under:
		sank.emit()


## Back home with the hull whole (the game over card calls it): at anchor where she started, everything
## that was moving her stopped. What's in the hold and her heart containers stay.
func respawn() -> void:
	sinking = false
	berth = null
	surfing_left = 0.0
	boost_left = 0.0
	boil_time = 0.0
	global_position = home_position
	rotation.y = home_turn
	health = max_hearts
	speed = 0.0
	knock = Vector3.ZERO
	caught_eye = null
	fling_left = 0.0
	rudder = 0.0
	anchored = true
	anchor_point = bow_point()
	sail.gather_up()
	paddles.stop()
	roll = 0.0
	roll_velocity = 0.0
	pitch = 0.0
	pitch_velocity = 0.0
	model.position.y = model_height
	model.rotation = Vector3.ZERO
	reset_physics_interpolation()    # a jump, not a glide: no smoothing from where she sank to home
	camera.jump_to_boat()            # the camera jumps there too, no glide across the map
	health_changed.emit(false)
	start_emerging()                 # and she comes up out of the water


## The spawn: the sinking played backwards (Enrico). She starts sink_depth under, leaning sink_lean_deg over,
## and comes up over sink_time seconds (update_emerging does it, frame by frame). Until she's up: no sailing,
## no anchor, no damage, and her inside has no mask (the sea covers her while she's under).
func start_emerging() -> void:
	emerging = true
	emerged_for = 0.0
	set_water_mask(false)
	model.position.y = model_height - sink_depth
	model.rotation.z = deg_to_rad(sink_lean_deg)
	if wake:
		wake.emitting = false
	for wing in [bow_wave_right, bow_wave_left]:
		if wing:
			wing.visible = false


## Each frame while she comes up: exactly the sinking's movement, backwards in time. Sinking went down
## slowly at first and quicker at the end (share × share); played backwards, she comes up quickly at first and
## slows as she reaches the surface. Once up: the mask back on her inside, and she's free to sail.
func update_emerging(dt: float) -> void:
	emerged_for += dt
	var share := minf(1.0, emerged_for / sink_time)     # 0 = still under, 1 = up
	var under := 1.0 - share                            # how much of the sinking is still "left": 1 → 0
	model.position.y = model_height - sink_depth * under * under
	model.rotation.z = deg_to_rad(sink_lean_deg) * under
	if share >= 1.0:
		emerging = false
		model.position.y = model_height
		model.rotation.z = 0.0
		set_water_mask(true)


## A heart container (Zelda's): one more heart, and the hull mended whole.
func add_heart_container() -> void:
	max_hearts += 1
	health = max_hearts
	health_changed.emit(false)


## A fishing spot tells her she's over it (here = true) or not any more (false). When that makes the difference
## between "over a spot" and "over none", she sends over_fishing_spot_changed (the wheel listens).
## (See also set_near_npc, below: the same for NPCs.)
func set_over_fishing_spot(spot: Node3D, here: bool) -> void:
	var was_over := not fishing_spots_under.is_empty()
	if here and not fishing_spots_under.has(spot):
		fishing_spots_under.append(spot)
	if not here:
		fishing_spots_under.erase(spot)
	var is_over := not fishing_spots_under.is_empty()
	if is_over != was_over:
		over_fishing_spot_changed.emit(is_over)


## An NPC tells her she came into its radius (near = true) or left it (npc.gd, from its Sensor).
func set_near_npc(npc: Node3D, near: bool) -> void:
	var had_hint := talk_hint()
	if near and not npcs_near.has(npc):
		npcs_near.append(npc)
	if not near:
		npcs_near.erase(npc)
		npcs_talked_to.erase(npc)        # gone out of its radius: coming back, she can talk to it again
	if talk_hint() != had_hint:
		talk_hint_changed.emit()


## An NPC tells her their talk is over (npc.gd, when the talk box closes). Until she leaves its radius it counts as
## talked to: the hub shows the anchor again (Enrico: so it's clear she can sail on) and anchoring there again
## doesn't start the same talk over. (In Unreal: the NPC calling an interface function on the pawn.)
func done_talking_with(npc: Node3D) -> void:
	var had_hint := talk_hint()
	if not npcs_talked_to.has(npc):
		npcs_talked_to.append(npc)
	if talk_hint() != had_hint:
		talk_hint_changed.emit()


## Has she already talked to this NPC since she came into its radius?
func has_talked_to(npc: Node3D) -> bool:
	return npcs_talked_to.has(npc)


## Is there an NPC near her she hasn't talked to yet? (Then dropping anchor starts a talk.)
func npcs_waiting() -> bool:
	for npc in npcs_near:
		if not npcs_talked_to.has(npc):
			return true
	return false


## Should the wheel's hub show the speech bubble? While she's in the radius of an NPC she hasn't talked to yet
## (dropping anchor will start the talk) or while someone is talking (a tap goes on).
func talk_hint() -> bool:
	return talking or npcs_waiting()


## Where her bow is now, on the water.
func bow_point() -> Vector3:
	var fwd := -global_transform.basis.z
	return global_position + fwd * bow_reach

func _physics_process(dt: float) -> void:
	# Sinking: only that, no sailing, no anchor, no bumps.
	if sinking:
		update_sinking(dt)
		return
	# Coming up out of the water (the spawn): only that, until she's up.
	if emerging:
		update_emerging(dt)
		Fog.reveal(global_position)    # the fog clears round her already, so she comes up in seen water
		return
	# Caught in a maelstrom: only that, no sailing, no helm, no anchor, until it spits her out.
	if caught_eye != null:
		update_caught(dt)
		return
	# the keyboard: Space / Enter works the anchor (the arrows turn the wheel, in ui/helm)
	if Input.is_action_just_pressed("ui_accept"):
		toggle_anchor()

	var wind_from: Vector3 = Wind.from_vector()                 # the wind (Assets/Landscape/world/wind.gd)
	# In the shallows (land within shallows_width metres) the sail gives less (sail.gd shallows_sail).
	# The baked picture of the distances says how far the shore is (Land): cheap, so every frame.
	in_shallows = Land.distance_to_shore(global_position) < shallows_width
	# The wind's push: the sail's (sail.gd), 0 when it's not set or she's at anchor.
	var drive: float = sail.drive()
	# Just cast off from a pier: the wind gives nothing for calm_left seconds (she glides on the push).
	if calm_left > 0.0:
		calm_left = maxf(0.0, calm_left - dt)
		drive = 0.0

	# speed eases toward what the sail gives; the anchor takes her way off quickly
	var target := top_speed * drive
	var rate := anchor_bite if anchored else accel
	# The paddle wheels (paddles.gd), wound by the crank: if they give more than the sail, she goes at their push,
	# picked up at their own (quicker) bite.
	paddles.update(dt)
	if paddles.push_speed() > target:
		target = paddles.push_speed()
		rate = paddles.bite
	# A wind gust's boost (gust.gd): her top speed × boost_multiplier while it lasts, picked up at boost_accel.
	if boost_left > 0.0:
		boost_left = maxf(0.0, boost_left - dt)
		if not anchored:
			target *= boost_multiplier
			rate = boost_accel
	# Surfing a big wave: a push on top, fading over its last 0.8 s; she picks it up quickly (rate 3).
	if surfing_left > 0.0:
		surfing_left = maxf(0.0, surfing_left - dt)
		if not anchored:
			target += surf_boost * minf(1.0, surfing_left / 0.8)
			rate = 3.0
	# Inside an NPC's radius (npcs_near, told by npc.gd): never faster than npc_speed_limit of her top speed.
	# She slows down to it smoothly, at her usual rate (the line below): she doesn't stop dead.
	if not npcs_near.is_empty():
		target = minf(target, top_speed * npc_speed_limit)
	speed += (target - speed) * minf(1.0, dt * rate)

	# She turns at the same rate whatever her speed, as in the prototype; not at anchor.
	var yaw_before := rotation.y
	if berth != null:
		glide_to_berth(dt)           # tied up at a pier: only gliding into place, nothing else moves her
	else:
		if not anchored:
			rotate_y(-rudder * turn_rate * paddles.turn_factor() * dt)   # quicker while the paddles push
		update_current(dt)
		update_boiling(dt)
		move_and_bounce(dt)
		hold_at_anchor()
	# How quickly she really turned this frame (the rudder, a bump, the anchor line swinging her):
	# wrapf keeps the difference between -PI and PI when the angle goes round past 180 degrees.
	turn_speed = wrapf(rotation.y - yaw_before, -PI, PI) / dt
	Fog.reveal(global_position)                                 # clear the fog round her (fog.gd)

	# the look: heel away from the wind (only as much as the sail drives her), a gentle bob; the sail's own look
	# (boom, belly, gathered up at anchor, its trail) is the sail's (sail.gd)
	var side := signf(global_transform.basis.x.dot(wind_from))   # + = wind from starboard
	heel = side * deg_to_rad(heel_max_deg) * drive
	rock_and_roll(dt)
	# A gentle bob up and down, round the height Model has in the scene (set it there to sink her more or less).
	model.position.y = model_height + sin(Time.get_ticks_msec() * 0.0013) * 0.04
	sail.update_look(dt, drive)
	update_water_fx(dt)

## How she leans (roll) and how her bow rises and dips (pitch). First where she should be:
##   roll  = the heel from the wind + the lean out of a turn + the waves' roll
##   pitch = the bow lifted by her speed (more the faster she goes) + the waves' pitch
## Then, instead of jumping there, she is pulled there like a weight on a spring (a damped spring):
## she swings a little past it and settles. That swing is what makes the boat feel alive when you turn.
func rock_and_roll(dt: float) -> void:
	# 1. The lean out of a turn: as in the prototype, how quickly she turns × how fast she goes.
	#    Turning right, turn_speed is negative and she leans left (+), so the sign is flipped.
	var turn_share := -turn_speed / turn_rate          # 1 = turning right at turn_rate
	var speed_share := speed / top_speed               # 1 = at top speed
	var turn_lean := turn_share * speed_share * deg_to_rad(turn_lean_deg)

	# 2. The bow and her speed: her share of top speed (0..1), raised to bow_lift_curve, times bow_lift_deg.
	#    With the curve at 2: at half speed a quarter of the lift, at top speed all of it.
	#    (pow(a, b) is a to the power b.) The spring below makes it rise and settle smoothly, not jump.
	var lift_share := pow(clampf(speed / top_speed, 0.0, 1.0), bow_lift_curve)
	var bow_lift := lift_share * deg_to_rad(bow_lift_deg)

	# 3. The waves: two slow sine waves (pitch a little quicker than roll, so they don't move in step).
	#    TAU (2 x pi) / period makes one full swing take `period` seconds.
	var seconds := Time.get_ticks_msec() / 1000.0
	var wave_roll := sin(seconds * TAU / wave_period) * deg_to_rad(wave_roll_deg)
	var wave_pitch := sin(seconds * TAU / (wave_period * 0.8)) * deg_to_rad(wave_pitch_deg)

	# 4. Where she should be.
	var roll_target := heel + turn_lean + wave_roll
	var pitch_target := bow_lift + wave_pitch

	# 5. The springs: the further she is from the target, the harder she's pulled toward it (stiffness);
	#    the faster she's moving, the more that's held back (damping). velocity changes the angle.
	roll_velocity += (roll_stiffness * (roll_target - roll) - roll_damping * roll_velocity) * dt
	roll += roll_velocity * dt
	pitch_velocity += (pitch_stiffness * (pitch_target - pitch) - pitch_damping * pitch_velocity) * dt
	pitch += pitch_velocity * dt
	# never further than the prototype allowed: about 34 degrees of roll, 17 of pitch (more up, if bow_lift_deg asks)
	roll = clampf(roll, -0.6, 0.6)
	pitch = clampf(pitch, -0.3, maxf(0.3, deg_to_rad(bow_lift_deg + wave_pitch_deg)))

	model.rotation.z = roll    # z: round her length, so she leans left (+) and right (-)
	model.rotation.x = pitch   # x: across her, so the bow goes up (+) and down (-)


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


## Moves her for this frame: her own way (forward × speed) plus the push of a bump (knock).
## If that would put her middle or her bow on land (the Land autoload), she doesn't go there:
## she bumps (see bump) and bounces back off the shore.
func move_and_bounce(dt: float) -> void:
	bump_wait = maxf(0.0, bump_wait - dt)
	enemy_wait = maxf(0.0, enemy_wait - dt)
	knock *= exp(-bounce_fade * dt)                      # the push of the last bump dies away

	var fwd := -global_transform.basis.z
	var own_way := fwd * speed                           # her own way, from the sail
	# Spat out of a maelstrom: the push holds, then fades over its last 0.4 s.
	var fling := Vector3.ZERO
	if fling_left > 0.0:
		fling_left = maxf(0.0, fling_left - dt)
		fling = fling_velocity * minf(1.0, fling_left / 0.4)
	var velocity := own_way + knock + drift + whirl_pull + fling   # her way + a bump's push + the current + the whirlpools' pull + being spat out
	whirl_pull = Vector3.ZERO        # used (it's in velocity now): each maelstrom adds its pull again next frame
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


## The current: the Wind autoload's (Wind.current(): downwind, at its CURRENT_SPEED). On her it eases in at the
## start (drift_amount 0..1). It carries her at anchor too: the anchor line holds her (see hold_at_anchor).
func update_current(dt: float) -> void:
	# Just cast off from a pier: no current yet; afterwards it takes hold again gently (drift_amount from 0).
	if calm_left > 0.0:
		drift_amount = 0.0
		drift = Vector3.ZERO
		return
	
	# Near the coast the current lets her go (Enrico): the baked picture says how far the shore is (Land).
	var target := 1.0                                     # out at sea: the full current
	if Land.distance_to_shore(global_position) < shore_calm_distance:
		target = 0.0                                      # close to the shore: none
	if not npcs_near.is_empty():
		target = 0.0                                      # in an NPC's radius: none either (Enrico), so she can stop by
	# Eased, not switched: drift_amount slides toward the target a little every frame, so she isn't jolted.
	drift_amount += (target - drift_amount) * minf(1.0, dt * current_ease)
	# A strong current zone (SeaZone, kind CURRENT: Land.current_at) takes over from the usual current: its own
	# direction and strength, whatever the wind. At its soft edge, where its push is still weaker than the usual
	# current, the two are mixed, so she slides into it rather than being yanked.
	var zone_push := Land.current_at(global_position)
	var zone_share := clampf(zone_push.length() / Wind.CURRENT_SPEED, 0.0, 1.0)   # 0 = no zone, 1 = the zone only
	var flow := Wind.current() * (1.0 - zone_share) + zone_push
	drift = flow * drift_amount


## Boiling water: while she's in it, boil_damage hearts every boil_every seconds (the first one boil_every seconds
## after she comes in). Out of it, the count starts again. (take_damage does nothing while she sinks or comes up.)
func update_boiling(dt: float) -> void:
	if Land.boil_at(global_position) < boil_threshold:
		boil_time = 0.0
		return
	boil_time += dt
	if boil_time >= boil_every:
		boil_time -= boil_every
		take_damage(boil_damage)


## Pushed back by something she can't go over (an item of a floating shop she can't afford): she loses her way and
## is shoved away from `from_point` at `push` m/s (the same push a bump gives, fading at bounce_fade). No damage.
func push_away(from_point: Vector3, push: float) -> void:
	var away := global_position - from_point
	away.y = 0.0
	if away.length() < 0.01:
		away = global_transform.basis.z    # right on top of it: back her out astern
	speed = 0.0
	knock += away.normalized() * push


## She ran into an enemy (or it into her): every monster calls this when she's touching it (sea_urchin.gd,
## sea_imp_zone.gd). She's knocked back away from `enemy_point` (the shore bump's push, bounce_kick plus a share of her
## speed), loses most of her way and enemy_touch_damage hearts, with the hull's knock; then nothing for
## enemy_touch_cooldown seconds, so touching it for a while is one hit, not one every frame.
func bump_into_enemy(enemy_point: Vector3) -> void:
	if enemy_wait > 0.0 or sinking or emerging:
		return
	enemy_wait = enemy_touch_cooldown
	var away := global_position - enemy_point
	away.y = 0.0
	if away.length() < 0.01:
		away = global_transform.basis.z      # right on top of it: back her out astern
	knock += away.normalized() * (bounce_kick + absf(speed) * bounce_extra)
	speed *= bounce_slowdown
	take_damage(enemy_touch_damage)      # its sound is the damage's (Sfx.boat_hurt), not the hull's knock


## A bump against the shore: `out` is the way to the open sea, `into` how fast she hit (m/s).
## As in the HTML prototype: a push back out, much less speed, the bow swung off a little, and the hull
## takes hit_damage (half a heart).
func bump(out: Vector3, into: float) -> void:
	speed *= bounce_slowdown                             # she loses most of her way
	if bump_wait > 0.0 or into < bounce_min_speed:
		return                                           # just a nudge, or the same bump as a moment ago
	bump_wait = bounce_cooldown
	take_damage(hit_damage)                              # the same whatever her speed (as in the prototype)
	# The knock of the hull (Assets/SFX): louder the harder she hit, never quieter than 40%.
	Sfx.hull_bump(clampf(0.4 + 0.6 * into / top_speed, 0.0, 1.0))

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

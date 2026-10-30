@tool
extends Node3D
## A SEA IMP (Enrico's "mimic"). Where you place it, it lurks: it looks like a fishing spot, a big patch of stirred water.
## When the boat comes within `wake_radius` it wakes, and from then on it runs this cycle, over and over:
##   1. EMERGING (`emerge_time` 1.5 s): only the patch of stirred water shows where it's about to come up, so
##      the player can see it coming and react;
##   2. UP: the imp itself shows (sea_imp.png); it waits `idle_before_spit` 1 s, spits a fireball at where the
##      boat will be (1 heart if it hits), waits `idle_after_spit` 1 s more…
##   3. …and dives: UNDER, the imp invisible and out of reach, but its patch of dark water SWIMS (Enrico), at
##      `swim_speed`, from where it went under to where it will come up next, so the player sees it coming;
##   4. then it emerges again somewhere else, a spot of open water that's in view (on the screen), and so on.
## It goes back to lurking at its own place when the boat sinks, or when she's more than `radius` from it (she got
## away) AND it's off her screen (the imp, or its patch under water): while it's on screen it chases her past the radius.
##
## It has `max_hearts` 3: a bomb's blast or a trap (bomb.gd, trap.gd → hit_imp_at) takes one while it's emerging
## or up, and blinks black (HURT, `hurt_time`); if it has some left it then goes under (and the cycle goes on). At 0 it's DEFEATED: it stays up,
## harmless, black (dead), drifting with the current; the boat sailing over it (within `collect_radius`) takes it into the hold ("imp").
## Killed, it also leaves `drop_min`–`drop_max` pickups of `drop_item` (bombs) round it, `drop_spread` metres
## apart (Assets/Items/pickup/pickup.tscn: they float where they fell until she sails over them).
## Lost hearts stay lost.
## The harpoon can hook it while it's up (group "hookable", harpoon.gd): it loses the harpoon's damage (blinking) and
## is STUNNED, up and harmless (no fireball, no bump), while pulled and for the harpoon's stun_time after it's let go;
## then it goes under as usual. Dead, the harpoon can pull its body to her too.
##
## To place one: instance sea_imp_zone.tscn under SeaImps in Overworld (like placing a Blueprint) and move it where
## it should lurk. In the editor a red disc shows `radius`, and the lurking patch and the imp show at its place.
## (In Unreal: an enemy actor with a little state machine run every Tick.)
##
## Its parts (sea_imp_zone.tscn): `Imp`, the imp's camera-facing picture (sea_imp.gdshader: nothing under the water
## line is drawn; sea_imp.png, one frame for now); `Patch`, the stirred water (the fishing spot's own flipbook
## shader and picture, `lurk_size` across), shown while it lurks and while it's emerging.

const FIREBALL_SCENE := preload("res://Assets/Dangers/sea_imp/fireball.tscn")
const Pickup := preload("res://Assets/Items/pickup/pickup.gd")   # for Pickup.drop_loot (every enemy's reward)

## How far from its place it still hunts her, in metres: further than this, it goes back to lurking.
@export var radius := 60:
	set(value):
		radius = value
		_fit_editor_disc()
@export var wake_radius := 25            # metres: the boat this close to the lurking imp wakes it
@export var lurk_size := 10.8              # metres across the patch of stirred water (Enrico: 3 times the first 3.6)
@export var max_hearts := 3.0              # its health, in hearts (a bomb or a trap takes one)
@export var touch_radius := 2.0            # metres: the boat's middle this close to it while it's up = she ran into it (bounce, half a heart)
@export var collect_radius := 2.5          # metres: defeated, it goes into the hold when the boat's middle comes this close
@export var emerge_time := 2             # seconds the patch shows before it comes up (the warning)
@export var idle_before_spit := 1.5        # seconds up before it spits
@export var idle_after_spit := 3         # seconds up after spitting, before it disappears
@export var swim_speed := 6.0              # m/s its patch swims under water to the next spot (Enrico: a steady speed)
## Where it may come up again (Enrico, to compare how the fight feels): on = only downwind of the boat (a bomb
## drifts to it); off = anywhere on the screen.
@export var downwind_only := true
@export var spawn_distance_min := 6.0      # metres from the boat it may come up (nearest…
@export var spawn_distance_max := 18.0     # …furthest), always on water and in view
@export var screen_margin := 0.12          # how far in from the screen's edges it comes up (a share of the screen)
@export var fireball_speed := 8          # metres a second (she can dodge it)
@export var fireball_damage := 1.0         # hearts a fireball takes off (Enrico: one)
@export var fireball_hit_radius := 3     # metres from the boat's middle a fireball hits her
@export var fireball_life := 9           # seconds a fireball flies before it's gone
@export var show_fireball_hit_radius := true  # DEBUG: an ink ring on the water under each fireball, as big as its hit radius
@export var aim_ahead := 0.5               # it aims where the boat will be this many seconds later
@export var spit_height := 1.5             # metres above the water the fireball leaves its mouth
@export var hurt_time := 0.5               # seconds it stays up blinking black when hit, before it goes under
@export var hurt_blinks_per_second := 12.0 # how fast it blinks black while hurt
@export var drop_item: ItemData = preload("res://Assets/Inventory/items/bomb.tres")   # what it leaves when killed (none = nothing)
@export_range(0.0, 1.0) var drop_chance := 1.0   # how likely it drops it: 1 = always, 0.5 = one time in two
@export var drop_min := 1                  # how many pickups it leaves, at least…
@export var drop_max := 2                  # …and at most (Enrico: 1 or 2 bombs)
@export var drop_spread := 3.0             # metres from the imp they land, at most

enum State { LURKING, EMERGING, UP, HURT, STUNNED, UNDER, DEFEATED, CAPTURED }

var state := State.LURKING
var time := 0.0            # seconds in the current state
var has_spat := false      # has it spat since it came up?
var hearts := 3.0          # hearts it has left
var on_hook := false       # pulled by the harpoon now
var stun_time := 0.0       # STUNNED: seconds it stays so once the harpoon lets it go (the harpoon's stun_time)
var hook_flash_left := 0.0 # seconds left of the black blink after the harpoon hurt it
var swim_target: Variant = null   # under water: the spot it's swimming to (null = not chosen yet)

@onready var imp: MeshInstance3D = $Imp
@onready var patch: MeshInstance3D = $Patch


func _ready() -> void:
	_fit_patch()
	if Engine.is_editor_hint():
		_make_editor_disc()
		return
	add_to_group("sea_imps")    # so bombs and traps find it (bomb.gd, trap.gd: hit_imp_at)
	add_to_group("hookable")    # so the harpoon can catch it (harpoon.gd)
	imp.material_override = imp.material_override.duplicate()   # its own copy, so only this imp blinks
	hearts = max_hearts
	lurk()


func _process(dt: float) -> void:
	if Engine.is_editor_hint():
		return
	time += dt
	var boat := get_tree().get_first_node_in_group("player_boat") as Node3D
	if state == State.CAPTURED:
		return
	hook_flash_left = maxf(0.0, hook_flash_left - dt)
	update_flash()
	if state == State.DEFEATED:
		# Beaten: black (update_flash), afloat and harmless, carried by the current (drift_with_current).
		# The boat sailing over it takes it aboard (if there's room).
		if not on_hook:
			drift_with_current(dt)                     # on the harpoon the rope moves it instead
		if boat != null and not boat.sinking and distance_to(boat, imp.global_position) <= collect_radius:
			if Inventory.add("imp") == 1:
				imp.visible = false
				state = State.CAPTURED
		return
	if boat == null:
		return
	# She sank: back to lurking at once.
	if state != State.LURKING and boat.sinking:
		lurk()
		return
	# She got away (further than `radius` from its place): it goes back to lurking only once it's also off her
	# screen (Enrico). While it, or its patch under water, is on screen it keeps chasing her; once she leaves it
	# behind, off screen (its patch swims slower than she sails), it gives up and goes home.
	if state != State.LURKING and distance_to(boat, global_position) > radius and not is_seen(boat):
		lurk()
		return
	# Up out of the water (or blinking, hurt), it's solid: the boat running into it bounces back and loses half a
	# heart (boat.gd bump_into_enemy; Enrico: a rule for every monster).
	if (state == State.UP or state == State.HURT) and distance_to(boat, imp.global_position) <= touch_radius:
		boat.bump_into_enemy(imp.global_position)
	match state:
		State.LURKING:
			if not boat.sinking and distance_to(boat, global_position) <= wake_radius:
				emerge_at(global_position)              # the first time, it comes up where it lurked
		State.EMERGING:
			if time >= emerge_time:
				come_up()
		State.UP:
			if not has_spat and time >= idle_before_spit:
				has_spat = true
				spit(boat)
			elif has_spat and time >= idle_before_spit + idle_after_spit:
				go_under()
		State.HURT:
			if time >= hurt_time:
				go_under()                                 # done blinking: it vanishes under
		State.STUNNED:
			if not on_hook and time >= stun_time:
				go_under()                                 # the stun is over (it counts from when it was let go)
		State.UNDER:
			swim(boat, dt)


# ---- the states ----

## Is it on the player's screen? Up (or hurt) the imp itself, under water (emerging or swimming) its patch: is
## that spot inside the boat camera's view (is_position_in_frustum: inside what the camera sees)?
func is_seen(boat: Node3D) -> bool:
	var spot := imp.global_position
	if state == State.EMERGING or state == State.UNDER:
		spot = patch.global_position      # under water: its patch is what shows
	return boat.camera.is_position_in_frustum(spot)


## Lurking at its own place: only the patch of stirred water, like a fishing spot.
func lurk() -> void:
	state = State.LURKING
	time = 0.0
	imp.visible = false
	patch.visible = true
	patch.global_position = Vector3(global_position.x, 0.05, global_position.z)


## The warning: the patch shows at `spot` for emerge_time seconds, then it comes up there.
func emerge_at(spot: Vector3) -> void:
	state = State.EMERGING
	time = 0.0
	imp.visible = false
	patch.visible = true
	patch.global_position = Vector3(spot.x, 0.05, spot.z)
	imp.global_position = Vector3(spot.x, 0.0, spot.z)


## Up: the imp shows where the patch was.
func come_up() -> void:
	state = State.UP
	time = 0.0
	has_spat = false
	patch.visible = false
	imp.visible = true


## Gone under: the imp invisible and out of reach; its patch stays where it dived, and from the next frame it
## swims to where it will come up (swim()).
func go_under() -> void:
	state = State.UNDER
	time = 0.0
	imp.visible = false
	patch.visible = true
	patch.global_position = Vector3(imp.global_position.x, 0.05, imp.global_position.z)
	swim_target = null


## Hit (with hearts left): it stays up, harmless, blinking black for hurt_time seconds, then goes under.
## Hit while still emerging, it shows itself at once, so the player sees it was hurt.
func get_hurt() -> void:
	state = State.HURT
	time = 0.0
	patch.visible = false
	imp.visible = true


## 0 hearts: it stays up on the water, harmless, waiting to be picked up; it turns black and drifts with the current.
func defeat() -> void:
	state = State.DEFEATED
	time = 0.0
	patch.visible = false
	imp.visible = true
	Sfx.enemy_death()
	Pickup.drop_loot(get_parent(), drop_item, imp.global_position, drop_chance, drop_min, drop_max, drop_spread)


# ---- what it does ----

## Under water, every frame: choose where to come up (once), then the patch swims straight there at
## swim_speed; when it arrives, the warning starts there (emerge_at) and the imp comes up as before.
func swim(boat: Node3D, dt: float) -> void:
	if swim_target == null:
		swim_target = find_spot_in_view(boat)
		if swim_target == null:
			return                                 # no good spot this frame: wait where it is, try again next frame
	var target: Vector3 = swim_target
	var here := patch.global_position
	var goal := Vector3(target.x, here.y, target.z)
	# move_toward: a step of swim_speed × dt toward the goal, never past it (like VInterpConstantTo in Unreal).
	patch.global_position = here.move_toward(goal, swim_speed * dt)
	if patch.global_position.distance_to(goal) < 0.01:
		emerge_at(target)

## Spits a fireball at where the boat will be `aim_ahead` seconds from now (if she keeps going as she is).
func spit(boat: Node3D) -> void:
	var forward: Vector3 = -boat.global_transform.basis.z
	var target: Vector3 = boat.global_position + forward * boat.speed * aim_ahead
	var start := imp.global_position + Vector3(0.0, spit_height, 0.0)
	var ball := FIREBALL_SCENE.instantiate()
	get_parent().add_child(ball)     # into the world, not inside the zone
	ball.show_hit_radius = show_fireball_hit_radius
	ball.launch(start, target, fireball_speed, fireball_damage, fireball_hit_radius, fireball_life)


## A spot of open water to come up at: on the screen (not too near its edges), between spawn_distance_min and
## spawn_distance_max from the boat, and (with downwind_only on) DOWNWIND of her (Enrico): a line through the boat across the wind splits
## the screen in two, and it only comes up on the side the wind blows toward, so a bomb dropped off her bow drifts
## with the current toward it (never upwind, where she'd have to beat into the wind to reach it). Up to 20 tries: a random point of the screen, followed down along the
## camera's line of sight to the water (like a mouse click turned into a point on the ground). Null if none fits.
func find_spot_in_view(boat: Node3D) -> Variant:
	# The boat's camera (it lives in the game view's own viewport, not in this node's: game_view.gd).
	var camera: Camera3D = boat.camera
	var screen := camera.get_viewport().get_visible_rect().size
	for attempt in 20:
		var on_screen := Vector2(
			randf_range(screen_margin, 1.0 - screen_margin) * screen.x,
			randf_range(screen_margin, 1.0 - screen_margin) * screen.y)
		var from := camera.project_ray_origin(on_screen)
		var direction := camera.project_ray_normal(on_screen)
		if direction.y >= -0.001:
			continue                                      # looking up: it never meets the water
		var spot := from + direction * (-from.y / direction.y)   # where the line of sight meets the water (y 0)
		var distance := distance_to(boat, spot)
		if distance < spawn_distance_min or distance > spawn_distance_max:
			continue                                      # too near her or too far
		if downwind_only and not is_downwind(boat, spot):
			continue                                      # on the upwind side of the line: not there (if downwind_only)
		if Land.is_land(spot):
			continue                                      # on land
		return spot
	return null


## True if `spot` is on the downwind side of the line through the boat across the wind. The wind blows toward
## -Wind.from_vector(); the arrow from her to the spot points that way (a positive dot product, i.e. less than
## 90 degrees between them) when the spot is downwind of her.
func is_downwind(boat: Node3D, spot: Vector3) -> bool:
	var downwind: Vector3 = -Wind.from_vector()
	var to_spot := spot - boat.global_position
	to_spot.y = 0.0
	return to_spot.dot(downwind) > 0.0


## A bomb's blast or a trap at `point`, reaching `reach` metres (bomb.gd, trap.gd call this on every imp).
## Only while it's emerging or up and that close: it loses `damage` hearts and blinks black; at 0 it's defeated,
## otherwise it goes under once it's done blinking (HURT). Gives back true if it was hit.
func hit_imp_at(point: Vector3, reach: float, damage: float) -> bool:
	if state != State.EMERGING and state != State.UP and state != State.STUNNED:
		return false
	var off := point - imp.global_position
	off.y = 0.0
	if off.length() > reach:
		return false
	hearts = maxf(0.0, hearts - damage)
	if hearts <= 0.0:
		defeat()          # it blinks black too (update_flash), then stays up
	else:
		get_hurt()        # it blinks black, then goes under
	return true


# ---- on the harpoon (harpoon.gd: the functions every hookable thing has) ----

## Only while it's up out of the water (also stunned or dead, not under or emerging), and not on the hook already.
func can_be_hooked() -> bool:
	if on_hook:
		return false
	return state == State.UP or state == State.HURT or state == State.STUNNED or state == State.DEFEATED


func hook_point() -> Vector3:
	return imp.global_position


func hook_size() -> float:
	return 1.0


## Caught: it loses the harpoon's damage (0 = none) and is stunned; killed by it, it's DEFEATED and comes along dead.
func hooked(harpoon: Node3D) -> void:
	on_hook = true
	if state == State.DEFEATED:
		return                                        # already dead: just its body pulled in
	if harpoon.damage > 0.0:
		hearts = maxf(0.0, hearts - harpoon.damage)
		if hearts <= 0.0:
			defeat()
			return
		hook_flash_left = hurt_time
	state = State.STUNNED
	time = 0.0
	patch.visible = false
	imp.visible = true


## On the hook while stunned or dead (taken aboard, or hurt by a bomb meanwhile: let go).
func still_hooked() -> bool:
	return state == State.STUNNED or state == State.DEFEATED


func pulled_to(point: Vector3) -> void:
	imp.global_position = Vector3(point.x, 0.0, point.z)


## Let go: the stun lasts the harpoon's stun_time from now.
func unhooked(harpoon: Node3D) -> void:
	on_hook = false
	stun_time = harpoon.stun_time
	if state == State.STUNNED:
		time = 0.0


## The black flash when it's hurt: for hurt_time seconds after a hit (HURT, or just DEFEATED) the picture
## blinks between black and its own colours (the shader's `flash`: 1 = black, 0 = as drawn).
## Once DEFEATED and done blinking it stays black for good: it's dead (a different picture later, Enrico).
func update_flash() -> void:
	var flashing := (state == State.HURT or state == State.DEFEATED) and time < hurt_time
	var black := 0.0
	if flashing and int(time * hurt_blinks_per_second) % 2 == 0:
		black = 1.0
	if state == State.STUNNED and hook_flash_left > 0.0 and int(hook_flash_left * hurt_blinks_per_second) % 2 == 0:
		black = 1.0                                   # just hurt by the harpoon
	if state == State.DEFEATED and time >= hurt_time:
		black = 1.0                                   # dead: solid black
	imp.material_override.set_shader_parameter("flash", black)


## Dead, it floats: the current (the Wind autoload's, Wind.current(), downwind) carries it, as it does the boat.
## It stops where the next step would be on land, so it washes up against the shore instead of going through it.
func drift_with_current(dt: float) -> void:
	var next_place: Vector3 = imp.global_position + Wind.current() * dt
	next_place.y = 0.0
	if not Land.is_land(next_place):
		imp.global_position = next_place


## The distance across the water (not the height) from the boat to a point.
func distance_to(boat: Node3D, point: Vector3) -> float:
	var off := boat.global_position - point
	off.y = 0.0
	return off.length()


## The patch (a 1 x 1 m plane) is scaled to lurk_size.
func _fit_patch() -> void:
	var node := get_node_or_null("Patch") as Node3D
	if node:
		node.scale = Vector3(lurk_size, 1.0, lurk_size)


# ---------- In the editor only: `radius` drawn as a disc on the water ----------

var _editor_disc: MeshInstance3D

func _make_editor_disc() -> void:
	# A flat red cylinder, see-through, 1 m across, scaled to the radius. It's made in code and not saved in the
	# scene (no owner), so it never appears in the game.
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.05
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.2, 0.2, 0.25)
	material.render_priority = 10       # drawn after the sea and everything else, never hidden by it from afar
	material.no_depth_test = true       # and on top of the land, so it can be spotted from anywhere
	mesh.material = material
	_editor_disc = MeshInstance3D.new()
	_editor_disc.mesh = mesh
	_editor_disc.position.y = 0.1
	add_child(_editor_disc)
	_fit_editor_disc()


func _fit_editor_disc() -> void:
	if _editor_disc:
		_editor_disc.scale = Vector3(radius, 1.0, radius)

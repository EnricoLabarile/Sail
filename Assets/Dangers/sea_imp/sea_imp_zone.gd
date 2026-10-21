@tool
extends Node3D
## A SEA IMP'S ZONE: a circle of sea where a sea imp lives (the prototype's sea imp). While the boat is inside it,
## the imp comes up out of the water somewhere near her, spits a fireball at her, sinks back under, and comes up
## again somewhere else, over and over. It stops when:
##   - the boat sails out of the zone (she ran away): the imp sinks and waits, and starts again if she comes back;
##   - the boat sinks (0 hearts): the same;
##   - the imp is killed: `max_hits` slingshot stones while it's up. Then it's gone for good.
## A stone that hits it while it's up also makes it duck under at once (and come up elsewhere).
##
## To place one: instance sea_imp_zone.tscn under SeaImps in Overworld (like placing a Blueprint), move it where
## you want it on the sea and set `radius` in the Inspector. In the editor the zone is drawn as a red disc on the
## water and the imp stands in its middle, so you can see them; while playing the disc isn't there.
## (In Unreal: a trigger volume actor that owns its enemy and runs its little state machine every Tick.)
##
## The imp's picture: `Imp` (a camera-facing picture, sea_imp.gdshader) with sea_imp.png, a single frame for now.
## When the animation sheet comes, set frames_x / frames_y on Imp's material and pick `frame` in this script.

const FIREBALL_SCENE := preload("res://Assets/Dangers/sea_imp/fireball.tscn")

## The zone's radius on the water, in metres.
@export var radius := 25.0:
	set(value):
		radius = value
		_fit_editor_disc()
@export var max_hits := 3                  # stones it takes to kill it
@export var spawn_distance_min := 8.0      # metres from the boat it comes up (nearest…
@export var spawn_distance_max := 15.0     # …and furthest), always inside the zone and on water
@export var under_time_min := 1.2          # seconds it stays under before coming up again (shortest…
@export var under_time_max := 2.4          # …and longest)
@export var rise_time := 0.5               # seconds to come up out of the water
@export var spit_after := 0.75             # seconds up (after rising) before it spits
@export var up_time := 1.15                # seconds up in all (after rising) before it sinks again
@export var sink_time := 0.5               # seconds to sink back under
@export var depth := 4.2                   # metres down it sits when it's under (a bit more than the picture's height, 4 m)
@export var fireball_speed := 7.5          # metres a second (she can dodge it)
@export var fireball_damage := 1.0         # hearts a fireball takes off (the prototype's: a heart)
@export var fireball_hit_radius := 1.3     # metres from the boat's middle a fireball hits her
@export var fireball_life := 3.0           # seconds a fireball flies before it's gone
@export var aim_ahead := 0.5               # it aims where the boat will be this many seconds later
@export var spit_height := 1.5             # metres above the water the fireball leaves its mouth
@export var stone_hit_radius := 2.0        # metres from the imp a stone must land to hit it

enum State { WAITING, UNDER, RISING, UP, SINKING, DEAD }

var state := State.WAITING
var time := 0.0            # seconds in the current state
var under_for := 0.0       # how long it stays under this time (picked at random)
var hits_left := 3         # stones it can still take
var has_spat := false      # has it spat its fireball since it came up?

@onready var imp: MeshInstance3D = $Imp


func _ready() -> void:
	if Engine.is_editor_hint():
		_make_editor_disc()
		return
	add_to_group("sea_imps")    # so the slingshot's stones find it when they land (stone.gd)
	hits_left = max_hits
	imp.visible = false


func _process(dt: float) -> void:
	if Engine.is_editor_hint():
		return
	time += dt
	var boat := get_tree().get_first_node_in_group("player_boat")
	var boat_here: bool = boat != null and not boat.sinking and is_inside(boat.global_position)
	match state:
		State.WAITING:
			# Hidden, waiting for her to come into the zone.
			if boat_here:
				hits_left = max_hits     # a fresh start each time she comes in
				go_under()
		State.UNDER:
			# Under water, swimming to its next spot.
			if not boat_here:
				state = State.WAITING
			elif time >= under_for:
				come_up(boat)
		State.RISING:
			# Coming up out of the water.
			set_height(lerpf(-depth, 0.0, minf(time / rise_time, 1.0)))
			if not boat_here:
				start_sinking()
			elif time >= rise_time:
				state = State.UP
				time = 0.0
				has_spat = false
		State.UP:
			# Up: it stares at her, spits, then goes under.
			if not boat_here:
				start_sinking()
			elif time >= spit_after and not has_spat:
				has_spat = true
				spit(boat)
			elif time >= up_time:
				start_sinking()
		State.SINKING:
			# Going back under. Then: gone for good (killed), or under and up again elsewhere.
			set_height(lerpf(0.0, -depth, minf(time / sink_time, 1.0)))
			if time >= sink_time:
				imp.visible = false
				if hits_left <= 0:
					state = State.DEAD
				else:
					go_under()
		State.DEAD:
			pass


## Is this point of the sea inside the zone? (Only the distance across the water counts, not the height.)
func is_inside(point: Vector3) -> bool:
	var off := point - global_position
	off.y = 0.0
	return off.length() <= radius


## Under water, for a little while (a random time between under_time_min and under_time_max).
func go_under() -> void:
	state = State.UNDER
	time = 0.0
	under_for = randf_range(under_time_min, under_time_max)


## Picks a spot on the water near the boat (spawn_distance_min..max away, inside the zone, not on land) and starts
## coming up there. If no spot is found this time (she's near the zone's edge or a shore), it tries again next frame.
func come_up(boat: Node3D) -> void:
	for attempt in 20:
		var angle := randf() * TAU
		var distance := randf_range(spawn_distance_min, spawn_distance_max)
		var spot: Vector3 = boat.global_position + Vector3(cos(angle), 0.0, sin(angle)) * distance
		spot.y = 0.0
		if is_inside(spot) and not Land.is_land(spot):
			imp.global_position = spot
			set_height(-depth)
			imp.visible = true
			state = State.RISING
			time = 0.0
			return


## Starts going back under from wherever it is.
func start_sinking() -> void:
	state = State.SINKING
	time = 0.0


## The imp's height: 0 = up (the bottom of its picture on the water line), -depth = all under.
## (What's under the water isn't drawn: sea_imp.gdshader.)
func set_height(height: float) -> void:
	imp.global_position.y = height


## Spits a fireball at where the boat will be `aim_ahead` seconds from now (if she keeps going as she is).
func spit(boat: Node3D) -> void:
	var forward: Vector3 = -boat.global_transform.basis.z
	var target: Vector3 = boat.global_position + forward * boat.speed * aim_ahead
	var start := imp.global_position + Vector3(0.0, spit_height, 0.0)
	var ball := FIREBALL_SCENE.instantiate()
	get_parent().add_child(ball)     # into the world, not inside the zone
	ball.launch(start, target, fireball_speed, fireball_damage, fireball_hit_radius, fireball_life)


## A slingshot stone has landed at `point` (stone.gd calls this on every zone). If the imp is up (or coming up)
## and the stone fell close enough, it's hit: one hit less; it ducks under at once. At 0 it's dead.
func stone_landed(point: Vector3) -> void:
	if state != State.RISING and state != State.UP:
		return
	var off := point - imp.global_position
	off.y = 0.0
	if off.length() > stone_hit_radius:
		return
	hits_left -= 1
	start_sinking()


# ---------- In the editor only: the zone drawn as a disc on the water ----------

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
	mesh.material = material
	_editor_disc = MeshInstance3D.new()
	_editor_disc.mesh = mesh
	_editor_disc.position.y = 0.1
	add_child(_editor_disc)
	_fit_editor_disc()


func _fit_editor_disc() -> void:
	if _editor_disc:
		_editor_disc.scale = Vector3(radius, 1.0, radius)

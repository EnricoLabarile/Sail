extends Node3D
## THE GUST SPAWNER (Enrico): wind gusts (gust.tscn) are no longer placed on the map; they come from the wind.
## Once the boat has kept her top speed for `full_speed_time` seconds, gusts start to appear at the edge of the
## screen she's sailing UPWIND of (where the wind comes from), at a random place across the wind, and travel
## across the whole screen the way the wind blows. To catch one she steers sideways onto its path. They follow
## the wind: if it turns, new gusts come from the new upwind side and the ones on their way turn with it.
## At most `max_gusts` are on the screen at once. A gust is freed once it has crossed the screen (past her,
## downwind, and out of the camera's view).
## (In Unreal: a spawner actor with a timer that spawns Blueprint actors at the edge of the view.)
##
## One in each level (a plain Node3D with this script, under Gameplay/Gusts in the Overworld). Its numbers are
## below, in the Inspector.

const GUST_SCENE := preload("res://Assets/Landscape/gust/gust.tscn")

@export var full_speed_time := 3.0    # seconds at top speed before the gusts start (and as long as she keeps it)
@export var full_speed_share := 0.95  # what counts as top speed: this share of boat.gd's top_speed (0.95 = 95%)
@export var max_gusts := 3            # how many gusts can be on the screen at the same time
@export var spawn_every_min := 0.8    # seconds between one gust and the next, picked at random between these
@export var spawn_every_max := 1.6
@export var travel_speed := 30      # metres a second they travel downwind (she does 7 at top speed)
@export var spread := 0.8             # how far across the screen they may appear: 1 = anywhere along the edge, 0.5 = the middle half

var boat: Node3D = null               # found once, then kept
var full_speed_for := 0.0             # seconds she has been at top speed without a break
var next_spawn := 0.0                 # seconds left until the next gust may appear
var gusts: Array[Node3D] = []         # the gusts on their way now


func _process(dt: float) -> void:
	if boat == null:
		boat = get_tree().get_first_node_in_group("player_boat") as Node3D
		if boat == null:
			return
	forget_finished_gusts()
	# 1. The condition: she's at top speed (and sailing) for full_speed_time seconds in a row. Any slowing down
	#    starts the count again.
	var fast: bool = boat.speed >= boat.top_speed * full_speed_share and not boat.anchored and not boat.sinking
	if fast:
		full_speed_for += dt
	else:
		full_speed_for = 0.0
	if full_speed_for < full_speed_time:
		return
	# 2. Kept up long enough: a gust every spawn_every seconds, while there's room for one more on the screen.
	next_spawn -= dt
	if next_spawn <= 0.0 and gusts.size() < max_gusts:
		spawn_gust()
		next_spawn = randf_range(spawn_every_min, spawn_every_max)


## A new gust just outside the screen, on the side the wind comes from, somewhere across the wind.
func spawn_gust() -> void:
	var upwind: Vector3 = Wind.from_vector()           # where the wind comes FROM
	upwind.y = 0.0
	upwind = upwind.normalized()
	var across := Vector3(-upwind.z, 0.0, upwind.x)    # at right angles to the wind (the red line in Enrico's sketch)
	# How wide the screen is across the wind, near her: walk out from her both ways until out of view.
	var half_width := distance_to_screen_edge(boat.global_position, across)
	var start := boat.global_position + across * randf_range(-1.0, 1.0) * half_width * spread
	start.y = 0.0
	# Then walk upwind from there until that point is out of the camera's view: that's the screen's edge.
	start += upwind * (distance_to_screen_edge(start, upwind) + 4.0)
	var gust := GUST_SCENE.instantiate()
	gust.travel_speed = travel_speed
	add_child(gust)
	gust.global_position = start
	gusts.append(gust)


## Metres from `from` along `direction` (on the water) to the edge of what the camera sees: steps out 2 m at a
## time until the point is out of view (at most 200 m).
func distance_to_screen_edge(from: Vector3, direction: Vector3) -> float:
	var camera: Camera3D = boat.camera
	var distance := 0.0
	while distance < 200.0:
		var point := from + direction * distance
		point.y = 0.0
		if not camera.is_position_in_frustum(point):
			break
		distance += 2.0
	return distance


## Frees the gusts that have crossed the screen: downwind of her and out of the camera's view.
func forget_finished_gusts() -> void:
	var downwind: Vector3 = -Wind.from_vector()
	downwind.y = 0.0
	for gust in gusts.duplicate():
		if not is_instance_valid(gust):
			gusts.erase(gust)
			continue
		var past_her: bool = (gust.global_position - boat.global_position).dot(downwind) > 0.0
		var far_away: bool = gust.global_position.distance_to(boat.global_position) > 300.0   # a safety net
		if (past_her and not boat.camera.is_position_in_frustum(gust.global_position)) or far_away:
			gusts.erase(gust)
			gust.queue_free()

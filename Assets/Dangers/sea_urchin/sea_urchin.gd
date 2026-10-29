@tool
extends Node3D
## A SEA URCHIN (Enrico): a very large urchin, less aggressive than the sea imp. It never aims at the boat: it
## WANDERS about inside its area for a while, then STOPS and shoots spikes in all 8 directions (north, south, east,
## west and the diagonals), a few times, then wanders again, forever. A spike that hits the boat takes half a heart.
## (In Unreal: an actor with a simple state machine in its Tick, spawning projectile actors.)
##
## This node is the middle of its AREA: a circle of `area_radius` (a red disc in the editor). The urchin itself is
## the child `Urchin`, which moves; it never leaves the circle and never goes onto land.
## The cycle:
##   WALKING   for `walk_time` seconds at `walk_speed`: it heads for a random point of the area, and on reaching
##             it picks another;
##   ATTACKING for `attack_time` seconds, standing still: `shot_count` rounds of 8 spikes, spread evenly over that
##             time (the first right away);
## then WALKING again.

enum State { WALKING, ATTACKING }

## Metres round this node it wanders in (it never leaves this circle). The editor disc follows it.
@export var area_radius := 20.0:
	set(value):
		area_radius = value
		_fit_editor_disc()
@export var walk_speed := 2.0         # metres a second it moves while wandering
@export var walk_time := 4.0          # seconds it wanders before it stops to shoot
@export var attack_time := 2.0        # seconds it stands still shooting
@export var shot_count := 3           # rounds of spikes in each attack (each round = 8 spikes)
@export var spike_speed := 8.0        # metres a second a spike flies (the boat does 7 at top speed)
@export var spike_range := 15.0       # metres a spike flies before it's gone
@export var spike_damage := 0.5       # hearts a spike takes off the boat (Enrico: half a heart)
@export var spike_hit_radius := 1.2   # metres from the boat's middle a spike must come to hit her

const SPIKE_SCENE := preload("res://Assets/Dangers/sea_urchin/spike.tscn")

var state := State.WALKING
var timer := 0.0                      # seconds since the state began
var shots_fired := 0                  # rounds shot in this attack so far
var target := Vector3.ZERO            # where it's walking to, in the area (this node's space)

@onready var urchin: Node3D = $Urchin
var _editor_disc: MeshInstance3D = null


func _ready() -> void:
	if Engine.is_editor_hint():
		_make_editor_disc()           # in the editor only: the area drawn as a see-through red disc
		return
	target = random_point_in_area()


func _process(dt: float) -> void:
	if Engine.is_editor_hint():
		return
	timer += dt
	if state == State.WALKING:
		walk(dt)
		if timer >= walk_time:
			start_attack()
	else:
		attack()


# ---- walking ----

## A step toward the target; on reaching it (or if the way is blocked by land), a new target.
func walk(dt: float) -> void:
	var next := urchin.position.move_toward(target, walk_speed * dt)
	if Land.is_land(to_global(next)):
		target = random_point_in_area()   # land in the way: go somewhere else instead
		return
	urchin.position = next
	if urchin.position.distance_to(target) < 0.1:
		target = random_point_in_area()


## A random point of the area, on water (in this node's space, at the water's height). It tries 20 times; if it
## finds no water, it stays where it is.
func random_point_in_area() -> Vector3:
	for i in 20:
		var angle := randf() * TAU
		var distance := sqrt(randf()) * area_radius   # sqrt: spread evenly over the circle, not bunched in the middle
		var point := Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
		if not Land.is_land(to_global(point)):
			return point
	return urchin.position


# ---- attacking ----

func start_attack() -> void:
	state = State.ATTACKING
	timer = 0.0
	shots_fired = 0


## Shoots its rounds spread evenly over attack_time: round n goes off at n × (attack_time / shot_count) seconds
## (round 0 right away). When the time is up, it goes back to wandering.
func attack() -> void:
	var gap := attack_time / maxf(1.0, shot_count)
	if shots_fired < shot_count and timer >= shots_fired * gap:
		shoot_round()
		shots_fired += 1
	if timer >= attack_time and shots_fired >= shot_count:
		state = State.WALKING
		timer = 0.0


## 8 spikes from the urchin's middle: north, north-east, east… one every eighth of a turn.
func shoot_round() -> void:
	for i in 8:
		var angle := TAU * i / 8.0
		var direction := Vector3(sin(angle), 0.0, -cos(angle))   # angle 0 = north (-Z), then clockwise
		var spike := SPIKE_SCENE.instantiate()
		get_parent().add_child(spike)                            # into the level, so it flies on its own
		var start := urchin.global_position
		start.y = 0.3                                            # just above the water
		spike.launch(start, direction, spike_speed, spike_damage, spike_hit_radius, spike_range)


# ---- the editor disc (the area) ----

## A flat red see-through disc, 1 m across, scaled to the area. Made in code with no owner, so it's never saved
## and never in the game; drawn over everything, from afar too (Enrico's rule for editor helpers).
func _make_editor_disc() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.05
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.2, 0.2, 0.25)
	material.render_priority = 10
	material.no_depth_test = true
	mesh.material = material
	_editor_disc = MeshInstance3D.new()
	_editor_disc.mesh = mesh
	_editor_disc.position.y = 0.1
	add_child(_editor_disc)
	_fit_editor_disc()


func _fit_editor_disc() -> void:
	if _editor_disc:
		_editor_disc.scale = Vector3(area_radius, 1.0, area_radius)

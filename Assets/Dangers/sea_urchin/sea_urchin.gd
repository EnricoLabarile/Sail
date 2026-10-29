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
## A bomb hurts it (Enrico: every enemy can be bombed): in the blast it loses `damage` hearts of its `max_hearts` and
## blinks black for `hurt_time`; at 0 it blinks and is gone (bomb.gd calls blast_at on the group "bomb_targets"),
## with the enemies' death sound (Sfx.enemy_death) and its reward (drop_item, as every enemy: Pickup.drop_loot).

enum State { WALKING, ATTACKING, DEAD }

## Metres round this node it wanders in (it never leaves this circle). The editor disc follows it.
@export var area_radius := 20.0:
	set(value):
		area_radius = value
		_fit_editor_disc()
@export var walk_speed := 2.0         # metres a second it moves while wandering
@export var walk_time := 6.0          # seconds it wanders before it stops to shoot
@export var attack_time := 3.0        # seconds it stands still shooting
@export var shot_count := 1           # rounds of spikes in each attack (each round = 8 spikes)
@export var spike_speed := 6.0        # metres a second a spike flies (the boat does 7 at top speed)
@export var spike_range := 30.0       # metres a spike flies before it's gone
@export var spike_damage := 0.5       # hearts a spike takes off the boat (Enrico: half a heart)
@export var spike_hit_radius := 1.2   # metres from the boat's middle a spike must come to hit her
@export var max_hearts := 3.0         # how much a bomb must take off it to kill it (Enrico: 3 for now)
@export var body_radius := 1.5        # metres: a bomb's blast reaching this close to its middle hits it
@export var touch_radius := 3.0       # metres: the boat's middle this close to it = she ran into it (bounce, half a heart)
@export var hurt_time := 0.5          # seconds it blinks black when hurt (and before it's gone, when killed)
@export var hurt_blinks_per_second := 12.0
@export var drop_item: ItemData = preload("res://Assets/Inventory/items/bomb.tres")   # what it leaves when killed (none = nothing)
@export_range(0.0, 1.0) var drop_chance := 1.0   # how likely it drops it: 1 = always, 0.5 = one time in two
@export var drop_min := 1             # how many it leaves, at least…
@export var drop_max := 2             # …and at most
@export var drop_spread := 3.0        # metres from the urchin they land, at most

const SPIKE_SCENE := preload("res://Assets/Dangers/sea_urchin/spike.tscn")
const Pickup := preload("res://Assets/Items/pickup/pickup.gd")   # for Pickup.drop_loot (every enemy's reward)

var state := State.WALKING
var timer := 0.0                      # seconds since the state began
var shots_fired := 0                  # rounds shot in this attack so far
var target := Vector3.ZERO            # where it's walking to, in the area (this node's space)
var hearts := 3.0                     # its health now (max_hearts at start)
var hurt_left := 0.0                  # seconds of blinking left (0 = not blinking)
var picture_material: StandardMaterial3D   # its own copy of the picture's material (to blink only this one)

@onready var urchin: Node3D = $Urchin
var _editor_disc: MeshInstance3D = null


func _ready() -> void:
	if Engine.is_editor_hint():
		_make_editor_disc()           # in the editor only: the area drawn as a see-through red disc
		return
	target = random_point_in_area()
	hearts = max_hearts
	add_to_group("bomb_targets")          # so a bomb's blast checks it (bomb.gd explode)
	# Its own copy of the picture's material, so blinking one urchin doesn't blink the others.
	var picture := $Urchin/Picture as MeshInstance3D
	picture_material = (picture.mesh.surface_get_material(0) as StandardMaterial3D).duplicate()
	picture.material_override = picture_material


func _process(dt: float) -> void:
	if Engine.is_editor_hint():
		return
	timer += dt
	update_blink(dt)
	if state == State.DEAD:
		if hurt_left <= 0.0:
			queue_free()                  # done blinking: it's gone
		return
	check_touch()
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


# ---- running into the boat ----

## The boat's middle within touch_radius of the urchin: she ran into it (or it walked into her). The boat does the
## rest (boat.gd bump_into_enemy: she bounces back and loses half a heart, once in a while, not every frame).
func check_touch() -> void:
	var boat := get_tree().get_first_node_in_group("player_boat") as Node3D
	if boat == null:
		return
	var off := boat.global_position - urchin.global_position
	off.y = 0.0
	if off.length() <= touch_radius:
		boat.bump_into_enemy(urchin.global_position)


# ---- hurt by a bomb ----

## A bomb went off (bomb.gd): if its blast reaches the urchin's body, it loses the bomb's damage and blinks black;
## at 0 hearts it's dead (it stops, blinks, and is gone).
func blast_at(bomb: Node3D) -> void:
	if state == State.DEAD:
		return
	if not bomb.in_blast(urchin.global_position, body_radius):
		return
	hearts = maxf(0.0, hearts - bomb.damage)
	hurt_left = hurt_time
	if hearts <= 0.0:
		state = State.DEAD
		Sfx.enemy_death()
		Pickup.drop_loot(get_parent(), drop_item, urchin.global_position, drop_chance, drop_min, drop_max, drop_spread)


## The black blink: while hurt_left runs down, the picture switches between black and its own colours (its colour
## multiplies the picture: black = every pixel black, white = as drawn).
func update_blink(dt: float) -> void:
	if hurt_left <= 0.0:
		return
	hurt_left = maxf(0.0, hurt_left - dt)
	var black := int(hurt_left * hurt_blinks_per_second) % 2 == 0 and hurt_left > 0.0
	picture_material.albedo_color = Color.BLACK if black else Color.WHITE


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

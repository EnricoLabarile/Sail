@tool
extends Node3D
## A BIG WAVES ZONE: a circle of sea (`radius`) where big waves roll in (the prototype's rollers), placed by hand.
## While the boat is inside it, every `spawn_every_min`..`max` seconds a wave rises upwind of her (so she sees it
## coming) and rolls downwind (big_wave.gd); at most `max_waves` at once. And while she runs downwind (the wind at
## least `downwind_deg` round from her bow) she now and then gets a wave of her own: it rises just astern of her,
## a little off to one side, already at her pace, so a touch of the helm lets her catch it and surf.
## Waves die down before land and at the zone's edge.
##
## To place one: instance wave_zone.tscn under BigWaves in Overworld (like placing a Blueprint), move it and set
## `radius`. In the editor a see-through green disc shows it; in the game there's nothing to see but the waves.
## The boat coming in and going out is told by the physics engine (Sensor, an Area3D: like a Trigger Volume).

const WAVE_SCENE := preload("res://Assets/Dangers/big_waves/big_wave.tscn")

## Metres round the zone's middle where the waves roll.
@export var radius := 60.0:
	set(value):
		radius = value
		_fit_sensor()
		_fit_editor_disc()
@export var spawn_every_min := 1.5     # seconds between two waves (shortest…
@export var spawn_every_max := 3.0     # …longest)
@export var max_waves := 10            # at most this many at once
@export var spawn_back_min := 6.0      # metres upwind of her a wave rises (nearest…
@export var spawn_back_max := 36.0     # …furthest)
@export var spawn_side := 26.0         # metres it may be off to either side
@export var length_min := 4.5          # metres along a wave's crest (shortest…
@export var length_max := 7.5          # …longest)
@export var pace_min := 2.5            # metres a second a wave rolls (slowest…
@export var pace_max := 3.0            # …fastest)
@export var life_min := 4.0            # seconds a wave lives (shortest…
@export var life_max := 6.0            # …longest)
@export var damage := 0.5              # hearts a wave takes off when it hits her badly
@export var catch_up := 2.5            # m/s a wave behind her runs faster than her, to catch her for surfing
@export var max_pace := 12.0           # m/s a wave hurrying after her never goes faster than this
@export var spare := 0.55              # a wave about to hit her badly slows to this share of its pace
@export var downwind_deg := 120.0      # she's running downwind when the wind comes from at least this far round from her bow
@export var surf_wave_chance := 0.3    # chance each second, while she runs downwind, of a wave of her own…
@export var surf_wave_back := 10.0     # …rising this many metres astern of her…
@export var surf_wave_side := 4.5      # …up to this far off to either side

var boat_inside := false       # is the boat in the zone? (told by the sensor)
var spawn_wait := 1.0          # seconds to the next wave
var surf_wave: Node3D          # her own wave, while it lives (one at a time)


func _ready() -> void:
	_fit_sensor()
	if Engine.is_editor_hint():
		_make_editor_disc()
		return
	$Sensor.area_entered.connect(_on_sensor_entered)
	$Sensor.area_exited.connect(_on_sensor_exited)
	set_process(false)    # waves only while she's in the zone: the sensor switches it on and off


func _on_sensor_entered(area: Area3D) -> void:
	if area.get_parent().is_in_group("player_boat"):
		boat_inside = true
		set_process(true)


func _on_sensor_exited(area: Area3D) -> void:
	if area.get_parent().is_in_group("player_boat"):
		boat_inside = false
		set_process(false)


func _process(dt: float) -> void:
	if Engine.is_editor_hint() or not boat_inside:
		return
	var boat := get_tree().get_first_node_in_group("player_boat") as Node3D
	if boat == null or boat.sinking or boat.berth != null:
		return
	# 1. Every few seconds, a wave upwind of her (if there's room for one more).
	spawn_wait -= dt
	if spawn_wait <= 0.0:
		spawn_wait = randf_range(spawn_every_min, spawn_every_max)
		if count_waves() < max_waves:
			spawn_upwind(boat)
	# 2. Running downwind: now and then a wave of her own, just astern.
	if not is_instance_valid(surf_wave):
		surf_wave = null
	if surf_wave == null and is_running_downwind(boat):
		# surf_wave_chance per second (worked out for this frame's share of a second)
		if randf() < 1.0 - pow(1.0 - surf_wave_chance, dt):
			spawn_surf_wave(boat)


## Is this point of the sea inside the zone? (Only the distance across the water counts.)
func is_inside(point: Vector3) -> bool:
	var off := point - global_position
	off.y = 0.0
	return off.length() <= radius


## How many of this zone's waves are rolling now.
func count_waves() -> int:
	var n := 0
	for wave in get_tree().get_nodes_in_group("big_waves"):
		if wave.zone == self:
			n += 1
	return n


## The way the waves roll: downwind (the wind blows FROM Wind.from_vector(), so they go the other way).
func downwind() -> Vector3:
	return -Wind.from_vector()


## She runs downwind if the wind comes from at least downwind_deg round from her bow, and she's under way.
func is_running_downwind(boat: Node3D) -> bool:
	if boat.anchored or boat.speed < 0.6:
		return false
	var forward: Vector3 = -boat.global_transform.basis.z
	var off_wind := rad_to_deg(forward.angle_to(Wind.from_vector()))   # 0 = head to wind, 180 = wind astern
	return off_wind >= downwind_deg


## A wave somewhere upwind of her: up to 20 tries for a spot in the zone, on water, with water ahead of it.
func spawn_upwind(boat: Node3D) -> void:
	var travel := downwind()
	var side := Vector3(-travel.z, 0.0, travel.x)
	for attempt in 20:
		var back := randf_range(spawn_back_min, spawn_back_max)
		var offset := randf_range(-spawn_side, spawn_side)
		var spot: Vector3 = boat.global_position - travel * back + side * offset
		if can_rise_at(spot, travel):
			make_wave(spot, randf_range(pace_min, pace_max), randf_range(life_min, life_max))
			return


## Her own wave: just astern, a little off to one side, already rolling at her pace plus catch_up (so it closes
## in on her), and living long enough to reach her.
func spawn_surf_wave(boat: Node3D) -> void:
	var travel := downwind()
	var side := Vector3(-travel.z, 0.0, travel.x)
	var back := surf_wave_back * randf_range(0.85, 1.15)
	var spot: Vector3 = boat.global_position - travel * back + side * randf_range(-surf_wave_side, surf_wave_side)
	if not can_rise_at(spot, travel):
		return
	var base := randf_range(pace_min, pace_max)
	var forward: Vector3 = -boat.global_transform.basis.z
	var her_pace: float = boat.speed * forward.dot(travel) + boat.drift.dot(travel)   # her way plus the current's
	var pace := clampf(her_pace + catch_up, base, max_pace)
	surf_wave = make_wave(spot, pace, randf_range(5.5, 6.5))
	surf_wave.base_speed = base


## A wave may rise at a spot in the zone, on water, with 12 m of water (in the zone) ahead of it.
func can_rise_at(spot: Vector3, travel: Vector3) -> bool:
	var ahead := spot + travel * 12.0
	return is_inside(spot) and is_inside(ahead) and not Land.is_land(spot) and not Land.is_land(ahead)


func make_wave(spot: Vector3, pace: float, life: float) -> Node3D:
	var wave := WAVE_SCENE.instantiate()
	wave.add_to_group("big_waves")
	get_parent().add_child(wave)          # into the world, not inside the zone
	wave.launch(self, spot, downwind(), randf_range(length_min, length_max), pace, life)
	return wave


## The sensor's cylinder is as wide as the zone (its own copy of the shape: local to scene in wave_zone.tscn).
func _fit_sensor() -> void:
	var shape := get_node_or_null("Sensor/Shape") as CollisionShape3D
	if shape and shape.shape:
		shape.shape.radius = radius


# ---------- In the editor only: the zone drawn as a disc on the water ----------
# Made in code with no owner, so it isn't saved in the scene and never appears in the game.

var _editor_disc: MeshInstance3D

func _make_editor_disc() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.05
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.2, 0.9, 0.4, 0.2)
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

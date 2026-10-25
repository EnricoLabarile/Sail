@tool
extends Node3D
## A MAELSTROM: a whirlpool that wanders inside its zone (a circle of zone_radius round this node), shows for
## shown_time seconds, hides for hidden_time, then comes back somewhere else in the zone, forever.
## It has two parts: the outer ring (Outer) and the core (Core), both turning.

@export var zone_radius := 20.0:     # metres: the circle it wanders in, round this node
	set(value):
		zone_radius = value
		_fit_editor_disc()
@export var outer_radius := 4:    # metres: the outer ring's size
	set(value):
		outer_radius = value
		fit_pictures()               # the picture follows at once, in the editor too

@export var core_radius := 1:      # metres: the core's size
	set(value):
		core_radius = value
		fit_pictures()
@export var wander_speed := 2.0      # metres a second it drifts about
@export var shown_time := 15        # seconds it's there…
@export var hidden_time := 5       # …and seconds it's gone
@export var spin_speed := 2.0        # how fast the pictures turn (radians a second; 6.28 = a full turn)
@export var fade_time := 3         # seconds it takes to fade in or out
@export var pull_strength := 4.0     # m/s she's pulled toward the eye at the core's edge (top_speed is 7)


var fade := 0.0                      # 0 = invisible, 1 = fully there



var showing := true                  # is it there now?
var timer := 0.0                     # seconds since it appeared (or disappeared)
var target := Vector3.ZERO           # the point it's drifting toward, inside the zone

@onready var whirl: Node3D = $Whirl
@onready var outer: MeshInstance3D = $Whirl/Outer
@onready var core: MeshInstance3D = $Whirl/Core


func _ready() -> void:
	
	fit_pictures()
	
	# Each maelstrom gets its own copy of the materials, so fading one doesn't fade the others.
	outer.material_override = outer.material_override.duplicate()
	core.material_override = core.material_override.duplicate()
	
	if Engine.is_editor_hint():
		_make_editor_disc()          # in the editor only: the zone drawn as a see-through disc
		return                       # in the editor: just the look, it doesn't move
	appear()
	
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
		_editor_disc.scale = Vector3(zone_radius, 1.0, zone_radius)



func _process(dt: float) -> void:
	if Engine.is_editor_hint():
		return
	timer += dt
	
		# Fade toward 1 while it's showing, toward 0 while it's gone.
	var wanted := 1.0 if showing else 0.0
	fade = move_toward(fade, wanted, dt / fade_time)
	set_fade(fade)
	
	outer.rotate_y(-spin_speed * dt)          # minus: clockwise seen from above
	core.rotate_y(-spin_speed * 2.0 * dt)     # the core turns faster
	
	if showing:
		
		wander(dt)
		if timer >= shown_time:
			disappear()
	else:
		if timer >= hidden_time:
			appear()


## Shows up at a random point of the zone and picks where to drift to.
func appear() -> void:
	showing = true
	timer = 0.0
	whirl.position = random_point_in_zone()
	target = random_point_in_zone()
	


## Goes away (for hidden_time seconds).
func disappear() -> void:
	showing = false
	timer = 0.0
	


## Drifts toward the target at wander_speed; once there, picks a new one.
func wander(dt: float) -> void:
	whirl.position = whirl.position.move_toward(target, wander_speed * dt)
	if whirl.position.distance_to(target) < 0.1:
		target = random_point_in_zone()


## A random point inside the zone, far enough in that the whole outer ring stays inside it.
func random_point_in_zone() -> Vector3:
	var angle := randf() * TAU                                        # a random direction
	var distance := sqrt(randf()) * (zone_radius - outer_radius)      # a random distance from the middle
	return Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)

## Sets how see-through both pictures are: 0 = invisible, 1 = solid.
func set_fade(amount: float) -> void:
	outer.material_override.albedo_color.a = amount
	core.material_override.albedo_color.a = amount
	whirl.visible = amount > 0.0     # fully faded out: not drawn at all (cheaper)

## Makes the two pictures as big as their radii (the planes are 1 x 1 m: diameter = radius x 2).
func fit_pictures() -> void:
	# When the scene loads, the setters run BEFORE _ready, when outer and core aren't found yet
	# (@onready fills them in only at _ready): then there's nothing to scale, so stop here.
	if outer == null or core == null:
		return
	outer.scale = Vector3(outer_radius * 2.0, 1.0, outer_radius * 2.0)
	core.scale = Vector3(core_radius * 2.0, 1.0, core_radius * 2.0)
	
## Is it dangerous now? Only once fully faded in, and not while fading out:
## while it fades in or out it's just a picture (no pull, no damage, no fling).
func is_active() -> bool:
	return showing and fade >= 1.0
	
	
## Pulls the boat toward the eye while she's inside the outer ring: nothing at the ring's edge,
## pull_strength at the core's edge (and inside it).
func pull_boat() -> void:
	var boat := get_tree().get_first_node_in_group("player_boat") as Node3D
	if boat == null:
		return
	# From the boat to the eye, flat on the sea (y = 0, so she's never pulled up or down).
	var to_eye := whirl.global_position - boat.global_position
	to_eye.y = 0.0
	var distance := to_eye.length()
	if distance > outer_radius or distance < 0.01:
		return                       # outside the ring (or right in the eye): no pull
	# 0 at the ring's edge, 1 at the core's edge; clamped so inside the core it stays 1.
	var closeness := clampf((outer_radius - distance) / (outer_radius - core_radius), 0.0, 1.0)
	boat.whirl_pull += to_eye.normalized() * pull_strength * closeness

## At the physics' pace (with the boat's movement): the pull, only while it's dangerous.
func _physics_process(_dt: float) -> void:
	if Engine.is_editor_hint():
		return
	if is_active():
		pull_boat()

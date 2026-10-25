@tool
extends Node3D
## A MAELSTROM: a whirlpool that wanders inside its zone (a circle of zone_radius round this node), shows for
## shown_time seconds, hides for hidden_time, then comes back somewhere else in the zone, forever.
## It has two parts: the outer ring (Outer) and the core (Core), both turning.

@export var zone_radius := 30.0:     # metres: the circle it wanders in, round this node
	set(value):
		zone_radius = value
		_fit_editor_disc()
@export var outer_radius := 10.0     # metres: the outer ring's size
@export var core_radius := 2.5       # metres: the core's size
@export var wander_speed := 2.0      # metres a second it drifts about
@export var shown_time := 5.0        # seconds it's there…
@export var hidden_time := 3.0       # …and seconds it's gone
@export var spin_speed := 2.0        # how fast the pictures turn (radians a second; 6.28 = a full turn)

var showing := true                  # is it there now?
var timer := 0.0                     # seconds since it appeared (or disappeared)
var target := Vector3.ZERO           # the point it's drifting toward, inside the zone

@onready var whirl: Node3D = $Whirl
@onready var outer: MeshInstance3D = $Whirl/Outer
@onready var core: MeshInstance3D = $Whirl/Core


func _ready() -> void:
	outer.scale = Vector3(outer_radius * 2.0, 1.0, outer_radius * 2.0)
	core.scale = Vector3(core_radius * 2.0, 1.0, core_radius * 2.0)
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
	if showing:
		outer.rotate_y(-spin_speed * dt)          # minus: clockwise seen from above
		core.rotate_y(-spin_speed * 2.0 * dt)     # the core turns faster
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
	whirl.visible = true


## Goes away (for hidden_time seconds).
func disappear() -> void:
	showing = false
	timer = 0.0
	whirl.visible = false


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

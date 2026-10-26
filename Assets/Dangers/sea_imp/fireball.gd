extends Node3D
## ONE FIREBALL, spat by a sea imp (sea_imp_zone.gd): it flies straight, at a steady height over the water, toward
## where the boat was going to be. If it comes within `hit_radius` of her she loses `damage` hearts and it's gone;
## it's also gone when it reaches land or after `life` seconds (it missed).
## (In Unreal: a small projectile actor moving itself every Tick, overlap-tested against the player's pawn.)
##
## Its picture is a sheet of frames (fireball.png, frames_x × frames_y), played over and over: it flickers.

@export var frames_x := 4          # frames across the sheet
@export var frames_y := 4          # frames down
@export var fps := 12.0            # frames a second (it loops)

@onready var picture: MeshInstance3D = $Picture   # the ball, facing the camera

var velocity := Vector3.ZERO   # metres a second, across the water (set by launch)
var damage := 1.0              # hearts it takes off the boat when it hits
var hit_radius := 5          # metres: this close to the boat's middle, it hits her
var life := 3.0                # seconds before it's gone, hit or not
var time := 0.0                # seconds since it was spat


## The sea imp calls this right after adding the fireball to the world.
func launch(start: Vector3, target: Vector3, speed: float, hearts: float, radius: float, seconds: float) -> void:
	global_position = start
	var way := target - start
	way.y = 0.0                          # it flies level, at the height it was spat
	velocity = way.normalized() * speed
	damage = hearts
	hit_radius = radius
	life = seconds
	# Each fireball has its own copy of the material (so each shows its own frame).
	picture.material_override = picture.material_override.duplicate()
	set_frame(randi() % (frames_x * frames_y))


func _process(dt: float) -> void:
	time += dt
	global_position += velocity * dt
	set_frame(int(time * fps) % (frames_x * frames_y))
	# Out of time, or over land: gone.
	if time >= life or Land.is_land(global_position):
		queue_free()
		return
	# Close enough to the boat: it hits her.
	var boat := get_tree().get_first_node_in_group("player_boat")
	if boat == null or boat.sinking:
		return
	var off: Vector3 = boat.global_position - global_position
	off.y = 0.0                          # only the distance across the water
	if off.length() < hit_radius:
		boat.take_damage(damage)
		queue_free()


func set_frame(frame: int) -> void:
	var material: ShaderMaterial = picture.material_override
	material.set_shader_parameter("frame", frame)
	material.set_shader_parameter("frames_x", frames_x)
	material.set_shader_parameter("frames_y", frames_y)

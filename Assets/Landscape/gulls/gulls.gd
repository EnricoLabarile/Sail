extends Node3D
## GULLS: now and then a small flock (1 to 3 gulls, in a loose V) flies across the screen, high up, roughly
## downwind, weaving a little, as in the prototype. Each gull is a flat picture (a PlaneMesh lying level) showing
## a flipbook (gull.gdshader, gull.png): Enrico draws the wings beating in it.
## They're on the clouds' render layer, so the clouds' shadow map sees them too: they cast a shadow on the sea,
## the land and the boat, like the clouds (clouds.gd, cloud_shadow.gdshader).
## (In Unreal: an actor that spawns a few flying sprites now and then and destroys them once they're gone.)

@export var gull_texture: Texture2D           # the flipbook (gull.png, 4 x 4 frames)
@export var gull_size := 2.2                  # metres the picture covers, a side (the prototype's gulls spanned 22 px)
@export var height := 12.0                    # metres above the sea (the clouds are at 35)
@export var fps := 12.0                       # flipbook frames a second
@export var first_flock_after := Vector2(6.0, 10.0)   # seconds before the first flock (from, to: a random time)
@export var flock_every := Vector2(15.0, 22.0)        # seconds between flocks (from, to)
@export var speed := Vector2(7.2, 9.5)        # metres a second they fly (from, to; the prototype's 72–95 px/s)
@export var spawn_distance := 70.0            # metres from the boat they appear and vanish: just off the screen
@export var weave := 0.6                      # metres a second they drift side to side, slowly

const CLOUD_LAYER := 2   # the clouds' render layer (clouds.gd): the shadow-map camera sees it

var flock_timer := 0.0
var gulls: Array[MeshInstance3D] = []   # the gulls flying now
var mesh: PlaneMesh                     # one flat square, shared by every gull


func _ready() -> void:
	flock_timer = randf_range(first_flock_after.x, first_flock_after.y)
	mesh = PlaneMesh.new()
	mesh.size = Vector2(gull_size, gull_size)


func _process(dt: float) -> void:
	# 1. Time for a new flock?
	flock_timer -= dt
	if flock_timer <= 0.0:
		flock_timer = randf_range(flock_every.x, flock_every.y)
		start_flock()

	# 2. Every gull flies on, weaving a little, and goes once it has flown far enough.
	for gull in gulls.duplicate():   # (a copy: gulls may be taken out of the list while going through it)
		var forward: Vector3 = gull.get_meta("forward")
		var side := Vector3(-forward.z, 0.0, forward.x)        # at right angles to the way it flies
		var wobble: float = gull.get_meta("wobble") + dt * 0.9
		gull.set_meta("wobble", wobble)
		var gull_speed: float = gull.get_meta("speed")
		gull.position += forward * gull_speed * dt + side * cos(wobble) * weave * dt
		var left: float = gull.get_meta("left") - gull_speed * dt   # metres still to fly
		gull.set_meta("left", left)
		if left <= 0.0:
			gulls.erase(gull)
			gull.queue_free()


## A flock of 1 to 3 gulls, starting just off the screen on the upwind side, flying across past the boat.
func start_flock() -> void:
	var boat := get_tree().get_first_node_in_group("player_boat") as Node3D
	if boat == null:
		return
	# Which way: downwind (the way the clouds drift), give or take 40 degrees.
	var downwind := -Wind.from_vector()
	downwind.y = 0.0
	var forward := downwind.normalized().rotated(Vector3.UP, randf_range(-0.7, 0.7))
	var side := Vector3(-forward.z, 0.0, forward.x)
	# Where: behind the boat (upwind) by spawn_distance, a little to one side, high up.
	var start := boat.global_position - forward * spawn_distance + side * randf_range(-15.0, 15.0)
	start.y = height
	var flock_speed := randf_range(speed.x, speed.y)
	var count := randi_range(1, 3)
	for k in count:
		# A loose V: each one a little further back, and out to one side then the other.
		var back := k * randf_range(2.2, 3.4)
		var out := (1.0 if k % 2 == 1 else -1.0) * k * randf_range(1.2, 2.0)
		var position_in_flock := start - forward * back - side * out
		var gull := make_gull(forward)
		gull.position = position_in_flock
		gull.set_meta("forward", forward)
		gull.set_meta("speed", flock_speed * randf_range(0.95, 1.05))
		gull.set_meta("wobble", randf() * TAU)
		gull.set_meta("left", spawn_distance * 2.0 + 20.0 + back)   # across the screen and out the other side
		gulls.append(gull)


## One gull: the flat square with its own copy of the material (its own starting frame), turned so the top of
## the picture (the head) points the way it flies.
func make_gull(forward: Vector3) -> MeshInstance3D:
	var material := ShaderMaterial.new()
	material.shader = preload("res://Assets/Landscape/gulls/gull.gdshader")
	material.render_priority = 2   # see-through things: with the clouds, after the sea and the shadows, before the fog
	material.set_shader_parameter("gull_tex", gull_texture)
	material.set_shader_parameter("fps", fps)
	material.set_shader_parameter("phase", randf() * 16.0)
	var gull := MeshInstance3D.new()
	gull.mesh = mesh
	gull.material_override = material
	gull.layers = CLOUD_LAYER                     # seen by the game camera and by the clouds' shadow map
	gull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gull.rotation.y = atan2(-forward.x, -forward.z)   # the picture's top (north, -z) turned to face `forward`
	add_child(gull)
	return gull

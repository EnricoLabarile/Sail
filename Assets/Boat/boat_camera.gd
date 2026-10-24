extends Camera3D
## THE BOAT'S CAMERA: everything about how the game is looked at, in one place. It sits on the Camera3D node
## inside boat.tscn (like a Camera Component with its own Blueprint logic in Unreal), and boat.gd only talks
## to it through two calls: shake() when she takes damage, jump_to_boat() when she's put back home.
##
## What it does:
##   - it looks at her from the south, tilted (tilt_deg), always the same way up: it doesn't turn with her
##     (like a spring arm that doesn't inherit rotation);
##   - it follows her loosely: a dead zone round the point it looks at (focus); while she stays in it the
##     camera stays still; out of it, the camera glides after her until she's back on the zone's edge;
##   - it shakes when she's hurt (h_offset / v_offset: they move the picture, not the camera, so the
##     following isn't disturbed);
##   - it carries the ink outline round the boat (boat_outline.gdshader), a screen effect in front of it.

@export var tilt_deg := 20.0         # the camera's tilt from straight down (the prototype's BOAT_TILT look)
# How far it sits from her, along the way it looks. It's orthographic (no perspective), so this doesn't change
# the picture at all: it only has to be far enough that tall things (the clouds) near the bottom of the screen
# don't end up behind the camera's near plane and get cut off.
@export var distance := 100.0
@export var dead_zone := 6.0         # metres she can move before the camera follows (0 = always follow)
@export var follow_speed := 3.0      # how quickly it catches up once she's out (higher = quicker)
@export var shake_strength := 0.5    # metres the view jumps about at first, when she's hurt
@export var shake_time := 0.3        # seconds the shake lasts, dying away
@export var outline_width := 1.5     # the ink outline round her, in phone points (0 = no outline)

var focus := Vector3.ZERO            # the point on the water it looks at (it trails behind her)
var shake_left := 0.0                # seconds of shake left

@onready var boat: Node3D = get_parent()   # the boat this camera belongs to (Camera3D is a child of Boat)


func _ready() -> void:
	top_level = true                 # it follows her position by itself, not her turning
	focus = boat.global_position     # it starts right over her
	add_outline()


func _process(dt: float) -> void:
	follow(dt)
	update_shake(dt)
	# From the south, tilted, looking at `focus`: up and back along the tilt by `distance`.
	var t := deg_to_rad(tilt_deg)
	global_position = focus + Vector3(0.0, cos(t), sin(t)) * distance
	global_rotation = Vector3(-(PI / 2.0 - t), 0.0, 0.0)


# ---- what the boat calls ----

## She took damage: the screen shakes for shake_time seconds.
func shake() -> void:
	shake_left = shake_time


## She was put somewhere else at once (back home): the camera jumps there too, no glide across the map.
func jump_to_boat() -> void:
	focus = boat.global_position


# ---- inside the camera ----

## The point it looks at trails after her: inside the dead zone it stays still, outside it glides toward her
## until she's back on the zone's edge.
func follow(dt: float) -> void:
	var off := boat.global_position - focus   # from the camera's point to her
	off.y = 0.0
	if off.length() > dead_zone:
		var goal := boat.global_position - off.normalized() * dead_zone   # puts her right on the edge
		focus = focus.lerp(goal, minf(1.0, follow_speed * dt))


## The shake, every frame while it lasts: a random jump sideways and up/down, less and less as it dies away.
func update_shake(dt: float) -> void:
	if shake_left <= 0.0:
		h_offset = 0.0
		v_offset = 0.0
		return
	shake_left = maxf(0.0, shake_left - dt)
	var amount := shake_strength * shake_left / shake_time
	h_offset = randf_range(-amount, amount)
	v_offset = randf_range(-amount, amount)


## The ink outline round the boat (Assets/Boat/boat_outline.gdshader): a rectangle in front of the camera that
## the shader stretches over the whole screen. Made here in code (and not in the scene) so it doesn't cover the
## editor's view.
func add_outline() -> void:
	var outline := ShaderMaterial.new()
	outline.shader = load("res://Assets/Boat/boat_outline.gdshader")
	outline.render_priority = 1                 # drawn after the sea (0), so the line sits on the water
	outline.set_shader_parameter("outline_width", outline_width)
	var quad := QuadMesh.new()
	quad.material = outline
	var screen := MeshInstance3D.new()
	screen.mesh = quad
	screen.extra_cull_margin = 16384.0         # never skipped as "out of view" (the shader moves it)
	screen.position = Vector3(0.0, 0.0, -1.0)  # just in front of the camera
	add_child(screen)

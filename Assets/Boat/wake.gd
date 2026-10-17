extends MeshInstance3D
## THE WAKE: a ribbon of foam on the water behind the boat.
##
## As the boat sails, every `point_spacing` metres it drops a point at her stern (behind her middle). Each
## point remembers where it was dropped, when, and how fast she was going. Every frame a flat strip is built
## through those points (a triangle strip with ImmediateMesh: in Unreal, a Procedural Mesh rebuilt each Tick):
## narrow near the boat, wider further back (the wake spreads), and fading out as the points get older.
## Old points are dropped, so the ribbon has at most a few dozen points: one cheap draw call.
## The look is in wake.gdshader (white, soft edges; you can give it a foam drawing).

@export var point_spacing := 0.8    # metres between two points of the ribbon
@export var life := 3.0             # seconds a point lasts: the wake's length in time
@export var width_start := 0.8      # metres wide just behind the boat…
@export var width_end := 3.0        # …and at the end of the wake
@export var stern_offset := 2.0     # metres from the boat's middle back to where the wake starts
@export var min_speed := 0.5        # m/s: slower than this, no new foam
@export var height := 0.03          # metres above the water (just above it, so it shows)

# The ribbon's points, oldest first. Each is a Dictionary: {"pos": Vector3, "time": float, "strength": float}
var points: Array = []
var immediate := ImmediateMesh.new()
var material := ShaderMaterial.new()

@onready var boat: Node3D = get_parent()


func _ready() -> void:
	top_level = true                # it stays in the world: it doesn't move or turn with the boat
	global_transform = Transform3D.IDENTITY
	mesh = immediate
	material.shader = load("res://Assets/Boat/wake.gdshader")
	material.render_priority = 1    # see-through things: drawn after the sea (0), before the fog (2)
	extra_cull_margin = 16384.0     # its box changes every frame: never skip it as "out of view"


func _process(_dt: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var stern := stern_point()
	var strength := clampf(boat.speed / boat.top_speed, 0.0, 1.0)

	# 1. Drop a new point when she has moved point_spacing metres since the last one (and is moving).
	if boat.speed > min_speed:
		if points.is_empty() or points[-1]["pos"].distance_to(stern) >= point_spacing:
			points.append({"pos": stern, "time": now, "strength": strength})

	# 2. Forget the points older than `life` (they're at the start of the list).
	while not points.is_empty() and now - points[0]["time"] > life:
		points.pop_front()

	# 3. Build the ribbon.
	build_ribbon(now, stern, strength)


## Where the wake starts: behind the boat's middle, on the water.
func stern_point() -> Vector3:
	var back: Vector3 = boat.global_transform.basis.z    # +Z is her back (forward is -Z)
	var p: Vector3 = boat.global_position + back * stern_offset
	p.y = height
	return p


## Builds the strip: for each point, two corners, one each side of the path, as far apart as the wake is
## wide there. The newest end is the stern right now, so the ribbon always reaches the boat.
func build_ribbon(now: float, stern: Vector3, strength: float) -> void:
	immediate.clear_surfaces()
	# The path, from the oldest point to the stern now.
	var path: Array = points.duplicate()
	if boat.speed > min_speed:
		path.append({"pos": stern, "time": now, "strength": strength})
	if path.size() < 2:
		return                                           # nothing to draw yet

	immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, material)
	for i in path.size():
		var point: Dictionary = path[i]
		# a. How old this point is, 0 (new) .. 1 (about to go).
		var age := clampf((now - point["time"]) / life, 0.0, 1.0)
		# b. Which way the path goes here (from the point before to the point after), and the
		#    sideways direction, flat on the water.
		var before: Vector3 = path[maxi(i - 1, 0)]["pos"]
		var after: Vector3 = path[mini(i + 1, path.size() - 1)]["pos"]
		var along := (after - before).normalized()
		var side := Vector3(-along.z, 0.0, along.x)
		# c. Its width (wider as it ages) and how strong the foam is (fading as it ages).
		var half_width := lerpf(width_start, width_end, age) / 2.0
		var alpha: float = point["strength"] * (1.0 - age)
		# d. The two corners. UV: x across (0 one side, 1 the other), y along (0 new, 1 old).
		immediate.surface_set_color(Color(1, 1, 1, alpha))
		immediate.surface_set_uv(Vector2(0.0, age))
		immediate.surface_add_vertex(point["pos"] - side * half_width)
		immediate.surface_set_color(Color(1, 1, 1, alpha))
		immediate.surface_set_uv(Vector2(1.0, age))
		immediate.surface_add_vertex(point["pos"] + side * half_width)
	immediate.surface_end()

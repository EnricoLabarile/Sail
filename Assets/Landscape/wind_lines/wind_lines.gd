extends Node3D
## WIND LINES: thin wavy ink lines that appear on the sea round the boat, draw themselves out the way the
## wind blows, drift a little with it and vanish (as the prototype's wind streaks).
## Each line is a long, narrow flat rectangle (a MeshInstance3D with a PlaneMesh) and wind_line.gdshader
## draws the line on it. A few lines are made once at the start and used again and again (a pool, as in
## Unreal): when one is finished, it waits until it's needed again somewhere else.

@export var line_count := 32            # how many lines can be on the sea at once
@export var lines_per_second := 0.6    # how many new lines appear each second (on average)
@export var line_length := 6.0         # metres
@export var line_width := 0.22         # metres (about two dots on the screen)
@export var line_life := 2.2           # seconds a line lasts, from appearing to gone
@export var spawn_radius := 25.0       # the furthest from the boat a line can appear, in metres
@export var spawn_radius_min := 4.0    # the nearest
@export var drift_speed := 1.5         # metres a second the lines drift with the wind
@export var line_alpha := 1.0          # how dark the ink is (0..1; under 1 the dither breaks the line up)

const PLANE_WIDTH := 0.8   # the rectangle's width: room for the line to bend either side
const WIND_LINE_SHADER := preload("res://Assets/Landscape/wind_lines/wind_line.gdshader")

var lines: Array[MeshInstance3D] = []   # the pool of lines
var ages: Array[float] = []             # how long each line has been showing (seconds)
var spawn_timer := 0.0                  # seconds until the next line appears


func _ready() -> void:
	for i in line_count:
		lines.append(make_line())
		ages.append(line_life)   # finished: free to be used


## Makes one line: the flat rectangle on the water, with its own copy of the material
## (so each line can be at a different moment of its life).
func make_line() -> MeshInstance3D:
	var mesh := PlaneMesh.new()               # a flat rectangle facing up, its length along x
	mesh.size = Vector2(line_length, PLANE_WIDTH)
	var material := ShaderMaterial.new()
	material.shader = WIND_LINE_SHADER
	material.render_priority = 1              # drawn after the sea, before the clouds and the fog
	material.set_shader_parameter("plane_length", line_length)
	material.set_shader_parameter("plane_width", PLANE_WIDTH)
	material.set_shader_parameter("line_width", line_width)
	material.set_shader_parameter("alpha", line_alpha)
	mesh.material = material
	var line := MeshInstance3D.new()
	line.mesh = mesh
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	line.visible = false
	add_child(line)
	return line


func _process(dt: float) -> void:
	var downwind := -Wind.from_vector()   # the way the wind blows (as the clouds drift)
	downwind.y = 0.0

	# 1. Time for a new line? (Not at a steady beat: a little sooner or later each time.)
	spawn_timer -= dt
	if spawn_timer <= 0.0:
		spawn_timer = randf_range(0.5, 1.5) / lines_per_second
		start_line(downwind)

	# 2. Every line showing: older, drifting with the wind, and its shader told how far along it is.
	for i in lines.size():
		var line := lines[i]
		if not line.visible:
			continue
		ages[i] += dt
		if ages[i] >= line_life:
			line.visible = false   # finished: back in the pool
			continue
		line.position += downwind * drift_speed * dt
		var material: ShaderMaterial = line.mesh.material
		material.set_shader_parameter("progress", ages[i] / line_life)


## Takes a free line from the pool and puts it somewhere round the boat, along the wind.
func start_line(downwind: Vector3) -> void:
	var boat := get_tree().get_first_node_in_group("player_boat") as Node3D
	if boat == null:
		return
	for i in lines.size():
		var line := lines[i]
		if line.visible:
			continue   # busy: try the next one
		# Where: a random spot round the boat, a little above the water.
		var angle := randf() * TAU
		var distance := randf_range(spawn_radius_min, spawn_radius)
		line.position = boat.global_position + Vector3(cos(angle), 0.0, sin(angle)) * distance
		line.position.y = 0.05
		# Which way: its length along the wind, give or take a little.
		line.rotation.y = atan2(-downwind.z, downwind.x) + randf_range(-0.15, 0.15)
		# Its own bend, so no two lines look alike.
		var material: ShaderMaterial = line.mesh.material
		material.set_shader_parameter("seed", randf() * TAU)
		material.set_shader_parameter("wave_height", randf_range(0.15, 0.3))
		material.set_shader_parameter("wave_length", randf_range(8.0, 12.0))
		material.set_shader_parameter("progress", 0.0)
		ages[i] = 0.0
		line.visible = true
		return

class_name ShaderWarmup
extends Node3D
## SHADER WARM-UP: draws every material of the level once, at the very start, so nothing stutters later.
##
## Why (Enrico: frame drops while sailing round): the first time a material is drawn, the graphics card has to
## compile its shader, and on the web (WebGL) that stops the game for a moment: a dropped frame each time a new
## kind of thing comes into view (an island, a fishing spot, the first fireball…). Measured sailing twice round
## the Overworld: 6 such hitches on the first lap, only where something new showed on the second.
## So at the start every material is drawn once, on tiny squares just in front of the camera (a few pixels, for
## FRAMES frames), and then they're gone. In Unreal terms: PSO precaching.
##
## Which materials: everything in the level (also what's hidden or far away: the imp, the NPC's bubble, islands
## out of view), plus the things that are only made later, while playing: the scenes in LATER (a fireball, a
## bomb and its blast, a trap, a pickup, a big wave, an urchin's spike), made here once, hidden, just to read their materials.
## The full-screen effects (fog, outline, cloud shadows) are already drawn from the first frame: skipped.
##
## GameView adds it when the level starts (game_view.gd).

const LATER := [
	preload("res://Assets/Dangers/sea_imp/fireball.tscn"),
	preload("res://Assets/Items/bomb/bomb.tscn"),
	preload("res://Assets/Items/trap/trap.tscn"),
	preload("res://Assets/Items/pickup/pickup.tscn"),
	preload("res://Assets/Dangers/big_waves/big_wave.tscn"),
	preload("res://Assets/Dangers/sea_urchin/spike.tscn"),
	preload("res://Assets/Items/harpoon/harpoon.tscn"),
]
const FRAMES := 3              # frames the squares stay (one is enough to compile; a couple more to be safe)
const SQUARE := 0.01           # metres a side: at 2 m from the camera that's a few pixels

var materials: Array[Material] = []   # every material found, once each
var particles: Array[CPUParticles3D] = []   # particle emitters: drawn differently, warmed up as small copies


## Starts the warm-up in front of `camera` (the boat's). It frees itself when done.
func run(camera: Camera3D) -> void:
	# 1. The things made later: made once here, hidden and switched off (no fuse burning, no hits), only so
	#    their materials can be read (some are made in their _ready, so they must be in the tree).
	var later := Node3D.new()
	later.visible = false
	later.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(later)
	for scene in LATER:
		var thing: Node = scene.instantiate()
		later.add_child(thing)
		if thing.has_method("make_hit_disc"):
			thing.make_hit_disc()            # the fireball's debug ring is made in code
	# 2. Every material in the whole game tree (the level and those things).
	collect(get_tree().root)
	# 3. A tiny square for each, all in one spot just in front of the camera, low and to the right.
	var squares := Node3D.new()
	camera.add_child(squares)
	squares.position = Vector3(0.25, -0.5, -2.0)
	for material in materials:
		var square := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(SQUARE, SQUARE)
		square.mesh = quad
		square.material_override = material
		square.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		squares.add_child(square)
	# 4. Particles are drawn another way (many copies of one mesh): a copy of each emitter, its dots made tiny.
	for emitter in particles:
		var copy := emitter.duplicate() as CPUParticles3D
		copy.scale_amount_min = SQUARE
		copy.scale_amount_max = SQUARE
		copy.local_coords = true
		copy.emitting = true
		squares.add_child(copy)
	# 5. Wait a few frames (they're drawn, the shaders compile), then everything goes.
	for i in FRAMES:
		await get_tree().process_frame
	squares.queue_free()
	queue_free()


## Walks down from `node` and keeps every 3D material it meets (once each).
func collect(node: Node) -> void:
	if node is GeometryInstance3D:
		keep(node.material_override)
		keep(node.material_overlay)
	if node is MeshInstance3D and node.mesh:
		for i in node.mesh.get_surface_count():
			keep(node.get_active_material(i))
	if node is CPUParticles3D:
		particles.append(node)
	for child in node.get_children():
		collect(child)


## Keeps a material if it's new, and if it isn't one of the full-screen effects (they set POSITION themselves,
## so they cover the whole screen whatever the mesh, and they're drawn from the first frame anyway).
func keep(material: Material) -> void:
	if material == null or materials.has(material):
		return
	if material is ShaderMaterial:
		var shader: Shader = material.shader
		if shader == null or shader.code.contains("POSITION ="):
			return
	materials.append(material)

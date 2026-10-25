@tool
extends Node3D
## THE SHORE BAKER: makes the picture the sea reads to draw its waves along the coasts (sea.gdshader's shore
## waves). Press "Bake shore" in the Inspector after moving, adding or removing coasts; it saves the picture at
## `save_path`. Each level (the Overworld, every gym) has its own baker and its own picture: give each a different
## save_path. After baking, the level's Sea is given the new picture by itself (Shore Texture): save the level. (In Unreal: an Editor Utility that bakes a distance field texture.)
##
## What the picture is: the whole map seen from above, one pixel every `metres_per_pixel`; each pixel holds how
## far that point of the sea is from the nearest coast (black = on the coast, white = MAX_DISTANCE metres or more).
## The sea shader reads it and draws lines of foam at the right distances, moving in toward the shore.
##
## How it's made, in three steps:
##   1. A PHOTO of the land from above. Every mesh under the nodes in `land_roots` (Islands, Coast) is copied,
##      painted plain white, into a little world of its own, and an orthographic camera high above looks straight
##      down at it, seeing only what's ABOVE the water (its far plane is the sea's level, y 0): so what it
##      sees is the land as it meets the water. White = land, see-through = sea.
##   2. The DISTANCES: for every sea pixel, how far to the nearest land pixel. Done in two sweeps over the picture
##      (top-left to bottom-right, then back), each pixel taking the smallest of its neighbours' distances plus
##      the step to them (1 straight, 1.41 diagonally): a "chamfer" distance, close enough for waves.
##   3. SAVED as a grey picture (shore_distance.png), which the sea's material uses (sea.tscn: shore_tex).
## It runs in the editor only when you press the button; nothing happens in the game.

## The furthest distance the picture can tell, in metres (white = this far or more). The sea shader must use
## the same number (sea.gdshader: shore_max_distance).
const MAX_DISTANCE := 32.0

## The press-to-bake button in the Inspector (it calls bake()).
@export_tool_button("Bake shore", "Bake") var bake_button := bake
## Where this level's picture is saved. A different file for every level, or one would overwrite the other.
@export_file("*.png") var save_path := "res://Assets/Landscape/shore/shore_distance.png"
## The nodes whose meshes are the land (everything inside them, however deep). If a path doesn't lead anywhere (the
## node was moved into a "folder" node), the node is looked for by its name anywhere in the level.
@export var land_roots: Array[NodePath] = [NodePath("../Islands"), NodePath("../Coast")]
## Metres a pixel of the picture covers (1 = a 1008 x 1008 picture for the 1008 m map; 2 = four times quicker
## to bake, smoother; 0.5 = sharper, four times slower).
@export var metres_per_pixel := 1.0


func bake() -> void:
	var side := int(round(Land.WORLD_SIZE / metres_per_pixel))
	print("Shore baker: taking the photo (%d x %d)…" % [side, side])
	var land := await take_photo(side)
	print("Shore baker: working out the distances…")
	var distances := distance_to_land(land, side)
	var picture := to_picture(distances, side)
	# The Inspector may keep the file as a "uid://…" name (Godot's id for it): turn it back into its res:// path,
	# since a picture can only be saved to a real path.
	var path := save_path
	if path.begins_with("uid://"):
		path = ResourceUID.get_id_path(ResourceUID.text_to_id(path))
	var error := picture.save_png(path)
	if error != OK:
		print("Shore baker: could NOT save ", path, " (error ", error, ")")
		return
	print("Shore baker: saved ", path)
	if Engine.is_editor_hint():
		use_new_picture(path)


## In the editor, after saving: the editor imports the new picture again at once, and this level's Sea is given it
## (Shore Texture), so the waves change straight away. (EditorInterface is asked for by name: it only exists in
## the editor, and writing it plainly would break the exported game.)
func use_new_picture(path: String) -> void:
	var editor = Engine.get_singleton("EditorInterface")
	var files = editor.get_resource_filesystem()
	files.update_file(path)              # it's a new or changed file…
	files.reimport_files([path])         # …import it again now (the texture in memory is refreshed)
	var sea := owner.find_child("Sea", true, false)
	if sea == null:
		return
	sea.shore_texture = load(path)       # the level's Sea uses this picture now (its setter puts it on the material)
	editor.mark_scene_as_unsaved()       # so the level is saved with it (Ctrl+S)
	print("Shore baker: this level's Sea now uses ", path)


# ---- 1. the photo ----

## The land seen from above: a PackedByteArray of side x side, 1 = land, 0 = sea.
func take_photo(side: int) -> PackedByteArray:
	# A picture-in-a-picture (a SubViewport) with a world of its own, so only the land is in it.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(side, side)
	viewport.own_world_3d = true
	viewport.world_3d = World3D.new()
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)

	# Plain white copies of every land mesh, where they stand in the level.
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.cull_mode = BaseMaterial3D.CULL_DISABLED
	white.albedo_color = Color.WHITE
	for path in land_roots:
		var root := get_node_or_null(path)
		if root == null:
			root = owner.find_child(path.get_name(path.get_name_count() - 1), true, false)   # by its name (Islands, Coast)
		if root == null:
			print("Shore baker: no ", path, " found, skipped")
			continue
		for found in root.find_children("*", "MeshInstance3D", true, false):
			var original := found as MeshInstance3D
			var copy := MeshInstance3D.new()
			copy.mesh = original.mesh
			copy.material_override = white
			viewport.add_child(copy)
			copy.global_transform = original.global_transform

	# The camera: high above the middle of the map, looking straight down, seeing the whole map; its far
	# plane is at the sea's level, so nothing under the water shows.
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = Land.WORLD_SIZE
	camera.near = 0.05
	camera.far = 200.0
	viewport.add_child(camera)
	camera.global_position = Vector3(0.0, 200.0, 0.0)
	camera.rotation = Vector3(-PI / 2.0, 0.0, 0.0)       # looking down; the top of the picture is north (-Z)
	camera.current = true

	# Wait for it to be drawn (twice: the frame it's drawn, and the one it's ready to read).
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.queue_free()

	# Land is wherever something was drawn (the alpha, every 4th byte of RGBA, is not see-through).
	image.convert(Image.FORMAT_RGBA8)
	var bytes := image.get_data()
	var land := PackedByteArray()
	land.resize(side * side)
	for i in side * side:
		land[i] = 1 if bytes[i * 4 + 3] > 127 else 0
	return land


# ---- 2. the distances ----

## For every pixel, how many pixels to the nearest land (0 on land), as a PackedFloat32Array.
func distance_to_land(land: PackedByteArray, side: int) -> PackedFloat32Array:
	const DIAGONAL := 1.4142
	var far := MAX_DISTANCE / metres_per_pixel + 1.0      # "very far": more than the picture can tell
	var d := PackedFloat32Array()
	d.resize(side * side)
	for i in side * side:
		d[i] = 0.0 if land[i] == 1 else far
	# Sweep 1: from the top left, looking at the neighbours already done (left, up-left, up, up-right).
	for y in side:
		for x in side:
			var i := y * side + x
			if d[i] == 0.0:
				continue
			var best := d[i]
			if x > 0:
				best = minf(best, d[i - 1] + 1.0)
			if y > 0:
				best = minf(best, d[i - side] + 1.0)
				if x > 0:
					best = minf(best, d[i - side - 1] + DIAGONAL)
				if x < side - 1:
					best = minf(best, d[i - side + 1] + DIAGONAL)
			d[i] = best
	# Sweep 2: from the bottom right, the other neighbours (right, down-right, down, down-left).
	for y in range(side - 1, -1, -1):
		for x in range(side - 1, -1, -1):
			var i := y * side + x
			if d[i] == 0.0:
				continue
			var best := d[i]
			if x < side - 1:
				best = minf(best, d[i + 1] + 1.0)
			if y < side - 1:
				best = minf(best, d[i + side] + 1.0)
				if x < side - 1:
					best = minf(best, d[i + side + 1] + DIAGONAL)
				if x > 0:
					best = minf(best, d[i + side - 1] + DIAGONAL)
			d[i] = best
	return d


# ---- 3. the picture ----

## The distances as a grey picture: black = on the coast, white = MAX_DISTANCE metres or more.
func to_picture(d: PackedFloat32Array, side: int) -> Image:
	var bytes := PackedByteArray()
	bytes.resize(side * side)
	for i in side * side:
		var metres := d[i] * metres_per_pixel
		bytes[i] = int(clampf(metres / MAX_DISTANCE, 0.0, 1.0) * 255.0)
	return Image.create_from_data(side, side, false, Image.FORMAT_L8, bytes)

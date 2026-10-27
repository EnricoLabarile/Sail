@tool
@icon("res://Assets/Quests/map_marker/map_marker_icon.svg")
extends Node3D
## A MAP MARKER: an invisible point you place in the world. Once it's active, the logbook's map shows an X in
## the middle of the square (A1..I9) it stands in: not at its exact spot, the whole square is marked.
## Later an NPC giving a quest will switch it on (activate()); for now you can tick `active` in the Inspector.
##
## To place one: instance map_marker.tscn under MapMarkers in Overworld (like placing a Blueprint) and move it.
## In the editor it shows as a red X in a circle (in the scene tree and in the 3D view, always on top so islands
## don't hide it); in the game there's nothing to see.
## (In Unreal: an invisible Target Point actor with an editor-only billboard, read by the map widget.)
##
## ITS PRINTED MAP (Enrico): an active marker with a `picture` also gets a page of its own in the logbook, showing
## that picture: the area round the marker. The picture is made IN THE EDITOR, not while playing: press
## "Print map" in the Inspector and the area round the marker is printed to a PNG file (`print_path`), which is
## then put in `picture` by itself; save the level. Print again after changing the coasts. (`picture` can also be
## any picture of yours, dragged in by hand.) (In Unreal: an Editor Utility that renders a Scene Capture to a
## texture asset.)
##
## How it's printed, like the shore baker's photo (shore_baker.gd):
##   1. A little world of its own with copies of only the sea and the land (the meshes under `land_roots`), each
##      with its own material: so nothing else gets in (no boat, imps, clouds, fog or editor discs).
##   2. An orthographic camera (no perspective, like a map) straight above the marker, looking down, area_size
##      metres across. North is at the top of the picture. (In orthographic how high it is changes nothing in the
##      picture: CAMERA_HEIGHT only has to be above everything.)
##   3. One picture of picture_size pixels a side, made 1-bit with the game's own dither (the same sums, and the
##      settings read from the level's Dither: brightness, contrast, levels), so it looks like the game in ink.

const ICON := preload("res://Assets/Quests/map_marker/map_marker_icon.svg")
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]   # the 4 x 4 dot pattern (as dither.gdshader)
const PAPER := Color("ebe7dc")
const INK := Color("1b1a17")
const PRINTS_FOLDER := "res://Assets/Quests/map_marker/prints"   # where the printed maps go if print_path is empty
const CAMERA_HEIGHT := 200.0         # metres up the camera prints from: above any island (any height gives the same picture)

## Is it shown on the logbook's map (and its page in the logbook)?
@export var active := false
## The printed map shown on its logbook page (made by "Print map", or any picture of yours). Empty = no page.
@export var picture: Texture2D

@export_group("Print map")
## The press-to-print button (it calls print_map()).
@export_tool_button("Print map", "ImageTexture") var print_button := print_map
## Where the printed map is saved. Empty = PRINTS_FOLDER/<level>_<marker>.png.
@export_file("*.png") var print_path := ""
@export var area_size := 120        # metres across the area printed (the marker is in the middle)
@export var picture_size := 140      # pixels a side of the picture (the book draws it at a whole multiple: 2 x on a phone)
## The nodes whose meshes are the land (as the shore baker's): looked for by name anywhere in the level if the
## path doesn't lead anywhere.
@export var land_roots: Array[NodePath] = [NodePath("../../Islands"), NodePath("../../Coast")]


func _ready() -> void:
	add_to_group("map_markers")   # so the logbook finds every marker when it opens (book.gd)
	if Engine.is_editor_hint():
		_make_editor_icon()


## Switches it on: the X appears on the logbook's map, and its page (the next time the book is opened).
func activate() -> void:
	active = true


## Switches it off: the X and the page go.
func deactivate() -> void:
	active = false


## The square of the logbook's map it stands in: column 0..8 (A..I, from the west) and row 0..8 (1..9, from the
## north). The same sum the logbook uses for the boat's square: its place as a share of the map, times 9.
func square() -> Vector2i:
	var squares := 9
	var col := int(floor((global_position.x / Land.WORLD_SIZE + 0.5) * squares))
	var row := int(floor((global_position.z / Land.WORLD_SIZE + 0.5) * squares))
	return Vector2i(clampi(col, 0, squares - 1), clampi(row, 0, squares - 1))


# ---------- Printing the map (the editor tool) ----------

## Prints the area round the marker to a PNG and puts it in `picture` (see the top of the file). It waits for
## the picture to be drawn, so it's an `await` function: it finishes by itself a frame or two later.
func print_map() -> void:
	var image := await take_photo()
	image = to_one_bit(image)
	var path := where_to_save()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var error := image.save_png(path)
	if error != OK:
		print("Map marker: could NOT save ", path, " (error ", error, ")")
		return
	print("Map marker: printed ", path)
	if Engine.is_editor_hint():
		use_new_picture(path)
	else:
		picture = ImageTexture.create_from_image(image)


## The file to save to: print_path (turned back from a "uid://…" name into its res:// path if needed, as the
## shore baker does), or, if it's empty, PRINTS_FOLDER/<level>_<marker>.png.
func where_to_save() -> String:
	var path := print_path
	if path.begins_with("uid://"):
		path = ResourceUID.get_id_path(ResourceUID.text_to_id(path))
	if path == "":
		var level := "level"
		if owner and owner.scene_file_path != "":
			level = owner.scene_file_path.get_file().get_basename()
		path = PRINTS_FOLDER + "/" + level + "_" + name + ".png"
	return path


## In the editor, after saving: the new picture is imported at once and put in `picture`, and the level is marked
## as changed so it's saved with it. (EditorInterface is asked for by name: it exists only in the editor.)
func use_new_picture(path: String) -> void:
	var editor = Engine.get_singleton("EditorInterface")
	var files = editor.get_resource_filesystem()
	files.update_file(path)
	files.reimport_files([path])
	picture = load(path)
	editor.mark_scene_as_unsaved()
	print("Map marker: ", name, " now shows ", path, " (save the level)")


## The photo: copies of the sea and the land in a world of their own, seen from straight above by an orthographic camera.
func take_photo() -> Image:
	var view := SubViewport.new()
	view.size = Vector2i(picture_size, picture_size)
	view.own_world_3d = true
	view.world_3d = World3D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(view)
	# The sea: a copy of the level's Sea (with the material it wears, shore waves and all).
	var level := owner if owner else get_tree().current_scene
	var sea := level.find_child("Sea", true, false) as MeshInstance3D
	if sea:
		_copy_mesh(sea, view)
	else:
		print("Map marker: no Sea found in the level, printed without it")
	# The land: a copy of every mesh under the land roots.
	for path in land_roots:
		var root := get_node_or_null(path)
		if root == null:
			root = level.find_child(path.get_name(path.get_name_count() - 1), true, false)
		if root == null:
			print("Map marker: no ", path, " found, skipped")
			continue
		for found in root.find_children("*", "MeshInstance3D", true, false):
			_copy_mesh(found, view)
	# The camera: straight above the marker, looking down (turned -90 degrees round x), north (-Z) at the top.
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = area_size
	camera.far = CAMERA_HEIGHT + 50.0                # down to a little below the sea
	view.add_child(camera)
	camera.global_position = Vector3(global_position.x, CAMERA_HEIGHT, global_position.z)
	camera.global_rotation = Vector3(-PI / 2.0, 0.0, 0.0)
	camera.current = true
	# Wait for it to be drawn (twice: the frame it's drawn, and the one it's ready to read), keep it, tidy up.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	view.queue_free()
	return image


## A copy of a mesh where it stands, with the materials it's drawn with (its override, or each surface's).
func _copy_mesh(original: MeshInstance3D, into: Node) -> void:
	if original.mesh == null:
		return
	var copy := MeshInstance3D.new()
	copy.mesh = original.mesh
	copy.material_override = original.material_override
	for i in original.mesh.get_surface_count():
		copy.set_surface_override_material(i, original.get_active_material(i))
	into.add_child(copy)
	copy.global_transform = original.global_transform


## The game's dither settings (the Dither's material: brightness, contrast, levels), so the picture gets the
## same look. If the level has no Dither, the plain values.
func dither_settings() -> Dictionary:
	var settings := {"brightness": 0.0, "contrast": 1.0, "black_point": 0.0, "white_point": 1.0, "gamma": 1.0}
	var level := owner if owner else get_tree().current_scene
	var dither := level.find_child("Dither", true, false)
	if dither:
		for rect in dither.find_children("*", "ColorRect", true, false):
			var material := rect.material as ShaderMaterial
			if material:
				for key in settings:
					var value = material.get_shader_parameter(key)
					if value != null:
						settings[key] = value
	return settings


## The picture in two colours, with the same sums as the game's dither (dither.gdshader): each pixel's grey,
## then brightness and contrast, then the levels, then compared with the 4 x 4 pattern's number for its place
## (it repeats every 4 x 4 pixels): brighter = paper, darker = ink.
func to_one_bit(image: Image) -> Image:
	var d := dither_settings()
	image.convert(Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			var grey := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			grey = clampf((grey - 0.5) * d.contrast + 0.5 + d.brightness, 0.0, 1.0)
			grey = clampf((grey - d.black_point) / maxf(d.white_point - d.black_point, 0.001), 0.0, 1.0)
			grey = pow(grey, 1.0 / d.gamma)
			var threshold: float = (BAYER[(y % 4) * 4 + (x % 4)] + 0.5) / 16.0
			image.set_pixel(x, y, PAPER if grey > threshold else INK)
	return image


# ---------- In the editor only: the icon in the 3D view ----------

## A picture that always faces the camera, the same size whatever the zoom, drawn over everything. It's made in
## code with no owner, so it isn't saved in the scene and never appears in the game.
func _make_editor_icon() -> void:
	var sprite := Sprite3D.new()
	sprite.texture = ICON
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.fixed_size = true          # same size on screen however far the camera is
	sprite.pixel_size = 0.0015
	sprite.no_depth_test = true       # drawn over the islands, so you can always find it
	sprite.render_priority = 12       # and after the sea, so the water never covers it from afar
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	add_child(sprite)

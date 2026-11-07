@tool
extends Node3D
## THE 2D BOAT (Enrico, Nov 2026): the 3D boat photographed once, from the game's angle, at `directions` headings
## (a SHEET of pictures), and in the game a flat picture on the water showing the right one, instead of the 3D model.
## (In Unreal: like baking an impostor / a flipbook of a mesh, then drawing that instead of the mesh.)
## It lives on the node `BoatSprite` inside boat.tscn. Two parts:
##
## 1. THE BAKE (editor only): open boat.tscn, select BoatSprite and press "Bake boat sheet" in the Inspector (~1 s).
##    In a little world of its own it puts copies of the boat's meshes (those under Model, except the parts named in
##    `left_out`: the paddle wheels), cut at the water line (the sea hides the rest in the game: toon_shade.gdshader's
##    cut_below_water; the inside of the hull, "inner", isn't cut, as in the game), and an orthographic camera tilted
##    `bake_tilt_deg` from straight down (Enrico: not a perfect top-down; 30 = the game camera's), looking north. It
##    turns the copies round `directions` times (frame i = the boat's rotation.y of i/directions of a turn) and pastes
##    each picture into the sheet, left to right, row by row; it saves the PNG (`sheet_path`), imports it and puts it in
##    `sheet`. Save boat.tscn after. BAKE AGAIN after changing the boat's meshes, colours or the tilt.
##
## 2. IN THE GAME (`use_sprite` on): the 3D meshes under Model are hidden (the boat still works the same: only the
##    look changes) and a flat square lies over the water at her (interpolated) place, `height_above_water` over the
##    level's sea (its Sea node's height: the Overworld's is 0.087, not 0) and moved south to make up for it, with the
##    sheet's picture for her heading (the nearest of the `directions`). Its size: the frame's pixels / `pixels_per_metre`
##    across, and stretched north-south by 1 / cos(the game camera's tilt), so that, lying on the water, the camera sees
##    it exactly as it was photographed. It's solid where the picture is (alpha scissor): it writes depth, so the ink
##    outline goes round it as round the 3D boat. It goes down and comes up with Model (sinking, coming up, bobbing),
##    under the sea when she's under; she blinks black when overheated (set_black, from boat.gd).
##    What the 2D boat doesn't do (yet): the lean in turns and the rocking (only the bobbing up and down), the paddles.

@export_group("Bake")
## The press-to-bake button (it calls bake()).
@export_tool_button("Bake boat sheet", "Bake") var bake_button := bake
## Where the sheet is saved.
@export_file("*.png") var sheet_path := "res://Assets/Boat/boat_sprite/boat_sheet.png"
@export var directions := 16            # headings in the sheet (16 = one every 22.5°)
@export var frame_size := 96            # pixels a side of each picture
@export var pixels_per_metre := 12.0    # how big the boat is in the picture (12 ≈ the phone's game view at camera distance 90)
@export_range(0.0, 89.0) var bake_tilt_deg := 30.0   # the bake camera's tilt from straight down (0 = top-down)
## Parts of the boat left out of the bake (and hidden in the game like the rest): node names under Model.
@export var left_out: Array[String] = ["Paddles"]

@export_group("In game")
@export var use_sprite := true          # off = the 3D boat as before
@export var sheet: Texture2D            # the baked sheet (set by the bake)
## Metres over the level's sea (its Sea node's height). Lifted well clear of it: a few centimetres weren't enough,
## at the camera's distance the sea and the picture fought over the same pixels (depth precision). The lift doesn't
## show: the picture is moved south by the same amount × tan(the camera's tilt), so it's seen where it would be on the water.
@export var height_above_water := 1.0

var boat: Node3D                        # the boat (this node's parent)
var model: Node3D                       # her Model (it bobs, sinks and comes up: the picture follows its height)
var quad: MeshInstance3D                # the flat square on the water showing the picture
var material: StandardMaterial3D        # its material (the sheet, the frame shown, the black blink)
var columns := 1                        # the sheet's grid
var rows := 1
var sea_level := 0.0                    # the height of the level's sea (its Sea node: not always exactly 0)
var south_shift := 0.0                  # metres the lifted picture is moved south, so the camera sees it on the water


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	set_process(false)
	if not use_sprite or sheet == null:
		return                           # the 3D boat stays
	boat = get_parent() as Node3D
	model = boat.get_node_or_null("Model") as Node3D
	setup.call_deferred()                # after the boat's own _ready (her camera is known then)


# ---------- In the game ----------

## Hides the 3D boat and makes the flat picture on the water.
func setup() -> void:
	hide_3d_boat()
	var sea := get_tree().current_scene.find_child("Sea", true, false) as Node3D if get_tree().current_scene else null
	if sea:
		sea_level = sea.global_position.y
	columns = sheet_columns()
	rows = sheet_rows()
	var frame := Vector2(sheet.get_width() / float(columns), sheet.get_height() / float(rows))
	# How much the camera squeezes north-south lengths on the water: cos of its tilt from straight down. The picture
	# was taken at that squeeze already, so lying on the water it's stretched back by 1 / cos.
	var tilt := deg_to_rad(boat.get_node("Camera3D").tilt_deg)
	south_shift = height_above_water * tan(tilt)
	var plane := PlaneMesh.new()        # a flat square facing up; its top edge (the picture's top) is north (-Z)
	plane.size = Vector2(frame.x / pixels_per_metre, frame.y / pixels_per_metre / cos(tilt))
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR   # solid or nothing: it writes depth (the outline)
	material.alpha_scissor_threshold = 0.5
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.albedo_texture = sheet
	material.uv1_scale = Vector3(1.0 / columns, 1.0 / rows, 1.0)        # one frame of the grid…
	plane.material = material
	quad = MeshInstance3D.new()
	quad.mesh = plane
	quad.top_level = true                # placed in the world by hand: it doesn't turn with her (the frames do)
	quad.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(quad)
	set_process(true)


## Hides every mesh of the 3D boat under Model (not the steam's puffs, which are placed in the world on their own).
func hide_3d_boat() -> void:
	if model == null:
		return
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		if not mesh.top_level:
			mesh.visible = false


## Every frame: the picture at her drawn place, at Model's height (bobbing, sinking, coming up), showing her heading.
func _process(_dt: float) -> void:
	var drawn := boat.get_global_transform_interpolated()
	var drop := 0.0
	if model:
		drop = model.position.y - boat.model_height      # how far Model is from where it rests (under water: hidden)
	quad.global_position = Vector3(drawn.origin.x, sea_level + height_above_water + drop, drawn.origin.z + south_shift)
	quad.global_rotation = Vector3.ZERO
	show_frame(frame_for(drawn.basis))


## Which frame of the sheet matches her heading: her turn round y (as rotation.y: basis.z = (sin, 0, cos)), as a
## share of a whole turn, rounded to the nearest of the `directions`.
func frame_for(basis: Basis) -> int:
	var turn := atan2(basis.z.x, basis.z.z)
	var share := wrapf(turn, 0.0, TAU) / TAU
	return int(round(share * directions)) % directions


## Shows frame i: the material's picture shifted to that cell of the grid (left to right, row by row).
func show_frame(i: int) -> void:
	var cell := Vector3(float(i % columns) / columns, float(i / columns) / rows, 0.0)
	if material.uv1_offset != cell:
		material.uv1_offset = cell


## Overheated (boat.gd blink_black → set_black): the picture all black (on) or as drawn (off).
func set_black(on: bool) -> void:
	if material:
		material.albedo_color = Color.BLACK if on else Color.WHITE


func sheet_columns() -> int:
	return int(ceil(sqrt(float(directions))))


func sheet_rows() -> int:
	return int(ceil(float(directions) / sheet_columns()))


# ---------- The bake (editor only) ----------

## The Inspector's button: photographs the boat at every heading into one sheet (make_sheet), saves it and puts it
## in `sheet` (see the notes at the top).
func bake() -> void:
	if not Engine.is_editor_hint():
		return
	var sheet_image := await make_sheet()
	if sheet_image:
		save_sheet(sheet_image)


## The sheet as a picture (null if there's no Model). Takes directions × 2 frames to draw.
func make_sheet() -> Image:
	boat = get_parent() as Node3D
	model = boat.get_node_or_null("Model") as Node3D
	if model == null:
		push_warning("Boat sprite: no Model next to me, nothing to bake")
		return null
	# A picture-in-a-picture (a SubViewport) with a world of its own: only the boat's copies are in it.
	var view := SubViewport.new()
	view.size = Vector2i(frame_size, frame_size)
	view.own_world_3d = true
	view.world_3d = World3D.new()
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(view)
	var pivot := Node3D.new()            # the copies are inside it: turning it turns the whole boat
	view.add_child(pivot)
	copy_meshes(pivot)
	# The camera: orthographic (no perspective, like a drawing), frame_size / pixels_per_metre metres across, tilted
	# bake_tilt_deg from straight down and looking north at her middle, from far enough away.
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = frame_size / pixels_per_metre
	camera.near = 0.1
	camera.far = 200.0
	view.add_child(camera)
	camera.rotation = Vector3(-(PI / 2.0 - deg_to_rad(bake_tilt_deg)), 0.0, 0.0)
	camera.position = camera.basis.z * 50.0      # 50 m back along the way it looks
	camera.current = true
	# One photo per heading, pasted into the sheet.
	var columns_now := sheet_columns()
	var sheet_image := Image.create(columns_now * frame_size, sheet_rows() * frame_size, false, Image.FORMAT_RGBA8)
	for i in directions:
		pivot.rotation.y = TAU * i / directions
		view.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw     # drawn…
		await RenderingServer.frame_post_draw     # …and ready to read
		var photo := view.get_texture().get_image()
		photo.convert(Image.FORMAT_RGBA8)
		var corner := Vector2i((i % columns_now) * frame_size, (i / columns_now) * frame_size)
		sheet_image.blit_rect(photo, Rect2i(Vector2i.ZERO, Vector2i(frame_size, frame_size)), corner)
	view.queue_free()
	return sheet_image


## A copy of every mesh of the boat under Model, where it is on the boat (Model at rest), in the bake's world, except
## the parts in `left_out`. The boat's own toon_shade materials are copied and told to cut below the water line,
## except on her inside ("inner" in its name or its parent's: in the game the sea never covers it).
func copy_meshes(pivot: Node3D) -> void:
	# Model at rest: at the height it's placed in boat.tscn, upright (in the game it bobs, rocks, sinks and comes up;
	# in the editor it's always at rest; boat.gd keeps that height in model_height once the game runs).
	var rest_height: float = model.position.y if Engine.is_editor_hint() else boat.model_height
	var model_at_rest := Transform3D(Basis(), Vector3(model.position.x, rest_height, model.position.z))
	var to_model := model.global_transform.affine_inverse()
	for found in model.find_children("*", "MeshInstance3D", true, false):
		var original := found as MeshInstance3D
		if original.top_level or is_left_out(original):
			continue
		var copy := MeshInstance3D.new()
		copy.mesh = original.mesh
		pivot.add_child(copy)
		copy.transform = model_at_rest * (to_model * original.global_transform)   # where it is on the boat, at rest
		var names := (String(original.name) + " " + String(original.get_parent().name)).to_lower()
		var cut := not names.contains("inner")
		for surface in original.mesh.get_surface_count():
			var surface_material := original.get_active_material(surface)
			if surface_material is ShaderMaterial:
				surface_material = surface_material.duplicate()
				surface_material.set_shader_parameter("cut_below_water", cut)
			copy.set_surface_override_material(surface, surface_material)


## Is this mesh inside one of the parts left out (a node named in `left_out`, between it and Model)?
func is_left_out(mesh: Node) -> bool:
	var node := mesh
	while node != null and node != model:
		if left_out.has(String(node.name)):
			return true
		node = node.get_parent()
	return false


## Saves the sheet as a PNG, imports it again and puts it in `sheet` (save boat.tscn after: Ctrl+S).
func save_sheet(sheet_image: Image) -> void:
	var path := sheet_path
	if path.begins_with("uid://"):
		path = ResourceUID.get_id_path(ResourceUID.text_to_id(path))   # the Inspector may store the file as a uid
	sheet_image.save_png(path)
	var editor = Engine.get_singleton("EditorInterface")   # asked for by name: it only exists in the editor
	var files = editor.get_resource_filesystem()
	files.update_file(path)
	files.reimport_files([path])
	sheet = load(path)
	editor.mark_scene_as_unsaved()
	print("Boat sprite: %d headings baked into %s" % [directions, path])

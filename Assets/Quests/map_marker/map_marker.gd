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
## THE CLOSE-UP (Enrico): an active marker also gets its own page in the logbook, a picture of the area round it.
## take_picture() puts a camera high above it, looking down from the south with the game camera's tilt (so the
## islands, drawings standing up toward that camera, show as they do in the game; straight down they'd be seen
## edge on) but orthographic (no perspective, like a map), area_size metres across, renders ONE picture
## (picture_size pixels a side) into a SubViewport, keeps a copy and throws the camera away (in Unreal: a Scene
## Capture 2D that captures once). The copy is made 1-bit with the game's own dither: the same sums and the same
## settings (brightness, contrast, levels, read from the level's Dither), so it looks like the game, drawn in ink. It's taken when the
## level starts (if `active`) and when activate() is called. The camera sees only render layer 1 (the sea, the
## land, the boat if she's there): not the clouds and gulls (layer 2), not the fog and the other screen effects
## (layer 3), so the area shows even if she has never been there.

const ICON := preload("res://Assets/Quests/map_marker/map_marker_icon.svg")

## Is it shown on the logbook's map?
@export var active := false
@export var area_size := 60.0        # metres a side of the area its page shows (it's in the middle)
@export var picture_size := 140      # pixels a side of the picture (the book draws it at a whole multiple: 2 x on a phone)
@export var picture_height := 100.0  # metres above the sea the camera takes the picture from
@export var start_delay := 0.3       # seconds after the level starts before an active marker takes its picture

const SEES_LAYERS := 1               # render layer 1 only: the sea, the land, the boat (see above)
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]   # the 4 x 4 dot pattern (as dither.gdshader)
const PAPER := Color("ebe7dc")
const INK := Color("1b1a17")

var picture: ImageTexture = null     # the close-up for the logbook (null until it's taken)


func _ready() -> void:
	add_to_group("map_markers")   # so the logbook finds every marker when it opens (book.gd)
	if Engine.is_editor_hint():
		_make_editor_icon()
		return
	if active:
		_take_picture_soon()


## At the level's start the picture waits start_delay seconds: in the first frames the level is still being set
## up (GameView moves the sea and the islands into its view), and a picture taken then came out wrong (the same
## grey for every marker). The black curtain is still down meanwhile (start_screen.gd), so nobody sees it.
func _take_picture_soon() -> void:
	await get_tree().create_timer(start_delay).timeout
	if picture == null:
		take_picture()


## Switches it on: the X appears on the logbook's map (the next time the book is opened).
func activate() -> void:
	active = true
	if picture == null:
		take_picture()


## Switches it off: the X goes.
func deactivate() -> void:
	active = false


## The square of the logbook's map it stands in: column 0..8 (A..I, from the west) and row 0..8 (1..9, from the
## north). The same sum the logbook uses for the boat's square: its place as a share of the map, times 9.
func square() -> Vector2i:
	var squares := 9
	var col := int(floor((global_position.x / Land.WORLD_SIZE + 0.5) * squares))
	var row := int(floor((global_position.z / Land.WORLD_SIZE + 0.5) * squares))
	return Vector2i(clampi(col, 0, squares - 1), clampi(row, 0, squares - 1))


# ---------- The close-up for the logbook ----------

## Takes the picture of the area round it (see the top of the file). It waits for the frame to be drawn, so
## it's an `await` function: it carries on by itself a frame or two later.
func take_picture() -> void:
	# 1. A small picture to draw into, and a camera in it. The SubViewport shares the game's 3D world, so the
	#    camera sees the real sea and islands.
	var view := SubViewport.new()
	view.size = Vector2i(picture_size, picture_size)
	view.render_target_update_mode = SubViewport.UPDATE_ONCE   # one picture, then it stops
	add_child(view)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = area_size                                     # metres it sees, side to side
	camera.far = picture_height + 50.0
	camera.cull_mask = SEES_LAYERS
	view.add_child(camera)
	# Up and back to the south along the game camera's tilt, looking at the marker, north at the top of the
	# picture (as the logbook's map). The same sums as boat_camera.gd.
	var tilt := deg_to_rad(game_camera_tilt())
	camera.global_position = global_position + Vector3(0.0, cos(tilt), sin(tilt)) * picture_height
	camera.global_rotation = Vector3(-(PI / 2.0 - tilt), 0.0, 0.0)
	camera.current = true
	# 2. Wait until it has been drawn (twice, to be safe), then keep a copy of the picture.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	view.queue_free()                                           # the camera's job is done
	# 3. Paper and ink: each pixel's grey against the 4 x 4 pattern (darker than its threshold: ink).
	picture = ImageTexture.create_from_image(to_one_bit(image))


## The game camera's tilt from straight down, in degrees (boat_camera.gd's tilt_deg; 20 if there's no boat).
func game_camera_tilt() -> float:
	var boat := get_tree().get_first_node_in_group("player_boat")
	if boat and boat.camera:
		return boat.camera.tilt_deg
	return 20.0


## The game's dither settings (the Dither's material: brightness, contrast, levels), so the picture gets the
## same look. If the level has no Dither, the plain values.
func dither_settings() -> Dictionary:
	var settings := {"brightness": 0.0, "contrast": 1.0, "black_point": 0.0, "white_point": 1.0, "gamma": 1.0}
	var dither := get_tree().current_scene.find_child("Dither", true, false)
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

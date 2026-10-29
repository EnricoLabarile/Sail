@tool
extends Node3D
## THE SEA ZONE BAKER: turns all the level's sea zones (SeaZone nodes, sea_zone.tscn: boiling water and strong
## currents) into ONE picture of the whole map, which the sea's shader (to draw them) and the boat (Land.boil_at,
## Land.current_at: to feel them) read. Press "Bake sea zones" in the Inspector after adding, moving or changing
## a zone. Like the ShoreBaker: one per level, each with its own save_path. After baking, the level's Sea is given
## the new picture by itself (Zones Texture): save the level.
## (In Unreal: an Editor Utility that bakes a mask texture from splines.)
##
## What the picture holds, one pixel a metre (`metres_per_pixel`), north at the top:
##   RED   = how much the sea boils there (0 = not at all, 1 = fully: inside a boiling zone, past its soft edge);
##   GREEN = the strong current's push toward the east (+x), BLUE = toward the south (+z), both in m/s, stored as
##           128 + push / SeaZone.MAX_PUSH * 127 (so 128 = no push, above = east / south, below = west / north).
## Where several zones overlap, the boiling takes the strongest and the currents add up.
## Nothing of it runs in the game.

const LandScript := preload("res://Assets/Landscape/world/land.gd")   # for WORLD_SIZE
const WindScript := preload("res://Assets/Landscape/world/wind.gd")   # for CURRENT_SPEED

## The press-to-bake button in the Inspector (it calls bake()).
@export_tool_button("Bake sea zones", "Bake") var bake_button := bake
## Where this level's picture is saved. A different file for every level, or one would overwrite the other.
@export_file("*.png") var save_path := "res://Assets/Landscape/sea_zones/SeaZones_Overworld.png"
## Metres a pixel covers (1 = a 1008 x 1008 picture for the 1008 m map).
@export var metres_per_pixel := 1.0


func bake() -> void:
	var side := int(round(LandScript.WORLD_SIZE / metres_per_pixel))
	# Three numbers a pixel (red, green, blue), all starting at "nothing": no boiling, no push.
	var boil := PackedFloat32Array()
	var push_x := PackedFloat32Array()
	var push_z := PackedFloat32Array()
	boil.resize(side * side)
	push_x.resize(side * side)
	push_z.resize(side * side)
	var zones: Array = []
	if owner:
		zones = owner.find_children("*", "Node3D", true, false)   # every node of the level; the zones are picked below
	var count := 0
	for node in zones:
		if node is SeaZone:
			paint_zone(node, side, boil, push_x, push_z)
			count += 1
	print("Sea zone baker: %d zones painted" % count)
	var picture := to_picture(side, boil, push_x, push_z)
	var path := save_path
	if path.begins_with("uid://"):
		path = ResourceUID.get_id_path(ResourceUID.text_to_id(path))   # a real path to save to (see ShoreBaker)
	var error := picture.save_png(path)
	if error != OK:
		print("Sea zone baker: could NOT save ", path, " (error ", error, ")")
		return
	write_import_settings(path)
	print("Sea zone baker: saved ", path)
	if Engine.is_editor_hint():
		use_new_picture(path)


## Paints one zone into the three arrays: every pixel whose middle is inside its outline, faded in over
## edge_softness metres from the edge.
func paint_zone(zone: SeaZone, side: int, boil: PackedFloat32Array, push_x: PackedFloat32Array,
		push_z: PackedFloat32Array) -> void:
	var outline := zone.polygon()
	if outline.size() < 3:
		print("Sea zone baker: ", zone.name, " has fewer than 3 points, skipped")
		return
	var half := LandScript.WORLD_SIZE / 2.0
	# Only the pixels in the box round the outline need looking at (in Unreal: the bounds).
	var box := Rect2(outline[0], Vector2.ZERO)
	for point in outline:
		box = box.expand(point)
	var x_from := maxi(0, int((box.position.x + half) / metres_per_pixel))
	var x_to := mini(side - 1, int((box.end.x + half) / metres_per_pixel))
	var y_from := maxi(0, int((box.position.y + half) / metres_per_pixel))
	var y_to := mini(side - 1, int((box.end.y + half) / metres_per_pixel))
	# The current's push at full strength (m/s), the way the zone points.
	var flow := zone.flow_direction() * WindScript.CURRENT_SPEED * zone.strength
	for y in range(y_from, y_to + 1):
		for x in range(x_from, x_to + 1):
			# The middle of this pixel, in world metres.
			var point := Vector2((x + 0.5) * metres_per_pixel - half, (y + 0.5) * metres_per_pixel - half)
			if not Geometry2D.is_point_in_polygon(point, outline):
				continue
			var share := 1.0                                   # how much of the zone is here (1 = fully)
			if zone.edge_softness > 0.0:
				share = clampf(distance_to_edge(point, outline) / zone.edge_softness, 0.0, 1.0)
			var i := y * side + x
			if zone.kind == SeaZone.Kind.BOILING:
				boil[i] = maxf(boil[i], share)
			else:
				push_x[i] += flow.x * share
				push_z[i] += flow.z * share


## Metres from a point to the nearest side of the outline.
func distance_to_edge(point: Vector2, outline: PackedVector2Array) -> float:
	var nearest := INF
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var closest := Geometry2D.get_closest_point_to_segment(point, a, b)
		nearest = minf(nearest, point.distance_to(closest))
	return nearest


## The three arrays as an RGB picture (see the notes at the top for what each colour means).
func to_picture(side: int, boil: PackedFloat32Array, push_x: PackedFloat32Array,
		push_z: PackedFloat32Array) -> Image:
	var bytes := PackedByteArray()
	bytes.resize(side * side * 3)
	for i in side * side:
		bytes[i * 3] = int(round(boil[i] * 255.0))
		bytes[i * 3 + 1] = push_to_byte(push_x[i])
		bytes[i * 3 + 2] = push_to_byte(push_z[i])
	return Image.create_from_data(side, side, false, Image.FORMAT_RGB8, bytes)


## A push (m/s, east or south positive) as a byte: 128 = none, 255 = +MAX_PUSH, 1 = -MAX_PUSH.
func push_to_byte(push: float) -> int:
	return clampi(128 + int(round(push / SeaZone.MAX_PUSH * 127.0)), 1, 255)


## How the picture must be imported: as it is, not compressed (compression would change the numbers in it) and
## without mipmaps. Written next to it the first time, so Godot imports it right (Enrico's shore masks are
## imported the same way).
func write_import_settings(path: String) -> void:
	var import_path := path + ".import"
	if FileAccess.file_exists(import_path):
		return                          # already there: Godot keeps it (and its id)
	var file := FileAccess.open(import_path, FileAccess.WRITE)
	file.store_string("[remap]\n\nimporter=\"texture\"\ntype=\"CompressedTexture2D\"\n\n[params]\n\n" +
		"compress/mode=0\nmipmaps/generate=false\ndetect_3d/compress_to=0\n")
	file.close()


## In the editor, after saving: import the picture again now and give it to this level's Sea (as ShoreBaker does).
func use_new_picture(path: String) -> void:
	var editor = Engine.get_singleton("EditorInterface")
	var files = editor.get_resource_filesystem()
	files.update_file(path)
	files.reimport_files([path])
	var sea := owner.find_child("Sea", true, false)
	if sea == null:
		return
	sea.zones_texture = load(path)
	editor.mark_scene_as_unsaved()
	print("Sea zone baker: this level's Sea now uses ", path)

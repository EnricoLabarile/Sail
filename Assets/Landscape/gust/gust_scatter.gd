@tool
extends Node3D
## THE GUST SCATTER: fills the sea with wind gusts (gust.tscn) by itself, instead of placing them one by one.
## (In Unreal: a little procedural spawner, like a PCG graph or a Construction Script that adds instances.)
##
## How it places them:
##   1. A grid over the whole map with `spacing` metres between gusts, but OFFSET: every other row is pushed half a
##      step sideways (and the rows are a little closer, × 0.87), so the gusts sit on diagonals, like the cells of a
##      honeycomb, never in straight rows and columns. Every gust has its 6 neighbours `spacing` metres away.
##   2. Each point is checked against this level's shore picture (the one its Sea uses, made by the ShoreBaker:
##      how many metres to the nearest coast, up to 32): a point closer than `min_coast_distance` to a coast is
##      dropped, and land counts as 0, so no gust ever lands on an island. At 32 (the picture's farthest), only the
##      open sea the picture marks as "far from any coast" gets gusts.
##   3. A gust is made at each point left.
## They're made when the level starts, and in the editor too, so you see them while you work; they're never saved in
## the level (no owner), so changing a number here just makes them again. Their own numbers (radius, boost…) are
## gust.tscn's: change them there for all of them.
## Re-bake the shore (ShoreBaker) after changing the coasts, and the gusts follow.

const GUST_SCENE := preload("res://Assets/Landscape/gust/gust.tscn")
const ShoreBaker := preload("res://Assets/Landscape/shore/shore_baker.gd")   # for MAX_DISTANCE (32 m)
const LandScript := preload("res://Assets/Landscape/world/land.gd")          # for WORLD_SIZE (works in the editor too)

## Metres between a gust and its neighbours (smaller = more gusts). 60 m on the 1008 m map is about 300 places
## before the land is taken out.
@export var spacing := 60.0:
	set(value):
		spacing = maxf(value, 5.0)      # never so small it makes thousands
		_rebuild_later()
## How far from any coast a gust must be, in metres (0 = right up to the shore, 32 = the shore picture's farthest).
@export_range(0.0, 32.0, 1.0) var min_coast_distance := 32.0:
	set(value):
		min_coast_distance = value
		_rebuild_later()
## Metres kept clear along the map's edge.
@export var edge_margin := 10.0:
	set(value):
		edge_margin = value
		_rebuild_later()

var _rebuild_queued := false   # a rebuild already asked for this frame (several changes make one rebuild)


func _ready() -> void:
	_rebuild_later()


## Several numbers can change at once (loading the scene sets them all): rebuild once, at the end of the frame.
func _rebuild_later() -> void:
	if _rebuild_queued or not is_inside_tree():
		return
	_rebuild_queued = true
	rebuild.call_deferred()


## Takes away the gusts made before and makes them again from the numbers above.
func rebuild() -> void:
	_rebuild_queued = false
	for child in get_children():
		child.queue_free()
	var distances := _shore_picture()
	if distances == null:
		push_warning("GustScatter: no shore picture found (the level's Sea, shore_texture): no gusts made.")
		return
	var made := 0
	for point in grid_points():
		var metres := distance_to_shore(distances, point)
		# On water (more than 0) and far enough from every coast (a hair of slack: the picture's white is 32 exactly).
		if metres > 0.0 and metres >= min_coast_distance - 0.01:
			var gust := GUST_SCENE.instantiate()
			add_child(gust)                    # no owner: never saved into the level
			gust.global_position = point
			made += 1
	print("GustScatter: %d gusts" % made)


## The points of the offset grid over the whole map (minus the edge margin), on the water's level.
func grid_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	var half := LandScript.WORLD_SIZE / 2.0 - edge_margin
	var row_step := spacing * 0.866              # sqrt(3)/2: rows that close make every neighbour `spacing` away
	var row := 0
	var z := -half
	while z <= half:
		# Every other row starts half a step further along: that's what puts them on diagonals.
		var x := -half + (spacing * 0.5 if row % 2 == 1 else 0.0)
		while x <= half:
			points.append(Vector3(x, 0.0, z))
			x += spacing
		z += row_step
		row += 1
	return points


## This level's picture of the distances to the coast, from its Sea (the same one Land reads in the game).
func _shore_picture() -> Image:
	var root: Node = owner if owner else get_tree().current_scene
	if Engine.is_editor_hint() and get_tree().edited_scene_root:
		root = get_tree().edited_scene_root
	if root == null:
		return null
	var sea := root.find_child("Sea", true, false)
	if sea == null or sea.get("shore_texture") == null:
		return null
	return sea.shore_texture.get_image()


## Metres from `point` to the nearest coast, read from the picture as Land does (0 = on land or on the coast,
## ShoreBaker.MAX_DISTANCE = that far or more).
func distance_to_shore(picture: Image, point: Vector3) -> float:
	var across := (point.x + LandScript.WORLD_SIZE / 2.0) / LandScript.WORLD_SIZE
	var down := (point.z + LandScript.WORLD_SIZE / 2.0) / LandScript.WORLD_SIZE
	var x := clampi(int(across * picture.get_width()), 0, picture.get_width() - 1)
	var y := clampi(int(down * picture.get_height()), 0, picture.get_height() - 1)
	return picture.get_pixel(x, y).r * ShoreBaker.MAX_DISTANCE

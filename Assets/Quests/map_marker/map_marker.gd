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

const ICON := preload("res://Assets/Quests/map_marker/map_marker_icon.svg")

## Is it shown on the logbook's map?
@export var active := false


func _ready() -> void:
	add_to_group("map_markers")   # so the logbook finds every marker when it opens (book.gd)
	if Engine.is_editor_hint():
		_make_editor_icon()


## Switches it on: the X appears on the logbook's map (the next time the book is opened).
func activate() -> void:
	active = true


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
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	add_child(sprite)

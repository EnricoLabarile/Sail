@tool
extends Node3D
## AN ISLAND (Enrico: a 2D drawing, not a 3D model). Its picture is drawn slightly from the side (3/4 view), and
## stands on the sea on a card that faces the camera, its bottom edge on the water at this node's place: so the
## picture shows on the screen just as it was drawn, a texture pixel to a screen pixel (at pixels_per_metre 9),
## and the boat sailing behind the island is hidden by it (in Unreal: a camera-facing sprite actor).
## Its collision is only the island's footprint on the water (the `Footprint` polygon, which Enrico shapes in the
## editor), smaller than the drawing: the hills and peaks the boat can pass behind aren't solid.
##
## @tool: it runs in the editor too, so the card takes the picture's size and the camera's tilt there as well.

## The island's drawing (3/4 view, the front shore along the bottom edge, see-through round it).
@export var picture: Texture2D:
	set(value):
		picture = value
		fit()

## How many of the picture's pixels make a metre. The game shows 9 game pixels a metre (40 m across 360), so at
## 9 a pixel of the drawing is a pixel on the screen.
@export var pixels_per_metre := 9.0:
	set(value):
		pixels_per_metre = value
		fit()

## The camera's tilt (as boat.gd's camera_tilt_deg): the card leans back by as much, so it faces the camera.
@export var camera_tilt_deg := 45.0:
	set(value):
		camera_tilt_deg = value
		fit()


func _ready() -> void:
	fit()


## Sizes the card to the picture and leans it to face the camera, its bottom edge at this node's place.
## A note for drawing the footprint: a point the picture shows h metres up from its bottom edge is, on the
## water, h / cos(tilt) metres behind it (1.41 × h at 45°): the footprint's back edge goes about that far north.
func fit() -> void:
	var card := get_node_or_null("Card") as MeshInstance3D
	if card == null or picture == null:
		return
	var size := Vector2(picture.get_width(), picture.get_height()) / pixels_per_metre
	var mesh := QuadMesh.new()
	mesh.size = size
	mesh.center_offset = Vector3(0.0, size.y * 0.5, 0.0)   # the bottom edge at the node's place, not the middle
	card.mesh = mesh
	# Lean it back so it faces the camera: the camera looks down at (90 - tilt) degrees from level.
	card.rotation = Vector3(-deg_to_rad(90.0 - camera_tilt_deg), 0.0, 0.0)
	var material := card.material_override as ShaderMaterial
	if material:
		material.set_shader_parameter("picture", picture)

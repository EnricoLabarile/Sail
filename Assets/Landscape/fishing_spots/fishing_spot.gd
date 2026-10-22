@tool
extends Node3D
## A FISHING SPOT: a patch of darker water with rings welling up (fishing_spot.gdshader). Drop the anchor
## within `reach` metres of its middle (a little more than the patch you see) and she starts fishing; after
## `fishing_time` seconds still at anchor, the haul comes in: fish into the hold (the Inventory autoload) or
## a heart container (one more heart, the hull mended). Then the spot is fished out: it fades away and is gone.
## Weigh anchor before the haul and the nets come back empty (the spot stays, try again).
##
## To place one: instance fishing_spot.tscn (like placing a Blueprint) under FishingSpots in Overworld, move
## it where you want it on the water, and pick in the Inspector what's there (`loot`) and how much.
## @tool: in the editor it's drawn at its size (so you can see where it is); there it does nothing else.

enum Loot { FISH, HEART_CONTAINER }

@export var loot := Loot.FISH       # what the haul brings up
@export var fish_count := 1         # how many fish (only for FISH; as many as fit in the hold)
## The patch's radius on the water, in metres (the picture is twice this across).
@export var radius := 3.3:
	set(value):
		radius = value
		_fit_picture()
@export var reach := 4.5            # metres from the middle the anchor may fall to fish here (a bit more than radius)
@export var fishing_time := 3.0     # seconds at anchor before the haul comes in
@export var fade_time := 1.8        # seconds it takes to fade away once fished out

var _boat: Node3D                   # the boat fishing here (while she is)
var _fishing_left := -1.0           # seconds left to the haul; below 0 = nobody is fishing
var _fished_out := false            # the haul has come in: the spot is fading away
var _fade := 1.0                    # 1 = as drawn, 0 = gone


func _ready() -> void:
	add_to_group("fishing_spots")     # so the boat finds every spot when the anchor goes down (boat.gd)
	_fit_picture()
	if Engine.is_editor_hint():
		return
	_material().set_shader_parameter("phase", randf() * 16.0)   # its own place in the flipbook


## The picture (a 1 x 1 m plane) is scaled to the spot's size. (Scaled, not resized: the plane mesh is shared
## by every spot, so resizing it would resize them all.)
func _fit_picture() -> void:
	var picture := get_node_or_null("Picture") as Node3D
	if picture:
		picture.scale = Vector3(radius * 2.0, 1.0, radius * 2.0)


## Each spot has its own copy of the material (local to scene in fishing_spot.tscn), so it fades alone.
func _material() -> ShaderMaterial:
	return $Picture.material_override


## Called by the boat when she drops anchor: if the anchor is within reach (and there's still something
## here), she starts fishing.
func try_fishing(boat: Node3D) -> void:
	if _fished_out or _fishing_left >= 0.0:
		return
	var off: Vector3 = boat.anchor_point - global_position
	off.y = 0.0                                   # only the distance across the water
	if off.length() > reach:
		return
	_boat = boat
	_fishing_left = fishing_time


## Is the boat here? True while her middle is within `reach` of the spot's middle (or while she's fishing
## here), as long as there's still something to haul. The wheel's hub (helm.gd) asks this to show a question
## mark instead of the anchor.
func has_boat(boat: Node3D) -> bool:
	if _fished_out:
		return false
	if _fishing_left >= 0.0:
		return true                               # fishing here: until the haul comes in
	var off: Vector3 = boat.global_position - global_position
	off.y = 0.0                                   # only the distance across the water
	return off.length() <= reach


func _process(dt: float) -> void:
	if Engine.is_editor_hint():
		return
	# Fished out: fade away, then the spot is gone for good.
	if _fished_out:
		_fade -= dt / fade_time
		_material().set_shader_parameter("fade", maxf(_fade, 0.0))
		if _fade <= 0.0:
			queue_free()
		return
	if _fishing_left < 0.0:
		return                                    # nobody fishing here
	# She weighed anchor (or sank) before the haul: the nets come back empty.
	if not _boat.anchored or _boat.sinking:
		_fishing_left = -1.0
		return
	_fishing_left -= dt
	if _fishing_left <= 0.0:
		_haul()


## The haul comes in.
func _haul() -> void:
	_fishing_left = -1.0
	if loot == Loot.FISH:
		var caught := Inventory.add("fish", fish_count)
		if caught == 0:
			return                                # the hold is full: nothing caught, the spot stays
	else:
		_boat.add_heart_container()
	_fished_out = true

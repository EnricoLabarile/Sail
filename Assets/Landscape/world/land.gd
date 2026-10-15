extends Node
## LAND: tells any script whether a point of the world is land or sea.
##
## This script is an Autoload (Project Settings → Globals → Autoload, name "Land"), like `Wind`:
## any script can ask `Land.is_land(position)`. (In Unreal: a World Subsystem.)
##
## It reads map_collision.png: a black and white picture of the whole world, white = land, black = sea.
## Home (world position 0, 0) is the middle of the picture. If you change the coasts in the painting,
## change this picture the same way (or ask me to make it again from the painting).
##
## The map doesn't repeat: it's one picture, 504 x 504 metres, and outside it counts as land.
## So the edge of the map is a wall the boat bumps into, like any coast.

const WORLD_SIZE := 504.0      # metres the picture covers, a side (the prototype's 5040 px world)
const MASK_PATH := "res://Assets/Landscape/world/map_collision.png"

var _mask: Image               # the picture, kept in memory so we can read its pixels


## Called once, when the game starts: load the picture.
func _ready() -> void:
	var texture: Texture2D = load(MASK_PATH)
	_mask = texture.get_image()


## True if this point of the world is land. Only x and z count (the height doesn't matter).
func is_land(pos: Vector3) -> bool:
	# 1. From metres to a share of the picture, 0..1. Home (0, 0) is the middle, 0.5.
	var u := pos.x / WORLD_SIZE + 0.5
	var v := pos.z / WORLD_SIZE + 0.5
	# 2. Outside the picture (below 0 or above 1): the edge of the map, a wall. It counts as land.
	if u < 0.0 or u >= 1.0 or v < 0.0 or v >= 1.0:
		return true
	# 3. From a share to a pixel of the picture.
	var px := int(u * _mask.get_width())
	var py := int(v * _mask.get_height())
	# 4. White (bright) = land.
	return _mask.get_pixel(px, py).r > 0.5


## Which way the open sea is from a point near the coast: a flat arrow of length 1 pointing away from
## the land (in Unreal terms, the "impact normal" of a hit). Used to bounce the boat off the shore.
##
## How: it looks at 16 points on a circle round `pos` (like the hours on a clock) and adds up the
## directions of those that are sea. Where most of the sea is, the arrow points.
func way_to_sea(pos: Vector3) -> Vector3:
	const LOOK := 2.0                    # metres: how far round the point it looks
	var total := Vector3.ZERO
	for i in 16:
		var angle := i * TAU / 16.0
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		if not is_land(pos + direction * LOOK):
			total += direction
	if total.length() < 0.001:
		return Vector3.ZERO                # land all round: no way out found
	return total.normalized()


## True if there is land within `distance` metres of `pos` (for example: is she in the shallows?).
##
## How: it looks at points on three circles round `pos` (at a third, two thirds and all of the
## distance), 16 points each, like the hours on a clock. If any of them is land, the answer is yes.
func is_near_land(pos: Vector3, distance: float) -> bool:
	for ring in [1.0, 2.0, 3.0]:
		var radius: float = distance * ring / 3.0
		for i in 16:
			var angle := i * TAU / 16.0
			var direction := Vector3(cos(angle), 0.0, sin(angle))
			if is_land(pos + direction * radius):
				return true
	return false

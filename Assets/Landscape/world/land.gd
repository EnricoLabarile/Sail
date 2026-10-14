extends Node
## LAND: tells any script whether a point of the world is land or sea.
##
## This script is an Autoload (Project Settings → Globals → Autoload, name "Land"), like `Wind`:
## any script can ask `Land.is_land(position)`. (In Unreal: a World Subsystem.)
##
## It reads map_collision.png: a black and white picture of the whole world, white = land, black = sea.
## Home (world position 0, 0) is the middle of the picture. If you change the coasts in the painting,
## change this picture the same way (or ask me to make it again from the painting).

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
	#    fposmod(..., 1.0) wraps it: the world repeats, so 1.2 becomes 0.2.
	var u := fposmod(pos.x / WORLD_SIZE + 0.5, 1.0)
	var v := fposmod(pos.z / WORLD_SIZE + 0.5, 1.0)
	# 2. From a share to a pixel of the picture.
	var px := int(u * _mask.get_width())
	var py := int(v * _mask.get_height())
	# 3. White (bright) = land.
	return _mask.get_pixel(px, py).r > 0.5

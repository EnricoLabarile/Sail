extends Node
## LAND: tells any script whether a point of the world is land or sea.
##
## This script is an Autoload (Project Settings → Globals → Autoload, name "Land"), like `Wind`:
## any script can ask `Land.is_land(position)`. (In Unreal: a World Subsystem.)
##
## The land is made of 3D meshes (the coasts) placed in the level, each with a collision shape
## (a StaticBody3D: in Unreal, a mesh with "Block All" collision). To find out if a point is land,
## it shoots a ray straight down from high above that point, like a line trace in Unreal:
## if the ray hits anything solid, that point is land; if it falls through to nothing, it's sea.
##
## The map is WORLD_SIZE x WORLD_SIZE metres round home (0, 0), and outside it counts as land: so the edge of the map
## is a wall the boat bumps into, like any coast.

# Metres the map covers, a side (the prototype's 5040 px world was 504; Enrico doubled it). The ONE place to
# change the world's size: the sea, the fog, the clouds and the logbook's map all read Land.WORLD_SIZE.
# (The sea plane in sea.tscn must be set to the same size by hand.)
const WORLD_SIZE := 1008.0
const RAY_TOP := 100.0         # metres: the ray starts this high above the sea…
const RAY_BOTTOM := -20.0      # …and goes down to this depth

## The shore baker's script, only to read MAX_DISTANCE (so the two never disagree).
const ShoreBaker := preload("res://Assets/Landscape/shore/shore_baker.gd")

## The picture of the distances to the coast of the level that's open (made by its ShoreBaker), kept in
## memory to read its pixels. Each level has its own: the level's Sea hands it over at start (set_shore_picture).
var shore_image: Image


## The picture of the sea zones (boiling water, strong currents) of the level that's open, made by its
## SeaZoneBaker; handed over by the level's Sea at start (set_zones_picture). null = no zones anywhere.
var zones_image: Image


## The level's Sea calls this at start with its sea zones picture (sea.gd, `zones_texture`).
func set_zones_picture(texture: Texture2D) -> void:
	zones_image = texture.get_image() if texture else null


## The pixel of the zones picture under this point of the world (black = nothing there, if there's no picture).
func _zones_pixel(pos: Vector3) -> Color:
	if zones_image == null:
		return Color(0.0, 128.0 / 255.0, 128.0 / 255.0)   # no boiling, no push
	var half := WORLD_SIZE / 2.0
	var x := clampi(int((pos.x + half) / WORLD_SIZE * zones_image.get_width()), 0, zones_image.get_width() - 1)
	var y := clampi(int((pos.z + half) / WORLD_SIZE * zones_image.get_height()), 0, zones_image.get_height() - 1)
	return zones_image.get_pixel(x, y)


## How much the sea boils at this point: 0 = not at all, 1 = fully (inside a boiling zone, past its soft edge).
func boil_at(pos: Vector3) -> float:
	return _zones_pixel(pos).r


## The strong current's push at this point, flat on the water, in m/s (zero outside every current zone).
## The picture keeps it as 128 = none, more = east / south, less = west / north (sea_zone_baker.gd).
func current_at(pos: Vector3) -> Vector3:
	var pixel := _zones_pixel(pos)
	var east := (pixel.g8 - 128) / 127.0 * SeaZone.MAX_PUSH
	var south := (pixel.b8 - 128) / 127.0 * SeaZone.MAX_PUSH
	return Vector3(east, 0.0, south)


## The level's Sea calls this at start with its shore picture (sea.gd, `shore_texture`). null = no picture:
## every point counts as far from the coast.
func set_shore_picture(texture: Texture2D) -> void:
	if texture == null:
		shore_image = null
		return
	# The picture is imported as a texture (for the graphics card); get_image() gives a copy of its pixels
	# that scripts can read (in Unreal: reading a texture's data on the CPU).
	shore_image = texture.get_image()

## True if this point of the world is land. Only x and z count (the height doesn't matter).
func is_land(pos: Vector3) -> bool:
	# 1. Outside the map: the edge, a wall. It counts as land.
	var half := WORLD_SIZE / 2.0
	if absf(pos.x) >= half or absf(pos.z) >= half:
		return true
	# 2. A ray straight down through the point (a line trace). get_world_3d() is the 3D world of the
	#    game; its direct_space_state is where you ask the physics engine questions like this one.
	var space := get_viewport().get_world_3d().direct_space_state
	var from := Vector3(pos.x, RAY_TOP, pos.z)
	var to := Vector3(pos.x, RAY_BOTTOM, pos.z)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit := space.intersect_ray(query)
	# 3. It hit something (a coast's collision): land. Nothing: sea. (hit is an empty Dictionary when
	#    nothing was hit.)
	return not hit.is_empty()


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

## How many metres from this point of the sea to the nearest coast (up to the picture's MAX_DISTANCE, 32 m:
## further than that it says 32). 0 = on the coast.
func distance_to_shore(pos: Vector3) -> float:
	if shore_image == null:
		return ShoreBaker.MAX_DISTANCE            # no picture: as if far from every coast
	# 1. Where the point is on the map, from 0 (west / north edge) to 1 (east / south edge).
	var half := WORLD_SIZE / 2.0
	var across := (pos.x + half) / WORLD_SIZE
	var down := (pos.z + half) / WORLD_SIZE
	# 2. That place in the picture's pixels (clamped: outside the map, the nearest edge pixel).
	var x := clampi(int(across * shore_image.get_width()), 0, shore_image.get_width() - 1)
	var y := clampi(int(down * shore_image.get_height()), 0, shore_image.get_height() - 1)
	# 3. The pixel's grey (0 = black .. 1 = white) times MAX_DISTANCE = metres.
	return shore_image.get_pixel(x, y).r * ShoreBaker.MAX_DISTANCE

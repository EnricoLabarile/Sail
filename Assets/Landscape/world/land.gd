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

extends Node3D
## ONE SPIKE, shot by a sea urchin (sea_urchin.gd): it flies straight across the water, the way it was shot. If it
## touches the boat's HULL (Enrico, Nov 2026: before, only within `hit_radius` of her middle, so spikes crossing her
## bow or stern did nothing) she loses `damage` hearts and it's gone; it's also gone when it
## reaches land or has flown `range_left` metres (it missed).
## (In Unreal: a small projectile actor moving itself every Tick, overlap-tested against the player's pawn.)
##
## The hull is seen as a CAPSULE lying on the water (like a capsule collision in Unreal, turned with the boat): the
## line from her stern to her bow (boat.stern_point() / bow_point(), bow_reach either way of her middle), and
## everything within `hit_radius` of that line (her half width).
##
## Its picture (spike.png, on the flat plane `Picture`) has its point at the TOP: the plane is turned so the top
## points the way it flies. All its numbers come from the urchin that shoots it (launch).

@onready var picture: MeshInstance3D = $Picture

var velocity := Vector3.ZERO     # metres a second across the water
var damage := 0.5                # hearts it takes off the boat
var hit_radius := 1.2            # metres: this close to the line from her stern to her bow, it hits her (her half width)
var range_left := 15.0           # metres it can still fly before it's gone


## The urchin calls this right after adding the spike to the world: from where, which way (flat, length 1), and its
## numbers.
func launch(start: Vector3, direction: Vector3, speed: float, hearts: float, radius: float, distance: float) -> void:
	global_position = start
	velocity = direction * speed
	damage = hearts
	hit_radius = radius
	range_left = distance
	# Turn the picture's top (the plane's -Z) the way it flies. atan2 gives the turn round the up axis.
	rotation.y = atan2(-direction.x, -direction.z)


func _process(dt: float) -> void:
	var step := velocity * dt
	global_position += step
	range_left -= step.length()
	# Flown far enough, or reached land: gone.
	if range_left <= 0.0 or Land.is_land(global_position):
		queue_free()
		return
	# Touching the hull: it hits her (take_damage does nothing while she sinks or comes up).
	var boat := get_tree().get_first_node_in_group("player_boat") as Node3D
	if boat == null:
		return
	if distance_to_hull(boat) < hit_radius:
		boat.hit_by_enemy(damage)    # hearts off, and her engine heats up (boat.gd)
		queue_free()


## How far the spike is from the line stern → bow, across the water (the height doesn't count).
## Geometry2D.get_closest_point_to_segment gives the point of that line nearest the spike; on the water x and z
## are the two flat directions, so the line and the spike are put into 2D as (x, z).
func distance_to_hull(boat: Node3D) -> float:
	var stern: Vector3 = boat.stern_point()
	var bow: Vector3 = boat.bow_point()
	var me := Vector2(global_position.x, global_position.z)
	var nearest := Geometry2D.get_closest_point_to_segment(me, Vector2(stern.x, stern.z), Vector2(bow.x, bow.z))
	return me.distance_to(nearest)

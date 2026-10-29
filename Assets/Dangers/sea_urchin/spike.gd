extends Node3D
## ONE SPIKE, shot by a sea urchin (sea_urchin.gd): it flies straight across the water, the way it was shot. If it
## comes within `hit_radius` of the boat's middle she loses `damage` hearts and it's gone; it's also gone when it
## reaches land or has flown `range_left` metres (it missed).
## (In Unreal: a small projectile actor moving itself every Tick, overlap-tested against the player's pawn.)
##
## Its picture (spike.png, on the flat plane `Picture`) has its point at the TOP: the plane is turned so the top
## points the way it flies. All its numbers come from the urchin that shoots it (launch).

@onready var picture: MeshInstance3D = $Picture

var velocity := Vector3.ZERO     # metres a second across the water
var damage := 0.5                # hearts it takes off the boat
var hit_radius := 1.2            # metres: this close to the boat's middle, it hits her
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
	# Close enough to the boat's middle: it hits her (take_damage does nothing while she sinks or comes up).
	var boat := get_tree().get_first_node_in_group("player_boat") as Node3D
	if boat == null:
		return
	var off := boat.global_position - global_position
	off.y = 0.0                        # only the distance across the water
	if off.length() < hit_radius:
		boat.take_damage(damage)
		queue_free()

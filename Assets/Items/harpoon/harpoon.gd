extends Node3D
## THE HARPOON (Enrico, like Zelda's hookshot): shot from the bow straight ahead, on a rope. If its head comes
## close to something that can be hooked, it bites into it and the rope PULLS that thing to the boat; if it
## catches nothing, it flies out to `max_length` (or until it hits land) and the rope pulls it back.
## (In Unreal: a projectile actor with a cable component, spawned by the harpoon button.)
##
## What can be hooked: every node in the group "hookable" (a general rule, like "bomb_targets"). Each gives:
##   can_be_hooked() -> bool   may it be hooked now? (the imp only when it's up, a pickup only if it's free…)
##   hook_point() -> Vector3   where it is now, on the water
##   hook_size() -> float      metres round hook_point() the head may pass and still catch it
##   hooked(harpoon)           it's caught: an enemy takes `damage` and is stunned (harpoon.damage, stun_time)
##   still_hooked() -> bool    still on the hook? (false = let it go: killed and gone, taken aboard…)
##   pulled_to(point)          the rope moves it here (every frame while pulled)
##   unhooked(harpoon)         let go: an enemy's stun (stun_time) counts from now
## Now: pickups, the sea urchin, the sea imp (also dead, to bring its body aboard).
##
## Its numbers are the exports below: select Harpoon (harpoon.tscn) and change them in the Inspector.
## damage 0 = it doesn't hurt, stun_time 0 = no stun once let go (Enrico).

enum State { FLYING, PULLING, RETURNING }

@export var shoot_speed := 30.0     # m/s the head flies out (she does 3.5 at top speed)
@export var max_length := 20.0      # metres of rope: it flies this far at most, then comes back
@export var return_speed := 40.0    # m/s the empty head is pulled back
@export var pull_speed := 12.0      # m/s a hooked thing is pulled toward her
@export var stop_distance := 2.0    # metres from her bow the pull stops (the thing is let go there)
@export var hook_radius := 1.0      # metres: how close the head must pass (plus the thing's own hook_size) to catch it
@export var damage := 0.5           # hearts a hooked enemy loses (0 = none)
@export var stun_time := 2.0        # seconds a hooked enemy stays stunned, harmless, after it's let go (0 = none)
@export var head_height := 0.3      # metres above the water the head and the rope fly
@export var rope_width := 0.12      # metres

var state := State.FLYING
var boat: Node3D = null             # who shot it: the rope starts at her bow
var direction := Vector3.FORWARD    # which way it flies (her bow's way when shot; it doesn't turn with her after)
var flown := 0.0                    # metres flown out so far
var target: Node = null             # what's on the hook (PULLING)

@onready var head: MeshInstance3D = $Head
@onready var rope: MeshInstance3D = $Rope


## The harpoon button calls this right after adding it to the level.
func launch(from_boat: Node3D) -> void:
	boat = from_boat
	direction = -boat.global_transform.basis.z
	direction.y = 0.0
	direction = direction.normalized()
	head.global_position = bow()
	head.rotation.y = atan2(-direction.x, -direction.z)   # the picture's top (the plane's -Z) the way it flies
	update_rope()


func _process(dt: float) -> void:
	if boat == null or not is_instance_valid(boat) or boat.sinking:
		let_go()
		queue_free()
		return
	match state:
		State.FLYING:
			fly(dt)
		State.PULLING:
			pull(dt)
		State.RETURNING:
			come_back(dt)
	if is_inside_tree():
		update_rope()


## Out it goes, straight ahead; it hooks the first hookable thing it passes close to.
func fly(dt: float) -> void:
	var step := shoot_speed * dt
	head.global_position += direction * step
	flown += step
	var caught := find_hookable()
	if caught:
		target = caught
		state = State.PULLING
		target.hooked(self)
		return
	if flown >= max_length or Land.is_land(head.global_position):
		state = State.RETURNING      # nothing caught: the rope pulls it back


## The first thing of the group "hookable" that may be hooked now and is close enough to the head.
func find_hookable() -> Node:
	for thing in get_tree().get_nodes_in_group("hookable"):
		if not thing.can_be_hooked():
			continue
		if flat_distance(head.global_position, thing.hook_point()) <= hook_radius + thing.hook_size():
			return thing
	return null


## The rope pulls the hooked thing toward her bow (wherever her bow is now: she may be moving). It's let go
## once it's stop_distance from the bow, if the next step would be on land, or when it says it's off the hook.
func pull(dt: float) -> void:
	if not is_instance_valid(target) or not target.still_hooked():
		target = null
		state = State.RETURNING
		return
	var here: Vector3 = target.hook_point()
	var goal := bow()
	goal.y = here.y
	var next := here.move_toward(goal, pull_speed * dt)
	if Land.is_land(next) or flat_distance(next, goal) <= stop_distance:
		let_go()
		state = State.RETURNING
		return
	target.pulled_to(next)
	head.global_position = Vector3(next.x, head_height, next.z)


## Empty, the head is pulled back to the bow; there it's gone.
func come_back(dt: float) -> void:
	var goal := bow()
	head.global_position = head.global_position.move_toward(goal, return_speed * dt)
	if head.global_position.distance_to(goal) < 0.3:
		queue_free()


## Whatever is on the hook is let go (its stun starts now).
func let_go() -> void:
	if target != null and is_instance_valid(target):
		target.unhooked(self)
	target = null


## Where the rope starts: her bow, at the head's height.
func bow() -> Vector3:
	var point: Vector3 = boat.bow_point()
	point.y = head_height
	return point


## The rope: a thin flat strip from her bow to the head (a 1 x 1 plane moved to the middle, turned along the line
## and stretched to its length).
func update_rope() -> void:
	var start := bow()
	var end := head.global_position
	var line := end - start
	line.y = 0.0
	var length := line.length()
	rope.visible = length > 0.05
	if not rope.visible:
		return
	rope.global_position = (start + end) * 0.5
	rope.global_rotation = Vector3(0.0, atan2(-line.x, -line.z), 0.0)
	rope.scale = Vector3(rope_width, 1.0, length)


## The distance across the water (not the height) between two points.
func flat_distance(a: Vector3, b: Vector3) -> float:
	var off := a - b
	off.y = 0.0
	return off.length()

extends Node3D
## THE SAIL (Enrico: everything about the sail lives here, apart from the boat). On the `Rig` node in boat.tscn,
## which turns round the mast and holds the sail and the boom. (In Unreal: an Actor Component on the boat Pawn.)
##
## What it does:
##   - the push of the wind (`drive()`, 0..1 of her top speed): read off the sail's curve (POLAR) from her angle to
##     the wind, less in the shallows (`shallows_sail`); the boat multiplies her top speed by it;
##   - its look: the boom swung out to leeward, the cloth's belly (the shape keys Inflated_Right / Inflated_Left),
##     gathered up onto the boom at anchor, and the boom's trail on the water in a hard fast turn (SailTrail);
##   - whether it's SET: the sail is an item in the hold ("sail", Assets/Inventory/items/sail.tres). A tap on its slot
##     in the logbook switches it on or off (Inventory.toggle). Off, the mast and the sail are gone (Enrico) and the
##     wind gives her nothing; the current still carries her (that's the boat's, boat.gd update_current).
##
## The boat (boat.gd) only calls two things: drive() for her speed, and update_look(dt) every frame.

const ITEM := "sail"   # the item's id (sail.tres)

# The sail's curve (the prototype's SAIL_POLAR_MARCONI): [degrees off the wind, share of top speed].
# 0 = head to wind, 180 = wind right astern.
const POLAR := [[10, 0.0], [0, 0.7], [45.0, 1.0 ], [90.0, 1.0], [180.0, 1.0]]

@export var shallows_sail := 0.5        # what it gives in the shallows (land near: boat.gd in_shallows), as a share
@export var sail_fill_rate := 2.0       # how quickly the cloth fills or empties (higher = quicker)
@export var boom_max_deg := 90.0        # the furthest the boom swings out from her middle line, either side
@export var furl_rate := 2.2            # how quickly it's gathered up when the anchor goes down…
@export var unfurl_rate := 3.5          # …and spread again when it comes up (higher = quicker)
@export var furled_height := 0.06       # how tall the sail is when gathered up, as a share of its full height
# The boom's trail: in a tight, fast turn the boom's end skims the water and leaves dots (SailTrail, dropped where
# SailTip is). How hard she turns = her share of turn_rate × her share of top_speed (0..1); over this, it's on.
@export var sail_trail_threshold := 0.4

var belly := 0.0     # how full the cloth is: -1 full to port (left), 0 flat, +1 full to starboard (right)
var furl := 1.0      # 0 = spread, 1 = gathered up on the boom (she starts at anchor: gathered up)

@onready var boat: Node3D = owner                     # the boat (boat.tscn's root)
@onready var mast: Node3D = get_parent()              # sm_boat_mast: hidden with everything on it when the sail is off
@onready var sail_node: Node3D = $sm_boat_sail        # squashed down onto the boom to gather it up
# The sail's mesh: the MeshInstance3D inside the imported sm_boat_sail (the FBX makes it a little scene), with
# the two shape keys made in Blender (-1 if missing).
@onready var sail_mesh: MeshInstance3D = sail_node.find_children("*", "MeshInstance3D")[0]
@onready var key_right: int = sail_mesh.find_blend_shape_by_name("Inflated_Right")   # belly to starboard
@onready var key_left: int = sail_mesh.find_blend_shape_by_name("Inflated_Left")     # belly to port
@onready var sail_tip: Node3D = $SailTip                                  # the boom's end (a Marker3D, like a Socket)
@onready var sail_trail: CPUParticles3D = owner.find_child("SailTrail")   # the dots it leaves on the water


func _ready() -> void:
	Inventory.toggled.connect(_on_toggled)   # switched on or off in the logbook
	mast.visible = is_set()


## Is the sail set? It must be aboard and switched on.
func is_set() -> bool:
	return Inventory.is_on(ITEM)


## The wind's push, as a share of her top speed (0..1). Nothing when the sail is off or she's at anchor / tied up.
func drive() -> float:
	if not is_set() or boat.anchored:
		return 0.0
	var push := polar(angle_off_wind())
	if boat.in_shallows:
		push *= shallows_sail          # less wind by the coast (Enrico)
	return push


## Her angle to the wind in degrees: 0 = head to wind, 180 = wind right astern.
func angle_off_wind() -> float:
	var fwd: Vector3 = -boat.global_transform.basis.z           # Godot's forward is -Z
	return rad_to_deg(fwd.angle_to(Wind.from_vector()))


## The share of top speed the sail gives at `off_deg` degrees off the wind: read off POLAR, straight lines between
## its points.
func polar(off_deg: float) -> float:
	for i in range(1, POLAR.size()):
		if off_deg <= POLAR[i][0]:
			var a = POLAR[i - 1]
			var b = POLAR[i]
			return lerpf(a[1], b[1], (off_deg - a[0]) / (b[0] - a[0]))
	return POLAR[-1][1]


## Every frame (boat.gd): the boom, the belly, gathering up and the trail. `push` is this frame's drive().
func update_look(dt: float, push: float) -> void:
	if not is_set():
		return                           # no mast, nothing to move
	# Which side the wind comes from: + = from starboard.
	var side := signf(boat.global_transform.basis.x.dot(Wind.from_vector()))
	# The boom swings out to leeward, the side away from the wind: wind from starboard (side = +1) puts the sail
	# out to port. A positive rotation.y turns the rig anticlockwise seen from above, which swings the boom (behind
	# the mast) over to starboard: so the sign is the opposite of `side`. How far out: half the wind's angle off
	# the bow, but never less than 8 degrees and never more than boom_max_deg.
	var boom := -side * deg_to_rad(clampf(angle_off_wind() * 0.5, 8.0, boom_max_deg))
	rotation.y = lerpf(rotation.y, boom if push > 0.0 else 0.0, dt * 2.0)
	update_belly(dt, side)
	update_furl(dt)
	update_trail()


## The cloth fills with the wind: the faster she goes, the fuller it is, and the belly is always on the side away
## from the wind (to leeward, like the boom).
func update_belly(dt: float, side: float) -> void:
	# 1. How full: her speed as a share of her top speed (0 = still, 1 = full speed).
	var fullness := clampf(boat.speed / boat.top_speed, 0.0, 1.0)
	# 2. Which way: away from the wind. Wind from port (side = -1) fills it to starboard (+).
	var target := -side * fullness
	# 3. Gently, not all at once: changing tack, belly slides through 0 (it empties, goes flat, fills the other side).
	belly = lerpf(belly, target, minf(1.0, dt * sail_fill_rate))
	# 4. Shared out to the two shape keys: one gets the belly, the other stays at 0.
	if key_right >= 0:
		sail_mesh.set_blend_shape_value(key_right, maxf(belly, 0.0))
	if key_left >= 0:
		sail_mesh.set_blend_shape_value(key_left, maxf(-belly, 0.0))


## At anchor (or tied up) the sail is gathered up onto the boom (only a look); it spreads again as the anchor comes
## up. Done by squashing the sail's node down (scale.y) onto the boom.
func update_furl(dt: float) -> void:
	var target := 1.0 if boat.anchored else 0.0
	var rate := furl_rate if boat.anchored else unfurl_rate
	furl = lerpf(furl, target, minf(1.0, dt * rate))
	sail_node.scale.y = lerpf(1.0, furled_height, furl)


## The boom's trail: the emitter follows the boom's end, but down on the water (with local_coords off the dots stay
## where they were dropped, so they make a line behind her). On only while she turns hard enough at speed.
func update_trail() -> void:
	if sail_trail == null:
		return
	var tip := sail_tip.global_position
	sail_trail.global_position = Vector3(tip.x, 0.05, tip.z)
	var turn_share: float = absf(boat.turn_speed) / boat.turn_rate        # 1 = turning as fast as she can
	var speed_share := clampf(boat.speed / boat.top_speed, 0.0, 1.0)
	var turning_hard := turn_share * speed_share
	sail_trail.emitting = turning_hard > sail_trail_threshold and not boat.anchored and not boat.sinking


## Stops the trail at once (she's sinking, or the sail was taken down).
func stop_trail() -> void:
	if sail_trail:
		sail_trail.emitting = false


## Gathered up on the boom at once (she's back home at anchor after sinking).
func gather_up() -> void:
	furl = 1.0
	sail_node.scale.y = furled_height


## Switched on or off in the logbook: the mast shows or goes. Set again, it starts gathered up and spreads.
func _on_toggled(item: String, _on: bool) -> void:
	if item != ITEM:
		return
	mast.visible = is_set()
	if is_set():
		gather_up()
	else:
		stop_trail()

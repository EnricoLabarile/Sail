@tool
extends Node3D
## A SEA MINE (Enrico, Nov 2026): a mine floating on the water, placed by hand. It blows up, with exactly the bomb's
## blast (the cross and the circle, the damage, the shake and the sound), when:
##   - the boat runs into it (her middle within `touch_radius`), unless she's towing it;
##   - an enemy touches it (anything in the group "enemies" whose `touch_place()` comes within `touch_radius`), even
##     while she's towing it;
##   - a sea imp comes up next to it (sea_imp_zone.gd calls `imp_emerging_at` when it starts to emerge);
##   - a blast catches it (a bomb or another mine: group "bomb_targets", `blast_at`), so mines go off in a chain.
## The boat can tow it with the hook: its `Towable` child (the component, Assets/Items/towable/towable.gd) does that.
## The blast itself is a bomb (bomb.tscn) made where the mine is and set off at once; the mine is gone.
## (In Unreal: an actor that spawns the bomb Blueprint and calls its Explode event, then destroys itself.)

const BOMB_SCENE := preload("res://Assets/Items/bomb/bomb.tscn")

@export var touch_radius := 2.5     # metres: the boat's or an enemy's middle this close to its middle sets it off
@export var emerge_radius := 6.0    # metres: a sea imp starting to come up this close to it sets it off
@export var body_radius := 1.2      # metres: its size for a blast (a blast reaching this far round it sets it off)
@export var bob_height := 0.1       # metres it bobs up and down on the water
@export var bob_speed := 2.0        # how fast it bobs

var blown := false                  # it went off (it's going)
var bob_time := 0.0

@onready var picture: MeshInstance3D = $Picture
@onready var picture_height: float = $Picture.position.y   # where the picture sits, as placed in sea_mine.tscn
@onready var towable: Towable = $Towable                    # the component that lets the hook drag it


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("sea_mines")            # so a sea imp coming up looks for mines near it (sea_imp_zone.gd)
	add_to_group("bomb_targets")         # so a blast checks it (bomb.gd explode): mines go off in a chain
	bob_time = randf() * TAU             # each mine bobs on its own beat


func _process(dt: float) -> void:
	if Engine.is_editor_hint():
		return
	# It bobs a little on the water (only the picture: the mine's place doesn't change).
	bob_time += dt * bob_speed
	picture.position.y = picture_height + sin(bob_time) * bob_height


## Every physics frame: has the boat or an enemy run into it?
func _physics_process(_dt: float) -> void:
	if Engine.is_editor_hint() or blown:
		return
	# The boat: not while she's towing it (the rope keeps it behind her anyway).
	var boat := Boat.current as Node3D
	if boat and not towable.is_towed() and Land.flat_distance(boat.global_position, global_position) <= touch_radius:
		blow_up()
		return
	# The enemies: each one says where it is while it's solid (touch_place), or null while it can't touch (under water).
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var place: Variant = enemy.touch_place()
		if place != null and Land.flat_distance(place, global_position) <= touch_radius:
			blow_up()
			return


## A sea imp starts to come up at `spot` (sea_imp_zone.gd emerge_at): close enough, the mine goes off.
func imp_emerging_at(spot: Vector3) -> void:
	if not blown and Land.flat_distance(spot, global_position) <= emerge_radius:
		blow_up()


## A blast went off (bomb.gd explode, for the group "bomb_targets"): caught in it, the mine goes off too. Deferred,
## so the first blast finishes checking everything before this one starts.
func blast_at(bomb: Node3D) -> void:
	if not blown and bomb.in_blast(global_position, body_radius):
		blow_up.call_deferred()


## Boom: a bomb is made where the mine is and set off at once (the same blast as a dropped bomb); the mine is gone.
func blow_up() -> void:
	if blown:
		return
	blown = true
	towable.stop_tow()                   # the rope comes off if she was towing it
	var bomb := BOMB_SCENE.instantiate()
	get_parent().add_child(bomb)         # next to the mine in the world (the mine itself is about to go)
	bomb.global_position = Vector3(global_position.x, 0.0, global_position.z)
	bomb.time = bomb.fuse_time           # its fuse already burnt: the blast's flash starts from its beginning
	bomb.explode()
	queue_free()

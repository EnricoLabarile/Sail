@tool
extends Node3D
## A FISHING SPOT: a patch of darker water with rings welling up (fishing_spot.gdshader). Drop the anchor
## within `reach` metres of its middle (a little more than the patch you see) and she starts fishing; after
## `fishing_time` seconds still at anchor, the haul comes in: coins into the purse (the Inventory autoload) or
## a heart container (one more heart, the hull mended), its icon shown rising over the boat (Assets/Boat/item_show.gd,
## like anything brought aboard). Then the spot is fished out: it fades away and is gone.
## (Enrico, Nov 2026: a tap on the interaction button's question mark drops the anchor here by itself, and the
## anchor counts as within reach if either it or her middle is: see try_fishing.)
## Weigh anchor before the haul and the nets come back empty (the spot stays, try again).
##
## To place one: instance fishing_spot.tscn (like placing a Blueprint) under FishingSpots in Overworld, move
## it where you want it on the water, and pick in the Inspector what's there (`loot`) and how much.
## @tool: in the editor it's drawn at its size (so you can see where it is); there it does nothing else.
##
## The boat over the spot: `Sensor` (an Area3D, a cylinder `reach` metres round, like a Trigger Volume in Unreal)
## is told by the physics engine when the boat's own little sensor (`SpotSensor` in boat.tscn) comes in or goes
## out. The spot then tells the boat "you're over me" / "not any more" (boat.gd set_over_fishing_spot), and the
## boat tells the wheel, which shows a question mark instead of the anchor. Nothing is checked every frame.

## What a haul can bring up (Enrico, Nov 2026: coins or a heart container, for now; the fish are gone).
enum Loot { COINS, HEART_CONTAINER }

const COIN_ICON := preload("res://Assets/Inventory/icons/coin.png")                  # shown over the boat for coins
const HEART_ICON := preload("res://Assets/Inventory/icons/heart_container.png")      # ...and for a heart container

@export var loot := Loot.COINS      # what the haul brings up
@export var coin_amount := 5        # how many coins (only for COINS): set it on each spot
## The patch's radius on the water, in metres (the picture is twice this across).
@export var radius := 3.3:
	set(value):
		radius = value
		_fit_picture()
## Metres from the middle the boat may be to fish here (Enrico: a little more than the patch you see, so it isn't
## tight); the sensor is this big too, so it's also where the question mark shows.
@export var reach := 5.5:
	set(value):
		reach = value
		_fit_sensor()
@export var fishing_time := 3.0     # seconds at anchor before the haul comes in
@export var fade_time := 1.8        # seconds it takes to fade away once fished out

var _boat: Node3D                   # the boat fishing here (while she is)
var _fishing_left := -1.0           # seconds left to the haul; below 0 = nobody is fishing
var _fished_out := false            # the haul has come in: the spot is fading away
var _fade := 1.0                    # 1 = as drawn, 0 = gone
var _player: Node3D                 # the player's boat, once the sensor has seen her
var _boat_inside := false           # is she inside the sensor now?
var _told_boat := false             # what we last told her: true = "you're over me"


func _ready() -> void:
	add_to_group("fishing_spots")     # so the boat finds every spot when the anchor goes down (boat.gd)
	_fit_picture()
	_fit_sensor()
	if Engine.is_editor_hint():
		return
	_material().set_shader_parameter("phase", randf() * 16.0)   # its own place in the flipbook
	set_process(false)    # nothing to do every frame until she fishes here (try_fishing switches it on)
	# The physics engine calls these when the boat's sensor comes in or goes out (like OnBeginOverlap /
	# OnEndOverlap in Unreal).
	$Sensor.area_entered.connect(_on_sensor_entered)
	$Sensor.area_exited.connect(_on_sensor_exited)


## The picture (a 1 x 1 m plane) is scaled to the spot's size. (Scaled, not resized: the plane mesh is shared
## by every spot, so resizing it would resize them all.)
func _fit_picture() -> void:
	var picture := get_node_or_null("Picture") as Node3D
	if picture:
		picture.scale = Vector3(radius * 2.0, 1.0, radius * 2.0)


## The sensor's cylinder is as wide as `reach`. (Each spot has its own copy of the shape: local to scene in
## fishing_spot.tscn, so changing one spot's reach doesn't change the others'.)
func _fit_sensor() -> void:
	var shape := get_node_or_null("Sensor/Shape") as CollisionShape3D
	if shape and shape.shape:
		shape.shape.radius = reach


## The boat's sensor came in: remember her, and tell her if there's something here.
func _on_sensor_entered(area: Area3D) -> void:
	var boat := area.get_parent() as Node3D
	if boat == null or not boat.is_in_group("player_boat"):
		return
	_player = boat
	_boat_inside = true
	_update_boat_here()


## The boat's sensor went out.
func _on_sensor_exited(area: Area3D) -> void:
	if area.get_parent() != _player:
		return
	_boat_inside = false
	_update_boat_here()


## Works out whether the boat counts as "over this spot" and, only if that has changed, tells her.
## She is while she's inside the sensor or fishing here (even if the current has carried her a little out),
## as long as there's still something to haul. Called only when something changes: she comes in or goes out,
## starts or stops fishing, the haul comes in.
func _update_boat_here() -> void:
	if _player == null:
		return
	var here := not _fished_out and (_boat_inside or _fishing_left >= 0.0)
	if here == _told_boat:
		return
	_told_boat = here
	_player.set_over_fishing_spot(self, here)


## Each spot has its own copy of the material (local to scene in fishing_spot.tscn), so it fades alone.
func _material() -> ShaderMaterial:
	return $Picture.material_override


## Called by the boat when she drops anchor: if the anchor is within reach (and there's still something
## here), she starts fishing.
func try_fishing(boat: Node3D) -> void:
	if _fished_out or _fishing_left >= 0.0:
		return
	# Close enough if the anchor OR her middle is within reach (the anchor lies off her bow, up to 2.2 m further:
	# where the question mark shows, anchoring must always work).
	if Land.flat_distance(boat.anchor_point, global_position) > reach and Land.flat_distance(boat.global_position, global_position) > reach:
		return
	_boat = boat
	_player = boat
	_fishing_left = fishing_time
	set_process(true)                             # count the fishing time down, every frame
	_update_boat_here()


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
		set_process(false)                        # nobody fishing here: rest until try_fishing
		return
	# She weighed anchor (or sank) before the haul: the nets come back empty.
	if not _boat.anchored or _boat.sinking:
		_fishing_left = -1.0
		_update_boat_here()
		return
	_fishing_left -= dt
	if _fishing_left <= 0.0:
		_haul()


## The haul comes in: the coins or the heart, and its icon rises over the boat so it's clear what was found.
func _haul() -> void:
	_fishing_left = -1.0
	if loot == Loot.COINS:
		Inventory.add_coins(coin_amount)          # the purse under the hearts counts up (health.gd)
		_show_over_boat(COIN_ICON)
	else:
		_boat.add_heart_container()
		_show_over_boat(HEART_ICON)
	_fished_out = true
	_update_boat_here()                           # nothing left here: the wheel shows the anchor again


## The haul's icon rising over the boat (the Boat's child ItemShow, item_show.gd), with the "came aboard" sound, like
## anything brought aboard (the fish of a haul made it before, going through the hold).
func _show_over_boat(icon: Texture2D) -> void:
	Sfx.came_aboard()
	var shower := _boat.get_node_or_null("ItemShow")
	if shower:
		shower.show_picture(icon)

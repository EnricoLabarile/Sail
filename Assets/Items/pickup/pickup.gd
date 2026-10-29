@tool
extends Node3D
## A PICKUP: one kind of item (an ItemData: bomb, trap, fish…) floating on the water on a paper disc, bobbing.
## When the boat comes within `reach` (its Sensor, an Area3D like a Trigger Volume, feels her SpotSensor) it's
## MAGNETISED (Enrico): it flies to her, quicker and quicker, and once it reaches her middle it goes into the
## hold, with a blip and a little screen shake. If the hold has no room, it stays where it is.
## (In Unreal: a pickup actor with an overlap volume, like the coins and hearts of any game.)
##
## It's a thing on its own: place pickup.tscn anywhere in a level and pick its `item` in the Inspector. Other
## things also make them:
##   - the floating shop puts one on each slot, with a `price` (store_alternative.gd decides whether she can
##     have it: `auto_take` off, it listens to `touched`);
##   - a sea imp leaves some when it's killed (sea_imp_zone.gd, `drop_item`).

signal touched(pickup: Node3D, boat: Node3D)   # the boat came over it (sent always, taken or not)
signal taken(pickup: Node3D)                   # it went into the hold (just before it's freed)

## What it is (drag a .tres from Assets/Inventory/items here).
@export var item: ItemData:
	set(value):
		item = value
		_show_icon()
@export var count := 1                 # how many of it she gets
@export var price := 0                 # coins it costs (0 = free; the shop sets its own prices)
## The magnet: metres from it her middle must come for it to fly to her (Enrico: about twice the boat; was 5,
## when she had to sail onto it). Change it here or in the Inspector: the sensor follows by itself
## (_fit_sensor), in the editor too. (The floating shop sets its own: store_alternative.gd pickup_radius.)
@export var reach := 6.0:
	set(value):
		reach = value
		_fit_sensor()
@export var auto_take := true          # off when a shop decides instead (it listens to `touched`): then no magnet
@export var pull_speed := 3.0          # m/s it sets off toward her when the magnet catches it…
@export var pull_accel := 25.0         # …gaining this much speed every second (so it's sucked in faster and faster)
@export var collect_distance := 0.8    # metres from her middle at which it's in: into the hold
@export var bob_height := 0.1          # metres it bobs up and down
@export var bob_speed := 8.0           # how fast
@export var take_shake_strength := 0.25   # the little screen shake when she takes it (metres)…
@export var take_shake_time := 0.18       # …and how long it lasts (seconds)

var time := randf() * TAU              # where in its bob it is (each one starts at its own point)
var picture: MeshInstance3D            # the icon, made in code (so it's never saved into a level)
var pulled_by: Node3D = null           # the boat it's flying to (null = not pulled, it floats where it is)
var speed := 0.0                       # how fast it's flying to her now (m/s)

@onready var floating: Node3D = $Float   # the disc and the icon: this bobs, the pickup itself stays put


func _ready() -> void:
	_make_picture()
	_fit_sensor()
	if Engine.is_editor_hint():
		return
	$Sensor.area_entered.connect(_on_sensor_entered)


## The sensor's cylinder is as wide as `reach`: `reach` is the one number to change, the shape just follows it.
## (Each pickup has its own copy of the shape: local to scene in pickup.tscn, so one's reach doesn't change the
## others'.) Called when `reach` changes and at start; get_node_or_null because the setter can run before the
## nodes exist (while the scene is being loaded).
func _fit_sensor() -> void:
	var shape_node := get_node_or_null("Sensor/Shape") as CollisionShape3D
	if shape_node and shape_node.shape:
		shape_node.shape.radius = reach


func _process(dt: float) -> void:
	if Engine.is_editor_hint():
		return
	time += dt * bob_speed
	floating.position.y = sin(time) * bob_height
	if pulled_by:
		fly_to_boat(dt)


## The magnet: it moves straight toward her middle (wherever she is now: she's moving too), speeding up, and
## when it's close enough it's taken. If meanwhile the hold has filled up (or the purse emptied), it stops and
## stays where it got to.
func fly_to_boat(dt: float) -> void:
	if not is_instance_valid(pulled_by):
		pulled_by = null
		return
	var target := pulled_by.global_position
	target.y = global_position.y                     # it stays on the water: only across, never up or down
	speed += pull_accel * dt
	global_position = global_position.move_toward(target, speed * dt)
	if global_position.distance_to(target) <= collect_distance:
		if why_not() == "":
			take(pulled_by)
		else:
			pulled_by = null                         # no room any more: it just floats here


## Something came over it: if it's the boat, tell whoever listens, and take it if it takes itself.
func _on_sensor_entered(area: Area3D) -> void:
	var boat := area.get_parent() as Node3D
	if boat == null or not boat.is_in_group("player_boat"):
		return
	touched.emit(self, boat)
	if auto_take and why_not() == "" and pulled_by == null:
		pulled_by = boat                             # the magnet: from now on _process flies it to her
		speed = pull_speed


## Why she can't take it now: "hold_full", "no_money", or "" if she can.
func why_not() -> String:
	if item == null:
		return "no_item"
	var after: Array[String] = Inventory.items.duplicate()
	for i in count:
		after.append(item.id)
	if Inventory.slots_of(after).size() > Inventory.SLOTS:
		return "hold_full"
	if Inventory.coins < price:
		return "no_money"
	return ""


## Into the hold (and the coins out of the purse, if it has a price), a shake, and it's gone. (The sound is the
## boat's: anything coming aboard makes it, see boat.gd _on_came_aboard.)
func take(boat: Node3D) -> void:
	Inventory.add(item.id, count)
	if price > 0:
		Inventory.add_coins(-price)
	boat.camera.shake_hard(take_shake_strength, take_shake_time)
	taken.emit(self)
	queue_free()


## EVERY ENEMY'S REWARD (Enrico's rule: when an enemy dies it drops something; sea_imp_zone.gd, sea_urchin.gd).
## With a chance of `chance` (0..1: 1 = always, 0.5 = one time in two) it leaves between count_min and count_max
## pickups of `item`, each on its own spot of water within `spread` metres of `middle`, added to `parent` (the level,
## not the enemy, so they stay put whatever it does next). `item` null = nothing.
## static: it belongs to the script, not to a pickup, so an enemy calls it as Pickup.drop_loot(…) (like a static
## function in a Blueprint Function Library).
static func drop_loot(parent: Node, item: ItemData, middle: Vector3, chance: float, count_min: int, count_max: int,
		spread: float) -> void:
	if item == null or randf() >= chance:
		return
	var scene: PackedScene = load("res://Assets/Items/pickup/pickup.tscn")
	for i in randi_range(count_min, count_max):
		var pickup := scene.instantiate()
		pickup.item = item
		parent.add_child(pickup)
		pickup.global_position = loot_spot(middle, spread)


## A random spot of water within `spread` metres of `middle` (if 10 tries all land on land: `middle` itself).
static func loot_spot(middle: Vector3, spread: float) -> Vector3:
	middle.y = 0.0
	for attempt in 10:
		var angle := randf() * TAU
		var distance := randf_range(1.0, spread)
		var spot := middle + Vector3(cos(angle), 0.0, sin(angle)) * distance
		if not Land.is_land(spot):
			return spot
	return middle


## The icon lying on the disc: a flat plane with the item's picture, sharp, see-through round it, unshaded.
func _make_picture() -> void:
	if picture == null:
		var plane := PlaneMesh.new()
		plane.size = Vector2(2.6, 2.6)
		picture = MeshInstance3D.new()
		picture.mesh = plane
		picture.position.y = 0.15
		picture.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		$Float.add_child(picture)          # no owner: made fresh each time, never saved in a scene
	_show_icon()


func _show_icon() -> void:
	if picture == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_texture = item.icon if item else null
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	picture.material_override = material

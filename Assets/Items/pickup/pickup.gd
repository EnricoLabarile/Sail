@tool
extends Node3D
## A PICKUP: one kind of item (an ItemData: bomb, trap, fish…) floating on the water on a paper disc, bobbing.
## The boat sails over it (its Sensor, an Area3D like a Trigger Volume, feels her SpotSensor) and it goes into
## the hold, with a blip and a little screen shake. If the hold has no room, it stays where it is.
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
@export var reach := 2.4               # metres from it her middle must come to take it
@export var auto_take := true          # off when a shop decides instead (it listens to `touched`)
@export var bob_height := 0.1          # metres it bobs up and down
@export var bob_speed := 8.0           # how fast
@export var take_shake_strength := 0.25   # the little screen shake when she takes it (metres)…
@export var take_shake_time := 0.18       # …and how long it lasts (seconds)

var time := randf() * TAU              # where in its bob it is (each one starts at its own point)
var picture: MeshInstance3D            # the icon, made in code (so it's never saved into a level)

@onready var floating: Node3D = $Float   # the disc and the icon: this bobs, the pickup itself stays put


func _ready() -> void:
	_make_picture()
	if Engine.is_editor_hint():
		return
	# The sensor as wide as `reach` (each pickup has its own copy of the shape: local to scene in pickup.tscn).
	var shape := $Sensor/Shape.shape as CylinderShape3D
	shape.radius = reach
	$Sensor.area_entered.connect(_on_sensor_entered)


func _process(dt: float) -> void:
	if Engine.is_editor_hint():
		return
	time += dt * bob_speed
	floating.position.y = sin(time) * bob_height


## Something came over it: if it's the boat, tell whoever listens, and take it if it takes itself.
func _on_sensor_entered(area: Area3D) -> void:
	var boat := area.get_parent() as Node3D
	if boat == null or not boat.is_in_group("player_boat"):
		return
	touched.emit(self, boat)
	if auto_take and why_not() == "":
		take(boat)


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

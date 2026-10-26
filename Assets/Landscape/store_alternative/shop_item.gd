extends Node3D
## ONE THING FOR SALE at a floating shop (store_alternative.gd puts one on each of its slots): its picture on a
## paper disc, floating and bobbing on the water. The boat sails over it (its Sensor, an Area3D like a Trigger
## Volume, feels her SpotSensor): the shop decides whether she gets it (try_buy) or bounces off.

@export var bob_height := 0.08   # metres it bobs up and down
@export var bob_speed := 2.0     # how fast

var item := ""                   # the item's id ("bomb"…)
var price := 0                   # coins it costs (its ItemData buy_price)
var shop: Node3D = null          # the floating shop it belongs to
var time := randf() * TAU        # where in its bob it is (each one starts at its own point)

@onready var picture: MeshInstance3D = $Picture


## Called by the shop as soon as it's made: what it is, for whom, and how close she must come to take it.
func setup(info: ItemData, for_shop: Node3D, reach: float) -> void:
	item = info.id
	price = info.buy_price
	shop = for_shop
	# Its picture: the item's icon, sharp (nearest), see-through round it, unshaded like everything else.
	var material := StandardMaterial3D.new()
	material.albedo_texture = info.icon
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	picture.material_override = material
	# The sensor as wide as `reach` (each item has its own copy of the shape: local to scene in shop_item.tscn).
	var shape := $Sensor/Shape.shape as CylinderShape3D
	shape.radius = reach
	$Sensor.area_entered.connect(_on_sensor_entered)


func _process(dt: float) -> void:
	time += dt * bob_speed
	position.y = sin(time) * bob_height


## Something came over it: if it's the boat, ask the shop.
func _on_sensor_entered(area: Area3D) -> void:
	var boat := area.get_parent() as Node3D
	if boat == null or not boat.is_in_group("player_boat"):
		return
	shop.try_buy(self, boat)

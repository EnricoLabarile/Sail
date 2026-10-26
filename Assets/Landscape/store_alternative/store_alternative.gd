@tool
extends Node3D
## A FLOATING SHOP (the alternative store, Enrico): no counter, no window. The things for sale float on the water
## on the shop's three slots (Slot1, Slot2, Slot3: move them in the scene), each with its price beside it. Sail
## over one: with enough coins and room in the hold it's yours (the coins go), otherwise she bounces off it.
## The merchant talks without stopping her: a speech bubble over him, on screen for line_time seconds, when she
## comes within greet_radius ("welcome"), and when she bounces off a thing (too dear, or the hold is full).
## (In Unreal: an actor with three trigger volumes for the goods and one round the shop for the greeting.)
##
## The bubble and the price tags are drawn crisp, pinned to where the merchant and the goods are on screen
## (Talk, a CanvasLayer), so the words stay readable through the dither.
## In the editor a see-through green disc shows greet_radius.

@export var for_sale: Array[ItemData] = []   # up to three things: the first on Slot1, the second on Slot2, the third on Slot3
@export var welcome_line := "Welcome, sailor! Sail over what you fancy."
@export var no_money_line := "You can't afford that."
@export var hold_full_line := "Your hold is full."
@export var greet_radius := 30.0:              # metres round the shop where the merchant greets her
	set(value):
		greet_radius = value
		_fit_greet_area()
@export var pickup_radius := 2.4               # metres from a thing her middle must come to take it (or bounce)
@export var bounce_push := 6.0                 # m/s she's pushed back off a thing she can't take
@export var line_time := 3.0                   # seconds a line stays in the bubble

const ITEM_SCENE := preload("res://Assets/Landscape/store_alternative/shop_item.tscn")

var items: Array[Node3D] = []                  # the things still for sale (ShopItem nodes)
var price_tags: Array[Label] = []              # their price tags on screen, in the same order
var boat_near := false                         # is she within greet_radius?
var line_left := 0.0                           # seconds the bubble still shows

@onready var merchant: Node3D = $Merchant
@onready var talk_layer: CanvasLayer = $Talk
@onready var bubble: PanelContainer = $Talk/Bubble
@onready var bubble_text: Label = $Talk/Bubble/Text


func _ready() -> void:
	_fit_greet_area()
	if Engine.is_editor_hint():
		_make_editor_disc()
		return
	talk_layer.visible = true              # the bubble's layer on (the bubble itself shows only when he speaks)
	bubble.visible = false
	$GreetArea.area_entered.connect(_on_greet_entered)
	$GreetArea.area_exited.connect(_on_greet_exited)
	put_out_goods()


## One ShopItem on each slot, for the first three things in for_sale (an empty entry leaves its slot empty).
func put_out_goods() -> void:
	for i in mini(3, for_sale.size()):
		var info := for_sale[i]
		if info == null:
			continue
		var slot := get_node("Slot%d" % (i + 1)) as Node3D
		var thing := ITEM_SCENE.instantiate()
		slot.add_child(thing)
		thing.setup(info, self, pickup_radius)
		items.append(thing)
		var tag := make_price_tag("%dc" % info.buy_price)
		talk_layer.add_child(tag)
		price_tags.append(tag)


# ---------- buying ----------

## The boat came over `thing`: she gets it if she can pay and it fits; otherwise she bounces off and the merchant
## says why.
func try_buy(thing: Node3D, boat: Node3D) -> void:
	var after: Array[String] = Inventory.items.duplicate()
	after.append(thing.item)
	if Inventory.slots_of(after).size() > Inventory.SLOTS:
		bounce(thing, boat, hold_full_line)
		return
	if Inventory.coins < thing.price:
		bounce(thing, boat, no_money_line)
		return
	# Bought: into the hold, the coins out of the purse, and it's gone from the water (for good).
	Inventory.add(thing.item)
	Inventory.add_coins(-thing.price)
	var index := items.find(thing)
	items.remove_at(index)
	price_tags[index].queue_free()
	price_tags.remove_at(index)
	thing.queue_free()


## She can't take it: pushed back off it (boat.gd push_away: no damage), and the merchant says `line`.
func bounce(thing: Node3D, boat: Node3D, line: String) -> void:
	boat.push_away(thing.global_position, bounce_push)
	say(line)


# ---------- the merchant's words ----------

## She came within greet_radius: the merchant greets her, and the camera comes closer (as at anchor).
func _on_greet_entered(area: Area3D) -> void:
	var boat := area.get_parent() as Node3D
	if boat and boat.is_in_group("player_boat") and not boat_near:
		boat_near = true
		boat.camera.ask_close_up(true)
		say(welcome_line)


## She left: the camera goes back out.
func _on_greet_exited(area: Area3D) -> void:
	var boat := area.get_parent() as Node3D
	if boat and boat.is_in_group("player_boat") and boat_near:
		boat_near = false
		boat.camera.ask_close_up(false)


## Shows `line` in the bubble over the merchant for line_time seconds.
func say(line: String) -> void:
	bubble_text.text = line
	bubble.visible = true
	line_left = line_time


## Every frame: count the bubble down, and pin the bubble and the price tags to where the merchant and the goods
## are on screen (only while she's near; far off nothing shows).
func _process(dt: float) -> void:
	if Engine.is_editor_hint():
		return
	if line_left > 0.0:
		line_left -= dt
		if line_left <= 0.0:
			bubble.visible = false
	for tag in price_tags:
		tag.visible = boat_near
	if not boat_near and not bubble.visible:
		return
	var camera := get_boat_camera()
	if camera == null:
		return
	if bubble.visible:
		var head := on_screen(camera, merchant.global_position + Vector3(0, 4.2, 0))
		bubble.position = head - Vector2(bubble.size.x * 0.5, bubble.size.y)   # centred above the head
	for i in items.size():
		var spot := on_screen(camera, items[i].global_position + Vector3(0, 0, 2.6))   # just in front of the thing
		price_tags[i].position = spot - price_tags[i].size * 0.5


## Where a point of the world shows on the screen, in this layer's coordinates. The camera draws into the game view
## (a smaller picture, see game_view.gd), so its point is turned into a share of that picture (0..1) and then
## into the same share of the screen.
func on_screen(camera: Camera3D, point: Vector3) -> Vector2:
	var in_view := camera.unproject_position(point)
	var view_size := camera.get_viewport().get_visible_rect().size
	var screen_size := talk_layer.get_viewport().get_visible_rect().size
	return in_view / view_size * screen_size


func get_boat_camera() -> Camera3D:
	var boat := get_tree().get_first_node_in_group("player_boat")
	if boat == null:
		return null
	return boat.camera


## A price tag: the price in ink on a little paper label with an ink border.
func make_price_tag(text: String) -> Label:
	var tag := Label.new()
	tag.text = text
	tag.add_theme_color_override("font_color", Color("1b1a17"))
	tag.add_theme_font_size_override("font_size", 12)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("ebe7dc")
	box.border_color = Color("1b1a17")
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.content_margin_left = 4
	box.content_margin_right = 4
	tag.add_theme_stylebox_override("normal", box)
	tag.visible = false
	return tag


# ---------- the greeting area ----------

## The greeting area's cylinder as wide as greet_radius (its own copy of the shape: local to scene).
func _fit_greet_area() -> void:
	var shape_node := get_node_or_null("GreetArea/Shape") as CollisionShape3D
	if shape_node and shape_node.shape:
		shape_node.shape.radius = greet_radius
	if _editor_disc:
		_editor_disc.scale = Vector3(greet_radius, 1.0, greet_radius)


# ---------- In the editor only: greet_radius drawn as a disc on the water ----------
# Made in code with no owner, so it isn't saved in the scene and never appears in the game.

var _editor_disc: MeshInstance3D

func _make_editor_disc() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.05
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.2, 0.9, 0.4, 0.2)
	material.render_priority = 10       # drawn after the sea, never hidden by it from afar
	material.no_depth_test = true       # and over the land
	mesh.material = material
	_editor_disc = MeshInstance3D.new()
	_editor_disc.mesh = mesh
	_editor_disc.position.y = 0.1
	add_child(_editor_disc)
	_fit_greet_area()

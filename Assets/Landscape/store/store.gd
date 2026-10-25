extends Node3D
## A STORE: a pier with a merchant. The boat sails up to it and ties up by herself (the pier's own logic,
## Assets/Landscape/pier); as soon as she's tied up, the counter opens (StoreCounter, store_counter.gd), where the
## player trades the hold for the merchant's goods, the purse settling the difference.
## (In Unreal: an actor holding the pier as a Child Actor, plus a widget.)
##
## Its scene (store.tscn) has: Pier (an instance of pier.tscn: move/turn it, and its Berth, as for any pier),
## Building (a placeholder box), StoreCounter (the trading window).
## In the Inspector: the merchant's name, what it sells (for_sale: add a slot, then drag in an ItemData .tres from
## Assets/Inventory/items, or pick it with the slot's menu; as many as you like) and how many of each (stock).
## What the merchant BUYS from the player is set in each item's .tres (sell_price above 0).

@export var merchant_name := "Merchant"      # shown on top of the counter
@export var for_sale: Array[ItemData] = []    # what this merchant sells
@export var stock := -1                       # how many of each it has (-1 = no limit)

var sold := {}                                # item's id → how many sold so far (for `stock`)

@onready var pier: Node3D = $Pier
@onready var counter: CanvasLayer = $StoreCounter


func _ready() -> void:
	pier.docked.connect(_on_docked)


## The boat tied up at this store's pier: the counter opens.
func _on_docked(_boat: Node3D) -> void:
	counter.open(self)


## What's for sale now, as piles [{"item": id, "count": how many}], less what's already on the counter (`taken`).
## With no stock limit the count is just 1 (it's never shown as a pile).
func goods_left(taken: Array[String]) -> Array:
	var result := []
	for info in for_sale:
		if info == null:
			continue                     # an empty slot in the Inspector's list
		var left := 1                    # no limit: always one more on the shelf
		if stock >= 0:
			left = stock - sold.get(info.id, 0) - taken.count(info.id)
		if left > 0:
			result.append({"item": info.id, "count": left})
	return result


## One of `item` was bought: counts it (for `stock`).
func sold_one(item: String) -> void:
	sold[item] = sold.get(item, 0) + 1

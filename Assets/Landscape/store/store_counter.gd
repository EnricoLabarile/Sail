extends CanvasLayer
## THE COUNTER: the trading window of a store (store.gd opens it when the boat ties up at its pier).
## (In Unreal: a UMG widget the store actor shows; here a CanvasLayer drawn crisp, over the game, not dithered.)
##
## As the prototype's barter table: on the left YOUR HOLD, on the right the merchant's goods (FOR SALE).
## A tap on a thing moves one of it onto the counter, under its column ("You give" / "You take"); a tap on it
## there puts it back. The BALANCE is what you give (each at its sell price) minus what you take (each at its buy
## price): above 0 the merchant pays you the difference, below 0 you pay it from your purse.
## TRADE is only possible when something is on the counter, the purse covers what's owed, and everything you'd
## have afterwards fits in the hold; otherwise the line under the purse says why. QUIT closes without trading.
## Either way she stays tied up; she leaves as usual, holding the anchor button.
## Things the merchant won't buy (sell price 0, set in their ItemData .tres) are greyed out in your hold.
##
## Its layout (sizes, places, fonts) is in store_counter.tscn: the item buttons are made here in code.

const PAPER := Color("ebe7dc")
const INK := Color("1b1a17")
const BUTTON_SIZE := Vector2(46, 50)   # one item's button on the counter

var store: Node = null                 # the store whose counter this is (store.gd), set by open()
var give: Array[String] = []           # what the player puts on the counter from the hold
var take: Array[String] = []           # what the player takes from the merchant

@onready var title_label: Label = $Card/Margin/Lines/Title
@onready var hold_grid: GridContainer = $Card/Margin/Lines/Columns/Hold/HoldGrid
@onready var give_grid: GridContainer = $Card/Margin/Lines/Columns/Hold/GiveGrid
@onready var shop_grid: GridContainer = $Card/Margin/Lines/Columns/Shop/ShopGrid
@onready var take_grid: GridContainer = $Card/Margin/Lines/Columns/Shop/TakeGrid
@onready var purse_label: Label = $Card/Margin/Lines/Purse
@onready var balance_label: Label = $Card/Margin/Lines/Balance
@onready var quit_button: Button = $Card/Margin/Lines/Buttons/Quit
@onready var trade_button: Button = $Card/Margin/Lines/Buttons/Trade


func _ready() -> void:
	visible = false
	style_button(quit_button, false)
	style_button(trade_button, true)
	quit_button.pressed.connect(close)
	trade_button.pressed.connect(trade)


# ---------- opening and closing ----------

## Shows the counter for this store: an empty counter, the merchant's name on top.
func open(for_store: Node) -> void:
	store = for_store
	give.clear()
	take.clear()
	title_label.text = store.merchant_name
	set_game_controls(false)
	visible = true
	refresh()


## Hides the counter and gives the player the controls back.
func close() -> void:
	visible = false
	set_game_controls(true)


## While the counter is open: no wheel, wind vane, hearts, logbook or bomb button (the prototype hid them too),
## and the anchor can't be worked (boat.talking, as during a talk), so she can't sail off with it open.
func set_game_controls(on: bool) -> void:
	for group in ["hidden_while_talking", "hidden_at_start"]:
		for node in get_tree().get_nodes_in_group(group):
			node.visible = on
	var helm := get_tree().get_first_node_in_group("helm") as CanvasItem
	if helm:
		helm.visible = on
	var boat := get_tree().get_first_node_in_group("player_boat")
	if boat:
		boat.talking = not on


# ---------- the sums ----------

## What's on the counter, in coins: what you give (at its sell price) minus what you take (at its buy price).
func balance() -> int:
	var total := 0
	for item in give:
		total += Inventory.data(item).sell_price
	for item in take:
		total -= Inventory.data(item).buy_price
	return total


## The hold as it would be after the trade: what's aboard, less what's given, plus what's taken.
func hold_after() -> Array[String]:
	var after: Array[String] = Inventory.items.duplicate()
	for item in give:
		after.erase(item)                # erase takes out one of it
	for item in take:
		after.append(item)
	return after


## Why the trade can't be done ("" = it can).
func problem() -> String:
	if give.is_empty() and take.is_empty():
		return "Tap things to put them on the counter"
	if Inventory.coins + balance() < 0:
		return "Not enough coins"
	if Inventory.slots_of(hold_after()).size() > Inventory.SLOTS:
		return "No room in the hold"
	return ""


# ---------- the trade ----------

## Done: what's given leaves the hold, what's taken comes in, the purse settles the balance, the merchant's stock
## goes down; then the counter closes.
func trade() -> void:
	if problem() != "":
		return
	var coins := balance()
	for item in give:
		Inventory.remove(item)
	for item in take:
		Inventory.add(item)
		store.sold_one(item)
	Inventory.add_coins(coins)
	close()


# ---------- drawing the counter ----------

## Builds every button again from what's where now, and writes the purse and the balance.
func refresh() -> void:
	# Your hold, less what's already on the counter; a tap gives one (if the merchant buys it).
	fill_grid(hold_grid, piles(Inventory.items, give), "sell", give_one)
	fill_grid(give_grid, piles(give, []), "sell", take_back_given)
	# The merchant's goods, less what you already took; a tap takes one.
	fill_grid(shop_grid, store.goods_left(take), "buy", take_one)
	fill_grid(take_grid, piles(take, []), "buy", put_back_taken)
	purse_label.text = "Purse: %d coins" % Inventory.coins
	var why := problem()
	var money := balance()
	if why != "":
		balance_label.text = why
	elif money > 0:
		balance_label.text = "You get %d coins" % money
	elif money < 0:
		balance_label.text = "You pay %d coins" % -money
	else:
		balance_label.text = "Even trade"
	trade_button.disabled = why != ""
	trade_button.modulate.a = 0.4 if why != "" else 1.0


## Counts a list of items into piles, in order: [{"item": name, "count": n}], leaving out what's in `minus`.
func piles(list: Array[String], minus: Array[String]) -> Array:
	var left: Array[String] = list.duplicate()
	for item in minus:
		left.erase(item)
	var result := []
	var where := {}                    # item → its pile in `result`
	for item in left:
		if where.has(item):
			result[where[item]]["count"] += 1
		else:
			where[item] = result.size()
			result.append({"item": item, "count": 1})
	return result


## Empties a grid and fills it with a button per pile. `price` is which price to show ("sell" or "buy");
## `on_tap` is called with the item's name when a button is tapped.
func fill_grid(grid: GridContainer, pile_list: Array, price: String, on_tap: Callable) -> void:
	for child in grid.get_children():
		child.queue_free()
	for pile in pile_list:
		var item: String = pile["item"]
		var info := Inventory.data(item)
		if info == null:
			continue
		var coins := info.sell_price if price == "sell" else info.buy_price
		var button := Button.new()
		button.custom_minimum_size = BUTTON_SIZE
		button.icon = info.icon
		button.expand_icon = false
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.focus_mode = Control.FOCUS_NONE
		var how_many := "" if pile["count"] == 1 else "x%d " % pile["count"]
		button.text = "%s%dc" % [how_many, coins]           # e.g. "x3 2c": three of them, 2 coins each
		style_button(button, false)
		button.add_theme_font_size_override("font_size", 10)
		if price == "sell" and coins <= 0:
			button.disabled = true          # the merchant doesn't buy this
			button.modulate.a = 0.35
		button.pressed.connect(on_tap.bind(item))   # bind: the button hands its item's name to on_tap
		grid.add_child(button)


## Ink on paper like the rest of the card; `filled` = the other way round (paper on ink).
func style_button(button: Button, filled: bool) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = INK if filled else PAPER
	box.border_color = INK
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	box.set_content_margin_all(4)
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, box)
	var text_colour := PAPER if filled else INK
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		button.add_theme_color_override(state, text_colour)


# ---------- the taps ----------

func give_one(item: String) -> void:
	give.append(item)
	refresh()


func take_back_given(item: String) -> void:
	give.erase(item)
	refresh()


func take_one(item: String) -> void:
	take.append(item)
	refresh()


func put_back_taken(item: String) -> void:
	take.erase(item)
	refresh()

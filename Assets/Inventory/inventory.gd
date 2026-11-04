extends Node
## THE INVENTORY: the boat's hold, as the prototype's ("Cargo", 9 slots), and what's equipped.
## An autoload (project.godot), so it's there all game long and any script can use it by name, e.g.
## Inventory.add("fish"). (In Unreal: a GameInstance subsystem that keeps the player's items.)
## Only the data lives here: the logbook (Assets/UI/logbook/book.gd) draws it and lets the player tap it.
##
## An item is just its name (a String), e.g. "fish". Everything else about it (its picture, its prices, whether it
## stacks or can be equipped) is in its ItemData file, Assets/Inventory/items/<name>.tres, read at the start into
## `catalogue` (see item_data.gd). A new kind of item = a new .tres in that folder.
## Most things take a slot each (two fish = two slots). Stackable things (bombs, traps) pile up in ONE slot,
## however many there are, with their number drawn on it. When all the slots are taken, nothing new fits.
##
## EQUIPPING (Enrico, Nov 2026: ONE thing at a time, used with the interaction button in the middle of the wheel,
## Assets/UI/interaction_button): `equipped` is what's in hand ("" = nothing). Any equippable thing (bomb, trap, Aeolus
## Jar, harpoon, hook). In the logbook a tap on a thing's slot equips it (whatever was equipped is put back); holding
## the finger on it takes it off (unequip).
## Things with ItemData.equip_on_pickup (bomb, jar, harpoon, hook) are equipped by themselves when they come aboard, if
## nothing is equipped yet.
##
## SWITCHED ON / OFF (Enrico): things with ItemData.toggle_on_tap (the sail) aren't put in hand: a tap on their slot
## in the logbook switches them on or off (toggle), kept in `switched_on`; is_on(item) = aboard and on.
##
## The purse: `coins`, taken in and spent at the stores. It takes no slot.

## Sent whenever something comes in or goes out (the open logbook listens, to draw the pages again).
signal changed
## The purse changed (add_coins): the coins under the hearts listen to it (health.gd).
signal coins_changed(coins: int)
## Sent when what's equipped changes (the item buttons and the logbook listen).
signal equipped_changed
## Sent when something comes aboard (anything: a pickup, a caught imp, the fish from a haul, a buy at a counter).
## The boat listens and plays the "came aboard" sound (boat.gd). Not sent for the things she sets out with.
signal came_aboard(item: String, count: int)
## Sent when a thing is switched on or off (the sail, sail.gd, listens; so does the logbook).
signal toggled(item: String, on: bool)

const SLOTS := 9   # how many slots the hold has
const ITEMS_FOLDER := "res://Assets/Inventory/items"   # one ItemData .tres per kind of item

## What she sets out with (Enrico: no bombs and no Aeolus Jars, she finds them; 9 traps, to try them).
## (The paddles aren't an item any more, Enrico: they're always fitted, boat's paddles.gd.)
const START_ITEMS := {}   # (Enrico, Nov 2026: no sail any more; the paddles are always fitted)
const START_ON: Array[String] = []     # of those, the ones switched on at the start (the sail is struck)
const START_COINS := 10             # coins in the purse at the start (10 for now, Enrico: to try the floating shop)

var catalogue := {}                 # every kind of item: its name → its ItemData (read from ITEMS_FOLDER)
var items: Array[String] = []   # what's aboard, one entry per thing, in the order it came in
var equipped := ""                  # what's in hand, used with the interaction button ("" = nothing)
var coins := START_COINS            # the purse
var switched_on: Array[String] = [] # the toggle things switched on now (the sail)


func _ready() -> void:
	load_catalogue()
	for item in START_ITEMS:
		add(item, START_ITEMS[item])
	switched_on.assign(START_ON)


## Reads every ItemData file in ITEMS_FOLDER into `catalogue`, by its id. (ResourceLoader.list_directory works
## in the exported game too, where the files are stored under other names.)
func load_catalogue() -> void:
	for file_name in ResourceLoader.list_directory(ITEMS_FOLDER):
		if not file_name.ends_with(".tres"):
			continue
		var data := load(ITEMS_FOLDER + "/" + file_name) as ItemData
		if data and data.id != "":
			catalogue[data.id] = data


## An item's ItemData (null if there's no file for it).
func data(item: String) -> ItemData:
	return catalogue.get(item)


## An item's picture (null if none).
func icon_of(item: String) -> Texture2D:
	var info := data(item)
	return info.icon if info else null


## True if this item piles up in one slot.
func is_stackable(item: String) -> bool:
	var info := data(item)
	return info != null and info.stackable


## True if this item can be equipped.
func is_equippable(item: String) -> bool:
	var info := data(item)
	return info != null and info.equippable


## Puts coins in the purse (or takes them out, with a negative number).
func add_coins(amount: int) -> void:
	coins += amount
	changed.emit()
	coins_changed.emit(coins)


## Puts `count` of `item` in the hold, as many as there's room for. Gives back how many went in.
## A stackable thing already aboard needs no new slot; anything else needs a free one.
func add(item: String, count := 1) -> int:
	var added := 0
	while added < count:
		var needs_slot := not (is_stackable(item) and items.has(item))
		if needs_slot and is_full():
			break
		items.append(item)
		added += 1
	if added > 0:
		# Things coming aboard with equip_on_pickup in their .tres are equipped at once if nothing is in hand, so the
		# interaction button shows them without opening the logbook (something else in hand: they wait in the hold).
		var info := data(item)
		if info and info.equippable and info.equip_on_pickup and equipped == "":
			equip(item)
		changed.emit()
		came_aboard.emit(item, added)
	return added


## Takes one `item` out of the hold. Gives back false if there was none. When the last one of the equipped
## thing goes, nothing is equipped any more.
func remove(item: String) -> bool:
	var index := items.find(item)
	if index == -1:
		return false
	items.remove_at(index)
	changed.emit()
	if is_equipped(item) and not items.has(item):
		unequip(item)
	return true


## How many of `item` are aboard.
func count(item: String) -> int:
	return items.count(item)


## The slots as the logbook shows them, in order: each one a Dictionary {"item": name, "count": how many}.
## A stackable thing is one slot with its whole count; anything else is one slot with count 1.
func slots() -> Array:
	return slots_of(items)


## The same for any list of items (e.g. the hold as it would be after a trade, to see if it all fits).
func slots_of(list: Array[String]) -> Array:
	var result := []
	var stacked := {}                  # stackable item → its slot in `result`
	for item in list:
		if is_stackable(item):
			if stacked.has(item):
				result[stacked[item]]["count"] += 1
				continue
			stacked[item] = result.size()
		result.append({"item": item, "count": 1})
	return result


## True when every slot is taken.
func is_full() -> bool:
	return slots().size() >= SLOTS


## A tap on a thing's slot in the logbook: equips it (whatever was in hand is put back in the hold). Toggle things (the
## sail) are switched on or off instead. Only equippable things that are aboard.
func tap_equip(item: String) -> void:
	var info := data(item)
	if info and info.toggle_on_tap:
		toggle(item)                      # the sail: on or off
		return
	if not is_equippable(item) or count(item) == 0:
		return
	equip(item)


## Puts `item` in hand (whatever was there before is simply no longer equipped).
func equip(item: String) -> void:
	if equipped == item:
		return
	equipped = item
	equipped_changed.emit()


## Puts the NEXT equippable thing of the hold in hand (Enrico: a long press on the interaction button), in the
## logbook's order (its slots, left to right, top to bottom), going round to the first after the last. Nothing in hand:
## the first one. Nothing equippable aboard: nothing changes. Gives back whether something new was put in hand.
func equip_next() -> bool:
	var choices: Array[String] = []            # the equippable things aboard, in the slots' order
	for slot in slots():
		if is_equippable(slot["item"]):
			choices.append(slot["item"])
	if choices.is_empty():
		return false
	var next := 0                              # nothing in hand (or it's not in the list): the first one
	var now := choices.find(equipped)          # where the thing in hand is in the list (-1 = not there)
	if now != -1:
		next = (now + 1) % choices.size()      # the one after it, back to the first after the last
	if choices[next] == equipped:
		return false                           # only one equippable thing aboard, and it's already in hand
	equip(choices[next])
	return true


## Takes `item` off (holding the finger on its slot, or the last one spent).
func unequip(item: String) -> void:
	if equipped == item and item != "":
		equipped = ""
		equipped_changed.emit()


## Is `item` the thing in hand now?
func is_equipped(item: String) -> bool:
	return item != "" and equipped == item


## Switches a toggle thing (the sail) on or off, if it's aboard.
func toggle(item: String) -> void:
	if count(item) == 0:
		return
	if switched_on.has(item):
		switched_on.erase(item)
	else:
		switched_on.append(item)
	toggled.emit(item, switched_on.has(item))


## Is `item` aboard and switched on? (The sail: is it set?)
func is_on(item: String) -> bool:
	return switched_on.has(item) and count(item) > 0

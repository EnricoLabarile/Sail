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
## Equippable things are equipped by tapping their slot in the logbook; tapping it again unequips it. There are two
## equip slots (ItemData.equip_slot): "main", the bomb or the trap, one at a time (equipping one unequips the
## other), kept in `equipped`; and "wind", the Aeolus Jar, kept in `equipped_wind`, with its own button.
## Things with ItemData.equip_on_pickup (the bomb, the jar) are equipped by themselves when they come aboard.
##
## The purse: `coins`, taken in and spent at the stores. It takes no slot.

## Sent whenever something comes in or goes out (the open logbook listens, to draw the pages again).
signal changed
## Sent when what's equipped changes (the bomb button and the logbook listen).
signal equipped_changed
## Sent when something comes aboard (anything: a pickup, a caught imp, the fish from a haul, a buy at a counter).
## The boat listens and plays the "came aboard" sound (boat.gd). Not sent for the things she sets out with.
signal came_aboard(item: String, count: int)

const SLOTS := 9   # how many slots the hold has
const ITEMS_FOLDER := "res://Assets/Inventory/items"   # one ItemData .tres per kind of item

## What she sets out with (Enrico: no bombs and no Aeolus Jars, she finds them; 9 traps, to try them).
const START_ITEMS := {"trap": 9}
const START_COINS := 10             # coins in the purse at the start (10 for now, Enrico: to try the floating shop)

var catalogue := {}                 # every kind of item: its name → its ItemData (read from ITEMS_FOLDER)
var items: Array[String] = []   # what's aboard, one entry per thing, in the order it came in
var equipped := ""                  # the bomb or trap equipped now (the "main" slot; "" = nothing)
var equipped_wind := ""             # the Aeolus Jar, if equipped (the "wind" slot; "" = nothing)
var coins := START_COINS            # the purse


func _ready() -> void:
	load_catalogue()
	for item in START_ITEMS:
		add(item, START_ITEMS[item])


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
		# Bombs and jars coming aboard are equipped at once (Enrico: equip_on_pickup in their .tres), so their
		# button shows without opening the logbook.
		var info := data(item)
		if info and info.equippable and info.equip_on_pickup and not is_equipped(item):
			_set_equipped(info.equip_slot, item)
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
		_set_equipped(slot_of(item), "")
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


## Equips `item` (tapping its slot); if it's already equipped, unequips it. Only equippable things that are
## aboard can be equipped, one at a time.
func toggle_equip(item: String) -> void:
	if not is_equippable(item) or count(item) == 0:
		return
	if is_equipped(item):
		_set_equipped(slot_of(item), "")
	else:
		_set_equipped(slot_of(item), item)


## Is `item` equipped now (in either slot)?
func is_equipped(item: String) -> bool:
	return item != "" and (equipped == item or equipped_wind == item)


## Which equip slot `item` goes in: "main" or "wind" (its ItemData.equip_slot).
func slot_of(item: String) -> String:
	var info := data(item)
	return info.equip_slot if info else "main"


## Puts `item` in the equip slot `slot` ("" = empty it), and tells whoever listens.
func _set_equipped(slot: String, item: String) -> void:
	if slot == "wind":
		equipped_wind = item
	else:
		equipped = item
	equipped_changed.emit()

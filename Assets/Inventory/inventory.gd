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
## EQUIPPING, A and B (Enrico, like Zelda's two item buttons): two equip slots, `equipped_a` and `equipped_b`, each
## with its own button on the screen (A above, B below: Hud.ITEM_BUTTON_TOP). ANY equippable thing (bomb, trap, Aeolus
## Jar, harpoon) can go in either. In the logbook a tap on a thing's slot puts it in A; tapping it again moves it to
## B, and again back to A (tap_equip); holding the finger on it takes it off (unequip). Putting a thing where another
## one is: if the new one was in the other slot they swap places, otherwise the old one is taken off.
## Things with ItemData.equip_on_pickup (bomb, jar, harpoon) are equipped by themselves when they come aboard, in the first
## empty slot (A, then B); with both taken they wait in the hold.
##
## The purse: `coins`, taken in and spent at the stores. It takes no slot.

## Sent whenever something comes in or goes out (the open logbook listens, to draw the pages again).
signal changed
## Sent when what's equipped changes (the item buttons and the logbook listen).
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
var equipped_a := ""                # what's in the A slot (its button above; "" = nothing)
var equipped_b := ""                # what's in the B slot (its button below; "" = nothing)
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
		# Things coming aboard with equip_on_pickup in their .tres are equipped at once, in the first empty slot,
		# so their button shows without opening the logbook (both slots taken: they just wait in the hold).
		var info := data(item)
		if info and info.equippable and info.equip_on_pickup and not is_equipped(item):
			if equipped_a == "":
				_set_slot("a", item)
			elif equipped_b == "":
				_set_slot("b", item)
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


## A tap on a thing's slot in the logbook: not equipped → into A; in A → over to B; in B → back to A.
## Only equippable things that are aboard.
func tap_equip(item: String) -> void:
	if not is_equippable(item) or count(item) == 0:
		return
	if slot_with(item) == "a":
		equip(item, "b")
	else:
		equip(item, "a")


## Puts `item` in `slot` ("a" or "b"). If it was in the other slot, the two swap places; if it wasn't equipped,
## whatever was in `slot` is taken off.
func equip(item: String, slot: String) -> void:
	var was_in := slot_with(item)
	if was_in == slot:
		return
	var other := "b" if slot == "a" else "a"
	var displaced := equipped_a if slot == "a" else equipped_b
	if was_in == other:
		_set_slot(other, displaced)           # swap: the one that was here goes where the item was
	_set_slot(slot, item)


## Takes `item` off (holding the finger on its slot, or the last one spent).
func unequip(item: String) -> void:
	var slot := slot_with(item)
	if slot != "":
		_set_slot(slot, "")


## Is `item` equipped now (in either slot)?
func is_equipped(item: String) -> bool:
	return slot_with(item) != ""


## Which slot `item` is in: "a", "b", or "" (not equipped).
func slot_with(item: String) -> String:
	if item == "":
		return ""
	if equipped_a == item:
		return "a"
	if equipped_b == item:
		return "b"
	return ""


## Puts `item` in `slot` ("" = empty it), and tells whoever listens.
func _set_slot(slot: String, item: String) -> void:
	if slot == "a":
		equipped_a = item
	else:
		equipped_b = item
	equipped_changed.emit()

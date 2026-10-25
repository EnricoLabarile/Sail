extends Node
## THE INVENTORY: the boat's hold, as the prototype's ("Cargo", 9 slots), and what's equipped.
## An autoload (project.godot), so it's there all game long and any script can use it by name, e.g.
## Inventory.add("fish"). (In Unreal: a GameInstance subsystem that keeps the player's items.)
## Only the data lives here: the logbook (Assets/UI/logbook/book.gd) draws it and lets the player tap it.
##
## An item is just its name (a String), e.g. "fish"; its picture for the logbook is in ICONS.
## Most things take a slot each (two fish = two slots). STACKABLE things (bombs, traps) pile up in ONE slot,
## however many there are, with their number drawn on it. When all the slots are taken, nothing new fits.
##
## EQUIPPABLE things (a bomb or a trap) are equipped by tapping their slot in the logbook; one at a time
## (equipping one unequips the other); tapping it again unequips it. `equipped` says which ("" = nothing).

## Sent whenever something comes in or goes out (the open logbook listens, to draw the pages again).
signal changed
## Sent when what's equipped changes (the bomb button and the logbook listen).
signal equipped_changed

const SLOTS := 9   # how many slots the hold has

## Every item's picture in the logbook, by name. A new kind of item: add its name and its PNG here.
const ICONS := {
	"fish": preload("res://Assets/Inventory/icons/fish.png"),
	"bomb": preload("res://Assets/Inventory/icons/bomb.png"),
	"trap": preload("res://Assets/Inventory/icons/trap.png"),
	"imp": preload("res://Assets/Inventory/icons/imp.png"),
}

const STACKABLE := ["bomb", "trap"]     # these pile up in one slot
const EQUIPPABLE := ["bomb", "trap"]    # these can be equipped (tap their slot in the logbook)

## What she sets out with (Enrico: 9 bombs and 9 traps, to try them).
const START_ITEMS := {"bomb": 9, "trap": 9}

var items: Array[String] = []   # what's aboard, one entry per thing, in the order it came in
var equipped := "bomb"              # the item equipped now ("" = nothing)


func _ready() -> void:
	for item in START_ITEMS:
		add(item, START_ITEMS[item])


## Puts `count` of `item` in the hold, as many as there's room for. Gives back how many went in.
## A stackable thing already aboard needs no new slot; anything else needs a free one.
func add(item: String, count := 1) -> int:
	var added := 0
	while added < count:
		var needs_slot := not (STACKABLE.has(item) and items.has(item))
		if needs_slot and is_full():
			break
		items.append(item)
		added += 1
	if added > 0:
		changed.emit()
	return added


## Takes one `item` out of the hold. Gives back false if there was none. When the last one of the equipped
## thing goes, nothing is equipped any more.
func remove(item: String) -> bool:
	var index := items.find(item)
	if index == -1:
		return false
	items.remove_at(index)
	changed.emit()
	if item == equipped and not items.has(item):
		equipped = ""
		equipped_changed.emit()
	return true


## How many of `item` are aboard.
func count(item: String) -> int:
	return items.count(item)


## The slots as the logbook shows them, in order: each one a Dictionary {"item": name, "count": how many}.
## A stackable thing is one slot with its whole count; anything else is one slot with count 1.
func slots() -> Array:
	var result := []
	var stacked := {}                  # stackable item → its slot in `result`
	for item in items:
		if STACKABLE.has(item):
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
	if not EQUIPPABLE.has(item) or count(item) == 0:
		return
	if equipped == item:
		equipped = ""
	else:
		equipped = item
	equipped_changed.emit()

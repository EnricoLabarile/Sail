extends Node
## THE INVENTORY: the boat's hold, as the prototype's ("Cargo", 9 slots).
## An autoload (project.godot), so it's there all game long and any script can use it by name, e.g.
## Inventory.add("fish"). (In Unreal: a GameInstance subsystem that keeps the player's items.)
##
## Each slot holds one thing: a fish takes one slot, two fish take two. An item is just its name (a String),
## e.g. "fish"; its picture for the logbook is in ICONS. When all the slots are full, nothing more fits.
## The logbook (Assets/UI/logbook/book.gd) draws the slots on its top half.

## Sent whenever something comes in or goes out (the open logbook listens, to draw the pages again).
signal changed

const SLOTS := 9   # how many slots the hold has

## Every item's picture in the logbook, by name. A new kind of item: add its name and its PNG here.
const ICONS := {
	"fish": preload("res://Assets/Inventory/icons/fish.png"),
}

var items: Array[String] = []   # what's aboard, one entry a slot, in the order it came in


## Puts `count` of `item` in the hold, as many as there's room for. Gives back how many went in.
func add(item: String, count := 1) -> int:
	var added := 0
	while added < count and not is_full():
		items.append(item)
		added += 1
	if added > 0:
		changed.emit()
	return added


## Takes one `item` out of the hold. Gives back false if there was none.
func remove(item: String) -> bool:
	var slot := items.find(item)
	if slot == -1:
		return false
	items.remove_at(slot)
	changed.emit()
	return true


## How many of `item` are aboard.
func count(item: String) -> int:
	return items.count(item)


## True when every slot is taken.
func is_full() -> bool:
	return items.size() >= SLOTS

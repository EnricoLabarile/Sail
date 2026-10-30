extends Node
## THE HUD'S VISIBILITY (the autoload "Hud", like a GameInstance subsystem in Unreal): decides whether the icons on
## the screen (the wind vane, the hearts, the logbook button, the bomb button) show or not.
##
## Several things want them hidden, each for its own reason, and they mustn't undo each other:
##   "start"  until "Set sail" (start_screen.gd)
##   "anchor" while the boat is at anchor or tied up (boat.gd, Enrico: only the hub then)
##   "talk"   while someone talks (talk_box.gd: only the wind vane and the hearts)
##   "store"  while the store's counter is open (store_counter.gd)
## Each one says "hide these groups for my reason" or "my reason is gone" (set_hidden); an icon shows only when no
## reason at all is hiding it. So a talk ending at anchor doesn't bring the icons back while she's still anchored.
## The icons are found by their groups (Node dock → Groups, like Actor Tags in Unreal): "hidden_at_start" (all four)
## and "hidden_while_talking" (the wind vane and the hearts).

## Where the A and B item buttons sit (Enrico's Zelda-like slots, Inventory.equipped_a / _b): each button (bomb,
## jar, harpoon) moves to the place of the slot its thing is in. Their Control's offset_top, from the bottom of the
## screen (they're 80 px tall): A above, B below it.
const ITEM_BUTTON_TOP := {"a": -252.0, "b": -162.0}

const GROUPS := ["hidden_at_start", "hidden_while_talking"]   # every group of icons this looks after

var reasons := {}   # reason → the groups it hides, e.g. {"anchor": ["hidden_at_start"]}


## Hide (hidden = true) or stop hiding (false) the icons in `groups`, for `reason`.
func set_hidden(reason: String, groups: Array, hidden: bool) -> void:
	if hidden:
		reasons[reason] = groups
	else:
		reasons.erase(reason)
	refresh()


## Puts an item button (its Control) in the place of `slot` ("a" or "b"; "" leaves it where it is).
func place_item_button(button: Control, slot: String) -> void:
	if not ITEM_BUTTON_TOP.has(slot):
		return
	var height := button.offset_bottom - button.offset_top
	button.offset_top = ITEM_BUTTON_TOP[slot]
	button.offset_bottom = button.offset_top + height


## Shows every icon no reason hides, hides the rest.
func refresh() -> void:
	# 1. Which nodes are hidden by at least one reason.
	var hidden_nodes := {}
	for reason in reasons:
		for group in reasons[reason]:
			for node in get_tree().get_nodes_in_group(group):
				hidden_nodes[node] = true
	# 2. Every icon: shown unless it's in that list.
	for group in GROUPS:
		for node in get_tree().get_nodes_in_group(group):
			node.visible = not hidden_nodes.has(node)

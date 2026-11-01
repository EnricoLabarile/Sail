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
## jar, harpoon, hook) moves to the place of the slot its thing is in. The places are two frames in the UI layout
## scene (Assets/UI/ui_layout.tscn: `ItemSlots/SlotA` and `SlotB`, in the groups "item_slot_a" / "item_slot_b"):
## move or resize them there and every button follows. If they can't be found, these offsets (from the bottom-right
## corner) are used: A above, B below it.
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


## Puts an item button (its Control) in the place of `slot` ("a" or "b"; "" leaves it where it is): the same place
## and size as that slot's frame in ui_layout.tscn (see put_in_frame).
func place_item_button(button: Control, slot: String) -> void:
	if not ITEM_BUTTON_TOP.has(slot):
		return
	var frame := get_tree().get_first_node_in_group("item_slot_" + slot) as Control
	if frame:
		put_in_frame(button, frame)
		return
	# No layout scene: the old fixed places.
	var height := button.offset_bottom - button.offset_top
	button.offset_top = ITEM_BUTTON_TOP[slot]
	button.offset_bottom = button.offset_top + height


## Gives `button` the same anchors and offsets as `frame` (so the same place and size on the screen), and its
## CanvasLayer the same offset as the frame's CanvasLayer (if you moved the whole ItemSlots layer, the buttons follow).
## Static, so the buttons can also call it in the editor (where this autoload doesn't run): see their _process.
static func put_in_frame(button: Control, frame: Control) -> void:
	button.anchor_left = frame.anchor_left
	button.anchor_top = frame.anchor_top
	button.anchor_right = frame.anchor_right
	button.anchor_bottom = frame.anchor_bottom
	button.offset_left = frame.offset_left
	button.offset_top = frame.offset_top
	button.offset_right = frame.offset_right
	button.offset_bottom = frame.offset_bottom
	var button_layer := button.get_parent() as CanvasLayer
	var frame_layer := frame.get_parent() as CanvasLayer
	if button_layer and frame_layer:
		button_layer.offset = frame_layer.offset


## In the editor only (the buttons call it every editor frame): the button sits in its preview slot's frame, so moving
## SlotA / SlotB in ui_layout.tscn shows at once where the buttons will be. (No frame, e.g. in the button's own scene:
## it stays where it is.)
static func show_in_frame_in_editor(button: Control, slot: String) -> void:
	if not button.is_inside_tree():
		return
	var frame := button.get_tree().get_first_node_in_group("item_slot_" + slot) as Control
	if frame:
		put_in_frame(button, frame)


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

extends Control
## THE HOOK'S ACTION (Enrico, Nov 2026: no button of its own any more). When the hook is the thing in hand
## (Inventory.equipped), a tap on the interaction button (Assets/UI/interaction_button) calls `use()`:
##   - holding nothing: it GRABS the nearest thing that can be towed (the group "towable": a barrel, a key, the
##     castaway's raft, a lever…) if the boat is close enough to it; a rope goes from her stern to it;
##   - holding something: it LETS IT GO.
## While she holds something `is_active()` is true: the interaction button is drawn inked.
## Any real damage to the boat makes her let go (boat.gd's signal `hurt`); so does taking the hook off.
## The hook isn't spent (not like the bombs or the jars).
## The same few things as every item action: ITEM, ICON, use(), can_use(), cooldown_share(), is_active().
## This node stays in ui_layout.tscn only to hold its state; it's never drawn.
##
## THE TOWABLE INTERFACE (what a thing in the group "towable" must have, so the hook can use it):
##   can_be_towed() -> bool      may it be grabbed now? (not broken, not already held, not busy)
##   tow_reach() -> float        how close (metres) her middle must be to its middle to grab it
##   start_tow(boat)             grabbed: the rope goes on (it moves itself / pulls from now on)
##   stop_tow()                  let go
##   is_towed() -> bool          still held? (it can let go by itself: a lever pulled all the way, a barrel broken)

const ITEM := "hook"
const ICON := preload("res://Assets/Inventory/icons/hook.png")
## Enrico's two pictures for the interaction button (Nov 2026): the empty hand when something is in reach to grab, the
## hand holding a ball while she's towing something. (Nothing in reach: the hook's own icon.)
## The empty hand is a FLIPBOOK (Enrico, Nov 2026): 16 frames of 32 x 32 in a 4 x 4 grid, played by the interaction
## button (current_icon_frames tells it the grid). The still picture t_interaction_grabbable.png stays in the folder.
const GRABBABLE_ICON := preload("res://Assets/UI/interaction_button/t_interaction_grabbable_flipbook.png")
const GRABBABLE_FRAMES := Vector2i(4, 4)    # columns x rows of its grid
const GRABBING_ICON := preload("res://Assets/UI/interaction_button/t_interaction_grabbing.png")

## Seconds between two looks for the nearest thing in reach (for the button's picture only; a tap always looks again).
@export var look_every := 0.2

var towed: Node3D = null             # what she's holding now (null = nothing)
var in_reach: Node3D = null          # the nearest thing in reach at the last look (for the picture)
var look_left := 0.0                 # seconds to the next look


func _ready() -> void:
	visible = false                      # never drawn: the interaction button shows it
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("item_actions")         # so the interaction button finds it
	Inventory.equipped_changed.connect(_on_equipped_changed)
	_listen_to_boat.call_deferred()      # once the level is all there (the boat is found by its group)


## Enrico: whenever the boat really takes damage (anything: a fireball, a spike, a bomb, boiling water…), the hook
## lets go of what it holds. The boat sends `hurt` for that (boat.gd take_damage; a bump on the shore doesn't).
func _listen_to_boat() -> void:
	var boat := Boat.current
	if boat:
		boat.hurt.connect(let_go)


## The hook taken off while holding something: it's let go.
func _on_equipped_changed() -> void:
	if not Inventory.is_equipped(ITEM):
		let_go()


func _process(dt: float) -> void:
	# The thing let go by itself (a lever pulled all the way, a barrel blown up, she sank): forget it.
	if towed != null and not is_holding():
		towed = null
	# The nearest thing in reach, for the button's picture: looked for a few times a second (it used to be every
	# frame), and only while the hook is in hand.
	look_left -= dt
	if look_left <= 0.0:
		look_left = look_every
		in_reach = nearest_in_reach() if Inventory.is_equipped(ITEM) else null


## The hook can always be tapped (to grab or to let go).
func can_use() -> bool:
	return true


func cooldown_share() -> float:
	return 0.0


## True while she holds something: the interaction button is drawn inked.
func is_active() -> bool:
	return is_holding()


## A tap: let go if holding something, else grab the nearest thing in reach.
func use() -> void:
	if is_holding():
		let_go()
	else:
		grab()


## Is she holding something now?
func is_holding() -> bool:
	return is_instance_valid(towed) and towed.is_towed()


## The picture the interaction button shows for the hook (it asks every frame): holding something → the full hand;
## something in reach to grab (at the last look) → the empty hand; else the hook.
func current_icon() -> Texture2D:
	if is_holding():
		return GRABBING_ICON
	if is_instance_valid(in_reach):
		return GRABBABLE_ICON
	return ICON


## The grid of current_icon()'s picture, if it's a flipbook (columns x rows); (1, 1) = a still picture.
func current_icon_frames() -> Vector2i:
	if not is_holding() and is_instance_valid(in_reach):
		return GRABBABLE_FRAMES
	return Vector2i(1, 1)


## Grabs the nearest towable thing whose reach her middle is in. Nothing in reach: nothing happens.
func grab() -> void:
	var boat := Boat.current as Node3D
	if boat == null or boat.sinking or boat.emerging:
		return
	var nearest := nearest_in_reach()
	if nearest == null:
		return
	towed = nearest
	towed.start_tow(boat)
	Sfx.lever_hook()                   # the low click of hooking on (the lever's)


## The nearest towable thing whose reach her middle is in, or null (nothing to grab here).
func nearest_in_reach() -> Node3D:
	var boat := Boat.current as Node3D
	if boat == null:
		return null
	var nearest: Node3D = null
	var nearest_distance := INF
	for thing in get_tree().get_nodes_in_group("towable"):
		if not thing.can_be_towed():
			continue
		var off: Vector3 = thing.global_position - boat.global_position
		off.y = 0.0
		var distance := off.length()
		if distance <= thing.tow_reach() and distance < nearest_distance:
			nearest = thing
			nearest_distance = distance
	return nearest


## Lets go of what she's holding (if anything).
func let_go() -> void:
	if is_holding():
		towed.stop_tow()
	towed = null

@tool
extends Control
## THE HOOK BUTTON (bottom right, in the place of the slot the hook is equipped in: A above, B below,
## Hud.place_item_button). A round paper button with the hook.
## Enrico: the hook is an active thing now. A tap GRABS the nearest thing that can be towed (the group "towable":
## a barrel, a lever) if the boat is close enough to it; a rope goes from her stern to it. Another tap LETS IT GO.
## While she holds something the button is drawn inked (ink disc, paper hook), so it's clear she's hooked to it.
## Nothing in reach: the tap only flashes and clicks, as every button.
## The hook isn't spent (not like the bombs or the harpoon): it shows while the hook is equipped.
## Drawn with code under the dither (CanvasLayer 95, like the wheel), so it's 1-bit.
## @tool: drawn in the editor too (always shown there), so you can place and size it; there it only draws.
## (In Unreal: a UMG button whose OnClicked attaches a cable component from the pawn to the nearest actor with a tag.)
##
## THE TOWABLE INTERFACE (what a thing in the group "towable" must have, so this button can use it):
##   can_be_towed() -> bool      may it be grabbed now? (not broken, not already held, not busy)
##   tow_reach() -> float        how close (metres) her middle must be to its middle to grab it
##   start_tow(boat)             grabbed: the rope goes on (it moves itself / pulls from now on)
##   stop_tow()                  let go
##   is_towed() -> bool          still held? (it can let go by itself: a lever pulled all the way, a barrel broken)

const HOOK := "hook"                 # the item's id (Assets/Inventory/items/hook.tres)
const ICON := preload("res://Assets/Inventory/icons/hook.png")
const HUD := preload("res://Assets/UI/hud.gd")   # the Hud autoload's script: its static put_in_frame works in the editor too
const PAPER := Color("ebe7dc")
const INK := Color("1b1a17")

@export var press_flash := 0.12      # a press turns the button black for this long (s), with a click (Enrico: every button)
## In the editor only: which slot frame (SlotA / SlotB in ui_layout.tscn) this button is shown in, to preview the
## layout. In the game it goes where its thing is equipped.
@export_enum("a", "b") var editor_slot := "b"

var press_flash_left := 0.0          # seconds it stays black after a press
var towed: Node3D = null             # what she's holding now (null = nothing)
var icon_paper: Texture2D = ICON     # the same hook drawn in paper (for the inked look), made in _ready


func _ready() -> void:
	icon_paper = paper_copy(ICON)
	if Engine.is_editor_hint():
		return
	Inventory.equipped_changed.connect(_update_shown)   # equipped or taken off
	Inventory.changed.connect(_update_shown)
	_update_shown()
	_listen_to_boat.call_deferred()      # once the level is all there (the boat is found by its group)


## Enrico: whenever the boat really takes damage (anything: a fireball, a spike, a bomb, boiling water…), the hook
## lets go of what it holds. The boat sends `hurt` for that (boat.gd take_damage; a bump on the shore doesn't).
func _listen_to_boat() -> void:
	var boat := get_tree().get_first_node_in_group("player_boat")
	if boat:
		boat.hurt.connect(let_go)


## Shown only while the hook is equipped. Taken off while holding something: it's let go.
func _update_shown() -> void:
	visible = Inventory.is_equipped(HOOK)
	Hud.place_item_button(self, Inventory.slot_with(HOOK))
	if not Inventory.is_equipped(HOOK):
		let_go()


func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventScreenTouch and event.pressed:
		# Every press: a low click and the button black for a moment (Enrico: every button).
		press_flash_left = press_flash
		Sfx.button_press()
		queue_redraw()
		if is_holding():
			let_go()                  # second tap: let go
		else:
			grab()                    # first tap: grab the nearest thing in reach
		accept_event()                # the tap stops here (it doesn't also reach the wheel or the sea)


func _process(dt: float) -> void:
	if Engine.is_editor_hint():
		HUD.show_in_frame_in_editor(self, editor_slot)   # follows its slot's frame while you move it
		return
	if press_flash_left > 0.0:
		press_flash_left = maxf(0.0, press_flash_left - dt)
		queue_redraw()
	# The thing let go by itself (a lever pulled all the way, a barrel blown up, she sank): back to the plain look.
	if towed != null and not is_holding():
		towed = null
		queue_redraw()


## Is she holding something now?
func is_holding() -> bool:
	return is_instance_valid(towed) and towed.is_towed()


## Grabs the nearest towable thing whose reach her middle is in. Nothing in reach: nothing happens.
func grab() -> void:
	var boat := get_tree().get_first_node_in_group("player_boat") as Node3D
	if boat == null or boat.sinking or boat.emerging:
		return
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
	if nearest == null:
		return
	towed = nearest
	towed.start_tow(boat)
	Sfx.lever_hook()                   # the low click of hooking on (the lever's)
	queue_redraw()


## Lets go of what she's holding (if anything).
func let_go() -> void:
	if is_holding():
		towed.stop_tow()
	towed = null
	queue_redraw()


## A copy of a picture with every pixel paper-coloured (its see-through parts kept): the ink hook becomes a paper
## hook, to draw on the ink disc. (Done once: an Image is the picture's pixels in memory, like a Texture's source.)
func paper_copy(picture: Texture2D) -> Texture2D:
	var image := picture.get_image()
	if image == null:
		return picture
	image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var alpha := image.get_pixel(x, y).a
			image.set_pixel(x, y, Color(PAPER, alpha))
	return ImageTexture.create_from_image(image)


## A paper disc with an ink rim and the hook's picture. Holding something: inked (an ink disc, the hook in paper).
func _draw() -> void:
	var middle := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 3.0
	var holding := false if Engine.is_editor_hint() else is_holding()
	draw_circle(middle + Vector2(3, 3), radius, INK)           # a hard shadow, as the other buttons'
	draw_circle(middle, radius, INK if holding else PAPER)
	draw_arc(middle, radius, 0.0, TAU, 48, INK, 3.0)
	var icon_size := ICON.get_size() * (radius * 1.1 / ICON.get_size().y)
	var icon_rect := Rect2(middle - icon_size * 0.5, icon_size)
	draw_texture_rect(icon_paper if holding else ICON, icon_rect, false)
	# Just pressed: the whole button black (as the wheel's hub does).
	if press_flash_left > 0.0:
		draw_circle(middle, radius, INK)

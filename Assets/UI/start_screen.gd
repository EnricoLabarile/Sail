extends CanvasLayer
## THE START SCREEN: a card shown before the game starts, saying which build this is
## (its number and when it was built), so on the phone you can tell you're playing the latest one.
##
## There's no "start" button (Enrico): the boat starts at anchor, and weighing the anchor (holding the wheel's hub,
## as always) is what starts the game. Until then every control but the hub is hidden: everything in the group
## "hidden_at_start" (the wind vane, the hearts, the logbook button, the bomb button). To hide something else at
## the start too, add its node to that group (Node dock → Groups; like an Actor Tag in Unreal).
## The game isn't paused meanwhile: she simply waits at anchor while the clouds and gulls go by.
##
## THE LEVELS (Enrico): under the build, a button for every level in LEVELS_FOLDER (the Overworld, the gyms…).
## The list is read from the folder every time the card shows, so a new level saved there gets its button by
## itself. A tap loads that level (in Unreal: Open Level). The one being played is drawn inked, like a pressed key.
## (The autoloads stay as they were: the hold, the fog's seen sea and the wind carry over to the new level.)

const BuildInfo := preload("res://Assets/UI/build_info.gd")   # the build's number and time
const LEVELS_FOLDER := "res://Assets/Scenes"                  # where the levels are
const FIRST_LEVEL := "Overworld"                              # this one comes first in the list, the others A to Z

const PAPER := Color("ebe7dc")
const INK := Color("1b1a17")

@onready var build_label: Label = $Card/Margin/Lines/Build
@onready var levels_box: VBoxContainer = $Card/Margin/Lines/Levels


func _ready() -> void:
	build_label.text = "Build %s\n%s" % [BuildInfo.NUMBER, BuildInfo.STARTED]
	add_level_buttons()
	_show_controls.call_deferred(false)        # after every node is ready (and in its group): hide the controls
	_listen_to_boat.call_deferred()


## Waits for the boat to weigh anchor for the first time (boat.gd sends anchor_weighed).
func _listen_to_boat() -> void:
	var boat := get_tree().get_first_node_in_group("player_boat")
	if boat:
		boat.anchor_weighed.connect(_on_start, CONNECT_ONE_SHOT)   # ONE_SHOT: only the first time


## The anchor came up: the card goes away and the controls come back.
func _on_start() -> void:
	hide()
	_show_controls(true)


## Hides (or shows) every node in the group "hidden_at_start".
func _show_controls(show: bool) -> void:
	for node in get_tree().get_nodes_in_group("hidden_at_start"):
		node.visible = show


# ---------- The levels ----------

## The names of the levels in LEVELS_FOLDER (without ".tscn"): the Overworld first, then the others A to Z.
func level_names() -> Array[String]:
	var names: Array[String] = []
	# ResourceLoader.list_directory works in the editor AND in the exported game (where the scenes are stored
	# under other names: it gives back the names you see in the editor).
	for file_name in ResourceLoader.list_directory(LEVELS_FOLDER):
		if file_name.ends_with(".tscn"):
			names.append(file_name.get_basename())   # "Gym_Imp.tscn" → "Gym_Imp"
	names.sort()
	if names.has(FIRST_LEVEL):
		names.erase(FIRST_LEVEL)
		names.insert(0, FIRST_LEVEL)
	return names


## One button per level, inside the Levels box of the card.
func add_level_buttons() -> void:
	var playing := get_tree().current_scene.scene_file_path   # the level open now
	for level in level_names():
		var path := LEVELS_FOLDER + "/" + level + ".tscn"
		var button := Button.new()
		button.text = level.replace("_", " ")                  # "Gym_Imp" → "Gym Imp"
		button.focus_mode = Control.FOCUS_NONE                 # no keyboard focus ring (Space works the anchor)
		style_button(button, path == playing)
		button.pressed.connect(load_level.bind(path))          # bind: the button hands its own path to load_level
		levels_box.add_child(button)


## Ink on paper like the rest of the card; the level being played is the other way round (paper on ink).
func style_button(button: Button, is_playing: bool) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = INK if is_playing else PAPER
	box.border_color = INK
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	box.set_content_margin_all(6)
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, box)
	var text_colour := PAPER if is_playing else INK
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, text_colour)
	button.add_theme_font_size_override("font_size", 15)


## Loads that level, in place of this one.
func load_level(path: String) -> void:
	get_tree().change_scene_to_file(path)

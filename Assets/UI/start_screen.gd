extends CanvasLayer
## THE START SCREEN: a card shown before the game starts, saying which build this is
## (its number and when it was built), so on the phone you can tell you're playing the latest one.
##
## HOW IT STARTS (Enrico): the screen is BLACK behind the card until "Set sail" is pressed, so nothing of the level
## shows, not even a level being switched. Meanwhile the game is paused (get_tree().paused: the boat, the wind and
## the imps wait; she comes up out of the water only once it goes). "Set sail" takes the card and the black away,
## the controls come back and the game goes; the boat is still at anchor: holding the wheel's hub weighs it, as always.
## This node keeps working while paused (process_mode = Always, set in start_screen.tscn), otherwise its own
## buttons would be paused too. Until "Set sail" every node in the group "hidden_at_start" is hidden (the wind
## vane, the hearts, the logbook button, the bomb button); to hide something else too, add its node to that group
## (Node dock → Groups; like an Actor Tag in Unreal).
##
## THE LEVELS (Enrico): under the build, a button for every level in LEVELS_FOLDER (the Overworld, the gyms…).
## The list is read from the folder every time the card shows, so a new level saved there gets its button by
## itself. The level that's loaded now is drawn inked, like a pressed key. A tap on another one loads it at once
## (in Unreal: Open Level), behind the black: the new level comes up with this same card, its button inked, and
## waits for "Set sail" too. (The autoloads stay as they were: the hold, the fog's seen sea and the wind carry over.)
##
## THE BLACK (the "curtain"): a black sheet over the whole game, in its own CanvasLayer (CURTAIN_LAYER) just under
## the card. It fades away over curtain_fade when "Set sail" is pressed. (In Unreal: a fade from black on the
## camera manager when the player presses Play.)

const BuildInfo := preload("res://Assets/UI/build_info.gd")   # the build's number and time
const LEVELS_FOLDER := "res://Assets/Scenes"                  # where the levels are
const FIRST_LEVEL := "Overworld"                              # this one comes first in the list, the others A to Z

const PAPER := Color("ebe7dc")
const INK := Color("1b1a17")
const CURTAIN_LAYER := 129                                    # above the whole game, just under the card (130)

@export var curtain_fade := 0.3     # seconds the black takes to fade away after "Set sail"

var curtain: ColorRect              # the black sheet (made in code, in its own layer above everything)

@onready var build_label: Label = $Card/Margin/Lines/Build
@onready var levels_box: VBoxContainer = $Card/Margin/Lines/Levels
@onready var start_button: Button = $Card/Margin/Lines/Start


func _ready() -> void:
	make_curtain()                             # black from the very first frame
	build_label.text = "Build %s\n%s" % [BuildInfo.NUMBER, BuildInfo.STARTED]
	add_level_buttons()
	style_button(start_button, true)           # "Set sail" inked, so it stands out from the level list
	start_button.pressed.connect(_on_start)    # when it's pressed, call _on_start
	get_tree().paused = true                   # everything waits for "Set sail"
	_show_controls.call_deferred(false)        # after every node is ready (and in its group): hide the controls


## "Set sail": the card goes, the black fades away, the controls come back and the game goes (still at anchor).
func _on_start() -> void:
	$Card.hide()
	_show_controls(true)
	get_tree().paused = false
	lift_curtain()


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
		if path != playing:                                    # the one loaded now does nothing: it's already there
			button.pressed.connect(load_level.bind(path))      # bind: the button hands its own path to load_level
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


## Loads that level, in place of this one. The screen is already black behind the card, so the switch doesn't
## show: the new level starts with its own card on black, waiting for "Set sail".
## (The paused state carries over; the new level's card pauses it again anyway.)
func load_level(path: String) -> void:
	get_tree().change_scene_to_file(path)


# ---------- The black curtain ----------

## The black sheet over the whole screen, in its own layer above everything. It also catches taps while it shows
## (mouse_filter STOP), so nothing is pressed through the black.
func make_curtain() -> void:
	var layer := CanvasLayer.new()
	layer.layer = CURTAIN_LAYER
	add_child(layer)
	curtain = ColorRect.new()
	curtain.color = Color.BLACK
	curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(curtain)


## "Set sail" was pressed: fade the black away (a Tween on its see-through-ness, like a Timeline in Blueprints),
## then hide the whole start screen.
func lift_curtain() -> void:
	var fade := create_tween()
	fade.tween_property(curtain, "modulate:a", 0.0, curtain_fade)
	fade.tween_callback(func():
		curtain.visible = false
		hide())

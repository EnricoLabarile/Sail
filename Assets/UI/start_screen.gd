extends CanvasLayer
## THE START SCREEN: a card shown before the game starts, saying which build this is
## (its number and when it was built), so on the phone you can tell you're playing the latest one.
## A tap on "Set sail" hides it and the game starts.
##
## While it's up, the game is paused (get_tree().paused): the boat and the wind wait.
## This node keeps working while paused (process_mode = Always, set in start_screen.tscn),
## otherwise its own button would be paused too.

const BuildInfo := preload("res://Assets/UI/build_info.gd")   # the build's number and time

@onready var build_label: Label = $Card/Margin/Lines/Build
@onready var start_button: Button = $Card/Margin/Lines/Start


func _ready() -> void:
	build_label.text = "Build %s\n%s" % [BuildInfo.NUMBER, BuildInfo.STARTED]
	start_button.pressed.connect(_on_start)    # when the button is pressed, call _on_start
	get_tree().paused = true                   # hold the game until "Set sail"


func _on_start() -> void:
	get_tree().paused = false                  # the game goes
	hide()                                     # the card goes away

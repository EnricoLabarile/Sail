extends CanvasLayer
## THE START SCREEN: a card shown before the game starts, saying which build this is
## (its number and when it was built), so on the phone you can tell you're playing the latest one.
##
## There's no button (Enrico): the boat starts at anchor, and weighing the anchor (holding the wheel's hub, as
## always) is what starts the game. Until then every control but the hub is hidden: everything in the group
## "hidden_at_start" (the wind vane, the hearts, the logbook button, the bomb button). To hide something else at
## the start too, add its node to that group (Node dock → Groups; like an Actor Tag in Unreal).
## The game isn't paused meanwhile: she simply waits at anchor while the clouds and gulls go by.

const BuildInfo := preload("res://Assets/UI/build_info.gd")   # the build's number and time

@onready var build_label: Label = $Card/Margin/Lines/Build


func _ready() -> void:
	build_label.text = "Build %s\n%s" % [BuildInfo.NUMBER, BuildInfo.STARTED]
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

extends CanvasLayer
## THE GAME OVER CARD: shown when the boat has sunk (0 hearts, see boat.gd). The game is paused under it;
## a tap on "Set sail again" brings her back home with the hull whole (boat.respawn()) and the game goes on.
## Made like the start screen (start_screen.tscn): a card in the middle, crisp, over everything.
## This node keeps working while paused (process_mode = Always, set in game_over.tscn), otherwise its own
## button would be paused too. (In Unreal: a "You died" widget that the pawn's event dispatcher opens.)

@onready var again_button: Button = $Card/Margin/Lines/Again

func _ready() -> void:
	hide()                                      # not there until she sinks
	again_button.pressed.connect(_on_again)     # when the button is pressed, call _on_again
	_listen_to_boat.call_deferred()             # deferred: after the boat's own _ready (Boat.current is set there)


## Listens for her sinking, once (it used to look for her every frame).
func _listen_to_boat() -> void:
	if Boat.current:
		Boat.current.sank.connect(_on_sank)


## She's gone under: hold the game and show the card.
func _on_sank() -> void:
	get_tree().paused = true
	show()


## "Set sail again": back home, whole, and the game goes on.
func _on_again() -> void:
	Boat.current.respawn()
	get_tree().paused = false
	hide()

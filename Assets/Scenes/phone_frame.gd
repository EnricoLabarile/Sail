extends Node
## Autoload (like a GameInstance subsystem in Unreal): on a screen wider than a phone held upright
## (a PC window, a desktop browser) the game is shown in a phone-shaped frame, 360×800 scaled up
## evenly with bars at the sides, so it looks just as on the phone. On a phone it fills the screen
## as before (stretch aspect "expand": a taller phone just sees more sea).

const WIDE := 0.8   # width/height above which a screen counts as "not a phone" (4:5, like the HTML prototype)

func _ready() -> void:
	get_tree().root.size_changed.connect(_fit)
	_fit()

func _fit() -> void:
	var s := Vector2(get_tree().root.size)
	var wide := s.x / maxf(s.y, 1.0) > WIDE
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP if wide else Window.CONTENT_SCALE_ASPECT_EXPAND

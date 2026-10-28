extends Node
## Autoload (like a GameInstance subsystem in Unreal): on a screen wider than a phone held upright
## (a PC window, a desktop browser) the game is shown in a phone-shaped frame, 360×800 scaled up
## evenly with bars at the sides, so it looks just as on the phone. On a phone it fills the screen
## as before (stretch aspect "expand": a taller phone just sees more sea).
##
## THE GAME IS ALWAYS UPRIGHT (Enrico: portrait only, no turning with the phone). Two things for that:
##   1. In the browser on a phone, it asks the phone to lock the screen upright (screen.orientation.lock). Browsers
##      allow that only in some cases (full screen, or added to the home screen); elsewhere it's simply refused, and
##      nothing breaks.
##   2. Coming back from the background (Enrico: the screen was sometimes deformed after switching to another app
##      and back): the browser may have changed the page's size while the game was asleep without the game noticing,
##      so on coming back it asks the browser to send its "resize" again, a few times as the page settles
##      (0.1, 0.5 and 1 s later), and the game fits itself to the real size.

const WIDE := 0.8   # width/height above which a screen counts as "not a phone" (4:5, like the HTML prototype)
const REFIT_AFTER := [0.1, 0.4, 0.5]   # seconds between the re-fits after coming back (0.1, 0.5 and 1 s in all)

func _ready() -> void:
	get_tree().root.size_changed.connect(_fit)
	_fit()
	lock_upright()

func _fit() -> void:
	var s := Vector2(get_tree().root.size)
	var wide := s.x / maxf(s.y, 1.0) > WIDE
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP if wide else Window.CONTENT_SCALE_ASPECT_EXPAND


## Godot tells every node when the game comes back to the front (a notification, like Unreal's "application has
## reactivated" delegate).
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		refit_after_return()


## Back from the background: ask the browser for its size again a few times while the page settles, and fit to it.
func refit_after_return() -> void:
	lock_upright()
	for wait in REFIT_AFTER:
		# A timer that runs even while the game is paused (process_always), like a Delay node that ignores pause.
		await get_tree().create_timer(wait, true, false, true).timeout
		if OS.has_feature("web"):
			# The browser sends its "resize" again: Godot then measures the page and resizes the game (size_changed).
			JavaScriptBridge.eval("window.dispatchEvent(new Event('resize'));", true)
		_fit()


## In the browser, ask to keep the screen upright. Refused quietly where the browser doesn't allow it.
func lock_upright() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
		try {
			if (screen.orientation && screen.orientation.lock) {
				screen.orientation.lock('portrait').catch(function () {});
			}
		} catch (e) {}
	""", true)

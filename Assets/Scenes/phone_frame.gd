extends Node
## Autoload (like a GameInstance subsystem in Unreal): on a screen wider than a phone held upright
## (a PC window, a desktop browser) the game is shown in a phone-shaped frame, 360×800 scaled up
## evenly with bars at the sides, so it looks just as on the phone. On a phone it fills the screen
## (stretch aspect "expand": a taller phone just sees more sea).
##
## THE GAME IS ALWAYS UPRIGHT (Enrico: portrait only).
##   1. ON A PHONE THE FRAME IS NEVER USED (Enrico: after turning the phone sideways and back, the game stayed squeezed
##      between two black bars). The frame with the bars is for the PC only; on a phone (a touch screen, or a phone
##      browser) the game always fills the screen, whatever shape the browser says the page is for a moment while the
##      phone turns. So the bars can't get stuck there any more.
##   2. In the browser, after the phone turns or the game comes back from the background, the browser is asked to
##      send its "resize" again a few times while the page settles (0.1, 0.5 and 1 s later): Godot measures the page
##      every frame, and this makes sure it sees the final size, not one from the middle of the turn.
##   3. It asks the browser to lock the screen upright (screen.orientation.lock). Browsers allow that ONLY in full
##      screen (or added to the home screen as an app); in a normal tab they refuse, so the page still turns: that
##      can't be stopped from inside a web page.

const WIDE := 0.8   # width/height above which a screen counts as "not a phone" (4:5, like the HTML prototype)

func _ready() -> void:
	get_tree().root.size_changed.connect(_fit)
	_fit()
	lock_upright()
	listen_for_turns()

func _fit() -> void:
	var root := get_tree().root
	if is_phone():
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND   # a phone: always fill the screen
		return
	var s := Vector2(root.size)
	var wide := s.x / maxf(s.y, 1.0) > WIDE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP if wide else Window.CONTENT_SCALE_ASPECT_EXPAND


## True on a phone or tablet: an Android / iPhone app, a phone's browser (Godot's "web_android" / "web_ios" tags), or
## any screen that can be touched. (A PC with a touch screen counts too: it then fills its window, no frame.)
func is_phone() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") \
			or DisplayServer.is_touchscreen_available()


## Godot tells every node when the game comes back to the front (a notification, like Unreal's "application has
## reactivated" delegate): ask for the size again, as after a turn.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		lock_upright()
		if OS.has_feature("web"):
			JavaScriptBridge.eval("window.vvAskSizeAgain && window.vvAskSizeAgain();", true)
		_fit()


## In the browser: whenever the phone turns (or the page is shown again), send "resize" again 0.1, 0.5 and 1 s
## later, so the final size reaches the game. Set up once (a little JavaScript added to the page, like a Blueprint
## binding to a browser event). Its own resizes are "not trusted" events, so they don't set it off again.
func listen_for_turns() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
		if (!window.vvAskSizeAgain) {
			window.vvAskSizeAgain = function () {
				[100, 500, 1000].forEach(function (ms) {
					setTimeout(function () { window.dispatchEvent(new Event('resize')); }, ms);
				});
			};
			window.addEventListener('orientationchange', window.vvAskSizeAgain);
			if (screen.orientation && screen.orientation.addEventListener) {
				screen.orientation.addEventListener('change', window.vvAskSizeAgain);
			}
			window.addEventListener('resize', function (e) { if (e.isTrusted) window.vvAskSizeAgain(); });
			document.addEventListener('visibilitychange', window.vvAskSizeAgain);
		}
	""", true)


## In the browser, ask to keep the screen upright. Refused quietly where the browser doesn't allow it (a normal tab).
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

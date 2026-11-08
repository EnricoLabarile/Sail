extends Node
## THE GAME VIEW: draws the dithered part of the game (the 3D world and the controls under the dither) at the
## game's own resolution, then shows it blown up to the screen, each game pixel a block of real pixels.
##
## Why: the dither draws one dot per game pixel, about 3 x 3 real pixels on a phone. Drawing everything at the
## phone's full resolution (about 1080 x 2340) and then keeping one pixel in nine was mostly wasted work. Here
## the world, the wheel, the logbook's button and the dither itself are drawn in a SubViewport about 360 pixels
## wide (in Unreal: a Scene Capture into a small Render Target), and a TextureRect stretches that picture over
## the screen without smoothing (nearest), so the dots stay sharp.
## What stays at full resolution, crisp, on top: the open logbook, the wind vane, the start screen.
##
## How: when the game starts (after every node is ready), the nodes listed in DITHERED (and the logbook's
## button layer) are moved into the SubViewport, wherever they are in the level (found by name). In the editor the scene looks as always.
## Taps and drags on the picture are passed on to the SubViewport, scaled to its pixels (push_input).

const DESIGN_WIDTH := 360.0   # the game's width in the project settings: the controls are laid out for this width

## How many dots across the screen: the game view is drawn about this many pixels wide, one dither dot a pixel.
## 360 = a dot is 3 x 3 real pixels on a phone 1080 wide; 540 = 2 x 2 (a finer grain, about 2.25 times the
## work); 1080 = 1 x 1 (the finest, 9 times the work). The controls (wheel, sling, logbook button) keep their
## size on the screen whatever this is: only the grain changes. (On a narrower screen it can't go finer than
## a dot per real pixel.) It can be changed WHILE THE GAME RUNS (Enrico, Nov 2026: to compare resolutions): from the
## editor's Remote tree (select GameView, change it in the Inspector) or with the "Dots" button of the performance
## overlay; the view is resized at once (the setter calls _fit). A dot is always a whole number of real pixels, so
## on a phone 1080 wide only 1080 / 1, 2, 3, 4… really differ (1080, 540, 360, 270, 216…): the overlay shows the
## real size ("game view … (xN)").
@export_range(90, 1080, 1) var dots_across := 540:   # Enrico, Nov 2026: 540 by default (was 360)
	set(value):
		dots_across = value
		if view != null:
			_fit()
## TILT-SHIFT (Enrico, Nov 2026, a test): the top and bottom of the world blurred, so the sea looks like a little
## model. Only the world: the controls and the logbook's button stay sharp (Assets/Post_Process/tilt_shift/).
## Off for now (Enrico, Nov 2026): it cost about a quarter of the frame on the phone and barely shows after the dither.
@export var tilt_shift_on := false:
	set(value):
		tilt_shift_on = value
		_update_tilt_shift()
@export_range(0.0, 0.5) var tilt_top := 0.35:     # share of the screen's height blurred from the top (0 = none)
	set(value):
		tilt_top = value
		_update_tilt_shift()
@export_range(0.0, 0.5) var tilt_bottom := 0.4:   # the same, from the bottom
	set(value):
		tilt_bottom = value
		_update_tilt_shift()
@export_range(0.0, 10.0) var tilt_blur := 6.0:    # how far the blur reaches at the very edge (game-view pixels)
	set(value):
		tilt_blur = value
		_update_tilt_shift()

const TILT_SHIFT_SHADER := preload("res://Assets/Post_Process/tilt_shift/tilt_shift.gdshader")
const TILT_SHIFT_LAYER := 90   # over the world, under the controls (95) and the dither (100)

const DITHERED := ["Sea", "Coast", "Clouds", "WindLines", "Gulls", "Boat", "Dither", "Helm", "BombButton", "JarButton", "HookButton", "Crank"]   # nodes of the level moved into the view (by name, anywhere in it)

var view: SubViewport         # where the dithered part of the game is drawn
var screen: TextureRect       # the view's picture, stretched over the screen
var dot_scale := 1            # real pixels per game pixel (3 on a phone about 1080 wide, 1 on a 360 x 800 window)
var tilt_shift: ColorRect     # the tilt-shift's full-screen rectangle inside the view (null until the game starts)


func _ready() -> void:
	_build.call_deferred()        # after every node of the scene is ready


func _build() -> void:
	# 1. The SubViewport. It uses the same 3D world as the rest of the game (it doesn't make its own).
	view = SubViewport.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)

	# 2. Move the dithered nodes into it: the world, the dither and the controls under it. They're looked for by
	#    name anywhere in the level (owner = the level's root), so they can sit inside "folder" nodes (Core, UI…).
	var scene := owner
	for node_name in DITHERED:
		var node := scene.find_child(node_name, true, false)
		if node:
			node.reparent(view)
	var icon_layer := scene.find_child("IconLayer", true, false)   # the logbook's button (its open book stays crisp)
	if icon_layer:
		icon_layer.reparent(view)

	# 2b. The tilt-shift: a rectangle over the whole view on its own CanvasLayer (90). A canvas shader reads what's
	#     been drawn so far (the 3D world only, as the controls' layers come after it) and blurs top and bottom.
	var tilt_layer := CanvasLayer.new()
	tilt_layer.layer = TILT_SHIFT_LAYER
	view.add_child(tilt_layer)
	tilt_shift = ColorRect.new()
	tilt_shift.set_anchors_preset(Control.PRESET_FULL_RECT)
	tilt_shift.mouse_filter = Control.MOUSE_FILTER_IGNORE   # never takes a touch
	var material := ShaderMaterial.new()
	material.shader = TILT_SHIFT_SHADER
	tilt_shift.material = material
	tilt_layer.add_child(tilt_shift)
	_update_tilt_shift()

	# 3. The picture of it, over the whole screen, under the crisp layers (vane 110, book 120, start screen 130).
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	screen = TextureRect.new()
	screen.texture = view.get_texture()
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # blown up without smoothing: sharp dots
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen.stretch_mode = TextureRect.STRETCH_SCALE
	screen.set_anchors_preset(Control.PRESET_TOP_LEFT)   # placed and sized by _fit (not stretched to the screen)
	screen.gui_input.connect(_pass_input)
	layer.add_child(screen)

	# 4. Its size, now and whenever the window changes.
	get_tree().root.size_changed.connect(_fit)
	_fit()

	# 5. Every material drawn once now, so none stutters the first time it comes into view (shader_warmup.gd).
	var boat := Boat.current
	if boat:
		var warmup := ShaderWarmup.new()
		add_child(warmup)
		warmup.run(boat.camera)


## The view's size: the screen's real pixels divided by the dot scale, ROUNDED UP. The dot scale: real pixels
## across the screen / dots_across, rounded (whole real pixels a dot, so every dot is the same size).
## The picture of the view is then shown at EXACTLY dot_scale real pixels a dot, from the top left corner: the last
## row or column of dots may hang a little off the screen's edge, where it's simply cut off. (Enrico, Nov 2026: it
## used to be stretched over the whole screen; when the screen's height wasn't a whole number of dots, e.g. 1873
## real pixels at 2 a dot, one row of pixels was doubled in the middle of the screen, and the dither showed it as a
## thin line across, dark on one side and light on the other.)
## The controls inside the view are laid out as if it were DESIGN_WIDTH (360) wide (size_2d_override, like
## a DPI scale in Unreal's UMG), and stretched to the view's real pixels: so they keep their size on the screen.
func _fit() -> void:
	var window := get_tree().root
	var real_size := window.get_visible_rect().size * window.get_final_transform().get_scale()   # real pixels
	dot_scale = maxi(1, roundi(real_size.x / dots_across))
	var dots := Vector2i(maxi(1, ceili(real_size.x / dot_scale)), maxi(1, ceili(real_size.y / dot_scale)))
	view.size = dots
	# The real pixels the picture covers: a whole number of them a dot (a hair more than the screen, at most).
	var covered := Vector2(dots * dot_scale)
	# The picture's rectangle, in the screen's own units (Godot's: the project's 360-wide layout, stretched to the
	# window): real pixels × (units per real pixel).
	var units_per_pixel := window.get_visible_rect().size / real_size
	screen.position = Vector2.ZERO
	screen.size = covered * units_per_pixel
	# The controls' own size: the covered real pixels divided by the scale they'd have at 360 dots across.
	var ui_scale := maxi(1, roundi(real_size.x / DESIGN_WIDTH))
	view.size_2d_override = Vector2i(maxi(1, int(covered.x / ui_scale)), maxi(1, int(covered.y / ui_scale)))
	view.size_2d_override_stretch = true


## Sends the tilt-shift's numbers to its shader (also when they're changed in the Inspector while the game runs).
func _update_tilt_shift() -> void:
	if tilt_shift == null:
		return
	tilt_shift.visible = tilt_shift_on
	var material := tilt_shift.material as ShaderMaterial
	material.set_shader_parameter("top_band", tilt_top)
	material.set_shader_parameter("bottom_band", tilt_bottom)
	material.set_shader_parameter("blur_pixels", tilt_blur)


## A tap or a drag on the picture: passed on to the SubViewport, its position turned into the units the controls
## inside are laid out in. Those are the view's size_2d_override (the screen as if it were DESIGN_WIDTH 360 wide, see
## _fit), NOT the view's pixels: with dots_across 360 on a phone the two happened to be the same, but at 540 the view
## has 540 pixels across while the controls still think in 360, so a touch landed 1.5 times too far right and down
## (Enrico, Nov 2026: "the UI stopped working"). Now a touch is in the same place whatever dots_across is.
func _pass_input(event: InputEvent) -> void:
	var units := Vector2(view.size_2d_override)
	if units.x <= 0.0 or units.y <= 0.0:
		units = Vector2(view.size)                 # no override: the controls think in the view's pixels
	var to_units := units / screen.size            # from the picture on the screen to the controls' units
	view.push_input(event.xformed_by(Transform2D.IDENTITY.scaled(to_units)), true)

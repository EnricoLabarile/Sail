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
## button layer) are moved into the SubViewport. In the editor the scene looks as always.
## Taps and drags on the picture are passed on to the SubViewport, scaled to its pixels (push_input).

const DESIGN_WIDTH := 360.0   # the game's width in the project settings: the picture is about this many pixels wide
const DITHERED := ["Sea", "Coast", "Clouds", "WindLines", "Gulls", "Boat", "Dither", "Helm"]   # nodes of Overworld moved into the view

var view: SubViewport         # where the dithered part of the game is drawn
var screen: TextureRect       # the view's picture, stretched over the screen
var dot_scale := 1            # real pixels per game pixel (3 on a phone about 1080 wide, 1 on a 360 x 800 window)


func _ready() -> void:
	add_to_group("game_view")   # so the logbook's counter can find it
	_build.call_deferred()        # after every node of the scene is ready


func _build() -> void:
	# 1. The SubViewport. It uses the same 3D world as the rest of the game (it doesn't make its own).
	view = SubViewport.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	# Time how long drawing it takes (on the processor and on the graphics chip), for the logbook's counter.
	RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(), true)

	# 2. Move the dithered nodes into it: the world, the dither and the controls under it.
	var scene := get_parent()
	for node_name in DITHERED:
		var node := scene.get_node_or_null(node_name)
		if node:
			node.reparent(view)
	var icon_layer := scene.find_child("IconLayer", true, false)   # the logbook's button (its open book stays crisp)
	if icon_layer:
		icon_layer.reparent(view)

	# 3. The picture of it, over the whole screen, under the crisp layers (vane 110, book 120, start screen 130).
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	screen = TextureRect.new()
	screen.texture = view.get_texture()
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # blown up without smoothing: sharp dots
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen.stretch_mode = TextureRect.STRETCH_SCALE
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.gui_input.connect(_pass_input)
	layer.add_child(screen)

	# 4. Its size, now and whenever the window changes.
	get_tree().root.size_changed.connect(_fit)
	_fit()


## The view's size: the screen's real pixels divided by the dot scale. The dot scale: real pixels across the
## screen / 360, rounded (so on an upright phone the world is always about 360 dots wide, as on the PC).
func _fit() -> void:
	var window := get_tree().root
	var real_size := window.get_visible_rect().size * window.get_final_transform().get_scale()   # real pixels
	dot_scale = maxi(1, roundi(real_size.x / DESIGN_WIDTH))
	view.size = Vector2i(maxi(1, int(real_size.x / dot_scale)), maxi(1, int(real_size.y / dot_scale)))


## A tap or a drag on the picture: passed on to the SubViewport, its position turned into the view's pixels.
func _pass_input(event: InputEvent) -> void:
	var to_view := Vector2(view.size) / screen.size
	view.push_input(event.xformed_by(Transform2D.IDENTITY.scaled(to_view)), true)

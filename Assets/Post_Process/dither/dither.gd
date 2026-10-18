extends CanvasLayer
## THE DITHER's helper: draws the 3D world at the game's own resolution.
## The dither (dither.gdshader) shows one dot for every game pixel (the 360 x 800 design screen), however
## sharp the real screen is: on a phone (about 1080 x 2340) one dot covers 3 x 3 real pixels and only one of
## them is used. So there's no point drawing the 3D world (sea, clouds, shadows, outline, fog) at full
## resolution: this sets the 3D resolution scale (in Unreal: Screen Percentage) to one game pixel per pixel,
## 1/3 on that phone, 9 times less work for the graphics chip. The UI keeps the full resolution.
## On the PC editor window (360 x 800) the scale is 1: nothing changes.

const DESIGN_SIZE := Vector2(360.0, 800.0)   # the game's screen size in the project settings


func _ready() -> void:
	set_3d_scale()
	get_tree().root.size_changed.connect(set_3d_scale)   # again whenever the window changes size


## Real screen pixels per game pixel (the same sum as dither.gdshader: on an upright screen the width,
## on a wide one the smaller side; rounded, at least 1), and the 3D drawn at 1 / that.
func set_3d_scale() -> void:
	var window_size := Vector2(get_tree().root.size)     # the real pixels of the window (or the phone's screen)
	var ratio := window_size / DESIGN_SIZE
	var side := ratio.x                                  # upright (a phone): the width
	if window_size.x > window_size.y:
		side = minf(ratio.x, ratio.y)                    # wide (a computer): the smaller side
	var scale := maxf(1.0, roundf(side))
	get_tree().root.scaling_3d_scale = 1.0 / scale

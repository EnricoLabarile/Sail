extends CanvasLayer
## THE CATCH ABOVE THE BOAT (Enrico, Nov 2026, like Link's Awakening, where Link holds up what he found): whenever
## something comes into the hold (a pickup, a fish, a bought thing, a caught imp: Inventory's `came_aboard`), its icon
## shows up over the boat, rises GRADUALLY above her, stays a moment and fades away. The boat doesn't stop.
## (In Unreal terms: an Actor Component of the boat that draws a little widget over her.)
##
## It's drawn on the screen (a CanvasLayer, not a 3D thing), so it's always easy to read; it's a child of the Boat, so
## the game view (game_view.gd) takes it into the dithered picture with her, under the dither (layer 94 < 100).
## Every frame it works out where the boat is on the screen and draws the icon there, a little higher as time goes by.
## Several things one after the other (a bomb, then a key…) wait in a queue and are shown in turn; a pile coming
## aboard at once (two bombs from a barrel) is one show.
## Things that don't go into the hold (a fishing spot's coins or heart container) are shown too: whoever brings
## them calls `show_picture(their icon)` on this node (the Boat's child `ItemShow`).

const INK := Color("1b1a17")
const PAPER := Color("ebe7dc")

@export var rise_time := 0.9       # seconds it takes to rise from the boat to its highest point (slowing down at the end)
@export var hold_time := 0.5       # seconds it stays up there
@export var fade_time := 0.3       # seconds it takes to fade away
@export var appear_time := 0.15    # seconds it takes to fade in at the start
@export var start_height := 10.0   # pixels above the boat's middle where it appears
@export var rise_height := 30.0    # pixels it rises from there
@export var icon_size := 28.0      # the icon's size on the screen, in pixels
@export var disc_padding := 5.0    # paper round the icon (a disc with an ink ring, so it reads on the dark sea)

var queue: Array[Texture2D] = []   # the pictures waiting to be shown, in order
var icon: Texture2D                # the picture being shown now (null = nothing)
var time := 0.0                    # seconds since it started showing
var picture: Control               # where it's drawn (made in _ready)


func _ready() -> void:
	layer = 94                       # under the controls (95) and the dither (100)
	# The drawing surface: a Control over the whole screen that ignores the mouse; its "draw" signal calls our
	# _draw_picture, so the drawing code stays here.
	picture = Control.new()
	picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.draw.connect(_draw_picture)
	add_child(picture)
	Inventory.came_aboard.connect(_on_came_aboard)
	set_process(false)               # nothing to do until something comes aboard


## Something came into the hold: show its icon.
func _on_came_aboard(new_item: String, _count: int) -> void:
	show_picture(Inventory.icon_of(new_item))


## Shows a picture over the boat: now, or after the one being shown. Anything may call it (fishing_spot.gd does,
## for coins and heart containers, which never go into the hold).
func show_picture(picture_to_show: Texture2D) -> void:
	if picture_to_show == null:
		return
	queue.append(picture_to_show)
	if icon == null:
		show_next()


## Takes the next thing from the queue and starts showing it (or stops, if the queue is empty).
func show_next() -> void:
	if queue.is_empty():
		icon = null
		set_process(false)
		picture.queue_redraw()       # clears the last picture
		return
	icon = queue.pop_front()
	time = 0.0
	set_process(true)


func _process(dt: float) -> void:
	time += dt
	if time >= rise_time + hold_time + fade_time:
		show_next()
		return
	picture.queue_redraw()           # it moves (and the boat moves): draw it again


## Where the boat's middle is on the screen (the camera in the game view turns a 3D point into a screen point).
func boat_on_screen() -> Vector2:
	var boat := get_parent() as Node3D
	var camera: Camera3D = boat.camera
	var middle := boat.get_global_transform_interpolated().origin
	return camera.unproject_position(middle)


func _draw_picture() -> void:
	if icon == null:
		return
	# 1. How high: it rises over rise_time, quick at first and slowing as it gets there (ease out), then stays.
	var share := clampf(time / rise_time, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - share, 3.0)
	var height := start_height + rise_height * eased
	# 2. How visible: fades in over appear_time, fades out over the last fade_time.
	var fade_in := clampf(time / appear_time, 0.0, 1.0)
	var fade_out := clampf((rise_time + hold_time + fade_time - time) / fade_time, 0.0, 1.0)
	var alpha := minf(fade_in, fade_out)
	# 3. Draw it there: a paper disc with an ink ring, the icon in the middle.
	var middle := boat_on_screen() - Vector2(0.0, height)
	var radius := icon_size * 0.5 + disc_padding
	picture.draw_circle(middle, radius + 2.0, Color(INK, alpha))
	picture.draw_circle(middle, radius, Color(PAPER, alpha))
	var box := Rect2(middle - Vector2(icon_size, icon_size) * 0.5, Vector2(icon_size, icon_size))
	picture.draw_texture_rect(icon, box, false, Color(1, 1, 1, alpha))

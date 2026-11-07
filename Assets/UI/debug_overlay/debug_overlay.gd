extends CanvasLayer
## THE PERFORMANCE OVERLAY (Enrico, Nov 2026: to find out on the phone what makes the game slow). Switched on with
## the "Performance overlay" box on the start screen; then, in every level, a small panel top left shows numbers
## refreshed `refresh_every` seconds. (In Unreal: "stat fps" + "stat unit" + "stat rhi" on one panel.)
##
## HOW TO READ IT (what makes a frame slow):
##   - "Frame" is the time between two drawn frames (what the player feels). 16.7 ms = 60 fps, 33.3 ms = 30 fps.
##     "worst" is the slowest frame of the last second; "hitches" counts frames over HITCH_MS in the last 10 s
##     (those are the stutters, even when the average fps looks fine).
##   - "CPU" is the processor's work, the SLOWEST of the last second (Godot measures these as a maximum):
##     "process" (every _process of every node, the UI, the scene tree), "physics" (every _physics_process: the
##     boat) and "render prep" (the CPU getting the frames ready for the graphics card, the window and the game view).
##   - The arrow says where the slowest frame went: if the worst frame is much longer than the CPU's work, the time
##     went on the GRAPHICS CARD (GPU): too many pixels, heavy shaders, see-through layers; otherwise on the CPU.
##   - "GPU" is the card's own time when the browser can measure it (often it can't on the web: "n/a").
##   - "Draw" is the drawing work: draw calls (each one costs, on a phone a few hundred is a lot), objects and
##     triangles. "VRAM" is the video memory used.
##   - Then the device: the graphics card's name, the window and the game view (how many pixels are really drawn).
##
## It lives in ui_layout.tscn (node DebugOverlay), so it's in every level; it stays out of the game view (it's not
## dithered) and keeps working while the game is paused (process_mode Always).

## Is it on? A static var belongs to the script, not to one overlay, so the choice on the start screen holds for every
## level loaded after it (for this session only: reloading the page starts it off again).
static var enabled := false

const HITCH_MS := 50.0             # a frame slower than this counts as a hitch (a stutter the player sees)
const HITCH_WINDOW := 10.0         # seconds the hitches are counted over

@export var refresh_every := 0.25  # seconds between two refreshes of the text (the measuring itself is every frame)
@export var font_size := 10

var label: Label
var since_refresh := 0.0
var frame_times: Array[float] = []     # the frames of the last second (ms), to find the worst one
var frame_ages: Array[float] = []      # how long ago each of those was (s)
var hitch_ages: Array[float] = []      # how long ago each hitch of the last HITCH_WINDOW seconds was (s)
var shown := false                     # was it on a frame ago? (to show / hide it when the box is ticked)
var game_view: Node = null             # the level's GameView (game_view.gd), found once: its SubViewport draws the world


func _ready() -> void:
	layer = 140                        # over everything, the start screen (130) too
	process_mode = Node.PROCESS_MODE_ALWAYS
	make_panel()
	# Ask the rendering server to time each frame's drawing (CPU and GPU) for the main window. (Off by default:
	# measuring costs a little.)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	visible = false


## The panel: a black see-through box with small white text, top left, not catching any touch.
func make_panel() -> void:
	var box := PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.position = Vector2(4, 4)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.set_content_margin_all(4)
	box.add_theme_stylebox_override("panel", style)
	add_child(box)
	label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	box.add_child(label)


func _process(dt: float) -> void:
	# Follow the box on the start screen.
	if enabled != shown:
		shown = enabled
		visible = enabled
	if not enabled:
		return
	measure(dt)
	since_refresh += dt
	if since_refresh >= refresh_every:
		since_refresh = 0.0
		label.text = report()


## Every frame: keep the last second of frame times and the last HITCH_WINDOW seconds of hitches.
func measure(dt: float) -> void:
	var ms := dt * 1000.0
	for i in frame_ages.size():
		frame_ages[i] += dt
	for i in hitch_ages.size():
		hitch_ages[i] += dt
	frame_times.append(ms)
	frame_ages.append(0.0)
	while not frame_ages.is_empty() and frame_ages[0] > 1.0:
		frame_ages.pop_front()
		frame_times.pop_front()
	if ms > HITCH_MS:
		hitch_ages.append(0.0)
	while not hitch_ages.is_empty() and hitch_ages[0] > HITCH_WINDOW:
		hitch_ages.pop_front()


## The text of the panel, line by line.
func report() -> String:
	var lines: Array[String] = []
	var fps := Engine.get_frames_per_second()
	var average := 1000.0 / fps if fps > 0 else 0.0
	var worst := 0.0
	for ms in frame_times:
		worst = maxf(worst, ms)
	lines.append("FPS %d   frame %.1f ms   worst %.1f" % [fps, average, worst])
	lines.append("hitches >%d ms (last %ds): %d" % [HITCH_MS, HITCH_WINDOW, hitch_ages.size()])

	# Our own CPU work this frame.
	var scripts := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var viewport_rid := get_viewport().get_viewport_rid()
	var render_cpu := RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid) \
			+ RenderingServer.get_frame_setup_time_cpu()
	find_game_view()
	if game_view:
		# The world is drawn in the game view's own SubViewport (game_view.gd): its share of the drawing.
		render_cpu += RenderingServer.viewport_get_measured_render_time_cpu(game_view.view.get_viewport_rid())
	lines.append("CPU worst/s: process %.1f  physics %.1f  render prep %.1f ms" % [scripts, physics, render_cpu])
	var cpu_total := scripts + physics + render_cpu
	lines.append("CPU %.1f vs worst frame %.1f ms -> %s" % [cpu_total, worst,
			"GPU-bound" if worst > cpu_total * 1.5 else "CPU-bound"])
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid)
	if game_view:
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(game_view.view.get_viewport_rid())
	lines.append("GPU %s" % ("%.1f ms" % gpu if gpu > 0.0 else "n/a (not measured here)"))

	# The drawing work.
	var draw_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var objects := Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var triangles := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	lines.append("Draw calls %d  objects %d  tris %dk" % [draw_calls, objects, int(triangles / 1000.0)])
	var vram := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	var texture_mem := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0
	lines.append("VRAM %.0f MB (textures %.0f)" % [vram, texture_mem])

	# Memory and the size of the level.
	var memory := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	lines.append("RAM %.0f MB  nodes %d" % [memory, nodes])

	# The device and the pixels drawn.
	lines.append(RenderingServer.get_video_adapter_name())
	var window := get_viewport().get_visible_rect().size
	var real := window * get_viewport().get_final_transform().get_scale()
	lines.append("window %dx%d  real px %dx%d" % [window.x, window.y, real.x, real.y])
	if game_view:
		var size: Vector2i = game_view.view.size
		lines.append("game view %dx%d (x%d)" % [size.x, size.y, game_view.dot_scale])
	return "\n".join(lines)


## Finds the level's GameView once its SubViewport exists (it's made at the start, deferred), and asks for its
## drawing to be timed too.
func find_game_view() -> void:
	if game_view != null or get_tree().current_scene == null:
		return
	var found := get_tree().current_scene.find_child("GameView", true, false)
	if found and found.get("view") is SubViewport:
		game_view = found
		RenderingServer.viewport_set_measure_render_time(game_view.view.get_viewport_rid(), true)

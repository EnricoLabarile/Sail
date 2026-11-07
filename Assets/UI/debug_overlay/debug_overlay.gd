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
##   - The arrow says where the time goes, comparing the AVERAGE frame with the CPU's work: the CPU numbers are the
##     slowest of the second, so if even they are well under the average frame, the rest must be the GRAPHICS CARD
##     (GPU-bound: too many pixels, heavy shaders, see-through layers); if they reach it, it's the CPU (CPU-bound);
##     in between, "mixed". (A single slow frame, a hitch, shows in "worst" and "hitches", not here.)
##   - "GPU" is the card's own time when the browser can measure it (often it can't on the web: "n/a").
##   - "Draw" is the drawing work: draw calls (each one costs, on a phone a few hundred is a lot), objects and
##     triangles. "VRAM" is the video memory used.
##   - Then the device: the graphics card's name, the window and the game view (how many pixels are really drawn).
##
## THE SWITCHES (Enrico, Nov 2026: to find out on the phone what costs what): under the numbers, a button for each
## part of the picture; a tap switches that part off (the button turns dark), another tap back on. Sail, switch one
## off, watch the FPS: what it gains is what that part costs on this phone. They're only for testing: each level
## starts with everything on. (SWITCHES lists them; `switch_off` does the work for each.)
##   Sea       the sea's shader (its texture, shore waves, deep water, grid) → a plain grey sea
##   Dither    the 1-bit dither over the world (the picture then shows in greys)
##   Fog       the fog of war's screen effect
##   Shadows   the clouds' shadows' screen effect
##   Clouds    the clouds, their shadows and the cloud map (and their movement)
##   Outline   the ink outline round the boat (screen effect)
##   Islands   all the land pieces (365 meshes in the Overworld)
##   Effects   gulls, wind lines, the boat's wake (the bow wave stays: boat.gd shows it every frame; it's 2 quads)
##   UI        the wheel, the lever, the logbook and the hearts (not drawn)
## And one more button, "Dots n": the game view's resolution (its dots_across), each tap the next of RESOLUTIONS, round
## and round (Enrico, Nov 2026: to see the game at different resolutions; it replaced the old "Half res" switch).
##
## It lives in ui_layout.tscn (node DebugOverlay), so it's in every level; it stays out of the game view (it's not
## dithered) and keeps working while the game is paused (process_mode Always).

## Is it on? A static var belongs to the script, not to one overlay, so the choice on the start screen holds for every
## level loaded after it (for this session only: reloading the page starts it off again).
static var enabled := false

const HITCH_MS := 50.0             # a frame slower than this counts as a hitch (a stutter the player sees)
const HITCH_WINDOW := 10.0         # seconds the hitches are counted over
const SWITCHES := ["Sea", "Dither", "Fog", "Shadows", "Clouds", "Outline", "Islands", "Effects", "UI"]
## The resolutions the "Dots" button goes through (dots across the screen: game_view.gd dots_across; 360 = as usual).
const RESOLUTIONS := [360, 540, 1080, 270, 180]

@export var refresh_every := 0.25  # seconds between two refreshes of the text (the measuring itself is every frame)
@export var font_size := 10

var label: Label
var since_refresh := 0.0
var frame_times: Array[float] = []     # the frames of the last second (ms), to find the worst one
var frame_ages: Array[float] = []      # how long ago each of those was (s)
var hitch_ages: Array[float] = []      # how long ago each hitch of the last HITCH_WINDOW seconds was (s)
var shown := false                     # was it on a frame ago? (to show / hide it when the box is ticked)
var game_view: Node = null             # the level's GameView (game_view.gd), found once: its SubViewport draws the world
var switched_off := {}                 # name of a switch → true while that part is off
var buttons := {}                      # name of a switch → its button
var dots_button: Button                # the "Dots n" button (the game view's resolution)
var sea_material: Material             # the sea's own material, kept while the "Sea" switch puts a plain one on it


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
	var lines := VBoxContainer.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lines)
	label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	lines.add_child(label)
	# The switches: small buttons in rows of five, under the numbers.
	var grid := GridContainer.new()
	grid.columns = 5
	lines.add_child(grid)
	for switch_name in SWITCHES:
		var button := Button.new()
		button.text = switch_name
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", font_size)
		button.pressed.connect(toggle.bind(switch_name))   # bind: the button hands its own name to toggle
		grid.add_child(button)
		buttons[switch_name] = button
		paint_button(switch_name)
	# The resolution button, last in the grid.
	dots_button = Button.new()
	dots_button.focus_mode = Control.FOCUS_NONE
	dots_button.add_theme_font_size_override("font_size", font_size)
	dots_button.pressed.connect(next_resolution)
	grid.add_child(dots_button)
	show_resolution()


## The "Dots" button tapped: the game view goes to the next resolution of RESOLUTIONS (after the last, the first).
func next_resolution() -> void:
	find_game_view()
	if game_view == null:
		return
	var at := RESOLUTIONS.find(game_view.dots_across)       # -1 if it's a value set by hand: then the first
	game_view.dots_across = RESOLUTIONS[(at + 1) % RESOLUTIONS.size()]   # its setter resizes the view (game_view.gd)
	show_resolution()


## Writes the game view's dots_across on the button ("Dots 360").
func show_resolution() -> void:
	find_game_view()
	var dots: int = game_view.dots_across if game_view else 360
	dots_button.text = "Dots %d" % dots


## A switch tapped: that part off if it was on, on if it was off.
func toggle(switch_name: String) -> void:
	var off: bool = not switched_off.get(switch_name, false)
	switched_off[switch_name] = off
	switch_off(switch_name, off)
	paint_button(switch_name)


## A button light while its part is on, dark (and its name crossed by "-") while it's off.
func paint_button(switch_name: String) -> void:
	var off: bool = switched_off.get(switch_name, false)
	var button: Button = buttons[switch_name]
	button.text = ("-" + switch_name + "-") if off else switch_name
	button.modulate = Color(0.45, 0.45, 0.45) if off else Color.WHITE


## Switches one part of the picture off (off = true) or back on. Each part is found by its node's name in the level
## (as game_view.gd does), or, for the screen effects (made in code, with no names), by their shader's file.
func switch_off(switch_name: String, off: bool) -> void:
	var level := get_tree().current_scene
	if level == null:
		return
	match switch_name:
		"Sea":
			var sea := level.find_child("Sea", true, false) as MeshInstance3D
			if sea:
				if off:
					sea_material = sea.material_override
					var plain := StandardMaterial3D.new()
					plain.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					plain.albedo_color = Color(0.55, 0.55, 0.55)
					sea.material_override = plain
				elif sea_material:
					sea.material_override = sea_material
		"Dither":
			set_node_shown(level, "Dither", not off)
		"Fog":
			show_screen_effect(level, "fog.gdshader", not off)
		"Shadows":
			show_screen_effect(level, "cloud_shadow.gdshader", not off)
		"Clouds":
			var clouds := level.find_child("Clouds", true, false)
			if clouds:
				clouds.visible = not off
				clouds.process_mode = Node.PROCESS_MODE_DISABLED if off else Node.PROCESS_MODE_INHERIT
		"Outline":
			show_screen_effect(level, "boat_outline.gdshader", not off)
		"Islands":
			set_node_shown(level, "Islands", not off)
		"Effects":
			for node_name in ["Gulls", "WindLines", "Wake"]:
				set_node_shown(level, node_name, not off)
			var paddles := level.find_child("Paddles", true, false)
			if paddles and paddles.get("puffs") != null:
				for puff in paddles.puffs:
					puff.visible = puff.visible and not off   # the steam: hidden now (shown again by the next puffs)
		"UI":
			for node_name in ["Helm", "Crank", "IconLayer", "Health"]:
				set_node_shown(level, node_name, not off)


## Shows or hides the node of that name, wherever it is in the level (if it's there). A plain Node (a "folder" such
## as Islands in the Overworld) has no visibility of its own: then its children are shown or hidden.
func set_node_shown(level: Node, node_name: String, shown_now: bool) -> void:
	var node := level.find_child(node_name, true, false)
	if node == null:
		return
	if "visible" in node:
		node.visible = shown_now
		return
	for child in node.get_children():
		if "visible" in child:
			child.visible = shown_now


## Shows or hides every mesh in the level drawn with that shader (the full-screen effects: fog, shadows, outline).
func show_screen_effect(level: Node, shader_file: String, shown_now: bool) -> void:
	for mesh in level.find_children("*", "MeshInstance3D", true, false):
		var quad := (mesh as MeshInstance3D).mesh as QuadMesh
		if quad == null or not (quad.material is ShaderMaterial):
			continue
		var shader: Shader = (quad.material as ShaderMaterial).shader
		if shader and shader.resource_path.ends_with(shader_file):
			mesh.visible = shown_now


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
	var verdict := "mixed"
	if average > cpu_total * 1.2:
		verdict = "GPU-bound"
	elif cpu_total >= average * 0.8:
		verdict = "CPU-bound"
	lines.append("CPU %.1f vs avg frame %.1f ms -> %s" % [cpu_total, average, verdict])
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

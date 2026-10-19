extends Control
## THE SLINGSHOT (bottom right, mirroring the logbook), as in the prototype: drag its pouch down to stretch the
## bands; once the pull reaches fire_pull it shoots by itself, a stone flying off ahead of the bow in an arc
## (Assets/Boat/stone/). Let go before and the pouch springs back, nothing shot. After a shot the pouch is empty
## for reload_time. While pulling, a dashed ring on the water shows where the stone will land.
## The Enter key shoots too. No limit to the stones for now (Enrico).
##
## It is drawn with code, in greys, under the dither (its CanvasLayer is 95, like the wheel's), so it's 1-bit.
## The drawing is the prototype's, made in its units (a 64 x 80 box) and scaled to this Control's size.
## (In Unreal: a UMG widget that spawns a projectile actor.)

@export var sling_distance := 6.0   # metres ahead of the bow the stone lands (the prototype's 60 px)
@export var flight_time := 0.7      # seconds the stone flies
@export var arc_height := 2.9       # metres its arc rises (the prototype's 29 px)
@export var muzzle_height := 1.0    # metres above the water it leaves the bow
@export var fire_pull := 0.7        # pull the pouch this far (0..1) and it shoots by itself
@export var reload_time := 0.9      # seconds before the next stone is in the pouch

const STONE_SCENE := preload("res://Assets/Boat/stone/stone.tscn")
const DRAW_W := 64.0               # the prototype's drawing box
const DRAW_H := 80.0
const PULL_TRAVEL := 48.0          # how far down the pouch goes at a full pull (in the drawing's units)
const AIM_SIZE := 2.0              # metres across the aim ring
const PAPER := Color(1, 1, 1)
const INK := Color(0, 0, 0)

var pull := 0.0                    # 0..1, how far the pouch is pulled down
var drag_index := -1               # the finger on the pouch (-1 = none)
var drag_start_y := 0.0            # where that finger came down
var reload := 0.0                  # seconds until the pouch has a stone again
var enter_was_down := false        # the Enter key a frame ago (so one press is one shot)
var boat_velocity := Vector3.ZERO  # how the boat is moving (metres a second), measured each frame
var last_boat_pos := Vector3.ZERO
var aim_ring: MeshInstance3D       # the dashed ring on the water (made the first time it's needed)


func _boat() -> Node3D:
	return get_tree().get_first_node_in_group("player_boat") as Node3D


## How many screen pixels one of the drawing's units is.
func _k() -> float:
	return minf(size.x / DRAW_W, size.y / DRAW_H)


# ---- touching it ----

func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			if drag_index == -1 and reload <= 0.0:
				drag_index = e.index
				drag_start_y = e.position.y
				accept_event()
		elif e.index == drag_index:
			drag_index = -1          # let go before the shot: the pouch springs back (in _process)
	elif e is InputEventScreenDrag and e.index == drag_index:
		pull = clampf((e.position.y - drag_start_y) / (PULL_TRAVEL * _k()), 0.0, 1.0)
		queue_redraw()
		if pull >= fire_pull:        # pulled far enough: it shoots by itself
			drag_index = -1
			pull = 0.0
			shoot()
		accept_event()


func _process(dt: float) -> void:
	var boat := _boat()
	if boat == null:
		return
	# 1. How the boat is moving (the stone is carried on by her way, so it doesn't seem to veer behind her).
	if dt > 0.0:
		boat_velocity = (boat.global_position - last_boat_pos) / dt
	last_boat_pos = boat.global_position

	# 2. The reload: the pouch is empty for a moment after a shot.
	if reload > 0.0:
		reload = maxf(0.0, reload - dt)
		if reload == 0.0:
			queue_redraw()           # the stone is back in the pouch

	# 3. Let go: the pouch springs back up.
	if drag_index == -1 and pull > 0.0:
		pull = maxf(0.0, pull - dt * 6.0)
		queue_redraw()

	# 4. The Enter key shoots at once.
	var enter_down := Input.is_key_pressed(KEY_ENTER)
	if enter_down and not enter_was_down and reload <= 0.0:
		shoot()
	enter_was_down = enter_down

	# 5. The aim ring on the water, while pulling.
	update_aim(boat)


## Where the stone will land: sling_distance ahead of the bow, plus how far the boat moves while it flies.
func landing_point(boat: Node3D) -> Vector3:
	var forward := -boat.global_transform.basis.z
	forward.y = 0.0
	var spot: Vector3 = boat.bow_point() + forward.normalized() * sling_distance + boat_velocity * flight_time
	spot.y = 0.0
	return spot


## Fire: a stone into the world, from the bow to the landing point.
func shoot() -> void:
	var boat := _boat()
	if boat == null or reload > 0.0:
		return
	var start: Vector3 = boat.bow_point()
	start.y = muzzle_height
	var stone := STONE_SCENE.instantiate()
	boat.get_parent().add_child(stone)   # in the world, next to the boat (not inside her: it mustn't move with her)
	stone.launch(start, landing_point(boat), flight_time, arc_height)
	reload = reload_time
	Sfx.sling_shot()
	queue_redraw()


## The dashed ring where the stone will land: shown while the pouch is pulled, firmer as the pull nears the shot.
func update_aim(boat: Node3D) -> void:
	var showing := drag_index != -1 and pull > 0.05
	if aim_ring == null:
		if not showing:
			return
		aim_ring = make_aim_ring()
		boat.get_parent().add_child(aim_ring)
	aim_ring.visible = showing
	if showing:
		var spot := landing_point(boat)
		aim_ring.global_position = Vector3(spot.x, 0.03, spot.z)
		var material: ShaderMaterial = aim_ring.material_override
		material.set_shader_parameter("strength", minf(1.0, pull / fire_pull))


func make_aim_ring() -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(AIM_SIZE, AIM_SIZE)
	var material := ShaderMaterial.new()
	material.shader = preload("res://Assets/UI/slingshot/aim_ring.gdshader")
	material.render_priority = 1   # after the sea, before the stones, the clouds and the fog
	var ring := MeshInstance3D.new()
	ring.mesh = mesh
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return ring


# ---- drawing it (the prototype's SVG, in greys) ----

func _draw() -> void:
	var k := _k()
	var drop := pull * PULL_TRAVEL   # how far down the pouch is, in the drawing's units
	# 1. The wooden fork: a light grey shape outlined in ink.
	var fork := path_points([
		[28, 77], [28, 52], ["q", 28, 44, 20, 38], [8, 21], ["q", 6, 14, 12, 13], ["q", 17, 13, 18, 19], [28, 33],
		["q", 32, 38, 36, 33], [46, 19], ["q", 47, 13, 52, 13], ["q", 58, 14, 56, 21], [44, 38], ["q", 36, 44, 36, 52],
		[36, 77]], k)
	draw_colored_polygon(fork, Color(0.8, 0.8, 0.8))
	draw_polyline(close(fork), INK, 2.2 * k, true)
	draw_line(Vector2(31, 73) * k, Vector2(31, 55) * k, Color(0, 0, 0, 0.5), 0.8 * k)   # the grain
	draw_line(Vector2(33, 70) * k, Vector2(33, 60) * k, Color(0, 0, 0, 0.5), 0.8 * k)
	# 2. The bands, from the prongs' tips to the pouch: ink over a paper edge, so they read over the wood.
	var pouch_middle := Vector2(32, 18 + drop)
	for tip in [Vector2(11, 16), Vector2(53, 16)]:
		draw_line(tip * k, pouch_middle * k, PAPER, 5.5 * k)
		draw_line(tip * k, pouch_middle * k, INK, 2.4 * k)
	# 3. The pouch (a mid grey: the dither makes it dotted) and the stone in it (not while reloading).
	var pouch := path_points([[21, 15 + drop], ["q", 32, 31 + drop, 43, 15 + drop], ["q", 32, 23 + drop, 21, 15 + drop]], k)
	draw_colored_polygon(pouch, Color(0.6, 0.6, 0.6))
	draw_polyline(close(pouch), INK, 2.0 * k, true)
	if reload <= 0.0:
		draw_circle(Vector2(32, 19 + drop) * k, 6.0 * k, INK)


## The points of a shape from a list of steps in the drawing's units: [x, y] is a straight line to that point,
## ["q", cx, cy, x, y] a curve to (x, y) bent toward (cx, cy) (like the SVG's Q).
func path_points(steps: Array, k: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for step in steps:
		if step[0] is String:
			var start := points[points.size() - 1] / k
			var bend := Vector2(step[1], step[2])
			var end := Vector2(step[3], step[4])
			for i in range(1, 9):
				var t := i / 8.0
				points.append(start.lerp(bend, t).lerp(bend.lerp(end, t), t) * k)
		else:
			points.append(Vector2(step[0], step[1]) * k)
	return points


## The same points with the first one again at the end, to draw the outline all the way round.
func close(points: PackedVector2Array) -> PackedVector2Array:
	var closed := points.duplicate()
	closed.append(points[0])
	return closed

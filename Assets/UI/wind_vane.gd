extends Control
## The wind indicator, top right: a paper dial with north at the top (the camera never turns, so the
## screen's up is always north). The ink arrow flies the way the wind blows, its feathered tail on
## the side the wind comes from; the small hollow triangle on the rim is where the bow points, so the
## angle between them tells you how she sails. It reads the boat's wind every frame, so it follows any
## change of wind (it shifts now and then, see Wind). (Like a UMG widget that reads a value from the pawn on tick.)

const PAPER := Color("ebe7dc")
const INK := Color("1b1a17")

var wind_deg := 0.0      # where the wind blows from (0 = north, 90 = east)
var heading := Vector2.UP

func _process(_dt: float) -> void:
	var b := get_tree().get_first_node_in_group("player_boat") as Node3D
	if b == null:
		return
	var fwd := -b.global_transform.basis.z
	var h := Vector2(fwd.x, fwd.z).normalized()           # world +x = screen right, world +z = screen down
	var w: float = Wind.from_deg
	if absf(w - wind_deg) > 0.2 or h.distance_to(heading) > 0.01:
		wind_deg = w
		heading = h
		queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 2.0
	# the dial
	draw_circle(c, r, INK)
	draw_circle(c, r - 2.5, PAPER)
	for i in 8:                                             # ticks, longer at N E S W
		var a := i * TAU / 8.0
		var d := Vector2(sin(a), -cos(a))
		var l := 6.0 if i % 2 == 0 else 3.0
		draw_line(c + d * (r - 3.0), c + d * (r - 3.0 - l), INK, 1.5)
	# N at the top
	var f := get_theme_default_font()
	draw_string(f, c + Vector2(-4.0, -r + 18.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)
	# the wind: from its side toward the other
	var from := Vector2(sin(deg_to_rad(wind_deg)), -cos(deg_to_rad(wind_deg)))
	var arm := r * 0.62
	var tail := c + from * arm
	var tip := c - from * arm
	var side := Vector2(-from.y, from.x)
	draw_line(tail, tip + from * 6.0, INK, 3.0)
	draw_colored_polygon(PackedVector2Array([tip, tip + from * 10.0 + side * 6.0, tip + from * 10.0 - side * 6.0]), INK)
	for k in 2:                                             # two feathers at the tail
		var p := tail - from * (k * 5.0)
		draw_line(p, p + from * 5.0 + side * 5.0, INK, 2.0)
		draw_line(p, p + from * 5.0 - side * 5.0, INK, 2.0)
	# the bow: a hollow triangle on the rim
	var hp := c + heading * (r - 2.0)
	var hs := Vector2(-heading.y, heading.x)
	var tri := PackedVector2Array([hp + heading * 5.0, hp - heading * 5.0 + hs * 5.0, hp - heading * 5.0 - hs * 5.0])
	draw_colored_polygon(tri, PAPER)
	draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), INK, 1.5)

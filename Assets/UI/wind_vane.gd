@tool
extends Control
## The wind indicator, top right, as in Valheim (Enrico): it turns with the boat, not with the map.
##   - In the middle the boat, always pointing up (her bow is the top of the dial).
##   - Round her a ring. Its thick ink stretches are where the wind is bad for sailing: if the wind comes from
##     there, the sail gives less than `poor_drive` of its best (worked out from the boat's curve, POLAR in
##     boat.gd, so it follows any change to it). For this boat that's right ahead and a little either side.
##   - On the ring, the wind: a little badge with an arrow pointing in, sitting where the wind comes FROM,
##     seen from the boat. Steer, and it slides round the ring; keep it off the thick ink to sail well.
## It's redrawn only when the wind's place on the ring moves (by half a degree or more).
## (Like a UMG widget that reads a value from the pawn on tick.)
## @tool: the script also runs in the editor, so it's drawn there too and you can place and size it yourself
## (like a Blueprint's construction script). In the editor it only draws: the wind from behind on the left.

const PAPER := Color("ebe7dc")
const INK := Color("1b1a17")
## The boat's script, only to read its sailing curve (POLAR: [degrees off the wind, share of top speed]).
const BOAT_SCRIPT := preload("res://Assets/Boat/boat.gd")

@export var poor_drive := 0.9    # below this share of the sail's best, the ring is drawn thick (bad wind)

var wind_on_ring := 215.0        # where the wind comes from, seen from the boat: 0 = dead ahead, 90 = from the right


func _process(_dt: float) -> void:
	if Engine.is_editor_hint():
		return                       # in the editor: only the drawing
	var b := get_tree().get_first_node_in_group("player_boat") as Node3D
	if b == null:
		return
	# The way her bow points, as a compass angle (0 = north, 90 = east): Godot's forward is -Z, north is -Z.
	var fwd := -b.global_transform.basis.z
	var heading_deg := rad_to_deg(atan2(fwd.x, -fwd.z))
	# The wind's direction minus hers = where it comes from, seen from her (0 = on the bow, 180 = astern).
	var angle := wrapf(Wind.from_deg - heading_deg, 0.0, 360.0)
	if absf(wrapf(angle - wind_on_ring, -180.0, 180.0)) > 0.5:
		wind_on_ring = angle
		queue_redraw()


## How much the sail gives with the wind `off_deg` degrees off the bow (0..180): the boat's own curve.
func drive_at(off_deg: float) -> float:
	var curve: Array = BOAT_SCRIPT.POLAR
	for i in range(1, curve.size()):
		if off_deg <= curve[i][0]:
			var a = curve[i - 1]
			var b = curve[i]
			return lerpf(a[1], b[1], (off_deg - a[0]) / (b[0] - a[0]))
	return curve[-1][1]


## A point on a circle of radius r round c, at `deg` degrees clockwise from the top.
func on_circle(c: Vector2, r: float, deg: float) -> Vector2:
	var a := deg_to_rad(deg)
	return c + Vector2(sin(a), -cos(a)) * r


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 8.0      # the ring (room outside it for the wind badge)

	# 1. A paper disc behind, so it reads on any sea, and the thin ring.
	draw_circle(c, r + 6.0, PAPER)
	draw_arc(c, r, 0.0, TAU, 64, INK, 1.5)

	# 2. The bad-wind stretches, in thick ink. Going round the ring a degree at a time, a stretch starts where the
	#    sail starts giving too little and ends where it's good again; each stretch is drawn as one arc.
	var in_stretch := false                               # are we inside a bad stretch now?
	var stretch_start := 0                                # if so, where it began (degrees)
	for deg in range(-180, 181):
		var poor := drive_at(absf(deg)) < poor_drive      # absf: the same either side of the bow
		if poor and not in_stretch:                       # a bad stretch begins here
			in_stretch = true
			stretch_start = deg
		var ends_here := in_stretch and (not poor or deg == 180)
		if ends_here:                                     # …and ends here: draw it
			_thick_arc(c, r, stretch_start, deg)
			in_stretch = false

	# 3. The boat in the middle, bow up: a pointed hull in ink with a paper line down her middle.
	var hull := PackedVector2Array()
	var length := r * 0.62
	var beam := r * 0.22
	# t goes from 0 (the bow, at the top) to 1 (the stern): her half-width is beam × sin(PI × t), so 0 at both
	# ends and widest in the middle (a leaf shape, like Valheim's).
	for i in 13:                                    # the right side, bow to stern…
		var t := i / 12.0
		hull.append(c + Vector2(beam * sin(PI * t), -length + 2.0 * length * t))
	for i in range(12, -1, -1):                     # …then the left side, stern back to bow
		var t := i / 12.0
		hull.append(c + Vector2(-beam * sin(PI * t), -length + 2.0 * length * t))
	draw_colored_polygon(hull, INK)
	draw_line(c + Vector2(0.0, -length * 0.55), c + Vector2(0.0, length * 0.6), PAPER, 1.0)

	# 4. The wind: a badge on the ring where it comes from, with an arrow pointing in (the way it blows).
	var at := on_circle(c, r, wind_on_ring)
	var inward := (c - at).normalized()
	var side := Vector2(-inward.y, inward.x)
	# In the bad-wind zone the badge's colours flip (Enrico): an ink disc with a paper arrow, so you see at once
	# that the sail gives little from there. Elsewhere a paper disc with an ink arrow.
	var in_bad_wind := drive_at(absf(wrapf(wind_on_ring, -180.0, 180.0))) < poor_drive
	var disc := INK if in_bad_wind else PAPER
	var mark := PAPER if in_bad_wind else INK
	draw_circle(at, 7.5, disc)
	draw_arc(at, 7.5, 0.0, TAU, 24, mark, 1.5)
	var tip := at + inward * 4.5
	var tail := at - inward * 4.5
	draw_line(tail, tip - inward * 2.0, mark, 2.0)
	draw_colored_polygon(PackedVector2Array([tip, tip - inward * 4.0 + side * 3.5, tip - inward * 4.0 - side * 3.5]), mark)


## A thick ink arc on the ring from `from_deg` to `to_deg` (clockwise from the top; draw_arc itself counts from
## the right, hence the - 90).
func _thick_arc(c: Vector2, r: float, from_deg: float, to_deg: float) -> void:
	draw_arc(c, r, deg_to_rad(from_deg - 90.0), deg_to_rad(to_deg - 90.0), 24, INK, 5.0)

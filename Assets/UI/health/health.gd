@tool
extends Control
## THE HEARTS, top left: the boat's health ("Hull"), as the prototype's: a paper panel with an ink border and
## a hard shadow, the word "Hull" and one heart for every heart she has, each full, half or empty (Zelda's way).
## When she's hurt the panel flashes ink for a moment (the prototype's "hurt").
## It listens to the boat's health_changed signal (boat.gd), so it's drawn again only when something changes,
## not every frame. (In Unreal: a UMG widget bound to an event dispatcher on the pawn.)
## @tool: drawn in the editor too (three full hearts), so you can place it yourself; there it only draws.

const PAPER := Color("ebe7dc")
const INK := Color("1b1a17")

const HURT_FLASH := 0.35          # seconds the panel stays ink after a hit
const HEART_SIZE := 17.0          # one heart, in pixels
const HEART_GAP := 3.0            # the space between two hearts
const PADDING := Vector2(9, 4)    # paper round what's inside the panel (as the prototype's CSS)
const LABEL_GAP := 8.0            # the space between "Hull" and the first heart
const FONT_SIZE := 13
const CURVE_STEPS := 6            # points along each curve of the heart (more = rounder)

# The heart's outline, from the prototype's SVG, in a 16 x 16 box: it starts at the point at the bottom and
# goes round in six curves (cubic Béziers, each [control 1, control 2, end]). The first three are its left
# half, which is what a half heart fills.
const HEART_START := Vector2(8, 14.6)
const HEART_CURVES := [
	[Vector2(4, 11.2), Vector2(1, 8.6), Vector2(1, 5.3)],       # down at the bottom, up the left side
	[Vector2(1, 2.9), Vector2(2.9, 1), Vector2(5.1, 1)],        # round the top of the left lobe
	[Vector2(6.4, 1), Vector2(7.4, 1.7), Vector2(8, 2.8)],      # down into the dip in the middle
	[Vector2(8.6, 1.7), Vector2(9.6, 1), Vector2(10.9, 1)],     # up out of the dip
	[Vector2(13.1, 1), Vector2(15, 2.9), Vector2(15, 5.3)],     # round the top of the right lobe
	[Vector2(15, 8.6), Vector2(12, 11.2), Vector2(8, 14.6)],    # down the right side to the point
]

var max_hearts := 3.0      # how many hearts she has
var health := 3.0          # how many are left (0.5 = half a heart)
var _flash := 0.0          # seconds of the hurt flash left
var _boat: Node3D
var _full_heart: PackedVector2Array    # the heart's outline (all six curves), made once
var _left_half: PackedVector2Array     # its left half (the first three curves), made once


func _ready() -> void:
	_full_heart = _heart_shape(6)
	_left_half = _heart_shape(3)


## Every frame: find the boat once (and listen to her), then only count down the hurt flash.
func _process(dt: float) -> void:
	if Engine.is_editor_hint():
		return
	if _boat == null:
		_boat = get_tree().get_first_node_in_group("player_boat") as Node3D
		if _boat:
			_boat.health_changed.connect(_on_health_changed)
			_on_health_changed(false)
		return
	if _flash > 0.0:
		_flash -= dt
		if _flash <= 0.0:
			queue_redraw()             # the flash is over: back to paper


## The boat's health changed: read it, flash if she was hurt, draw again.
func _on_health_changed(hurt: bool) -> void:
	max_hearts = _boat.max_hearts
	health = _boat.health
	if hurt:
		_flash = HURT_FLASH
	queue_redraw()


func _draw() -> void:
	var count := ceili(max_hearts)
	var font := get_theme_default_font()
	var label_w := font.get_string_size("Hull", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var hearts_w := count * HEART_SIZE + (count - 1) * HEART_GAP
	var panel := Rect2(Vector2.ZERO, PADDING * 2.0 + Vector2(label_w + LABEL_GAP + hearts_w, HEART_SIZE))

	# Hurt: the panel turns ink and what's on it paper, for HURT_FLASH seconds.
	var hurt := _flash > 0.0
	var back := INK if hurt else PAPER
	var front := PAPER if hurt else INK

	# 1. The panel: a hard ink shadow 3 px down and right, the paper, an ink border.
	draw_rect(Rect2(panel.position + Vector2(3, 3), panel.size), INK)
	draw_rect(panel, back)
	draw_rect(panel, INK, false, 2.0)

	# 2. "Hull", in the middle of the panel's height.
	var middle_y := PADDING.y + HEART_SIZE * 0.5
	var baseline := middle_y + (font.get_ascent(FONT_SIZE) - font.get_descent(FONT_SIZE)) * 0.5
	draw_string(font, Vector2(PADDING.x, baseline), "Hull", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, front)

	# 3. The hearts: each one full, half or empty, depending on how much health is left for it.
	var heart_scale := HEART_SIZE / 16.0
	for i in count:
		var corner := Vector2(PADDING.x + label_w + LABEL_GAP + i * (HEART_SIZE + HEART_GAP), PADDING.y)
		var left := clampf(health - i, 0.0, 1.0)          # this heart's share: 1 full, 0.5 half, 0 empty
		if left >= 1.0:
			draw_colored_polygon(_placed(_full_heart, corner, heart_scale), front)
		elif left > 0.0:
			draw_colored_polygon(_placed(_left_half, corner, heart_scale), front)
		var outline := _placed(_full_heart, corner, heart_scale)
		outline.append(outline[0])                         # back to the start, to close it
		draw_polyline(outline, front, 1.6 * heart_scale)


## The points round the heart's outline (in its 16 x 16 box), following its first `curves` curves.
func _heart_shape(curves: int) -> PackedVector2Array:
	var points := PackedVector2Array([HEART_START])
	var from := HEART_START
	for c in curves:
		var curve: Array = HEART_CURVES[c]
		for step in range(1, CURVE_STEPS + 1):
			points.append(from.bezier_interpolate(curve[0], curve[1], curve[2], step / float(CURVE_STEPS)))
		from = curve[2]
	if curves == HEART_CURVES.size():
		points.remove_at(points.size() - 1)                 # the whole heart ends where it started: once is enough
	return points


## The heart's points moved to `corner` and scaled from its 16 x 16 box to the size it's drawn at.
func _placed(shape: PackedVector2Array, corner: Vector2, factor: float) -> PackedVector2Array:
	var placed := PackedVector2Array()
	for p in shape:
		placed.append(corner + p * factor)
	return placed

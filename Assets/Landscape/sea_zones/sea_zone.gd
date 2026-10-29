@tool
class_name SeaZone
extends Node3D
## A SEA ZONE (Enrico): a stretch of sea, drawn in the editor, that is either
##   - BOILING: the boat loses hearts while she's in it (boat.gd boil_damage every boil_every seconds), or
##   - CURRENT: a strong current that carries her the way THIS NODE POINTS (its forward, -Z, the blue arrow in the
##     editor), whatever the wind: the usual current (Wind.CURRENT_SPEED) times `strength`.
## (In Unreal: a Blueprint with a Spline Component that marks out an area.)
##
## How to draw it: the child `Outline` is a Path3D (a spline, like Unreal's). Select it, and in the 3D view's
## toolbar use the Path tools to add, move or delete points: they are the corners of the zone, joined in order and
## closed back to the first. Only where the points are on the water counts (their height doesn't matter).
## To turn a current: rotate the SeaZone node (Y) and the arrow and the flow turn with it.
##
## Nothing here runs in the game: the zones are BAKED (the SeaZoneBaker node, "Bake sea zones") into one picture
## of the whole map, which the sea's shader and the boat read. So after changing a zone, bake again.

enum Kind { BOILING, CURRENT }

## The baked picture holds the current's push up to this many metres a second (each colour channel has only 256
## steps, so this sets the precision too: 20 m/s = steps of about 0.16 m/s). The baker, Land and the sea shader
## all use it from here.
const MAX_PUSH := 20.0

@export var kind := Kind.BOILING:
	set(value):
		kind = value
		_draw_helper()
## CURRENT only: how many times the usual current (Wind.CURRENT_SPEED, 1.5 m/s) it carries her at. 4 = 6 m/s.
@export var strength := 15.0
## Metres in from the edge over which the zone fades in (0 = a hard edge). It takes hold gradually as she enters.
@export var edge_softness := 4.0

var helper: MeshInstance3D = null     # the editor-only drawing (outline and arrow), made in code with no owner


func _ready() -> void:
	if not Engine.is_editor_hint():
		return                           # in the game a zone does nothing: the baked picture does the work
	var outline := get_node_or_null("Outline") as Path3D
	if outline and outline.curve:
		outline.curve.changed.connect(_draw_helper)   # redraw the helper whenever a point is moved
	set_notify_transform(true)                      # and when the node is moved or turned
	_draw_helper()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		_draw_helper()


## The zone's corners on the water, in world metres (x, z), in order: the Path3D's points.
func polygon() -> PackedVector2Array:
	var points := PackedVector2Array()
	var outline := get_node_or_null("Outline") as Path3D
	if outline == null or outline.curve == null:
		return points
	for i in outline.curve.point_count:
		var world := outline.global_transform * outline.curve.get_point_position(i)
		points.append(Vector2(world.x, world.z))
	return points


## Which way the current flows, flat on the water (length 1): the node's forward (-Z), as the boat's.
func flow_direction() -> Vector3:
	var forward := -global_transform.basis.z
	forward.y = 0.0
	return forward.normalized()


# ---- the editor helper: the outline (red for boiling, blue for current) and, for a current, an arrow ----

func _draw_helper() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if helper == null:
		helper = MeshInstance3D.new()
		helper.top_level = true          # drawn in world space: easier, the points are already there
		add_child(helper)                # no owner: never saved into the level
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo = true
		material.no_depth_test = true    # seen over the land (Enrico's rule for helpers)
		material.render_priority = 10    # and after the sea, from afar too
		helper.material_override = material
	var colour := Color(0.9, 0.2, 0.1) if kind == Kind.BOILING else Color(0.2, 0.4, 1.0)
	var lines := ImmediateMesh.new()     # a mesh made of lines, rebuilt each time (only in the editor)
	var points := polygon()
	if points.size() >= 2:
		lines.surface_begin(Mesh.PRIMITIVE_LINES)
		for i in points.size():
			var a := points[i]
			var b := points[(i + 1) % points.size()]   # the last point joins back to the first: closed
			lines.surface_set_color(colour)
			lines.surface_add_vertex(Vector3(a.x, 0.3, a.y))
			lines.surface_set_color(colour)
			lines.surface_add_vertex(Vector3(b.x, 0.3, b.y))
		if kind == Kind.CURRENT:
			_add_arrow(lines, colour)
		lines.surface_end()
	helper.mesh = lines
	helper.global_transform = Transform3D.IDENTITY


## A 10 m arrow from the node's middle the way the current flows.
func _add_arrow(lines: ImmediateMesh, colour: Color) -> void:
	var start := Vector3(global_position.x, 0.3, global_position.z)
	var ahead := flow_direction()
	var side := Vector3(-ahead.z, 0.0, ahead.x)
	var tip := start + ahead * 10.0
	for pair in [[start, tip], [tip, tip - ahead * 2.5 + side * 1.5], [tip, tip - ahead * 2.5 - side * 1.5]]:
		lines.surface_set_color(colour)
		lines.surface_add_vertex(pair[0])
		lines.surface_set_color(colour)
		lines.surface_add_vertex(pair[1])

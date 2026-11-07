@tool
@icon("res://Assets/Inventory/icons/bomb.png")
class_name Destructible
extends Node3D
## DESTRUCTIBLE: a COMPONENT that lets bombs break whatever it's put in (Enrico: like the Towable, an Actor Component
## in Unreal). Add it as a child of the thing (select it, "Add Child Node", look for "Destructible") and put it where
## the thing's middle is: the area a blast must reach is drawn round THIS node (a red shape in the editor), so you
## move and turn the component to fit it.
##
## What it does:
##   - it's in the group "bomb_targets", so every blast (a bomb, a sea mine) asks it `blast_at(bomb)`;
##   - a blast reaching its area takes `bomb.damage` hearts off `max_hearts`, and the thing blinks black for a moment;
##   - at 0 hearts: signal `destroyed`, and the thing goes (freed, or hidden with its collisions off).
## Its area: CIRCLE (`radius` round it) or BOX (`box_size` metres, width along its x, depth along its z, turned with
## it): a long wall needs the box. For the box a grid of points every `box_step` metres is checked (corners and edges
## included), so a thin blast arm across it still counts.
## Its signal, for the parent to react (connect it in the Node dock): destroyed   (a door opens, a prize appears...)
## First use: the secret wall (Assets/Landscape/secret_wall/secret_wall.tscn), Zelda 1's bombable walls.

signal destroyed
## For the EventTrigger (Assets/Quests/event_trigger): sent when this thing's job is done (destroyed).
signal done

enum Shape { CIRCLE, BOX }

@export var max_hearts := 1.0       # how much it takes (a bomb does 1: with 1 a single blast breaks it)
@export var shape := Shape.CIRCLE:
	set(value):
		shape = value
		_update_editor_shape()
@export var radius := 2.0:          # metres: the area round it, for CIRCLE
	set(value):
		radius = value
		_update_editor_shape()
@export var box_size := Vector2(8, 4):   # metres: the area's width (x) and depth (z), for BOX
	set(value):
		box_size = value
		_update_editor_shape()
@export var box_step := 2.0         # metres between the points checked across the box (smaller = more exact)
@export var free_parent := true     # at 0 hearts: true = the thing is freed; false = only hidden, its collisions off
@export var hurt_time := 0.5        # seconds it blinks black when hit
@export var hurt_blinks_per_second := 12.0

var hearts := 1.0
var broken := false
var blink_left := 0.0
var thing: Node3D                    # the parent: what breaks
var black: StandardMaterial3D        # the blink: an unshaded black laid over every mesh of the thing
var _editor_shape: MeshInstance3D = null


func _ready() -> void:
	if Engine.is_editor_hint():
		_update_editor_shape()       # in the editor only: the area drawn in see-through red
		return
	thing = get_parent() as Node3D
	hearts = max_hearts
	add_to_group("bomb_targets")     # so a blast checks it (bomb.gd explode)
	black = StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color.BLACK
	set_process(false)               # nothing to do until it's hit (then only while it blinks)


## A blast went off (bomb.gd explode): does it reach the area? Then it's hurt.
func blast_at(bomb: Node3D) -> void:
	if broken or not is_inside_area_of(bomb):
		return
	hearts -= bomb.damage
	if hearts <= 0.0:
		break_apart.call_deferred()   # after the blast has finished checking everything
	else:
		blink_left = hurt_time
		set_process(true)


## Is any part of its area in the blast? CIRCLE: its middle, with the radius added. BOX: a grid of points across it.
func is_inside_area_of(bomb: Node3D) -> bool:
	if shape == Shape.CIRCLE:
		return bomb.in_blast(global_position, radius)
	var columns := maxi(1, ceili(box_size.x / box_step))
	var rows := maxi(1, ceili(box_size.y / box_step))
	for i in columns + 1:
		for j in rows + 1:
			# A point of the box in this node's own space (its middle at 0, 0), then into the world.
			var local := Vector3(box_size.x * (float(i) / columns - 0.5), 0.0, box_size.y * (float(j) / rows - 0.5))
			if bomb.in_blast(global_transform * local):
				return true
	return false


## While hurt: the thing blinks black (the black material laid over its meshes, on and off), then back to normal.
func _process(dt: float) -> void:
	if Engine.is_editor_hint():
		return
	blink_left -= dt
	var on := blink_left > 0.0 and int(blink_left * hurt_blinks_per_second) % 2 == 0
	set_black(on)
	if blink_left <= 0.0:
		set_process(false)


## Lays the black over every mesh of the thing (on) or takes it off (off).
func set_black(on: bool) -> void:
	for mesh in thing.find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = black if on else null


## 0 hearts: the signal, then the thing goes.
func break_apart() -> void:
	if broken:
		return
	broken = true
	destroyed.emit()
	done.emit()
	if free_parent:
		thing.queue_free()
		return
	thing.visible = false
	for collision in thing.find_children("*", "CollisionShape3D", true, false):
		collision.set_deferred("disabled", true)
	for collision in thing.find_children("*", "CollisionPolygon3D", true, false):
		collision.set_deferred("disabled", true)


## In the editor only: its area as a see-through red disc or box on the water, seen from afar (render_priority 10, no
## depth test, Enrico's rule); made in code with no owner, so it's never saved and never in the game.
func _update_editor_shape() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _editor_shape == null:
		_editor_shape = MeshInstance3D.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1, 0, 0, 0.3)
		mat.no_depth_test = true
		mat.render_priority = 10
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_editor_shape.material_override = mat
		add_child(_editor_shape)
	if shape == Shape.CIRCLE:
		var disc := CylinderMesh.new()
		disc.top_radius = radius
		disc.bottom_radius = radius
		disc.height = 0.05
		_editor_shape.mesh = disc
	else:
		var plane := PlaneMesh.new()
		plane.size = box_size
		_editor_shape.mesh = plane
	_editor_shape.position = Vector3(0, 0.1, 0)

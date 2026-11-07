@tool
class_name TowGoal
extends Node3D
## TOW GOAL: a place where something towed with the hook must be brought (Enrico). Add a Node3D anywhere in the
## level, give it this script (or "Add Child Node" → look for "TowGoal"), and set its `goal_id` and `radius`.
## When a Towable (towable.gd) with the same `tow_id` comes within `radius` of it, the goal takes it: the Towable is
## let go there for good (its signal `delivered`, so its owner can react: the NPC on the raft changes its lines),
## and the goal sends `arrived` (connect it to anything else: a door, a reward…).
## In the editor a green disc shows `radius`.
## THE CALM (Enrico, Nov 2026): inside the green area there's no current: the boat isn't carried and nothing drifts
## (calm_at, asked by boat.gd update_current and by Wind.drift), so a thing towed there stays there.
## (In Unreal: a trigger volume that checks the overlapping actor for a component with a matching tag.)

## Sent when a Towable is delivered here.
signal arrived(towable: Node3D)

## Which Towables it takes: the same text as their `tow_id` (empty = any).
@export var goal_id := ""
## Metres from its middle a towed thing's middle must come within.
@export var radius := 8.0:
	set(value):
		radius = value
		_fit_disc()


func _ready() -> void:
	add_to_group("tow_goals")           # so calm_at finds every goal of the level
	if Engine.is_editor_hint():
		_make_editor_disc()
		return


## Is `point` inside any goal's green area? There the current doesn't flow (Enrico). A static function belongs to the
## script, not to one goal (like a Blueprint Function Library): call it as TowGoal.calm_at(get_tree(), point).
static func calm_at(tree: SceneTree, point: Vector3) -> bool:
	for goal in tree.get_nodes_in_group("tow_goals"):
		var off: Vector3 = point - goal.global_position
		off.y = 0.0
		if off.length() <= goal.radius:
			return true
	return false


## Every physics frame: is a Towable that fits close enough? (A few towables in a level: cheap.)
func _physics_process(_dt: float) -> void:
	if Engine.is_editor_hint():
		return
	for towable in get_tree().get_nodes_in_group("towable"):
		if not towable is Towable:
			continue                                     # the lever is "towable" too, but not a Towable: skip
		if towable.delivered_to != null:
			continue                                     # already taken by a goal
		if goal_id != "" and towable.tow_id != goal_id:
			continue                                     # not for this goal
		var off: Vector3 = towable.global_position - global_position
		off.y = 0.0
		if off.length() <= radius:
			towable.deliver(self)
			arrived.emit(towable)


# ---------- In the editor only: radius drawn as a green disc on the water ----------

var _editor_disc: MeshInstance3D

func _make_editor_disc() -> void:
	# A flat green cylinder, see-through, 1 m across, scaled to the radius. Made in code with no owner, so it's not
	# saved in the scene and never appears in the game.
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.05
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.3, 0.9, 0.4, 0.3)
	material.render_priority = 10       # drawn after the sea and everything else, never hidden by it from afar
	material.no_depth_test = true       # and on top of the land, so it can be spotted from anywhere
	mesh.material = material
	_editor_disc = MeshInstance3D.new()
	_editor_disc.mesh = mesh
	_editor_disc.position.y = 0.1
	add_child(_editor_disc)
	_fit_disc()


func _fit_disc() -> void:
	if _editor_disc:
		_editor_disc.scale = Vector3(radius, 1.0, radius)

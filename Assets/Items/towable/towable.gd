@icon("res://Assets/Inventory/icons/hook.png")
class_name Towable
extends Node3D
## TOWABLE: a COMPONENT that makes whatever it's put in draggable with the hook (Enrico: like an Actor Component in
## Unreal, added to any actor). Add it as a child of anything that moves as one piece (a barrel, a key, an NPC on a
## raft…): select that node, "Add Child Node", look for "Towable". Leave it at the parent's middle (position 0, 0, 0).
## It moves its PARENT, not itself.
##
## What it does:
##   - the hook (Assets/UI/hook_button, through the interaction button) grabs it when her middle is within `grab_reach` of the parent's middle
##     (it's in the group "towable": the hook's interface, can_be_towed, tow_reach, start_tow, stop_tow,
##     is_towed);
##   - towed, the parent follows her: kept at most `rope_length` metres from her stern to its edge (`size` is how big
##     the thing is), pulled along the rope when taut, left still when slack; never onto land (it stays stuck on the
##     shore); she goes at × `tow_slowdown`; an ink rope from her stern to it;
##   - HOW HEAVY IT IS (Enrico, Nov 2026: things sorted by the strength it takes to pull them), `weight`:
##       LIGHT (category 1): she just drags it along, as above;
##       HEAVY (category 2): it moves only while she BOOSTS (the throttle lever held past the middle, paddles.gd
##       is_boosting). Not boosting, once the rope is taut the thing stays put and holds HER instead, like an anchor:
##       her stern can't get further than the rope from it (she can still turn round it, or come back);
##   - a second tap, any damage to the boat (hook_button.gd) or her sinking lets it go: it stays where it is;
##   - a TowGoal (tow_goal.gd) with the same id can take it (`deliver`): it's let go there for good.
## Its signals, for the parent to react (connect them in the Node dock, like binding an Event Dispatcher):
##   grabbed(boat)   the hook took it        released        let go (any way)
##   delivered(goal) a TowGoal took it (after `released`)
## (The barrel stops being solid while towed, the NPC on the raft changes its lines when delivered: see their
## scripts. Something that needs nothing else, needs no script at all: only this component.)

## How hard it is to pull (see the notes above): LIGHT = category 1, HEAVY = category 2.
enum Weight { LIGHT, HEAVY }

signal grabbed(boat: Node3D)
signal released
signal delivered(goal: Node3D)
## For the EventTrigger (Assets/Quests/event_trigger): sent when this thing's job is done (brought to its TowGoal).
signal done

## Which goals take it: a TowGoal with the same text (a goal with no id takes anything).
@export var tow_id := ""
@export var weight := Weight.LIGHT  # LIGHT: dragged along as she goes; HEAVY: only while she boosts, else it holds her
@export var grab_reach := 8.0       # metres from the parent's middle her middle may be for the hook to grab it
@export var rope_length := 4.0      # metres of rope from her stern to the thing's edge while towed
@export var tow_slowdown := 0.2     # her speed × this while she tows it (1 = it doesn't hold her back)
@export var size := 1.0             # metres from the thing's middle to its edge (where the rope ends)
@export var towable_after_delivery := false   # once a goal took it, can it be towed again?
@export var rope_width := 0.15      # metres
@export var rope_height := 0.6      # metres above the water the rope runs

var thing: Node3D                   # the parent: what moves
var tow_boat: Node3D = null         # the boat towing it (null = not towed)
var delivered_to: Node3D = null     # the TowGoal that took it (null = none yet)
var rope: MeshInstance3D            # the ink strip from her stern to it (made in code, shown only while towed)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	thing = get_parent() as Node3D
	add_to_group("towable")                              # so the hook finds it
	# The thing moves in physics frames while towed, like the boat: drawn smoothly between them.
	thing.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	make_rope()
	set_physics_process(false)                           # nothing to do until it's towed
	set_process(false)


func _physics_process(_dt: float) -> void:
	follow_boat()


func _process(_dt: float) -> void:
	draw_rope()


# ---- the hook's interface (Assets/UI/hook_button/hook_button.gd) ----

## May it be grabbed now?
func can_be_towed() -> bool:
	if tow_boat != null:
		return false                                     # already held
	if delivered_to != null and not towable_after_delivery:
		return false                                     # a goal took it for good
	return true


## How close her middle must be to the thing's middle to grab it.
func tow_reach() -> float:
	return grab_reach


## Grabbed: from now on the thing follows her on the rope, and she's held back a little.
func start_tow(by_boat: Node3D) -> void:
	tow_boat = by_boat
	tow_boat.held_back = tow_slowdown                    # boat.gd: her speed × this
	rope.visible = true
	set_physics_process(true)
	set_process(true)
	grabbed.emit(tow_boat)


## Let go: it stays where it is.
func stop_tow() -> void:
	if tow_boat == null:
		return
	if is_instance_valid(tow_boat):
		tow_boat.held_back = 1.0
	tow_boat = null
	rope.visible = false
	set_physics_process(false)
	set_process(false)
	released.emit()


## Still held?
func is_towed() -> bool:
	return tow_boat != null


# ---- goals (tow_goal.gd) ----

## A TowGoal took it: let go (if held), remembered as delivered, and the parent is told.
func deliver(goal: Node3D) -> void:
	stop_tow()
	delivered_to = goal
	delivered.emit(goal)
	done.emit()


# ---- following her ----

## Towed, every physics frame: when the rope is taut (the thing's edge further than rope_length from her stern) the
## thing is pulled toward her stern, along the rope, to just rope_length from it. Slack: it stays where it is.
## Never onto land: then it stays where it was. She sank: let go.
func follow_boat() -> void:
	if not is_instance_valid(tow_boat) or tow_boat.sinking:
		stop_tow()
		return
	var stern: Vector3 = tow_boat.stern_point()
	var off: Vector3 = thing.global_position - stern     # from her stern to it
	off.y = 0.0
	var reach := rope_length + size                      # the rope plus the thing's own size, to its middle
	if off.length() <= reach:
		return                                           # slack: it doesn't move
	# Taut. A HEAVY thing moves only while she boosts: otherwise it stays, and the rope holds her instead.
	if weight == Weight.HEAVY and not tow_boat.paddles.is_boosting():
		hold_boat(off, reach)
		return
	var place: Vector3 = stern + off.normalized() * reach
	place.y = thing.global_position.y
	# Not onto land: its middle and its edge on the way it goes must both be on water.
	var step: Vector3 = place - thing.global_position
	var ahead: Vector3 = place
	if step.length() > 0.001:
		ahead = place + step.normalized() * size * 0.5
	if Land.is_land(place) or Land.is_land(ahead):
		return
	thing.global_position = place


## A HEAVY thing she pulls without boosting: it doesn't budge, so the rope holds HER, as the anchor's line does
## (boat.gd hold_at_anchor). Her stern is put back at the rope's length from it, on the line from it to her stern, her
## heading kept (so she can still turn round it, or come back toward it), and the way she had pulling off is lost.
## `off` = from her stern to the thing; `reach` = the rope plus the thing's size.
func hold_boat(off: Vector3, reach: float) -> void:
	var stern: Vector3 = thing.global_position - off.normalized() * reach   # where her stern may be, at most
	var forward: Vector3 = -tow_boat.global_transform.basis.z
	var middle: Vector3 = stern + forward * tow_boat.bow_reach             # her middle is bow_reach ahead of her stern
	tow_boat.global_position = Vector3(middle.x, tow_boat.global_position.y, middle.z)
	tow_boat.speed = minf(tow_boat.speed, 0.0)                            # her way is taken off by the rope


## A thin flat ink strip from her stern to the thing's edge (a 1 x 1 plane moved to the middle, turned along the line
## and stretched to its length). Drawn every frame from the smoothed places of both.
func draw_rope() -> void:
	if not is_instance_valid(tow_boat):
		return
	var boat_now: Transform3D = tow_boat.get_global_transform_interpolated()
	var stern: Vector3 = boat_now.origin + boat_now.basis.z * tow_boat.bow_reach   # her stern (her forward is -Z)
	var middle: Vector3 = thing.get_global_transform_interpolated().origin
	var line: Vector3 = middle - stern
	line.y = 0.0
	var length := line.length() - size * 0.5             # the rope ends at the thing's side, not its middle
	if length < 0.05:
		rope.visible = false
		return
	rope.visible = true
	var direction := line.normalized()
	var start := Vector3(stern.x, rope_height, stern.z)
	rope.global_position = start + direction * length * 0.5
	rope.global_rotation = Vector3(0.0, atan2(-direction.x, -direction.z), 0.0)
	rope.scale = Vector3(rope_width, 1.0, length)


## The rope: a 1 x 1 plane in plain ink (unshaded), placed in world space (top_level) and not smoothed (it's
## placed every drawn frame from smoothed places already).
func make_rope() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(1, 1)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("1b1a17")
	material.render_priority = 2
	mesh.material = material
	rope = MeshInstance3D.new()
	rope.mesh = mesh
	rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rope.top_level = true
	rope.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	rope.visible = false
	add_child(rope)
